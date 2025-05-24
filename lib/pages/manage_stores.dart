// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageStoresPage extends StatefulWidget {
  const ManageStoresPage({super.key});

  @override
  _ManageStoresPageState createState() => _ManageStoresPageState();
}

class _ManageStoresPageState extends State<ManageStoresPage> {
  final TextEditingController _storeNameController = TextEditingController();
  String? _selectedGerant;
  
  Future<void> _addStore() async {
    if (_storeNameController.text.isEmpty || _selectedGerant == null) return;

    await FirebaseFirestore.instance.collection('stores').add({
      'name': _storeNameController.text.trim(),
      'gerant': _selectedGerant,
    });

    _storeNameController.clear();
    Navigator.pop(context); // Fermer la boîte de dialogue
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestion des Points de Vente"), backgroundColor: Colors.red),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('stores').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.red));

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              return ListTile(
                title: Text(doc['name']),
                subtitle: Text("Gérant: ${doc['gerant']}"),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        child: const Icon(Icons.add),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Ajouter un Point de Vente"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: _storeNameController, decoration: const InputDecoration(labelText: "Nom du Point de Vente")),
                  StreamBuilder(
                    stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: "Gérant").snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator(color: Colors.red);
                      return DropdownButton<String>(
                        value: _selectedGerant,
                      items: snapshot.data!.docs.map((doc) {
                      return DropdownMenuItem<String>(
                        value: doc['email'], 
                        child: Text(doc['email']),
                      );
                                            }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedGerant = newValue; // ✅ Met à jour la valeur sélectionnée
                        });
                      },
                    );
                    
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
                TextButton(onPressed: _addStore, child: const Text("Ajouter", style: TextStyle(color: Colors.red))),
              ],
            ),
          );
        },
      ),
    );
  }
}
