import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:whiskyshop_app/pages/emploi_du_temps_employe.dart';
import 'package:whiskyshop_app/pages/historique_virements.dart';
import 'package:whiskyshop_app/pages/demande_service.dart';
import 'package:whiskyshop_app/pages/notification_employe_page_page.dart';
import 'package:whiskyshop_app/pages/profil_page.dart';
import 'package:whiskyshop_app/pages/scanner_qr_presence.dart';
import 'package:whiskyshop_app/pages/suivi_gerant_page.dart';

class EmployeHome extends StatelessWidget {
  const EmployeHome({super.key});

  // Utiliser 'seen' (et non 'lu') comme champ pour les notifications non lues
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
        title: const Text("Tableau de bord Employé"),
        backgroundColor: const Color.fromARGB(0, 233, 230, 230),
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
              title: 'Mon Emploi du Temps',
              icon: Icons.schedule,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => EmploiDuTempsEmploye(employeUid: FirebaseAuth.instance.currentUser!.uid,)),
                );
              },
            ),
            _buildMenuButton(
              context,
              title: 'Marquer ma présence',
              icon: Icons.access_time,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ScannerQrPresence()),
                );
              },
            ),
            _buildMenuButton(
              context,
              title: 'Historique de mes Paiements',
              icon: Icons.account_balance_wallet,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => HistoriqueVirements()),
                );
              },
            ),
            _buildMenuButton(
              context,
              title: 'Demande un Service',
              icon: Icons.request_page,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DemandeService()),
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
            if (userUid != null)
              _buildMenuButtonWithBadge(
                context,
                title: 'Notifications',
                icon: Icons.notifications,
                stream: getUnreadNotificationsCount(userUid),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotificationsEmployePage()),
                  );
                },
              ),
            _buildMenuButton(
              context,
              title: 'Noter votre gérant',
              icon: Icons.note,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SuiviGerantPage()),
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
              color: const Color.fromARGB(255, 8, 139, 76),
              shape: BoxShape.circle,
              boxShadow: const [
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

  Widget _buildMenuButton(
      BuildContext context, {
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
          color: const Color.fromARGB(255, 8, 139, 76),
          shape: BoxShape.circle,
          boxShadow: const [
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
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
