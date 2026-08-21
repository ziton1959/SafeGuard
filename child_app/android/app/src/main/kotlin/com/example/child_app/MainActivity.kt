package com.example.child_app

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

class MainActivity : FlutterActivity() {
    private val CHANNEL = "safeguard/ocr"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ping" -> {
                        result.success("pong from Kotlin!")
                    }
                    "testOcr" -> {
                        // Stage 2: OCR a test image we draw in code.
                        runTestOcr(result)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    private fun runTestOcr(result: MethodChannel.Result) {
        // 1. Create a blank white bitmap and draw some text on it.
        val bitmap = Bitmap.createBitmap(600, 200, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)
        val paint = Paint().apply {
            color = Color.BLACK
            textSize = 48f
            isAntiAlias = true
        }
        canvas.drawText("nti 9a7ba hello", 30f, 110f, paint)

        // 2. Run ML Kit text recognition on it.
        val image = InputImage.fromBitmap(bitmap, 0)
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

        recognizer.process(image)
            .addOnSuccessListener { visionText ->
                // 3. Send the extracted text back up to Dart.
                result.success(visionText.text)
            }
            .addOnFailureListener { e ->
                result.error("OCR_FAILED", e.message, null)
            }
    }
}