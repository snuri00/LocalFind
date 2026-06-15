import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

import 'app_config.dart';
import 'confidence.dart';
import 'model_repository.dart';

class GeolocatorEngine {
  final ModelRepository _repo;
  final OnnxRuntime _ort = OnnxRuntime();
  OrtSession? _vision;
  OrtSession? _head;
  List<OrtProvider> _providers = const [OrtProvider.CPU];

  GeolocatorEngine(this._repo);

  List<OrtProvider> get activeProviders => _providers;

  Future<void> load() async {
    if (_vision != null && _head != null) return;
    final available = await _ort.getAvailableProviders();
    _providers = _pickProviders(available);
    final options = OrtSessionOptions(providers: _providers);

    final visionFile = await _repo.fileFor(AppConfig.vision);
    final headFile = await _repo.fileFor(AppConfig.head);
    _vision = await _ort.createSession(visionFile.path, options: options);
    _head = await _ort.createSession(headFile.path, options: options);
  }

  List<OrtProvider> _pickProviders(List<OrtProvider> available) {
    if (Platform.isIOS && available.contains(OrtProvider.CORE_ML)) {
      return [OrtProvider.CORE_ML, OrtProvider.CPU];
    }
    if (Platform.isAndroid && available.contains(OrtProvider.NNAPI)) {
      return [OrtProvider.NNAPI, OrtProvider.XNNPACK, OrtProvider.CPU];
    }
    if (available.contains(OrtProvider.XNNPACK)) {
      return [OrtProvider.XNNPACK, OrtProvider.CPU];
    }
    return [OrtProvider.CPU];
  }

  Future<GeoEstimate> locate(Uint8List imageBytes) async {
    await load();
    final pixels = _preprocess(imageBytes);

    final input = await OrtValue.fromList(
      pixels,
      [1, 3, AppConfig.imageSize, AppConfig.imageSize],
    );

    Map<String, OrtValue>? visionOut;
    Map<String, OrtValue>? headOut;
    try {
      visionOut = await _vision!.run({AppConfig.visionInput: input});
      final feature = visionOut[AppConfig.visionOutput]!;
      headOut = await _head!.run({AppConfig.headInput: feature});

      final coordsRaw = await headOut[AppConfig.headCoords]!.asFlattenedList();
      final probsRaw = await headOut[AppConfig.headProbs]!.asFlattenedList();

      final coords = <LatLng>[];
      for (var i = 0; i < AppConfig.topK; i++) {
        coords.add(LatLng(
          (coordsRaw[i * 2] as num).toDouble(),
          (coordsRaw[i * 2 + 1] as num).toDouble(),
        ));
      }
      final probs = probsRaw.map((e) => (e as num).toDouble()).toList();
      return buildEstimate(coords, probs);
    } finally {
      await input.dispose();
      if (visionOut != null) {
        for (final v in visionOut.values) {
          await v.dispose();
        }
      }
      if (headOut != null) {
        for (final v in headOut.values) {
          await v.dispose();
        }
      }
    }
  }

  Float32List _preprocess(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not decode image');
    }
    const size = AppConfig.imageSize;
    final scale = size / (decoded.width < decoded.height ? decoded.width : decoded.height);
    final resized = img.copyResize(
      decoded,
      width: (decoded.width * scale).round(),
      height: (decoded.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
    final offsetX = ((resized.width - size) / 2).round();
    final offsetY = ((resized.height - size) / 2).round();
    final crop = img.copyCrop(resized, x: offsetX, y: offsetY, width: size, height: size);

    final out = Float32List(3 * size * size);
    final mean = AppConfig.clipMean;
    final std = AppConfig.clipStd;
    final plane = size * size;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final p = crop.getPixel(x, y);
        final idx = y * size + x;
        out[idx] = (p.rNormalized - mean[0]) / std[0];
        out[plane + idx] = (p.gNormalized - mean[1]) / std[1];
        out[2 * plane + idx] = (p.bNormalized - mean[2]) / std[2];
      }
    }
    return out;
  }

  Future<void> dispose() async {
    await _vision?.close();
    await _head?.close();
    _vision = null;
    _head = null;
  }
}
