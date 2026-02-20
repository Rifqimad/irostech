// lib/screens/substances_screen.dart

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/file_download_helper.dart'
    if (dart.library.html) '../services/file_download_helper_web.dart';
import '../services/firebase_service.dart';
import 'substance_management_screen.dart';

class SubstancesScreen extends StatefulWidget {
  const SubstancesScreen({super.key});

  @override
  State<SubstancesScreen> createState() => _SubstancesScreenState();
}

class _SubstancesScreenState extends State<SubstancesScreen> {
  String substanceFilter = 'all';
  String substanceSearch = '';
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;
  List<SubstanceItem> _allSubstances = [];

  @override
  void initState() {
    super.initState();
    _initializeSubstances();
  }

  Future<void> _initializeSubstances() async {
    // Initialize default substances if collection is empty
    await _firebaseService.initializeDefaultSubstances();
    
    // Load substances from Firestore
    _firebaseService.getSubstances().listen((snapshot) {
      final substances = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return SubstanceItem(
          id: doc.id,
          name: data['name'] as String? ?? '',
          category: data['category'] as String? ?? '',
          properties: data['properties'] as String? ?? '',
          description: data['description'] as String? ?? '',
          severity: data['severity'] as String? ?? 'unknown',
        );
      }).toList();

      setState(() {
        _allSubstances = substances;
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSubstances();

    return Column(
      children: [
        _panel(
          title: 'CBRN Substances Database',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _filterChip('All', 'all'),
                  _filterChip('Chem', 'chemical'),
                  _filterChip('Bio', 'biological'),
                  _filterChip('Rad', 'radiological'),
                  _filterChip('Nuc', 'nuclear'),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(hintText: 'Search substances...'),
                onChanged: (value) => setState(() => substanceSearch = value),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF38FF9C),
                  ),
                )
              else if (filtered.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No substances found',
                      style: TextStyle(color: Color(0xFF7C8B85)),
                    ),
                  ),
                )
              else
                _grid(
                  columns: 2,
                  children: filtered
                      .map((item) => _panel(
                            title: item.name,
                            compact: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getSeverityColor(item.severity),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item.severity.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item.category.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF38FF9C),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.properties,
                                  style: const TextStyle(
                                    color: Color(0xFF38FF9C),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.description,
                                  style: const TextStyle(color: Color(0xFF7C8B85)),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _importSubstances,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2A24),
                    ),
                    child: const Text('Import'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _exportSubstances,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2A24),
                    ),
                    child: const Text('Export'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SubstanceManagementScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38FF9C),
                    ),
                    child: const Text(
                      'Manage Substances',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<SubstanceItem> _filteredSubstances() {
    if (substanceFilter == 'all') {
      if (substanceSearch.trim().isEmpty) return _allSubstances;
      final term = substanceSearch.toLowerCase();
      return _allSubstances
          .where((item) =>
              item.name.toLowerCase().contains(term) ||
              item.properties.toLowerCase().contains(term) ||
              item.description.toLowerCase().contains(term))
          .toList();
    } else {
      final filtered = _allSubstances
          .where((item) => item.category == substanceFilter)
          .toList();
      
      if (substanceSearch.trim().isEmpty) return filtered;
      
      final term = substanceSearch.toLowerCase();
      return filtered
          .where((item) =>
              item.name.toLowerCase().contains(term) ||
              item.properties.toLowerCase().contains(term) ||
              item.description.toLowerCase().contains(term))
          .toList();
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Color(0xFFFF4D4F);
      case 'high':
        return const Color(0xFFFFB020);
      case 'medium':
        return const Color(0xFF38FF9C);
      case 'low':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF7C8B85);
    }
  }

