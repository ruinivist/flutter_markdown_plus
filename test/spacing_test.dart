// Checks spacing between Markdown blocks without fixing theme token values.
// Used by renderer regressions for lists, headings and stylesheet updates.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

// ---------- Layout helpers ----------

Future<void> _pumpMarkdown(WidgetTester tester, String data, MarkdownStyleSheet style, {double width = 300}) {
  return tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: MarkdownBody(data: data, styleSheet: style)),
  ))));
}

double _gap(WidgetTester tester, String before, String after) =>
    tester.getTopLeft(find.text(after)).dy - tester.getBottomLeft(find.text(before)).dy;

// ---------- Spacing behavior ----------

void main() {
  final MarkdownStyleSheet style =
      MarkdownStyleSheet(blockSpacing: 23, listItemSpacing: 7, headingSpacing: 11, headingBeforeSpacing: 31);

  testWidgets('headings have asymmetric gaps without edge gaps', (WidgetTester tester) async {
    await _pumpMarkdown(tester, 'Start\n\n# First\n## Second\n\nEnd\n\nFinal', style);
    expect(_gap(tester, 'Start', 'First'), 31);
    expect(_gap(tester, 'First', 'Second'), 31);
    expect(_gap(tester, 'Second', 'End'), 11);
    expect(_gap(tester, 'End', 'Final'), 23);
    expect(tester.getTopLeft(find.text('Start')).dy, tester.getTopLeft(find.byType(MarkdownBody)).dy);
    expect(tester.getBottomLeft(find.text('Final')).dy, tester.getBottomLeft(find.byType(MarkdownBody)).dy);
  });

  for (final String marker in <String>['-', '1.', '- [ ]']) {
    testWidgets('$marker list keeps wrapped text height independent of sibling gap', (WidgetTester tester) async {
      const String wrapped = 'A long item that must wrap into several lines inside the narrow card';
      await _pumpMarkdown(tester, '$marker $wrapped\n$marker Last', style, width: 200);
      final double height = tester.getSize(find.text(wrapped)).height;
      expect(_gap(tester, wrapped, 'Last'), 7);
      await _pumpMarkdown(tester, '$marker $wrapped\n$marker Last', style.copyWith(listItemSpacing: 19), width: 200);
      expect(tester.getSize(find.text(wrapped)).height, height);
      expect(_gap(tester, wrapped, 'Last'), 19);
    });
  }

  testWidgets('nested and loose lists keep paragraph and nested block gaps', (WidgetTester tester) async {
    await _pumpMarkdown(tester, '- Parent\n\n  Paragraph\n\n  - Nested one\n  - Nested two\n\n- Last', style);
    expect(_gap(tester, 'Parent', 'Paragraph'), 23);
    expect(_gap(tester, 'Paragraph', 'Nested one'), 23);
    expect(_gap(tester, 'Nested one', 'Nested two'), 7);
    expect(_gap(tester, 'Nested two', 'Last'), 7);
  });

  testWidgets('nested headings and styles propagate to both Markdown widgets', (WidgetTester tester) async {
    await _pumpMarkdown(
        tester, '- # List heading\n\n  List paragraph\n\n> ## Quote heading\n>\n> Quote paragraph', style);
    expect(_gap(tester, 'List heading', 'List paragraph'), 11);
    expect(_gap(tester, 'Quote heading', 'Quote paragraph'), 11);
    for (final double spacing in <double>[9, 17]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Markdown(
        data: 'Intro\n\n# Heading\n\nParagraph\n\n- First\n- Second',
        styleSheet: style.copyWith(headingSpacing: spacing, headingBeforeSpacing: spacing, listItemSpacing: spacing),
      ))));
      expect(_gap(tester, 'Intro', 'Heading'), spacing);
      expect(_gap(tester, 'Heading', 'Paragraph'), spacing);
      expect(_gap(tester, 'First', 'Second'), spacing);
    }
  });

  testWidgets('nested first headings stay flush while later headings get a gap', (WidgetTester tester) async {
    await _pumpMarkdown(tester, '- # First heading\n\n  Paragraph\n\n  ## Later heading', style);
    final Finder content = find.descendant(of: find.byType(Flexible), matching: find.byType(Column)).first;
    expect(tester.getTopLeft(find.text('First heading')).dy, tester.getTopLeft(content).dy);
    expect(_gap(tester, 'Paragraph', 'Later heading'), 31);
    await _pumpMarkdown(tester, '> # Quote heading\n>\n> Text\n>\n> ## Next heading', style);
    expect(_gap(tester, 'Text', 'Next heading'), 31);
  });

  testWidgets('unset builder spacing falls back to block spacing', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (BuildContext context) {
      final MarkdownBuilder builder = MarkdownBuilder(
        delegate: _TestDelegate(context),
        selectable: false,
        styleSheet: MarkdownStyleSheet(
          blockSpacing: 23,
          p: const TextStyle(fontSize: 14),
          pPadding: EdgeInsets.zero,
          h1: const TextStyle(fontSize: 20),
          h1Padding: EdgeInsets.zero,
          listBullet: const TextStyle(fontSize: 14),
          listIndent: 24,
          listBulletPadding: EdgeInsets.zero,
        ),
        imageDirectory: null,
        imageBuilder: null,
        checkboxBuilder: null,
        bulletBuilder: null,
        builders: <String, MarkdownElementBuilder>{},
        paddingBuilders: <String, MarkdownPaddingBuilder>{},
        listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.baseline,
      );
      return Column(
          children: builder.build(md.Document().parseLines(<String>[
        'Intro',
        '',
        '# Heading',
        '',
        'Paragraph',
        '',
        '- First',
        '- Second',
      ])));
    })));
    expect(_gap(tester, 'Intro', 'Heading'), 23);
    expect(_gap(tester, 'Heading', 'Paragraph'), 23);
    expect(_gap(tester, 'First', 'Second'), 23);
  });

  for (int level = 1; level <= 6; level += 1) {
    testWidgets('h$level has no leading or trailing gap', (WidgetTester tester) async {
      await _pumpMarkdown(tester, '${'#' * level} Heading', style);
      expect(tester.getSize(find.byType(MarkdownBody)).height, tester.getSize(find.text('Heading')).height);
      await _pumpMarkdown(tester, '${'#' * level} Heading\n\nParagraph', style);
      expect(tester.getTopLeft(find.text('Heading')).dy, tester.getTopLeft(find.byType(MarkdownBody)).dy);
      expect(_gap(tester, 'Heading', 'Paragraph'), 11);
    });
  }

  test('new fields survive copying, merging, equality and hashing', () {
    final MarkdownStyleSheet base =
        MarkdownStyleSheet.fromTheme(ThemeData(textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 14))));
    final MarkdownStyleSheet copy = base.copyWith(listItemSpacing: 7, headingSpacing: 11, headingBeforeSpacing: 31);
    final MarkdownStyleSheet merged =
        base.merge(MarkdownStyleSheet(listItemSpacing: 7, headingSpacing: 11, headingBeforeSpacing: 31));
    expect(copy, merged);
    expect(copy.hashCode, merged.hashCode);
    expect(copy.copyWith(listItemSpacing: 19), isNot(copy));
    expect(copy.copyWith(headingSpacing: 19), isNot(copy));
    expect(copy.copyWith(headingBeforeSpacing: 19), isNot(copy));
    expect(copy.copyWith(), copy);
    expect(MarkdownStyleSheet().listItemSpacing, isNull);
    expect(MarkdownStyleSheet().headingSpacing, isNull);
    expect(MarkdownStyleSheet().headingBeforeSpacing, isNull);
  });
}

// ---------- Builder delegate ----------

class _TestDelegate implements MarkdownBuilderDelegate {
  _TestDelegate(this.context);

  @override
  final BuildContext context;

  @override
  GestureRecognizer createLink(String text, String? href, String title) => TapGestureRecognizer();

  @override
  TextSpan formatText(MarkdownStyleSheet styleSheet, String code, {String? language}) =>
      TextSpan(text: code, style: styleSheet.code);
}
