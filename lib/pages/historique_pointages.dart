import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HistoriquePointages extends StatefulWidget {
  const HistoriquePointages({super.key});

  @override
  State<HistoriquePointages> createState() => _HistoriquePointagesState();
}

class _HistoriquePointagesState extends State<HistoriquePointages> {
  List<Map<String, dynamic>> allPointages = [];
  List<String> allEmployes = [];
  String? selectedEmploye;
  DateTime? selectedDate;

  Future<void> loadPointages() async {
    final snapshot = await FirebaseFirestore.instance.collection('pointages').get();
    List<Map<String, dynamic>> pointages = [];
    Set<String> employes = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final uid = data['uid']?.toString();

      final entree = data['date'] != null ? (data['date'] as Timestamp).toDate() : null;
      final sortie = data['sortie'] != null ? (data['sortie'] as Timestamp).toDate() : null;

      String fullname = 'Inconnu';

      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          fullname = userDoc.data()!['fullName']?.toString() ?? 'Sans nom';
        }
      }

      pointages.add({
        'fullName': fullname,
        'entree': entree,
        'sortie': sortie,
      });

      employes.add(fullname);
    }

    setState(() {
      allPointages = pointages;
      allEmployes = employes.toList();
    });
  }

  List<Map<String, dynamic>> get filteredPointages {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return allPointages.where((p) {
      final matchEmploye = selectedEmploye == null || p['fullName'] == selectedEmploye;

      final matchDate = selectedDate != null
          ? (p['entree'] != null &&
          DateFormat('yyyy-MM-dd').format(p['entree']) == DateFormat('yyyy-MM-dd').format(selectedDate!))
          : (p['entree'] != null &&
          DateFormat('yyyy-MM-dd').format(p['entree']) == todayStr);

      return matchEmploye && matchDate;
    }).toList();
  }

  List<String> get pointedEmployesForDate {
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate ?? DateTime.now());

    return allPointages
        .where((p) =>
    p['entree'] != null &&
        DateFormat('yyyy-MM-dd').format(p['entree']) == dateStr)
        .map((p) => p['fullName'].toString())
        .toSet()
        .toList();
  }


  @override
  void initState() {
    super.initState();
    loadPointages();
  }

  Widget buildPointageCard(Map<String, dynamic> pointage) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.badge_rounded, color: Colors.blueAccent),
        title: Text(pointage['fullName'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Entrée : ${pointage['entree'] != null ? DateFormat('dd/MM/yyyy – HH:mm').format(pointage['entree']) : 'Non pointé'}"),
            Text("Sortie : ${pointage['sortie'] != null ? DateFormat('dd/MM/yyyy – HH:mm').format(pointage['sortie']) : 'Pas encore sorti'}"),
          ],
        ),
      ),
    );
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void resetFilters() {
    setState(() {
      selectedDate = null;
      selectedEmploye = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pointages = filteredPointages;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique des Pointages"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: resetFilters,
            tooltip: 'Réinitialiser les filtres',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: allPointages.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedEmploye,
                    hint: const Text("Filtrer par employé"),
                    items: allEmployes
                        .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedEmploye = value;
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      child: Text(
                        selectedDate != null
                            ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                            : "Filtrer par date",
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (pointages.isEmpty)
              const Text("Aucun pointage trouvé pour les filtres appliqués."),
            ...pointages.map(buildPointageCard),
            const SizedBox(height: 20),
            if (selectedEmploye == null) ...[
              const Divider(),
              const SizedBox(height: 12),
              Text(
                "Employés ayant pointé le ${DateFormat('dd/MM/yyyy').format(selectedDate ?? DateTime.now())} :",
                style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: pointedEmployesForDate
                    .map((e) => Chip(label: Text(e), backgroundColor: Colors.green[50]))
                    .toList(),
              )
            ]
          ],
        ),
      ),
    );
  }
}
