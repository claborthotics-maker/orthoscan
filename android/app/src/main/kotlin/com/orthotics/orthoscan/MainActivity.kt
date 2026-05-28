package com.orthotics.orthoscan

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.orthotics.orthoscan/arcore"
    private val TAG = "OrthoScan"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register ARCore platform view
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "arcore_view",
            ArCoreViewFactory(flutterEngine.dartExecutor.binaryMessenger, this)
        )

        // Keep existing method channel for compatibility
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isArCoreSupported" -> {
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Called from ArCoreView
    fun startScanSession() {
        orthoscanStartSession()
        Log.i(TAG, "Scan session started")
    }

    fun stopScanSession() {
        orthoscanStopSession()
        Log.i(TAG, "Scan session stopped")
    }

    fun resetScan() {
        orthoscanReset()
        Log.i(TAG, "Scan reset")
    }

    fun getPointCount(): Int {
        return orthoscanGetPointCount()
    }

    external fun addPointToCore(x: Float, y: Float, z: Float)
    external fun getPointsFromCore(): FloatArray?
    private external fun orthoscanStartSession()
    private external fun orthoscanStopSession()
    private external fun orthoscanReset()
    private external fun orthoscanGetPointCount(): Int

    companion object {
        init {
            System.loadLibrary("orthoscan_core")
        }
    }
}