package com.follow.clash.service.modules

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

class ModuleLifecycleTest {
    @Test
    fun `cleanup continues after failure and retains only failed resources for retry`() {
        val stopped = mutableListOf<Int>()
        var fail = true
        val modules = ModuleLifecycle((1..3).map { id ->
            object : ServiceModule {
                override fun start() {}
                override fun stop() {
                    stopped.add(id)
                    if (id == 2 && fail) error("cleanup failed")
                }
            }
        })
        modules.start()
        assertTrue(runCatching { modules.stop() }.isFailure)
        assertEquals(listOf(3, 2, 1), stopped)
        fail = false
        modules.stop()
        modules.stop()
        assertEquals(listOf(3, 2, 1, 2), stopped)
    }

    @Test
    fun `partial module startup is also cleaned`() {
        var stopped = false
        val lifecycle = ModuleLifecycle(listOf(object : ServiceModule {
            override fun start() { error("partial startup") }
            override fun stop() { stopped = true }
        }))
        assertTrue(runCatching { lifecycle.start() }.isFailure)
        lifecycle.stop()
        assertTrue(stopped)
    }

    @Test
    fun `late publication cannot resurrect a stopped notification`() {
        val gate = ModuleGate()
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val events = mutableListOf<String>()
        val update = thread {
            gate.update {
                entered.countDown()
                check(release.await(5, TimeUnit.SECONDS))
                events.add("publish")
            }
        }
        assertTrue(entered.await(5, TimeUnit.SECONDS))
        val stop = thread { gate.stop { events.add("remove") } }
        release.countDown()
        update.join(5_000)
        stop.join(5_000)
        gate.update { events.add("late publish") }
        assertEquals(listOf("publish", "remove"), events)
    }

    @Test
    fun `failed removal still blocks updates and can be retried`() {
        val gate = ModuleGate()
        assertTrue(runCatching { gate.stop { error("remove failed") } }.isFailure)
        gate.update { fail("updated after stop") }
        var removed = false
        gate.stop { removed = true }
        assertTrue(removed)
    }
}
