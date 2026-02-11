// lib/screens/substances_screen.dart

import 'package:flutter/material.dart';

class SubstancesScreen extends StatefulWidget {
  const SubstancesScreen({super.key});

  @override
  State<SubstancesScreen> createState() => _SubstancesScreenState();
}

class _SubstancesScreenState extends State<SubstancesScreen> {
  String substanceFilter = 'all';
  String substanceSearch = '';

  final Map<String, List<SubstanceItem>> substanceDatabase = {
    'chemical': [
      SubstanceItem(name: 'Sarin', properties: 'Liquid, Volatile, Lethal', description: 'Nerve agent with rapid inhalation hazards.'),
      SubstanceItem(name: 'Chlorine', properties: 'Gas, Greenish, Corrosive', description: 'Respiratory irritant with dense plume behavior.'),
      SubstanceItem(name: 'VX', properties: 'Persistent, Oily', description: 'Extremely toxic nerve agent with surface persistence.'),
      SubstanceItem(name: 'Tabun', properties: 'Liquid, Volatile', description: 'First discovered nerve agent with delayed symptoms.'),
      SubstanceItem(name: 'Soman', properties: 'Liquid, Volatile', description: 'More potent than tabun with rapid onset.'),
      SubstanceItem(name: 'Cyclosarin', properties: 'Liquid, Volatile', description: 'More persistent than sarin with higher toxicity.'),
      SubstanceItem(name: 'Mustard Gas', properties: 'Liquid, Vesicant', description: 'Causes severe blistering and respiratory damage.'),
      SubstanceItem(name: 'Lewisite', properties: 'Liquid, Vesicant', description: 'Arsenic-based blistering agent with immediate pain.'),
      SubstanceItem(name: 'Phosgene', properties: 'Gas, Colorless', description: 'Choking agent causing pulmonary edema.'),
      SubstanceItem(name: 'Hydrogen Cyanide', properties: 'Gas, Volatile', description: 'Blood agent preventing cellular respiration.'),
      SubstanceItem(name: 'Cyanogen Chloride', properties: 'Gas, Volatile', description: 'Blood agent with rapid incapacitation.'),
      SubstanceItem(name: 'Sulfur Mustard', properties: 'Liquid, Vesicant', description: 'Delayed blistering agent with long-term effects.'),
      SubstanceItem(name: 'Nitrogen Mustard', properties: 'Liquid, Vesicant', description: 'Blistering agent with alkylating properties.'),
      SubstanceItem(name: 'BZ', properties: 'Solid, Deliriant', description: 'Incapacitating agent causing hallucinations.'),
      SubstanceItem(name: 'Saxitoxin', properties: 'Solid, Neurotoxin', description: 'Paralytic shellfish poison with rapid onset.'),
      SubstanceItem(name: 'Ricin', properties: 'Solid, Toxin', description: 'Protein toxin derived from castor beans.'),
      SubstanceItem(name: 'Aflatoxin', properties: 'Solid, Carcinogen', description: 'Fungal toxin causing liver damage.'),
      SubstanceItem(name: 'Tetrodotoxin', properties: 'Solid, Neurotoxin', description: 'Marine toxin causing paralysis.'),
      SubstanceItem(name: 'Botulinum Toxin', properties: 'Solid, Neurotoxin', description: 'Most potent biological toxin known.'),
      SubstanceItem(name: 'Agent 15', properties: 'Liquid, Deliriant', description: 'Incapacitating agent similar to BZ.'),
    ],
    'biological': [
      SubstanceItem(name: 'Anthrax', properties: 'Spore-forming, Durable', description: 'Inhalational risk with long environmental persistence.'),
      SubstanceItem(name: 'Ricin', properties: 'Toxin, Powder', description: 'Protein toxin derived from castor beans.'),
      SubstanceItem(name: 'Botulinum', properties: 'Neurotoxin', description: 'Highly lethal toxin requiring rapid containment.'),
      SubstanceItem(name: 'Smallpox', properties: 'Virus, Contagious', description: 'Highly infectious with high mortality rate.'),
      SubstanceItem(name: 'Ebola', properties: 'Virus, Hemorrhagic', description: 'Severe hemorrhagic fever with high mortality.'),
      SubstanceItem(name: 'Marburg', properties: 'Virus, Hemorrhagic', description: 'Related to Ebola with similar symptoms.'),
      SubstanceItem(name: 'Plague', properties: 'Bacteria, Pneumonic', description: 'Highly contagious respiratory infection.'),
      SubstanceItem(name: 'Tularemia', properties: 'Bacteria, Highly infectious', description: 'Rabbit fever with aerosol transmission risk.'),
      SubstanceItem(name: 'Brucellosis', properties: 'Bacteria, Zoonotic', description: 'Chronic infection with multiple organ involvement.'),
      SubstanceItem(name: 'Q Fever', properties: 'Bacteria, Coxiella', description: 'Highly resistant spores with aerosol risk.'),
      SubstanceItem(name: 'Glanders', properties: 'Bacteria, Burkholderia', description: 'Rare disease with high mortality if untreated.'),
      SubstanceItem(name: 'Melioidosis', properties: 'Bacteria, Burkholderia', description: 'Similar to glanders with environmental persistence.'),
      SubstanceItem(name: 'Cholera', properties: 'Bacteria, Waterborne', description: 'Severe diarrheal disease with dehydration risk.'),
      SubstanceItem(name: 'Typhoid', properties: 'Bacteria, Salmonella', description: 'Systemic infection with high fever.'),
      SubstanceItem(name: 'Dengue', properties: 'Virus, Mosquito-borne', description: 'Hemorrhagic fever with severe joint pain.'),
      SubstanceItem(name: 'Yellow Fever', properties: 'Virus, Mosquito-borne', description: 'Hemorrhagic fever with liver involvement.'),
      SubstanceItem(name: 'Lassa', properties: 'Virus, Arenavirus', description: 'Hemorrhagic fever with hearing loss risk.'),
      SubstanceItem(name: 'Junin', properties: 'Virus, Arenavirus', description: 'Argentine hemorrhagic fever agent.'),
      SubstanceItem(name: 'Machupo', properties: 'Virus, Arenavirus', description: 'Bolivian hemorrhagic fever agent.'),
      SubstanceItem(name: 'Guanarito', properties: 'Virus, Arenavirus', description: 'Venezuelan hemorrhagic fever agent.'),
    ],
    'radiological': [
      SubstanceItem(name: 'Cesium-137', properties: 'Radioactive, Long-lived', description: 'Gamma-emitting fission product.'),
      SubstanceItem(name: 'Cobalt-60', properties: 'Radiation Source', description: 'Industrial source for irradiation.'),
      SubstanceItem(name: 'Iodine-131', properties: 'Short-lived', description: 'Thyroid uptake risk after exposure.'),
      SubstanceItem(name: 'Strontium-90', properties: 'Bone-seeker', description: 'Beta emitter with long half-life.'),
      SubstanceItem(name: 'Plutonium-239', properties: 'Alpha emitter', description: 'Heavy metal with lung cancer risk.'),
      SubstanceItem(name: 'Americium-241', properties: 'Alpha emitter', description: 'Used in smoke detectors, toxic if inhaled.'),
      SubstanceItem(name: 'Uranium-235', properties: 'Fissile', description: 'Enriched uranium for nuclear weapons.'),
      SubstanceItem(name: 'Uranium-238', properties: 'Depleted', description: 'Dense metal with chemical toxicity.'),
      SubstanceItem(name: 'Radium-226', properties: 'Alpha emitter', description: 'Naturally radioactive, bone seeker.'),
      SubstanceItem(name: 'Polonium-210', properties: 'Alpha emitter', description: 'Extremely toxic, lethal in micrograms.'),
      SubstanceItem(name: 'Tritium', properties: 'Beta emitter', description: 'Radioactive hydrogen, water contaminant.'),
      SubstanceItem(name: 'Carbon-14', properties: 'Beta emitter', description: 'Long-lived environmental tracer.'),
      SubstanceItem(name: 'Krypton-85', properties: 'Noble gas', description: 'Fission product, atmospheric dispersion.'),
      SubstanceItem(name: 'Xenon-133', properties: 'Noble gas', description: 'Medical imaging isotope, short half-life.'),
      SubstanceItem(name: 'Technetium-99m', properties: 'Gamma emitter', description: 'Medical imaging isotope, widely used.'),
      SubstanceItem(name: 'Iridium-192', properties: 'Gamma emitter', description: 'Industrial radiography source.'),
      SubstanceItem(name: 'Cobalt-57', properties: 'Gamma emitter', description: 'Medical imaging and calibration source.'),
      SubstanceItem(name: 'Barium-140', properties: 'Beta emitter', description: 'Fission product with short half-life.'),
      SubstanceItem(name: 'Cerium-144', properties: 'Beta emitter', description: 'Fission product, significant heat source.'),
      SubstanceItem(name: 'Promethium-147', properties: 'Beta emitter', description: 'Used in nuclear batteries, long-lived.'),
    ],
    'nuclear': [
      SubstanceItem(name: 'Uranium-235', properties: 'Fissile, Heavy metal', description: 'Criticality risk in enriched states.'),
      SubstanceItem(name: 'Plutonium-239', properties: 'Fissile, Alpha emitter', description: 'Requires strict contamination controls.'),
      SubstanceItem(name: 'Uranium-238', properties: 'Dense, Toxic', description: 'Depleted uranium handling protocols.'),
      SubstanceItem(name: 'Uranium-233', properties: 'Fissile, Artificial', description: 'Breeder reactor fuel material.'),
      SubstanceItem(name: 'Plutonium-240', properties: 'Fissile, Spontaneous', description: 'High spontaneous fission rate.'),
      SubstanceItem(name: 'Plutonium-241', properties: 'Fissile, Beta emitter', description: 'Decays to americium-241.'),
      SubstanceItem(name: 'Neptunium-237', properties: 'Fissile, Artificial', description: 'Byproduct of nuclear reactors.'),
      SubstanceItem(name: 'Americium-241', properties: 'Fissile, Alpha emitter', description: 'Produced in nuclear reactors.'),
      SubstanceItem(name: 'Curium-244', properties: 'Fissile, Alpha emitter', description: 'High heat output, potential fuel.'),
      SubstanceItem(name: 'Californium-252', properties: 'Neutron source', description: 'Spontaneous fission neutron emitter.'),
      SubstanceItem(name: 'Thorium-232', properties: 'Fertile, Natural', description: 'Potential breeder reactor fuel.'),
      SubstanceItem(name: 'Thorium-233', properties: 'Fissile, Artificial', description: 'Intermediate in thorium cycle.'),
      SubstanceItem(name: 'Deuterium', properties: 'Fusion fuel', description: 'Heavy hydrogen for fusion reactors.'),
      SubstanceItem(name: 'Tritium', properties: 'Fusion fuel', description: 'Radioactive hydrogen for fusion.'),
      SubstanceItem(name: 'Lithium-6', properties: 'Fusion breeding', description: 'Produces tritium in fusion reactions.'),
      SubstanceItem(name: 'Lithium-7', properties: 'Fusion breeding', description: 'Neutron source in fusion reactions.'),
      SubstanceItem(name: 'Beryllium-9', properties: 'Neutron multiplier', description: 'Reflects and multiplies neutrons.'),
      SubstanceItem(name: 'Boron-10', properties: 'Neutron absorber', description: 'Control rod material for reactors.'),
      SubstanceItem(name: 'Cadmium-113', properties: 'Neutron absorber', description: 'Control rod material for reactors.'),
      SubstanceItem(name: 'Hafnium-178', properties: 'Neutron absorber', description: 'Control rod material for reactors.'),
    ],
  };

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
              _grid(
                columns: 2,
                children: filtered
                    .map((item) => _panel(
                          title: item.name,
                          compact: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2A24),
                    ),
                    child: const Text('Import'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2A24),
                    ),
                    child: const Text('Export'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2A24),
                    ),
                    child: const Text('Add Substance'),
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
    final allItems = <SubstanceItem>[];
    if (substanceFilter == 'all') {
      substanceDatabase.forEach((_, items) => allItems.addAll(items));
    } else {
      allItems.addAll(substanceDatabase[substanceFilter] ?? []);
    }
    if (substanceSearch.trim().isEmpty) return allItems;
    final term = substanceSearch.toLowerCase();
    return allItems
        .where((item) =>
            item.name.toLowerCase().contains(term) ||
            item.properties.toLowerCase().contains(term) ||
            item.description.toLowerCase().contains(term))
        .toList();
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
  final String name;
  final String properties;
  final String description;

  SubstanceItem({
    required this.name,
    required this.properties,
    required this.description,
  });
}
