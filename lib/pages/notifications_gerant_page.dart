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
      // Ajouté dans la méthode fetchNotifications
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
          'note': (data['note'] is num) ? (data['note'] as num).toDouble() : 0.0,
          'commentaire': (data['commentaire'] ?? '').toString(),
          'fullName': fullName,
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
          'lu': data['lu'] ?? false,
        });
      }

    }

    final allNotificationsSnapshot = await firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .get();

    for (var doc in allNotificationsSnapshot.docs) {
      final data = doc.data();
      final title = data['title'];

      if (title == 'Profil incomplet') {
        result.add({
          'type': 'profil_incomplet',
          'userId': data['userId'],
          'message': data['message'],
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
          'seen': data['seen'] ?? false,
          'link': data['link'],
        });
      } else if (title == 'Document rejeté') {
        result.add({
          'type': 'rejet',
          'userId': data['userId'],
          'message': data['message'],
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
          'seen': data['seen'] ?? false,
          'link': data['link'],
        });
      }
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

              if (type == 'note') {
                final note = item['note'] ?? 0.0;
                final fullName = item['fullName'] ?? 'Employé';
                final commentaire = item['commentaire'] ?? '';
                final isRead = item['lu'] == true;
                if (!isRead) {
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Nouveau",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  );
                }


              return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.grey[200] : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: isRead ? Colors.grey : Colors.indigo,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isRead ? Colors.grey[700] : Colors.black,
                              ),
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
                            if (commentaire.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                commentaire,
                                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                              ),
                            ],
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

              if (type == 'profil_incomplet') {
                final isRead = item['seen'] == true;

                return GestureDetector(
                  onTap: isRead ? null : () async {
                    final firestore = FirebaseFirestore.instance;
                    final snapshot = await firestore
                        .collection('users')
                        .doc(currentUser!.uid)
                        .collection('notifications')
                        .where('userId', isEqualTo: item['userId'])
                        .where('title', isEqualTo: 'Profil incomplet')
                        .get();

                    for (var doc in snapshot.docs) {
                      await doc.reference.update({'seen': true});
                    }
                    if (item['link'] != null) {
                      Navigator.pushNamed(context, item['link']).then((_) {
                      });
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isRead ? Colors.grey[200] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isRead ? Colors.grey : Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning,
                            color: isRead ? Colors.grey : Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Profil incomplet",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isRead ? Colors.grey : Colors.black)),
                              Text(item['message']),
                              const SizedBox(height: 4),
                              Text(
                                formattedDate,
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }

              if (type == 'rejet') {
                final isRead = item['seen'] == true;

                return GestureDetector(
                  onTap: isRead ? null : () async {
                    final firestore = FirebaseFirestore.instance;
                    final snapshot = await firestore
                        .collection('users')
                        .doc(currentUser!.uid)
                        .collection('notifications')
                        .where('userId', isEqualTo: item['userId'])
                        .where('title', isEqualTo: 'Document rejeté')
                        .get();

                    for (var doc in snapshot.docs) {
                      await doc.reference.update({'seen': true});
                    }

                    if (item['link'] != null) {
                      Navigator.pushNamed(context, item['link']).then((_) {
                      });
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isRead ? Colors.grey[200] : Colors.red[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isRead ? Colors.grey : Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber,
                            color: isRead ? Colors.grey : Colors.red, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Document rejeté",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isRead ? Colors.grey : Colors.red)),
                              Text(item['message']),
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
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          );

        },
      ),
    );
  }
}
