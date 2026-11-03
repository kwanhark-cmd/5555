package com.kwanhark.vaultassistant.account_vault

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// local_auth(지문·얼굴)는 FragmentActivity 가 필요하다.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // 화면 캡처·최근 앱 미리보기 방지(기본 켜짐). 앱이 준비되면 설정값으로 다시 맞춘다.
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "account_vault/secure_screen")
            .setMethodCallHandler { call, result ->
                if (call.method == "setSecure") {
                    val on = call.arguments as? Boolean ?: true
                    runOnUiThread {
                        if (on) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        // 앱 꾸미기: 런처 이름·아이콘 바꾸기(같은 앱, 다른 입구 하나만 켬)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "account_vault/launcher")
            .setMethodCallHandler { call, result ->
                if (call.method != "setStyle") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val wanted = when (call.arguments as? String) {
                    "calculator" -> "LauncherCalculator"
                    "memo" -> "LauncherMemo"
                    else -> "LauncherDefault"
                }
                try {
                    for (alias in listOf("LauncherDefault", "LauncherCalculator", "LauncherMemo")) {
                        val state = if (alias == wanted) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                        else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                        packageManager.setComponentEnabledSetting(
                            ComponentName(packageName, "$packageName.$alias"),
                            state,
                            PackageManager.DONT_KILL_APP
                        )
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("launcher_failed", e.javaClass.simpleName, null)
                }
            }
        // 새 버전 설치: 해시 확인을 마친 APK 를 안드로이드 설치 화면으로 넘긴다(사용자가 최종 확인).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "account_vault/installer")
            .setMethodCallHandler { call, result ->
                if (call.method != "installApk") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !packageManager.canRequestPackageInstalls()
                    ) {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")
                            )
                        )
                        result.success("need_permission")
                        return@setMethodCallHandler
                    }
                    val file = File(call.arguments as String)
                    val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success("started")
                } catch (e: Exception) {
                    result.error("install_failed", e.javaClass.simpleName, null)
                }
            }
    }
}
