import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GestionPointVente extends StatefulWidget {
  const GestionPointVente({super.key});

  @override
  _GestionPointVenteState createState() => _GestionPointVenteState();
}

class _GestionPointVenteState extends State<GestionPointVente> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _pointsVente = [];
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      QuerySnapshot pointsVenteSnapshot =
          await _firestore.collection('points_vente').get();
      QuerySnapshot usersSnapshot =
          await _firestore.collection('users').get();

      setState(() {
        _pointsVente = pointsVenteSnapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'nom': data['nom'],
            'adresse': data['adresse'],
            'telephone': data['telephone'],
            'gerant': data['gerant'],
            'employes': List<String>.from(data['employes'] ?? []),
            'taches': List<String>.from(data['taches'] ?? []),
          };
        }).toList();

        _users = usersSnapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'fullName': data.containsKey('fullName') ? data['fullName'] : 'Inconnu',
            'role': data['role'],
          };
        }).toList();

        _loading = false;
      });
    } catch (e) {
      print("Erreur lors de la récupération des données : $e");
      setState(() => _loading = false);
    }
  }

  void _ajouterOuModifierTaches(String pointVenteId, List<String> tachesExistantes) {
    List<TextEditingController> controllers =
        tachesExistantes.map((t) => TextEditingController(text: t)).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("Assigner des tâches"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                ...controllers.asMap().entries.map((entry) {
                  int index = entry.key;
                  TextEditingController controller = entry.value;
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(labelText: 'Tâche ${index + 1}'),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            controllers.removeAt(index);
                          });
                        },
                      )
                    ],
                  );
                }),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      controllers.add(TextEditingController());
                    });
                  },
                  icon: Icon(Icons.add),
                  label: Text("Ajouter une tâche"),
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Annuler")),
            TextButton(
              onPressed: () async {
                List<String> taches = controllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                await _firestore.collection('points_vente').doc(pointVenteId).update({
                  'taches': taches,
                });
                _fetchData();
                Navigator.pop(context);
              },
              child: Text("Enregistrer"),
            ),
          ],
        ),
      ),
    );
  }
