import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VoirPresence extends StatefulWidget {
  const VoirPresence({super.key});

  @override
  State<VoirPresence> createState() => _VoirPresenceState();
}

class _VoirPresenceState extends State<VoirPresence> {
  bool _scanned = false;
  bool _isForEntry = true;

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (_scanned) return;

    final Barcode barcode = capture.barcodes.first;
    final String? code = barcode.rawValue;

    if (code == null) return;
    setState(() => _scanned = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage("Utilisateur non connecté.");
      return;
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
        .collection('pointage')
        .where('uid', isEqualTo: user.uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (_isForEntry) {
      if (snapshot.docs.isEmpty) {
        // Enregistrer l'entrée
        await FirebaseFirestore.instance.collection('pointage').add({
          'uid': user.uid,
          'code': code,
          'date': Timestamp.now(),
          'sortie': null,
        });
        _showMessage("Entrée enregistrée avec succès.");
      } else {
        _showMessage("Vous avez déjà marqué votre présence aujourd’hui.");
      }
    } else {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        if (doc['sortie'] == null) {
          // Marquer la sortie
          await doc.reference.update({'sortie': Timestamp.now()});
          _showMessage("Sortie enregistrée avec succès.");
        } else {
          _showMessage("Vous avez déjà marqué votre sortie aujourd’hui.");
        }
      } else {
        _showMessage("Aucune présence enregistrée aujourd’hui.");
      }
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.pop(context);
  }

  void _startScan(bool isEntry) {
    setState(() {
      _scanned = false;
      _isForEntry = isEntry;
    });
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEntry ? 'Scanner Entrée' : 'Scanner Sortie'),
        content: SizedBox(
          height: 300,
          width: double.infinity,
          child: MobileScanner(
            controller: MobileScannerController(),
            onDetect: (capture) => _handleScan(capture),
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.black87,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner Présence / Sortie'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _startScan(true),
                icon: const Icon(Icons.login),
                label: const Text("Scanner Présence"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _startScan(false),
                icon: const Icon(Icons.logout),
                label: const Text("Scanner Sortie"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
