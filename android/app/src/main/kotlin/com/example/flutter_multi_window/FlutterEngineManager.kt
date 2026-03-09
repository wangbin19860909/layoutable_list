package com.example.flutter_multi_window

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader

/**
 * 单例管理共享的FlutterEngine
 * 兼容Flutter 3.10+ 新版本API
 */
object FlutterEngineManager {
    private const val ENGINE_ID = "shared_flutter_engine"
    private var flutterEngine: FlutterEngine? = null

    /**
     * 初始化并获取共享的FlutterEngine
     */
    fun getSharedEngine(): FlutterEngine {
        if (flutterEngine == null) {
            // 适配Flutter 3.10+ 新版本API（移除getInstance()）
            val flutterLoader = FlutterLoader()

            // 初始化FlutterLoader
            flutterLoader.startInitialization(MyApp.context)
            flutterLoader.ensureInitializationCompleteAsync(
                MyApp.context,
                arrayOf(),
                Handler(Looper.getMainLooper()),
                Runnable { }
            )

            // 创建FlutterEngine实例
            flutterEngine = FlutterEngine(MyApp.context)
            // 预加载Flutter入口（main函数）
            flutterEngine!!.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            // 将引擎缓存，方便后续获取
            FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
        }
        return flutterEngine!!
    }

    /**
     * 销毁引擎（APP退出时调用）
     */
    fun destroyEngine() {
        flutterEngine?.destroy()
        flutterEngine = null
        FlutterEngineCache.getInstance().remove(ENGINE_ID)
    }
}