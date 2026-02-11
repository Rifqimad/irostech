// lib/screens/evacuation_screen.dart

import 'package:flutter/material.dart';

class EvacuationScreen extends StatelessWidget {
  const EvacuationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _grid(columns: 4, children: [
        _panel(title: 'Evac Routes', compact: true, child: const _ListRow(label: 'Route Alpha · Clear')),
        _panel(title: 'Shelter Zones', compact: true, child: const _ListRow(label: 'Shelter B · 70% capacity')),
        _panel(title: 'Transport Assets', compact: true, child: const _ListRow(label: 'Vehicles · 12 ready')),
        _panel(title: 'Medical', compact: true, child: const _ListRow(label: 'Med Teams · 5 active')),
      ]),
      const SizedBox(height: 16),
      _grid(columns: 2, children: [
        _panel(title: 'Evacuation Timeline', child: const _ListRow(label: '00:10 · Zone A cleared')),
        _panel(title: 'Resource Summary', child: const _ListRow(label: 'Supplies · 4 convoys inbound')),
      ]),
    ]);
  }

  Widget _grid({required int columns, required List<Widget> children}) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final int adjustedColumns = width < 800 ? 1 : width < 1200 ? (columns > 2 ? 2 : columns) : columns;
      return Wrap(spacing: 16, runSpacing: 16, children: children.map((child) => SizedBox(width: (width - (16 * (adjustedColumns - 1))) / adjustedColumns, child: child)).toList());
    });
  }

  Widget _panel({required String title, required Widget child, bool compact = false}) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF101915), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1C2A24))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 10), compact ? DefaultTextStyle.merge(style: const TextStyle(fontSize: 12), child: child) : child]));
  }
}

class _ListRow extends StatelessWidget { final String label; const _ListRow({required this.label}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text(label))])); }
