import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/message_service_provider.dart';
import '../contacts/contacts_provider.dart';
import 'integrity_report.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  IntegrityReport? _report;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    final db = ref.read(appDatabaseProvider);
    final r = await computeIntegrityReport(db);
    if (mounted) {
      setState(() {
        _report = r;
        _busy = false;
      });
    }
  }

  Future<void> _reKick() async {
    final r = _report;
    if (r == null || r.stuckPeers.isEmpty) return;
    setState(() => _busy = true);
    final ms = await ref.read(messageServiceProvider.future);
    for (final pk in r.stuckPeers) {
      await ms.flushPeerOnReachable(pk);
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: _busy && r == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  title: const Text('Stuck outbox'),
                  subtitle: const Text(
                    'Pending > 24h — would-be-lost messages',
                  ),
                  trailing: Text('${r?.stuckOutbox ?? '-'}'),
                ),
                ListTile(
                  title: const Text('Orphaned sent'),
                  subtitle: const Text(
                    'Sent but unconfirmed (no receipt, no retry)',
                  ),
                  trailing: Text('${r?.orphanedSent ?? '-'}'),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: ((r?.stuckPeers.isEmpty ?? true) || _busy)
                        ? null
                        : _reKick,
                    child: Text(_busy ? 'Working…' : 'Re-kick stuck outbox'),
                  ),
                ),
                if (r != null && r.isClean)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('All records accounted for.'),
                  ),
              ],
            ),
    );
  }
}
