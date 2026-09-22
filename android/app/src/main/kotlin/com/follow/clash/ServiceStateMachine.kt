package com.follow.clash

import com.follow.clash.common.RunIntentArbiter
import com.follow.clash.models.SharedState
import com.follow.clash.service.models.NotificationParams
import com.follow.clash.service.models.VpnOptions
import com.google.gson.Gson
import com.google.gson.JsonObject
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
    val requested: Boolean = false,
) {
    fun toWireJson(): String = JsonObject().apply {
        addProperty("session", session)
        addProperty("revision", revision)
        addProperty("state", when (state) {
            RunState.STARTED -> "STARTED"
            RunState.STARTING -> "STARTING"
            RunState.STOPPING -> "STOPPING"
            RunState.STOPPED -> "STOPPED"
        })
        addProperty("startedAt", startedAt)
        addProperty("vpn", vpn)
        addProperty("failure", failure)
        addProperty("requested", requested)
    }.toString()
}

internal typealias RunRequest = RunIntentArbiter.Token

internal const val MISSING_CONFIG_MESSAGE = "No configuration found."
internal const val INVALID_CONFIG_MESSAGE = "Invalid configuration."
internal const val VPN_PERMISSION_MESSAGE = "VPN permission required."
internal const val START_FAILED_MESSAGE = "Failed to start service."

internal class ServiceStateMachine(private val host: ServiceStateHost) {
    private val transitionLock = Mutex()
    private val startPreparationLock = Mutex()
    private val mutableRunState = MutableStateFlow(RunState.STOPPED)
    private val arbiter = RunIntentArbiter()
    private val intentLock = Any()
    private val mutableObservation = MutableStateFlow(RunObservation(UUID.randomUUID().toString()))
    private var pendingStop: Deferred<Boolean>? = null
    private var pendingStopRequest: RunRequest? = null

    @Volatile
    private var cleanupFailed = false

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
            requested = isRunningRequested(),
        )
    }

    private fun publishCurrent(
        request: RunRequest,
        state: RunState,
        vpn: Boolean = observation.value.vpn,
        failure: String? = null,
    ) = synchronized(intentLock) {
        if (isCurrent(request)) publish(state, failure = failure, vpn = vpn)
    }

    private val runTimeMillis: Long
        get() = host.runTimeMillis

    suspend fun handleToggleAction() {
        if (isRunningRequested() || runState.value != RunState.STOPPED) {
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

    suspend fun handleServiceLost(token: RunRequest) = transitionLock.withLock {
        if (runTimeMillis != 0L) {
            return@withLock
        }
        fail(token, "service_lost")
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
        if (!isRunningRequested() && runState.value == RunState.STOPPED && runTimeMillis == 0L) {
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
                    result.complete(processStart(request))
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

    fun requestStop(): Deferred<Boolean> = synchronized(intentLock) {
        pendingStop?.takeIf {
            !it.isCompleted && pendingStopRequest?.let(::isCurrent) == true
        }?.let { return@synchronized it }
        val request = createRequest(running = false)
        val result = CompletableDeferred<Boolean>()
        pendingStop = result
        pendingStopRequest = request
        host.scope.launch {
            result.complete(
                runCatching { stop(request) }
                    .onFailure { error ->
                        host.log("Unable to process service stop request: $error")
                        synchronized(intentLock) {
                            if (isCurrent(request)) publish(
                                RunState.STOPPING,
                                failure = "stop_failed",
                            )
                        }
                    }
                    .getOrDefault(false),
            )
        }
        result
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
        val request = createRequest(running = true)
        try {
            if (!canStart(request)) return
            if (setupCore()) {
                if (!isCurrent(request)) {
                    reconcileStopped(force = true)
                } else if (!processStart(request)) {
                    host.showToast(START_FAILED_MESSAGE)
                }
            } else {
                fail(request, "configuration_failed")
                reconcileStopped(force = true)
            }
        } catch (error: Throwable) {
            host.log("Unable to prepare background service start: $error")
            fail(request, "start_failed")
            runCatching { reconcileStopped(force = true) }
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

    private suspend fun processStart(request: RunRequest): Boolean =
        runCatching { start(request) }
            .onFailure { error ->
                host.log("Unable to process service start request: $error")
                fail(request, "start_failed")
                runCatching { reconcileStopped() }
            }
            .getOrDefault(false)

    private suspend fun runStart(request: RunRequest): Boolean {
        if (!canStart(request)) {
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

    private suspend fun canStart(request: RunRequest): Boolean = transitionLock.withLock {
        if (!isCurrent(request)) return@withLock false
        if (!cleanupFailed) return@withLock true
        fail(request, "stop_failed")
        false
    }

    private suspend fun reconcileStopped(force: Boolean = false) = transitionLock.withLock {
        if (isRunningRequested() ||
            (!force && cleanupFailed) ||
            (!force && runTimeMillis == 0L && observation.value.failure != "start_failed")) {
            return@withLock
        }
        val request = captureRequestToken()
        val failure = observation.value.failure?.takeUnless { it == "stop_failed" }
        publishCurrent(request, RunState.STOPPING)
        try {
            stopService()
        } catch (error: Throwable) {
            publishCurrent(request, RunState.STOPPING, failure = "stop_failed")
            throw error
        }
        publishCurrent(request, RunState.STOPPED, failure = failure)
    }

    private suspend fun stop(request: RunRequest): Boolean = transitionLock.withLock {
        if (!isCurrent(request)) {
            return@withLock false
        }
        abandonVpnPreparation()
        publishCurrent(request, RunState.STOPPING)
        stopService()
        publishCurrent(request, RunState.STOPPED)
        isCurrent(request)
    }

    private suspend fun stopService() {
        try {
            host.stopService()
            cleanupFailed = false
        } catch (error: Throwable) {
            cleanupFailed = true
            throw error
        }
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
            if (cleanupFailed) publish(RunState.STOPPING, failure = "stop_failed")
            else publish(if (runTimeMillis == 0L) RunState.STOPPED else RunState.STARTED, failure)
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
