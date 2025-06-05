import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilCompletPage extends StatefulWidget {
  const ProfilCompletPage({super.key});

  @override
  State<ProfilCompletPage> createState() => _ProfilCompletPageState();
}

class _ProfilCompletPageState extends State<ProfilCompletPage> {
  Map<String, dynamic>? userData;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data['photoBase64'] != null && data['photoBase64'].isNotEmpty) {
          _imageBytes = base64Decode(data['photoBase64']);
        }
        setState(() {
          userData = data;
        });
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label : ",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil Complet"),
        backgroundColor: const Color.fromARGB(0, 233, 230, 230),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage: _imageBytes != null ? MemoryImage(_imageBytes!) : null,
                child: _imageBytes == null
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(height: 30),
            _buildInfoRow("Adresse", userData!['adresse'] ?? ''),
            _buildInfoRow("Poste", userData!['poste'] ?? ''),
            _buildInfoRow("Niveau d'étude", userData!['niveauEtude'] ?? ''),
            _buildInfoRow("Acte de naissance", userData!['acteDeNaissance'] ?? ''),
            _buildInfoRow("Diplômes", userData!['diplomes'] ?? ''),
            _buildInfoRow("Personne à contacter", userData!['personneAContacter'] ?? ''),
          ],
        ),
      ),
    );
  }
}
