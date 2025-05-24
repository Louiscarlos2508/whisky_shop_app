import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SuiviEmployesPage extends StatefulWidget {
  const SuiviEmployesPage({super.key});

  @override
  State<SuiviEmployesPage> createState() => _SuiviEmployesPageState();
}

class _SuiviEmployesPageState extends State<SuiviEmployesPage> {
  Future<List<Map<String, dynamic>>> getUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'fullName': data['fullName'] ?? '',
        'role': data['role'] ?? '',
        'taches': List<String>.from(data['taches'] ?? []),
        'sanction': data['sanction'] ?? false,
        'commentaireSanction': data['commentaireSanction'] ?? '',
        'note': (data['note'] ?? 0).toDouble(),
      };
    }).toList();
  }

  Future<void> sendNotification({
    required String userId,
    required String message,
    required String type,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type,
      'seen': false,
    });
  }

  Future<void> toggleSanction(String userId, bool isSanctioned) async {
    if (!isSanctioned) {
      String commentaire = '';
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Motif de la sanction"),
          content: TextField(
            onChanged: (value) => commentaire = value,
            maxLines: 3,
            decoration: const InputDecoration(hintText: "Saisir le motif..."),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (commentaire.trim().isEmpty) return;

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update({
                  'sanction': true,
                  'commentaireSanction': commentaire.trim(),
                });

                await sendNotification(
                  userId: userId,
                  message: "Vous avez été sanctionné : $commentaire",
                  type: "sanction",
                );

                Navigator.pop(context);
                setState(() {});
              },
              child: const Text("Sanctionner"),
            ),
          ],
        ),
      );
    } else {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'sanction': false,
        'commentaireSanction': "",
      });

      await sendNotification(
        userId: userId,
        message: "Votre sanction a été levée.",
        type: "sanction",
      );

      setState(() {});
    }
  }

  Future<void> updateNote(String userId, double note) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'note': note,
    });

    await sendNotification(
      userId: userId,
      message: "Une nouvelle note vous a été attribuée : ${note.toStringAsFixed(0)} ★",
      type: "note",
    );

    setState(() {});
  }

  Future<List<Map<String, dynamic>>> getPointages() async {
    final snapshot = await FirebaseFirestore.instance.collection('pointages').get();
    List<Map<String, dynamic>> pointages = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final uid = data['uid']?.toString();
      final entree = (data['date'] as Timestamp?)?.toDate();
      final sortie = (data['sortie'] as Timestamp?)?.toDate();
      String fullname = 'Inconnu';

      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          fullname = userDoc.data()!['fullName']?.toString() ?? 'Sans nom';
        }
      }

      pointages.add({
        'fullName': fullname,
        'entree': entree,
        'sortie': sortie,
      });
    }

    return pointages;
  }

  void showNoteDialog(String userId, double currentNote) {
    double selectedNote = currentNote;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attribuer une note'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                min: 0,
                max: 5,
                divisions: 5,
                label: selectedNote.toStringAsFixed(0),
                value: selectedNote,
                onChanged: (value) {
                  setStateDialog(() => selectedNote = value);
                },
              ),
              Text("Note : ${selectedNote.toStringAsFixed(0)} étoiles")
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Annuler'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Valider'),
            onPressed: () {
              updateNote(userId, selectedNote);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget buildResponsiveTable({
    required BuildContext context,
    required List<DataColumn> columns,
    required List<DataRow> rows,
  }) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            columnSpacing: 20,
            columns: columns,
            rows: rows,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 80,
            headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
            dividerThickness: 0.5,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Suivi des employés"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text("Liste des utilisateurs", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: getUsers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final users = snapshot.data!;
                return buildResponsiveTable(
                  context: context,
                  columns: const [
                    DataColumn(label: Text("Nom complet")),
                    DataColumn(label: Text("Rôle")),
                    DataColumn(label: Text("Tâches assignées")),
                    DataColumn(label: Text("Sanction")),
                    DataColumn(label: Text("Commentaire Sanction")),
                    DataColumn(label: Text("Note")),
                    DataColumn(label: Text("Actions")),
                  ],
                  rows: users.map((user) {
                    return DataRow(cells: [
                      DataCell(Text(user['fullName'] ?? '')),
                      DataCell(Text(user['role'] ?? '')),
                      DataCell(Text((user['taches'] as List<String>).join(', '))),
                      DataCell(Text(user['sanction'] ? "Oui" : "Non")),
                      DataCell(Text(user['commentaireSanction'] ?? '')),
                      DataCell(Text("${user['note']} ★")),
                      DataCell(Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => toggleSanction(user['id'], user['sanction']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: user['sanction'] ? Colors.green : Colors.red,
                            ),
                            child: Text(user['sanction'] ? "Lever" : "Sanctionner"),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => showNoteDialog(user['id'], user['note']),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            child: const Text("Noter"),
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 32),
            const Divider(thickness: 1),
            const SizedBox(height: 24),
            Text("Historique des pointages", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: getPointages(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final pointages = snapshot.data!;
                if (pointages.isEmpty) return const Text("Aucun pointage trouvé.");
                return buildResponsiveTable(
                  context: context,
                  columns: const [
                    DataColumn(label: Text("Nom employé")),
                    DataColumn(label: Text("Entrée")),
                    DataColumn(label: Text("Sortie")),
                  ],
                  rows: pointages.map((p) {
                    return DataRow(cells: [
                      DataCell(Text(p['fullName'] ?? '')),
                      DataCell(Text(p['entree'] != null ? DateFormat('dd/MM/yyyy – HH:mm').format(p['entree']) : 'Non pointé')),
                      DataCell(Text(p['sortie'] != null ? DateFormat('dd/MM/yyyy – HH:mm').format(p['sortie']) : 'Pas encore sorti')),
                    ]);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
