import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'emploi_du_temps.dart';

class ListeEmployesGestion extends StatefulWidget {
  const ListeEmployesGestion({super.key});

  @override
  State<ListeEmployesGestion> createState() => _ListeEmployesGestionState();
}

class _ListeEmployesGestionState extends State<ListeEmployesGestion> {
  List<Map<String, dynamic>> employes = [];
  List<Map<String, dynamic>> filteredEmployes = [];
  String? pointVenteId;
  bool isLoading = true;


  @override
  void initState() {
    super.initState();
    listeEmployes();
  }

  Future<void> listeEmployes() async {
    setState(() {
      isLoading = true;
    });
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final pointVenteSnapshot = await FirebaseFirestore.instance
          .collection('points_vente')
          .where('gerant', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (pointVenteSnapshot.docs.isNotEmpty) {
        final pointVenteDoc = pointVenteSnapshot.docs.first;
        pointVenteId = pointVenteDoc.id;
        final pointVenteData = pointVenteDoc.data();

        final List<dynamic> employeUIDs = pointVenteData['employes'] ?? [];

        if (employeUIDs.isNotEmpty) {
          final usersSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: employeUIDs)
              .get();

          setState(() {
            employes = usersSnapshot.docs.map((doc) {
              final data = doc.data();
              return {
                "id": doc.id,
                "nom": data["fullName"] ?? "",
                "poste": data["poste"] ?? "",
              };
            }).toList();

            filteredEmployes = employes;
          });
        }
      }
    } catch (e) {
      print("Erreur lors du chargement des employés : $e");
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Emplois du Temps', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),),
        backgroundColor: Colors.black,
        automaticallyImplyLeading: true,
          iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue,))
          : filteredEmployes.isEmpty
          ? const Center(child: Text("Aucun employé trouvé."))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: filteredEmployes.length,
        itemBuilder: (context, index) {
          final employe = filteredEmployes[index];
          final nomComplet = employe["nom"];
          final id = employe["id"];

          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              leading: CircleAvatar(
                backgroundColor: Colors.black,
                child: Text(
                  nomComplet.isNotEmpty ? nomComplet[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                nomComplet,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: const Text("Clique pour gérer l'emploi du temps"),
              trailing: const Icon(Icons.schedule, color: Colors.black),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmploiDuTemps(employeId: id),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
