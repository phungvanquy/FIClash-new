package com.follow.clash

import com.follow.clash.common.RunIntentArbiter
import com.follow.clash.models.SharedState
import com.follow.clash.service.models.NotificationParams
import com.follow.clash.service.models.VpnOptions
import com.google.gson.Gson
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.coroutines.resume
import java.util.UUID

enum class RunState {
    STARTED,
    STARTING,
    STOPPING,
    STOPPED,
}

data class RunObservation(
    val session: String,
    val revision: Long = 0,
    val state: RunState = RunState.STOPPED,
    val startedAt: Long = 0,
    val vpn: Boolean = false,
    val failure: String? = null,
)

internal typealias RunRequest = RunIntentArbiter.Token

internal const val MISSING_CONFIG_MESSAGE = "No configuration found."
internal const val INVALID_CONFIG_MESSAGE = "Invalid configuration."
internal const val VPN_PERMISSION_MESSAGE = "VPN permission required."
internal const val START_FAILED_MESSAGE = "Failed to start service."

/**
 * Callers request a transition; the newest request always wins. Every step that outlives its own
 * suspension point re-checks [isCurrent] before it publishes anything, so a start that was overtaken
 * by a stop cannot report itself as started.
 */
internal class ServiceStateMachine(private val host: ServiceStateHost) {
    private val transitionLock = Mutex()
    private val startPreparationLock = Mutex()
    private val mutableRunState = MutableStateFlow(RunState.STOPPED)
    private val arbiter = RunIntentArbiter()
    private val intentLock = Any()
    private val mutableObservation = MutableStateFlow(RunObservation(UUID.randomUUID().toString()))

    @Volatile
    private var sharedState = SharedState()

    @Volatile
    private var pendingVpnPreparation: (() -> Unit)? = null

    val runState = mutableRunState.asStateFlow()
    val observation = mutableObservation.asStateFlow()

    fun snapshot(): RunObservation = observation.value

    private fun publish(state: RunState, failure: String? = null, vpn: Boolean = observation.value.vpn) {
        mutableRunState.value = state
        mutableObservation.value = observation.value.copy(
            revision = observation.value.revision + 1,
            state = state,
            startedAt = if (state == RunState.STOPPED) 0 else runTimeMillis,
            vpn = state != RunState.STOPPED && vpn,
            failure = failure,
        )
    }

    private fun publishCurrent(request: RunRequest, state: RunState, vpn: Boolean = observation.value.vpn) =
        synchronized(intentLock) {
            if (isCurrent(request)) publish(state, vpn = vpn)
        }

    private val runTimeMillis: Long
        get() = host.runTimeMillis

    suspend fun handleToggleAction() {
        if (isRunningRequested()) {
            handleStopAction()
        } else {
            handleStartAction()
        }
    }

    suspend fun refresh(): Long = transitionLock.withLock {
        val current = runTimeMillis
        synchronized(intentLock) {
            if (runState.value != RunState.STARTING && runState.value != RunState.STOPPING) {
                publish(if (current == 0L) RunState.STOPPED else RunState.STARTED)
            }
        }
        current
    }

    fun captureRequestToken(): RunRequest = arbiter.current()

    /**
     * Settles the state after the bound service was lost. [token] is the request that was current
     * when the loss was observed, so a start that raced ahead of this callback keeps its intent.
     */
    suspend fun handleServiceLost(token: RunRequest) = transitionLock.withLock {
        if (runTimeMillis != 0L) {
            return@withLock
        }
        synchronized(intentLock) {
            if (arbiter.resetToStopped(token)) publish(RunState.STOPPED, failure = "service_lost")
        }
    }

    suspend fun handleStartAction() {
        if (isRunningRequested()) {
            return
        }
        val tile = host.tile()
        if (tile != null) {
            tile.handleStart()
            return
        }
        loadPreferencesAndStart()
    }

    suspend fun handleStopAction() {
        if (!isRunningRequested()) {
            return
        }
        val tile = host.tile()
        if (tile != null) {
            tile.handleStop()
            return
        }
        host.showToast(sharedState.stopTip)
        requestStop().await()
    }

    suspend fun handleVpnRevokeAction() {
        if (!host.isVpnServiceActive()) {
            return
        }
        handleStopAction()
    }

    fun requestStart(): Deferred<Boolean> {
        val request = createRequest(running = true)
        val result = CompletableDeferred<Boolean>()
        val launchRequest: (Boolean) -> Unit = { shouldStart ->
            if (!shouldStart) {
                fail(request, "notification_permission_denied")
                result.complete(false)
            } else {
                host.scope.launch {
                    result.complete(
                        runCatching { start(request) }
                            .onFailure { error ->
                                host.log("Unable to process service start request: $error")
                                fail(request, "start_failed")
                                reconcileStopped()
                            }
                            .getOrDefault(false),
                    )
                }
            }
        }
        val app = host.app()
        if (app != null) {
            app.requestNotificationPermission(launchRequest)
        } else {
            launchRequest(true)
        }
        return result
    }

    fun requestStop(): Deferred<Boolean> {
        val request = createRequest(running = false)
        val result = CompletableDeferred<Boolean>()
        host.scope.launch {
            result.complete(
                runCatching { stop(request) }
                    .onFailure { error ->
                        host.log("Unable to process service stop request: $error")
                        synchronized(intentLock) {
                            if (isCurrent(request)) publish(
                                if (runTimeMillis == 0L) RunState.STOPPED else RunState.STARTED,
                                failure = "stop_failed",
                            )
                        }
                    }
                    .getOrDefault(false),
            )
        }
        return result
    }

