package com.orthotics.orthoscan

import android.content.Context
import android.media.Image
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
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

    // Camera background shader
    private var quadProgram = 0
    private var quadPositionAttrib = 0
    private var quadTexCoordAttrib = 0
    private var quadTextureUniform = 0
    private var transformedUvCoords: FloatBuffer? = null

    // Point cloud shader
    private var pointProgram = 0
    private var pointPositionAttrib = 0
    private var pointMvpUniform = 0
    private var pointDepthRangeUniform = 0

    // Accumulated world-space points (x,y,z triples)
    private var pointsBuffer: FloatBuffer = ByteBuffer
        .allocateDirect(60000 * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
    private var pointFloatCount = 0
    private var shouldClear = false
    private val maxFloats = 900000 // ~300k points cap

    // Voxel dedup grid (3mm)
    private val voxelSet = HashSet<Long>()
    private val voxelSize = 0.003f
    private var floorY = Float.NaN

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

    private val POINT_VERTEX_SHADER = """
        uniform mat4 u_ModelViewProjection;
        uniform vec2 u_DepthRange;
        attribute vec4 a_Position;
        varying vec4 v_Color;
        void main() {
            gl_Position = u_ModelViewProjection * vec4(a_Position.xyz, 1.0);
            gl_PointSize = 5.0;
            float depth = gl_Position.w;
            float t = clamp((depth - u_DepthRange.x) / (u_DepthRange.y - u_DepthRange.x), 0.0, 1.0);
            vec3 nearColor = vec3(1.0, 0.2, 0.1);
            vec3 midColor = vec3(1.0, 0.85, 0.1);
            vec3 farColor = vec3(0.1, 0.5, 1.0);
            vec3 color;
            if (t < 0.5) {
                color = mix(nearColor, midColor, t * 2.0);
            } else {
                color = mix(midColor, farColor, (t - 0.5) * 2.0);
            }
            v_Color = vec4(color, 1.0);
        }
    """.trimIndent()

    private val POINT_FRAGMENT_SHADER = """
        precision mediump float;
        varying vec4 v_Color;
        void main() {
            vec2 coord = gl_PointCoord - vec2(0.5);
            if (length(coord) > 0.5) discard;
            gl_FragColor = v_Color;
        }
    """.trimIndent()

    private val QUAD_VERTS = floatArrayOf(-1f, -1f, +1f, -1f, -1f, +1f, +1f, +1f)
    private val QUAD_UVS = floatArrayOf(0f, 1f, 1f, 1f, 0f, 0f, 1f, 0f)

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

                val vert = loadShader(GLES20.GL_VERTEX_SHADER, VERTEX_SHADER)
                val frag = loadShader(GLES20.GL_FRAGMENT_SHADER, FRAGMENT_SHADER)
                quadProgram = GLES20.glCreateProgram()
                GLES20.glAttachShader(quadProgram, vert)
                GLES20.glAttachShader(quadProgram, frag)
                GLES20.glLinkProgram(quadProgram)
                quadPositionAttrib = GLES20.glGetAttribLocation(quadProgram, "a_Position")
                quadTexCoordAttrib = GLES20.glGetAttribLocation(quadProgram, "a_TexCoord")
                quadTextureUniform = GLES20.glGetUniformLocation(quadProgram, "sTexture")

                val pVert = loadShader(GLES20.GL_VERTEX_SHADER, POINT_VERTEX_SHADER)
                val pFrag = loadShader(GLES20.GL_FRAGMENT_SHADER, POINT_FRAGMENT_SHADER)
                pointProgram = GLES20.glCreateProgram()
                GLES20.glAttachShader(pointProgram, pVert)
                GLES20.glAttachShader(pointProgram, pFrag)
                GLES20.glLinkProgram(pointProgram)
                pointPositionAttrib = GLES20.glGetAttribLocation(pointProgram, "a_Position")
                pointMvpUniform = GLES20.glGetUniformLocation(pointProgram, "u_ModelViewProjection")
                pointDepthRangeUniform = GLES20.glGetUniformLocation(pointProgram, "u_DepthRange")

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

                if (shouldClear) {
                    pointFloatCount = 0
                    voxelSet.clear()
                    shouldClear = false
                }

                val session = arSession ?: return
                try {
                    session.setCameraTextureName(cameraTextureId)
                    val frame = session.update()

                    if (isScanning) {
                        updateFloorPlane(session)
                    }

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

                    drawCameraBackground()

                    if (isScanning) {
                        captureDepthImage(frame)
                    }

                    drawAccumulatedPoints(frame)

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
        GLES20.glVertexAttribPointer(quadPositionAttrib, 2, GLES20.GL_FLOAT, false, 0, vertBuf)
        GLES20.glVertexAttribPointer(quadTexCoordAttrib, 2, GLES20.GL_FLOAT, false, 0, uvCoords)
        GLES20.glEnableVertexAttribArray(quadPositionAttrib)
        GLES20.glEnableVertexAttribArray(quadTexCoordAttrib)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(quadPositionAttrib)
        GLES20.glDisableVertexAttribArray(quadTexCoordAttrib)
        GLES20.glDepthMask(true)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
    }

    private fun appendPoint(x: Float, y: Float, z: Float) {
        if (pointFloatCount + 3 > pointsBuffer.capacity()) {
            if (pointsBuffer.capacity() * 2 > maxFloats) return
            val newBuf = ByteBuffer
                .allocateDirect(pointsBuffer.capacity() * 2 * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer()
            pointsBuffer.position(0)
            pointsBuffer.limit(pointFloatCount)
            newBuf.put(pointsBuffer)
            pointsBuffer = newBuf
        }
        pointsBuffer.position(pointFloatCount)
        pointsBuffer.put(x)
        pointsBuffer.put(y)
        pointsBuffer.put(z)
        pointFloatCount += 3
    }

    private fun updateFloorPlane(session: Session) {
        try {
            var lowest = Float.NaN
            for (plane in session.getAllTrackables(Plane::class.java)) {
                if (plane.trackingState == TrackingState.TRACKING &&
                    plane.type == Plane.Type.HORIZONTAL_UPWARD_FACING) {
                    val y = plane.centerPose.ty()
                    if (lowest.isNaN() || y < lowest) lowest = y
                }
            }
            if (!lowest.isNaN()) floorY = lowest
        } catch (e: Exception) {
            // ignore
        }
    }

    private fun captureDepthImage(frame: Frame) {
        var depthImage: Image? = null
        try {
            depthImage = frame.acquireDepthImage16Bits()
            val dw = depthImage.width
            val dh = depthImage.height
            val plane = depthImage.planes[0]
            val buffer = plane.buffer
            val rowStride = plane.rowStride
            val pixelStride = plane.pixelStride

            val intr = frame.camera.imageIntrinsics
            val fx = intr.focalLength[0]
            val fy = intr.focalLength[1]
            val cxp = intr.principalPoint[0]
            val cyp = intr.principalPoint[1]
            val iw = intr.imageDimensions[0]
            val ih = intr.imageDimensions[1]
            val sx = dw.toFloat() / iw
            val sy = dh.toFloat() / ih
            val fxd = fx * sx
            val fyd = fy * sy
            val cxd = cxp * sx
            val cyd = cyp * sy

            val pose = frame.camera.pose
            val pt = FloatArray(3)
            val step = 2

            val uStart = (dw * 0.15f).toInt()
            val uEnd = (dw * 0.85f).toInt()
            val vStart = (dh * 0.15f).toInt()
            val vEnd = (dh * 0.85f).toInt()

            var v = vStart
            while (v < vEnd) {
                var u = uStart
                while (u < uEnd) {
                    val byteIndex = v * rowStride + u * pixelStride
                    val lo = buffer.get(byteIndex).toInt() and 0xFF
                    val hi = buffer.get(byteIndex + 1).toInt() and 0xFF
                    val raw = (hi shl 8) or lo
                    val depthMm = raw and 0x1FFF
                    if (depthMm in 150..900) { // 15cm - 90cm
                        val d = depthMm / 1000.0f
                        val x = (u - cxd) * d / fxd
                        val y = (v - cyd) * d / fyd
                        pt[0] = x
                        pt[1] = -y
                        pt[2] = -d
                        val world = pose.transformPoint(pt)
                        val aboveFloor = floorY.isNaN() ||
                                world[1] > floorY + 0.015f
                        if (aboveFloor) {
                            val gx = Math.round(world[0] / voxelSize).toLong()
                            val gy = Math.round(world[1] / voxelSize).toLong()
                            val gz = Math.round(world[2] / voxelSize).toLong()
                            val key = (gx and 0x1FFFFF) or
                                    ((gy and 0x1FFFFF) shl 21) or
                                    ((gz and 0x1FFFFF) shl 42)
                            if (voxelSet.add(key)) {
                                appendPoint(world[0], world[1], world[2])
                                mainActivity.addPointToCore(world[0], world[1], world[2])
                            }
                        }
                    }
                    u += step
                }
                v += step
            }
        } catch (e: NotYetAvailableException) {
            // depth not ready yet
        } catch (e: Exception) {
            Log.d(TAG, "Depth capture: ${e.message}")
        } finally {
            depthImage?.close()
        }
    }

    private fun drawAccumulatedPoints(frame: Frame) {
        if (pointFloatCount < 3) return
        try {
            val camera = frame.camera
            val projMatrix = FloatArray(16)
            camera.getProjectionMatrix(projMatrix, 0, 0.1f, 100.0f)
            val viewMatrix = FloatArray(16)
            camera.getViewMatrix(viewMatrix, 0)
            val mvpMatrix = FloatArray(16)
            Matrix.multiplyMM(mvpMatrix, 0, projMatrix, 0, viewMatrix, 0)

            GLES20.glUseProgram(pointProgram)
            GLES20.glUniformMatrix4fv(pointMvpUniform, 1, false, mvpMatrix, 0)
            GLES20.glUniform2f(pointDepthRangeUniform, 0.2f, 1.5f)

            pointsBuffer.position(0)
            pointsBuffer.limit(pointFloatCount)
            GLES20.glVertexAttribPointer(
                pointPositionAttrib, 3, GLES20.GL_FLOAT, false, 0, pointsBuffer)
            GLES20.glEnableVertexAttribArray(pointPositionAttrib)
            GLES20.glDrawArrays(GLES20.GL_POINTS, 0, pointFloatCount / 3)
            GLES20.glDisableVertexAttribArray(pointPositionAttrib)
            pointsBuffer.limit(pointsBuffer.capacity())
        } catch (e: Exception) {
            Log.d(TAG, "Draw accumulated: ${e.message}")
        }
    }

    private fun initArSession() {
        try {
            val installStatus = ArCoreApk.getInstance().requestInstall(mainActivity, true)
            if (installStatus == ArCoreApk.InstallStatus.INSTALL_REQUESTED) return
            val session = Session(context)
            val config = Config(session).apply {
                updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                planeFindingMode = Config.PlaneFindingMode.HORIZONTAL
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
                    shouldClear = true
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
                    if (pts == null || pts.isEmpty()) {
                        result.success(emptyList<Float>())
                    } else {
                        val total = pts.size / 3
                        val maxPoints = 15000
                        val stride = if (total <= maxPoints) 1
                                     else (total + maxPoints - 1) / maxPoints
                        val out = ArrayList<Float>(minOf(total, maxPoints) * 3)
                        var i = 0
                        while (i < total) {
                            val base = i * 3
                            out.add(pts[base])
                            out.add(pts[base + 1])
                            out.add(pts[base + 2])
                            i += stride
                        }
                        result.success(out)
                    }
                }
                "reset" -> {
                    isScanning = false
                    shouldClear = true
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