  void _showAddSubstanceDialog() {
    final nameController = TextEditingController();
    final categoryController = TextEditingController(text: 'chemical');
    final propertiesController = TextEditingController();
    final descriptionController = TextEditingController();
    final severityController = TextEditingController(text: 'high');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101915),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1C2A24)),
        ),
        title: const Text(
          'Add New Substance',
          style: TextStyle(color: Color(0xFFE6F4EE)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Color(0xFF7C8B85)),
                ),
                style: const TextStyle(color: Color(0xFFE6F4EE)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category (chemical/biological/radiological/nuclear)',
                  labelStyle: TextStyle(color: Color(0xFF7C8B85)),
                ),
                style: const TextStyle(color: Color(0xFFE6F4EE)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: propertiesController,
                decoration: const InputDecoration(
                  labelText: 'Properties',
                  labelStyle: TextStyle(color: Color(0xFF7C8B85)),
                ),
                style: const TextStyle(color: Color(0xFFE6F4EE)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Color(0xFF7C8B85)),
                ),
                style: const TextStyle(color: Color(0xFFE6F4EE)),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: severityController,
                decoration: const InputDecoration(
                  labelText: 'Severity (critical/high/medium/low)',
                  labelStyle: TextStyle(color: Color(0xFF7C8B85)),
                ),
                style: const TextStyle(color: Color(0xFFE6F4EE)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF7C8B85)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  categoryController.text.isEmpty ||
                  propertiesController.text.isEmpty ||
                  descriptionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all required fields'),
                    backgroundColor: Color(0xFFFF4D4F),
                  ),
                );
                return;
              }

              try {
                await _firebaseService.addSubstance(
                  name: nameController.text,
                  category: categoryController.text,
                  properties: propertiesController.text,
                  description: descriptionController.text,
                  severity: severityController.text,
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Substance added successfully'),
                      backgroundColor: Color(0xFF38FF9C),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding substance: ${e.toString()}'),
                      backgroundColor: Color(0xFFFF4D4F),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38FF9C),
            ),
            child: const Text(
              'Add',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportSubstances() async {
    try {
      if (_allSubstances.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No substances to export'),
              backgroundColor: Color(0xFFFF4D4F),
            ),
          );
        }
        return;
      }

      // Create CSV content
      final csvContent = StringBuffer();
      csvContent.writeln('Name,Category,Properties,Description,Severity');
      
      for (final substance in _allSubstances) {
        csvContent.writeln(
          '${_escapeCsv(substance.name)},'
          '${_escapeCsv(substance.category)},'
          '${_escapeCsv(substance.properties)},'
          '${_escapeCsv(substance.description)},'
          '${_escapeCsv(substance.severity)}',
        );
      }

      // Download the CSV file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'substances_$timestamp.csv';
      await FileDownloadHelper.downloadFile(fileName, csvContent.toString());

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV exported successfully as: $fileName'),
            backgroundColor: Color(0xFF38FF9C),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting substances: ${e.toString()}'),
            backgroundColor: Color(0xFFFF4D4F),
          ),
        );
      }
    }
  }

  Future<void> _importSubstances() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      
      if (result == null || result.files.isEmpty) {
        return;
      }
      
      final file = result.files.first;
      final bytes = file.bytes;
      
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error reading file'),
              backgroundColor: Color(0xFFFF4D4F),
            ),
          );
        }
        return;
      }
      
      final csvContent = utf8.decode(bytes);
      final lines = csvContent.split('\n');
      
      if (lines.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CSV file is empty or invalid'),
              backgroundColor: Color(0xFFFF4D4F),
            ),
          );
        }
        return;
      }
      
      // Skip header row and process data
      int importedCount = 0;
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        final values = _parseCsvLine(line);
        if (values.length >= 4) {
          try {
            await _firebaseService.addSubstance(
              name: values[0],
              category: values[1],
              properties: values[2],
              description: values[3],
              severity: values.length > 4 ? values[4] : 'unknown',
            );
            importedCount++;
          } catch (e) {
            print('Error importing substance: $e');
          }
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $importedCount substance(s)'),
            backgroundColor: Color(0xFF38FF9C),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing substances: ${e.toString()}'),
            backgroundColor: Color(0xFFFF4D4F),
          ),
        );
      }
    }
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  List<String> _parseCsvLine(String line) {
    final List<String> result = [];
    bool inQuotes = false;
    String currentValue = '';
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          currentValue += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(currentValue);
        currentValue = '';
      } else {
        currentValue += char;
      }
    }
    
    result.add(currentValue);
    return result;
  }

  Widget _filterChip(String label, String value) {
    final active = substanceFilter == value;
    return GestureDetector(
      onTap: () => setState(() => substanceFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF38FF9C) : const Color(0xFF1C2A24),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : const Color(0xFFE6F4EE),
            fontSize: 12,
          ),
        ),
      ),
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
          spacing: 16,
          runSpacing: 16,
          children: children
              .map(
                (child) => SizedBox(
                  width: (width - (16 * (adjustedColumns - 1))) / adjustedColumns,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _panel({
    required String title,
    required Widget child,
    bool compact = false,
  }) {
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
          compact
              ? DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 12),
                  child: child,
                )
              : child,
        ],
      ),
    );
  }
}

class SubstanceItem {
  final String id;
  final String name;
  final String category;
  final String properties;
  final String description;
  final String severity;
  
  SubstanceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.properties,
    required this.description,
    required this.severity,
  });
}
