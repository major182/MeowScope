package com.meowscope.meowscope

/** アプリの更新で、OS のインストールの画面の前に「この提供元のアプリを許可」の画面を出すかを決める（画面設計書 S-51）。 */
object UpdatePermission {
    /** アプリごとの許可（canRequestPackageInstalls）ができた Android 8.0 の API の番号。 */
    const val PER_APP_PERMISSION_SDK = 26

    /**
     * 許可の画面を先に出すか。
     *
     * Android 8.0 より前は、アプリごとの許可がなく、確かめる関数も端末にない（呼ぶとアプリが落ちる。#198）。
     * その端末では OS のインストールの画面が自分で「提供元不明のアプリ」の設定を求めるので、ここでは出さない。
     * [canRequestInstalls] は、Android 8.0 以上のときだけ呼ぶ。
     */
    fun needsPermissionScreen(sdkInt: Int, canRequestInstalls: () -> Boolean): Boolean =
        sdkInt >= PER_APP_PERMISSION_SDK && !canRequestInstalls()
}
