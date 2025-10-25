import 'package:flutter/material.dart';

class CallPanelWidget extends StatefulWidget {
  final String callerName;
  final String callerNumber;

  const CallPanelWidget({
    super.key,
    required this.callerName,
    required this.callerNumber,
  });

  @override
  State<CallPanelWidget> createState() => _CallPanelWidgetState();
}

class _CallPanelWidgetState extends State<CallPanelWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
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
                child: const Icon(Icons.person_outline_rounded, color: Colors.white70, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.callerName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      widget.callerNumber,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Yeni Eklenen Animasyonlu İkon
          ScaleTransition(
            scale: _animation,
            child: Icon(
              Icons.ring_volume, // Dikkat çekici ama cevaplama anlamı taşımayan ikon
              color: Colors.cyanAccent.withOpacity(0.8),
              size: 40,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
