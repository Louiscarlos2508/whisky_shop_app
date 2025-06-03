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
    final paiementsSnapshot = await _firestore.collection('paiements').get();
    final usersSnapshot = await _firestore.collection('users').get();
    final demandesSnapshot = await _firestore
        .collection('demandedeservice')
        .where('typeDemande', isEqualTo: 'pret')
        .where('statut', isEqualTo: 'validée')
        .get();

    // Mapping utilisateurs
    Map<String, String> beneficiaires = {};
    for (var doc in usersSnapshot.docs) {
      String userId = doc.id;
      String fullName = doc['fullName'];
      beneficiaires[userId] = fullName;
    }

    // Mapping prêts validés par userId
    Map<String, Map<String, dynamic>> pretsMap = {};
    for (var doc in demandesSnapshot.docs) {
      String userId = doc['userId'];
      pretsMap[userId] = {
        'montantPret': doc['montantPret'],
        'periodeRemboursement': doc['periodeRemboursement'],
        'montantRestant': doc['montantRestant'],
        'datePret': DateFormat('dd/MM/yyyy').format((doc['timestamp'] as Timestamp).toDate()),
      };
    }

    setState(() {
      _beneficiairesMap = beneficiaires;
      _paiements = paiementsSnapshot.docs.map((doc) {
        String beneficiaireId = doc['beneficiaire'];
        var pretInfo = pretsMap[beneficiaireId];

        Timestamp timestamp = doc['date'] ?? Timestamp.now();
        String dateFormatted = DateFormat('dd/MM/yyyy').format(timestamp.toDate());

        return {
          'id': doc.id,
          'beneficiaire': _beneficiairesMap[beneficiaireId] ?? 'Inconnu',
          'montant': doc['montant'],
          'modePaiement': doc['modePaiement'],
          'statut': doc['statut'],
          'date': dateFormatted,
          'montantPret': pretInfo?['montantPret'] ?? 0,
          'periodeRemboursement': pretInfo?['periodeRemboursement'] ?? 0,
          'montantRestant': pretInfo?['montantRestant'] ?? 0,
          'datePret': pretInfo?['datePret'] ?? '—',
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
  TextEditingController periodeRemboursementController = TextEditingController();
  TextEditingController montantRestantController = TextEditingController();

  String? beneficiaireId;
  String? modePaiement;
  String telAdmin = "+2250700000000"; // 🔁 à personnaliser
  bool isLoadingPret = false;
  bool hasPret = false;

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
onChanged: (value) async {
  setState(() {
    beneficiaireId = value as String;
    isLoadingPret = true;
    hasPret = false;
  });

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('demandedeservice')
        .where('userId', isEqualTo: beneficiaireId)
        .where('typeDemande', isEqualTo: 'pret')
        .where('statut', isEqualTo: 'validée')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first.data();

      // Vérification que les champs existent bien
      double montantPret = (doc['montantPret'] ?? 0).toDouble();
      double montantRestant = (doc['montantRestant'] ?? 0).toDouble();
      int periode = (doc['periodeRemboursement'] ?? 1).toInt();

      // Mise à jour des contrôleurs
      montantPretController.text = montantPret.toStringAsFixed(0);
      montantRestantController.text = montantRestant.toStringAsFixed(0);
      periodeRemboursementController.text = periode.toString();

      setState(() {
        hasPret = true;
      });
    } else {
      montantPretController.clear();
      montantRestantController.clear();
      periodeRemboursementController.clear();

      setState(() {
        hasPret = false;
      });
    }
  } catch (e) {
    print("Erreur de chargement des données de prêt : $e");
    montantPretController.clear();
    montantRestantController.clear();
    periodeRemboursementController.clear();
    setState(() {
      hasPret = false;
    });
  } finally {
    setState(() {
      isLoadingPret = false;
    });
  }
},

              ),
              SizedBox(height: 10),
              TextField(
                controller: montantController,
                decoration: InputDecoration(labelText: "Montant total"),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 10),
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
              if (hasPret && !isLoadingPret) ...[
                SizedBox(height: 10),
                TextField(
                  controller: montantPretController,
                  readOnly: true,
                  decoration: InputDecoration(labelText: "Montant du prêt"),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: periodeRemboursementController,
                  readOnly: true,
                  decoration: InputDecoration(labelText: "Période de remboursement (mois)"),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: montantRestantController,
                  readOnly: true,
                  decoration: InputDecoration(labelText: "Montant restant à rembourser"),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Annuler")),
          TextButton(
            onPressed: () async {
              if (beneficiaireId != null && modePaiement != null && montantController.text.isNotEmpty) {
                double montant = double.parse(montantController.text);
                double montantPret = hasPret ? double.tryParse(montantPretController.text) ?? 0 : 0;
                int periode = hasPret ? int.tryParse(periodeRemboursementController.text) ?? 1 : 1;

                double tranche = hasPret ? (montantPret / periode) : 0;
                double montantFinal = montant - tranche;
                double montantRestant = hasPret ? montantPret - tranche : 0;

                if (montantFinal < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("⚠️ Le montant final est négatif. Veuillez vérifier les données.")),
                  );
                  return;
                }

                // 🔁 Mise à jour du prêt s’il existe
                if (hasPret) {
                  final pretSnapshot = await _firestore
                      .collection('demandedeservice')
                      .where('userId', isEqualTo: beneficiaireId)
                      .where('typeDemande', isEqualTo: 'pret')
                      .where('statut', isEqualTo: 'validée')
                      .orderBy('timestamp', descending: true)
                      .limit(1)
                      .get();

                  if (pretSnapshot.docs.isNotEmpty) {
                    await _firestore.collection('demandedeservice')
                        .doc(pretSnapshot.docs.first.id)
                        .update({'montantRestant': montantRestant});
                  }
                }

                // 🔎 Récupération du numéro de téléphone
                DocumentSnapshot userDoc = await _firestore.collection('users').doc(beneficiaireId).get();
                String telDestinataire = userDoc['phone'] ?? '';

                // 💾 Enregistrement dans paiements
                await _firestore.collection('paiements').add({
                  'beneficiaire': beneficiaireId,
                  'montant': montant,
                  'montantPret': tranche,
                  'montantFinal': montantFinal,
                  'modePaiement': modePaiement,
                  'pretDeduit': hasPret,
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
                columns: const [
                  DataColumn(label: Text("Bénéficiaire")),
                  DataColumn(label: Text("Montant")),
                  DataColumn(label: Text("Mode de Paiement")),
                  DataColumn(label: Text("Statut")),
                  DataColumn(label: Text("Date")),
                  DataColumn(label: Text("Montant du prêt")),
                  DataColumn(label: Text("Période remboursement (mois)")),
                  DataColumn(label: Text("Montant restant")),
                  DataColumn(label: Text("Date du prêt")),
                  DataColumn(label: Text("Actions")),
                ],
                rows: _paiements.map((paiement) {
                  return DataRow(cells: [
                    DataCell(Text(paiement['beneficiaire'])),
                    DataCell(Text("${paiement['montant']}")),
                    DataCell(Text(paiement['modePaiement'])),
                    DataCell(Text(paiement['statut'])),
                    DataCell(Text(paiement['date'])),
                    DataCell(Text("${paiement['montantPret']}")),
                    DataCell(Text("${paiement['periodeRemboursement']}")),
                    DataCell(Text("${paiement['montantRestant']}")),
                    DataCell(Text(paiement['datePret'])),
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
              )

            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _ajouterPaiement,
        child: Icon(Icons.add),
      ),
    );
  }
}
