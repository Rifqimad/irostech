// lib/screens/analysis_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/firebase_service.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  
  // Data streams
  StreamSubscription<Map<String, dynamic>>? _droneSubscription;
  StreamSubscription<Map<String, dynamic>>? _zonesSubscription;
  StreamSubscription<Map<String, dynamic>>? _missionSubscription;
  
  // Data
  List<Map<String, dynamic>> _drones = [];
  List<Map<String, dynamic>> _hazardousZones = [];
  Map<String, dynamic> _missionStatus = {};
  
  // Statistics
  int _totalMissions = 0;
  int _successfulMissions = 0;
  double _avgResponseTime = 0.0;
  double _totalDistance = 0.0;
  
  // Mission tracking
  DateTime? _lastDetectionTime;
  List<double> _responseTimes = [];
  
  // Alert statistics
  int _criticalAlerts = 0;
  int _highAlerts = 0;
  int _mediumAlerts = 0;
  int _lowAlerts = 0;
  
  // Mission distribution
  int _surveillanceMissions = 0;
  int _reconnaissanceMissions = 0;
  int _searchRescueMissions = 0;
  int _evacuationMissions = 0;
  
  // Asset health
  List<AssetHealth> _assets = [];
  
  // Sensor status
  bool _heatmapEnabled = false;
  int _activeSensors = 0;
  
  // Operating drones (active status)
  List<Map<String, dynamic>> get _operatingDrones => 
    _drones.where((drone) {
      final status = drone['status'] as String? ?? '';
      return status.toLowerCase() == 'active' || status.toLowerCase() == 'operating';
    }).toList();
  
  // Critical/high detections from operating drones
  List<Map<String, dynamic>> get _criticalDetections => 
    _hazardousZones.where((zone) {
      final severity = zone['severity'] as String? ?? 'low';
      return severity == 'critical' || severity == 'high';
    }).toList();
  
  @override
  void initState() {
    super.initState();
    _initializeData();
  }
  
  @override
  void dispose() {
    _droneSubscription?.cancel();
    _zonesSubscription?.cancel();
    _missionSubscription?.cancel();
    super.dispose();
  }
  
  void _initializeData() {
    // Listen to drone positions
    _droneSubscription = _firebaseService.getDronePositions().listen((dronesData) {
      setState(() {
        _drones = dronesData.entries.map((entry) => Map<String, dynamic>.from(entry.value)).toList();
        _activeSensors = _operatingDrones.length;
        _updateAssetHealth();
      });
    });
    
    // Listen to hazardous zones
    _zonesSubscription = _firebaseService.getHazardousZones().listen((zonesData) {
      setState(() {
        final newZones = zonesData.entries.map((entry) => Map<String, dynamic>.from(entry.value)).toList();
        
        // Check if new zones were added and calculate response time
        if (_hazardousZones.length < newZones.length) {
          final now = DateTime.now();
          if (_lastDetectionTime != null) {
            final responseTime = now.difference(_lastDetectionTime!).inMinutes.toDouble();
            _responseTimes.add(responseTime);
            // Keep only last 50 response times
            if (_responseTimes.length > 50) {
              _responseTimes.removeAt(0);
            }
          }
          _lastDetectionTime = now;
        }
        
        _hazardousZones = newZones;
        _updateAlertStatistics();
      });
    });
    
    // Listen to mission status
    _missionSubscription = _firebaseService.getMissionStatus().listen((missionData) {
      setState(() {
        _missionStatus = missionData;
        _updateMissionStatistics();
      });
    });
    
    // Initialize default asset health
    _assets = [
      AssetHealth(name: 'UAV-ALPHA-1', health: 'Nominal', nextService: '36 hrs'),
      AssetHealth(name: 'UGV-DELTA-2', health: 'Degraded', nextService: '12 hrs'),
      AssetHealth(name: 'UAV-BRAVO-1', health: 'Nominal', nextService: '48 hrs'),
    ];
  }
  
  void _updateAlertStatistics() {
    _criticalAlerts = 0;
    _highAlerts = 0;
    _mediumAlerts = 0;
    _lowAlerts = 0;
    
    for (final zone in _hazardousZones) {
      final severity = zone['severity'] as String? ?? 'low';
      switch (severity) {
        case 'critical':
          _criticalAlerts++;
          break;
        case 'high':
          _highAlerts++;
          break;
        case 'medium':
          _mediumAlerts++;
          break;
        case 'low':
          _lowAlerts++;
          break;
      }
    }
  }
  
  void _updateMissionStatistics() {
    // Calculate mission statistics based on actual data
    final isRunning = _missionStatus['isRunning'] as bool? ?? false;
    
    if (isRunning) {
      // Total missions = number of detections made
      _totalMissions = _hazardousZones.length;
      
      // Successful missions = detections that are above threshold
      _successfulMissions = _hazardousZones.where((zone) {
        final detected = zone['detected'] as bool? ?? false;
        return detected;
      }).length;
      
      // Calculate average response time
      if (_responseTimes.isNotEmpty) {
        _avgResponseTime = _responseTimes.reduce((a, b) => a + b) / _responseTimes.length;
      }
      
      // Calculate total distance based on drone activity
      _totalDistance = _drones.fold(0.0, (sum, drone) {
        final battery = drone['battery'] as int? ?? 0;
        // Estimate distance based on battery usage (approximate)
        final estimatedDistance = (100 - battery) * 10.0; // 10km per 1% battery
        return sum + estimatedDistance;
      });
      
      // Calculate mission distribution based on detection types
      _surveillanceMissions = 0;
      _reconnaissanceMissions = 0;
      _searchRescueMissions = 0;
      _evacuationMissions = 0;
      
      for (final zone in _hazardousZones) {
        final substanceType = zone['substanceType'] as String? ?? '';
        // Simple classification based on substance type
        if (substanceType.toLowerCase().contains('chemical') || 
            substanceType.toLowerCase().contains('chlorine') ||
            substanceType.toLowerCase().contains('sarin')) {
          _surveillanceMissions++;
        } else if (substanceType.toLowerCase().contains('biological') ||
                   substanceType.toLowerCase().contains('anthrax')) {
          _reconnaissanceMissions++;
        } else if (substanceType.toLowerCase().contains('radiological') ||
                   substanceType.toLowerCase().contains('cesium')) {
          _searchRescueMissions++;
        } else if (substanceType.toLowerCase().contains('nuclear') ||
                   substanceType.toLowerCase().contains('uranium')) {
          _evacuationMissions++;
        }
      }
    }
  }
  
  void _updateAssetHealth() {
    // Update asset health based on drone battery levels
    _assets = _drones.map((drone) {
      final battery = drone['battery'] as int? ?? 100;
      final name = drone['name'] as String? ?? 'Unknown';
      final health = battery > 50 ? 'Nominal' : battery > 25 ? 'Degraded' : 'Critical';
      final nextService = battery > 75 ? '48 hrs' : battery > 50 ? '36 hrs' : '12 hrs';
      return AssetHealth(name: name, health: health, nextService: nextService);
    }).toList();
  }
  
  String _getSuccessRate() {
    if (_totalMissions == 0) return '0%';
    final rate = (_successfulMissions / _totalMissions * 100).toStringAsFixed(0);
    return '$rate%';
  }
  
  int _getTotalAlerts() => _criticalAlerts + _highAlerts + _mediumAlerts + _lowAlerts;
  
  int _getMissionPercent(int count) {
    if (_totalMissions == 0) return 0;
    return ((count / _totalMissions) * 100).round();
  }
  
  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Color(0xFFFF4D4F);
      case 'high':
        return const Color(0xFFFF7A45);
      case 'medium':
        return const Color(0xFFFFB020);
      case 'low':
        return const Color(0xFF2F80ED);
      default:
        return const Color(0xFF7C8B85);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _grid(
          columns: 4,
          children: [
            _panel(
              title: 'Operating Drones & Critical Detections',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Drones: ${_operatingDrones.length}',
                        style: const TextStyle(
                          color: Color(0xFF38FF9C),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Critical: ${_criticalDetections.length}',
                        style: const TextStyle(
                          color: Color(0xFFFF4D4F),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_operatingDrones.isEmpty)
                    const Text(
                      'No drones currently operating',
                      style: TextStyle(color: Color(0xFF7C8B85), fontSize: 11),
                    )
                  else
                    ..._operatingDrones.take(4).map((drone) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C2A24),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF38FF9C),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      drone['name'] as String? ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF38FF9C).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Active',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF38FF9C),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.battery_charging_full, size: 12, color: Color(0xFF7C8B85)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${drone['battery'] as int? ?? 0}% Battery',
                                      style: const TextStyle(
                                        color: Color(0xFF7C8B85),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )),
                  const SizedBox(height: 12),
                  if (_criticalDetections.isNotEmpty) ...[
                    const Text(
                      'Critical/High Detections:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Color(0xFFFF4D4F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._criticalDetections.take(3).map((zone) => Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4D4F).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getSeverityColor(zone['severity'] as String? ?? 'low'),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    zone['name'] as String? ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getSeverityColor(zone['severity'] as String? ?? 'low').withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      zone['severity'] as String? ?? 'low',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _getSeverityColor(zone['severity'] as String? ?? 'low'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${zone['substanceType'] as String? ?? 'Unknown'} · ${zone['radiusKm'] as double? ?? 0}km radius',
                                style: const TextStyle(
                                  color: Color(0xFF7C8B85),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ] else
                    const Text(
                      'No critical/high severity detections',
                      style: TextStyle(color: Color(0xFF7C8B85), fontSize: 11),
                    ),
                ],
              ),
            ),
            _panel(
              title: 'Mission Performance & Operational Metrics',
              child: _grid(
                columns: 2,
                children: [
                  _Metric(label: 'Total Missions', value: '$_totalMissions'),
                  _Metric(label: 'Success Rate', value: _getSuccessRate()),
                  _Metric(label: 'Avg Response Time', value: '${_avgResponseTime.toStringAsFixed(1)} min'),
                  _Metric(label: 'Total Distance', value: '${_totalDistance.toStringAsFixed(0)} km'),
                ],
              ),
            ),
            _panel(
              title: 'Mission Distribution',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Chip(text: 'Surveillance ${_getMissionPercent(_surveillanceMissions)}%'),
                      _Chip(text: 'Reconnaissance ${_getMissionPercent(_reconnaissanceMissions)}%'),
                      _Chip(text: 'Search & Rescue ${_getMissionPercent(_searchRescueMissions)}%'),
                      _Chip(text: 'Evacuation ${_getMissionPercent(_evacuationMissions)}%'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DistributionBar(label: 'Surveillance', percent: _getMissionPercent(_surveillanceMissions), color: const Color(0xFF38FF9C)),
                  const SizedBox(height: 8),
                  _DistributionBar(label: 'Reconnaissance', percent: _getMissionPercent(_reconnaissanceMissions), color: const Color(0xFF00D4FF)),
                  const SizedBox(height: 8),
                  _DistributionBar(label: 'Search & Rescue', percent: _getMissionPercent(_searchRescueMissions), color: const Color(0xFFFFB020)),
                  const SizedBox(height: 8),
                  _DistributionBar(label: 'Evacuation', percent: _getMissionPercent(_evacuationMissions), color: const Color(0xFFFF7A45)),
                ],
              ),
            ),
            _panel(
              title: 'Trend Analysis Charts',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ListRow(
                    label: 'CBRN Detection Trends',
                    badge: '${_getTotalAlerts()} Total',
                  ),
                  _ListRow(
                    label: 'Alert Frequency Analysis',
                    badge: '${_criticalAlerts + _highAlerts} Critical/High',
                  ),
                  _ListRow(
                    label: 'Robot Performance Metrics',
                    badge: '${_drones.length} Active',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C2A24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Detection Activity',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_getTotalAlerts()} total alerts detected',
                          style: const TextStyle(
                            color: Color(0xFF7C8B85),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_criticalAlerts} critical, ${_highAlerts} high, ${_mediumAlerts} medium, ${_lowAlerts} low',
                          style: const TextStyle(
                            color: Color(0xFF7C8B85),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _panel(
              title: 'Sensor Fusion Status',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Sensors: $_activeSensors',
                    style: const TextStyle(color: Color(0xFF7C8B85)),
                  ),
                  const SizedBox(height: 8),
                  Text('Heatmap Overlay: ${_heatmapEnabled ? 'Enabled' : 'Disabled'}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _heatmapEnabled = !_heatmapEnabled;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _heatmapEnabled ? const Color(0xFF38FF9C) : const Color(0xFF1C2A24),
                    ),
                    child: Text(
                      _heatmapEnabled ? 'Disable Heatmap' : 'Enable Heatmap',
                      style: TextStyle(
                        color: _heatmapEnabled ? Colors.black : const Color(0xFFE6F4EE),
                      ),
                    ),
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
                children: [
                  _SeverityRow(label: 'Critical', value: '$_criticalAlerts', severity: 'critical'),
                  _SeverityRow(label: 'High', value: '$_highAlerts', severity: 'high'),
                  _SeverityRow(label: 'Medium', value: '$_mediumAlerts', severity: 'medium'),
                  _SeverityRow(label: 'Low', value: '$_lowAlerts', severity: 'low'),
                ],
              ),
            ),
            _panel(
              title: 'Asset Health & Maintenance',
              child: Column(
                children: _assets
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
