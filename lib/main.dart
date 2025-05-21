import 'package:flutter/material.dart';
import 'package:audio_text_converter/audio_text_converter_screen.dart'; // Importe l'écran principal de l'application

void main() {
  runApp(const MyApp());
}

/// Classe principale de l'application.
/// C'est un StatelessWidget qui configure le MaterialApp et l'écran de démarrage.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AudioText Converter', // Titre de l'application
      theme: ThemeData(
        primarySwatch: Colors.blue, // Couleur principale de l'application
        visualDensity: VisualDensity.adaptivePlatformDensity, // Densité visuelle adaptative
        fontFamily: 'Inter', // Utilisation de la police Inter
      ),
      home: const AudioTextConverterScreen(), // L'écran principal de l'application
    );
  }
}
