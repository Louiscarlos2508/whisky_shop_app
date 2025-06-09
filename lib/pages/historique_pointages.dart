import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HistoriquePointages extends StatefulWidget {
  const HistoriquePointages({super.key});

  @override
  State<HistoriquePointages> createState() => _HistoriquePointagesState();
}

class _HistoriquePointagesState extends State<HistoriquePointages> {
  Future<List<Map<String, dynamic>>> getPointages() async {
    final snapshot = await FirebaseFirestore.instance.collection('pointages').get();
    List<Map<String, dynamic>> pointages = [];

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
    }

    return pointages;
  }

  Widget buildResponsiveTable({
    required BuildContext context,
    required List<DataColumn> columns,
    required List<DataRow> rows,
  }) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            columnSpacing: 20,
            columns: columns,
            rows: rows,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 80,
            headingRowColor:WidgetStateProperty.all(Colors.blue),
            dividerThickness: 0.5,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique des Pointages de votre point de vente"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: getPointages(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final pointages = snapshot.data!;
            if (pointages.isEmpty) return const Text("Aucun pointage trouvé.");

            final nomsUniquepointes = pointages.map((p) => p['fullName']).toSet().toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Historique des pointages",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                buildResponsiveTable(
                  context: context,
                  columns: const [
                    DataColumn(label: Text("Nom employé")),
                    DataColumn(label: Text("Entrée")),
                    DataColumn(label: Text("Sortie")),
                  ],
                  rows: pointages.map((p) {
                    return DataRow(
                      cells: [
                        DataCell(Text(p['fullName'] ?? '')),
                        DataCell(Text(p['entree'] != null
                            ? DateFormat('dd/MM/yyyy – HH:mm').format(p['entree'])
                            : 'Non pointé')),
                        DataCell(Text(p['sortie'] != null
                            ? DateFormat('dd/MM/yyyy – HH:mm').format(p['sortie'])
                            : 'Pas encore sorti')),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Text(
                  "Employés ayant pointé",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: nomsUniquepointes
                      .map((name) => Chip(label: Text(name)))
                      .toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
