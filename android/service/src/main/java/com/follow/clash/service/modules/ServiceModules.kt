package com.follow.clash.service.modules

import android.app.Service
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.isActive

internal class ServiceModules(private val service: Service) {
    private var scope: CoroutineScope? = null
    private var modules: ModuleLifecycle? = null

    @Synchronized
    fun start() {
        if (scope?.isActive == true) return
        check(scope == null) { "Module cleanup is incomplete" }

        val nextScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        val nextModules = ModuleLifecycle(
            listOf(
                NotificationModule(service, nextScope),
                NetworkObserveModule(service),
                SuspendModule(service, nextScope),
            ),
        )
        scope = nextScope
        modules = nextModules

        try {
            nextModules.start()
        } catch (error: Throwable) {
            runCatching { stop() }.onFailure { error.addSuppressed(it) }
            throw error
        }
    }

    @Synchronized
    fun stop() {
        val currentScope = scope ?: return
        currentScope.cancel()
        modules?.stop()
        scope = null
        modules = null
    }
}
