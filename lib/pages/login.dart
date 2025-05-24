import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  String _errorMessage = '';

  void _login() async {
    setState(() {
      _loading = true;
      _errorMessage = '';
    });

    try {
      // Authentification
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Récupération de l'utilisateur Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (userData['isActive'] == false) {
          await _auth.signOut();
          setState(() {
            _errorMessage = "Votre compte a été désactivé. Veuillez contacter l'administrateur.";
            _loading = false;
          });
        } else {
          // Vérifie les documents AVANT redirection
          await checkUserDocuments();

          // Redirection
          String role = userData['role'] ?? 'employé';
          Navigator.pushReplacementNamed(context, '/${role}_dashboard');
        }
      } else {
        setState(() {
          _errorMessage = "Utilisateur introuvable.";
          _loading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "Erreur de connexion.";
        _loading = false;
      });
    }
  }


  Future<void> checkUserDocuments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = userDoc.data();

    // Ne pas notifier les admins
    final role = data?['role'] ?? '';
    if (role == 'admin') return;

    final docId = data?['pieceIdentite'];
    final acteNaissance = data?['acte_de_naissance'];
    /*final notifSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('type', isEqualTo: 'profil_incomplet')
        .get();

     */

    if (docId == null || docId == '' || acteNaissance == null || acteNaissance == '') {
      // Envoie une notification locale ici
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add({
        'title': 'Profil incomplet',
        'message': 'Veuillez compléter votre profil en ajoutant vos documents justificatifs.',
        'timestamp': Timestamp.now(),
        'seen': false,
        'type': 'profil_incomplet',
        'link': '/profile/${user.uid}', // pour la redirection si besoin
      });

    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Connexion")),
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logowhisky.png', width: 200, height: 200),
              SizedBox(height: 20),
              TextField(controller: _emailController, decoration: InputDecoration(labelText: 'Email')),
              TextField(controller: _passwordController, obscureText: true, decoration: InputDecoration(labelText: 'Mot de passe')),
              SizedBox(height: 20),
              _loading ? CircularProgressIndicator() : ElevatedButton(onPressed: _login, child: Text("Se connecter")),
              if (_errorMessage.isNotEmpty) ...[
                SizedBox(height: 20),
                Text(_errorMessage, style: TextStyle(color: Colors.red)),
              ],
                            TextButton(
                  onPressed: () {
                     ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("Veuillez contacter l'administrateur !")),
                     );
                   },
                  child: const Text("Pas de compte ?"),
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
