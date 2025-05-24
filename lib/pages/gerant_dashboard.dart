import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:whiskyshop_app/pages/generer_qr_presence.dart';
import 'package:whiskyshop_app/pages/gerant_home.dart';
import 'package:whiskyshop_app/pages/liste_employes_gestion_temps.dart';
import 'package:whiskyshop_app/pages/login.dart';
import 'package:whiskyshop_app/pages/notifications_gerant_page.dart';
import 'historique_pointages.dart';
import 'liste_employes.dart';

class GerantDashboard extends StatefulWidget {
  const GerantDashboard({super.key});

  @override
  _GerantDashboardState createState() => _GerantDashboardState();
}

class _GerantDashboardState extends State<GerantDashboard> {
  Widget _currentScreen = GerardHome(); // Page par défaut
  String? employeId;

  @override
  void initState() {
    super.initState();
    _fetchEmployeId();
  }

  void _changeScreen(Widget screen) {
    setState(() {
      _currentScreen = screen;
    });
    Navigator.pop(context); // Ferme le menu après sélection
  }

  Future<void> _fetchEmployeId() async {
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid != null) {
      final notesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userUid)
          .collection('notes')
          .get();

      if (notesSnapshot.docs.isNotEmpty) {
        final data = notesSnapshot.docs.first.data();
        if (data.containsKey('employeId')) {
          setState(() {
            employeId = data['employeId'];
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gérant Dashboard"),
        backgroundColor: const Color.fromARGB(0, 233, 230, 230),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, size: 50, color: Colors.white),
                  SizedBox(height: 10),
                  Text("Espace Gérant", style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.people),
              title: Text("Liste des Employés"),
              onTap: () => _changeScreen(ListeEmployes()),
            ),
            ListTile(
              leading: Icon(Icons.schedule),
              title: Text("Gérer les Emplois du Temps"),
              onTap: () => _changeScreen(ListeEmployesGestion()),
            ),
            ListTile(
              leading: Icon(Icons.history),
              title: Text("Historique des Pointages"),
              onTap: () => _changeScreen(HistoriquePointages()),
            ),
            ListTile(
              leading: Icon(Icons.qr_code),
              title: Text("Générer QR Code Pointage"),
              onTap: () => _changeScreen(GenererQrCodePresence()),
            ),
            ListTile(
              leading: Icon(Icons.notifications),
              title: Text("Notifications"),
              onTap: () {
                if (employeId != null) {
                  _changeScreen(NotificationsGerantPage(employeId: employeId!));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Employé ID introuvable."),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: _currentScreen,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        },
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.arrow_back),
      ),
    );
  }

}
