// lib/services/firebase_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update user profile with name
      if (credential.user != null) {
        await credential.user!.updateDisplayName(name);
        
        // Store additional user data in database
        await _database.child('users/${credential.user!.uid}').set({
          'name': name,
          'email': email,
          'createdAt': ServerValue.timestamp,
        });
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Handle Firebase Auth exceptions and return user-friendly messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

  // ============ SUBSTANCES (Firestore) ============

  // Get all substances as a stream
  Stream<QuerySnapshot> getSubstances() {
    return _firestore.collection('substances').snapshots();
  }

  // Get substances by category
  Stream<QuerySnapshot> getSubstancesByCategory(String category) {
    return _firestore
        .collection('substances')
        .where('category', isEqualTo: category)
        .snapshots();
  }

  // Get a single substance by ID
  Future<DocumentSnapshot?> getSubstance(String substanceId) async {
    try {
      final doc = await _firestore.collection('substances').doc(substanceId).get();
      return doc.exists ? doc : null;
    } catch (e) {
      return null;
    }
  }

  // Add a new substance
  Future<DocumentReference> addSubstance({
    required String name,
    required String category,
    required String properties,
    required String description,
    String? severity,
    String? casNumber,
    String? formula,
    String? meltingPoint,
    String? boilingPoint,
    String? density,
    String? solubility,
    String? vaporPressure,
    String? flashPoint,
    String? autoignition,
    String? exposureLimits,
    String? firstAid,
    String? decontamination,
    String? detectionMethods,
    String? protectiveEquipment,
    bool? isActive,
  }) async {
    try {
      final data = {
        'name': name,
        'category': category,
        'properties': properties,
        'description': description,
        'severity': severity ?? 'unknown',
        'casNumber': casNumber,
        'formula': formula,
        'meltingPoint': meltingPoint,
        'boilingPoint': boilingPoint,
        'density': density,
        'solubility': solubility,
        'vaporPressure': vaporPressure,
        'flashPoint': flashPoint,
        'autoignition': autoignition,
        'exposureLimits': exposureLimits,
        'firstAid': firstAid,
        'decontamination': decontamination,
        'detectionMethods': detectionMethods,
        'protectiveEquipment': protectiveEquipment,
        'isActive': isActive ?? true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      final docRef = await _firestore.collection('substances').add(data);
      print('Substance added successfully with ID: ${docRef.id}');
      return docRef;
    } catch (e) {
      print('Error adding substance: $e');
      rethrow;
    }
  }

  // Update an existing substance
  Future<void> updateSubstance({
    required String substanceId,
    String? name,
    String? category,
    String? properties,
    String? description,
    String? severity,
    String? casNumber,
    String? formula,
    String? meltingPoint,
    String? boilingPoint,
    String? density,
    String? solubility,
    String? vaporPressure,
    String? flashPoint,
    String? autoignition,
    String? exposureLimits,
    String? firstAid,
    String? decontamination,
    String? detectionMethods,
    String? protectiveEquipment,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      
      if (name != null) data['name'] = name;
      if (category != null) data['category'] = category;
      if (properties != null) data['properties'] = properties;
      if (description != null) data['description'] = description;
      if (severity != null) data['severity'] = severity;
      if (casNumber != null) data['casNumber'] = casNumber;
      if (formula != null) data['formula'] = formula;
      if (meltingPoint != null) data['meltingPoint'] = meltingPoint;
      if (boilingPoint != null) data['boilingPoint'] = boilingPoint;
      if (density != null) data['density'] = density;
      if (solubility != null) data['solubility'] = solubility;
      if (vaporPressure != null) data['vaporPressure'] = vaporPressure;
      if (flashPoint != null) data['flashPoint'] = flashPoint;
      if (autoignition != null) data['autoignition'] = autoignition;
      if (exposureLimits != null) data['exposureLimits'] = exposureLimits;
      if (firstAid != null) data['firstAid'] = firstAid;
      if (decontamination != null) data['decontamination'] = decontamination;
      if (detectionMethods != null) data['detectionMethods'] = detectionMethods;
      if (protectiveEquipment != null) data['protectiveEquipment'] = protectiveEquipment;
      if (isActive != null) data['isActive'] = isActive;
      
      data['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.collection('substances').doc(substanceId).update(data);
      print('Substance updated successfully with ID: $substanceId');
    } catch (e) {
      print('Error updating substance: $e');
      rethrow;
    }
  }

  // Delete a substance
  Future<void> deleteSubstance(String substanceId) async {
    try {
      await _firestore.collection('substances').doc(substanceId).delete();
      print('Substance deleted successfully with ID: $substanceId');
    } catch (e) {
      print('Error deleting substance: $e');
      rethrow;
    }
  }

  // Search substances by name or properties
  Stream<List<Map<String, dynamic>>> searchSubstances(String searchTerm) {
    final lowerTerm = searchTerm.toLowerCase();
    return _firestore
        .collection('substances')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] as String? ?? '').toLowerCase();
            final properties = (data['properties'] as String? ?? '').toLowerCase();
            final description = (data['description'] as String? ?? '').toLowerCase();
            return name.contains(lowerTerm) ||
                   properties.contains(lowerTerm) ||
                   description.contains(lowerTerm);
          })
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    });
  }

  // Initialize default substances if the collection is empty
  Future<void> initializeDefaultSubstances() async {
    try {
      final snapshot = await _firestore.collection('substances').limit(1).get();
      
      if (snapshot.docs.isEmpty) {
        print('Initializing default substances...');
        
        // Chemical substances
        final chemicals = [
        {
          'name': 'Sarin',
          'category': 'chemical',
          'properties': 'Liquid, Volatile, Lethal',
          'description': 'Nerve agent with rapid inhalation hazards.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Chlorine',
          'category': 'chemical',
          'properties': 'Gas, Greenish, Corrosive',
          'description': 'Respiratory irritant with dense plume behavior.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'VX',
          'category': 'chemical',
          'properties': 'Persistent, Oily',
          'description': 'Extremely toxic nerve agent with surface persistence.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Tabun',
          'category': 'chemical',
          'properties': 'Liquid, Volatile',
          'description': 'First discovered nerve agent with delayed symptoms.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Soman',
          'category': 'chemical',
          'properties': 'Liquid, Volatile',
          'description': 'More potent than tabun with rapid onset.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Cyclosarin',
          'category': 'chemical',
          'properties': 'Liquid, Volatile',
          'description': 'More persistent than sarin with higher toxicity.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Mustard Gas',
          'category': 'chemical',
          'properties': 'Liquid, Vesicant',
          'description': 'Causes severe blistering and respiratory damage.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Lewisite',
          'category': 'chemical',
          'properties': 'Liquid, Vesicant',
          'description': 'Arsenic-based blistering agent with immediate pain.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Phosgene',
          'category': 'chemical',
          'properties': 'Gas, Colorless',
          'description': 'Choking agent causing pulmonary edema.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Hydrogen Cyanide',
          'category': 'chemical',
          'properties': 'Gas, Volatile',
          'description': 'Blood agent preventing cellular respiration.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Cyanogen Chloride',
          'category': 'chemical',
          'properties': 'Gas, Volatile',
          'description': 'Blood agent with rapid incapacitation.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Sulfur Mustard',
          'category': 'chemical',
          'properties': 'Liquid, Vesicant',
          'description': 'Delayed blistering agent with long-term effects.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Nitrogen Mustard',
          'category': 'chemical',
          'properties': 'Liquid, Vesicant',
          'description': 'Blistering agent with alkylating properties.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'BZ',
          'category': 'chemical',
          'properties': 'Solid, Deliriant',
          'description': 'Incapacitating agent causing hallucinations.',
          'severity': 'medium',
          'isActive': true,
        },
        {
          'name': 'Saxitoxin',
          'category': 'chemical',
          'properties': 'Solid, Neurotoxin',
          'description': 'Paralytic shellfish poison with rapid onset.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Ricin',
          'category': 'chemical',
          'properties': 'Solid, Toxin',
          'description': 'Protein toxin derived from castor beans.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Aflatoxin',
          'category': 'chemical',
          'properties': 'Solid, Carcinogen',
          'description': 'Fungal toxin causing liver damage.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Tetrodotoxin',
          'category': 'chemical',
          'properties': 'Solid, Neurotoxin',
          'description': 'Marine toxin causing paralysis.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Botulinum Toxin',
          'category': 'chemical',
          'properties': 'Solid, Neurotoxin',
          'description': 'Most potent biological toxin known.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Agent 15',
          'category': 'chemical',
          'properties': 'Liquid, Deliriant',
          'description': 'Incapacitating agent similar to BZ.',
          'severity': 'medium',
          'isActive': true,
        },
      ];

      // Biological substances
      final biologicals = [
        {
          'name': 'Anthrax',
          'category': 'biological',
          'properties': 'Spore-forming, Durable',
          'description': 'Inhalational risk with long environmental persistence.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Smallpox',
          'category': 'biological',
          'properties': 'Virus, Contagious',
          'description': 'Highly infectious with high mortality rate.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Ebola',
          'category': 'biological',
          'properties': 'Virus, Hemorrhagic',
          'description': 'Severe hemorrhagic fever with high mortality.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Marburg',
          'category': 'biological',
          'properties': 'Virus, Hemorrhagic',
          'description': 'Related to Ebola with similar symptoms.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Plague',
          'category': 'biological',
          'properties': 'Bacteria, Pneumonic',
          'description': 'Highly contagious respiratory infection.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Tularemia',
          'category': 'biological',
          'properties': 'Bacteria, Highly infectious',
          'description': 'Rabbit fever with aerosol transmission risk.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Brucellosis',
          'category': 'biological',
          'properties': 'Bacteria, Zoonotic',
          'description': 'Chronic infection with multiple organ involvement.',
          'severity': 'medium',
          'isActive': true,
        },
        {
          'name': 'Q Fever',
          'category': 'biological',
          'properties': 'Bacteria, Coxiella',
          'description': 'Highly resistant spores with aerosol risk.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Glanders',
          'category': 'biological',
          'properties': 'Bacteria, Burkholderia',
          'description': 'Rare disease with high mortality if untreated.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Melioidosis',
          'category': 'biological',
          'properties': 'Bacteria, Burkholderia',
          'description': 'Similar to glanders with environmental persistence.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Cholera',
          'category': 'biological',
          'properties': 'Bacteria, Waterborne',
          'description': 'Severe diarrheal disease with dehydration risk.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Typhoid',
          'category': 'biological',
          'properties': 'Bacteria, Salmonella',
          'description': 'Systemic infection with high fever.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Dengue',
          'category': 'biological',
          'properties': 'Virus, Mosquito-borne',
          'description': 'Hemorrhagic fever with severe joint pain.',
          'severity': 'medium',
          'isActive': true,
        },
        {
          'name': 'Yellow Fever',
          'category': 'biological',
          'properties': 'Virus, Mosquito-borne',
          'description': 'Hemorrhagic fever with liver involvement.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Lassa',
          'category': 'biological',
          'properties': 'Virus, Arenavirus',
          'description': 'Hemorrhagic fever with hearing loss risk.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Junin',
          'category': 'biological',
          'properties': 'Virus, Arenavirus',
          'description': 'Argentine hemorrhagic fever agent.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Machupo',
          'category': 'biological',
          'properties': 'Virus, Arenavirus',
          'description': 'Bolivian hemorrhagic fever agent.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Guanarito',
          'category': 'biological',
          'properties': 'Virus, Arenavirus',
          'description': 'Venezuelan hemorrhagic fever agent.',
          'severity': 'high',
          'isActive': true,
        },
      ];

      // Radiological substances
      final radiologicals = [
        {
          'name': 'Cesium-137',
          'category': 'radiological',
          'properties': 'Radioactive, Long-lived',
          'description': 'Gamma-emitting fission product.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Cobalt-60',
          'category': 'radiological',
          'properties': 'Radiation Source',
          'description': 'Industrial source for irradiation.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Iodine-131',
          'category': 'radiological',
          'properties': 'Short-lived',
          'description': 'Thyroid uptake risk after exposure.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Strontium-90',
          'category': 'radiological',
          'properties': 'Bone-seeker',
          'description': 'Beta emitter with long half-life.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Plutonium-239',
          'category': 'radiological',
          'properties': 'Alpha emitter',
          'description': 'Heavy metal with lung cancer risk.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Americium-241',
          'category': 'radiological',
          'properties': 'Alpha emitter',
          'description': 'Used in smoke detectors, toxic if inhaled.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Uranium-235',
          'category': 'radiological',
          'properties': 'Fissile',
          'description': 'Enriched uranium for nuclear weapons.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Uranium-238',
          'category': 'radiological',
          'properties': 'Depleted',
          'description': 'Dense metal with chemical toxicity.',
          'severity': 'medium',
          'isActive': true,
        },
        {
          'name': 'Radium-226',
          'category': 'radiological',
          'properties': 'Alpha emitter',
          'description': 'Naturally radioactive, bone seeker.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Polonium-210',
          'category': 'radiological',
          'properties': 'Alpha emitter',
          'description': 'Extremely toxic, lethal in micrograms.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Tritium',
          'category': 'radiological',
          'properties': 'Beta emitter',
          'description': 'Radioactive hydrogen, water contaminant.',
          'severity': 'medium',
          'isActive': true,
        },
        {
          'name': 'Carbon-14',
          'category': 'radiological',
          'properties': 'Beta emitter',
          'description': 'Long-lived environmental tracer.',
          'severity': 'low',
          'isActive': true,
        },
        {
          'name': 'Krypton-85',
          'category': 'radiological',
          'properties': 'Noble gas',
          'description': 'Fission product, atmospheric dispersion.',
          'severity': 'medium',
          'isActive': true,
        },
        {
          'name': 'Xenon-133',
          'category': 'radiological',
          'properties': 'Noble gas',
          'description': 'Medical imaging isotope, short half-life.',
          'severity': 'low',
          'isActive': true,
        },
        {
          'name': 'Technetium-99m',
          'category': 'radiological',
          'properties': 'Gamma emitter',
          'description': 'Medical imaging isotope, widely used.',
          'severity': 'low',
          'isActive': true,
        },
        {
          'name': 'Iridium-192',
          'category': 'radiological',
          'properties': 'Gamma emitter',
          'description': 'Industrial radiography source.',
          'severity': 'high',
          'isActive': true,
        },
        {
          'name': 'Cobalt-57',
          'category': 'radiological',
          'properties': 'Gamma emitter',
          'description': 'Medical imaging and calibration source.',
          'severity': 'medium',
          'isActive': true,
        },
        {
          'name': 'Barium-140',
          'category': 'radiological',
          'properties': 'Beta emitter',
          'description': 'Fission product with short half-life.',
          'severity': 'medium',
          'isActive': true,
        },
        {
          'name': 'Cerium-144',
          'category': 'radiological',
          'properties': 'Beta emitter',
          'description': 'Fission product, significant heat source.',
          'severity': 'medium',
          'isActive': true,
        },
        {
          'name': 'Promethium-147',
          'category': 'radiological',
          'properties': 'Beta emitter',
          'description': 'Used in nuclear batteries, long-lived.',
          'severity': 'medium',
          'isActive': true,
        },
      ];

      // Nuclear substances
      final nuclears = [
        {
          'name': 'Uranium-235',
          'category': 'nuclear',
          'properties': 'Fissile, Heavy metal',
          'description': 'Criticality risk in enriched states.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Plutonium-239',
          'category': 'nuclear',
          'properties': 'Fissile, Alpha emitter',
          'description': 'Requires strict contamination controls.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Uranium-238',
          'category': 'nuclear',
          'properties': 'Dense, Toxic',
          'description': 'Depleted uranium handling protocols.',
          'severity': 'medium',
          'isActive': true,
        },
        {
          'name': 'Uranium-233',
          'category': 'nuclear',
          'properties': 'Fissile, Artificial',
          'description': 'Breeder reactor fuel material.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Plutonium-240',
          'category': 'nuclear',
          'properties': 'Fissile, Spontaneous',
          'description': 'High spontaneous fission rate.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Plutonium-241',
          'category': 'nuclear',
          'properties': 'Fissile, Beta emitter',
          'description': 'Decays to americium-241.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Neptunium-237',
          'category': 'nuclear',
          'properties': 'Fissile, Artificial',
          'description': 'Byproduct of nuclear reactors.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Americium-241',
          'category': 'nuclear',
          'properties': 'Fissile, Alpha emitter',
          'description': 'Produced in nuclear reactors.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Curium-244',
          'category': 'nuclear',
          'properties': 'Fissile, Alpha emitter',
          'description': 'High heat output, potential fuel.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Californium-252',
          'category': 'nuclear',
          'properties': 'Neutron source',
          'description': 'Spontaneous fission neutron emitter.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Thorium-232',
          'category': 'nuclear',
          'properties': 'Fertile, Natural',
          'description': 'Potential breeder reactor fuel.',
          'severity': 'medium',
          'isActive': true,
        },
        {
          'name': 'Thorium-233',
          'category': 'nuclear',
          'properties': 'Fissile, Artificial',
          'description': 'Intermediate in thorium cycle.',
          'severity': 'critical',
          'isActive': true,
        },
        {
          'name': 'Deuterium',
          'category': 'nuclear',
          'properties': 'Fusion fuel',
          'description': 'Heavy hydrogen for fusion reactors.',
          'severity': 'low',
          'isActive': true,
        },
        {
          'name': 'Tritium',
          'category': 'nuclear',
          'properties': 'Fusion fuel',
          'description': 'Radioactive hydrogen for fusion.',
          'severity': 'medium',
          'isActive': true,
        },
        {
          'name': 'Lithium-6',
          'category': 'nuclear',
          'properties': 'Fusion breeding',
          'description': 'Produces tritium in fusion reactions.',
          'severity': 'low',
          'isActive': true,
        },
        {
          'name': 'Lithium-7',
          'category': 'nuclear',
          'properties': 'Fusion breeding',
          'description': 'Neutron source in fusion reactions.',
          'severity': 'low',
          'isActive': true,
        },
        {
          'name': 'Beryllium-9',
          'category': 'nuclear',
          'properties': 'Neutron multiplier',
          'description': 'Reflects and multiplies neutrons.',
          'severity': 'low',
          'isActive': true,
        },
        {
          'name': 'Boron-10',
          'category': 'nuclear',
          'properties': 'Neutron absorber',
          'description': 'Control rod material for reactors.',
          'severity': 'low',
          'isActive': true,
        },
        {
          'name': 'Cadmium-113',
          'category': 'nuclear',
          'properties': 'Neutron absorber',
          'description': 'Control rod material for reactors.',
          'severity': 'low',
          'isActive': true,
        },
        {
          'name': 'Hafnium-178',
          'category': 'nuclear',
          'properties': 'Neutron absorber',
          'description': 'Control rod material for reactors.',
          'severity': 'low',
          'isActive': true,
        },
      ];

      // Add all substances to Firestore
      final batch = _firestore.batch();
      
      for (final chemical in chemicals) {
        final docRef = _firestore.collection('substances').doc();
        batch.set(docRef, {
          ...chemical,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      for (final biological in biologicals) {
        final docRef = _firestore.collection('substances').doc();
        batch.set(docRef, {
          ...biological,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      for (final radiological in radiologicals) {
        final docRef = _firestore.collection('substances').doc();
        batch.set(docRef, {
          ...radiological,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      for (final nuclear in nuclears) {
        final docRef = _firestore.collection('substances').doc();
        batch.set(docRef, {
          ...nuclear,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      print('Default substances initialized successfully');
      }
    } catch (e) {
      print('Error initializing default substances: $e');
      rethrow;
    }
  }

  // Update mission status
  Future<void> updateMissionStatus({
    required bool isRunning,
    required bool isPaused,
    required String pattern,
  }) async {
    await _database.child('mission').set({
      'isRunning': isRunning,
      'isPaused': isPaused,
      'pattern': pattern,
      'lastUpdate': ServerValue.timestamp,
    });
  }

  // Get mission status stream
  Stream<Map<String, dynamic>> getMissionStatus() {
    return _database.child('mission').onValue.map((event) {
      if (event.snapshot.value == null) {
        return {
          'isRunning': false,
          'isPaused': false,
          'pattern': 'Grid',
        };
      }
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  // Update drone position
  Future<void> updateDronePosition({
    required int droneId,
    required String name,
    required double lat,
    required double lng,
    required int battery,
    required String status,
  }) async {
    await _database.child('drones/drone$droneId').set({
      'id': droneId,
      'name': name,
      'lat': lat,
      'lng': lng,
      'battery': battery,
      'status': status,
      'lastUpdate': ServerValue.timestamp,
    });
  }

  // Get drone positions stream
  Stream<Map<String, dynamic>> getDronePositions() {
    return _database.child('drones').onValue.map((event) {
      if (event.snapshot.value == null) {
        return {};
      }
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  // Update hazardous zone
  Future<void> updateHazardousZone({
    required String zoneId,
    required String name,
    required double lat,
    required double lng,
    required double radiusKm,
    required String severity,
    required String substanceType,
    required bool detected,
  }) async {
    await _database.child('hazardousZones/$zoneId').set({
      'name': name,
      'lat': lat,
      'lng': lng,
      'radiusKm': radiusKm,
      'severity': severity,
      'substanceType': substanceType,
      'detected': detected,
      'lastUpdate': ServerValue.timestamp,
    });
  }

  // Get hazardous zones stream
  Stream<Map<String, dynamic>> getHazardousZones() {
    return _database.child('hazardousZones').onValue.map((event) {
      if (event.snapshot.value == null) {
        return {};
      }
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }
}