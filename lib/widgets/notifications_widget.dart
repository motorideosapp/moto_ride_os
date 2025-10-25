import 'package:flutter/material.dart';

class NotificationsWidget extends StatelessWidget {
  final VoidCallback onPhoneTap;
  final VoidCallback onMessageTap;
  final VoidCallback onDialpadTap;

  const NotificationsWidget({
    super.key,
    required this.onPhoneTap,
    required this.onMessageTap,
    required this.onDialpadTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionIcon(
            icon: Icons.access_time_filled_rounded,
            onPressed: onPhoneTap,
          ),
          _buildActionIcon(
            icon: Icons.chat_bubble_rounded,
            onPressed: onMessageTap,
          ),
          _buildActionIcon(
            icon: Icons.dialpad_rounded,
            onPressed: onDialpadTap,
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon(
      {required IconData icon, required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 32),
      onPressed: onPressed,
      splashRadius: 30.0,
      highlightColor: Colors.cyan.withOpacity(0.2),
    );
  }
}