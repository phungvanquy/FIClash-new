package com.follow.clash.service

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import com.follow.clash.common.GlobalState
import com.follow.clash.core.Core
import com.follow.clash.service.modules.ServiceModules

class ProxyService : Service(), ManagedService {
    private val modules = ServiceModules(this)
    private val binder = LocalBinder()
    private var active = false

    override fun onCreate() {
        super.onCreate()
        ManagedServiceRegistry.register(this)
    }

    override fun onDestroy() {
        try {
            runCatching { cleanup() }
                .onSuccess { ManagedServiceRegistry.unregister(this) }
                .onFailure { GlobalState.log("Proxy destruction cleanup failed: $it") }
        } finally {
            super.onDestroy()
        }
    }

    override fun onLowMemory() {
        Core.forceGC()
        super.onLowMemory()
    }

    inner class LocalBinder : Binder() {
        val service: ProxyService
            get() = this@ProxyService
    }

    override fun onBind(intent: Intent): IBinder = binder

    @Synchronized
    override fun start() {
        active = true
        try {
            modules.start()
        } catch (error: Exception) {
            stop()
            throw error
        }
    }

    @Synchronized
    override fun stop() {
        try {
            cleanup()
        } finally {
            stopSelf()
        }
    }

    @Synchronized
    private fun cleanup() {
        try {
            modules.stop()
        } finally {
            if (active) {
                Core.stopTun()
                active = false
            }
        }
    }
}
