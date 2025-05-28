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


  /*Future<void> createInitialSettings() async {
    try {
      await _firestore.collection('settings').doc('education_levels').set({
        'name': [
          'Aucun',
          'Primaire',
          'Secondaire',
          'License',
          'Master',
          'Doctorat',
        ]
      });

      await _firestore.collection('settings').doc('marital_statuses').set({
        'name': [
          'Célibataire',
          'Marié(e)',
          'Divorcé(e)',
          'Veuf(ve)',
        ]
      });

      print("Données ajoutées avec succès !");
    } catch (e) {
      print("Erreur lors de la création des données : $e");
    }
  }

   */


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

          //createInitialSettings();

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

    final role = data?['role'] ?? '';
    if (role == 'admin') return;

    final docId = data?['pieceIdentite'];
    final acteNaissance = data?['acte_de_naissance'];

    final notifCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications');

    final notifSnapshot = await notifCollection
        .where('type', isEqualTo: 'profil_incomplet')
        .limit(1)
        .get();

    final hasMissingDocs = (docId == null || docId.isEmpty || acteNaissance == null || acteNaissance.isEmpty);

    if (hasMissingDocs) {
      if (notifSnapshot.docs.isNotEmpty) {
        // 🔁 Mise à jour notification existante
        final docIdNotif = notifSnapshot.docs.first.id;
        await notifCollection.doc(docIdNotif).update({
          'seen': false,
          'timestamp': Timestamp.now(),
        });
      } else {
        // 🆕 Création nouvelle notification
        await notifCollection.add({
          'title': 'Profil incomplet',
          'message': 'Veuillez compléter votre profil en ajoutant vos documents justificatifs.',
          'timestamp': Timestamp.now(),
          'seen': false,
          'type': 'profil_incomplet',
          'link': '/profile/${user.uid}',
        });
      }
    } else {
      // ✅ Tous les documents sont fournis → supprimer notification si elle existe
      if (notifSnapshot.docs.isNotEmpty) {
        await notifCollection.doc(notifSnapshot.docs.first.id).delete();
      }
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
