import 'package:flutter/material.dart';

class MusicPlayerWidget extends StatefulWidget {
  const MusicPlayerWidget({super.key});

  @override
  State<MusicPlayerWidget> createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget> {
  bool _isPlaying = true;
  String _songTitle = 'Get Lucky';
  String _artistName = 'Daft Punk ft. Pharrell Williams';

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _nextSong() {
    // Sonraki şarkı mantığı buraya eklenecek
  }

  void _previousSong() {
    // Önceki şarkı mantığı buraya eklenecek
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border:
        Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.1),
            blurRadius: 10.0,
            spreadRadius: 2.0,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.music_note_rounded,
                    color: Colors.white70, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _songTitle,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      _artistName,
                      style:
                      const TextStyle(color: Colors.white70, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: LinearProgressIndicator(
              value: 0.7,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 2.0,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildControlButton(Icons.skip_previous_rounded, _previousSong),
              _buildControlButton(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                _togglePlayPause,
                size: 44.0,
                color: Colors.cyanAccent,
              ),
              _buildControlButton(Icons.skip_next_rounded, _nextSong),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed,
      {double size = 30.0, Color color = Colors.white}) {
    return IconButton(
      iconSize: size,
      icon: Icon(icon, color: color),
      onPressed: onPressed,
      splashRadius: 24.0,
      highlightColor: Colors.cyan.withOpacity(0.2),
    );
  }
}
