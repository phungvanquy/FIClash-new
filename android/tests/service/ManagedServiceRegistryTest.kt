package com.follow.clash.service

import org.junit.Assert.*
import org.junit.Test

class ManagedServiceRegistryTest {
    @Test
    fun `unbound services are cleaned and a failed service remains available for retry`() {
        var fail = true
        var firstStops = 0
        var secondStops = 0
        val first = object : ManagedService {
            override fun start() {}
            override fun stop() {
                firstStops++
                if (fail) error("cleanup failed")
            }
        }
        val second = object : ManagedService {
            override fun start() {}
            override fun stop() { secondStops++ }
        }
        ManagedServiceRegistry.register(first)
        ManagedServiceRegistry.register(second)
        try {
            assertTrue(runCatching { ManagedServiceRegistry.stopAll() }.isFailure)
            assertEquals(1, firstStops)
            assertEquals(1, secondStops)
            ManagedServiceRegistry.unregister(second)
            fail = false
            ManagedServiceRegistry.stopAll()
            assertEquals(2, firstStops)
            assertEquals(1, secondStops)
        } finally {
            ManagedServiceRegistry.unregister(first)
            ManagedServiceRegistry.unregister(second)
        }
    }
}
