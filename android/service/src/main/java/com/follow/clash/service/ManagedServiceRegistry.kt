package com.follow.clash.service

interface ManagedService {
    fun start()
    fun stop()
}

object ManagedServiceRegistry {
    private val services = mutableSetOf<ManagedService>()

    @Synchronized
    fun register(service: ManagedService) {
        services.add(service)
    }

    @Synchronized
    fun unregister(service: ManagedService) {
        services.remove(service)
    }

    fun stopAll() {
        val snapshot = synchronized(this) { services.toList() }
        var failure: Throwable? = null
        snapshot.forEach { service ->
            try {
                service.stop()
            } catch (error: Throwable) {
                if (failure == null) failure = error else failure!!.addSuppressed(error)
            }
        }
        failure?.let { throw it }
    }
}
