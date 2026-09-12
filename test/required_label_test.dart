import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_onboarding/features/onboarding/widgets/required_label.dart';

/// The required marker must stay on the same line as the last word.
///
/// Regression: the separator was an ordinary space, which is a line-break
/// opportunity, so when the label fit but the marker did not, Flutter wrapped
/// the asterisk onto a line by itself. With a non-breaking separator the last
/// word and the marker move together instead.
void main() {
  testWidgets('the asterisk stays on the last word\'s line', (tester) async {
    const label = 'Current fitness level';
    const style = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

    // Box the widget so every word fits but the marker does not. Probed: with
    // an ordinary separator the asterisk strands alone at every width from
    // +6 to +34 past the label; +10 sits well inside that band.
    final painter = TextPainter(
      text: const TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: painter.width + 10,
            child: const RequiredLabel(label),
          ),
        ),
      ),
    ));

    final paragraph =
        tester.renderObject<RenderParagraph>(find.byType(RichText));

    // Rendered text is "Current fitness level<sep>*". Compare the line the
    // last word sits on with the line the asterisk sits on.
    final lastWordStart = label.lastIndexOf(' ') + 1;
    final lastWord = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: lastWordStart, extentOffset: label.length),
    );
    final marker = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: label.length + 1, extentOffset: label.length + 2),
    );

    expect(lastWord, isNotEmpty);
    expect(marker, isNotEmpty);
    // With a breakable separator: "Current fitness level" / "*" — different
    // lines. With the non-breaking one: "Current fitness" / "level *".
    expect(marker.first.top, closeTo(lastWord.first.top, 0.5),
        reason: 'asterisk wrapped away from its word');
  });
}
