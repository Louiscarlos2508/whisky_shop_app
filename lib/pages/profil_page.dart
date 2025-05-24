import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await _firestore.collection('users').doc(widget.userId).get();
      if (!doc.exists) {
        print("Aucun document trouvé pour cet ID");
        return;
      }
      final data = doc.data();
      print("Données récupérées : $data");

      if (data != null) {
        setState(() {
          _fullNameController.text = data['fullName'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _selectedRole = (data['role'] != null) ? data['role'] as String : null;
          _selectedEducationLevel = (data['educationLevel'] != null) ? data['educationLevel'] as String : null;
          _isRegisteredCnss = data['cnssDeclared'] ?? false;
          _startDateController.text = data['startDate'] ?? '';
          _maritalStatusController.text = data['maritalStatus'] ?? '';
          _addressController.text = data['adresse'] ?? '';
          _emergencyContactController.text = data['emergencyContact'] ?? '';
          _pieceIdentiteUrl = (data['pieceIdentite'] != null) ? data['pieceIdentite'] as String : null;
          _acteDeNaissanceUrl = data['acte_de_naissance']?.toString();
          if (_acteDeNaissanceUrl?.trim().isEmpty ?? true) {
            _acteDeNaissanceUrl = null;
          }

        });
      }
    } catch (e) {
      print("Erreur lors du chargement des données : $e");
    }
  }


  Future<void> _uploadDocument(String type) async {
    print("Début upload document pour $type");
    final result = await FilePicker.platform.pickFiles();
    if (result == null) {
      print("Aucun fichier sélectionné");
      return;
    }
    final path = result.files.single.path;
    if (path == null) {
      print("Le chemin du fichier est null");
      return;
    }
    final file = File(path);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('documents/${widget.userId}/$type.pdf');
      print("Début upload vers Firebase Storage...");
      await ref.putFile(file);
      print("Upload terminé. Récupération URL...");
      final url = await ref.getDownloadURL();
      print("URL obtenu : $url");
      await _firestore.collection('users').doc(widget.userId).update({
        type: url,
      });
      if (kDebugMode) {
        print("URL sauvegardée dans Firestore.");
      }
      setState(() {
        if (type == 'acte_de_naissance') {
          _acteDeNaissanceUrl = url;
        } else if (type == 'pieceIdentite') {
          _pieceIdentiteUrl = url;
        }
      });
    } catch (e) {
      print("Erreur lors de l'upload: $e");
    }
  }


  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      enabled: false,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _buildUploadSection(String label, String type) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ElevatedButton(
            onPressed: () => _uploadDocument(type),
            child: Text("Téléverser"),
          )
        ],
      ),
    );

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profil de l'utilisateur")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            if (_acteDeNaissanceUrl == null || _acteDeNaissanceUrl!.trim().isEmpty)
              _buildUploadSection("Acte de naissance", 'acte_de_naissance'),
            if (_pieceIdentiteUrl == null || _pieceIdentiteUrl!.isEmpty)
              _buildUploadSection("Pièce d'identité", 'pieceIdentite'),
          ],
        ),
      ),
    );
  }
}
