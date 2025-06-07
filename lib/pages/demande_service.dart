// ... [Imports inchangés]
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DemandeService extends StatefulWidget {
  const DemandeService({super.key});

  @override
  State<DemandeService> createState() => _DemandeServiceState();
}

class _DemandeServiceState extends State<DemandeService> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  final RecorderController _recorderController = RecorderController();

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _filePath;
  String? _audioBase64;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _montantPretController = TextEditingController();
  final TextEditingController _periodeRemboursementController = TextEditingController();

  String? nomUtilisateur;
  String? posteUtilisateur;
  String? pointDeVenteId;
  String? phoneNumber;

  String _typeDemande = 'absence';
  String? _sousType; // urgence, manifestation, maladie, etc.

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _player.openPlayer();
    _chargerInfosUtilisateur();
  }

  Future<void> _initRecorder() async {
    final micStatus = await Permission.microphone.request();
    if (!mounted) return;
    if (!micStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Microphone non autorisé")),
      );
      return;
    }

    await _recorder.openRecorder();
    _recorderController
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 16000;
  }

  Future<void> _chargerInfosUtilisateur() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          nomUtilisateur = data?['fullName'] ?? '';
          posteUtilisateur = data?['poste'] ?? '';
          pointDeVenteId = data?['pointDeVenteId'] ?? '';
          phoneNumber = data?['phone'] ?? '';
        });
      }
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    _textController.dispose();
    _montantPretController.dispose();
    _periodeRemboursementController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();
    final uniqueFileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.aac';
    _filePath = '${dir.path}/$uniqueFileName';

    await _recorder.startRecorder(toFile: _filePath, codec: Codec.aacADTS);
    _recorderController.record();

    _timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration = Duration(seconds: _recordDuration.inSeconds + 1));
    });

    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    await _recorderController.stop();
    _timer?.cancel();
    setState(() => _isRecording = false);

    if (_filePath != null) {
      final file = File(_filePath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        setState(() {
          _audioBase64 = base64Encode(bytes);
        });
      }
    }
  }

  Future<void> _playAudio() async {
    if (_filePath == null || !(await File(_filePath!).exists())) return;

    if (_isPlaying) {
      await _player.stopPlayer();
    } else {
      await _player.startPlayer(
        fromURI: _filePath,
        codec: Codec.aacADTS,
        whenFinished: () => setState(() => _isPlaying = false),
      );
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _resetAudio() {
    if (_filePath != null) File(_filePath!).delete();
    setState(() {
      _audioBase64 = null;
      _filePath = null;
      _recordDuration = Duration.zero;
    });
  }

  Future<void> _envoyerDemande() async {
    if ((_audioBase64 == null || _audioBase64!.isEmpty) && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Veuillez enregistrer un audio ou écrire un message.")),
      );
      return;
    }

    double? montantPret;
    int? periode;

    if (_typeDemande == 'pret') {
      montantPret = double.tryParse(_montantPretController.text);
      periode = int.tryParse(_periodeRemboursementController.text);
      if (montantPret == null || periode == null || periode <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Veuillez entrer un montant et une période valides.")),
        );
        return;
      }
    }


    await FirebaseFirestore.instance.collection('demandedeservice').add({
      'texte': _textController.text.trim().isNotEmpty ? _textController.text.trim() : null,
      'audioBase64': _audioBase64,
      'statut': 'en attente',
      'timestamp': FieldValue.serverTimestamp(),
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'heure': DateFormat('HH:mm:ss').format(DateTime.now()),
      'nom': nomUtilisateur ?? '',
      'poste': posteUtilisateur ?? '',
      'pointDeVenteId': pointDeVenteId ?? '',
      'typeDemande': _typeDemande,
      'sousType': _sousType,
      'montantPret': montantPret,
      'telDestinataire': phoneNumber,
      'periodeRemboursement': periode,
      'montantRestant': montantPret, // reste à rembourser initialisé au montant total
      'montantMensuel': (montantPret! / periode!).round(),
      'moisDejaRembourses': 0,
      'tranchesRestantes': periode,
      'rembourse': false,
      'dateDemandePret': _typeDemande == 'pret' ? DateFormat('yyyy-MM-dd').format(DateTime.now()) : null,
      'userId': FirebaseAuth.instance.currentUser?.uid ?? ''
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Demande envoyée avec succès.")),
    );

    _resetAudio();
    _textController.clear();
    _montantPretController.clear();
    _periodeRemboursementController.clear();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Faire une demande")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _typeDemande,
              items: [
                DropdownMenuItem(value: 'absence', child: Text('Absence')),
                DropdownMenuItem(value: 'conge', child: Text('Congé')),
                DropdownMenuItem(value: 'pret', child: Text('Prêt')),
              ],
              onChanged: (val) => setState(() {
                _typeDemande = val!;
                _sousType = null;
              }),
              decoration: InputDecoration(labelText: "Type de demande"),
            ),
            const SizedBox(height: 10),
            if (_typeDemande == 'absence' || _typeDemande == 'conge') ...[
              DropdownButtonFormField<String>(
                value: _sousType,
                items: (_typeDemande == 'absence'
                        ? ['urgence', 'manifestation']
                        : ['maladie', 'grossesse', 'opération'])
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.capitalize())))
                    .toList(),
                onChanged: (val) => setState(() => _sousType = val),
                decoration: InputDecoration(labelText: "Motif"),
              ),
            ],
            if (_typeDemande == 'pret') ...[
              TextFormField(
                controller: _montantPretController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: "Montant du prêt"),
              ),
              TextFormField(
                controller: _periodeRemboursementController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: "Période de remboursement (mois)"),
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Message (texte)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            if (_isRecording)
              Column(
                children: [
                  AudioWaveforms(
                    enableGesture: true,
                    size: Size(MediaQuery.of(context).size.width, 100.0),
                    recorderController: _recorderController,
                    waveStyle: WaveStyle(
                      waveColor: Colors.blue,
                      extendWaveform: true,
                      showMiddleLine: false,
                    ),
                  ),
                  Text("Durée: ${_formatDuration(_recordDuration)}"),
                ],
              ),
            ElevatedButton.icon(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? "Arrêter" : "Démarrer enregistrement"),
            ),
            if (_audioBase64 != null) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _playAudio,
                icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                label: Text(_isPlaying ? "Arrêter" : "Écouter l'enregistrement"),
              ),
              ElevatedButton.icon(
                onPressed: _resetAudio,
                icon: Icon(Icons.delete),
                label: Text("Supprimer l'audio"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _envoyerDemande,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text("Envoyer la demande"),
            ),
          ],
        ),
      ),
    );
  }
}


extension StringExtension on String {
  String capitalize() => isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : '';
}

