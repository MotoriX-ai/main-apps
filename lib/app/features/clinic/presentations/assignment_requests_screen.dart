import 'package:flutter/material.dart';

import 'package:motorix_phase2/app/features/clinic/models/pipeline_models.dart';
import 'package:motorix_phase2/app/features/clinic/services/pipeline_client.dart';

class AssignmentRequestsScreen extends StatefulWidget {
  const AssignmentRequestsScreen({super.key});

  @override
  State<AssignmentRequestsScreen> createState() =>
      _AssignmentRequestsScreenState();
}

class _AssignmentRequestsScreenState extends State<AssignmentRequestsScreen> {
  final client = PipelineClient();
  List<AssignmentRequest>? items;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await client.getAssignmentRequests();
      if (mounted) setState(() => items = result);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    }
  }

  Future<void> _review(AssignmentRequest request, bool approve) async {
    try {
      await client.reviewAssignment(request.id, approve);
      await _load();
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    }
  }

  @override
  void dispose() {
    client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Permintaan Assignment')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red))
            else if (items == null)
              const Center(child: CircularProgressIndicator())
            else if (items!.isEmpty)
              const Text('Tidak ada permintaan pending.')
            else
              for (final request in items!)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(request.exercise,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        Text(request.patient),
                        if (request.note.isNotEmpty) Text(request.note),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _review(request, false),
                              child: const Text('Tolak'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _review(request, true),
                              child: const Text('Setujui'),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      );
}
