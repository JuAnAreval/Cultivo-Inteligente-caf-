class AiModelConfig {
  const AiModelConfig._();

  static const String modelFileName = 'qwen_2_5_1_5b_public.task';

  // El repositorio LiteRT original ahora responde 401.
  // Esta variante publica sigue resolviendo correctamente.
  static const String modelUrl =
      'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.task';
}
