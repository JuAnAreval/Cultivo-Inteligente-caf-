package com.appflutterai.app_flutter_ai

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.appflutterai/llm"
    private var llmInference: LlmInference? = null
    private var initializedModelPath: String? = null
    private var isGenerating = false
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initLlm" -> {
                    val modelPath = call.argument<String>("modelPath")
                    if (modelPath != null) {
                        try {
                            if (llmInference != null && initializedModelPath == modelPath) {
                                result.success("Initialized")
                                return@setMethodCallHandler
                            }

                            llmInference?.close()
                            llmInference = null

                            val options = LlmInference.LlmInferenceOptions.builder()
                                .setModelPath(modelPath)
                                .setMaxTopK(40)
                                .setMaxTokens(512)
                                .build()
                            llmInference = LlmInference.createFromOptions(context, options)
                            initializedModelPath = modelPath
                            result.success("Initialized")
                        } catch (e: Exception) {
                            initializedModelPath = null
                            llmInference = null
                            result.error("INIT_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Model path is required", null)
                    }
                }
                "generateResponse" -> {
                    val prompt = call.argument<String>("prompt")
                    if (prompt != null && llmInference != null) {
                        if (isGenerating) {
                            result.error("BUSY", "LLM is already generating a response", null)
                            return@setMethodCallHandler
                        }

                        isGenerating = true
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val response = llmInference?.generateResponse(prompt)
                                launch(Dispatchers.Main) {
                                    isGenerating = false
                                    result.success(response)
                                }
                            } catch (e: Exception) {
                                launch(Dispatchers.Main) {
                                    isGenerating = false
                                    result.error("GENERATE_FAILED", e.message, null)
                                }
                            }
                        }
                    } else {
                        result.error("INVALID_STATE", "LLM not initialized or prompt missing", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        llmInference?.close()
        llmInference = null
        initializedModelPath = null
        super.onDestroy()
    }
}
