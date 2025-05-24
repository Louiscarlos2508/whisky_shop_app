import 'package:flutter/material.dart';
import 'package:whiskyshop_app/pages/admin_demande_service.dart';
import 'package:whiskyshop_app/pages/gestion_paiements.dart';
import 'package:whiskyshop_app/pages/gestion_point_vente.dart';
import 'package:whiskyshop_app/pages/gestion_utilisateurs.dart';
import 'package:whiskyshop_app/pages/stats.dart';
import 'package:whiskyshop_app/pages/suivi_employes_page.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tableau de bord Administrateur"),
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
              title: 'Gestion des Utilisateurs',
              icon: Icons.people,
              onTap: () {
                // Redirection vers la page de gestion des utilisateurs
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GestionUtilisateurs()),
                );
              },
            ),
            _buildMenuButton(
              context,
              title: 'Gestion Points de Vente',
              icon: Icons.store,
              onTap: () {
                // Redirection vers la page de gestion des points de vente
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GestionPointVente()),
                );
              },
            ),
            _buildMenuButton(
              context,
              title: 'Paiements & Suivi',
              icon: Icons.payment,
              onTap: () {
                // Redirection vers la page de suivi des paiements
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GestionPaiements()),
                );
              },
            ),
            _buildMenuButton(
              context,
              title: 'Statistiques',
              icon: Icons.bar_chart,
              onTap: () {
                // Redirection vers la page des statistiques
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Stats()),
                );
              },
            ),
             _buildMenuButton(
              context,
              title: 'Suivi des Demandes',
              icon: Icons.padding,
              onTap: () {
                // Redirection vers la page des demandes service
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminDemandeService()),
                );
              },
            ),
                         _buildMenuButton(
              context,
              title: 'Suivi des Employes',
              icon: Icons.padding,
              onTap: () {
                // Redirection vers la page des demandes service
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SuiviEmployesPage()),
                );
              },
            ),
          ],
        ),
      ),
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
          color: Colors.redAccent,
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


