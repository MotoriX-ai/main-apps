import 'package:flutter/material.dart';
import 'package:motorix_phase2/motorix_phase2.dart';
import 'package:video_player/video_player.dart';

import 'package:motorix_phase2/app/features/auth/presentations/auth_screen.dart';
import 'package:motorix_phase2/app/features/camera/presentations/session_screen.dart';
import 'package:motorix_phase2/app/features/clinic/models/pipeline_models.dart';
import 'package:motorix_phase2/app/features/clinic/services/pipeline_client.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, this.mine = false});

  final bool mine;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final client = PipelineClient();
  final search = TextEditingController();
  List<CatalogExercise>? items;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final result = widget.mine
          ? await client.getMyTemplates()
          : await client.getCatalog(query: search.text);
      if (mounted) setState(() => items = result);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    }
  }

  @override
  void dispose() {
    search.dispose();
    client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mine ? 'Gerakan Tersimpan' : 'Katalog Gerakan'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!widget.mine) ...[
              SearchBar(
                controller: search,
                hintText: 'Cari nama gerakan',
                leading: const Icon(Icons.search),
                onSubmitted: (_) => _load(),
                trailing: [
                  IconButton(
                      onPressed: _load, icon: const Icon(Icons.arrow_forward)),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Gerakan publik adalah panduan dari fisioterapis. Sesi latihan tetap memerlukan assignment klinis.',
              ),
              const SizedBox(height: 18),
            ],
            if (items == null && error == null)
              const Center(child: CircularProgressIndicator())
            else if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red))
            else if (items!.isEmpty)
              Text(widget.mine
                  ? 'Belum ada gerakan yang dipublikasikan.'
                  : 'Gerakan tidak ditemukan.')
            else
              for (final item in items!)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    title: Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      '${item.publisher} · ${item.focus} · ${item.side}\n${item.description}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          CatalogDetailScreen(item: item, mine: widget.mine),
                    )),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class CatalogDetailScreen extends StatefulWidget {
  const CatalogDetailScreen(
      {super.key, required this.item, required this.mine});

  final CatalogExercise item;
  final bool mine;

  @override
  State<CatalogDetailScreen> createState() => _CatalogDetailScreenState();
}

class _CatalogDetailScreenState extends State<CatalogDetailScreen> {
  final client = PipelineClient();
  VideoPlayerController? video;
  String? message;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.networkUrl(
      client.catalogGuideUri(widget.item.id),
    );
    video = controller;
    controller.initialize().then((_) {
      controller.setLooping(true);
      if (mounted) setState(() {});
    }).catchError((Object _) {});
  }

  Future<void> _request() async {
    if (!await requireMotorixLogin(context)) return;
    setState(() => busy = true);
    try {
      await client.requestAssignment(widget.item.id);
      setState(
          () => message = 'Permintaan dikirim ke fisioterapis care team Anda.');
    } catch (exception) {
      setState(() => message = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _startAssigned() async {
    if (!await requireMotorixLogin(context)) return;
    setState(() => busy = true);
    try {
      final raw = await client.getAssignedRecipe(widget.item.id);
      final recipe = ExerciseRecipe.fromJson(raw);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SessionScreen(recipe: recipe),
      ));
    } catch (exception) {
      if (mounted) setState(() => message = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    video?.dispose();
    client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = video?.value.isInitialized ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AspectRatio(
            aspectRatio: ready ? video!.value.aspectRatio : 16 / 9,
            child: ready
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      VideoPlayer(video!),
                      Center(
                        child: IconButton.filled(
                          onPressed: () => setState(() {
                            video!.value.isPlaying
                                ? video!.pause()
                                : video!.play();
                          }),
                          icon: Icon(video!.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow),
                        ),
                      ),
                    ],
                  )
                : const ColoredBox(
                    color: Colors.black12,
                    child:
                        Center(child: Icon(Icons.accessibility_new, size: 56)),
                  ),
          ),
          const SizedBox(height: 18),
          Text(widget.item.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
          Text('Oleh ${widget.item.publisher}'),
          const SizedBox(height: 12),
          Text(widget.item.description.isEmpty
              ? 'Preview gerakan fisioterapi Motorix.'
              : widget.item.description),
          const SizedBox(height: 22),
          if (!widget.mine) ...[
            FilledButton.icon(
              onPressed: busy ? null : _startAssigned,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Mulai jika sudah ditugaskan'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : _request,
              icon: const Icon(Icons.assignment_add),
              label: const Text('Minta assignment'),
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!),
          ],
        ],
      ),
    );
  }
}
