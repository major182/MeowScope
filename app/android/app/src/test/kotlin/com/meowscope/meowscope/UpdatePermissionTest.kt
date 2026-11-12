package com.meowscope.meowscope

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** UT-UP-12：許可の画面を先に出すか（#198）。 */
class UpdatePermissionTest {
    @Test
    fun androidSevenNeverAsksAndDoesNotCallTheMissingFunction() {
        // 境界値 25：Android 7.1 は関数がないので呼ばない（呼ぶと落ちる）
        var called = false
        assertFalse(UpdatePermission.needsPermissionScreen(25) { called = true; false })
        assertFalse(called)
    }

    @Test
    fun androidEightAsksOnlyWhenNotYetAllowed() {
        // 境界値 26：Android 8.0 からは、まだ許可していなければ出す
        assertTrue(UpdatePermission.needsPermissionScreen(26) { false })
        assertFalse(UpdatePermission.needsPermissionScreen(26) { true })
        assertTrue(UpdatePermission.needsPermissionScreen(37) { false })
    }
}
