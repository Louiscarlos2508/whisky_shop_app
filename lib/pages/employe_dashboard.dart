import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:whiskyshop_app/pages/emploi_du_temps_employe.dart';
import 'package:whiskyshop_app/pages/employe_home.dart';
import 'package:whiskyshop_app/pages/login.dart';
import 'package:whiskyshop_app/pages/notification_employe_page_page.dart';
import 'package:whiskyshop_app/pages/profil_page.dart';
import 'package:whiskyshop_app/pages/scanner_qr_presence.dart';
import 'package:whiskyshop_app/pages/suivi_gerant_page.dart';
import 'demande_service.dart';
import 'historique_virements.dart';

class EmployeDashboard extends StatefulWidget {
  const EmployeDashboard({super.key});

  @override
  _EmployeDashboardState createState() => _EmployeDashboardState();
}

class _EmployeDashboardState extends State<EmployeDashboard> {
  Widget _currentScreen = EmployeHome(); // Page par défaut (peut être changée selon vos besoins)

  void _changeScreen(Widget screen) {
    setState(() {
      _currentScreen = screen;
    });
    Navigator.pop(context); // Fermer le menu après sélection
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Employé Dashboard"),
        backgroundColor: const Color.fromARGB(0, 233, 230, 230), // Vous pouvez personnaliser la couleur de l'AppBar ici
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: const Color.fromARGB(255, 8, 139, 76),),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.work, size: 50, color: Colors.white),
                  SizedBox(height: 10),
                  Text("Espace Employé", style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.schedule),
              title: Text("Mon Emploi du Temps"),
              onTap: () => _changeScreen(EmploiDuTempsEmploye()),
            ),
            ListTile(
              leading: Icon(Icons.history),
              title: Text("Marquer ma présence"),
              onTap: () => _changeScreen(ScannerQrPresence()),
            ),
            ListTile(
              leading: Icon(Icons.money),
              title: Text("Historique de mes Paiements"),
              onTap: () => _changeScreen(HistoriqueVirements()),
            ),
            ListTile(
              leading: Icon(Icons.request_page),
              title: Text("Demander un Service"),
              onTap: () => _changeScreen(DemandeService()),
            ),
             ListTile(
              leading: Icon(Icons.person),
              title: Text("Mon Profil"),
              onTap: () => _changeScreen(ProfilPage(userId: FirebaseAuth.instance.currentUser!.uid)),
            ),
             ListTile(
              leading: Icon(Icons.notification_add),
              title: Text("Notifications"),
              onTap: () => _changeScreen(NotificationsEmployePage()),
            ),
             ListTile(
              leading: Icon(Icons.note),
              title: Text("Noter votre gérant"),
              onTap: () => _changeScreen(SuiviGerantPage()),
            ),
          ],
        ),
      ),
      body: _currentScreen,
            floatingActionButton: FloatingActionButton(
        onPressed:  () {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()), // Remplace LoginPage() par ta page réelle
    );
  },
        backgroundColor: const Color.fromARGB(255, 8, 139, 76),
        child: Icon(Icons.arrow_back),
      ),
    );
  }
}
