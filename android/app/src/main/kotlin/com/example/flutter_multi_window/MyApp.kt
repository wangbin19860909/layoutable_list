package com.example.flutter_multi_window

import android.app.Application
import android.content.Context

class MyApp : Application() {
  companion object {
    lateinit var context: Context
      private set
  }

  override fun onCreate() {
    super.onCreate()
    context = applicationContext
  }
}