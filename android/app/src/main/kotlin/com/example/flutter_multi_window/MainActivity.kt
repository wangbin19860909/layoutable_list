package com.example.flutter_multi_window

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.appcompat.app.AppCompatActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AppCompatActivity() {
  private lateinit var flutterView: FlutterView
  private lateinit var flutterEngine: FlutterEngine
  private val REQUEST_OVERLAY_PERMISSION = 1001

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    flutterEngine = FlutterEngineManager.getSharedEngine()

    flutterView = FlutterView(this)
    flutterView.attachToFlutterEngine(flutterEngine)
    flutterEngine.navigationChannel.setInitialRoute("/main")

    setContentView(flutterView)

    /*window.decorView.postDelayed({
      checkOverlayPermission()
    }, 1000)*/
  }

  private fun checkOverlayPermission() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      if (!Settings.canDrawOverlays(this)) {
        val intent = Intent(
          Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
          android.net.Uri.parse("package:$packageName")
        )
        startActivityForResult(intent, REQUEST_OVERLAY_PERMISSION)
      } else {
        showFloatingWindow()
      }
    } else {
      showFloatingWindow()
    }
  }

  private fun showFloatingWindow() {
    //FloatingFlutterWindow.getInstance(this).show(flutterEngine)
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    super.onActivityResult(requestCode, resultCode, data)
    if (requestCode == REQUEST_OVERLAY_PERMISSION) {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(this)) {
        showFloatingWindow()
      }
    }
  }

  override fun onResume() {
    super.onResume()
    flutterEngine.lifecycleChannel.appIsResumed()
  }

  override fun onPause() {
    super.onPause()
    flutterEngine.lifecycleChannel.appIsInactive()
  }

  override fun onStop() {
    super.onStop()
    flutterEngine.lifecycleChannel.appIsPaused()
  }

  override fun onDestroy() {
    super.onDestroy()
    flutterView.detachFromFlutterEngine()
    FloatingFlutterWindow.getInstance(this).hide()
  }
}