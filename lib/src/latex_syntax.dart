// Parses inline and block math without interpreting the TeX contents as Markdown.
// Used by the built-in LaTeX support in Markdown and MarkdownBody.

import 'package:markdown/markdown.dart' as md;

// ---------- Inline math ----------

/// Recognizes the four standard math delimiters inside a paragraph.
/// Registered internally alongside the widget's custom inline syntaxes.
class LatexInlineSyntax extends md.InlineSyntax {
  /// Creates the built-in inline math syntax.
  LatexInlineSyntax()
      : super(
          r'(?<!\$)\$\$(?!\$)((?:\\[^\n]|[^\n\\$]|\$(?!\$))+?)\$\$(?!\$)'
          r'|(?<!\$)\$(?![\s$])((?:\\[^\n]|[^\n\\$])+?)(?<!\s)\$(?![$0-9])'
          r'|\\\(((?:\\[^\n]|[^\n\\])+?)\\\)'
          r'|\\\[((?:\\[^\n]|[^\n\\])+?)\\\]',
        );

  static final Expando<Set<int>> _backslashOpeners = Expando<Set<int>>();

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    final String source = parser.source;
    final int position = startMatchPos ?? parser.pos;
    if (position >= source.length) {
      return false;
    }
    if (source[position] == r'$') {
      return super.tryMatch(parser, position);
    }
    if (source[position] != r'\' ||
        position + 1 >= source.length ||
        (source[position + 1] != '(' && source[position + 1] != '[')) {
      return false;
    }
    final Set<int> openers = _backslashOpeners[parser] ??= _findBackslashOpeners(source);
    return openers.contains(position) && super.tryMatch(parser, position);
  }

  static Set<int> _findBackslashOpeners(String source) {
    final Set<int> openers = <int>{};
    final Set<String> closings = <String>{};
    for (int i = source.length - 1; i >= 0; i--) {
      if (source[i] == '\n') {
        closings.clear();
      }
      if (source[i] != r'\') {
        continue;
      }
      final int lastSlash = i;
      final String next = i + 1 < source.length ? source[i + 1] : '';
      while (i > 0 && source[i - 1] == r'\') {
        i--;
      }
      if ((lastSlash - i).isEven && (next == ')' || next == ']')) {
        closings.add(next);
      }
      // Preceding escapes belong to Markdown; keep potential openers conservative.
      if ((next == '(' && closings.contains(')')) || (next == '[' && closings.contains(']'))) {
        openers.add(lastSlash);
      }
    }
    return openers;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(_latexElement(
      match[1] ?? match[2] ?? match[3] ?? match[4]!,
      display: match[1] != null || match[4] != null,
    ));
    return true;
  }
}

// ---------- Multiline display math ----------

/// Recognizes matching standalone display fences without swallowing unfinished blocks.
/// Registered internally alongside the widget's custom block syntaxes.
class LatexBlockSyntax extends md.BlockSyntax {
  /// Creates the built-in display math syntax.
  const LatexBlockSyntax();

  static final RegExp _pattern = RegExp(r'^ {0,3}(\$\$|\\\[)[ \t]*$');
  static final Expando<Set<md.Line>> _openers = Expando<Set<md.Line>>();

  @override
  RegExp get pattern => _pattern;

  @override
  bool canParse(md.BlockParser parser) {
    if (!pattern.hasMatch(parser.current.content)) {
      return false;
    }
    Set<md.Line>? openers = _openers[parser];
    if (openers == null) {
      // Line identity keeps lookups correct when the parser retreats.
      openers = Set<md.Line>.identity();
      final Set<String> closings = <String>{};
      for (final md.Line line in parser.lines.reversed) {
        final Match? match = pattern.firstMatch(line.content);
        if (match != null && closings.contains(match[1] == r'$$' ? r'$$' : r'\]')) {
          openers.add(line);
        }
        final String content = line.content.trim();
        if (content == r'$$' || content == r'\]') {
          closings.add(content);
        }
      }
      _openers[parser] = openers;
    }
    return openers.contains(parser.current);
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final String closing = parser.current.content.trim() == r'$$' ? r'$$' : r'\]';
    final List<String> lines = <String>[];
    parser.advance();
    while (!parser.isDone && parser.current.content.trim() != closing) {
      lines.add(parser.current.content);
      parser.advance();
    }
    if (!parser.isDone) {
      parser.advance();
    }
    return md.Element('p', <md.Node>[_latexElement(lines.join('\n').trim(), display: true)]);
  }
}

md.Element _latexElement(String source, {required bool display}) =>
    md.Element.text('latex', source)..attributes['MathStyle'] = display ? 'display' : 'text';
