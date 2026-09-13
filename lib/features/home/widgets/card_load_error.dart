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
///
/// Two layouts, one widget, so both screens say the same thing the same
/// way. The dashboard's cards are full-width rows, so the default is a
/// 60px row. The today report's cards are cells in a three-column grid --
/// too narrow for a row with two lines of text beside an icon -- so
/// `compact` lays the same parts out the way that grid's cards do: icon
/// line, title, one line, the bar -- with the status line shortened to what
/// fits a cell, and the refresh icon carrying "tap to retry". The tap is the
/// same: the whole card.
class CardLoadError extends StatelessWidget {
  static const String message = "Couldn't load. Tap to retry.";
  static const String compactMessage = "Couldn't load";

  final String title;
  final IconData icon;
  final Color color;
  final Future<void> Function() onRetry;
  final bool compact;

  const CardLoadError({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onRetry,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Theme-aware, not fixed greys: the app follows the system theme, and
    // an error row nobody can read in dark mode is not an error state.
    final onSurface = Theme.of(context).colorScheme.onSurface;
    if (compact) return _cell(context, onSurface);
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
                        color: onSurface,
                      ),
                    ),
                    Text(
                      message,
                      style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.refresh, color: onSurface.withOpacity(0.6), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// The grid-cell layout: the today report's card shape (icon row, title,
  /// one line, a bar) with the error in the places the numbers would be.
  Widget _cell(BuildContext context, Color onSurface) {
    return InkWell(
      onTap: onRetry,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color.withOpacity(0.6), size: 24),
                Icon(Icons.refresh, color: onSurface.withOpacity(0.6), size: 16),
              ],
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            Text(
              compactMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: onSurface.withOpacity(0.7)),
            ),
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
