package com.orthotics.orthoscan

import android.content.Context
import android.opengl.GLES11Ext
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
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
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
    private var cameraTextureId = 0
    private var quadProgram = 0
    private var quadPositionAttrib = 0
    private var quadTexCoordAttrib = 0
    private var quadTextureUniform = 0
    private var transformedUvCoords: FloatBuffer? = null
    private var surfaceWidth = 0
    private var surfaceHeight = 0

    private val channel = MethodChannel(
        messenger, "com.orthotics.orthoscan/arcore_view"
    )

    private val VERTEX_SHADER = """
        attribute vec4 a_Position;
        attribute vec2 a_TexCoord;
        varying vec2 v_TexCoord;
        void main() {
            gl_Position = a_Position;
            v_TexCoord = a_TexCoord;
        }
    """.trimIndent()

    private val FRAGMENT_SHADER = """
        #extension GL_OES_EGL_image_external : require
        precision mediump float;
        varying vec2 v_TexCoord;
        uniform samplerExternalOES sTexture;
        void main() {
            gl_FragColor = texture2D(sTexture, v_TexCoord);
        }
    """.trimIndent()

    private val QUAD_VERTS = floatArrayOf(
        -1f, -1f, +1f, -1f, -1f, +1f, +1f, +1f
    )

    private val QUAD_UVS = floatArrayOf(
        0f, 1f, 1f, 1f, 0f, 0f, 1f, 0f
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
                // Create camera texture
                val ids = IntArray(1)
                GLES20.glGenTextures(1, ids, 0)
                cameraTextureId = ids[0]
                GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTextureId)
                GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
                    GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
                GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
                    GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
                GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
                    GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
                GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
                    GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)

                // Build shader program
                val vert = loadShader(GLES20.GL_VERTEX_SHADER, VERTEX_SHADER)
                val frag = loadShader(GLES20.GL_FRAGMENT_SHADER, FRAGMENT_SHADER)
                quadProgram = GLES20.glCreateProgram()
                GLES20.glAttachShader(quadProgram, vert)
                GLES20.glAttachShader(quadProgram, frag)
                GLES20.glLinkProgram(quadProgram)
                quadPositionAttrib = GLES20.glGetAttribLocation(quadProgram, "a_Position")
                quadTexCoordAttrib = GLES20.glGetAttribLocation(quadProgram, "a_TexCoord")
                quadTextureUniform = GLES20.glGetUniformLocation(quadProgram, "sTexture")

                // Init UV buffer
                transformedUvCoords = ByteBuffer
                    .allocateDirect(QUAD_UVS.size * 4)
                    .order(ByteOrder.nativeOrder())
                    .asFloatBuffer()
                transformedUvCoords!!.put(QUAD_UVS).position(0)

                Log.i(TAG, "GL surface created, texture: $cameraTextureId")
                initArSession()
            }

            override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
                GLES20.glViewport(0, 0, width, height)
                surfaceWidth = width
                surfaceHeight = height
                arSession?.setDisplayGeometry(0, width, height)
            }

            override fun onDrawFrame(gl: GL10?) {
                GLES20.glClearColor(0f, 0f, 0f, 1f)
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)

                val session = arSession ?: return
                try {
                    session.setCameraTextureName(cameraTextureId)
                    val frame = session.update()

                    // Update UV transform
                    if (frame.hasDisplayGeometryChanged() && transformedUvCoords != null) {
                        val uvBuf = ByteBuffer
                            .allocateDirect(QUAD_UVS.size * 4)
                            .order(ByteOrder.nativeOrder())
                            .asFloatBuffer()
                        uvBuf.put(QUAD_UVS).position(0)
                        val ndcBuf = ByteBuffer
                            .allocateDirect(QUAD_VERTS.size * 4)
                            .order(ByteOrder.nativeOrder())
                            .asFloatBuffer()
                        ndcBuf.put(QUAD_VERTS).position(0)
                        frame.transformCoordinates2d(
                            Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES,
                            ndcBuf,
                            Coordinates2d.TEXTURE_NORMALIZED,
                            uvBuf
                        )
                        transformedUvCoords = uvBuf
                    }

                    // Draw camera background
                    drawCameraBackground()

                    // Capture depth points if scanning
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

    private fun drawCameraBackground() {
        val uvCoords = transformedUvCoords ?: return

        val vertBuf = ByteBuffer
            .allocateDirect(QUAD_VERTS.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
        vertBuf.put(QUAD_VERTS).position(0)

        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(false)
        GLES20.glUseProgram(quadProgram)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTextureId)
        GLES20.glUniform1i(quadTextureUniform, 0)
        GLES20.glVertexAttribPointer(quadPositionAttrib, 2,
            GLES20.GL_FLOAT, false, 0, vertBuf)
        GLES20.glVertexAttribPointer(quadTexCoordAttrib, 2,
            GLES20.GL_FLOAT, false, 0, uvCoords)
        GLES20.glEnableVertexAttribArray(quadPositionAttrib)
        GLES20.glEnableVertexAttribArray(quadTexCoordAttrib)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(quadPositionAttrib)
        GLES20.glDisableVertexAttribArray(quadTexCoordAttrib)
        GLES20.glDepthMask(true)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
    }

    private fun capturePoints(frame: Frame) {
        try {
            val pointCloud = frame.acquirePointCloud()
            val points = pointCloud.points
            var i = 0
            while (i < points.limit() - 3) {
                val x = points.get(i)
                val y = points.get(i + 1)
                val z = points.get(i + 2)
                val confidence = points.get(i + 3)
                if (confidence > 0.1f) {
                    mainActivity.addPointToCore(x, y, z)
                }
                i += 4
            }
            pointCloud.release()
        } catch (e: NotYetAvailableException) {
            // Normal
        } catch (e: Exception) {
            Log.e(TAG, "Capture points error: ${e.message}")
        }
    }

    private fun initArSession() {
        try {
            val installStatus = ArCoreApk.getInstance()
                .requestInstall(mainActivity, true)
            if (installStatus == ArCoreApk.InstallStatus.INSTALL_REQUESTED) {
                return
            }
            val session = Session(context)
            val config = Config(session).apply {
                updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                depthMode = if (session.isDepthModeSupported(Config.DepthMode.AUTOMATIC))
                    Config.DepthMode.AUTOMATIC
                else Config.DepthMode.DISABLED
            }
            session.configure(config)
            session.setCameraTextureName(cameraTextureId)
            session.resume()
            arSession = session
            Log.i(TAG, "✓ ARCore session started")
        } catch (e: Exception) {
            Log.e(TAG, "ARCore init failed: ${e.message}")
        }
    }

    private fun loadShader(type: Int, code: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, code)
        GLES20.glCompileShader(shader)
        val status = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, status, 0)
        if (status[0] == 0) {
            Log.e(TAG, "Shader compile error: ${GLES20.glGetShaderInfoLog(shader)}")
        }
        return shader
    }

    private fun setupChannel() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startScan" -> {
                    isScanning = true
                    mainActivity.startScanSession()
                    result.success("started")
                }
                "stopScan" -> {
                    isScanning = false
                    mainActivity.stopScanSession()
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