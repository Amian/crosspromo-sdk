package app.crosspromo.sdk

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.util.Base64
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class CrossPromoFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "app.crosspromo/sdk")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAppContext" -> result.success(appContext())
            "generateEvidence" -> generateEvidence(call, result)
            "openUrl" -> openUrl(call, result)
            else -> result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun appContext(): Map<String, String> {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        val build = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode.toString()
        } else {
            info.versionCode.toString()
        }
        return mapOf(
            "platform" to "android",
            "bundle_id" to context.packageName,
            "version" to (info.versionName ?: "0"),
            "build_number" to build,
        )
    }

    private fun generateEvidence(call: MethodCall, result: MethodChannel.Result) {
        val mode = call.argument<String>("mode")
        if (mode == "none") {
            result.success(mapOf("provider" to "none", "key_id" to null, "payload_base64" to ""))
            return
        }
        val challengeBase64 = call.argument<String>("challenge_base64")
        val cloudProjectNumber = call.argument<Number>("cloud_project_number")?.toLong()
        if (challengeBase64 == null || cloudProjectNumber == null) {
            result.error("invalid_arguments", "Challenge and cloud project number are required", null)
            return
        }
        try {
            val challenge = Base64.decode(challengeBase64, Base64.DEFAULT)
            val digest = MessageDigest.getInstance("SHA-256").digest(challenge)
            val requestHash = Base64.encodeToString(
                digest,
                Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
            )
            val manager = IntegrityManagerFactory.createStandard(context)
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
                            result.success(
                                mapOf(
                                    "provider" to "play_integrity",
                                    "key_id" to null,
                                    "payload_base64" to Base64.encodeToString(tokenBytes, Base64.NO_WRAP),
                                )
                            )
                        }
                        .addOnFailureListener { error ->
                            result.error("integrity_evidence_failed", error.localizedMessage, null)
                        }
                }
                .addOnFailureListener { error ->
                    result.error("integrity_prepare_failed", error.localizedMessage, null)
                }
        } catch (error: Exception) {
            result.error("integrity_evidence_failed", error.localizedMessage, null)
        }
    }

    private fun openUrl(call: MethodCall, result: MethodChannel.Result) {
        val value = call.argument<String>("url")
        if (value == null) {
            result.error("invalid_url", "A URL is required", null)
            return
        }
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(value)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error("open_url_failed", error.localizedMessage, null)
        }
    }

}
