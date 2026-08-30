import 'package:flutter/material.dart';

import 'package:motorix_phase2/app/core/api_config.dart';
import 'package:motorix_phase2/app/features/clinic/models/pipeline_models.dart';
import 'package:motorix_phase2/app/features/clinic/services/pipeline_client.dart';

class ServerSelectorSheet extends StatefulWidget {
  const ServerSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ServerSelectorSheet(),
    );
  }

  @override
  State<ServerSelectorSheet> createState() => _ServerSelectorSheetState();
}

class _ServerSelectorSheetState extends State<ServerSelectorSheet> {
  late final TextEditingController _customUrlController;
  late String _selectedUrl;
  bool _isTesting = false;
  HealthStatus? _healthResult;
  String? _testError;

  @override
  void initState() {
    super.initState();
    _selectedUrl = ApiConfig.instance.baseUrl;
    _customUrlController = TextEditingController(text: _selectedUrl);
    _testConnection(_selectedUrl);
  }

  @override
  void dispose() {
    _customUrlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection(String url) async {
    setState(() {
      _isTesting = true;
      _testError = null;
      _healthResult = null;
    });

    final testClient = PipelineClient(baseUrlOverride: url);
    try {
      final details = await testClient.getHealthDetails();
      if (!mounted) return;
      setState(() {
        _healthResult = details;
        _isTesting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testError = e.toString().replaceFirst('StateError: ', '');
        _isTesting = false;
      });
    } finally {
      testClient.dispose();
    }
  }

  void _apply(String url) {
    ApiConfig.instance.setBaseUrl(url);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Endpoint API diubah ke: ${ApiConfig.instance.baseUrl}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xfffffdf8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xffdcd8ce),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xffd9f2df),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cloud_sync_outlined,
                      color: Color(0xff176b4b), size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pengaturan Server API',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff16221d))),
                      Text('Hubungkan runtime ke pipeline backend',
                          style: TextStyle(
                              fontSize: 14, color: Color(0xff66736d))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('PILIH PRESET SERVER',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff176b4b),
                    letterSpacing: 1.5)),
            const SizedBox(height: 10),
            for (final preset in ApiConfig.presets) ...[
              _PresetTile(
                preset: preset,
                isSelected: _selectedUrl == preset.url,
                onSelect: () {
                  setState(() {
                    _selectedUrl = preset.url;
                    _customUrlController.text = preset.url;
                  });
                  _testConnection(preset.url);
                },
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            const Text('URL KUSTOM / LAN IP',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff66736d),
                    letterSpacing: 1.2)),
            const SizedBox(height: 6),
            TextField(
              controller: _customUrlController,
              decoration: InputDecoration(
                hintText: 'https://...',
                filled: true,
                fillColor: const Color(0xfff6f4ee),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xffdcd8ce)),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xff176b4b)),
                  tooltip: 'Uji Koneksi',
                  onPressed: () {
                    final custom = _customUrlController.text.trim();
                    if (custom.isNotEmpty) {
                      setState(() => _selectedUrl = custom);
                      _testConnection(custom);
                    }
                  },
                ),
              ),
              onChanged: (val) {
                _selectedUrl = val.trim();
              },
            ),
            const SizedBox(height: 16),
            _HealthStatusCard(
              isTesting: _isTesting,
              health: _healthResult,
              error: _testError,
              testedUrl: _selectedUrl,
              onRetry: () => _testConnection(_selectedUrl),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => _apply(_selectedUrl),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff176b4b),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Gunakan Server Ini',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.isSelected,
    required this.onSelect,
  });

  final ApiServerPreset preset;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xffd9f2df) : const Color(0xfff6f4ee),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isSelected ? const Color(0xff176b4b) : const Color(0xffdcd8ce),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? const Color(0xff176b4b)
                  : const Color(0xff66736d),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(preset.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? const Color(0xff176b4b)
                              : const Color(0xff16221d))),
                  const SizedBox(height: 2),
                  Text(preset.description,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xff66736d))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthStatusCard extends StatelessWidget {
  const _HealthStatusCard({
    required this.isTesting,
    required this.health,
    required this.error,
    required this.testedUrl,
    required this.onRetry,
  });

  final bool isTesting;
  final HealthStatus? health;
  final String? error;
  final String testedUrl;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isTesting) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xfff6f4ee),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffdcd8ce)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 12),
            Text('Menguji koneksi server...',
                style: TextStyle(fontSize: 14, color: Color(0xff66736d))),
          ],
        ),
      );
    }

    final currentError = error;
    if (currentError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xfffdf2f2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xfff1aeb5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xffb02a37), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Koneksi Gagal',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xffb02a37))),
                ),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 24),
                  ),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(currentError,
                style: const TextStyle(fontSize: 12, color: Color(0xff842029))),
          ],
        ),
      );
    }

    final currentHealth = health;
    if (currentHealth != null) {
      final isOnline = currentHealth.ok || currentHealth.offlineReady;
      final poseHeavy =
          currentHealth.models['pose_heavy.task']?['available'] == true;
      final handModel = currentHealth.models['hand.task']?['available'] == true;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xffe8f5e9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffa5d6a7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOnline ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: const Color(0xff2e7d32),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isOnline ? 'Server Siap (Online)' : 'Server Aktif (Sebagian)',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: Color(0xff2e7d32)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _StatusPill(label: 'Pose AI', active: poseHeavy),
                _StatusPill(label: 'Hand AI', active: handModel),
                _StatusPill(
                    label: 'Media Tools (FFmpeg)',
                    active: currentHealth.mediaToolsReady),
                _StatusPill(
                    label: 'Notebook Engine', active: currentHealth.notebook),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? const Color(0xffc8e6c9) : const Color(0xffffecb3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: ${active ? "Siap" : "Tidak ada"}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: active ? const Color(0xff1b5e20) : const Color(0xfff57f17),
        ),
      ),
    );
  }
}
