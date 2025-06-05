import 'package:flutter/material.dart';


class Stats extends StatelessWidget  {
  static const String routeName = '/stats';

  const Stats({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Etst des lieux et ventes")),
      body: Center(
        child: Text("Liste des points des ventes par endroit..."),
      ),
    );
  }
}
