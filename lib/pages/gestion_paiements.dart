import 'dart:io';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:url_launcher/url_launcher.dart';

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
      final pretsSnapshot = await _firestore.collection('prets').get();

      Map<String, String> beneficiaires = {};
      for (var doc in usersSnapshot.docs) {
        String userId = doc.id;
        String fullName = doc['fullName'];
        beneficiaires[userId] = fullName;
      }

      Map<String, Map<String, dynamic>> pretsMap = {};
      for (var doc in pretsSnapshot.docs) {
        String userId = doc['userId'];
        if ((doc['tranchesRestantes'] ?? 0) > 0) {
          pretsMap[userId] = {
            'montantPret': doc['montantPret'],
            'periode': doc['periode'],
            'tranchesRestantes': doc['tranchesRestantes'],
            'montantRestant': doc['montantRestant'],
            'datePret': DateFormat('dd/MM/yyyy').format((doc['dateCreation'] as Timestamp).toDate()),
            'docId': doc.id,
          };
        }
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
            'beneficiaireId': beneficiaireId,
            'montant': doc['montant'],
            'modePaiement': doc['modePaiement'],
            'statut': doc['statut'],
            'date': dateFormatted,
            'montantPret': pretInfo?['montantPret'] ?? 0,
            'periode': pretInfo?['periode'] ?? 0,
            'tranchesRestantes': pretInfo?['tranchesRestantes'] ?? 0,
            'montantRestant': pretInfo?['montantRestant'] ?? 0,
            'datePret': pretInfo?['datePret'] ?? '-',
            'telDestinataire': doc['telDestinataire'] ?? '',
            'pretDocId': pretInfo?['docId'],
          };
        }).toList();
        _loading = false;
      });
    } catch (e) {
      print("Erreur : $e");
      setState(() => _loading = false);
    }
  }





  Future<void> _initierPaiement(Map<String, dynamic> paiement) async {
    String tel = paiement['telDestinataire'];
    double montantFinal = paiement['montantFinal'] ?? paiement['montant'];

    // Formatage en string sans décimales
    String montantFinalStr = montantFinal.toStringAsFixed(0);

    final uri = Uri.parse('tel:${Uri.encodeComponent("*144*2*1*$tel*$montantFinalStr#")}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirmation'),
          content: Text('Le paiement a-t-il été effectué avec succès ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Annuler"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _validerPaiement(paiement);
              },
              child: Text("Oui, confirmé"),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Impossible de lancer le téléphone")));
    }
  }


  Future<void> _validerPaiement(Map<String, dynamic> paiement) async {
    final id = paiement['id'];
    final pretDocId = paiement['pretDocId'];

    double montant = paiement['montant'];
    double montantPret = paiement['montantPret'];
    int tranchesRestantes = paiement['tranchesRestantes'];
    double montantRestant = paiement['montantRestant'];
    int periode = paiement['periodeRemboursement'];

    if (montantPret > 0 && pretDocId != null) {
      // Calcul tranche et déduction du prêt
      double tranche = montantPret / periode;
      int nbTranchesPayees = (montant / tranche).floor();
      double montantDeduit = nbTranchesPayees * tranche;

      double nouveauMontantRestant = montantRestant - montantDeduit;
      int nouvellesTranches = tranchesRestantes - nbTranchesPayees;

      if (nouveauMontantRestant < 0) nouveauMontantRestant = 0;
      if (nouvellesTranches < 0) nouvellesTranches = 0;

      // Mise à jour prêt
      await _firestore.collection('prets').doc(pretDocId).update({
        'montantRestant': nouveauMontantRestant,
        'tranchesRestantes': nouvellesTranches,
      });
    }

    // Mise à jour statut paiement
    await _firestore.collection('paiements').doc(id).update({
      'statut': 'Effectué',
    });

    _fetchData();
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
    String telAdmin = "+2250700000000";
    bool isLoadingPret = false;
    bool hasPret = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("Ajouter un paiement"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Informations du bénéficiaire", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                DropdownButtonFormField(
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
                          .where('montantRestant', isGreaterThan: 0)
                          .orderBy('timestamp', descending: true)
                          .limit(1)
                          .get();

                      if (snapshot.docs.isNotEmpty) {
                        final doc = snapshot.docs.first.data();
                        double montantRestant = (doc['montantRestant'] ?? 0).toDouble();

                        if (montantRestant > 0) {
                          montantPretController.text = (doc['montantPret'] ?? 0).toString();
                          montantRestantController.text = montantRestant.toString();
                          periodeRemboursementController.text = (doc['periodeRemboursement'] ?? 1).toString();
                          hasPret = true;
                        } else {
                          montantPretController.clear();
                          montantRestantController.clear();
                          periodeRemboursementController.clear();
                          hasPret = false; // prêt fini => ne pas afficher les champs
                        }
                      }

                    } catch (e) {
                      print("Erreur chargement prêt: $e");
                    } finally {
                      setState(() => isLoadingPret = false);
                    }
                  },
                ),
                SizedBox(height: 16),
                Text("Détails du paiement", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                TextField(
                  controller: montantController,
                  decoration: InputDecoration(labelText: "Montant à verser", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 12),
                DropdownButtonFormField(
                  hint: Text("Mode de paiement"),
                  items: ['Orange Money', 'Virement Bancaire'].map((mode) {
                    return DropdownMenuItem(value: mode, child: Text(mode));
                  }).toList(),
                  onChanged: (value) => setState(() => modePaiement = value as String),
                ),
                SizedBox(height: 16),
                if (hasPret && !isLoadingPret) ...[
                  Text("Informations sur le prêt", style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  _readonlyField(label: "Montant du prêt", controller: montantPretController),
                  SizedBox(height: 8),
                  _readonlyField(label: "Période de remboursement (mois)", controller: periodeRemboursementController),
                  SizedBox(height: 8),
                  _readonlyField(label: "Montant restant à payer", controller: montantRestantController),
                ],
              ],
            ),
          ),

          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Annuler")),
            TextButton(
              onPressed: () async {
                print("🟡 Tentative d'ajout de paiement");

                if (beneficiaireId == null || modePaiement == null || montantController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("❌ Veuillez remplir tous les champs obligatoires.")),
                  );
                  return;
                }

                try {
                  double montant = double.tryParse(montantController.text) ?? 0;
                  double montantPret = double.tryParse(montantPretController.text) ?? 0;
                  double montantRestant = double.tryParse(montantRestantController.text) ?? 0;
                  int periode = int.tryParse(periodeRemboursementController.text) ?? 1;

                  // Vérification si prêt déjà payé
                  if (hasPret) {
                    final paiementsExistants = await FirebaseFirestore.instance
                        .collection('paiements')
                        .where('beneficiaire', isEqualTo: beneficiaireId)
                        .where('pretDeduit', isEqualTo: true)
                        .orderBy('date', descending: true)
                        .limit(1)
                        .get();

                    if (paiementsExistants.docs.isNotEmpty) {
                      DateTime lastDate = (paiementsExistants.docs.first['date'] as Timestamp).toDate();
                      DateTime now = DateTime.now();
                      if (lastDate.month == now.month && lastDate.year == now.year) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("❌ Paiement déjà effectué ce mois-ci.")),
                        );
                        return;
                      }
                    }

                    /*if (montantRestant <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("✅ Le prêt a déjà été remboursé.")),
                      );
                      return;
                    }

                     */
                  }

                  double tranche = 0;
                  int moisPayes = 0;
                  double montantDeduit = 0;

                  if (hasPret) {
                    tranche = montantPret / periode;
                    moisPayes = (montant / tranche).floor();
                    montantDeduit = moisPayes * tranche;
                  }

                  if (tranche == 0 && hasPret) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("❌ Erreur : tranche invalide.")),
                    );
                    return;
                  }

                  double montantFinal = montant - montantDeduit;
                  double nouveauMontantRestant = montantRestant - montantDeduit;
                  if (nouveauMontantRestant < 0) nouveauMontantRestant = 0;

                  // c'est la miise à jour du prêt
                  if (hasPret) {
                    final pretSnapshot = await FirebaseFirestore.instance
                        .collection('demandedeservice')
                        .where('userId', isEqualTo: beneficiaireId)
                        .where('typeDemande', isEqualTo: 'pret')
                        .where('statut', isEqualTo: 'validée')
                        .where('montantRestant', isGreaterThan: 0)
                        .orderBy('timestamp', descending: true)
                        .limit(1)
                        .get();

                    if (pretSnapshot.docs.isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('demandedeservice')
                          .doc(pretSnapshot.docs.first.id)
                          .update({'montantRestant': nouveauMontantRestant});
                    }
                  }

                  DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(beneficiaireId).get();
                  String telDestinataire = userDoc['phone'] ?? '';

                  await FirebaseFirestore.instance.collection('paiements').add({
                    'beneficiaire': beneficiaireId,
                    'montant': montant,
                    'montantPret': montantDeduit,
                    'montantFinal': montantFinal,
                    'modePaiement': modePaiement,
                    'pretDeduit': hasPret,
                    'statut': 'En Attente',
                    'date': Timestamp.now(),
                    'telAdmin': telAdmin,
                    'telDestinataire': telDestinataire,
                  });

                  print("✅ Paiement ajouté avec succès");

                  _fetchData();
                  Navigator.pop(context);
                } catch (e) {
                  print("❌ Erreur lors de l'ajout du paiement : $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur lors de l'ajout du paiement.")),
                  );
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
    // xa c'est pour tier par statut
    final paiementsTries = List<Map<String, dynamic>>.from(_paiements)
      ..sort((a, b) {
        if (a['statut'] == 'En Attente' && b['statut'] != 'En Attente') return -1;
        if (a['statut'] != 'En Attente' && b['statut'] == 'En Attente') return 1;
        return 0;
      });

    return Scaffold(
      appBar: AppBar(
        title: Text("Gestion des paiements"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: Colors.green,),
            tooltip: "Exporter en Excel",
            onPressed: () {
              _exporterPaiementsEnAttente(_paiements);
            },
          ),
        ],
      ),

      body: _loading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: paiementsTries.length,
            itemBuilder: (context, index) {
              final paiement = paiementsTries[index];
              return GestureDetector(
                onTap: () => _afficherDetailsPaiement(context, paiement),
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paiement['beneficiaire'],
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _infoChip("Montant", "${paiement['montant']}"),
                            _infoChip("Statut", paiement['statut']),

                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _infoChip("Mode", paiement['modePaiement']),
                            _infoChip("Date", paiement['date']),
                          ],
                        ),
                        if (paiement['montantPret'] > 0 && paiement['tranchesRestantes'] > 0) ...[
                          Divider(),
                          Text("Détails du prêt", style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _infoChip("Montant prêt", "${paiement['montantPret']}"),
                              _infoChip("Tranches restantes", "${paiement['tranchesRestantes']}"),
                            ],
                          ),
                          _infoChip("Montant restant", "${paiement['montantRestant']}"),
                          _infoChip("Date prêt", paiement['datePret']),
                        ],
                        if (paiement['statut'] == 'En Attente') ...[
                          Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                icon: Icon(Icons.payment),
                                label: Text("Payer"),
                                onPressed: () => _initierPaiement(paiement),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _supprimerPaiement(paiement['id']),
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _ajouterPaiement,
        child: Icon(Icons.add),
      ),
    );
  }


  Widget _infoChip(String label, String value) {
    return Chip(
      label: Text("$label: $value", style: TextStyle(fontSize: 12)),
      backgroundColor: Colors.grey.shade200,
    );
  }

  Widget _readonlyField({required String label, required TextEditingController controller}) {
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        fillColor: Colors.grey.shade100,
        filled: true,
      ),
    );
  }


  void _afficherDetailsPaiement(BuildContext context, Map<String, dynamic> paiement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Text("Détails du paiement", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),

                _detailItem("Bénéficiaire", paiement['beneficiaire']),
                _detailItem("Montant", "${paiement['montant']}"),
                _detailItem("Statut", paiement['statut']),
                _detailItem("Mode de paiement", paiement['modePaiement']),
                _detailItem("Date", "${paiement['date']}"),

                if ((paiement['montantPret'] ?? 0) > 0 && (paiement['tranchesRestantes'] ?? 0) > 0) ...[
                  Divider(height: 32),
                  Text("Prêt associé", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 8),
                  _detailItem("Montant du prêt", "${paiement['montantPret']}"),
                  _detailItem("Montant restant", "${paiement['montantRestant']}"),
                  _detailItem("Tranches restantes", "${paiement['tranchesRestantes']}"),
                  _detailItem("Date du prêt", "${paiement['datePret']}"),
                ],

                SizedBox(height: 24),
                if (paiement['statut'] == 'En Attente') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.payment),
                      label: Text("Payer"),
                      onPressed: () {
                        Navigator.pop(context);
                        _initierPaiement(paiement);
                      },
                    ),
                  ),
                ],
                SizedBox(height: 8),
                Center(
                  child: TextButton(
                    child: Text("Fermer"),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: Text(value ?? '', style: TextStyle(color: Colors.grey[700]))),
        ],
      ),
    );
  }



  Future<void> _exporterPaiementsEnAttente(List<Map<String, dynamic>> paiements) async {
    try {
      final paiementsEnAttente = paiements.where((p) => p['statut'] == 'En Attente').toList();

      if (paiementsEnAttente.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Aucun paiement en attente à exporter.")));
        return;
      }

      if (Platform.isAndroid && (await _androidVersion()) <= 10) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Permission de stockage refusée")));
          return;
        }
      }

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.name = 'PaiementsEnAttente';

      sheet.getRangeByName('A1').setText('Nom bénéficiaire');
      sheet.getRangeByName('B1').setText('Numéro de téléphone');
      sheet.getRangeByName('C1').setText('Montant à recevoir');

      for (int i = 0; i < paiementsEnAttente.length; i++) {
        final paiement = paiementsEnAttente[i];
        sheet.getRangeByIndex(i + 2, 1).setText(paiement['beneficiaire'] ?? '');
        sheet.getRangeByIndex(i + 2, 2).setText(paiement['telDestinataire'] ?? '');
        sheet.getRangeByIndex(i + 2, 3).setNumber(
            double.tryParse((paiement['montantFinal'] ?? paiement['montant'] ?? 0).toString()) ?? 0);
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      String downloadsPath;
      if (Platform.isAndroid) {
        downloadsPath = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOWNLOAD);
      } else {
        downloadsPath = (await getApplicationDocumentsDirectory()).path;
      }

      final filePath = '$downloadsPath/paiements_en_attente_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(" Fichier exporté : $filePath")));
    } catch (e, stack) {
      print("Erreur lors de l'export Excel : $e");
      print("StackTrace : $stack");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur lors de l'export : $e")));
    }
  }


  Future<int> _androidVersion() async {
    if (!Platform.isAndroid) return 0;
    final version = await Process.run('getprop', ['ro.build.version.sdk']);
    return int.tryParse(version.stdout.toString().trim()) ?? 30;
  }



}
