import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:whiskyshop_app/pages/signup.dart';
import 'edit_user_page.dart';

class GestionUtilisateurs extends StatefulWidget {
  const GestionUtilisateurs({super.key});

  @override
  _GestionUtilisateursState createState() => _GestionUtilisateursState();
}

class _GestionUtilisateursState extends State<GestionUtilisateurs> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }



  void _fetchUsers() async {

    try {
      QuerySnapshot snapshot = await _firestore.collection('users').get();
      List<Map<String, dynamic>> usersList = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'fullName': data['fullName'] ?? '',
          'phone': data['phone'] ?? '',
          'role': data['role'] ?? '',
          'isActive': data['isActive'] ?? true,
          'matrimoniale': data['maritalStatus'] ?? '',
          'startDate': data['startDate'] ?? '',
          'deactivatedAt': data['deactivatedAt']
        };
      }).toList();

      setState(() {
        _users = usersList;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur lors du chargement des utilisateurs : $e";
        _loading = false;
      });
    }
  }

  void _deleteUser(String userId) async {
    bool confirmDelete = await _showDeleteConfirmation();
    if (confirmDelete) {
      await _firestore.collection('users').doc(userId).delete();
      _fetchUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Utilisateur supprimé avec succès")),
      );
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirmer la suppression"),
        content: Text("Voulez-vous vraiment supprimer cet utilisateur ?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Annuler")),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ??
        false;
  }

  Future<bool> _showToggleActivationConfirmation(bool isActive) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isActive ? "Désactiver le compte" : "Activer le compte"),
        content: Text(isActive
            ? "Voulez-vous vraiment désactiver ce compte utilisateur ?"
            : "Voulez-vous vraiment activer ce compte utilisateur ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              isActive ? "Désactiver" : "Activer",
              style: TextStyle(color: isActive ? Colors.red : Colors.green),
            ),
          ),
        ],
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gestion des Utilisateurs"),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_alt_1_rounded),
            tooltip: "Ajouter un utilisateur",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SignUpPage()),
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
          child: Text(_errorMessage,
              style: TextStyle(color: Colors.red)))
          : _users.isEmpty
          ? Center(child: Text("Aucun utilisateur trouvé"))
          : LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _users.map((user) {
              bool isActive = user['isActive'] ?? true;
              return SizedBox(
                width: constraints.maxWidth < 600
                    ? constraints.maxWidth
                    : (constraints.maxWidth / 2) - 16,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(user['fullName'] ?? '',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.green
                                    : Colors.red,
                                borderRadius:
                                BorderRadius.circular(20),
                              ),
                              child: Text(
                                isActive ? "Activé" : "Désactivé",
                                style:
                                TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text("Téléphone: ${user['phone'] ?? ''}"),
                        Text("Rôle: ${user['role'] ?? ''}"),
                        Text("Date de début: ${user['startDate'] ?? ''}"),
                        Text("Situation matrimoniale: ${user['matrimoniale'] ?? ''}"),
                        if (!isActive && user['deactivatedAt'] != null)
                          Text("Date de suspension: ${user['deactivatedAt'].toDate().toString().split('.')[0]}", style: TextStyle(color: Colors.red)),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit,
                                  color: Colors.blue),
                              tooltip: "Modifier",
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditUserPage(
                                      userId: user['id']),
                                ),
                              ).then((_) => _fetchUsers()),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete,
                                  color: Colors.red),
                              tooltip: "Supprimer",
                              onPressed: () =>
                                  _deleteUser(user['id']),
                            ),
                            IconButton(
                              icon: Icon(
                                isActive
                                    ? Icons.toggle_on
                                    : Icons.toggle_off,
                                color: isActive
                                    ? Colors.green
                                    : Colors.orange,
                                size: 30,
                              ),
                              tooltip: isActive
                                  ? "Désactiver"
                                  : "Activer",
                              onPressed: () async {
                                bool confirm =
                                await _showToggleActivationConfirmation(
                                    isActive);
                                if (confirm) {
                                  await _firestore
                                      .collection('users')
                                      .doc(user['id'])
                                      .update({
                                    'isActive': !isActive,
                                    'deactivatedAt': isActive
                                        ? DateTime.now()
                                        : null
                                  });
                                  _fetchUsers();
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(isActive
                                          ? "Compte désactivé avec succès"
                                          : "Compte activé avec succès"),
                                      backgroundColor: isActive
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}