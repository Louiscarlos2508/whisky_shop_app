import 'package:flutter/material.dart';
import 'package:whiskyshop_app/pages/admin_demande_service.dart';
import 'package:whiskyshop_app/pages/admin_home.dart';
import 'package:whiskyshop_app/pages/gestion_paiements.dart';
import 'package:whiskyshop_app/pages/gestion_point_vente.dart';
import 'package:whiskyshop_app/pages/login.dart';
import 'package:whiskyshop_app/pages/stats.dart';
import 'package:whiskyshop_app/pages/suivi_employes_page.dart';
import 'gestion_utilisateurs.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Widget _currentScreen = AdminHome(); // Page par défaut

  void _changeScreen(Widget screen) {
    setState(() {
      _currentScreen = screen;
    });
    Navigator.pop(context); // Fermer le menu après sélection
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Admin Dashboard")),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.redAccent),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.admin_panel_settings, size: 50, color: Colors.white),
                  SizedBox(height: 10),
                  Text("Espace Administrateur", style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.people),
              title: Text("Gestion des Utilisateurs"),
              onTap: () => _changeScreen(GestionUtilisateurs()),
            ),
            ListTile(
              leading: Icon(Icons.store),
              title: Text("Gestion Points de Vente"),
              onTap: () => _changeScreen(GestionPointVente()),
            ),
            ListTile(
              leading: Icon(Icons.payment),
              title: Text("Paiements & Suivi"),
              onTap: () => _changeScreen(GestionPaiements()),
            ),
            ListTile(
              leading: Icon(Icons.bar_chart),
              title: Text("Statistiques"),
              onTap: () => _changeScreen(Stats()),
            ),
            ListTile(
              leading: Icon(Icons.padding),
              title: Text("Suivi des Demandes"),
              onTap: () => _changeScreen(AdminDemandeService()),
            ),
            ListTile(
              leading: Icon(Icons.padding),
              title: Text("Suivi des Employés"),
              onTap: () => _changeScreen(SuiviEmployesPage()),
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
        backgroundColor: Colors.redAccent,
        child: Icon(Icons.arrow_back),
      ),
    );
  }
}
