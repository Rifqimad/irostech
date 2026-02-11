// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String role = 'commander';
  bool offlineMode = false;
  int syncQueue = 0;

  final List<AuditEntry> auditLog = [
    AuditEntry(time: '00:01:02', action: 'App started', actor: 'system'),
  ];

  @override
  Widget build(BuildContext context) {
    return _grid(columns: 2, children: [
      _panel(title: 'System Configuration', child: Column(children: const [
        _ListRow(label: 'Telemetry Refresh · 5s'),
        _ListRow(label: 'Map Cache · Enabled'),
      ])),
      _panel(title: 'User Preferences', child: Column(children: const [
        _ListRow(label: 'Theme · Tactical Dark'),
        _ListRow(label: 'Notifications · Enabled'),
      ])),
      _panel(title: 'Role Permissions', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Active Role: $role'),
        const SizedBox(height: 8),
        Text('Clear Zones: ${role == 'commander' ? 'Allowed' : 'Restricted'}'),
        const SizedBox(height: 4),
        Text('Export Data: ${role == 'commander' || role == 'analyst' ? 'Allowed' : 'Restricted'}'),
      ])),
      _panel(title: 'Offline / Edge Sync', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Expanded(child: Text('Offline Mode')), Switch(value: offlineMode, onChanged: (value) => setState(() => offlineMode = value))]),
        Text('Queue: $syncQueue event(s)'),
      ])),
      _panel(title: 'Audit Log', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: auditLog.take(6).map((entry) => _ListRow(label: '${entry.time} · ${entry.actor} · ${entry.action}')).toList())),
    ]);
  }

  Widget _grid({required int columns, required List<Widget> children}) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final int adjustedColumns = width < 800 ? 1 : width < 1200 ? (columns > 2 ? 2 : columns) : columns;
      return Wrap(spacing: 16, runSpacing: 16, children: children.map((child) => SizedBox(width: (width - (16 * (adjustedColumns - 1))) / adjustedColumns, child: child)).toList());
    });
  }

  Widget _panel({required String title, required Widget child}) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF101915), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1C2A24))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 10), child]));
  }
}

class _ListRow extends StatelessWidget { final String label; const _ListRow({required this.label}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text(label))])); }
class AuditEntry { final String time, action, actor; AuditEntry({required this.time, required this.action, required this.actor}); }
