// lib/features/home/widgets/card_load_error.dart
import 'package:flutter/material.dart';

/// What a dashboard card shows when its section of the day could not be
/// read.
///
/// Until this existed, a failed read rendered as the card's empty state --
/// "0 / 8 glasses", "0 consumed" -- which is a lie about the user's data,
/// and the lie the today report stopped telling at the model level in
/// ADR-0006 without ever showing it. The `Section` states have carried
/// `error` since then; this is the first place it is drawn.
///
/// Deliberately plain: the tracker's icon and colour so the row is still
/// recognisable in the column, one line of text, and the whole row is the
/// retry -- it asks the dashboard to read the day again, so a retry on one
/// card refreshes every card.
class CardLoadError extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Future<void> Function() onRetry;

  const CardLoadError({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).cardColor,
          ),
          child: Row(
            children: [
              Icon(icon, color: color.withOpacity(0.6), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      "Couldn't load. Tap to retry.",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.refresh, color: Colors.grey[500], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
