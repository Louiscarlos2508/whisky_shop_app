import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmploiDuTemps extends StatefulWidget {
  final String employeId;

  const EmploiDuTemps({super.key, required this.employeId});

  @override
  _EmploiDuTempsState createState() => _EmploiDuTempsState();
}

class _EmploiDuTempsState extends State<EmploiDuTemps> {
  final List<String> jours = [
    "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"
  ];

  final Map<String, TimeOfDay?> heureDebut = {};
  final Map<String, TimeOfDay?> heureFin = {};

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    for (var jour in jours) {
      heureDebut[jour] = null;
      heureFin[jour] = null;
    }
    _init();
  }

  Future<void> _init() async {
    await _loadEmploiDuTemps();
    setState(() {
      isLoading = false;
    });
  }

  String getCurrentWeek() {
    final now = DateTime.now();
    final beginningOfYear = DateTime(now.year, 1, 1);
    final daysSinceStart = now.difference(beginningOfYear).inDays;
    final firstWeekday = beginningOfYear.weekday;
    final weekOfYear = ((daysSinceStart + firstWeekday - 1) / 7).ceil();
    return "${now.year}-W${weekOfYear.toString().padLeft(2, '0')}";
  }

  Future<void> _loadEmploiDuTemps() async {
    final semaine = getCurrentWeek();
    final doc = await FirebaseFirestore.instance
        .collection('emploidutemps')
        .doc(semaine)
        .collection('employes')
        .doc(widget.employeId)
        .get();

    if (doc.exists && doc.data()?['jours'] != null) {
      final data = Map<String, dynamic>.from(doc['jours']);

      setState(() {
        data.forEach((jour, horaire) {
          if (horaire is String && horaire.contains(' - ')) {
            final parts = horaire.split(' - ');
            final debutParts = parts[0].split(':');
            final finParts = parts[1].split(':');
            heureDebut[jour] = TimeOfDay(
                hour: int.parse(debutParts[0]), minute: int.parse(debutParts[1]));
            heureFin[jour] = TimeOfDay(
                hour: int.parse(finParts[0]), minute: int.parse(finParts[1]));
          }
        });
      });
    }
  }

  Future<void> notifierModificationEmploiDuTemps(String employeUid) async {
    final firestore = FirebaseFirestore.instance;

    await firestore
        .collection('users')
        .doc(employeUid)
        .collection('notifications')
        .add({
      'message': 'Votre emploi du temps a été modifié.',
      'timestamp': FieldValue.serverTimestamp(), // <-- CHAMP ATTENDU PAR LE UI
      'seen': false, // <-- CHAMP ATTENDU PAR LE UI
      'type': 'emploi_du_temps', // optionnel, utile pour filtrer si besoin
    });
  }




  Future<void> _saveEmploiDuTemps() async {
    setState(() {
      isSaving = true;
    });
    final semaine = getCurrentWeek();
    final Map<String, String> horaires = {};

    for (var jour in jours) {
      final debut = heureDebut[jour];
      final fin = heureFin[jour];

      if (debut != null && fin != null) {
        horaires[jour] =
        "${debut.hour.toString().padLeft(2, '0')}:${debut.minute.toString().padLeft(2, '0')} - "
            "${fin.hour.toString().padLeft(2, '0')}:${fin.minute.toString().padLeft(2, '0')}";
      } else {
        horaires[jour] = "";
      }
    }


    await FirebaseFirestore.instance
        .collection('emploidutemps')
        .doc(semaine)
        .collection('employes')
        .doc(widget.employeId)
        .set({
      'semaine': semaine,
      'jours': horaires,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await notifierModificationEmploiDuTemps(widget.employeId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Emploi du temps enregistré pour $semaine")),
    );

    setState(() {
      isSaving = false;
    });
  }

  Future<void> _selectTime(String jour, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          heureDebut[jour] = picked;
        } else {
          heureFin[jour] = picked;
        }
      });
    }
  }

  Widget tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget horaireCell(String jour) {
    String format24(TimeOfDay? time) {
      if (time == null) return "";
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return "$hour:$minute";
    }

    final debut = format24(heureDebut[jour]) == "" ? "Début" : format24(heureDebut[jour]);
    final fin = format24(heureFin[jour]) == "" ? "Fin" : format24(heureFin[jour]);


    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton(
            onPressed: () => _selectTime(jour, true),
            child: Text(debut),
          ),
          const Text("-"),
          TextButton(
            onPressed: () => _selectTime(jour, false),
            child: Text(fin),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Emploi du Temps",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Table(
              border: TableBorder.all(color: Colors.black, width: 1),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(3),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Colors.black),
                  children: [
                    tableHeader("Jour"),
                    tableHeader("Horaires"),
                  ],
                ),
                ...jours.map((jour) => TableRow(
                  decoration: const BoxDecoration(color: Colors.white),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(jour, textAlign: TextAlign.center),
                    ),
                    horaireCell(jour),
                  ],
                )),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isSaving ? null : _saveEmploiDuTemps,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Enregistrer", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}



