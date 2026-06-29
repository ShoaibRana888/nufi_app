// lib/features/chat/widgets/chat_input.dart
import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;
  final bool enabled;
  
  const ChatInput({
    Key? key,
    required this.controller,
    required this.onSubmitted,
    this.enabled = true,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 5,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.mic),
              onPressed: enabled ? () {
                // TODO: Implement voice input
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Voice input coming soon!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } : null,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                decoration: InputDecoration(
                  hintText: enabled 
                      ? 'Ask your AI health coach...'
                      : 'AI is typing...',
                  hintStyle: TextStyle(
                    color: enabled ? Colors.grey[400] : Colors.grey[300],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: enabled ? Colors.grey[100] : Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: enabled ? onSubmitted : null,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              color: enabled ? Colors.purple : Colors.grey,
              onPressed: enabled && controller.text.trim().isNotEmpty
                  ? () => onSubmitted(controller.text)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}