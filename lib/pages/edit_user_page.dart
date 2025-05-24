import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class EditUserPage extends StatefulWidget {
  final String userId;
  const EditUserPage({super.key, required this.userId});

  @override
  _EditUserPageState createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  String _errorMessage = '';

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _maritalStatusController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();

  String? _identityDocUrl;
  String? _birthCertUrl;
  bool _identityDocValidated = false;
  bool _birthCertValidated = false;

  String? _selectedRole;
  String? _selectedEducationLevel;
  bool _isRegisteredCnss = false;

  List<String> _rolesFromDb = [];
  final List<String> _educationLevels = [
    'Aucun',
    'Primaire',
    'Secondaire',
    'Universitaire',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _loadRoles().then((_) => _loadUser());
  }

  Future<void> _loadRoles() async {
    try {
      final snapshot = await _firestore.collection('roles').get();
      final roles = snapshot.docs.map((doc) => doc['name'].toString()).toList();
      setState(() {
        _rolesFromDb = roles;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur lors du chargement des rôles : $e";
      });
    }
  }

  Future<void> _loadUser() async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(widget.userId).get();
      if (!doc.exists) {
        setState(() {
          _errorMessage = "Utilisateur non trouvé";
          _loading = false;
        });
        return;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      _fullNameController.text = data['fullName'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _startDateController.text = data['startDate'] ?? '';
      _maritalStatusController.text = data['maritalStatus'] ?? '';
      _identityDocUrl = data['identityDoc'];
      _birthCertUrl = data['birthCert'];
      _identityDocValidated = data['identityDocValidated'] ?? false;
      _birthCertValidated = data['birthCertValidated'] ?? false;
      _selectedRole = data['role'];
      _selectedEducationLevel = data['educationLevel'] ?? _educationLevels[0];
      _isRegisteredCnss = data['registeredCnss'] ?? false;
      _addressController.text = data['adresse'] ?? '';
      _emergencyContactController.text = data['emergencyContact'] ?? '';

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur lors du chargement de l'utilisateur : $e";
        _loading = false;
      });
    }
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez sélectionner un rôle.")),
      );
      return;
    }

    try {
      await _firestore.collection('users').doc(widget.userId).update({
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
        'educationLevel': _selectedEducationLevel,
        'registeredCnss': _isRegisteredCnss,
        'startDate': _startDateController.text.trim(),
        'maritalStatus': _maritalStatusController.text.trim(),
        'adresse': _addressController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Utilisateur mis à jour avec succès")),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la mise à jour : $e")),
      );
    }
  }

  Future<void> _rejectDocument(String docType) async {
    bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rejeter le document"),
        content: const Text(
            "Voulez-vous vraiment rejeter ce document ? Une notification sera envoyée à l'utilisateur."),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Annuler")),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Rejeter", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ??
        false;

    if (!confirm) return;

    try {
      await _firestore.collection('users').doc(widget.userId).update({
        docType: FieldValue.delete(),
        '${docType}Validated': false,
      });

      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('notifications')
          .add({
        'message': "$docType a été rejeté. Veuillez le soumettre à nouveau.",
        'timestamp': Timestamp.now(),
        'seen': false,
        'type': 'rejet',
        'link': '/profile/${widget.userId}',
        'title': "Rejet de document"
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$docType rejeté et notification envoyée.")),
      );

      setState(() {
        if (docType == 'pieceIdentite') {
          _identityDocUrl = null;
          _identityDocValidated = false;
        }
        if (docType == 'acte_de_naissance') {
          _birthCertUrl = null;
          _birthCertValidated = false;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors du rejet : $e")),
      );
    }
  }

  Widget _buildDocumentCard({
    required String docType,
    required String title,
    required String? docUrl,
    required bool validated,
  }) {
    if (docUrl == null) {
      return Card(
        child: ListTile(
          title: Text(title),
          subtitle: const Text("Aucun document soumis"),
        ),
      );
    }

    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(validated ? "Validé" : "Non validé"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () async {
                final uri = Uri.parse(docUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            if (!validated)
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                onPressed: () => _rejectDocument(docType),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _startDateController.dispose();
    _maritalStatusController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Modifier utilisateur")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Modifier utilisateur")),
        body: Center(
          child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Modifier utilisateur"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: "Nom complet",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                validator: (value) =>
                value == null || value.isEmpty ? "Nom requis" : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: "Téléphone",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                value == null || value.isEmpty ? "Téléphone requis" : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                items: _rolesFromDb
                    .map((role) => DropdownMenuItem(
                  value: role,
                  child: Text(role),
                ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedRole = val),
                decoration: const InputDecoration(
                  labelText: "Rôle",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                validator: (val) => val == null ? "Rôle requis" : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedEducationLevel,
                items: _educationLevels
                    .map((level) => DropdownMenuItem(
                  value: level,
                  child: Text(level),
                ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedEducationLevel = val),
                decoration: const InputDecoration(
                  labelText: "Niveau d'études",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text("Inscrit à la CNSS"),
                value: _isRegisteredCnss,
                onChanged: (val) => setState(() => _isRegisteredCnss = val),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _startDateController,
                decoration: const InputDecoration(
                  labelText: "Date d'embauche (yyyy-MM-dd)",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                keyboardType: TextInputType.datetime,
                validator: (val) {
                  if (val == null || val.isEmpty) return "Date d'embauche requise";
                  try {
                    DateFormat('yyyy-MM-dd').parseStrict(val);
                  } catch (e) {
                    return "Format invalide (yyyy-MM-dd)";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _maritalStatusController,
                decoration: const InputDecoration(
                  labelText: "Situation familiale",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: "Adresse",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emergencyContactController,
                decoration: const InputDecoration(
                  labelText: "Contact d'urgence",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Documents justificatifs",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),

              _buildDocumentCard(
                docType: 'identityDoc',
                title: "Pièce d'identité",
                docUrl: _identityDocUrl,
                validated: _identityDocValidated,
              ),

              _buildDocumentCard(
                docType: 'birthCert',
                title: "Acte de naissance",
                docUrl: _birthCertUrl,
                validated: _birthCertValidated,
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveUser,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text("Sauvegarder", style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
