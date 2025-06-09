import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SuiviGerantPage extends StatefulWidget {
  const SuiviGerantPage({super.key});

  @override
  _SuiviGerantPageState createState() => _SuiviGerantPageState();
}

class _SuiviGerantPageState extends State<SuiviGerantPage> {
  String? selectedGerantUid;
  Map<String, String> gerantsMap = {}; // UID => Nom
  double note = 3;
  final commentaireController = TextEditingController();

  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    fetchGerantsAssocies();
  }

  Future<void> fetchGerantsAssocies() async {
    if (currentUser == null) return;

    final snapshot = await FirebaseFirestore.instance.collection('points_vente').get();

    Set<String> gerantUids = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final List<dynamic> employes = data['employes'] ?? [];
      final String? gerant = data['gerant'];

      if (employes.contains(currentUser!.uid) && gerant != null) {
        gerantUids.add(gerant);
      }
    }

    for (String uid in gerantUids) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final nom = userDoc.data()?['fullName'] ?? 'Inconnu';
      gerantsMap[uid] = nom;
    }

    setState(() {});
  }

  Future<void> soumettreNote() async {
    if (selectedGerantUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Veuillez choisir un gérant.")));
      return;
    }

    final gerantRef = FirebaseFirestore.instance.collection('users').doc(selectedGerantUid);
    final doc = await gerantRef.get();

    double ancienneNote = 0;
    int totalNotes = 0;

    if (doc.exists) {
      final data = doc.data()!;
      ancienneNote = (data['note'] ?? 0).toDouble();
      totalNotes = (data['totalNotes'] ?? 0);
    }

    double nouvelleNote = ((ancienneNote * totalNotes) + note) / (totalNotes + 1);

    await gerantRef.update({
      'note': double.parse(nouvelleNote.toStringAsFixed(1)),
      'totalNotes': totalNotes + 1,
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Note soumise avec succès.")));
    commentaireController.clear();
    setState(() {
      selectedGerantUid = null;
      note = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Noter mon gérant")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: gerantsMap.isEmpty
            ? Center(child: Text("Aucun gérant associé trouvé."))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Sélectionnez un gérant :"),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedGerantUid,
                    hint: Text("Choisir un gérant"),
                    items: gerantsMap.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedGerantUid = value;
                      });
                    },
                  ),
                  SizedBox(height: 20),
                  Text("Note (1 à 5) : ${note.toStringAsFixed(1)}"),
                  Slider(
                    value: note,
                    onChanged: (value) => setState(() => note = value),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: note.toStringAsFixed(1),
                  ),
                  TextField(
                    controller: commentaireController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: "Commentaire (facultatif)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: soumettreNote,
                    child: Text("Soumettre la note"),
                  )
                ],
              ),
      ),
    );
  }
}
