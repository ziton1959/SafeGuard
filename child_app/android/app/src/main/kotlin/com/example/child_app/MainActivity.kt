package com.example.child_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.media.projection.MediaProjectionManager
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ping" -> result.success("pong from Kotlin!")
                    "testOcr" -> runTestOcr(result)
                    "requestCapture" -> {
                        // Stage 3a: show the screen-capture permission dialog.
                        pendingResult = result
                        val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                                as MediaProjectionManager
                        startActivityForResult(
                            mpm.createScreenCaptureIntent(),
                            SCREEN_CAPTURE_REQUEST
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREEN_CAPTURE_REQUEST) {
            if (resultCode == Activity.RESULT_OK) {
                pendingResult?.success("Permission granted!")
            } else {
                pendingResult?.success("Permission denied")
            }
            pendingResult = null
        }
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