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
  final _phoneController = TextEditingController();
  final _startDateController = TextEditingController();
  final _maritalStatusController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  String? _selectedRole;
  String? _selectedEducationLevel;
  bool _isRegisteredCnss = false;

  String? _acteDeNaissanceUrl;
  String? _pieceIdentiteUrl;

  File? _selectedFile;
  String? _selectedFileType;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
        _selectedEducationLevel = data?['educationLevel'];
        _isRegisteredCnss = data?['cnssDeclared'] ?? false;
        _startDateController.text = data?['startDate'] ?? '';
        _maritalStatusController.text = data?['maritalStatus'] ?? '';
        _addressController.text = data?['adresse'] ?? '';
        _emergencyContactController.text = data?['emergencyContact'] ?? '';
        _pieceIdentiteUrl = data?['pieceIdentite'];
        _acteDeNaissanceUrl = data?['acte_de_naissance'];
      });
    } catch (e) {
      print("Erreur chargement données : $e");
    }
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

    final ref = FirebaseStorage.instance
        .ref()
        .child('documents/${widget.userId}/$_selectedFileType.pdf');

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

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        enabled: false,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profil de l'utilisateur"), centerTitle: true,),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField("Nom complet", _fullNameController),
            _buildTextField("Téléphone", _phoneController),
            _buildTextField("Rôle", TextEditingController(text: _selectedRole ?? '')),
            _buildTextField("Niveau d'éducation", TextEditingController(text: _selectedEducationLevel ?? '')),
            Row(
              children: [
                Checkbox(value: _isRegisteredCnss, onChanged: null),
                Text("Déclaré à la CNSS")
              ],
            ),
            _buildTextField("Date de début", _startDateController),
            _buildTextField("Statut matrimonial", _maritalStatusController),
            _buildTextField("Adresse", _addressController),
            _buildTextField("Contact d'urgence", _emergencyContactController),
            SizedBox(height: 20),
            _buildUploadSection("Acte de naissance", 'acte_de_naissance', _acteDeNaissanceUrl),
            _buildUploadSection("Pièce d'identité", 'pieceIdentite', _pieceIdentiteUrl),
          ],
        ),
      ),
    );
  }
}
