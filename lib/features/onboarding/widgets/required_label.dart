import 'package:flutter/material.dart';

/// A section label followed by the red required-field asterisk.
///
/// The onboarding pages used to build this as a Row of two Texts. A Row gives
/// its children unbounded width, so a label that did not fit the screen could
/// not wrap and overflowed instead — visibly, on the two longest labels at
/// iPhone width, and latently on every other one at any narrower width. One
/// rich text wraps like a paragraph and keeps the asterisk glued to the last
/// word.
class RequiredLabel extends StatelessWidget {
  final String text;
  final double fontSize;

  const RequiredLabel(this.text, {super.key, this.fontSize = 18});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
