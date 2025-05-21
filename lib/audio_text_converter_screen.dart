import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class AudioTextConverterScreen extends StatefulWidget {
  const AudioTextConverterScreen({super.key});

  @override
  State<AudioTextConverterScreen> createState() =>
      _AudioTextConverterScreenState();
}

class _AudioTextConverterScreenState extends State<AudioTextConverterScreen>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _transcribedText = '';
  List<LocaleName> _localeNames = [];
  String? _currentLocaleId;

  final FlutterTts _flutterTts = FlutterTts();
  String _textToSpeak = '';
  bool _isSpeaking = false;
  List<dynamic> _voices = [];
  String? _currentVoiceId;
  String? _currentTtsLanguage;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initSpeechToText();
    _initTextToSpeech();
    _requestPermissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _speechToText.stop(); // Arrête l'écoute STT si elle est active
    _flutterTts.stop(); // Arrête la synthèse vocale si elle est active
    super.dispose();
  }

  // --- Gestion des Permissions ---
  /// Demande les permissions nécessaires (microphone et stockage).
  Future<void> _requestPermissions() async {
    // Demande la permission du microphone
    PermissionStatus micStatus = await Permission.microphone.request();
    if (micStatus.isDenied) {
      // Gère la permission refusée
      _showMessage(
          'Permission microphone refusée. Veuillez l\'activer dans les paramètres.');
      return;
    }
    if (micStatus.isPermanentlyDenied) {
      // Ouvre les paramètres de l'application si la permission est refusée de manière permanente
      openAppSettings();
      return;
    }

    // Demande la permission de stockage (pour la sauvegarde de fichiers, bien que la sauvegarde audio soit complexe avec flutter_tts)
    // Pour Android 10 (API 29) et supérieur, WRITE_EXTERNAL_STORAGE est déprécié.
    // Pour iOS, l'accès aux fichiers est généralement géré par des répertoires d'application spécifiques.
    // Pour la simplicité, nous la demanderons mais noterons son utilisation limitée avec la configuration TTS actuelle.
    PermissionStatus storageStatus = await Permission.storage.request();
    if (storageStatus.isDenied) {
      _showMessage(
          'Permission de stockage refusée. Le partage pourrait être limité.');
    }
  }

  // --- Initialisation et Logique Speech-to-Text ---
  /// Initialise le service Speech-to-Text.
  Future<void> _initSpeechToText() async {
    bool available = await _speechToText.initialize(
      onError: (val) => setState(() {
        _isListening = false;
        _showMessage('Erreur STT: ${val.errorMsg}');
      }),
      onStatus: (val) => setState(() {
        if (val == 'listening') {
          _isListening = true;
        } else if (val == 'notListening') {
          _isListening = false;
        }
      }),
    );
    if (available) {
      // Récupère les locales disponibles et définit la locale par défaut (français si disponible)
      _localeNames = await _speechToText.locales();
      setState(() {
        _currentLocaleId = _localeNames
            .firstWhere((locale) => locale.localeId.startsWith('fr'),
                orElse: () => _localeNames.first)
            .localeId;
      });
    } else {
      _showMessage(
          'Le service Speech-to-Text n\'est pas disponible sur cet appareil.');
    }
  }

  /// Démarre l'écoute pour la transcription en temps réel.
  void _startListening() async {
    if (_speechToText.isAvailable && !_isListening) {
      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _transcribedText = result.recognizedWords;
          });
        },
        localeId: _currentLocaleId, // Utilise la locale sélectionnée
        listenFor:
            const Duration(seconds: 30), // Écoute pendant 30 secondes maximum
        pauseFor: const Duration(
            seconds: 3), // Met en pause si pas de parole pendant 3 secondes
        partialResults:
            true, // Affiche les résultats partiels au fur et à mesure
      );
      setState(() {
        _isListening = true;
        _transcribedText = ''; // Efface le texte précédent
      });
    } else if (_isListening) {
      _stopListening(); // Si déjà en écoute, arrête l'écoute
    } else {
      _showMessage('STT non disponible ou déjà en cours.');
    }
  }

  /// Arrête l'écoute pour la transcription.
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  // --- Initialisation et Logique Text-to-Speech ---
  /// Initialise le service Text-to-Speech.
  Future<void> _initTextToSpeech() async {
    // Gère les événements de début, de fin et d'erreur de la synthèse vocale
    _flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
    _flutterTts.setErrorHandler((msg) {
      setState(() {
        _isSpeaking = false;
        _showMessage('Erreur TTS: $msg');
      });
    });

    // Récupère les voix et langues disponibles
    _voices = await _flutterTts.getVoices;
    // Définit la langue par défaut (français si disponible, sinon la première langue trouvée)
    String defaultLanguage = 'fr-FR';
    if (_voices.isNotEmpty) {
      defaultLanguage = _voices.first['locale'] ?? 'fr-FR';
    }
    _currentTtsLanguage = defaultLanguage;
    await _flutterTts.setLanguage(defaultLanguage);
    _currentVoiceId = await _flutterTts.getDefaultVoice;

    setState(() {
      // Filtre les voix par la langue actuelle si possible, sinon prend la première
      if (_currentTtsLanguage != null) {
        _voices = _voices
            .where((voice) =>
                voice['locale'].toString().startsWith(_currentTtsLanguage!))
            .toList();
        if (_voices.isNotEmpty) {
          _currentVoiceId = _voices[0]
              ['name']; // Définit la première voix disponible pour la langue
        }
      }
    });

    // Définit la langue et la voix par défaut
    if (_currentTtsLanguage != null) {
      await _flutterTts.setLanguage(_currentTtsLanguage!);
    }
    if (_currentVoiceId != null) {
      await _flutterTts.setVoice(
          {'name': _currentVoiceId ?? '', 'locale': _currentTtsLanguage ?? ''});
    }

    await _flutterTts.setSpeechRate(0.5); // Vitesse de parole normale
    await _flutterTts.setVolume(1.0); // Volume maximum
    await _flutterTts.setPitch(1.0); // Hauteur de la voix normale
  }

  /// Déclenche la synthèse vocale du texte saisi.
  Future<void> _speak() async {
    if (_textToSpeak.isNotEmpty) {
      await _flutterTts.speak(_textToSpeak);
    } else {
      _showMessage('Veuillez entrer du texte à convertir en audio.');
    }
  }

  /// Arrête la synthèse vocale.
  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
    });
  }

  // --- Fonctions Utilitaires ---
  /// Affiche un message temporaire (SnackBar) à l'utilisateur.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Copie le texte donné dans le presse-papiers.
  Future<void> _copyText(String text) async {
    if (text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
      _showMessage('Texte copié dans le presse-papiers.');
    } else {
      _showMessage('Aucun texte à copier.');
    }
  }

  /// Partage le texte donné via les options de partage de l'appareil.
  Future<void> _shareText(String text) async {
    if (text.isNotEmpty) {
      await Share.share(text);
    } else {
      _showMessage('Aucun texte à partager.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'AudioText Converter'), // Titre de la barre d'applications
        bottom: TabBar(
          controller: _tabController, // Contrôleur pour les onglets
          tabs: const [
            Tab(
                icon: Icon(Icons.mic),
                text: 'Audio vers Texte'), // Onglet pour la transcription
            Tab(
                icon: Icon(Icons.text_fields),
                text: 'Texte vers Audio'), // Onglet pour la synthèse vocale
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController, // Vue des onglets
        children: [
          // --- Onglet 1: Audio vers Texte ---
          _buildAudioToTextTab(),
          // --- Onglet 2: Texte vers Audio ---
          _buildTextToAudioTab(),
        ],
      ),
    );
  }

  /// Construit l'interface utilisateur pour l'onglet "Audio vers Texte".
  Widget _buildAudioToTextTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sélection de la langue pour STT
          DropdownButtonFormField<String>(
            value: _currentLocaleId,
            decoration: const InputDecoration(
              labelText: 'Langue de transcription',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12.0)),
              ),
            ),
            items: _localeNames
                .map((locale) => DropdownMenuItem(
                      value: locale.localeId,
                      child: Text(locale.name),
                    ))
                .toList(),
            onChanged: (newValue) {
              setState(() {
                _currentLocaleId = newValue;
              });
            },
          ),
          const SizedBox(height: 20),
          // Bouton Enregistrer/Arrêter
          ElevatedButton.icon(
            onPressed: _speechToText.isAvailable ? _startListening : null,
            icon: Icon(_isListening ? Icons.stop : Icons.mic),
            label:
                Text(_isListening ? 'Arrêter l\'écoute' : 'Démarrer l\'écoute'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              backgroundColor:
                  _isListening ? Colors.redAccent : Colors.blueAccent,
              foregroundColor: Colors.white,
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          // Affichage du texte transcrit
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Text(
                    _transcribedText.isEmpty
                        ? 'Le texte transcrit apparaîtra ici...'
                        : _transcribedText,
                    style: TextStyle(
                        fontSize: 16,
                        color: _transcribedText.isEmpty
                            ? const Color.fromARGB(255, 168, 52, 52)
                            : const Color.fromARGB(255, 224, 191, 191)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Boutons d'action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _transcribedText.isNotEmpty
                      ? () => _copyText(_transcribedText)
                      : null,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copier'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _transcribedText.isNotEmpty
                      ? () => _shareText(_transcribedText)
                      : null,
                  icon: const Icon(Icons.share),
                  label: const Text('Partager'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construit l'interface utilisateur pour l'onglet "Texte vers Audio".
  Widget _buildTextToAudioTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Champ de saisie de texte
          TextField(
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Entrez le texte à convertir en audio',
              hintText: 'Tapez ou collez votre texte ici...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12.0)),
              ),
              alignLabelWithHint: true,
            ),
            onChanged: (text) {
              setState(() {
                _textToSpeak = text;
              });
            },
          ),
          const SizedBox(height: 20),
          // Sélection de la langue pour TTS
          DropdownButtonFormField<String>(
            value: _currentTtsLanguage,
            decoration: const InputDecoration(
              labelText: 'Langue de la synthèse vocale',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12.0)),
              ),
            ),
            items: _voices
                .map<String>((voice) =>
                    voice['locale'].toString()) // Récupère les locales uniques
                .toSet() // Assure l'unicité
                .map<DropdownMenuItem<String>>(
                    (locale) => DropdownMenuItem<String>(
                          value: locale,
                          child: Text(locale),
                        ))
                .toList(),
            onChanged: (newValue) async {
              setState(() {
                _currentTtsLanguage = newValue;
                // Filtre les voix pour la nouvelle langue
                _voices = _voices
                    .where((voice) => voice['locale'].toString() == newValue)
                    .toList();
                if (_voices.isNotEmpty) {
                  _currentVoiceId = _voices[0][
                      'name']; // Définit la première voix pour la nouvelle langue
                } else {
                  _currentVoiceId = null;
                }
              });
              if (newValue != null) {
                await _flutterTts.setLanguage(newValue);
                if (_currentVoiceId != null) {
                  await _flutterTts.setVoice(
                      {'name': _currentVoiceId ?? '', 'locale': newValue});
                }
              }
            },
          ),
          const SizedBox(height: 20),
          // Sélection de la voix pour TTS
          DropdownButtonFormField<String>(
            value: _currentVoiceId,
            decoration: const InputDecoration(
              labelText: 'Voix',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12.0)),
              ),
            ),
            items: _voices
                .map<DropdownMenuItem<String>>(
                    (voice) => DropdownMenuItem<String>(
                          value: voice['name'] as String,
                          child: Text('${voice['name']} (${voice['locale']})'),
                        ))
                .toList(),
            onChanged: (newValue) async {
              setState(() {
                _currentVoiceId = newValue;
              });
              if (newValue != null && _currentTtsLanguage != null) {
                await _flutterTts.setVoice(
                    {'name': newValue, 'locale': _currentTtsLanguage ?? ''});
              }
            },
          ),
          const SizedBox(height: 20),
          // Bouton Écouter/Arrêter
          ElevatedButton.icon(
            onPressed: _textToSpeak.isNotEmpty
                ? (_isSpeaking ? _stopSpeaking : _speak)
                : null,
            icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
            label:
                Text(_isSpeaking ? 'Arrêter la lecture' : 'Écouter le texte'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              backgroundColor:
                  _isSpeaking ? Colors.redAccent : Colors.blueAccent,
              foregroundColor: Colors.white,
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          // Note sur la sauvegarde/partage de l'audio
          const Text(
            'La sauvegarde et le partage de l\'audio généré ne sont pas directement supportés par cette implémentation locale de TTS. '
            'Cela nécessiterait une intégration avec des services cloud ou des fonctionnalités spécifiques à la plateforme.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
