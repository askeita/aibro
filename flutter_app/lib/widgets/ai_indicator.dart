import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';


/// Animated pill shown when the AI assistant is "thinking".
class AIIndicator extends StatelessWidget {
  const AIIndicator({super.key});

  /// Builds the glowing indicator row.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .fadeIn(duration: 500.ms)
              .fadeOut(duration: 500.ms),
          const SizedBox(width: 12),
          const Text(
            'AI is thinking...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
