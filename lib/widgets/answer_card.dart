import 'package:flutter/material.dart';

/// AnswerCard — displays a query result with a subtle card style.
/// Shows a loading indicator while waiting, an error icon on empty results,
/// and the natural-language answer when ready.
class AnswerCard extends StatelessWidget {
  final String? answer;           // null = not yet queried
  final bool isLoading;

  const AnswerCard({super.key, this.answer, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content;

    if (isLoading) {
      // Show a spinner while the query runs
      content = const Center(child: CircularProgressIndicator());
    } else if (answer == null) {
      // Prompt the user to ask something
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 48, color: theme.colorScheme.primary.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(
            'Ask something like:\n"What apps did I use today?"',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ],
      );
    } else {
      // Show the answer
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              answer!,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ),
        ],
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: content,
    );
  }
}