    fun syncSharedState(state: SharedState) {
        sharedState = state
        applySharedState()
    }

    private suspend fun loadPreferencesAndStart() {
        sharedState = host.loadSharedState()
        if (sharedState.setupParams == null || sharedState.vpnOptions == null) {
            host.showToast(MISSING_CONFIG_MESSAGE)
            return
        }
        if (setupCore()) {
            if (!requestStart().await()) {
                host.showToast(START_FAILED_MESSAGE)
            }
        }
    }

    private fun applySharedState() {
        host.setCrashlytics(sharedState.crashlytics)
        host.updateNotificationParams(notificationParams(sharedState))
    }

    private suspend fun setupCore(): Boolean {
        applySharedState()
        host.showToast(sharedState.startTip)
        return host.quickSetup(
            initParams(host.homeDirPath, host.sdkInt),
            Gson().toJson(sharedState.setupParams),
        ).fold(
            onSuccess = { message ->
                if (message.isEmpty()) {
                    true
                } else {
                    host.log("Unable to set up core: $message")
                    showConfigError(message)
                    false
                }
            },
            onFailure = { error ->
                host.log("Unable to set up core: $error")
                showConfigError(error.message)
                false
            },
        )
    }

    private fun showConfigError(message: String?) {
        host.showToast(message?.takeIf { it.isNotBlank() } ?: INVALID_CONFIG_MESSAGE)
    }

    private suspend fun start(request: RunRequest): Boolean = startPreparationLock.withLock {
        val started = runStart(request)
        if (!started) {
            reconcileStopped()
        }
        started
    }

    private suspend fun runStart(request: RunRequest): Boolean {
        if (!isCurrent(request)) {
            return false
        }
        val options = sharedState.vpnOptions
        if (options == null) {
            fail(request, "missing_configuration")
            return false
        }
        if (!prepareVpn(options)) {
            if (host.app() == null && isCurrent(request)) {
                host.showToast(VPN_PERMISSION_MESSAGE)
            }
            fail(request, "vpn_permission_denied")
            return false
        }
        if (!isCurrent(request)) {
            return false
        }

        return transitionLock.withLock transition@{
            if (!isCurrent(request)) {
                return@transition false
            }
            if (runTimeMillis != 0L && host.isVpnServiceActive() == options.enable) {
                publishCurrent(request, RunState.STARTED, vpn = options.enable)
                return@transition true
            }
            publishCurrent(request, RunState.STARTING)
            val startedAtMillis = host.startService(options)
            if (startedAtMillis == 0L) {
                fail(request, "start_failed")
                return@transition false
            }
            if (!isCurrent(request)) {
                return@transition false
            }
            publishCurrent(request, RunState.STARTED, vpn = options.enable)
            true
        }
    }

    private suspend fun reconcileStopped() = transitionLock.withLock {
        if (isRunningRequested() || runTimeMillis == 0L) {
            return@withLock
        }
        val request = captureRequestToken()
        publishCurrent(request, RunState.STOPPING)
        host.stopService()
        publishCurrent(request, RunState.STOPPED)
    }

    private suspend fun stop(request: RunRequest): Boolean = transitionLock.withLock {
        if (!isCurrent(request)) {
            return@withLock false
        }
        abandonVpnPreparation()
        if (runTimeMillis == 0L) {
            publishCurrent(request, RunState.STOPPED)
            return@withLock true
        }
        publishCurrent(request, RunState.STOPPING)
        host.stopService()
        publishCurrent(request, RunState.STOPPED)
        isCurrent(request)
    }

    private suspend fun prepareVpn(options: VpnOptions): Boolean {
        val app = host.app()
            ?: return !options.enable || host.isVpnPermissionGranted()
        return suspendCancellableCoroutine { continuation ->
            val callback: (Boolean) -> Unit = { granted ->
                pendingVpnPreparation = null
                if (continuation.isActive) {
                    continuation.resume(granted)
                }
            }
            pendingVpnPreparation = {
                app.cancelVpnPreparation(callback)
                callback(false)
            }
            continuation.invokeOnCancellation {
                pendingVpnPreparation = null
                app.cancelVpnPreparation(callback)
            }
            app.prepareVpn(options.enable, callback)
        }
    }

    private fun abandonVpnPreparation() {
        val abandon = pendingVpnPreparation ?: return
        pendingVpnPreparation = null
        abandon()
    }

    private fun createRequest(running: Boolean): RunRequest = synchronized(intentLock) {
        arbiter.request(running).also {
            publish(if (running) RunState.STARTING else RunState.STOPPING)
        }
    }

    private fun isRunningRequested(): Boolean = arbiter.isRunningRequested

    private fun isCurrent(request: RunRequest): Boolean = arbiter.isCurrent(request)

    private fun fail(request: RunRequest, failure: String) = synchronized(intentLock) {
        if (arbiter.resetToStopped(request)) {
            publish(if (runTimeMillis == 0L) RunState.STOPPED else RunState.STARTED, failure)
        }
    }

    internal companion object {
        /**
         * The Core init payload. The key spelling is a cross-language contract with the Go wrapper,
         * not an implementation detail.
         */
        fun initParams(homeDirPath: String, sdkInt: Int): String = Gson().toJson(
            mapOf(
                "home-dir" to homeDirPath,
                "version" to sdkInt,
            ),
        )

        fun notificationParams(state: SharedState): NotificationParams = NotificationParams(
            title = state.currentProfileName,
            stopText = state.stopText,
            onlyStatisticsProxy = state.onlyStatisticsProxy,
            showStopAction = state.showStopAction,
        )
    }
}
