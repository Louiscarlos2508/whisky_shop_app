import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationsGerantPage extends StatefulWidget {
  final String employeId;

  const NotificationsGerantPage({super.key, required this.employeId});

  @override
  _NotificationsGerantPageState createState() => _NotificationsGerantPageState();
}


class _NotificationsGerantPageState extends State<NotificationsGerantPage> {
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    marquerNotesCommeLues(widget.employeId); // Marquer les notes comme lues
  }

  Future<void> marquerNotesCommeLues(String employeId) async {
    final firestore = FirebaseFirestore.instance;
    final usersSnapshot = await firestore.collection('users').get();

    for (var userDoc in usersSnapshot.docs) {
      final notesSnapshot = await userDoc.reference
          .collection('notes')
          .where('employeId', isEqualTo: employeId)
          .where('lu', isEqualTo: false)
          .get();

      for (var noteDoc in notesSnapshot.docs) {
        await noteDoc.reference.update({'lu': true});
      }
    }
  }


  Future<List<Map<String, dynamic>>> fetchNotifications(String employeId) async {
    if (currentUser == null) return [];

    final firestore = FirebaseFirestore.instance;
    List<Map<String, dynamic>> result = [];

    // 🔹 1. Avis des employés (notes stockées chez les clients, pas chez le gérant)
    final usersSnapshot = await firestore.collection('users').get();

    for (var userDoc in usersSnapshot.docs) {
      final notesSnapshot = await userDoc.reference
          .collection('notes')
          .where('employeId', isEqualTo: employeId)
          .orderBy('timestamp', descending: true)
          .get();

      for (var doc in notesSnapshot.docs) {
        final data = doc.data();

        final fullName = userDoc.data()['fullName'] ?? 'Employé';

        result.add({
          'type': 'note',
          'note': (data['note'] ?? 0).toDouble(),
          'commentaire': (data['commentaire'] ?? '').toString(),
          'fullName': fullName,
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
        });
      }
    }

    // 🔹 2. Notifications "Profil incomplet" (dans le compte du gérant)
    final profilIncompletSnapshot = await firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('notifications')
        .where('title', isEqualTo: 'Profil incomplet')
        .orderBy('timestamp', descending: true)
        .get();

    for (var doc in profilIncompletSnapshot.docs) {
      final data = doc.data();
      result.add({
        'type': 'profil_incomplet',
        'userId': data['userId'],
        'message': data['message'],
        'timestamp': (data['timestamp'] as Timestamp).toDate(),
      });
    }

    // 🔹 3. Notifications "Rejet document" (dans le compte du gérant)
    final rejetSnapshot = await firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('notifications')
        .where('title', isEqualTo: 'Rejet document')
        .orderBy('timestamp', descending: true)
        .get();

    for (var doc in rejetSnapshot.docs) {
      final data = doc.data();
      result.add({
        'type': 'rejet',
        'message': data['message'],
        'timestamp': (data['timestamp'] as Timestamp).toDate(),
      });
    }

    // 🔹 Trier toutes les notifications par date décroissante
    result.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    return result;
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        centerTitle: true,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchNotifications(widget.employeId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Aucune notification pour le moment."));
          }

          final notations = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notations.length,
            itemBuilder: (context, index) {
              final item = notations[index];
              final type = item['type'];
              final timestamp = item['timestamp'] as DateTime;
              final formattedDate = DateFormat('dd MMM yyyy à HH:mm').format(timestamp);

              if (item['type'] == 'profil_incomplet') {
                return GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/profile/${item['userId']}');
                  },
                  child: Container(
                    padding: EdgeInsets.all(14),
                    // design
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Profil incomplet", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(item['message']),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }

              if (type == 'note') {
                final note = item['note'] ?? 0;
                final fullName = item['fullName'] ?? 'Employé';
                final commentaire = item['commentaire'] ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notifications, color: Colors.indigo, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: List.generate(5, (i) {
                                return Icon(
                                  i < note ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 20,
                                );
                              }),
                            ),
                            const SizedBox(height: 6),
                            if (commentaire.isNotEmpty)
                              Text(
                                commentaire,
                                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              formattedDate,
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (type == 'rejet') {
                final message = item['message'] ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.red, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Document rejeté",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formattedDate,
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return SizedBox.shrink();

            },
          );
        },
      ),
    );
  }
}
