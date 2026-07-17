package app.crosspromo.sdk

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.util.Base64
import java.net.URL
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityManager
import java.security.MessageDigest

class CrossPromoNativeModule(
    private val reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext) {
    override fun getName() = "CrossPromoNative"

    @ReactMethod
    fun getAppContext(promise: Promise) {
        try {
            @Suppress("DEPRECATION")
            val info = reactContext.packageManager.getPackageInfo(reactContext.packageName, 0)
            @Suppress("DEPRECATION")
            val build = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode.toString()
            } else {
                info.versionCode.toString()
            }
            promise.resolve(Arguments.makeNativeMap(
                mapOf(
                    "platform" to "android",
                    "bundle_id" to reactContext.packageName,
                    "version" to (info.versionName ?: "0"),
                    "build_number" to build,
                )
            ))
        } catch (error: Exception) {
            promise.reject("app_context_failed", error)
        }
    }

    @ReactMethod
    fun generateEvidence(input: ReadableMap, promise: Promise) {
        val mode = input.getString("mode")
        if (mode == "none") {
            promise.resolve(Arguments.makeNativeMap(
                mapOf("provider" to "none", "key_id" to null, "payload_base64" to "")
            ))
            return
        }
        if (!input.hasKey("challenge_base64") || !input.hasKey("cloud_project_number")) {
            promise.reject("invalid_arguments", "Challenge and cloud project number are required")
            return
        }
        val challengeBase64 = input.getString("challenge_base64")
        val cloudProjectNumber = input.getDouble("cloud_project_number").toLong()
        if (challengeBase64 == null) {
            promise.reject("invalid_arguments", "Challenge is required")
            return
        }
        try {
            val challenge = Base64.decode(challengeBase64, Base64.DEFAULT)
            val digest = MessageDigest.getInstance("SHA-256").digest(challenge)
            val requestHash = Base64.encodeToString(
                digest,
                Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
            )
            val manager = IntegrityManagerFactory.createStandard(reactContext)
            val prepareRequest = StandardIntegrityManager.PrepareIntegrityTokenRequest.builder()
                .setCloudProjectNumber(cloudProjectNumber)
                .build()
            manager.prepareIntegrityToken(prepareRequest)
                .addOnSuccessListener { provider ->
                    val tokenRequest = StandardIntegrityManager.StandardIntegrityTokenRequest.builder()
                        .setRequestHash(requestHash)
                        .build()
                    provider.request(tokenRequest)
                        .addOnSuccessListener { response ->
                            val tokenBytes = response.token().toByteArray(Charsets.UTF_8)
                            promise.resolve(Arguments.makeNativeMap(
                                mapOf(
                                    "provider" to "play_integrity",
                                    "key_id" to null,
                                    "payload_base64" to Base64.encodeToString(tokenBytes, Base64.NO_WRAP),
                                )
                            ))
                        }
                        .addOnFailureListener { promise.reject("integrity_evidence_failed", it) }
                }
                .addOnFailureListener { promise.reject("integrity_prepare_failed", it) }
        } catch (error: Exception) {
            promise.reject("integrity_evidence_failed", error)
        }
    }

    @ReactMethod
    fun openUrl(value: String, promise: Promise) {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(value)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            reactContext.startActivity(intent)
            promise.resolve(null)
        } catch (error: Exception) {
            promise.reject("open_url_failed", error)
        }
    }

    @ReactMethod
    fun extractIconAccent(value: String, promise: Promise) {
        Thread {
            try {
                val connection = URL(value).openConnection()
                connection.connectTimeout = 10_000
                connection.readTimeout = 10_000
                val bytes = connection.getInputStream().use { it.readBytes() }
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                var sampleSize = 1
                while (bounds.outWidth / (sampleSize * 2) >= 32 &&
                    bounds.outHeight / (sampleSize * 2) >= 32
                ) {
                    sampleSize *= 2
                }
                val options = BitmapFactory.Options().apply { inSampleSize = sampleSize }
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
                if (bitmap == null) {
                    promise.resolve(null)
                    return@Thread
                }
                val accent = dominantColor(bitmap)
                bitmap.recycle()
                if (accent == null) {
                    promise.resolve(null)
                } else {
                    promise.resolve(Arguments.makeNativeMap(
                        mapOf(
                            "red" to accent[0],
                            "green" to accent[1],
                            "blue" to accent[2],
                        )
                    ))
                }
            } catch (error: Exception) {
                // Accent extraction is cosmetic; the card falls back to its
                // neutral palette rather than surfacing an error.
                promise.resolve(null)
            }
        }.start()
    }

    /**
     * Strongest saturated hue family in the icon, ignoring transparent,
     * near-white, near-black, and gray pixels. Mirrors the algorithm used by
     * the native iOS and Flutter SDK cards.
     */
    private fun dominantColor(bitmap: Bitmap): IntArray? {
        val width = bitmap.width
        val height = bitmap.height
        if (width <= 0 || height <= 0) return null
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
        val step = maxOf(1, pixels.size / 4096)

        val bucketCount = 12
        val weights = DoubleArray(bucketCount)
        val counts = IntArray(bucketCount)
        val reds = DoubleArray(bucketCount)
        val greens = DoubleArray(bucketCount)
        val blues = DoubleArray(bucketCount)
        var sampled = 0

        var index = 0
        while (index < pixels.size) {
            val pixel = pixels[index]
            index += step
            sampled++
            if ((pixel ushr 24) and 0xFF < 160) continue
            val red = (pixel shr 16 and 0xFF) / 255.0
            val green = (pixel shr 8 and 0xFF) / 255.0
            val blue = (pixel and 0xFF) / 255.0
            val value = maxOf(red, green, blue)
            val chroma = value - minOf(red, green, blue)
            val saturation = if (value == 0.0) 0.0 else chroma / value
            if (value < 0.16 || saturation < 0.16) continue
            if (value > 0.95 && saturation < 0.2) continue
            var hue = 0.0
            if (chroma > 0) {
                hue = when (value) {
                    red -> ((green - blue) / chroma).mod(6.0)
                    green -> (blue - red) / chroma + 2
                    else -> (red - green) / chroma + 4
                }
                hue /= 6
                if (hue < 0) hue += 1
            }
            val bucket = minOf(bucketCount - 1, (hue * bucketCount).toInt())
            val weight = saturation * saturation * value
            weights[bucket] += weight
            counts[bucket] += 1
            reds[bucket] += red * weight
            greens[bucket] += green * weight
            blues[bucket] += blue * weight
        }

        var best = 0
        for (bucket in 1 until bucketCount) {
            if (weights[bucket] > weights[best]) best = bucket
        }
        val threshold = maxOf(12, (sampled * 0.02).toInt())
        if (counts[best] < threshold || weights[best] <= 0) return null
        return intArrayOf(
            (reds[best] / weights[best] * 255).toInt().coerceIn(0, 255),
            (greens[best] / weights[best] * 255).toInt().coerceIn(0, 255),
            (blues[best] / weights[best] * 255).toInt().coerceIn(0, 255),
        )
    }

}
