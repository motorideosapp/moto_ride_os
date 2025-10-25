import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  List<dynamic> _voices = [];
  String? _selectedVoiceName;

  @override
  void initState() {
    super.initState();
    _getVoices();
    _loadSelectedVoice();
  }

  Future<void> _getVoices() async {
    var voices = await _flutterTts.getVoices;
    if (!mounted) return;
    var turkishVoices = voices.where((voice) => voice['locale'].toString().startsWith('tr-TR')).toList();
    setState(() {
      _voices = turkishVoices.isNotEmpty ? turkishVoices : voices;
    });
  }

  Future<void> _loadSelectedVoice() async {
    final prefs = await SharedPreferences.getInstance();
    final voiceJson = prefs.getString('selected_voice');
    if (voiceJson != null && mounted) {
      setState(() {
        try {
          final voiceData = json.decode(voiceJson);
          _selectedVoiceName = voiceData['name'];
        } catch (e) {
          print("Error loading selected voice: $e");
        }
      });
    }
  }

  Future<void> _setSelectedVoice(String voiceName) async {
    final voiceData = _voices.firstWhere((v) => v['name'] == voiceName);
    final voiceJson = json.encode(voiceData);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_voice', voiceJson);

    if (mounted) {
      setState(() {
        _selectedVoiceName = voiceName;
      });
    }

    await _flutterTts.setVoice({"name": voiceData['name'], "locale": voiceData['locale']});
    _flutterTts.speak('Bu ses ile yönlendirileceksiniz.');
  }

  void _speak(String text, String voiceName, String locale) async {
    await _flutterTts.setVoice({"name": voiceName, "locale": locale});
    await _flutterTts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ses Ayarları'),
      ),
      body: _voices.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _voices.length,
        itemBuilder: (context, index) {
          final voice = _voices[index];
          final voiceName = voice['name'];
          final voiceLocale = voice['locale'];

          return RadioListTile<String>(
            title: Text(voiceName),
            subtitle: Text(voiceLocale),
            value: voiceName,
            groupValue: _selectedVoiceName,
            onChanged: (String? value) {
              if (value != null) {
                _setSelectedVoice(value);
              }
            },
            secondary: IconButton(
              icon: const Icon(Icons.play_circle_fill),
              onPressed: () => _speak('Bu bir test sesidir', voiceName, voiceLocale),
            ),
          );
        },
      ),
    );
  }
}
