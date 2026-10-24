// Checks built-in math parsing, rendering, and style inheritance.
// Exercises the public Markdown widgets without the separate LaTeX extension.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus/src/latex_syntax.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

import 'utils.dart';

// ---------- Parsing and rendering ----------

void main() => defineTests();

void defineTests() {
  group('LaTeX', () {
    test('unfinished inline math avoids repeated suffix matching', () {
      for (final String marker in <String>[r'\(', r'\[']) {
        for (final int length in <int>[512, 1024]) {
          final _CountingInlineSyntax syntax = _CountingInlineSyntax();
          final md.Document document = md.Document(inlineSyntaxes: <md.InlineSyntax>[syntax]);
          final String source = List<String>.filled(length, marker).join(' ');
          final List<md.Node> nodes = document.parseInline(source);
          expect(nodes.whereType<md.Element>().where((md.Element element) => element.tag == 'latex'), isEmpty);
          expect(syntax.regexLookups, lessThanOrEqualTo(4));
        }
      }
    });

    test('inline closer lookups respect escapes, line boundaries, and separate parsers', () {
      final md.Document document = md.Document(inlineSyntaxes: <md.InlineSyntax>[LatexInlineSyntax()]);
      <String, List<String>>{
        r'\(a\)': <String>['a'],
        r'\[b\]': <String>['b'],
        r'\\(literal\\)': <String>[],
        r'\(a\\)': <String>[],
        r'\(a\\\)': <String>[r'a\\'],
        r'\(a\\) b\)': <String>[r'a\\) b'],
        '\\(unfinished\n\\[valid\\]': <String>['valid'],
        '\\[unfinished\n\\(valid\\)': <String>['valid'],
      }.forEach((String source, List<String> expected) {
        final Iterable<md.Element> equations =
            document.parseInline(source).whereType<md.Element>().where((md.Element element) => element.tag == 'latex');
        expect(equations.map((md.Element element) => element.textContent), expected, reason: source);
      });
    });

    test('unfinished display fences require linear lookahead', () {
      final List<int> reads = <int>[];
      for (final int length in <int>[512, 1024]) {
        final _CountingLines lines = _CountingLines(List<md.Line>.generate(length, (_) => md.Line(r'\[')));
        final md.BlockParser parser = md.BlockParser(lines, md.Document());
        const LatexBlockSyntax syntax = LatexBlockSyntax();
        while (!parser.isDone) {
          expect(syntax.canParse(parser), isFalse);
          parser.advance();
        }
        reads.add(lines.reads);
      }
      expect(reads[1], lessThan(reads[0] * 3));
    });

    test('display fence lookups stay scoped to the parser and survive retreat', () {
      const LatexBlockSyntax syntax = LatexBlockSyntax();
      final md.Document document = md.Document(blockSyntaxes: <md.BlockSyntax>[syntax]);
      final md.BlockParser parser = md.BlockParser(
        <md.Line>[md.Line(r'\['), md.Line('x'), md.Line(r'\]'), md.Line(r'\[')],
        document,
      );
      expect(syntax.canParse(parser), isTrue);
      parser.advance();
      parser.advance();
      parser.advance();
      expect(syntax.canParse(parser), isFalse);
      expect(syntax.canParse(md.BlockParser(<md.Line>[md.Line(r'\[')], document)), isFalse);
      parser.retreatBy(3);
      expect(syntax.canParse(parser), isTrue);
      expect(syntax.parse(parser).textContent, 'x');
      expect(syntax.canParse(parser), isFalse);

      expect(md.renderToHtml(document.parse('> \$\$\n> y\n> \$\$')), contains('<latex MathStyle="display">y</latex>'));
      final md.Document nextDocument = md.Document(blockSyntaxes: <md.BlockSyntax>[syntax]);
      expect(md.renderToHtml(nextDocument.parse('\\[\nz\n\\]')), contains('<latex MathStyle="display">z</latex>'));
    });

    for (final bool scrollable in <bool>[false, true]) {
      testWidgets('renders standard delimiters in ${scrollable ? 'Markdown' : 'MarkdownBody'}',
          (WidgetTester tester) async {
        const String source = r'Inline $x^2$, \(y_1\)! Display $$a+b$$; \[c+d\].'
            '\n\n\$\$\nx+y\n\$\$\n\n\\[\na-b\n\\]';
        await tester.pumpWidget(boilerplate(
          scrollable ? const Markdown(data: source) : const MarkdownBody(data: source),
        ));
        final List<Math> equations = tester.widgetList<Math>(find.byType(Math)).toList();
        expect(equations.map((Math equation) => equation.mathStyle), <MathStyle>[
          MathStyle.text,
          MathStyle.text,
          MathStyle.display,
          MathStyle.display,
          MathStyle.display,
          MathStyle.display,
        ]);
        expect(equations.every((Math equation) => equation.parseError == null), isTrue);
        expect(tester.takeException(), isNull);
      });
    }

    for (final String source in <String>[
      r'$300 $400',
      r'300$ 400$',
      r'$ spaced $',
      r'$x$5',
      r'$$$x$$$',
      r'$$x$',
      r'$x$$',
      r'\$x\$',
      r'\\(x\\)',
      r'\(x\]',
      r'[ x ] and ( y )',
      r'\ce{H2O} and \pu{1 m}',
      '`\$x\$`',
      '```tex\n\$\$\nx+y\n\$\$\n```',
      '    \$\$\n    x+y\n    \$\$',
      '\$\nx+y\n\$',
      '\$\$\nx+y\n\\]\n\nafter',
      '\\[\nx+y\n\$\$\n\nafter',
    ]) {
      testWidgets('keeps literal content: $source', (WidgetTester tester) async {
        await tester.pumpWidget(boilerplate(MarkdownBody(data: source)));
        expect(find.byType(Math), findsNothing);
        if (source.endsWith('after')) {
          expect(find.textContaining('after', findRichText: true), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('preserves TeX contents and supports overriding its builder', (WidgetTester tester) async {
      final _RecordingBuilder builder = _RecordingBuilder();
      await tester.pumpWidget(boilerplate(MarkdownBody(
        data: r'$\alpha_1 + \$2$ and \(\text{a * b}\)' '\n\n\$\$\na_1\n+b_2\n\$\$',
        builders: <String, MarkdownElementBuilder>{'latex': builder},
        extensionSet: md.ExtensionSet.none,
      )));
      expect(builder.sources, <String>[r'\alpha_1 + \$2', r'\text{a * b}', 'a_1\n+b_2']);
      expect(find.byType(Math), findsNothing);
      expect(find.text(r'\alpha_1 + \$2'), findsOneWidget);
    });

    for (final bool customBuilder in <bool>[false, true]) {
      testWidgets('math links call onTapLink once with ${customBuilder ? 'a custom' : 'the built-in'} builder',
          (WidgetTester tester) async {
        final List<MarkdownLink> taps = <MarkdownLink>[];
        await tester.pumpWidget(boilerplate(MarkdownBody(
          data: r'[$x$](https://example.com "equation")',
          builders: customBuilder ? <String, MarkdownElementBuilder>{'latex': _RecordingBuilder()} : const {},
          onTapLink: (String text, String? href, String title) => taps.add(MarkdownLink(text, href, title)),
        )));

        await tester.tap(customBuilder ? find.text('x') : find.byType(Math));
        expect(taps, hasLength(1));
        expectLinkTap(taps.single, const MarkdownLink('x', 'https://example.com', 'equation'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('dragging a wide linked equation scrolls without opening its link', (WidgetTester tester) async {
      final String equation = List<String>.filled(80, 'x').join('+');
      final List<MarkdownLink> taps = <MarkdownLink>[];
      await tester.pumpWidget(boilerplate(Center(
        child: SizedBox(
          width: 120,
          child: MarkdownBody(
            data: '[\$\$$equation\$\$](https://example.com)',
            onTapLink: (String text, String? href, String title) => taps.add(MarkdownLink(text, href, title)),
          ),
        ),
      )));

      final ScrollableState scroll = tester.state(find.byType(Scrollable));
      await tester.drag(find.byType(SingleChildScrollView), const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(0));
      expect(taps, isEmpty);
      expect(tester.takeException(), isNull);
    });

    for (final bool explicit in <bool>[false, true]) {
      testWidgets('honors ${explicit ? 'explicit' : 'extension-set'} custom syntax before built-in math',
          (WidgetTester tester) async {
        await tester.pumpWidget(boilerplate(MarkdownBody(
          data: '\$x\$\n\n\$\$\nx\n\$\$',
          inlineSyntaxes: explicit ? <md.InlineSyntax>[md.TextSyntax(r'\$x\$', sub: 'explicit inline')] : null,
          blockSyntaxes: explicit ? <md.BlockSyntax>[_LiteralBlockSyntax('explicit block')] : null,
          extensionSet: md.ExtensionSet(
            <md.BlockSyntax>[_LiteralBlockSyntax('extension block')],
            <md.InlineSyntax>[md.TextSyntax(r'\$x\$', sub: 'extension inline')],
          ),
        )));
        expect(find.byType(Math), findsNothing);
        expect(find.text('${explicit ? 'explicit' : 'extension'} inline', findRichText: true), findsOneWidget);
        expect(find.text('${explicit ? 'explicit' : 'extension'} block', findRichText: true), findsOneWidget);
      });
    }

    testWidgets('inherits surrounding styles and applies the LaTeX override', (WidgetTester tester) async {
      const TextStyle paragraph = TextStyle(fontSize: 18, color: Colors.blue);
      const TextStyle heading = TextStyle(fontSize: 28, color: Colors.green);
      final MarkdownStyleSheet base = MarkdownStyleSheet(p: paragraph, h1: heading);
      for (final Color? override in <Color?>[null, Colors.red]) {
        final MarkdownStyleSheet style = base.copyWith(latex: TextStyle(color: override));
        await tester.pumpWidget(boilerplate(MarkdownBody(
          data: '# \$x\$\n\n\$x\$',
          styleSheet: style,
        )));
        final List<Math> equations = tester.widgetList<Math>(find.byType(Math)).toList();
        expect(equations[0].textStyle!.color, override ?? heading.color);
        expect(equations[0].textStyle!.fontSize, heading.fontSize);
        expect(equations[1].textStyle!.color, override ?? paragraph.color);
        expect(equations[1].textStyle!.fontSize, paragraph.fontSize);
      }
    });

    testWidgets('uses the sheet scaler or inherited scaler exactly once', (WidgetTester tester) async {
      for (final TextScaler? override in <TextScaler?>[null, const TextScaler.linear(3)]) {
        await tester.pumpWidget(boilerplate(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MarkdownBody(
            data: r'$x$',
            styleSheet: MarkdownStyleSheet(p: const TextStyle(fontSize: 18), textScaler: override),
          ),
        )));
        final Math equation = tester.widget(find.byType(Math));
        expect(equation.textStyle!.fontSize, (override ?? const TextScaler.linear(2)).scale(18));
        expect(equation.textScaleFactor, 1);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('resolves partial non-inheriting LaTeX styles without inheriting surrounding fields',
        (WidgetTester tester) async {
      const TextStyle defaults = TextStyle(fontSize: 19, color: Colors.purple, fontWeight: FontWeight.bold);
      for (final TextStyle override in <TextStyle>[
        const TextStyle(inherit: false, color: Colors.red),
        const TextStyle(inherit: false, fontSize: 20),
      ]) {
        await tester.pumpWidget(boilerplate(DefaultTextStyle(
          style: defaults,
          child: MarkdownBody(
            data: r'# $x$',
            styleSheet: MarkdownStyleSheet(
              h1: const TextStyle(fontSize: 28, color: Colors.green, fontStyle: FontStyle.italic),
              latex: override,
              textScaler: const TextScaler.linear(2),
            ),
          ),
        )));
        final TextStyle style = tester.widget<Math>(find.byType(Math)).textStyle!;
        expect(style.fontSize, (override.fontSize ?? kDefaultFontSize) * 2);
        expect(style.color, override.color ?? Colors.white);
        expect(style.inherit, isFalse);
        expect(style.fontWeight, isNull);
        expect(style.fontStyle, isNull);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('resolves partial non-inheriting styles without an ambient text style', (WidgetTester tester) async {
      for (final TextStyle override in <TextStyle>[
        const TextStyle(inherit: false, color: Colors.red),
        const TextStyle(inherit: false, fontSize: 20),
      ]) {
        await tester.pumpWidget(boilerplate(MarkdownBody(
          data: r'$x$',
          styleSheet: MarkdownStyleSheet(latex: override),
        )));
        final TextStyle style = tester.widget<Math>(find.byType(Math)).textStyle!;
        expect(style.fontSize, isNotNull);
        expect(style.color, isNotNull);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('foreground paints render from body and LaTeX styles with scaling and accessible bold text',
        (WidgetTester tester) async {
      final Paint foreground = Paint()..color = Colors.red;
      final TextStyle style = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, foreground: foreground);
      for (final bool parent in <bool>[false, true]) {
        for (final bool bold in <bool>[false, true]) {
          await tester.pumpWidget(boilerplate(MediaQuery(
            data: MediaQueryData(boldText: bold, textScaler: const TextScaler.linear(2)),
            child: MarkdownBody(
              data: r'$x$',
              styleSheet: MarkdownStyleSheet(
                p: parent ? style : null,
                latex: parent ? null : style,
              ),
            ),
          )));
          final MathOptions options = tester.widget<Math>(find.byType(Math)).options!;
          expect(options.color, foreground.color);
          expect(options.fontSize, 40);
          expect(options.mathFontOptions!.fontWeight, bold ? FontWeight.bold : FontWeight.w600);
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('wide equations scroll horizontally inside narrow content', (WidgetTester tester) async {
      final String source = '\$\$${List<String>.filled(80, 'x').join('+')}\$\$';
      await tester.pumpWidget(boilerplate(Center(
        child: SizedBox(width: 120, child: MarkdownBody(data: source)),
      )));
      final ScrollableState scroll = tester.state(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      await tester.drag(find.byType(SingleChildScrollView), const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('invalid TeX uses the math renderer error fallback', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: MarkdownBody(data: r'$\unknowncommand{x}$'))));
      expect(tester.widget<Math>(find.byType(Math)).parseError, isNotNull);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('LaTeX style participates in copying, merging, and equality', () {
      final MarkdownStyleSheet base = MarkdownStyleSheet.fromTheme(ThemeData.light().copyWith(textTheme: textTheme));
      final MarkdownStyleSheet colored = base.copyWith(latex: const TextStyle(color: Colors.red));
      final MarkdownStyleSheet merged = colored.merge(MarkdownStyleSheet(latex: const TextStyle(fontSize: 24)));
      expect(colored, isNot(base));
      expect(colored, base.merge(MarkdownStyleSheet(latex: const TextStyle(color: Colors.red))));
      expect(colored.hashCode, base.copyWith(latex: const TextStyle(color: Colors.red)).hashCode);
      expect(merged.latex!.color, Colors.red);
      expect(merged.latex!.fontSize, 24);
      expect(merged.styles['latex'], merged.latex);
    });
  });
}

// ---------- Custom rendering and syntax ----------

class _CountingInlineSyntax extends LatexInlineSyntax {
  int regexLookups = 0;

  @override
  RegExp get pattern {
    regexLookups++;
    return super.pattern;
  }
}

class _CountingLines extends ListBase<md.Line> {
  _CountingLines(this._lines);

  final List<md.Line> _lines;
  int reads = 0;

  @override
  int get length => _lines.length;

  @override
  set length(int value) => _lines.length = value;

  @override
  md.Line operator [](int index) {
    reads++;
    return _lines[index];
  }

  @override
  void operator []=(int index, md.Line value) => _lines[index] = value;
}

class _RecordingBuilder extends MarkdownElementBuilder {
  final List<String> sources = <String>[];

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    sources.add(element.textContent);
    return Text(element.textContent);
  }
}

class _LiteralBlockSyntax extends md.BlockSyntax {
  _LiteralBlockSyntax(this.text);

  final String text;

  @override
  RegExp get pattern => RegExp(r'^\$\$$');

  @override
  md.Node parse(md.BlockParser parser) {
    parser.advance();
    parser.advance();
    parser.advance();
    return md.Element.text('p', text);
  }
}
