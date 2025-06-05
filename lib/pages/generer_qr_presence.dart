import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io' as io show File, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_html/html.dart' as html;

class GenererQrCodePresence extends StatefulWidget {
  const GenererQrCodePresence({super.key});

  @override
  State<GenererQrCodePresence> createState() => _GenererQrCodePresenceState();
}

class _GenererQrCodePresenceState extends State<GenererQrCodePresence> {
  final GlobalKey _qrKey = GlobalKey();
  String? _qrData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQrData();
  }

  Future<void> _loadQrData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Utilisateur non connecté.");
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final pointDeVenteId = userDoc['pointDeVenteId'];
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      setState(() {
        _qrData = "$pointDeVenteId|$today";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _qrData = null;
        _isLoading = false;
      });
      _showMessage("Erreur : ${e.toString()}", isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _downloadQRCode() async {
    try {
      final context = _qrKey.currentContext;
      if (context == null) {
        _showMessage("QR Code non prêt à être téléchargé", isError: true);
        return;
      }

      RenderRepaintBoundary boundary = context.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final fileName = 'qr_code_${DateTime.now().millisecondsSinceEpoch}.png';

      if (kIsWeb) {
        final blob = html.Blob([pngBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.Url.revokeObjectUrl(url);
        _showMessage("QR Code téléchargé avec succès (Web)");
      } else {
        if (io.Platform.isAndroid || io.Platform.isIOS) {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            _showMessage("Permission refusée", isError: true);
            return;
          }
        }

        final directory = await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
        final path = '${directory.path}/$fileName';
        final file = io.File(path);
        await file.writeAsBytes(pngBytes);

        _showMessage("QR Code téléchargé : $fileName");
      }
    } catch (e) {
      _showMessage("Erreur téléchargement : ${e.toString()}", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QR Code de présence")),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _qrData == null
                ? const Text("Impossible de générer le QR Code.")
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RepaintBoundary(
                        key: _qrKey,
                        child: QrImageView(
                          data: _qrData!,
                          version: QrVersions.auto,
                          size: 250.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: _downloadQRCode,
                        icon: const Icon(Icons.download),
                        label: const Text("Télécharger le QR Code"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                      )
                    ],
                  ),
      ),
    );
  }
}
