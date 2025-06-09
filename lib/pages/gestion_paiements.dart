import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:url_launcher/url_launcher.dart';

class GestionPaiements extends StatefulWidget {
  const GestionPaiements({super.key});

  @override
  State<GestionPaiements> createState() => _GestionPaiementsState();
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
      // Récupération parallèle des données Firestore
      final results = await Future.wait([
        _firestore.collection('paiements').get(),
        _firestore.collection('users').get(),
        _firestore
            .collection('demandedeservice')
            .where('typeDemande', isEqualTo: 'pret')
            .where('statut', isEqualTo: 'validée')
            .where('montantRestant', isGreaterThan: 0)
            .get(),
      ]);

      final paiementsSnapshot = results[0];
      final usersSnapshot = results[1];
      final demandesPretSnapshot = results[2];

      // Construction de la map des bénéficiaires
      Map<String, String> beneficiaires = {
        for (var doc in usersSnapshot.docs) doc.id: doc['fullName'] ?? 'Inconnu',
      };

      // Construction de la map des prêts valides avec tranches restantes
      Map<String, Map<String, dynamic>> pretsMap = {};
      for (var doc in demandesPretSnapshot.docs) {
        final data = doc.data();
        String userId = data['userId'];

        if ((data['tranchesRestantes'] ?? 0) > 0) {
          Timestamp? timestamp = data['timestamp'];
          String datePret = (timestamp != null)
              ? DateFormat('dd/MM/yyyy').format(timestamp.toDate())
              : '-';

          pretsMap[userId] = {
            'montantPret': data['montantPret'] ?? 0,
            'periode': data['periodeRemboursement'] ?? 0,
            'tranchesRestantes': data['tranchesRestantes'] ?? 0,
            'montantRestant': data['montantRestant'] ?? 0,
            'datePret': datePret,
            'docId': doc.id,
          };
        }
      }

      // Mise à jour de l'état
      setState(() {
        _beneficiairesMap = beneficiaires;
        _paiements = paiementsSnapshot.docs.map((doc) {
          final data = doc.data();
          String beneficiaireId = data['beneficiaire'];
          var pretInfo = pretsMap[beneficiaireId];

          // Sécuriser le champ date
          Timestamp timestamp = data['date'] ?? Timestamp.now();
          String dateFormatted = DateFormat('dd/MM/yyyy').format(timestamp.toDate());

          return {
            'id': doc.id,
            'beneficiaire': beneficiaires[beneficiaireId] ?? 'Inconnu',
            'beneficiaireId': beneficiaireId,
            'montant': data['montant'],
            'montantFinal': data['montantFinal'] ?? data['montant'],
            'modePaiement': data['modePaiement'],
            'statut': data['statut'],
            'date': dateFormatted,
            'montantPret': pretInfo?['montantPret'] ?? 0,
            'periodeRemboursement': pretInfo?['periode'] ?? 0,
            'tranchesRestantes': pretInfo?['tranchesRestantes'] ?? 0,
            'montantRestant': pretInfo?['montantRestant'] ?? 0,
            'datePret': pretInfo?['datePret'] ?? '-',
            'telDestinataire': data['telDestinataire'] ?? '',
            'pretDocId': pretInfo?['docId'],
          };
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors du chargement des données : $e");
      }
      setState(() => _loading = false);
    }
  }







  Future<void> _initierPaiement(Map<String, dynamic> paiement) async {
    String tel = paiement['telDestinataire'];
    double montantFinal = (paiement['montantFinal'] ?? 0).toDouble() ?? paiement['montant'];

    // Formatage en string sans décimales
    String montantFinalStr = montantFinal.toStringAsFixed(0);

    final uri = Uri.parse('tel:${Uri.encodeComponent("*144*2*$tel*$montantFinalStr#")}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);

      if(!mounted) return;

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
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Impossible de lancer le téléphone")));
    }
  }

  void _supprimerPaiement(String id) async {
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirmation"),
        content: Text("Voulez-vous vraiment supprimer ce paiement ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Annuler")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmation == true) {
      final doc = await FirebaseFirestore.instance.collection('paiements').doc(id).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final double montantPret = (data['montantPret'] ?? 0).toDouble();
      final String? pretDocId = data['pretDocId'];

      int nbTranches = 1;

      // Rétablir les données du prêt si applicable
      if (pretDocId != null && montantPret > 0) {
        final pretRef = FirebaseFirestore.instance.collection('demandedeservice').doc(pretDocId);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final pretSnapshot = await transaction.get(pretRef);
          final pretData = pretSnapshot.data();
          if (pretData == null) return;

          final double ancienRestant = (pretData['montantRestant'] ?? 0).toDouble();
          final int anciennesTranches = (pretData['tranchesRestantes'] ?? 0).toInt();

          transaction.update(pretRef, {
            'montantRestant': ancienRestant + montantPret,
            'tranchesRestantes': anciennesTranches + nbTranches,
          });
        });
      }

