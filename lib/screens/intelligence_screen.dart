// lib/screens/intelligence_screen.dart

import 'package:flutter/material.dart';

class IntelligenceScreen extends StatefulWidget {
  const IntelligenceScreen({super.key});

  @override
  State<IntelligenceScreen> createState() => _IntelligenceScreenState();
}

class _IntelligenceScreenState extends State<IntelligenceScreen> {
  String commsChannel = 'Command';
  String commsDraft = '';
  final TextEditingController commsController = TextEditingController();

  final List<CommsMessage> commsMessages = [
    CommsMessage(channel: 'Command', sender: 'Ops', message: 'Stand by for plume update', time: '00:01:02'),
    CommsMessage(channel: 'Medical', sender: 'Med-Lead', message: 'Triage team ready', time: '00:02:00'),
  ];

  final List<IncidentEvent> incidentEvents = [
    IncidentEvent(time: '00:00:12', message: 'Sensor trigger in Sector C-03'),
    IncidentEvent(time: '00:01:24', message: 'UAV-ALPHA-1 plume confirmation'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _grid(columns: 2, children: [
        _panel(title: 'DEFCON Level Control', child: Column(children: const [
          _ListRow(label: 'Current Level: DEFCON 3', badge: 'Round-the-clock watch'),
          _ListRow(label: 'Level Selector: DEFCON 1 - 5'),
        ])),
        _panel(title: 'Intelligence Sources', child: Column(children: const [
          _ListRow(label: 'Satellite KH-11 · Live feed'),
          _ListRow(label: 'Local Asset - 7 · Field report'),
          _ListRow(label: 'SIGINT Node-3 · Threat chatter'),
        ])),
      ]),
      const SizedBox(height: 16),
      _grid(columns: 2, children: [
        _panel(title: 'Target Identification', child: Column(children: const [
          _ListRow(label: 'Target: Bio Lab 14 · Classification: High Risk'),
          _ListRow(label: 'Target: Cargo Bay 3 · Classification: Medium'),
          _ListRow(label: 'Target: Water Plant · Classification: Low'),
        ])),
        _panel(title: 'Intel Timeline', child: Column(children: const [
          _ListRow(label: '12:01:22 · Satellite KH-11 detected movement'),
          _ListRow(label: '12:03:10 · UAV-ALPHA-1 confirmed CBRN plume'),
          _ListRow(label: '12:05:18 · Alert Level elevated to High'),
        ])),
      ]),
      const SizedBox(height: 16),
      _grid(columns: 2, children: [
        _panel(title: 'Comms Center', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButton<String>(
            value: commsChannel,
            dropdownColor: const Color(0xFF101915),
            items: const [
              DropdownMenuItem(value: 'Command', child: Text('Channel: Command')),
              DropdownMenuItem(value: 'Operations', child: Text('Channel: Operations')),
              DropdownMenuItem(value: 'Medical', child: Text('Channel: Medical')),
              DropdownMenuItem(value: 'Hazmat', child: Text('Channel: Hazmat')),
            ],
            onChanged: (value) => setState(() => commsChannel = value ?? 'Command'),
          ),
          const SizedBox(height: 8),
          TextField(controller: commsController, decoration: const InputDecoration(hintText: 'Type priority update...'), onChanged: (value) => commsDraft = value),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _sendCommsMessage, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C2A24)), child: const Text('Send Message')),
          const SizedBox(height: 10),
          ...commsMessages.where((msg) => msg.channel == commsChannel).take(6).map((msg) => _ListRow(label: '${msg.time} · ${msg.sender}: ${msg.message}')),
        ])),
        _panel(title: 'Incident Timeline & Export', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ...incidentEvents.map((e) => _ListRow(label: '${e.time} · ${e.message}')),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C2A24)), child: const Text('Export After-Action JSON')),
        ])),
      ]),
    ]);
  }

  void _sendCommsMessage() {
    if (commsDraft.trim().isEmpty) return;
    setState(() {
      commsMessages.insert(0, CommsMessage(channel: commsChannel, sender: 'Operator', message: commsDraft.trim(), time: _formatNow()));
      commsDraft = '';
    });
    commsController.clear();
  }

  String _formatNow() {
    final now = DateTime.now();
    return '${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
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

class _ListRow extends StatelessWidget { final String label; final String? badge; const _ListRow({required this.label, this.badge}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text(label)), if (badge != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF1C2A24), borderRadius: BorderRadius.circular(12)), child: Text(badge!, style: const TextStyle(fontSize: 11)))])); }
class CommsMessage { final String channel, sender, message, time; CommsMessage({required this.channel, required this.sender, required this.message, required this.time}); }
class IncidentEvent { final String time, message; IncidentEvent({required this.time, required this.message}); }
