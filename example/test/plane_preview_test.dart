// Checks the live editing and temporary controls in the Plane preview.
// Run against the example app when changing its comparison UI.

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_markdown_example/plane_preview.dart';

// ---------- Preview interactions ----------

void main() {
  testWidgets('editing, theme, width and reset retain renderer defaults',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PlanePreview());
    await tester.pumpAndSettle();
    final Finder bodies = find.byType(MarkdownBody);
    final double defaultSpacing =
        tester.widget<MarkdownBody>(bodies.first).styleSheet!.blockSpacing!;

    await tester.enterText(find.byType(TextField), '# Edited\n\nLive text');
    await tester.pump();
    expect(tester.widget<MarkdownBody>(bodies.first).data,
        '# Edited\n\nLive text');

    tester.widget<Slider>(find.byType(Slider).first).onChanged!(19);
    await tester.pump();
    expect(
        tester.widget<MarkdownBody>(bodies.first).styleSheet!.blockSpacing, 19);
    await tester.tap(find.text('Reset spacing'));
    await tester.pump();
    expect(tester.widget<MarkdownBody>(bodies.first).styleSheet!.blockSpacing,
        defaultSpacing);

    await tester.tap(find.text('Dark theme'));
    await tester.pumpAndSettle();
    final BuildContext context = tester.element(bodies.first);
    expect(Theme.of(context).brightness, Brightness.dark);
    await tester.tap(find.text('Narrow cards'));
    await tester.pumpAndSettle();
    expect(tester.getSize(bodies.first).width, 320 - 48 - 2);
    expect(tester.takeException(), isNull);
  });
}