      // Marquer le paiement comme annulé
      await FirebaseFirestore.instance.collection('paiements').doc(id).update({
        'statut': 'annulé',
      });

      _fetchData();
    }
  }

  Future<void> _validerPaiement(Map<String, dynamic> paiement) async {
    final String id = paiement['id'];

    await _firestore.collection('paiements').doc(id).update({
      'statut': 'Effectué',
    });

    _fetchData();
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
    String? telDestinataire;

    showDialog(
        context: context,
        builder: (context) => FutureBuilder<Set<String>>(
            future: _getBeneficiairesPayesCeMois(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return AlertDialog(
                  content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                );
              }

              if (snapshot.hasError) {
                return AlertDialog(
                  title: Text("Erreur"),
                  content: Text("Impossible de charger la liste des bénéficiaires."),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("Fermer"))],
                );
              }

              // Liste des bénéficiaires payés ce mois-ci
              final beneficiairesPayes = snapshot.data ?? {};

              // Filtrer la map des bénéficiaires
              final beneficiairesFiltres = Map<String, String>.from(_beneficiairesMap)
              ..removeWhere((key, value) => beneficiairesPayes.contains(key));

              return StatefulBuilder(
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
                          items: beneficiairesFiltres.entries.map((entry) {
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
                            final userDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(beneficiaireId)
                                .get();

                            telDestinataire = userDoc.data()?['phone'] ?? "";

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
                              double montantPret = (doc['montantPret'] ?? 0).toDouble();
                              double montantRestant = (doc['montantRestant'] ?? montantPret).toDouble();

                              if (montantRestant > 0) {
                                montantPretController.text = montantPret.toString();
                                montantRestantController.text = montantRestant.toString();
                                periodeRemboursementController.text = (doc['tranchesRestantes'] ?? 1).toString();
                                telDestinataire = doc['telDestinataire'] ?? telDestinataire;
                                hasPret = true;
                                if (kDebugMode) {
                                  print("DEBUG Loan Load: montantPretController=${montantPretController.text}, montantRestantController=${montantRestantController.text}, periodeRemboursementController=${periodeRemboursementController.text}");
                                }
                              } else {
                                montantPretController.clear();
                                montantRestantController.clear();
                                periodeRemboursementController.clear();
                                hasPret = false;
                              }
                            }

                          } catch (e) {
                            if (kDebugMode) {
                              print("Erreur chargement prêt: $e");
                            }
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
                      if (kDebugMode) {
                        print("🟡 Tentative d'ajout de paiement");
                      }

                      if (beneficiaireId == null || modePaiement == null || montantController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("❌ Veuillez remplir tous les champs obligatoires.")),
                        );
                        return;
                      }

                      try {
                        double montant = double.tryParse(montantController.text) ?? 0.0;
                        double montantRestant = double.tryParse(montantRestantController.text) ?? 0;

                        if (hasPret) {
                          final now = DateTime.now();
                          final firstDayOfMonth = DateTime(now.year, now.month, 1);
                          final lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

                          final paiementsExistants = await FirebaseFirestore.instance
                              .collection('paiements')
                              .where('beneficiaire', isEqualTo: beneficiaireId)
                              .where('pretDeduit', isEqualTo: true)
                              .where('statut', whereIn: ['En Attente', 'Validé', 'Effectué'])
                              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth))
                              .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastDayOfMonth))
                              .get();

                          if (paiementsExistants.docs.isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("❌ Paiement déjà effectué ce mois-ci.")),
                            );
                            return;
                          }
                        }

                        double montantDeduit = 0;
                        double montantFinal = montant;
                        String? pretDocId;
                        Map<String, dynamic> pretData = {};
                        double nouveauMontantRestant = montantRestant;
                        int nouvellesTranches = 0;

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
                            final doc = pretSnapshot.docs.first;
                            pretDocId = doc.id;
                            pretData = doc.data();

                            final double tranche = (doc['montantMensuel'] as num).toDouble();
                            final int tranchesRestantes = doc['tranchesRestantes'] ?? 1;

                            if (tranche == 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Le montant mensuel du prêt est invalide.")),
                              );
                              return;
                            }


                            int nbTranchesPayees = (montant / tranche).floor();
                            if (nbTranchesPayees > 1) nbTranchesPayees = 1;

                            if (nbTranchesPayees == 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(" Le montant est insuffisant pour couvrir une tranche de prêt.")),
                              );
                              return;
                            }

                            montantDeduit = nbTranchesPayees * tranche;
                            montantFinal = montant - montantDeduit;

                            nouveauMontantRestant = montantRestant - montantDeduit;
                            if (nouveauMontantRestant < 0) nouveauMontantRestant = 0;

                            nouvellesTranches = tranchesRestantes - nbTranchesPayees;
                            if (nouvellesTranches < 0) nouvellesTranches = 0;

                            // Mise à jour du prêt
                            final Map<String, dynamic> miseAJourPret = {
                              'montantRestant': nouveauMontantRestant,
                              'tranchesRestantes': nouvellesTranches,
                            };

                            if (nouveauMontantRestant == 0) {
                              miseAJourPret['rembourse'] = true;
                            }

                            await FirebaseFirestore.instance
                                .collection('demandedeservice')
                                .doc(pretDocId)
                                .update(miseAJourPret);
                          }
                        }

                        // Enregistrement du paiement
                        await FirebaseFirestore.instance.collection('paiements').add({
                          'beneficiaire': beneficiaireId,
                          'montant': montant.toDouble(),         // Converti en double
                          'montantPret': montantDeduit.toDouble(),
                          'montantFinal': montantFinal.toDouble(),
                          'modePaiement': modePaiement,
                          'pretDeduit': hasPret,
                          'statut': 'En Attente',
                          'date': Timestamp.now(),
                          'telAdmin': telAdmin,
                          'telDestinataire': telDestinataire,
                          if (hasPret) ...{
                            'pretDocId': pretDocId,
                            'montantRestant': nouveauMontantRestant.toDouble(),
                            'tranchesRestantes': nouvellesTranches,  // int sans toDouble()
                            'datePret': pretData['dateDemandePret'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
                            'periodeRemboursement': pretData['periodeRemboursement'],
                            'montantPretInitial': (pretData['montantPret'] as num).toDouble(),
                            'rembourse': nouveauMontantRestant == 0,
                          },
                        });

                        if (kDebugMode) {
                          print("Paiement ajouté avec succès");
                        }

                        _fetchData();
                        Navigator.pop(context);
                      } catch (e) {
                        if (kDebugMode) {
                          print("❌ Erreur lors de l'ajout du paiement : $e");
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Erreur lors de l'ajout du paiement.")),
                        );
                      }
                    },
                    child: Text("Ajouter"),
                  )

                ],
                ),
              );
            },
        ),
    );
  }

  Future<Set<String>> _getBeneficiairesPayesCeMois() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final snapshot = await FirebaseFirestore.instance
        .collection('paiements')
        .where('pretDeduit', isEqualTo: true) // Ou selon ton critère de paiement
        .where('statut', whereIn: ['En Attente', 'Validé', 'Effectué'])
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastDayOfMonth))
        .get();

    // Extraire les IDs des bénéficiaires payés ce mois-ci
    final Set<String> payesIds = snapshot.docs.map((doc) => doc['beneficiaire'] as String).toSet();

    return payesIds;
  }


  @override
  Widget build(BuildContext context) {
    String moisSelectionne = 'Tous';

    final moisDisponibles = ['Tous', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];

    final paiementsFiltres = moisSelectionne == 'Tous'
        ? _paiements
        : _paiements.where((p) {
      final parts = p['date'].split('/');
      final datePaiement = DateTime(
          int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0])
      );
      return datePaiement.month == moisDisponibles.indexOf(moisSelectionne);
    }).toList();


    final paiementsTries = List<Map<String, dynamic>>.from(paiementsFiltres)
      ..sort((a, b) {
        if (a['statut'] == 'En Attente' && b['statut'] != 'En Attente') return -1;
        if (a['statut'] != 'En Attente' && b['statut'] == 'En Attente') return 1;
        return 0;
      });


    return Scaffold(
      appBar: AppBar(
        title: Text("Gestion des paiements"),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: DropdownButton<String>(
              value: moisSelectionne,
              icon: Icon(Icons.arrow_drop_down),
              underline: Container(height: 2, color: Colors.green),
              items: moisDisponibles.map((String mois) {
                return DropdownMenuItem<String>(
                  value: mois,
                  child: Text(mois),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  moisSelectionne = newValue!;
                });
              },
            ),
          ),
        ),

        actions: [
          IconButton(
            icon: Icon(Icons.download, color: Colors.green,),
            tooltip: "Exporter en Excel",
            onPressed: () {
              _exporterPaiementsEnAttente(_paiements, context);
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
                        /*if (paiement['montantPret'] > 0 && paiement['tranchesRestantes'] > 0) ...[
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
                         */

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
    if (kDebugMode) {
      print("🟢 Paiement reçu : $paiement");
    }

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

                if ((paiement['montantPret'] ?? 0) > 0 ||
                    (paiement['montantRestant'] ?? 0) > 0 ||
                    (paiement['tranchesRestantes'] ?? 0) > 0) ...[
                  Divider(height: 32),
                  Text("Prêt associé", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 8),
                  _detailItem("Montant du prêt", "${paiement['montantPret'] ?? '-'}"),
                  _detailItem("Montant restant", "${paiement['montantRestant'] ?? '-'}"),
                  _detailItem("Tranches restantes", "${paiement['tranchesRestantes'] ?? '-'}"),
                  _detailItem("Date du prêt", "${paiement['datePret'] ?? '-'}"),
                  _detailItem("Montant salaire final", "${paiement['montantFinal'] ?? '-'}"),
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



  Future<void> _exporterPaiementsEnAttente(List<Map<String, dynamic>> paiements, BuildContext context) async {
    try {
      final paiementsEnAttente = paiements.where((p) => p['statut'] == 'En Attente').toList();

      if (paiementsEnAttente.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Aucun paiement en attente à exporter.")),
        );
        return;
      }

      // Créer le fichier Excel
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
          double.tryParse((paiement['montantFinal'] ?? paiement['montant'] ?? 0).toString()) ?? 0,
        );
      }

      final Uint8List bytes = Uint8List.fromList(workbook.saveAsStream());
      workbook.dispose();

      // Enregistrer le fichier avec file_saver
      final fileName = 'paiements_en_attente_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      print('Taille du fichier en bytes: ${bytes.length}');

      final result = await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: 'xlsx',
        mimeType: MimeType.custom,
        customMimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fichier exporté avec succès !")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : échec de l'enregistrement du fichier.")),
        );
      }
    } catch (e, stack) {
      if (kDebugMode) {
        print("Erreur : $e");
        print("StackTrace : $stack");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'export : $e")),
      );
    }
  }

}
