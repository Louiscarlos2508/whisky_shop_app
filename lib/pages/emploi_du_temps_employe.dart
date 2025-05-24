import 'package:flutter/foundation.dart';
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

  String getCurrentWeekId() {
    final now = DateTime.now();
    final beginningOfYear = DateTime(now.year, 1, 1);
    final daysSinceStart = now.difference(beginningOfYear).inDays;
    final firstWeekday = beginningOfYear.weekday;
    final weekNumber = ((daysSinceStart + firstWeekday - 1) / 7).ceil();
    return "${now.year}-W${weekNumber.toString().padLeft(2, '0')}";
  }

  Future<void> loadEmploiDuTemps() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "Utilisateur non connecté.";

      final semaineId = getCurrentWeekId();

      final doc = await FirebaseFirestore.instance
          .collection('emploidutemps')
          .doc(semaineId)
          .collection('employes')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data()?['jours'] != null) {
        setState(() {
          emploiDuTemps = Map<String, dynamic>.from(doc.data()!['jours']);
        });
      } else {
        setState(() {
          emploiDuTemps = {};
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur : $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur de chargement : $e")),
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
      appBar: AppBar(title: Text("Mon emploi du temps de la semaine")),
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
            leading: Icon(Icons.access_time),
          );
        },
      ),
    );
  }
}
