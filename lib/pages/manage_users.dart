import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  _ManageUsersPageState createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedRole = "Employé"; // Rôle par défaut

  Future<void> _addUser() async {
    if (_emailController.text.isEmpty || _phoneController.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('users').add({
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'role': _selectedRole,
    });

    _emailController.clear();
    _phoneController.clear();
    Navigator.pop(context); // Fermer la boîte de dialogue
  }

  Future<void> _deleteUser(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestion des Utilisateurs"), backgroundColor: Colors.red),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.red));

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              return ListTile(
                title: Text(doc['email']),
                subtitle: Text("${doc['phone']} - ${doc['role']}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteUser(doc.id),
                ),
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
              title: const Text("Ajouter un utilisateur"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
                  TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "Téléphone")),
                  DropdownButton<String>(
                    value: _selectedRole,
                    items: ["Administrateur", "Gérant", "Employé"].map((role) {
                      return DropdownMenuItem(value: role, child: Text(role));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedRole = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
                TextButton(onPressed: _addUser, child: const Text("Ajouter", style: TextStyle(color: Colors.red))),
              ],
            ),
          );
        },
      ),
    );
  }
}
