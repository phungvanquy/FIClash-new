package com.follow.clash.service.modules

internal interface ServiceModule {
    fun start()
    fun stop()
}

internal class ModuleLifecycle(private val modules: List<ServiceModule>) {
    private val owned = mutableListOf<ServiceModule>()

    fun start() {
        check(owned.isEmpty()) { "Module cleanup is incomplete" }
        modules.forEach { module ->
            owned.add(module)
            module.start()
        }
    }

    fun stop() {
        var failure: Throwable? = null
        owned.toList().asReversed().forEach { module ->
            try {
                module.stop()
                owned.remove(module)
            } catch (error: Throwable) {
                if (failure == null) failure = error else failure!!.addSuppressed(error)
            }
        }
        failure?.let { throw it }
    }
}

internal class ModuleGate {
    private var stopped = false

    @Synchronized
    fun update(block: () -> Unit) {
        if (!stopped) block()
    }

    @Synchronized
    fun stop(block: () -> Unit) {
        stopped = true
        block()
    }
}
