import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmploiDuTempsEmploye extends StatefulWidget {
  const EmploiDuTempsEmploye({super.key});

  @override
  State<EmploiDuTempsEmploye> createState() => _EmploiDuTempsEmployeState();
}

class _EmploiDuTempsEmployeState extends State<EmploiDuTempsEmploye> {
  final jours = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"];
  Map<String, dynamic> emploiDuTemps = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadEmploiDuTemps();
  }

  Future<void> loadEmploiDuTemps() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "Utilisateur non connecté.";

      // Étape 1 : Récupérer le pointDeVenteId de l'utilisateur connecté
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final pointDeVenteId = userDoc.data()?['pointDeVenteId'];

      if (pointDeVenteId == null || pointDeVenteId == "") throw "Aucun point de vente trouvé.";

      // Étape 2 : Déterminer la semaine actuelle
      final now = DateTime.now();
      final weekNumber = ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).ceil();
      final semaineId = "${now.year}-W${weekNumber.toString().padLeft(2, '0')}";

      // Étape 3 : Récupérer l'emploi du temps
      final doc = await FirebaseFirestore.instance
          .collection('emploidutemps')
          .doc(semaineId)
          .collection('points_vente')
          .doc(pointDeVenteId)
          .get();

      if (doc.exists && doc.data() != null) {
        setState(() {
          emploiDuTemps = Map<String, dynamic>.from(doc.data()?['jours'] ?? {});
        });
      } else {
        setState(() {
          emploiDuTemps = {};
        });
      }
    } catch (e) {
      print("Erreur de récupération : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mon emploi du temps")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : emploiDuTemps.isEmpty
              ? Center(child: Text("Aucun emploi du temps disponible."))
              : ListView.builder(
                  itemCount: jours.length,
                  itemBuilder: (context, index) {
                    final jour = jours[index];
                    final horaire = emploiDuTemps[jour] ?? "-";
                    return ListTile(
                      title: Text(jour),
                      subtitle: Text(horaire),
                      leading: Icon(Icons.calendar_today),
                    );
                  },
                ),
    );
  }
}
