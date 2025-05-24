import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sound/flutter_sound.dart';

class AdminDemandeService extends StatefulWidget {
  const AdminDemandeService({super.key});

  @override
  State<AdminDemandeService> createState() => _AdminDemandeServiceState();
}

class _AdminDemandeServiceState extends State<AdminDemandeService> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  String _playingId = '';

  @override
  void initState() {
    super.initState();
    _player.openPlayer();
  }

  @override
  void dispose() {
    _player.closePlayer();
    super.dispose();
  }

  Future<void> _playAudio(String docId, String base64Audio) async {
    if (_playingId == docId) {
      await _player.stopPlayer();
      setState(() {
        _playingId = '';
      });
    } else {
      final Uint8List audioBytes = base64Decode(base64Audio);
      await _player.startPlayer(
        fromDataBuffer: audioBytes,
        codec: Codec.aacADTS,
        whenFinished: () {
          setState(() {
            _playingId = '';
          });
        },
      );
      setState(() {
        _playingId = docId;
      });
    }
  }

  Future<void> _changerStatut(String docId, String statut) async {
    await FirebaseFirestore.instance.collection('demandedeservice').doc(docId).update({
      'statut': statut,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Demande $statut")),
    );
  }

  Future<String> _getNomPointVente(String pointDeVenteId) async {
    if (pointDeVenteId.isEmpty) return '---';
    try {
      final doc = await FirebaseFirestore.instance.collection('points_vente').doc(pointDeVenteId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['nom'] ?? '---';
      }
    } catch (e) {
      print("Erreur récupération point de vente: $e");
    }
    return '---';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Demandes des employés")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('demandedeservice')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) return Center(child: Text("Aucune demande pour le moment."));

          return ListView.builder(
            itemCount: docs.length,
itemBuilder: (context, index) {
  final doc = docs[index];
  final data = doc.data() as Map<String, dynamic>;

  final texte = data['texte'] ?? '';
  final audioBase64 = data['audioBase64'];
  final nom = data['nom'] ?? 'Inconnu';
  final poste = data['poste'] ?? '---'; // "poste" au lieu de "role"
  final pointDeVenteId = data['pointDeVenteId'] ?? '';
  final statut = data['statut'] ?? 'en attente';
  final docId = doc.id;

  // Convertir timestamp Firestore en DateTime
  final Timestamp? timestamp = data['timestamp'];
  final date = timestamp != null ? timestamp.toDate() : DateTime.now();
  final formattedDate = "${date.day}/${date.month}/${date.year} à ${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}";

  return FutureBuilder<String>(
    future: _getNomPointVente(pointDeVenteId),
    builder: (context, snapshotPV) {
      final nomPointVente = snapshotPV.data ?? '---';

      return Card(
        margin: EdgeInsets.all(10),
        child: ListTile(
          title: Text(texte),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Demandeur : $nom"),
              Text("Poste : $poste"),
              Text("Point de vente : $nomPointVente"),
              Text("Envoyée le : $formattedDate"),
              Text("Statut : $statut"),
              if (audioBase64 != null)
                TextButton.icon(
                  onPressed: () => _playAudio(docId, audioBase64),
                  icon: Icon(_playingId == docId ? Icons.stop : Icons.play_arrow),
                  label: Text(_playingId == docId ? "Arrêter l’audio" : "Écouter audio"),
                ),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _changerStatut(docId, "validée"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: Text("Valider"),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _changerStatut(docId, "refusée"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text("Refuser"),
                  ),
                ],
              )
            ],
          ),
        ),
      );
    },
  );
}

          );
        },
      ),
    );
  }
}
