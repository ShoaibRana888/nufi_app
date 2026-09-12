import 'package:flutter/material.dart';

/// A section label followed by the red required-field asterisk.
///
/// The onboarding pages used to build this as a Row of two Texts. A Row gives
/// its children unbounded width, so a label that did not fit the screen could
/// not wrap and overflowed instead — visibly, on the two longest labels at
/// iPhone width, and latently on every other one at any narrower width. One
/// rich text wraps like a paragraph and keeps the asterisk glued to the last
/// word: the separator is a non-breaking space, since an ordinary space is a
/// line-break opportunity and would let the asterisk wrap onto a line alone.
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
            text: '\u00A0*',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
