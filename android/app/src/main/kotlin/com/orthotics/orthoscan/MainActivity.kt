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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startScan" -> {
                        Log.i(TAG, "Start scan requested from Flutter")
                        result.success("scanning_started")
                    }
                    "stopScan" -> {
                        Log.i(TAG, "Stop scan requested from Flutter")
                        result.success("scanning_stopped")
                    }
                    "isArCoreSupported" -> {
                        // Check if ARCore is supported on this device
                        val supported = isArCoreSupported()
                        Log.i(TAG, "ARCore supported: $supported")
                        result.success(supported)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isArCoreSupported(): Boolean {
        return try {
            val availability = com.google.ar.core.ArCoreApk.getInstance()
                .checkAvailability(this)
            availability.isSupported
        } catch (e: Exception) {
            Log.e(TAG, "ARCore check failed: ${e.message}")
            false
        }
    }
}