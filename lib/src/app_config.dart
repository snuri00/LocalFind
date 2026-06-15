class ModelSpec {
  final String fileName;
  final int size;
  final String sha256;
  const ModelSpec({required this.fileName, required this.size, required this.sha256});

  String url(String base) => '$base/$fileName';
}

class AppConfig {
  static const String hfRepoBase =
      'https://huggingface.co/ekremabiii/localfind-geoclip-onnx/resolve/main';

  static const ModelSpec vision = ModelSpec(
    fileName: 'clip_vision_unnorm_fp16.onnx',
    size: 608368672,
    sha256: '2657fc35a2c498ae79ac8cb245f4a10d08c614a035cb1c31a5e999cafe334a3e',
  );

  static const ModelSpec head = ModelSpec(
    fileName: 'head.onnx',
    size: 107139382,
    sha256: '3ed768dc795a8d03b3d796a6310980075df386e587a74bf5539ba2e75e2da0b7',
  );

  static const List<ModelSpec> all = [vision, head];

  static const String visionInput = 'pixel_values';
  static const String visionOutput = '/visual_projection/MatMul_output_0';
  static const String headInput = 'image_features';
  static const String headCoords = 'topk_coords';
  static const String headProbs = 'topk_probs';

  static const int imageSize = 224;
  static const int topK = 20;

  static const List<double> clipMean = [0.48145466, 0.4578275, 0.40821073];
  static const List<double> clipStd = [0.26862954, 0.26130258, 0.27577711];
}
