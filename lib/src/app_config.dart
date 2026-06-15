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
    size: 608704678,
    sha256: '9e90e18ead7d37c788a11eaf1520e9c7832824da9d296bcd98b413f7b9d234b2',
  );

  static const ModelSpec head = ModelSpec(
    fileName: 'head.onnx',
    size: 107139318,
    sha256: '2dc1488fd69ec4e1dd1c0191bc3f7dcc4513944117a12ec4c1200d731b6b107b',
  );

  static const List<ModelSpec> all = [vision, head];

  static const String visionInput = 'pixel_values';
  static const String visionOutput = 'image_features';
  static const String headInput = 'image_features';
  static const String headCoords = 'topk_coords';
  static const String headProbs = 'topk_probs';

  static const int imageSize = 224;
  static const int topK = 20;

  static const List<double> clipMean = [0.48145466, 0.4578275, 0.40821073];
  static const List<double> clipStd = [0.26862954, 0.26130258, 0.27577711];
}
