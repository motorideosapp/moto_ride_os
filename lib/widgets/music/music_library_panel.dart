
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

// Müzik dosyası hakkında temel bilgileri tutan basit bir model.
class MusicFile {
  final String path;
  final String title;

  MusicFile({required this.path, required this.title});
}

// Cihazdaki müzik kütüphanesini gösteren ve yöneten panel.
class MusicLibraryPanel extends StatefulWidget {
  const MusicLibraryPanel({super.key});

  @override
  State<MusicLibraryPanel> createState() => _MusicLibraryPanelState();
}

class _MusicLibraryPanelState extends State<MusicLibraryPanel> {
  late Future<List<MusicFile>> _musicFilesFuture;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingPath;

  @override
  void initState() {
    super.initState();
    _musicFilesFuture = _findMusicFiles();
  }

  // GÜNCELLENDİ: Depolama alanını daha güvenli ve akıllıca tarayacak fonksiyon.
  Future<List<MusicFile>> _findMusicFiles() async {
    List<MusicFile> foundFiles = [];
    // Harici depolama yollarını al (Dahili hafıza + SD Kart vb.)
    List<Directory>? storageDirs = await getExternalStorageDirectories();

    if (storageDirs == null || storageDirs.isEmpty) {
      // Eğer depolama alanı bulunamazsa boş liste döndür.
      return [];
    }

    // Genellikle taranması gereken standart klasörler
    const List<String> commonMusicFolders = ['Music', 'Download', 'Audiobooks'];

    for (var storageDir in storageDirs) {
      // Ana depolama dizinini bul (genellikle .../Android/data'dan önceki kısım)
      final Directory root = Directory(storageDir.path.split('Android')[0]);

      // Standart müzik klasörlerini tara
      for (var folderName in commonMusicFolders) {
        final Directory musicDir = Directory('${root.path}$folderName');
        if (await musicDir.exists()) {
          // Klasördeki tüm dosyaları ve alt klasörleri tara
          await for (var entity in musicDir.list(recursive: true, followLinks: false)) {
            if (entity is File && _isAudioFile(entity.path)) {
              foundFiles.add(MusicFile(
                path: entity.path,
                title: entity.path.split('/').last.replaceAll(RegExp(r'\.[^.]*$'), ''),
              ));
            }
          }
        }
      }
    }
    return foundFiles;
  }

  // Dosya uzantısına göre ses dosyası olup olmadığını kontrol eden yardımcı fonksiyon
  bool _isAudioFile(String path) {
    return path.endsWith('.mp3') || path.endsWith('.m4a') || path.endsWith('.aac') || path.endsWith('.wav') || path.endsWith('.flac');
  }

  // Seçilen bir şarkıyı çalmak veya durdurmak için.
  Future<void> _playPause(String path) async {
    if (_currentlyPlayingPath == path && _audioPlayer.state == PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(path));
      _currentlyPlayingPath = path;
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() {});
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<MusicFile>>(
              future: _musicFilesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text('Müzikler aranıyor...', style: TextStyle(color: Colors.white70)),
                    ],
                  ));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Müzikler aranırken bir hata oluştu: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                if (snapshot.data == null || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Cihazınızda müzik dosyası bulunamadı.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                final musicFiles = snapshot.data!;
                return ListView.builder(
                  itemCount: musicFiles.length,
                  itemBuilder: (context, index) {
                    final file = musicFiles[index];
                    final bool isPlaying = _currentlyPlayingPath == file.path && _audioPlayer.state == PlayerState.playing;

                    return ListTile(
                      leading: Icon(
                        isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                        color: isPlaying ? Colors.cyanAccent : Colors.white70,
                        size: 32,
                      ),
                      title: Text(
                        file.title,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _playPause(file.path),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
