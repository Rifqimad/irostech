// lib/screens/analysis_screen.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<AssetHealth> assets = [
      AssetHealth(name: 'UAV-ALPHA-1', health: 'Nominal', nextService: '36 hrs'),
      AssetHealth(name: 'UGV-DELTA-2', health: 'Degraded', nextService: '12 hrs'),
      AssetHealth(name: 'UAV-BRAVO-1', health: 'Nominal', nextService: '48 hrs'),
    ];

    return Column(
      children: [
        _grid(
          columns: 4,
          children: [
            _panel(
              title: 'Mission Performance & Operational Metrics',
              child: _grid(
                columns: 2,
                children: const [
                  _Metric(label: 'Total Missions', value: '184'),
                  _Metric(label: 'Success Rate', value: '93%'),
                  _Metric(label: 'Avg Response Time', value: '4.6 min'),
                  _Metric(label: 'Total Distance', value: '8,240 km'),
                ],
              ),
            ),
            _panel(
              title: 'Mission Distribution',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Chip(text: 'Surveillance 44%'),
                      _Chip(text: 'Reconnaissance 26%'),
                      _Chip(text: 'Search & Rescue 18%'),
                      _Chip(text: 'Evacuation 12%'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DistributionBar(label: 'Surveillance', percent: 44, color: const Color(0xFF38FF9C)),
                  const SizedBox(height: 8),
                  _DistributionBar(label: 'Reconnaissance', percent: 26, color: const Color(0xFF00D4FF)),
                  const SizedBox(height: 8),
                  _DistributionBar(label: 'Search & Rescue', percent: 18, color: const Color(0xFFFFB020)),
                  const SizedBox(height: 8),
                  _DistributionBar(label: 'Evacuation', percent: 12, color: const Color(0xFFFF7A45)),
                ],
              ),
            ),
            _panel(
              title: 'Trend Analysis Charts',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _ListRow(label: 'CBRN Detection Trends'),
                  _ListRow(label: 'Alert Frequency Analysis'),
                  _ListRow(label: 'Robot Performance Metrics'),
                  SizedBox(height: 12),
                  Text(
                    'Line/area chart placeholders',
                    style: TextStyle(color: Color(0xFF7C8B85)),
                  ),
                ],
              ),
            ),
            _panel(
              title: 'Sensor Fusion Status',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Sensors: 5',
                    style: TextStyle(color: Color(0xFF7C8B85)),
                  ),
                  const SizedBox(height: 8),
                  const Text('Heatmap Overlay: Disabled'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2A24),
                    ),
                    child: const Text('Enable Heatmap'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _grid(
          columns: 2,
          children: [
            _panel(
              title: 'Alert Statistics',
              child: Column(
                children: const [
                  _SeverityRow(label: 'Critical', value: '12', severity: 'critical'),
                  _SeverityRow(label: 'High', value: '25', severity: 'high'),
                  _SeverityRow(label: 'Medium', value: '41', severity: 'medium'),
                  _SeverityRow(label: 'Low', value: '78', severity: 'low'),
                ],
              ),
            ),
            _panel(
              title: 'Asset Health & Maintenance',
              child: Column(
                children: assets
                    .map((asset) => _ListRow(
                          label: '${asset.name} · ${asset.health}',
                          badge: 'Service ${asset.nextService}',
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _grid({required int columns, required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int adjustedColumns = width < 800
            ? 1
            : width < 1200
                ? (columns > 2 ? 2 : columns)
                : columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children
              .map(
                (child) => SizedBox(
                  width: (width - (8 * (adjustedColumns - 1))) / adjustedColumns,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _panel({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101915),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C2A24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// Data Models
class AssetHealth {
  final String name;
  final String health;
  final String nextService;

  AssetHealth({
    required this.name,
    required this.health,
    required this.nextService,
  });
}

// Widget Components
class _Chip extends StatelessWidget {
  final String text;

  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2A24),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFFE6F4EE),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7C8B85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SeverityRow extends StatelessWidget {
  final String label;
  final String value;
  final String severity;

  const _SeverityRow({
    required this.label,
    required this.value,
    required this.severity,
  });

  Color _color() {
    switch (severity) {
      case 'critical':
        return const Color(0xFFFF4D4F);
      case 'high':
        return const Color(0xFFFF7A45);
      case 'medium':
        return const Color(0xFFFFB020);
      default:
        return const Color(0xFF2F80ED);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _color(),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  final String label;
  final String? badge;

  const _ListRow({required this.label, this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2A24),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge!,
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _DistributionBar extends StatelessWidget {
  final String label;
  final int percent;
  final Color color;

  const _DistributionBar({
    required this.label,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFFE6F4EE)),
            ),
            Text(
              '$percent%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent / 100,
            backgroundColor: const Color(0xFF1C2A24),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
