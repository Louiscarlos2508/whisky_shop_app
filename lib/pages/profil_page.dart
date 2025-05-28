import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilPage extends StatefulWidget {
  final String userId;

  const ProfilPage({required this.userId, super.key});

  @override
  State<ProfilPage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilPage> {
  final _firestore = FirebaseFirestore.instance;

  final _fullNameController = TextEditingController();
  final _roleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _startDateController = TextEditingController();
  //final _maritalStatusController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  bool _isEducationLevelEditable = true;
  bool _isStartDateEditable = true;
  bool _isMaritalStatusEditable = true;
  bool _isAddressEditable = true;
  bool _isEmergencyContactEditable = true;


  String? _selectedRole;
  String? _selectedEducationLevel;
  String? _selectedMaritalStatuses;
  bool _isRegisteredCnss = false;

  String? _acteDeNaissanceUrl;
  String? _pieceIdentiteUrl;

  File? _selectedFile;
  String? _selectedFileType;
  List<String> _educationLevels = [];

  List<String> _maritalStatuses = [];
  String _errorMessage = '';


  Future<void> _loadEducationLevels() async {
    try {
      final doc = await _firestore.collection('settings').doc('education_levels').get();
      final levels = List<String>.from(doc['name']);
      setState(() {
        _educationLevels = levels;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur lors du chargement des niveaux d'études : $e";
      });
    }
  }

  Future<void> _loadMaritalStatuses() async {
    try {
      final doc = await _firestore.collection('settings').doc('marital_statuses').get();
      final statuses = List<String>.from(doc['name']);

      print("Statuts matrimoniaux chargés : $statuses"); // 👈 DEBUG ici
      setState(() {
        _maritalStatuses = statuses;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur lors du chargement des statuts matrimoniaux : $e";
      });
    }
  }


  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadEducationLevels();
    _loadMaritalStatuses();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await _firestore.collection('users').doc(widget.userId).get();
      if (!doc.exists) return;
      final data = doc.data();
      setState(() {
        _fullNameController.text = data?['fullName'] ?? '';
        _phoneController.text = data?['phone'] ?? '';
        _selectedRole = data?['role'];
        _roleController.text = _selectedRole ?? '';
        _selectedEducationLevel = data?['educationLevel'];
        _isRegisteredCnss = data?['cnssDeclared'] ?? false;
        _startDateController.text = data?['startDate'] ?? '';
        //_maritalStatusController.text = data?['maritalStatus'] ?? '';
        _selectedMaritalStatuses = data?['maritalStatus'];
        _addressController.text = data?['adresse'] ?? '';
        _emergencyContactController.text = data?['emergencyContact'] ?? '';
        _pieceIdentiteUrl = data?['pieceIdentite'];
        _acteDeNaissanceUrl = data?['acte_de_naissance'];

        _isEducationLevelEditable = (_selectedEducationLevel == null || _selectedEducationLevel!.isEmpty);
        _isMaritalStatusEditable = (_selectedMaritalStatuses == null || _selectedMaritalStatuses!.isEmpty);
        //_isMaritalStatusEditable = _maritalStatusController.text.isEmpty;

        //_isEducationLevelEditable = (_selectedEducationLevel == null || _selectedEducationLevel!.isEmpty);
        _isStartDateEditable = _startDateController.text.isEmpty;
        //_isMaritalStatusEditable = _maritalStatusController.text.isEmpty;
        _isAddressEditable = _addressController.text.isEmpty;
        _isEmergencyContactEditable = _emergencyContactController.text.isEmpty;
      });
    } catch (e) {
      print("Erreur chargement données : $e");
    }
  }

  Widget _buildDropdownField({
    required String label,
    required List<String> items,
    required String? selectedValue,
    required bool enabled,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        onChanged: enabled ? onChanged : null,
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }


  Future<void> _pickDocument(String type) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _selectedFileType = type;
      });
    }
  }

  Future<void> _confirmUpload() async {
    if (_selectedFile == null || _selectedFileType == null) return;

    final extension = _selectedFile!.path.split('.').last;

    final ref = FirebaseStorage.instance
        .ref()
        .child('documents/${widget.userId}/$_selectedFileType.$extension');

    try {
      await ref.putFile(_selectedFile!);

      final url = await ref.getDownloadURL();

      await _firestore.collection('users').doc(widget.userId).update({
        _selectedFileType!: url,
      });

      setState(() {
        if (_selectedFileType == 'acte_de_naissance') {
          _acteDeNaissanceUrl = url;
        } else {
          _pieceIdentiteUrl = url;
        }
        _selectedFile = null;
        _selectedFileType = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Document téléversé avec succès.'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      print("Erreur upload : $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur lors du téléversement.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }


  Widget _buildUploadSection(String label, String type, String? url) {
    final isSelected = _selectedFile != null && _selectedFileType == type;

    // LOGIQUE STRICTE APPLIQUÉE
    if (url != null && url.isNotEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: Icon(Icons.visibility),
                label: Text("Voir le document"),
                onPressed: () => launchUrl(Uri.parse(url)),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (!isSelected)
              ElevatedButton(
                onPressed: () => _pickDocument(type),
                child: Text("Choisir un fichier"),
              ),
            if (isSelected) ...[
              Text("Fichier sélectionné : ${_selectedFile!.path.split('/').last}"),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _confirmUpload,
                    icon: Icon(Icons.upload),
                    label: Text("Confirmer"),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedFile = null;
                      _selectedFileType = null;
                    }),
                    child: Text("Annuler"),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
  Future<void> _saveUserProfile() async {
    try {
      await _firestore.collection('users').doc(widget.userId).update({
        if (_selectedEducationLevel != null && _isEducationLevelEditable)
          'educationLevel': _selectedEducationLevel,
        if (_startDateController.text.isNotEmpty && _isStartDateEditable)
          'startDate': _startDateController.text,
        if (_selectedMaritalStatuses != null && _isMaritalStatusEditable)
          'maritalStatus': _selectedMaritalStatuses,
        if (_addressController.text.isNotEmpty && _isAddressEditable)
          'adresse': _addressController.text,
        if (_emergencyContactController.text.isNotEmpty && _isEmergencyContactEditable)
          'emergencyContact': _emergencyContactController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Profil mis à jour."), backgroundColor: Colors.green),
      );

      setState(() {
        _isEducationLevelEditable = false;
        _isStartDateEditable = false;
        _isMaritalStatusEditable = false;
        _isAddressEditable = false;
        _isEmergencyContactEditable = false;
      });
    } catch (e) {
      print("Erreur mise à jour profil : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la mise à jour du profil."), backgroundColor: Colors.red),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profil de l'utilisateur"), centerTitle: true,),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField("Nom complet", _fullNameController, enabled: false),
            _buildTextField("Téléphone", _phoneController, enabled: false),
            _buildTextField("Rôle", _roleController, enabled: false),
            Row(
              children: [
                Checkbox(value: _isRegisteredCnss, onChanged: null),
                Text("Déclaré à la CNSS")
              ],
            ),

            TextFormField(
              controller: _startDateController,
              readOnly: true,
              enabled: _isStartDateEditable,
              decoration: InputDecoration(
                labelText: "Date de début",
                border: OutlineInputBorder(),
              ),
              onTap: () async {
                if (!_isStartDateEditable) return;
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  setState(() {
                    _startDateController.text =
                    "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                  });
                }
              },
            ),
            _buildDropdownField(
              label: "Niveau d'étude",
              items: _educationLevels,
              selectedValue: _selectedEducationLevel,
              enabled: _isEducationLevelEditable,
              onChanged: (value) {
                setState(() {
                  _selectedEducationLevel = value;
                });
              },
            ),
            _buildDropdownField(
              label: "Statut matrimonial",
              items: _maritalStatuses,
              selectedValue: _selectedMaritalStatuses,
              enabled: _isMaritalStatusEditable,
              onChanged: (value) {
                setState(() {
                  _selectedMaritalStatuses = value;
                });
              },
            ),
            _buildTextField("Adresse", _addressController, enabled: _isAddressEditable),
            _buildTextField("Contact d'urgence", _emergencyContactController, enabled: _isEmergencyContactEditable),

            const SizedBox(height: 16),
            _buildUploadSection("Pièce d'identité", "pieceIdentite", _pieceIdentiteUrl),
            _buildUploadSection("Acte de naissance", "acte_de_naissance", _acteDeNaissanceUrl),

            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saveUserProfile,
              icon: Icon(Icons.save),
              label: Text("Enregistrer"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
