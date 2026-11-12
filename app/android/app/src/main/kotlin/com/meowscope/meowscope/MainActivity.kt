package com.meowscope.meowscope

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // アプリの更新（F-UP-02、画面設計書 S-51）：取ってきた APK を OS のインストールの画面に渡す
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.meowscope/update")
            .setMethodCallHandler { call, result ->
                if (call.method != "installApk") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "path がない", null)
                    return@setMethodCallHandler
                }
                try {
                    // 初めてのときは、先に「この提供元のアプリを許可」の画面を出す。OS の案内から許可すると
                    // インストールに戻らずこのアプリに戻ってしまうため、許可を済ませてから Dart の側でもう一度呼ぶ
                    // Android 8.0 より前は、この許可がない（OS のインストールの画面が自分で求める。#198）
                    if (UpdatePermission.needsPermissionScreen(Build.VERSION.SDK_INT) {
                            packageManager.canRequestPackageInstalls()
                        }
                    ) {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                        result.success("needs_permission")
                        return@setMethodCallHandler
                    }
                    // ほかのアプリ（OS のインストーラー）にファイルを見せるには、file:// ではなく
                    // FileProvider の content:// を渡し、読む権限だけを一時的に与える
                    val uri = FileProvider.getUriForFile(this, "$packageName.updates", File(path))
                    val intent = Intent(Intent.ACTION_VIEW)
                        .setDataAndType(uri, "application/vnd.android.package-archive")
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    startActivity(intent)
                    result.success("started")
                } catch (e: Throwable) {
                    // 渡せないときは Dart の側で「取ってこられなかった」と同じ案内を出す。
                    // 端末にない関数を呼んだとき（Error）もアプリを落とさない（#198）
                    result.error("launch_failed", e.javaClass.simpleName, null)
                }
            }
    }
}
