import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:whiskyshop_app/pages/admin_dashboard.dart';
import 'package:whiskyshop_app/pages/admin_demande_service.dart';
import 'package:whiskyshop_app/pages/admin_home.dart';
import 'package:whiskyshop_app/pages/emploi_du_temps_employe.dart';
import 'package:whiskyshop_app/pages/employe_dashboard.dart';
import 'package:whiskyshop_app/pages/generer_qr_presence.dart';
import 'package:whiskyshop_app/pages/gerant_dashboard.dart';
import 'package:whiskyshop_app/pages/gestion_paiements.dart';
import 'package:whiskyshop_app/pages/gestion_point_vente.dart';
import 'package:whiskyshop_app/pages/gestion_utilisateurs.dart';
import 'package:whiskyshop_app/pages/liste_employes_gestion_temps.dart';
import 'package:whiskyshop_app/pages/login.dart';
import 'package:whiskyshop_app/pages/notification_employe_page_page.dart';
import 'package:whiskyshop_app/pages/profil_employe_view.dart';
import 'package:whiskyshop_app/pages/profil_page.dart';
import 'package:whiskyshop_app/pages/scanner_qr_presence.dart';
import 'package:whiskyshop_app/pages/signup.dart';
import 'package:whiskyshop_app/pages/stats.dart';
import 'package:whiskyshop_app/pages/suivi_employes_page.dart';
import 'package:whiskyshop_app/pages/suivi_gerant_page.dart';
import 'firebase_options.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Whisky Shop App",
      home: const AuthGate(), // 👈 Redirection intelligente
      routes: {
        "/login": (context) => LoginPage(),
        "/signup": (context) => SignUpPage(),
        "/admin_dashboard": (context) => AdminDashboard(),
        "/admin_home": (context) => AdminHome(),
        "/gerant_dashboard": (context) => GerantDashboard(),
        "/employe_dashboard": (context) => EmployeDashboard(),
        "/ProfilCompletPage": (context) => ProfilCompletPage(),
        "/gestion_utilisateurs": (context) => GestionUtilisateurs(),
        "/gestion_point_vente": (context) => GestionPointVente(),
        "/paiement": (context) => GestionPaiements(),
        "/stats": (context) => Stats(),
        "/admin_demande_service": (context) => AdminDemandeService(),
        "/generer_qr_presence": (context) => GenererQrCodePresence(),
        "/scanner_qr_presence": (context) => ScannerQrPresence(),
        "/notifications_employe_page": (context) => NotificationsEmployePage(),
        "/suivi_employes_page": (context) => SuiviEmployesPage(),
        "/suivi_gerant_page": (context) => SuiviGerantPage(),
        "/liste_employes_gestion_temps": (context) => ListeEmployesGestion(),
      },
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');

        if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'profile') {
          final userId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (_) => ProfilPage(userId: userId),
          );
        }

        if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'emploi_du_temps_employe') {
          final employeUid = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (_) => EmploiDuTempsEmploye(employeUid: employeUid),
          );
        }

        return null;
      },
    );

  }

}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData) {
          return const LoginPage(); // 🔐 Redirection vers Login
        }

        final user = snapshot.data!;
        return FutureBuilder<String>(
          future: getUserRole(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (roleSnapshot.hasError || !roleSnapshot.hasData) {
              return const Scaffold(
                  body: Center(child: Text("Erreur lors de la récupération du rôle")));
            }

            final role = roleSnapshot.data!;
            return switchRole(role);
          },
        );
      },
    );
  }

  Widget switchRole(String role) {
    switch (role) {
      case 'admin':
        return const AdminDashboard();
      case 'gerant':
        return const GerantDashboard();
      case 'employe':
        return const EmployeDashboard();
      default:
        return const Scaffold(
            body: Center(child: Text("Rôle utilisateur inconnu")));
    }
  }
}

Future<String> getUserRole(String uid) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  if (doc.exists && doc.data()!.containsKey('role')) {
    return doc['role'];
  } else {
    throw Exception("Rôle introuvable");
  }
}

