import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:whiskyshop_app/pages/generer_qr_presence.dart';
import 'package:whiskyshop_app/pages/liste_employes.dart';
import 'package:whiskyshop_app/pages/historique_pointages.dart';
import 'package:whiskyshop_app/pages/liste_employes_gestion_temps.dart';
import 'package:whiskyshop_app/pages/notifications_gerant_page.dart';
import 'package:whiskyshop_app/pages/profil_page.dart';
//import 'package:whiskyshop_app/pages/qr_generator_admin.dart';

class GerardHome extends StatelessWidget {
  const GerardHome({super.key});

  Stream<int> getUnreadNotificationsCount(String userUid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userUid)
        .collection('notifications')
        .where('seen', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }


  @override
  Widget build(BuildContext context) {
    final String? userUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text("Tableau de bord Gérant"),
        backgroundColor: Colors.black26,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          children: [
            _buildMenuButton(
              context,
              title: 'Liste des Employés',
              icon: Icons.people,
              onTap: () {
                // Redirection vers la page de liste des employés
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ListeEmployes()),
                );
              },
            ),
            _buildMenuButton(
              context,
              title: 'Gérer les Emplois du Temps',
              icon: Icons.schedule,
              onTap: () {
                // Redirection vers la page de gestion des emplois du temps
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ListeEmployesGestion()),
                );
              },
            ),
            _buildMenuButton(
              context,
              title: 'Historique des Pointages',
              icon: Icons.history,
              onTap: () {
                // Redirection vers la page de l'historique des pointages
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HistoriquePointages()),
                );
              },
            ),

            _buildMenuButtonWithBadge(
              context,
              title: 'Notifications',
              icon: Icons.notifications,
              stream: getUnreadNotificationsCount(userUid!),
              onTap: () async {
                try {
                  final notesSnapshot = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userUid)
                      .collection('notes')
                      .get();

                  if (notesSnapshot.docs.isNotEmpty) {
                    final noteDoc = notesSnapshot.docs.first;
                    final data = noteDoc.data();

                    if (data.containsKey('employeId')) {
                      String employeId = data['employeId'];
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationsGerantPage(employeId: employeId),
                        ),
                      );
                    } else {
                      throw Exception("Le champ 'employeId' est manquant dans notes.");
                    }
                  } else {
                    throw Exception("Aucune note trouvée pour cet utilisateur.");
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Erreur : ${e.toString()}"),
                    backgroundColor: Colors.red,
                  ));
                }
              },


            ),

            _buildMenuButton(
              context,
              title: 'Generer QR Code Pointage',
              icon: Icons.qr_code,
              onTap: () {
                // Redirection vers la page qr code 
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GenererQrCodePresence()),
                );

              },
             
            ),

            _buildMenuButton(
              context,
              title: 'Mon Profil',
              icon: Icons.person,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilPage(userId: FirebaseAuth.instance.currentUser!.uid,)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButtonWithBadge(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Stream<int> stream,
        required VoidCallback onTap,
      }) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        int unreadCount = snapshot.data ?? 0;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  offset: Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(icon, size: 50, color: Colors.white),
                      if (unreadCount > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildMenuButton(BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              offset: Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: Colors.white),
              SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
