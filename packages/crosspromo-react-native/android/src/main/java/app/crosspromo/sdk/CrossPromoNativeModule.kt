package app.crosspromo.sdk

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Base64
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityManager
import java.security.MessageDigest
import java.util.UUID

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
                    "installation_id" to installationId(),
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
    fun prepareIntegrity(promise: Promise) {
        promise.resolve(Arguments.makeNativeMap(
            mapOf(
                "provider" to "play_integrity",
                "key_id" to null,
                "app_transaction_jws" to null,
                "device_verification_id" to null,
            )
        ))
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
    fun resetInstallationId(promise: Promise) {
        preferences().edit().remove(INSTALLATION_ID).apply()
        promise.resolve(null)
    }

    private fun installationId(): String {
        val existing = preferences().getString(INSTALLATION_ID, null)
        if (existing != null) return existing
        val value = UUID.randomUUID().toString().lowercase()
        preferences().edit().putString(INSTALLATION_ID, value).apply()
        return value
    }

    private fun preferences() =
        reactContext.getSharedPreferences("app.crosspromo.sdk", Context.MODE_PRIVATE)

    private companion object {
        const val INSTALLATION_ID = "installation-id"
    }
}
