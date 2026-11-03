package com.kwanhark.vaultassistant.account_vault

import android.os.Bundle
import android.view.WindowManager
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
    }
}
