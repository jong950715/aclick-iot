import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConsoleView extends StatelessWidget{
  final List<String> messages;
  const ConsoleView({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Colors.blue.shade100,
              padding: const EdgeInsets.symmetric(
                  vertical: 8.0, horizontal: 16.0),
              child: const Row(
                children: [
                  Icon(Icons.terminal, size: 20),
                  SizedBox(width: 8),
                  Text('로그 콘솔',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(messages[index],
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
