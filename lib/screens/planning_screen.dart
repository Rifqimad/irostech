// lib/screens/planning_screen.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  int selectedMissionIndex = 0;
  bool showRoutes = false;
  bool geofenceSetMode = false;

  final List<MissionTask> missionTasks = [
    MissionTask(
      name: 'Recon Route A',
      priority: 'High',
      waypoints: const [
        LatLng(51.505, -0.09),
        LatLng(51.507, -0.094),
        LatLng(51.509, -0.096),
      ],
    ),
    MissionTask(
      name: 'Supply Corridor B',
      priority: 'Medium',
      waypoints: const [
        LatLng(51.502, -0.088),
        LatLng(51.504, -0.091),
        LatLng(51.506, -0.093),
      ],
    ),
  ];

  final List<GeofenceZone> geofences = [
    GeofenceZone(
      name: 'Perimeter A',
      center: const LatLng(51.506, -0.092),
      radiusKm: 0.6,
    ),
  ];

  final List<SopItem> sopChecklist = [
    SopItem(id: 1, label: 'Confirm hot zone perimeter'),
    SopItem(id: 2, label: 'Deploy decon corridor'),
    SopItem(id: 3, label: 'Establish medical triage'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _grid(
          columns: 3,
          children: [
            _panel(
              title: 'Mission Tasking & Route Optimization',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButton<int>(
                    value: selectedMissionIndex,
                    dropdownColor: const Color(0xFF101915),
                    items: missionTasks
                        .asMap()
                        .entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text('${entry.value.name} · ${entry.value.priority}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => selectedMissionIndex = value ?? 0),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() => showRoutes = !showRoutes),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2A24),
                    ),
                    child: Text(showRoutes ? 'Hide Route' : 'Show Route'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Waypoints: ${missionTasks[selectedMissionIndex].waypoints.length}',
                    style: const TextStyle(color: Color(0xFF7C8B85)),
                  ),
                ],
              ),
            ),
            _panel(
              title: 'Mission Templates',
              child: Column(
                children: const [
                  _ListRow(label: 'Surveillance · 3 UAV + 2 UGV · Risk: Medium'),
                  _ListRow(label: 'Extraction · 2 UGV + Support · Risk: High'),
                  _ListRow(label: 'Reconnaissance · 2 UAV · Risk: Low'),
                  _ListRow(label: 'Hazmat Containment · 1 UGV · Risk: High'),
                ],
              ),
            ),
            _panel(
              title: 'Planner & Waypoints',
              child: Column(
                children: const [
                  _ListRow(label: 'WP-1 · Entry Corridor'),
                  _ListRow(label: 'WP-2 · Sample Extraction'),
                  _ListRow(label: 'WP-3 · Decon Zone'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _grid(
          columns: 3,
          children: [
            _panel(
              title: 'Mission Playbooks',
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: const [
                  _Chip(text: 'Evacuation'),
                  _Chip(text: 'Decontamination'),
                  _Chip(text: 'Triage'),
                  _Chip(text: 'Perimeter Lockdown'),
                ],
              ),
            ),
            _panel(
              title: 'Playbook Checklist',
              child: Column(
                children: const [
                  _ListRow(label: 'Confirm evacuation corridor'),
                  _ListRow(label: 'Deploy decon units'),
                  _ListRow(label: 'Seal HVAC intakes'),
                ],
              ),
            ),
            _panel(
              title: 'Rules of Engagement',
              child: Column(
                children: const [
                  _ListRow(label: 'Non-lethal priority'),
                  _ListRow(label: 'Civilian corridor protection'),
                  _ListRow(label: 'Escalation authorized by Commander'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _grid(
          columns: 3,
          children: [
            _panel(
              title: 'Routes (Mission Queue)',
              child: Column(
                children: const [
                  _ListRow(label: 'Queue #1 · Recon Route A'),
                  _ListRow(label: 'Queue #2 · Supply Corridor B'),
                ],
              ),
            ),
            _panel(
              title: 'Resource Staging',
              child: Column(
                children: const [
                  _ListRow(label: 'UGV Support: Ready'),
                  _ListRow(label: 'Hazmat Kits: 12 available'),
                ],
              ),
            ),
            _panel(
              title: 'Geofence Management',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Geofences: ${geofences.length}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() => geofenceSetMode = !geofenceSetMode),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2A24),
                    ),
                    child: Text(geofenceSetMode ? 'Click Map to Add' : 'Add Geofence'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _panel(
          title: 'SOP Checklist & Acknowledgments',
          child: Column(
            children: sopChecklist
                .map(
                  (item) => Row(
                    children: [
                      Expanded(child: Text(item.label)),
                      if (item.acknowledged)
                        Text(
                          item.ackTime ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF7C8B85),
                          ),
                        )
                      else
                        TextButton(
                          onPressed: () {},
                          child: const Text('Acknowledge'),
                        ),
                    ],
                  ),
                )
                .toList(),
          ),
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
class MissionTask {
  final String name;
  final String priority;
  final List<LatLng> waypoints;

  MissionTask({
    required this.name,
    required this.priority,
    required this.waypoints,
  });
}

class GeofenceZone {
  final String name;
  final LatLng center;
  final double radiusKm;

  GeofenceZone({
    required this.name,
    required this.center,
    required this.radiusKm,
  });
}

class SopItem {
  final int id;
  final String label;
  final String? ackTime;
  final bool acknowledged;

  SopItem({
    required this.id,
    required this.label,
    this.ackTime,
    this.acknowledged = false,
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

class _ListRow extends StatelessWidget {
  final String label;

  const _ListRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
