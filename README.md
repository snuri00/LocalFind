# LocalFind

**On-device photo geolocation. Your photo never leaves your phone.**

LocalFind estimates where a photo was taken — fully on-device. The image is never uploaded; all inference runs locally on the phone's GPU via ONNX Runtime. Privacy is the whole point.

<p align="center"><em>Pick a photo → get an approximate location, a confidence indicator, and a place name on the map.</em></p>

---

## How it works

LocalFind is an on-device port of [GeoCLIP](https://github.com/VicenteVivan/geo-clip), split into two ONNX stages so the heavy gallery match stays inside the graph:

```
photo
  → CLIP preprocess (224×224)
  → [vision encoder]  CLIP ViT-L/14, fp16   → 768-d image features
  → [head]            MLP 768→512 → L2-normalize
                      → match against 100k precomputed GPS-gallery embeddings
                      → top-k coordinates + scores
  → cluster-based confidence (haversine spread of the top-k)
  → reverse geocode (Photon / OpenStreetMap) → place name
  → show on map
```

- **Vision encoder** is `openai/clip-vit-large-patch14`, exported to a vision-only, un-normalized ONNX graph (a drop-in for the GeoCLIP MLP head).
- **Head** bakes in the precomputed 100k GPS-gallery location embeddings (fp16) and their coordinates, so a single graph returns the top-k coordinates directly.
- Both models are **downloaded once at first launch** (~715 MB) from Hugging Face — they are *not* bundled, keeping the app binary small.

Models: **[ekremabiii/localfind-geoclip-onnx](https://huggingface.co/ekremabiii/localfind-geoclip-onnx)**

## Privacy

- The photo is processed entirely on-device. It is never sent to any server.
- The only network calls are: the one-time model download (Hugging Face), map tiles (OpenStreetMap), and an optional reverse-geocode of the *resulting coordinate* (not the photo) to show a place name. These can be disabled without affecting geolocation.

## Tech stack

- **Flutter** (UI, cross-platform)
- **[flutter_onnxruntime](https://pub.dev/packages/flutter_onnxruntime)** — ONNX Runtime with hardware execution providers:
  - iOS: **CoreML** (GPU / Neural Engine)
  - Android: **NNAPI** → **XNNPACK** → CPU fallback
- **flutter_map** + OpenStreetMap tiles, **image** (preprocessing), **dio** (download), **crypto** (checksum verify)

## Build & run

Requires the Flutter SDK and a device/emulator.

```bash
flutter pub get
flutter run
```

On first launch the app downloads the models (Wi-Fi recommended) and verifies them by SHA-256 before use.

### Platform notes
- **iOS:** minimum iOS 16, static linkage (handled in the Podfile by `flutter_onnxruntime`). Camera & photo-library usage descriptions are set in `Info.plist`.
- **Android:** `INTERNET` permission for the model download; `proguard-rules.pro` keeps `ai.onnxruntime.**`.

## Project structure

```
lib/
  main.dart                     UI: download gate, picker, map, result panel
  src/
    app_config.dart             model specs, I/O names, preprocessing constants
    model_repository.dart       download + SHA-256 verify + local cache
    geolocator_engine.dart      preprocess + two-stage ONNX inference
    confidence.dart             haversine + cluster-based confidence
    reverse_geocode.dart        Photon (OSM) coordinate → place name
```

## Accuracy & limitations

- On well-photographed landmarks the top-1 estimate is typically within ~50 m–1 km of ground truth.
- Accuracy is bounded by the **encoder**, not the gallery: GeoCLIP can place familiar scenes precisely but is uncertain on visually ambiguous or under-represented locations (expect tens to hundreds of km in those cases).
- The confidence indicator (tight cluster → *very high / high*; diffuse → *medium / low*) is the signal to trust — raw softmax probabilities are misleading over a large gallery.

## Credits

Built on [GeoCLIP](https://github.com/VicenteVivan/geo-clip) (MIT) and OpenAI [CLIP](https://github.com/openai/CLIP). Map data © OpenStreetMap contributors. Reverse geocoding by [Photon](https://photon.komoot.io/).

## License

MIT
