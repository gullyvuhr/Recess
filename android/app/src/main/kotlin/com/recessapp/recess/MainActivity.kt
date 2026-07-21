package com.recessapp.recess

import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var previewPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "recess/bell_preview",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "stop" -> {
                    stopPreview()
                    result.success(null)
                }
                "play" -> {
                    stopPreview()
                    val assetPath = call.arguments as? String
                    if (assetPath == null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    try {
                        val assetKey = FlutterInjector.instance()
                            .flutterLoader()
                            .getLookupKeyForAsset(assetPath)
                        val descriptor = assets.openFd(assetKey)
                        previewPlayer = MediaPlayer().apply {
                            setAudioAttributes(
                                AudioAttributes.Builder()
                                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                    .build(),
                            )
                            setDataSource(
                                descriptor.fileDescriptor,
                                descriptor.startOffset,
                                descriptor.length,
                            )
                            setOnCompletionListener { stopPreview() }
                            prepare()
                            descriptor.close()
                            start()
                        }
                    } catch (_: Exception) {
                        stopPreview()
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        stopPreview()
        super.onDestroy()
    }

    private fun stopPreview() {
        previewPlayer?.let {
            try {
                if (it.isPlaying) it.stop()
            } catch (_: IllegalStateException) {
                // The player can already be released after an audio interruption.
            }
            it.release()
        }
        previewPlayer = null
    }
}
