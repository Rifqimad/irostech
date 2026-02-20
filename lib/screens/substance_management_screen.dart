// lib/screens/substance_management_screen.dart

import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class SubstanceManagementScreen extends StatefulWidget {
  const SubstanceManagementScreen({super.key});

  @override
  State<SubstanceManagementScreen> createState() => _SubstanceManagementScreenState();
}

class _SubstanceManagementScreenState extends State<SubstanceManagementScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _substances = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _categoryFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadSubstances();
  }

  void _loadSubstances() {
    _firebaseService.getSubstances().listen((snapshot) {
      final substances = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      setState(() {
        _substances = substances;
        _isLoading = false;
      });
    });
  }

  List<Map<String, dynamic>> get _filteredSubstances {
    var filtered = _substances;

    // Filter by category
    if (_categoryFilter != 'all') {
      filtered = filtered
          .where((s) => (s['category'] as String?) == _categoryFilter)
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((s) {
        final name = (s['name'] as String? ?? '').toLowerCase();
        final properties = (s['properties'] as String? ?? '').toLowerCase();
        final description = (s['description'] as String? ?? '').toLowerCase();
        return name.contains(query) ||
               properties.contains(query) ||
               description.contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101915),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF38FF9C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Substance Management',
          style: TextStyle(color: Color(0xFFE6F4EE)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF38FF9C)),
            onPressed: () => _showSubstanceDialog(),
            tooltip: 'Add Substance',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF101915),
              border: Border(bottom: BorderSide(color: Color(0xFF1C2A24))),
            ),
            child: Column(
              children: [
                // Search Field
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search substances...',
                    hintStyle: const TextStyle(color: Color(0xFF7C8B85)),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF7C8B85),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0A0F0D),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  style: const TextStyle(color: Color(0xFFE6F4EE)),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
                const SizedBox(height: 12),
                // Category Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Chemical', 'chemical'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Biological', 'biological'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Radiological', 'radiological'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Nuclear', 'nuclear'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Substance List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF38FF9C),
                    ),
                  )
                : _filteredSubstances.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: const Color(0xFF7C8B85),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No substances found',
                              style: TextStyle(
                                color: Color(0xFF7C8B85),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredSubstances.length,
                        itemBuilder: (context, index) {
                          final substance = _filteredSubstances[index];
                          return _buildSubstanceCard(substance);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _categoryFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _categoryFilter = value);
      },
      selectedColor: const Color(0xFF38FF9C),
      backgroundColor: const Color(0xFF1C2A24),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : const Color(0xFFE6F4EE),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFF38FF9C) : Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildSubstanceCard(Map<String, dynamic> substance) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF101915),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1C2A24)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Expanded(
              child: Text(
                substance['name'] ?? 'Unknown',
                style: const TextStyle(
                  color: Color(0xFFE6F4EE),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            _buildSeverityBadge(substance['severity'] ?? 'unknown'),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                _buildCategoryBadge(substance['category'] ?? 'unknown'),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    substance['properties'] ?? '',
                    style: const TextStyle(
                      color: Color(0xFF38FF9C),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              substance['description'] ?? '',
              style: const TextStyle(
                color: Color(0xFF7C8B85),
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF38FF9C)),
              onPressed: () => _showSubstanceDialog(substance: substance),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Color(0xFFFF4D4F)),
              onPressed: () => _showDeleteDialog(substance),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityBadge(String severity) {
    Color color;
    switch (severity.toLowerCase()) {
      case 'critical':
        color = const Color(0xFFFF4D4F);
        break;
      case 'high':
        color = const Color(0xFFFFB020);
        break;
      case 'medium':
        color = const Color(0xFF38FF9C);
        break;
      case 'low':
        color = const Color(0xFF4CAF50);
        break;
      default:
        color = const Color(0xFF7C8B85);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        severity.toUpperCase(),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2A24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF38FF9C)),
      ),
      child: Text(
        category.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF38FF9C),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showSubstanceDialog({Map<String, dynamic>? substance}) {
    final isEditing = substance != null;
    final nameController = TextEditingController(text: substance?['name'] ?? '');
    final categoryController = TextEditingController(
      text: substance?['category'] ?? 'chemical',
    );
    final propertiesController = TextEditingController(
      text: substance?['properties'] ?? '',
    );
    final descriptionController = TextEditingController(
      text: substance?['description'] ?? '',
    );
    final severityController = TextEditingController(
      text: substance?['severity'] ?? 'high',
    );
    final casNumberController = TextEditingController(
      text: substance?['casNumber'] ?? '',
    );
    final formulaController = TextEditingController(
      text: substance?['formula'] ?? '',
    );
    final meltingPointController = TextEditingController(
      text: substance?['meltingPoint'] ?? '',
    );
    final boilingPointController = TextEditingController(
      text: substance?['boilingPoint'] ?? '',
    );
    final densityController = TextEditingController(
      text: substance?['density'] ?? '',
    );
    final solubilityController = TextEditingController(
      text: substance?['solubility'] ?? '',
    );
    final vaporPressureController = TextEditingController(
      text: substance?['vaporPressure'] ?? '',
    );
    final flashPointController = TextEditingController(
      text: substance?['flashPoint'] ?? '',
    );
    final autoignitionController = TextEditingController(
      text: substance?['autoignition'] ?? '',
    );
    final exposureLimitsController = TextEditingController(
      text: substance?['exposureLimits'] ?? '',
    );
    final firstAidController = TextEditingController(
      text: substance?['firstAid'] ?? '',
    );
    final decontaminationController = TextEditingController(
      text: substance?['decontamination'] ?? '',
    );
    final detectionMethodsController = TextEditingController(
      text: substance?['detectionMethods'] ?? '',
    );
    final protectiveEquipmentController = TextEditingController(
      text: substance?['protectiveEquipment'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF101915),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1C2A24)),
            ),
            title: Text(
              isEditing ? 'Edit Substance' : 'Add New Substance',
              style: const TextStyle(color: Color(0xFFE6F4EE)),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Basic Information'),
                    _buildTextField(nameController, 'Name *', required: true),
                    _buildDropdownField(
                      categoryController,
                      'Category *',
                      ['chemical', 'biological', 'radiological', 'nuclear'],
                      required: true,
                    ),
                    _buildTextField(propertiesController, 'Properties *', required: true),
                    _buildTextField(
                      descriptionController,
                      'Description *',
                      maxLines: 3,
                      required: true,
                    ),
                    _buildDropdownField(
                      severityController,
                      'Severity *',
                      ['critical', 'high', 'medium', 'low'],
                      required: true,
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Technical Data'),
                    _buildTextField(casNumberController, 'CAS Number'),
                    _buildTextField(formulaController, 'Chemical Formula'),
                    _buildTextField(meltingPointController, 'Melting Point'),
                    _buildTextField(boilingPointController, 'Boiling Point'),
                    _buildTextField(densityController, 'Density'),
                    _buildTextField(solubilityController, 'Solubility'),
                    _buildTextField(vaporPressureController, 'Vapor Pressure'),
                    _buildTextField(flashPointController, 'Flash Point'),
                    _buildTextField(autoignitionController, 'Autoignition Temperature'),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Safety Information'),
                    _buildTextField(
                      exposureLimitsController,
                      'Exposure Limits',
                      maxLines: 2,
                    ),
                    _buildTextField(firstAidController, 'First Aid Procedures', maxLines: 3),
                    _buildTextField(
                      decontaminationController,
                      'Decontamination Methods',
                      maxLines: 2,
                    ),
                    _buildTextField(
                      detectionMethodsController,
                      'Detection Methods',
                      maxLines: 2,
                    ),
                    _buildTextField(
                      protectiveEquipmentController,
                      'Required Protective Equipment',
                      maxLines: 2,
                    ),
                  ],
                ),
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
                      descriptionController.text.isEmpty ||
                      severityController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all required fields (*)'),
                        backgroundColor: Color(0xFFFF4D4F),
                      ),
                    );
                    return;
                  }

                  try {
                    if (isEditing) {
                      await _firebaseService.updateSubstance(
                        substanceId: substance!['id'],
                        name: nameController.text,
                        category: categoryController.text,
                        properties: propertiesController.text,
                        description: descriptionController.text,
                        severity: severityController.text,
                        casNumber: casNumberController.text.isEmpty
                            ? null
                            : casNumberController.text,
                        formula: formulaController.text.isEmpty
                            ? null
                            : formulaController.text,
                        meltingPoint: meltingPointController.text.isEmpty
                            ? null
                            : meltingPointController.text,
                        boilingPoint: boilingPointController.text.isEmpty
                            ? null
                            : boilingPointController.text,
                        density: densityController.text.isEmpty
                            ? null
                            : densityController.text,
                        solubility: solubilityController.text.isEmpty
                            ? null
                            : solubilityController.text,
                        vaporPressure: vaporPressureController.text.isEmpty
                            ? null
                            : vaporPressureController.text,
                        flashPoint: flashPointController.text.isEmpty
                            ? null
                            : flashPointController.text,
                        autoignition: autoignitionController.text.isEmpty
                            ? null
                            : autoignitionController.text,
                        exposureLimits: exposureLimitsController.text.isEmpty
                            ? null
                            : exposureLimitsController.text,
                        firstAid: firstAidController.text.isEmpty
                            ? null
                            : firstAidController.text,
                        decontamination:
                            decontaminationController.text.isEmpty
                                ? null
                                : decontaminationController.text,
                        detectionMethods:
                            detectionMethodsController.text.isEmpty
                                ? null
                                : detectionMethodsController.text,
                        protectiveEquipment:
                            protectiveEquipmentController.text.isEmpty
                                ? null
                                : protectiveEquipmentController.text,
                      );
                    } else {
                      await _firebaseService.addSubstance(
                        name: nameController.text,
                        category: categoryController.text,
                        properties: propertiesController.text,
                        description: descriptionController.text,
                        severity: severityController.text,
                        casNumber: casNumberController.text.isEmpty
                            ? null
                            : casNumberController.text,
                        formula: formulaController.text.isEmpty
                            ? null
                            : formulaController.text,
                        meltingPoint: meltingPointController.text.isEmpty
                            ? null
                            : meltingPointController.text,
                        boilingPoint: boilingPointController.text.isEmpty
                            ? null
                            : boilingPointController.text,
                        density: densityController.text.isEmpty
                            ? null
                            : densityController.text,
                        solubility: solubilityController.text.isEmpty
                            ? null
                            : solubilityController.text,
                        vaporPressure: vaporPressureController.text.isEmpty
                            ? null
                            : vaporPressureController.text,
                        flashPoint: flashPointController.text.isEmpty
                            ? null
                            : flashPointController.text,
                        autoignition: autoignitionController.text.isEmpty
                            ? null
                            : autoignitionController.text,
                        exposureLimits: exposureLimitsController.text.isEmpty
                            ? null
                            : exposureLimitsController.text,
                        firstAid: firstAidController.text.isEmpty
                            ? null
                            : firstAidController.text,
                        decontamination:
                            decontaminationController.text.isEmpty
                                ? null
                                : decontaminationController.text,
                        detectionMethods:
                            detectionMethodsController.text.isEmpty
                                ? null
                                : detectionMethodsController.text,
                        protectiveEquipment:
                            protectiveEquipmentController.text.isEmpty
                                ? null
                                : protectiveEquipmentController.text,
                      );
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEditing
                                ? 'Substance updated successfully'
                                : 'Substance added successfully',
                          ),
                          backgroundColor: const Color(0xFF38FF9C),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Error: ${e.toString()}',
                          ),
                          backgroundColor: const Color(0xFFFF4D4F),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38FF9C),
                ),
                child: Text(
                  isEditing ? 'Update' : 'Add',
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> substance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101915),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFF4D4F)),
        ),
        title: const Text(
          'Delete Substance',
          style: TextStyle(color: Color(0xFFE6F4EE)),
        ),
        content: Text(
          'Are you sure you want to delete "${substance['name']}"? This action cannot be undone.',
          style: const TextStyle(color: Color(0xFF7C8B85)),
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
              try {
                await _firebaseService.deleteSubstance(substance['id']);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Substance deleted successfully'),
                      backgroundColor: Color(0xFF38FF9C),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting substance: ${e.toString()}'),
                      backgroundColor: const Color(0xFFFF4D4F),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D4F),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF38FF9C),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool required = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          labelStyle: const TextStyle(color: Color(0xFF7C8B85)),
          filled: true,
          fillColor: const Color(0xFF0A0F0D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1C2A24)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1C2A24)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF38FF9C)),
          ),
        ),
        style: const TextStyle(color: Color(0xFFE6F4EE)),
      ),
    );
  }

  Widget _buildDropdownField(
    TextEditingController controller,
    String label,
    List<String> options, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: controller.text.isEmpty ? null : controller.text,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          labelStyle: const TextStyle(color: Color(0xFF7C8B85)),
          filled: true,
          fillColor: const Color(0xFF0A0F0D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1C2A24)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1C2A24)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF38FF9C)),
          ),
        ),
        dropdownColor: const Color(0xFF101915),
        style: const TextStyle(color: Color(0xFFE6F4EE)),
        items: options.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (value) {
          controller.text = value ?? '';
        },
      ),
    );
  }
}
