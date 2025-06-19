import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AudioText Converter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue)
            .copyWith(secondary: Colors.orange),
        fontFamily: 'Roboto',
      ),
      home: const AudioTextConverterScreen(),
    );
  }
}

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
  List<LocaleName> _localeNames = [
    LocaleName('fr-FR', 'Français'),
    LocaleName('en-US', 'Anglais (États-Unis)'),
    LocaleName('es-ES', 'Espagnol (Espagne)'),
    LocaleName('de-DE', 'Allemand (Allemagne)'),
    LocaleName('it-IT', 'Italien (Italie)'),
    LocaleName('pt-PT', 'Portugais (Portugal)'),
    LocaleName('ru-RU', 'Russe (Russie)'),
    LocaleName('zh-CN', 'Chinois (Chine)'),
  ];

  String? _currentLocaleId;

  final FlutterTts _flutterTts = FlutterTts();
  String _textToSpeak = '';
  bool _isSpeaking = false;
  List<dynamic> _voices = [
    {'name': 'fr-FR', 'locale': 'fr-FR'},
    {'name': 'en-US', 'locale': 'en-US'},
    {'name': 'es-ES', 'locale': 'es-ES'},
    {'name': 'de-DE', 'locale': 'de-DE'},
    {'name': 'it-IT', 'locale': 'it-IT'},
    {'name': 'pt-PT', 'locale': 'pt-PT'},
    {'name': 'ru-RU', 'locale': 'ru-RU'},
    {'name': 'zh-CN', 'locale': 'zh-CN'},
    {'name': 'ja-JP', 'locale': 'ja-JP'},
    {'name': 'ko-KR', 'locale': 'ko-KR'},
    {'name': 'ar-SA', 'locale': 'ar-SA'},
    {'name': 'nl-NL', 'locale': 'nl-NL'},
    {'name': 'sv-SE', 'locale': 'sv-SE'},
    {'name': 'da-DK', 'locale': 'da-DK'},
    {'name': 'fi-FI', 'locale': 'fi-FI'},
    {'name': 'no-NO', 'locale': 'no-NO'},
    {'name': 'pl-PL', 'locale': 'pl-PL'},
    {'name': 'tr-TR', 'locale': 'tr-TR'},
    {'name': 'th-TH', 'locale': 'th-TH'},
    {'name': 'vi-VN', 'locale': 'vi-VN'},
    {'name': 'hi-IN', 'locale': 'hi-IN'},
    {'name': 'bn-BD', 'locale': 'bn-BD'},
  ];

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

  // --- Speech to Text Initialization ---
  Future<void> _initSpeechToText() async {
    await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (error) {
        setState(() {
          _isListening = false;
        });
      },
    );
    setState(() {
      _currentLocaleId = _localeNames.first.localeId;
    });
  }

  // --- Text to Speech Initialization ---
  Future<void> _initTextToSpeech() async {
    await _flutterTts.setLanguage(_voices.first['locale']);
    setState(() {
      _currentTtsLanguage = _voices.first['locale'];
      _currentVoiceId = _voices.first['name'];
    });
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
      });
    });
  }

  // --- Permissions ---
  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.speech.request();
  }

  // --- Start Listening ---
  Future<void> _startListening() async {
    if (!_isListening) {
      await _speechToText.listen(
        localeId: _currentLocaleId ?? _localeNames.first.localeId,
        onResult: (result) {
          setState(() {
            _transcribedText = result.recognizedWords;
          });
        },
      );
      setState(() {
        _isListening = true;
      });
    } else {
      await _speechToText.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  // --- Copy Text ---
  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Texte copié dans le presse-papiers')),
    );
  }

  // --- Share Text ---
  Future<void> _shareText(String text) async {
    await Share.share(text);
  }

  // --- Speak ---
  Future<void> _speak() async {
    if (_textToSpeak.isNotEmpty) {
      await _flutterTts
          .setLanguage(_currentTtsLanguage ?? _voices.first['locale']);
      await _flutterTts.setVoice({
        'name': _currentVoiceId ?? _voices.first['name'],
        'locale': _currentTtsLanguage ?? _voices.first['locale']
      });
      await _flutterTts.speak(_textToSpeak);
    }
  }

  // --- Stop Speaking ---
  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AudioText Converter'),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.blueAccent,
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.mic), text: 'Audio vers Texte'),
            Tab(icon: Icon(Icons.text_fields), text: 'Texte vers Audio'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAudioToTextTab(),
          _buildTextToAudioTab(),
        ],
      ),
    );
  }

  Widget _buildAudioToTextTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey),
            ),
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Langue de transcription',
                border: InputBorder.none,
              ),
              value: _currentLocaleId,
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
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(150, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _speechToText.isAvailable ? _startListening : null,
            icon: Icon(_isListening ? Icons.stop : Icons.mic),
            label:
                Text(_isListening ? 'Arrêter l\'écoute' : 'Démarrer l\'écoute'),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey),
              ),
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Text(
                  _transcribedText.isEmpty
                      ? 'Le texte transcrit apparaîtra ici...'
                      : _transcribedText,
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        _transcribedText.isEmpty ? Colors.grey : Colors.black,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(100, 40),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _transcribedText.isNotEmpty
                      ? () => _copyText(_transcribedText)
                      : null,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copier'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(100, 40),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _transcribedText.isNotEmpty
                      ? () => _shareText(_transcribedText)
                      : null,
                  icon: const Icon(Icons.share),
                  label: const Text('Partager'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextToAudioTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey),
            ),
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Entrez le texte à convertir en audio',
                border: InputBorder.none,
              ),
              onChanged: (text) {
                setState(() {
                  _textToSpeak = text;
                });
              },
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey),
            ),
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Langue de la synthèse vocale',
                border: InputBorder.none,
              ),
              value: _currentTtsLanguage,
              items: _voices
                  .map<String>((voice) => voice['locale'].toString())
                  .toSet()
                  .map<DropdownMenuItem<String>>(
                      (locale) => DropdownMenuItem<String>(
                            value: locale,
                            child: Text(locale),
                          ))
                  .toList(),
              onChanged: (newValue) async {
                setState(() {
                  _currentTtsLanguage = newValue;
                });
                if (newValue != null) {
                  await _flutterTts.setLanguage(newValue);
                }
              },
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey),
            ),
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Voix',
                border: InputBorder.none,
              ),
              value: _currentVoiceId,
              items: _voices
                  .map<DropdownMenuItem<String>>((voice) =>
                      DropdownMenuItem<String>(
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
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(150, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _textToSpeak.isNotEmpty
                ? (_isSpeaking ? _stopSpeaking : _speak)
                : null,
            icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
            label:
                Text(_isSpeaking ? 'Arrêter la lecture' : 'Écouter le texte'),
          ),
        ],
      ),
    );
  }
}
