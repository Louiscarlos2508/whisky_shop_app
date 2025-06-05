import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:open_file/open_file.dart';
import 'package:archive/archive.dart';

class ProfilPage extends StatefulWidget {
  final String userId;

  const ProfilPage({required this.userId, super.key});

  @override
  State<ProfilPage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilPage> {
  final _firestore = FirebaseFirestore.instance;

  bool _isUploading = false;
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
  String? _profilePhotoBase64;
  final int _maxImageSizeBytes = 900 * 1024; // 900 Ko max (par sécurité)


  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      // Compression
      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        quality: 60,
        format: CompressFormat.jpeg,
      );

      if (compressed != null) {
        if (compressed.length > _maxImageSizeBytes) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("L’image est trop lourde. Choisissez une image plus légère.")),
          );
          return;
        }

        final base64Image = base64Encode(compressed);

        // Sauvegarde dans Firestore
        await _firestore.collection('users').doc(widget.userId).update({
          'profilePhoto': base64Image,
        });

        setState(() {
          _profilePhotoBase64 = base64Image;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Photo de profil mise à jour")),
        );
      }
    }
  }
  Widget _buildProfilePhoto() {
    final imageProvider = _profilePhotoBase64 != null
        ? MemoryImage(base64Decode(_profilePhotoBase64!))
        : AssetImage('assets/avatar.jpeg') as ImageProvider;

    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              if (_profilePhotoBase64 != null) {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: Image.memory(base64Decode(_profilePhotoBase64!)),
                  ),
                );
              }
            },
            child: CircleAvatar(
              radius: 60,
              backgroundImage: imageProvider,
              backgroundColor: Colors.grey[200],
            ),
          ),
          Positioned(
            bottom: 0,
            right: 4,
            child: GestureDetector(
              onTap: _pickProfilePhoto,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blue,
                child: Icon(Icons.edit, size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Future<void> _loadEducationLevels() async {
    try {
      final doc = await _firestore.collection('settings').doc('education_levels').get();
      final levels = List<String>.from(doc['name']);
      setState(() {
        _educationLevels = levels;
      });
    } catch (e) {
      setState(() {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"Erreur lors du chargement des niveaux d\'études : $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des statuts matrimoniaux : $e')),
        );
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
        _profilePhotoBase64 = data?['profilePhoto'];

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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final fileSize = await file.length();

      if (fileSize > _maxImageSizeBytes) {
        // Affiche un message d'erreur si fichier > 1 Mo
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Le fichier ne doit pas dépasser 1 Mo.'),
          backgroundColor: Colors.red,
        ));
        return; // Stoppe la fonction
      }

      setState(() {
        _selectedFile = file;
        _selectedFileType = type;
      });
    }
  }



  Future<void> _confirmUpload() async {
    if (_selectedFile == null || _selectedFileType == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final bytes = await _selectedFile!.readAsBytes();

      // 1. Création d’un fichier ZIP contenant le fichier sélectionné
      final archive = Archive()
        ..addFile(ArchiveFile(
          _selectedFile!.path.split('/').last,
          bytes.length,
          bytes,
        ));
      final zippedBytes = ZipEncoder().encode(archive)!;

      // 2. Encodage en base64
      final base64Zip = base64Encode(zippedBytes);

      // 3. Vérifie la limite Firestore
      if (base64Zip.length > _maxImageSizeBytes) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Fichier trop lourd même compressé. Choisissez un fichier plus léger.'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      // 4. Envoi dans Firestore
      await _firestore.collection('users').doc(widget.userId).update({
        _selectedFileType!: base64Zip,
      });

      setState(() {
        if (_selectedFileType == 'acte_de_naissance') {
          _acteDeNaissanceUrl = 'UPLOADED';
        } else if (_selectedFileType == 'pieceIdentite') {
          _pieceIdentiteUrl = 'UPLOADED';
        }
        _selectedFile = null;
        _selectedFileType = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Document compressé et stocké avec succès.'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      print("Erreur stockage : $e");
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur lors du stockage du document.'),
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
    if (url != null && url.isNotEmpty && url != 'UPLOADED') {
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
                onPressed: () async {
                  if (url.isNotEmpty) {
                    await OpenFile.open(_selectedFile!.path);
                  }
                },
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
                child: Text("Choisir un fichier", style: TextStyle(color: Colors.blue),),
              ),
            if (isSelected) ...[
              Text("Fichier sélectionné : ${_selectedFile!.path.split('/').last}"),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _confirmUpload,
                    icon: _isUploading
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                    )
                        : Icon(Icons.upload),
                    label: Text(
                      _isUploading ? "Chargement..." : "Confirmer",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedFile = null;
                      _selectedFileType = null;
                    }),
                    child: Text("Annuler", style: TextStyle(color: Colors.blue),),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                icon: Icon(Icons.visibility),
                label: Text("Prévisualiser", style: TextStyle(color: Colors.blue),),
                onPressed: () async {
                  await OpenFile.open(_selectedFile!.path);
                },
              ),
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

  bool _documentsCompletementValides() {
    return (_selectedEducationLevel != null && _startDateController.text.isNotEmpty &&
        _selectedMaritalStatuses != null && _addressController.text.isNotEmpty &&
        _emergencyContactController.text.isNotEmpty);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mon Profil"), centerTitle: true,),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfilePhoto(),
            const SizedBox(height: 16),
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
            if (_pieceIdentiteUrl == null || _pieceIdentiteUrl == 'UPLOADED')
              _buildUploadSection("Pièce d'identité", "pieceIdentite", _pieceIdentiteUrl),

            if (_acteDeNaissanceUrl == null || _acteDeNaissanceUrl == 'UPLOADED')
              _buildUploadSection("Acte de naissance", "acte_de_naissance", _acteDeNaissanceUrl),


            const SizedBox(height: 20),
            if (!_documentsCompletementValides())
              ElevatedButton.icon(
                onPressed: _saveUserProfile,
                icon: Icon(Icons.save, color: Colors.white),
                label: Text("Enregistrer", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.green,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
