import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whiskyshop_app/pages/employe_dashboard.dart';
import 'package:whiskyshop_app/pages/login.dart';
import 'package:whiskyshop_app/pages/admin_dashboard.dart';
import 'package:whiskyshop_app/pages/gerant_dashboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    await Future.delayed(const Duration(seconds: 3)); // Temps d'affichage du Splash
    User? user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
      String role = userDoc.get("role");

      if (role == "Administrateur") {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminDashboard()));
      } else if (role == "Gérant") {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GerantDashboard()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => EmployeDashboard()));
      }
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(0, 233, 230, 230), // Couleur de fond noir
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logowhisky.png', width: 150), // Logo de l'application
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.red), // Loader
            const SizedBox(height: 10),
            const Text(
              "Veuillez patienter SVP...",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
