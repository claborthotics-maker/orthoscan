package com.orthotics.orthoscan

import android.content.Context
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.util.Log
import android.view.View
import com.google.ar.core.*
import com.google.ar.core.exceptions.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

class ArCoreViewFactory(
    private val messenger: BinaryMessenger,
    private val mainActivity: MainActivity
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return ArCorePlatformView(context, messenger, mainActivity)
    }
}

class ArCorePlatformView(
    private val context: Context,
    private val messenger: BinaryMessenger,
    private val mainActivity: MainActivity
) : PlatformView {

    private val TAG = "ArCoreView"
    private val glSurfaceView = GLSurfaceView(context)
    private var arSession: Session? = null
    private var isScanning = false
    private var surfaceCreated = false
    private var cameraTextureId = 0

    private val channel = MethodChannel(
        messenger, "com.orthotics.orthoscan/arcore_view"
    )

    init {
        setupGL()
        setupChannel()
    }

    private fun setupGL() {
        glSurfaceView.preserveEGLContextOnPause = true
        glSurfaceView.setEGLContextClientVersion(2)
        glSurfaceView.setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        glSurfaceView.setRenderer(object : GLSurfaceView.Renderer {
            override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
                // Generate camera texture
                val ids = IntArray(1)
                GLES20.glGenTextures(1, ids, 0)
                cameraTextureId = ids[0]
                surfaceCreated = true
                Log.i(TAG, "GL surface created, texture: $cameraTextureId")
                initArSession()
            }

            override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
                GLES20.glViewport(0, 0, width, height)
                arSession?.setDisplayGeometry(0, width, height)
            }

            override fun onDrawFrame(gl: GL10?) {
                GLES20.glClearColor(0.1f, 0.1f, 0.1f, 1.0f)
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)

                val session = arSession ?: return
                try {
                    session.setCameraTextureName(cameraTextureId)
                    val frame = session.update()

                    if (isScanning) {
                        capturePoints(frame)
                    }
                } catch (e: CameraNotAvailableException) {
                    Log.e(TAG, "Camera not available: ${e.message}")
                } catch (e: Exception) {
                    Log.d(TAG, "Draw frame: ${e.message}")
                }
            }
        })
        glSurfaceView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
    }

    private fun initArSession() {
        try {
            val installStatus = ArCoreApk.getInstance()
                .requestInstall(mainActivity, true)
            if (installStatus == ArCoreApk.InstallStatus.INSTALL_REQUESTED) {
                Log.i(TAG, "ARCore install requested")
                return
            }

            val session = Session(context)
            val config = Config(session).apply {
                updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                if (session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                    depthMode = Config.DepthMode.AUTOMATIC
                    Log.i(TAG, "✓ Depth mode AUTOMATIC enabled")
                } else {
                    depthMode = Config.DepthMode.DISABLED
                    Log.w(TAG, "✗ Depth mode NOT supported on this device")
                }
            }
            session.configure(config)
            session.setCameraTextureName(cameraTextureId)
            session.resume()
            arSession = session
            Log.i(TAG, "✓ ARCore session started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "ARCore init failed: ${e.message}")
        }
    }

    private fun capturePoints(frame: Frame) {
        try {
            val pointCloud = frame.acquirePointCloud()
            val points = pointCloud.points
            var captured = 0
            var i = 0
            while (i < points.limit() - 3) {
                val x = points.get(i)
                val y = points.get(i + 1)
                val z = points.get(i + 2)
                val confidence = points.get(i + 3)
                if (confidence > 0.5f) {
                    mainActivity.addPointToCore(x, y, z)
                    captured++
                }
                i += 4
            }
            if (captured > 0) {
                Log.d(TAG, "Captured $captured points this frame")
            }
            pointCloud.release()
        } catch (e: NotYetAvailableException) {
            // Normal - depth not ready yet
        } catch (e: Exception) {
            Log.e(TAG, "Capture points error: ${e.message}")
        }
    }

    private fun setupChannel() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startScan" -> {
                    isScanning = true
                    mainActivity.startScanSession()
                    Log.i(TAG, "Scan started")
                    result.success("started")
                }
                "stopScan" -> {
                    isScanning = false
                    mainActivity.stopScanSession()
                    Log.i(TAG, "Scan stopped: ${mainActivity.getPointCount()} points")
                    result.success(mainActivity.getPointCount())
                }
                "getPointCount" -> {
                    result.success(mainActivity.getPointCount())
                }
                "getPoints" -> {
                    val pts = mainActivity.getPointsFromCore()
                    result.success(pts?.toList() ?: emptyList<Float>())
                }
                "reset" -> {
                    isScanning = false
                    mainActivity.resetScan()
                    result.success("reset")
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun getView(): View = glSurfaceView

    override fun dispose() {
        glSurfaceView.onPause()
        arSession?.pause()
        arSession?.close()
        arSession = null
        channel.setMethodCallHandler(null)
    }
}