import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'src/confidence.dart';
import 'src/geolocator_engine.dart';
import 'src/model_repository.dart';
import 'src/reverse_geocode.dart';

const int kCandidateCount = 5;

void main() {
  runApp(const LocalFindApp());
}

class LocalFindApp extends StatelessWidget {
  const LocalFindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LocalFind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B6CF2)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ModelRepository _repo = ModelRepository();
  late final GeolocatorEngine _engine = GeolocatorEngine(_repo);
  final ReverseGeocoder _geocoder = ReverseGeocoder();
  final ImagePicker _picker = ImagePicker();
  final MapController _map = MapController();

  bool _checking = true;
  bool _ready = false;
  bool _downloading = false;
  DownloadProgress? _progress;
  String? _error;

  bool _busy = false;
  Uint8List? _imageBytes;
  GeoEstimate? _estimate;

  int _selected = 0;
  final Map<int, String?> _placeNames = {};

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ready = await _repo.allReady();
    if (!mounted) return;
    setState(() {
      _ready = ready;
      _checking = false;
    });
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      await _repo.ensureModels((p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() {
        _ready = true;
        _downloading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _downloading = false;
      });
    }
  }

  List<LatLng> get _candidates {
    final est = _estimate;
    if (est == null) return const [];
    final n = est.candidates.length < kCandidateCount
        ? est.candidates.length
        : kCandidateCount;
    return est.candidates.sublist(0, n);
  }

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _estimate = null;
      _placeNames.clear();
      _selected = 0;
      _busy = true;
      _error = null;
    });
    try {
      final est = await _engine.locate(bytes);
      if (!mounted) return;
      setState(() => _estimate = est);
      _selectCandidate(0, animate: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectCandidate(int index, {bool animate = false}) {
    final cands = _candidates;
    if (index < 0 || index >= cands.length) return;
    setState(() => _selected = index);
    if (animate) _map.move(cands[index], 16);
    _ensurePlaceName(index);
  }

  Future<void> _ensurePlaceName(int index) async {
    if (_placeNames.containsKey(index)) return;
    _placeNames[index] = null;
    final name = await _geocoder.describe(_candidates[index]);
    if (!mounted) return;
    setState(() => _placeNames[index] = name);
  }

  Future<void> _openStreetView(LatLng c) async {
    final pano = Uri.parse(
        'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=${c.latitude},${c.longitude}');
    if (await launchUrl(pano, mode: LaunchMode.externalApplication)) return;
    final search = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${c.latitude},${c.longitude}');
    await launchUrl(search, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LocalFind'),
        actions: [
          if (_ready)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: Text('on-device', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : _ready
              ? _buildMain()
              : _buildDownload(),
    );
  }

  Widget _buildDownload() {
    final p = _progress;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.travel_explore, size: 72),
          const SizedBox(height: 16),
          const Text(
            'Your photo never leaves your phone.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'LocalFind needs to download the on-device model once (~715 MB). '
            'Wi-Fi recommended.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_downloading && p != null) ...[
            LinearProgressIndicator(value: p.fraction),
            const SizedBox(height: 8),
            Text(
              '${p.fileName}  (${p.fileIndex + 1}/${p.fileCount})  '
              '${_mb(p.received)} / ${_mb(p.total)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ] else
            FilledButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download),
              label: const Text('Download model'),
            ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }

  Widget _buildMain() {
    final est = _estimate;
    final cands = _candidates;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: const MapOptions(
                  initialCenter: LatLng(20, 0),
                  initialZoom: 1.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.localfind.localfind',
                  ),
                  if (est != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: est.primary,
                          radius: est.radiusKm * 1000,
                          useRadiusInMeter: true,
                          color: const Color(0x221B6CF2),
                          borderColor: const Color(0x551B6CF2),
                          borderStrokeWidth: 1,
                        ),
                      ],
                    ),
                  if (cands.isNotEmpty)
                    MarkerLayer(
                      markers: [
                        for (var i = 0; i < cands.length; i++)
                          Marker(
                            point: cands[i],
                            width: 34,
                            height: 34,
                            child: GestureDetector(
                              onTap: () => _selectCandidate(i, animate: true),
                              child: _candidatePin(i + 1, i == _selected),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              if (_busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
        _buildResultPanel(est),
      ],
    );
  }

  Widget _candidatePin(int rank, bool active) {
    return Container(
      decoration: BoxDecoration(
        color: active ? const Color(0xFF1B6CF2) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
            color: active ? Colors.white : const Color(0xFF1B6CF2), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: TextStyle(
          color: active ? Colors.white : const Color(0xFF1B6CF2),
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildResultPanel(GeoEstimate? est) {
    final cands = _candidates;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (est != null && cands.isNotEmpty) ...[
              Row(
                children: [
                  if (_imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_imageBytes!,
                          width: 44, height: 44, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                  ],
                  _confidenceChip(est.level),
                  const Spacer(),
                  Text('~${est.radiusKm.toStringAsFixed(1)} km',
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 12),
              _candidateSelector(),
              const SizedBox(height: 10),
              _selectedDetail(est),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => _openStreetView(cands[_selected]),
                  icon: const Icon(Icons.streetview),
                  label: const Text('Verify in Street View'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _candidateSelector() {
    final est = _estimate!;
    final cands = _candidates;
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const Text('Candidates',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(width: 10),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cands.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final active = i == _selected;
                final pct = (est.probs[i] * 100).toStringAsFixed(0);
                return ChoiceChip(
                  selected: active,
                  onSelected: (_) => _selectCandidate(i, animate: true),
                  label: Text('${i + 1} · $pct%'),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedDetail(GeoEstimate est) {
    final c = _candidates[_selected];
    final place = _placeNames[_selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, size: 18, color: Color(0xFF1B6CF2)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${c.latitude.toStringAsFixed(5)}, ${c.longitude.toStringAsFixed(5)}',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            Text('#${_selected + 1} of ${_candidates.length}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        if (place != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(place, style: const TextStyle(color: Colors.black87)),
          ),
        ] else if (_placeNames.containsKey(_selected)) ...[
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 24),
            child: Text('Looking up place…',
                style: TextStyle(color: Colors.black38, fontSize: 12)),
          ),
        ],
      ],
    );
  }

  Widget _confidenceChip(ConfidenceLevel level) {
    Color c;
    switch (level) {
      case ConfidenceLevel.veryHigh:
        c = Colors.green;
        break;
      case ConfidenceLevel.high:
        c = Colors.lightGreen;
        break;
      case ConfidenceLevel.medium:
        c = Colors.orange;
        break;
      case ConfidenceLevel.low:
        c = Colors.red;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c),
      ),
      child: Text(level == ConfidenceLevel.veryHigh
          ? 'Very high'
          : level == ConfidenceLevel.high
              ? 'High'
              : level == ConfidenceLevel.medium
                  ? 'Medium'
                  : 'Low',
          style: TextStyle(color: c, fontWeight: FontWeight.w600)),
    );
  }

  String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(0)} MB';

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }
}
