import 'package:flutter/material.dart';

class FeatureLine extends StatelessWidget {
  const FeatureLine({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class MessageCard extends StatelessWidget {
  const MessageCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(title),
          subtitle: Text(body),
        ),
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 44),
        child: Center(child: Text(text)),
      ),
    );
  }
}

class TextInputDialog extends StatefulWidget {
  const TextInputDialog({
    super.key,
    required this.title,
    required this.label,
    this.hint,
    this.initialValue,
    this.multiline = false,
  });

  final String title;
  final String label;
  final String? hint;
  final String? initialValue;
  final bool multiline;

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: controller,
          autofocus: true,
          minLines: widget.multiline ? 6 : 1,
          maxLines: widget.multiline ? 10 : 1,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
