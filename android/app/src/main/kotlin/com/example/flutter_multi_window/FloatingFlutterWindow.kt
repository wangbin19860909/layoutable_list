package com.example.flutter_multi_window

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine

class FloatingFlutterWindow private constructor(private val context: Context) {
  private val windowManager by lazy { context.getSystemService(Context.WINDOW_SERVICE) as WindowManager }
  private lateinit var flutterView: FlutterView
  private var isShowing = false

  private val layoutParams by lazy {
    WindowManager.LayoutParams().apply {
      type = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
      } else {
        @Suppress("DEPRECATION")
        WindowManager.LayoutParams.TYPE_PHONE
      }
      flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
          WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
          WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
      width = 500
      height = 700
      gravity = Gravity.END or Gravity.BOTTOM
      x = 30
      y = 100
      format = PixelFormat.TRANSLUCENT
    }
  }

  fun show(flutterEngine: FlutterEngine) {
    if (isShowing) return

    Log.d("FlutterWindow", "show")
    flutterView = FlutterView(context)
    flutterView.attachToFlutterEngine(flutterEngine)
    flutterEngine.navigationChannel.setInitialRoute("/floating")

    windowManager.addView(flutterView, layoutParams)
    isShowing = true

    flutterEngine.lifecycleChannel.appIsResumed()
  }

  fun hide() {
    if (!isShowing) return

    flutterView.detachFromFlutterEngine()
    windowManager.removeView(flutterView)
    isShowing = false
  }

  companion object {
    fun getInstance(context: Context): FloatingFlutterWindow {
      return FloatingFlutterWindow(context.applicationContext)
    }
  }
}