import 'package:flutter/material.dart';

import 'package:motorix_phase2/app/core/localization.dart';
import 'package:motorix_phase2/app/features/clinic/services/pipeline_client.dart';

class ClinicAdminScreen extends StatefulWidget {
  const ClinicAdminScreen({super.key});
  @override
  State<ClinicAdminScreen> createState() => _ClinicAdminScreenState();
}

class _ClinicAdminScreenState extends State<ClinicAdminScreen> {
  final client = PipelineClient();
  final email = TextEditingController();
  final userId = TextEditingController();
  final invitationId = TextEditingController();
  final patientId = TextEditingController();
  final clinicianId = TextEditingController();
  String role = 'physiotherapist';
  String? message;
  bool busy = false;
  Map<String, dynamic>? overview;

  String _text(String id, String en) => motorixText(context, id: id, en: en);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await client.getAdminOverview();
      if (mounted) setState(() => overview = value);
    } catch (exception) {
      if (mounted) setState(() => message = exception.toString());
    }
  }

  Future<void> _invite() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final invitation = await client.inviteClinician(email.text, role: role);
      setState(() {
        message =
            '${_text('Invitation email dikirim', 'Invitation email sent')}: ${invitation['id']}';
        invitationId.text = invitation['id']?.toString() ?? '';
      });
    } catch (exception) {
      setState(() => message = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _careTeam(bool assigned) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await client.manageCareTeam(
        patientId: patientId.text.trim(),
        clinicianId: clinicianId.text.trim(),
        assigned: assigned,
      );
      if (mounted) {
        setState(() => message = assigned
            ? _text('Care team ditambahkan.', 'Care team member added.')
            : _text('Care team dihapus.', 'Care team member removed.'));
      }
      await _load();
    } catch (exception) {
      if (mounted) setState(() => message = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _setStatus(String id, String status) async {
    try {
      await client.setAccountStatus(id, status);
      await _load();
    } catch (exception) {
      if (mounted) setState(() => message = exception.toString());
    }
  }

  Future<void> _approve() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await client.approveClinician(
          userId: userId.text.trim(), invitationId: invitationId.text.trim());
      setState(() => message = _text(
          'Klinisi diverifikasi. Aktivitas tercatat dalam audit klinik.',
          'Clinician verified. The action was recorded in the clinic audit.'));
    } catch (exception) {
      setState(() => message = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    client.dispose();
    email.dispose();
    userId.dispose();
    invitationId.dispose();
    patientId.dispose();
    clinicianId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(_text('Administrasi klinik', 'Clinic administration'))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(_text('Invitation klinisi', 'Clinician invitation'),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                  labelText: _text('Email klinisi', 'Clinician email'))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: InputDecoration(labelText: _text('Peran', 'Role')),
            items: [
              DropdownMenuItem(
                  value: 'physiotherapist',
                  child: Text(_text('Fisioterapis', 'Physiotherapist'))),
              DropdownMenuItem(
                  value: 'clinic_admin',
                  child: Text(
                      _text('Administrator klinik', 'Clinic administrator'))),
            ],
            onChanged: (value) => setState(() => role = value ?? role),
          ),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: busy ? null : _invite,
              child: Text(_text('Buat invitation', 'Create invitation'))),
          const Divider(height: 40),
          Text(_text('Verifikasi akun invitation', 'Verify invited account'),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(
              controller: invitationId,
              decoration: InputDecoration(
                  labelText: _text('Invitation ID', 'Invitation ID'))),
          const SizedBox(height: 12),
          TextField(
              controller: userId,
              decoration: InputDecoration(
                  labelText: _text('User ID dari akun yang menerima invitation',
                      'User ID of the invited account'))),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: busy ? null : _approve,
              child: Text(_text('Verifikasi klinisi', 'Verify clinician'))),
          const Divider(height: 40),
          const Text('Care team',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(
              controller: patientId,
              decoration: const InputDecoration(labelText: 'Patient ID')),
          const SizedBox(height: 12),
          TextField(
              controller: clinicianId,
              decoration: const InputDecoration(labelText: 'Clinician ID')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: FilledButton(
                    onPressed: busy ? null : () => _careTeam(true),
                    child: Text(_text('Tambahkan', 'Add')))),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton(
                    onPressed: busy ? null : () => _careTeam(false),
                    child: Text(_text('Hapus', 'Remove')))),
          ]),
          const Divider(height: 40),
          Text(_text('Akun klinik', 'Clinic accounts'),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          for (final profile in (overview?['profiles'] as List? ?? const []))
            ListTile(
              title: Text((profile as Map)['display_name']?.toString() ?? ''),
              subtitle: Text(
                  '${profile['role']} · ${profile['account_status']}\n${profile['id']}'),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (status) =>
                    _setStatus(profile['id'].toString(), status),
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'active',
                      child: Text(_text('Aktifkan', 'Activate'))),
                  PopupMenuItem(
                      value: 'pending',
                      child: Text(_text('Jadikan pending', 'Set pending'))),
                  PopupMenuItem(
                      value: 'suspended',
                      child: Text(_text('Tangguhkan', 'Suspend'))),
                ],
              ),
            ),
          const Divider(height: 40),
          Text(
              _text('Consent & audit immutable', 'Immutable consent and audit'),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(
              '${(overview?['consents'] as List? ?? const []).length} ${_text('catatan consent', 'consent records')}'),
          const SizedBox(height: 8),
          for (final event
              in (overview?['audit_events'] as List? ?? const []).take(25))
            ListTile(
              dense: true,
              title: Text((event as Map)['action']?.toString() ?? ''),
              subtitle:
                  Text('${event['created_at']} · ${event['resource_type']}'),
            ),
          if (message != null) ...[const SizedBox(height: 14), Text(message!)],
        ]),
      );
}
