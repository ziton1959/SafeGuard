package com.example.child_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

class MainActivity : FlutterActivity() {
    private val CHANNEL = "safeguard/ocr"
    private val SCREEN_CAPTURE_REQUEST = 1001
    private var pendingResult: MethodChannel.Result? = null

    private var mediaProjection: MediaProjection? = null
    private var imageReader: ImageReader? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var captureReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ping" -> result.success("pong from Kotlin!")
                    "testOcr" -> runTestOcr(result)
                    "startMonitoring" -> {
                        // Ask permission ONCE, set up persistent capture.
                        pendingResult = result
                        val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                                as MediaProjectionManager
                        startActivityForResult(
                            mpm.createScreenCaptureIntent(),
                            SCREEN_CAPTURE_REQUEST
                        )
                    }
                    "grabFrame" -> {
                        // Called repeatedly by the Dart timer. No permission prompt.
                        grabFrameAndOcr(result)
                    }
                    "stopMonitoring" -> {
                        cleanup()
                        result.success("stopped")
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREEN_CAPTURE_REQUEST) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val serviceIntent = Intent(this, ScreenCaptureService::class.java)
                startForegroundService(serviceIntent)
                Handler(Looper.getMainLooper()).postDelayed({
                    setupCapture(resultCode, data)
                }, 500)
            } else {
                pendingResult?.success("Permission denied")
                pendingResult = null
            }
        }
    }

    private fun setupCapture(resultCode: Int, data: Intent) {
        val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                as MediaProjectionManager
        mediaProjection = mpm.getMediaProjection(resultCode, data)

        mediaProjection?.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() { cleanup() }
        }, Handler(Looper.getMainLooper()))

        val metrics = DisplayMetrics()
        windowManager.defaultDisplay.getRealMetrics(metrics)
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val density = metrics.densityDpi

        imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "SafeGuardCapture",
            width, height, density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface, null, null
        )

        captureReady = true
        // tell Dart setup succeeded so it can start the timer
        pendingResult?.success("monitoring_started")
        pendingResult = null
    }

    private fun grabFrameAndOcr(result: MethodChannel.Result) {
        if (!captureReady || imageReader == null) {
            result.success("(not ready)")
            return
        }
        try {
            val image = imageReader?.acquireLatestImage()
            if (image == null) {
                result.success("(no frame)")
                return
            }
            val planes = image.planes
            val buffer = planes[0].buffer
            val pixelStride = planes[0].pixelStride
            val rowStride = planes[0].rowStride
            val rowPadding = rowStride - pixelStride * image.width

            val bitmap = Bitmap.createBitmap(
                image.width + rowPadding / pixelStride,
                image.height,
                Bitmap.Config.ARGB_8888
            )
            bitmap.copyPixelsFromBuffer(buffer)
            image.close()

            val inputImage = InputImage.fromBitmap(bitmap, 0)
            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            recognizer.process(inputImage)
                .addOnSuccessListener { visionText ->
                    result.success(if (visionText.text.isBlank()) "(no text)" else visionText.text)
                }
                .addOnFailureListener { e ->
                    result.success("(ocr failed: ${e.message})")
                }
        } catch (e: Exception) {
            result.success("(error: ${e.message})")
        }
    }

    private fun cleanup() {
        captureReady = false
        virtualDisplay?.release()
        imageReader?.close()
        mediaProjection?.stop()
        virtualDisplay = null
        imageReader = null
        mediaProjection = null
        try { stopService(Intent(this, ScreenCaptureService::class.java)) } catch (_: Exception) {}
    }

    private fun runTestOcr(result: MethodChannel.Result) {
        val bitmap = Bitmap.createBitmap(600, 200, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)
        val paint = Paint().apply {
            color = Color.BLACK
            textSize = 48f
            isAntiAlias = true
        }
        canvas.drawText("nti 9a7ba hello", 30f, 110f, paint)
        val image = InputImage.fromBitmap(bitmap, 0)
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        recognizer.process(image)
            .addOnSuccessListener { visionText -> result.success(visionText.text) }
            .addOnFailureListener { e -> result.error("OCR_FAILED", e.message, null) }
    }
}