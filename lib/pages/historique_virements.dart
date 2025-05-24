import 'package:flutter/material.dart';

class HistoriqueVirements extends StatelessWidget {
  final List<Map<String, String>> virements = [
    {"Date": "01/03/2025", "Montant": "500 FCFA"},
    {"Date": "10/03/2025", "Montant": "450 FCFA"},
    {"Date": "15/03/2025", "Montant": "600 FCFA"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Historique des Virements"),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Table(
              border: TableBorder.all(color: Colors.black, width: 1),
              columnWidths: {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(3),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.black),
                  children: [
                    tableHeader("Date"),
                    tableHeader("Montant"),
                  ],
                ),
                ...virements.map((entry) => TableRow(
                      decoration: BoxDecoration(color: Colors.white),
                      children: [
                        tableCell(entry["Date"]!),
                        tableCell(entry["Montant"]!),
                      ],
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
  }
}
