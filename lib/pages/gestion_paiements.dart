import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class GestionPaiements extends StatefulWidget {
  const GestionPaiements({super.key});

  @override
  _GestionPaiementsState createState() => _GestionPaiementsState();
}

class _GestionPaiementsState extends State<GestionPaiements> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _paiements = [];
  Map<String, String> _beneficiairesMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      QuerySnapshot paiementsSnapshot = await _firestore.collection('paiements').get();
      QuerySnapshot usersSnapshot = await _firestore.collection('users').get();

      Map<String, String> beneficiaires = {};
      for (var doc in usersSnapshot.docs) {
        String userId = doc.id;
        String fullName = doc['fullName'];
        beneficiaires[userId] = fullName;
      }

      setState(() {
        _beneficiairesMap = beneficiaires;
        _paiements = paiementsSnapshot.docs.map((doc) {
          String beneficiaireId = doc['beneficiaire'];
          Timestamp timestamp = doc['date'] ?? Timestamp.now();
          DateTime datePaiement = timestamp.toDate();
          String dateFormatted = DateFormat('dd/MM/yyyy').format(datePaiement);

          return {
            'id': doc.id,
            'beneficiaire': _beneficiairesMap[beneficiaireId] ?? 'Inconnu',
            'montant': doc['montant'],
            'modePaiement': doc['modePaiement'],
            'statut': doc['statut'],
            'date': dateFormatted,
            'rawDoc': doc, // Pour accéder plus tard au snapshot si besoin
          };
        }).toList();
        _loading = false;
      });
    } catch (e) {
      print("Erreur lors de la récupération des données : $e");
      setState(() => _loading = false);
    }
  }

  Future<void> initierPaiementOrangeMoney(Map<String, dynamic> paiement) async {
    String docId = paiement['id'];

    // ⚠ Simulation - à remplacer par appel à l’API Orange Money
    setState(() {
      paiement['statut'] = 'En cours';
    });

    await _firestore.collection('paiements').doc(docId).update({
      'statut': 'En cours',
    });

    await Future.delayed(Duration(seconds: 3)); // Simule l'attente de l'OTP et validation

    setState(() {
      paiement['statut'] = 'Effectué';
    });

    await _firestore.collection('paiements').doc(docId).update({
      'statut': 'Effectué',
    });
  }

  void _supprimerPaiement(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirmation"),
        content: Text("Voulez-vous vraiment supprimer ce paiement ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Annuler")),
          TextButton(
            onPressed: () async {
              await _firestore.collection('paiements').doc(id).delete();
              _fetchData();
              Navigator.pop(context);
            },
            child: Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

void _ajouterPaiement() {
  TextEditingController montantController = TextEditingController();
  TextEditingController montantPretController = TextEditingController();
  String? beneficiaireId;
  String? modePaiement;
  bool prelevementPret = false;
  String telAdmin = "+2250700000000"; // 🔁 remplace ici avec ton numéro réel ou récupère depuis Firestore

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text("Ajouter un paiement"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField(
                value: beneficiaireId,
                hint: Text("Sélectionner un bénéficiaire"),
                items: _beneficiairesMap.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) => setState(() => beneficiaireId = value as String),
              ),
              TextField(
                controller: montantController,
                decoration: InputDecoration(labelText: "Montant total"),
                keyboardType: TextInputType.number,
              ),
              DropdownButtonFormField(
                value: modePaiement,
                hint: Text("Mode de paiement"),
                items: ['Orange Money', 'Virement Bancaire'].map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Text(mode),
                  );
                }).toList(),
                onChanged: (value) => setState(() => modePaiement = value as String),
              ),
              CheckboxListTile(
                title: Text("Déduire un prêt avant paiement"),
                value: prelevementPret,
                onChanged: (bool? value) {
                  setState(() {
                    prelevementPret = value ?? false;
                  });
                },
              ),
              if (prelevementPret)
                TextField(
                  controller: montantPretController,
                  decoration: InputDecoration(labelText: "Montant du prêt à déduire"),
                  keyboardType: TextInputType.number,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Annuler")),
          TextButton(
            onPressed: () async {
              if (beneficiaireId != null && modePaiement != null && montantController.text.isNotEmpty) {
                double montant = double.parse(montantController.text);
                double montantPret = prelevementPret && montantPretController.text.isNotEmpty
                    ? double.parse(montantPretController.text)
                    : 0.0;

                double montantFinal = montant - montantPret;

                // Récupération du numéro du bénéficiaire depuis Firestore
                DocumentSnapshot userDoc = await _firestore.collection('users').doc(beneficiaireId).get();
                String telDestinataire = userDoc['phone'] ?? '';

                await _firestore.collection('paiements').add({
                  'beneficiaire': beneficiaireId,
                  'montant': montant,
                  'montantPret': montantPret,
                  'montantFinal': montantFinal,
                  'modePaiement': modePaiement,
                  'pretDeduit': prelevementPret,
                  'statut': 'En attente',
                  'date': Timestamp.now(),
                  'telAdmin': telAdmin,
                  'telDestinataire': telDestinataire,
                });

                _fetchData();
                Navigator.pop(context);
              }
            },
            child: Text("Ajouter"),
          ),
        ],
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Suivi des Paiements")),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text("Bénéficiaire")),
                  DataColumn(label: Text("Montant")),
                  DataColumn(label: Text("Mode de Paiement")),
                  DataColumn(label: Text("Statut")),
                  DataColumn(label: Text("Date")),
                  DataColumn(label: Text("Actions")),
                ],
                rows: _paiements.map((paiement) {
                  return DataRow(cells: [
                    DataCell(Text(paiement['beneficiaire'])),
                    DataCell(Text(paiement['montant'].toString())),
                    DataCell(Text(paiement['modePaiement'])),
                    DataCell(Text(paiement['statut'])),
                    DataCell(Text(paiement['date'])),
                    DataCell(Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _supprimerPaiement(paiement['id']),
                        ),
                        if (paiement['statut'] == 'En attente')
                          ElevatedButton(
                            onPressed: () => initierPaiementOrangeMoney(paiement),
                            child: Text("Payer maintenant"),
                          ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _ajouterPaiement,
        child: Icon(Icons.add),
      ),
    );
  }
}
