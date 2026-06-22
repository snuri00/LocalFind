class ModelSpec {
  final String fileName;
  final int size;
  final String sha256;
  const ModelSpec({required this.fileName, required this.size, required this.sha256});

  String url(String base) => '$base/$fileName';
}

class AppConfig {
  static const String hfRepoBase =
      'https://huggingface.co/ekremabiii/localfind-potsdam-onnx/resolve/main';

  static const ModelSpec vision = ModelSpec(
    fileName: 'streetclip_vision_fp16.onnx',
    size: 609361438,
    sha256: 'e693776f48b30a5d813964c3f77ee2f3b2f0dfb23702a5db53ea9f99c6a5d21c',
  );

  static const ModelSpec head = ModelSpec(
    fileName: 'potsdam_head.onnx',
    size: 69794743,
    sha256: 'dd7418ff8080c74e2910a5eb9fa60a75c8c7af657cd31964a7b765c9b451b7c4',
  );

  static const List<ModelSpec> all = [vision, head];

  static const String visionInput = 'pixel_values';
  static const String visionOutput = 'image_features';
  static const String headInput = 'image_features';
  static const String headCoords = 'topk_coords';
  static const String headProbs = 'topk_probs';

  static const int imageSize = 336;
  static const int topK = 20;

  static const List<double> clipMean = [0.48145466, 0.4578275, 0.40821073];
  static const List<double> clipStd = [0.26862954, 0.26130258, 0.27577711];
}
