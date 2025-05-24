import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationsEmployePage extends StatefulWidget {
  const NotificationsEmployePage({Key? key}) : super(key: key);

  @override
  State<NotificationsEmployePage> createState() => _NotificationsEmployePageState();
}

class _NotificationsEmployePageState extends State<NotificationsEmployePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool loading = true;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    setState(() => loading = true);
    final fetched = await fetchNotifications();
    setState(() {
      notifications = fetched;
      loading = false;
    });
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .get();

      final List<Map<String, dynamic>> fetched = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Notification',
          'message': data['message'] ?? '',
          'timestamp': data['timestamp'],
          'seen': data['seen'] ?? false,
          'link': data['link'],
        };
      }).toList();

      // Marquer comme lues (seen: true) toutes les notifications non lues
      for (var doc in snapshot.docs) {
        if (!(doc.data()['seen'] ?? false)) {
          await doc.reference.update({'seen': true});
        }
      }

      return fetched;
    } catch (e) {
      print('Erreur lors de la récupération des notifications : $e');
      return [];
    }
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return DateFormat('dd/MM/yyyy à HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes notifications')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
          ? const Center(child: Text("Aucune notification disponible."))
          : ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notif = notifications[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(
                Icons.notifications,
                color: notif['seen'] ? Colors.grey : Colors.red,
              ),
              title: Text(
                notif['title'],
                style: TextStyle(
                  fontWeight:
                  notif['seen'] ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notif['message']),
                  const SizedBox(height: 4),
                  Text(
                    formatTimestamp(notif['timestamp']),
                    style:
                    const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              onTap: () {
                if (notif['link'] != null) {
                  Navigator.pushNamed(context, notif['link']);
                }
              },
            ),
          );
        },
      ),
    );
  }
}
