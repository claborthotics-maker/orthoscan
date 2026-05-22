package com.orthotics.orthoscan

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import com.google.ar.core.*
import com.google.ar.core.exceptions.*

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.orthotics.orthoscan/arcore"
    private val TAG = "OrthoScan"

    private var arSession: Session? = null
    private var isScanning = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isArCoreSupported" -> {
                        val supported = isArCoreSupported()
                        Log.i(TAG, "ARCore supported: $supported")
                        result.success(supported)
                    }
                    "startScan" -> {
                        try {
                            startArSession()
                            isScanning = true
                            Log.i(TAG, "Scan started")
                            result.success("scanning_started")
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to start scan: ${e.message}")
                            result.error("START_FAILED", e.message, null)
                        }
                    }
                    "stopScan" -> {
                        isScanning = false
                        stopArSession()
                        Log.i(TAG, "Scan stopped")
                        result.success("scanning_stopped")
                    }
                    "captureFrame" -> {
                        try {
                            val pointCount = captureDepthFrame()
                            result.success(pointCount)
                        } catch (e: Exception) {
                            Log.e(TAG, "Frame capture failed: ${e.message}")
                            result.error("CAPTURE_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isArCoreSupported(): Boolean {
        return try {
            val availability = ArCoreApk.getInstance().checkAvailability(this)
            availability.isSupported
        } catch (e: Exception) {
            Log.e(TAG, "ARCore check failed: ${e.message}")
            false
        }
    }

    private fun startArSession() {
        if (arSession != null) return

        val installStatus = ArCoreApk.getInstance().requestInstall(this, true)
        if (installStatus == ArCoreApk.InstallStatus.INSTALL_REQUESTED) {
            Log.i(TAG, "ARCore installation requested")
            return
        }

        arSession = Session(this).apply {
            val config = Config(this).apply {
                if (isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                    depthMode = Config.DepthMode.AUTOMATIC
                    Log.i(TAG, "Depth mode enabled")
                } else {
                    depthMode = Config.DepthMode.DISABLED
                    Log.w(TAG, "Depth mode not supported on this device")
                }
                updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
            }
            configure(config)
        }

        Log.i(TAG, "ARCore session started")
    }

    private fun stopArSession() {
        arSession?.close()
        arSession = null
        Log.i(TAG, "ARCore session stopped")
    }

    private fun captureDepthFrame(): Int {
        val session = arSession ?: return 0

        return try {
            val frame = session.update()
            val pointCloud = frame.acquirePointCloud()
            val points = pointCloud.points
            val pointCount = points.limit() / 4

            Log.i(TAG, "Captured $pointCount points from depth frame")

            var i = 0
            while (i < points.limit() - 3) {
                val x = points.get(i)
                val y = points.get(i + 1)
                val z = points.get(i + 2)
                val confidence = points.get(i + 3)

                if (confidence > 0.5f) {
                    addPointToCore(x, y, z)
                }
                i += 4
            }

            pointCloud.release()
            pointCount
        } catch (e: NotYetAvailableException) {
            Log.d(TAG, "Depth frame not yet available")
            0
        } catch (e: Exception) {
            Log.e(TAG, "Error capturing frame: ${e.message}")
            0
        }
    }

    private external fun addPointToCore(x: Float, y: Float, z: Float)

    companion object {
        init {
            System.loadLibrary("orthoscan_core")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopArSession()
    }
}