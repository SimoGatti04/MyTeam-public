package com.example.myteam_video_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "it.simogatti.myteam/updater"
    private val INSTALL_PERMISSION_REQUEST_CODE = 1001
    private var pendingApkPath: String? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.localizedMessage, null)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                        return@setMethodCallHandler
                    }

                    val apkFile = File(filePath)
                    if (!apkFile.exists() || !apkFile.canRead()) {
                        result.error("FILE_NOT_FOUND", "APK file does not exist or cannot be read: $filePath", null)
                        return@setMethodCallHandler
                    }

                    // Verifica se abbiamo il permesso per installare app sconosciute (Android 8.0+)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        if (!packageManager.canRequestPackageInstalls()) {
                            // Salva lo stato e invia l'utente alle impostazioni di sistema
                            pendingApkPath = filePath
                            pendingResult = result
                            try {
                                val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                                startActivityForResult(intent, INSTALL_PERMISSION_REQUEST_CODE)
                            } catch (e: Exception) {
                                pendingResult = null
                                pendingApkPath = null
                                result.error("PERMISSION_DENIED", "Cannot open unknown sources settings: ${e.localizedMessage}", null)
                            }
                            return@setMethodCallHandler
                        }
                    }

                    launchInstaller(apkFile, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun launchInstaller(apkFile: File, result: MethodChannel.Result) {
        try {
            val authority = "$packageName.fileprovider"
            val contentUri: Uri = FileProvider.getUriForFile(this, authority, apkFile)

            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(contentUri, "application/vnd.android.package-archive")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
            }

            // Verifica che esista un'Activity capace di gestire l'Intent
            if (installIntent.resolveActivity(packageManager) != null) {
                startActivity(installIntent)
                result.success(true)
            } else {
                result.error("NO_INSTALLER", "No package installer available on this device", null)
            }
        } catch (e: Exception) {
            result.error("INSTALL_ERROR", "Error launching package installer: ${e.localizedMessage}", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == INSTALL_PERMISSION_REQUEST_CODE) {
            val res = pendingResult
            val path = pendingApkPath
            pendingResult = null
            pendingApkPath = null

            if (res != null && path != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && packageManager.canRequestPackageInstalls()) {
                    val apkFile = File(path)
                    if (apkFile.exists()) {
                        launchInstaller(apkFile, res)
                    } else {
                        res.error("FILE_NOT_FOUND", "File deleted during permission request", null)
                    }
                } else {
                    res.error("PERMISSION_DENIED", "User did not grant install unknown apps permission", null)
                }
            }
        }
    }
}