void _ajouterPointDeVente() {
  final nomController = TextEditingController();
  final adresseController = TextEditingController();
  final telephoneController = TextEditingController();
  String? gerantSelectionne;
  List<String> employesSelectionnes = [];

  showDialog(
    context: context,
    builder: (context) {
      final gerants = _users.where((u) => u['role'] == 'gerant').toList();
      final employes = _users.where((u) => u['role'] == 'employe').toList();

      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Ajouter un point de vente'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nomController,
                  decoration: InputDecoration(labelText: 'Nom du point de vente'),
                ),
                TextField(
                  controller: adresseController,
                  decoration: InputDecoration(labelText: 'Adresse'),
                ),
                TextField(
                  controller: telephoneController,
                  decoration: InputDecoration(labelText: 'Téléphone'),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: gerantSelectionne,
                  decoration: InputDecoration(labelText: 'Sélectionner un gérant'),
                  items: gerants.map<DropdownMenuItem<String>>((g) {
                    return DropdownMenuItem<String>(
                      value: g['id'] as String,
                      child: Text(g['fullName']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      gerantSelectionne = value;
                    });
                  },
                ),
                SizedBox(height: 16),
                Text('Sélectionner les employés :'),
                ...employes.map((e) {
                  return CheckboxListTile(
                    title: Text(e['fullName']),
                    value: employesSelectionnes.contains(e['id']),
                    onChanged: (bool? selected) {
                      setState(() {
                        if (selected == true) {
                          employesSelectionnes.add(e['id']);
                        } else {
                          employesSelectionnes.remove(e['id']);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (nomController.text.trim().isEmpty ||
                    adresseController.text.trim().isEmpty ||
                    telephoneController.text.trim().isEmpty ||
                    gerantSelectionne == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Veuillez remplir tous les champs.')),
                  );
                  return;
                }

                await _firestore.collection('points_vente').add({
                  'nom': nomController.text.trim(),
                  'adresse': adresseController.text.trim(),
                  'telephone': telephoneController.text.trim(),
                  'gerant': gerantSelectionne,
                  'employes': employesSelectionnes,
                  'taches': [],
                });

                Navigator.pop(context);
                _fetchData();
              },
              child: Text('Ajouter'),
            ),
          ],
        ),
      );
    },
  );
}

void _modifierPointVente(Map<String, dynamic> pointVente) {
  final nomController = TextEditingController(text: pointVente['nom']);
  final adresseController = TextEditingController(text: pointVente['adresse']);
  final telephoneController = TextEditingController(text: pointVente['telephone']);
  String? gerantSelectionne = pointVente['gerant'];
  List<String> employesSelectionnes = List<String>.from(pointVente['employes'] ?? []);

  showDialog(
    context: context,
    builder: (context) {
      final gerants = _users.where((u) => u['role'] == 'gerant').toList();
      final employes = _users.where((u) => u['role'] == 'employe').toList();

      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Modifier le point de vente'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nomController,
                  decoration: InputDecoration(labelText: 'Nom du point de vente'),
                ),
                TextField(
                  controller: adresseController,
                  decoration: InputDecoration(labelText: 'Adresse'),
                ),
                TextField(
                  controller: telephoneController,
                  decoration: InputDecoration(labelText: 'Téléphone'),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: gerantSelectionne,
                  decoration: InputDecoration(labelText: 'Sélectionner un gérant'),
                  items: gerants.map<DropdownMenuItem<String>>((g) {
                    return DropdownMenuItem<String>(
                      value: g['id'],
                      child: Text(g['fullName']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      gerantSelectionne = value;
                    });
                  },
                ),
                SizedBox(height: 16),
                Text('Sélectionner les employés :'),
                ...employes.map((e) {
                  return CheckboxListTile(
                    title: Text(e['fullName']),
                    value: employesSelectionnes.contains(e['id']),
                    onChanged: (bool? selected) {
                      setState(() {
                        if (selected == true) {
                          employesSelectionnes.add(e['id']);
                        } else {
                          employesSelectionnes.remove(e['id']);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (nomController.text.trim().isEmpty ||
                    adresseController.text.trim().isEmpty ||
                    telephoneController.text.trim().isEmpty ||
                    gerantSelectionne == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Veuillez remplir tous les champs.')),
                  );
                  return;
                }

                await _firestore.collection('points_vente').doc(pointVente['id']).update({
                  'nom': nomController.text.trim(),
                  'adresse': adresseController.text.trim(),
                  'telephone': telephoneController.text.trim(),
                  'gerant': gerantSelectionne,
                  'employes': employesSelectionnes,
                });

                Navigator.pop(context);
                _fetchData();
              },
              child: Text('Enregistrer'),
            ),
          ],
        ),
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Gestion des Points de Vente")),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _pointsVente.length,
              itemBuilder: (context, index) {
                final pointVente = _pointsVente[index];
                return Card(
                  child: ListTile(
                    title: Text(pointVente['nom']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Adresse: ${pointVente['adresse']}"),
                        Text("Téléphone: ${pointVente['telephone']}"),
                        Text("Gérant: ${_users.firstWhere((u) => u['id'] == pointVente['gerant'], orElse: () => {'fullName': 'Inconnu'})['fullName']}"),
                        Text("Employés: ${pointVente['employes'].map((id) => _users.firstWhere((u) => u['id'] == id, orElse: () => {'fullName': 'Inconnu'})['fullName']).join(', ')}"),
                        if (pointVente['taches'].isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: pointVente['taches']
                                .map<Widget>((t) => Text("- $t", style: TextStyle(color: Colors.blue)))
                                .toList(),
                          )
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: Icon(Icons.edit), onPressed: () => _modifierPointVente(pointVente)),
                        IconButton(
                          icon: Icon(Icons.add_task, color: Colors.blue),
                          onPressed: () => _ajouterOuModifierTaches(pointVente['id'], pointVente['taches']),
                        ),
                        IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: () {/* supprimer */}),
                      ],
                    ),
                  ),
                );
              },
            ),
            floatingActionButton: FloatingActionButton(
  onPressed: _ajouterPointDeVente,
  tooltip: "Ajouter un point de vente",
  child: Icon(Icons.add),
),

    );
    
  }
}
