// Provides an editable comparison of Markdown using Plane's visual defaults.
// Run by the example app's dedicated make preview entry point.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'screens/home_screen.dart';

// ---------- Entry point ----------

void main() => runApp(const PlanePreview());

/// Hosts the Plane preview and its temporary appearance controls.
/// Used independently of the example app's original demo browser.
class PlanePreview extends StatefulWidget {
  /// Creates the editable comparison preview.
  const PlanePreview({super.key});

  @override
  State<PlanePreview> createState() => _PlanePreviewState();
}

class _PlanePreviewState extends State<PlanePreview> {
  // ---------- State and lifecycle ----------

  final TextEditingController _source = TextEditingController();
  String _original = '';
  bool _dark = false;
  bool _narrow = false;
  double? _blockSpacing;
  double? _listItemSpacing;
  double? _headingSpacing;
  double? _headingBeforeSpacing;

  @override
  void initState() {
    super.initState();
    _loadSamples();
  }

  Future<void> _loadSamples() async {
    final List<String> samples = await Future.wait(<Future<String>>[
      rootBundle.loadString('assets/plane_preview.md'),
      rootBundle.loadString('assets/original_markdown_example_data.md'),
    ]);
    if (!mounted) return;
    setState(() {
      _source.text = samples[0];
      _original = samples[1];
    });
  }

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  // ---------- Controls and comparison ----------

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = _planeTheme(_dark);
    return MaterialApp(
      title: 'Plane Markdown preview',
      theme: theme,
      home: Builder(
        builder: (BuildContext context) {
          final MarkdownStyleSheet defaults = _planeStyle(theme);
          final MarkdownStyleSheet style = defaults.copyWith(
            blockSpacing: _blockSpacing,
            listItemSpacing: _listItemSpacing,
            headingSpacing: _headingSpacing,
            headingBeforeSpacing: _headingBeforeSpacing,
          );
          return Scaffold(
            appBar: AppBar(
              title: const Text('Plane Markdown preview'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HomeScreen())),
                  child: const Text('All demos'),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                Wrap(
                  spacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    FilterChip(
                      label: const Text('Dark theme'),
                      selected: _dark,
                      onSelected: (bool value) => setState(() => _dark = value),
                    ),
                    FilterChip(
                      label: const Text('Narrow cards'),
                      selected: _narrow,
                      onSelected: (bool value) => setState(() => _narrow = value),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _blockSpacing = null;
                        _listItemSpacing = null;
                        _headingSpacing = null;
                        _headingBeforeSpacing = null;
                      }),
                      child: const Text('Reset spacing'),
                    ),
                  ],
                ),
                _spacingSlider(
                  'Block spacing',
                  style.blockSpacing!,
                  _blockSpacing != null,
                  (double value) => setState(() => _blockSpacing = value),
                ),
                _spacingSlider(
                  'List item spacing',
                  style.listItemSpacing ?? style.blockSpacing!,
                  _listItemSpacing != null,
                  (double value) => setState(() => _listItemSpacing = value),
                ),
                _spacingSlider(
                  'After heading',
                  style.headingSpacing ?? style.blockSpacing!,
                  _headingSpacing != null,
                  (double value) => setState(() => _headingSpacing = value),
                ),
                _spacingSlider(
                  'Before heading',
                  style.headingBeforeSpacing ?? style.blockSpacing!,
                  _headingBeforeSpacing != null,
                  (double value) => setState(() => _headingBeforeSpacing = value),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _source,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: 'Editable Markdown', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: <Widget>[
                    _card('Plane sample', _source.text, style, theme),
                    _card('Original example', _original, style, theme),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _spacingSlider(String label, double value, bool overridden, ValueChanged<double> onChanged) {
    return SizedBox(
      width: 420,
      child: Row(
        children: <Widget>[
          Text('$label: ${value.round()}${overridden ? '' : ' (default)'}'),
          Expanded(
            child: Slider(label: '$label ${value.round()}', value: value, max: 32, divisions: 32, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _card(String label, String data, MarkdownStyleSheet style, ThemeData theme) {
    return SizedBox(
      width: _narrow ? 320 : 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: MarkdownBody(
              data: data,
              styleSheet: style,
              imageBuilder: (Uri uri, String? title, String? alt) => uri.scheme == 'resource'
                  ? Image.asset(uri.path, semanticLabel: alt, width: 96)
                  : Image.network(
                      uri.toString(),
                      semanticLabel: alt,
                      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                          Text(alt ?? 'Image unavailable'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Plane typography and palette ----------

// Keep aligned with Plane's lib/theme/starless.dart and text_markdown_preview.dart.
ThemeData _planeTheme(bool dark) {
  final Color surface = Color(dark ? 0xff252930 : 0xffffffff);
  final Color text = Color(dark ? 0xffe7e7e9 : 0xff201c1a);
  final Color subtle = Color(dark ? 0xff1e2229 : 0xfff7f3f0);
  final Color border = Color(dark ? 0xff393e46 : 0xffeae3de);
  return ThemeData(
    brightness: dark ? Brightness.dark : Brightness.light,
    fontFamily: 'JetBrains Mono',
    scaffoldBackgroundColor: Color(dark ? 0xff16191e : 0xfffbf9f7),
    colorScheme: ColorScheme.fromSeed(
      seedColor: Color(dark ? 0xff879db8 : 0xffc66b53),
      primary: Color(dark ? 0xff879db8 : 0xffc66b53),
      brightness: dark ? Brightness.dark : Brightness.light,
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: Color(dark ? 0xff38414c : 0xfff2ece8),
    ),
    cardColor: subtle,
    dividerColor: border,
    textTheme: TextTheme(
      bodyMedium: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 14, color: text),
    ),
  );
}

MarkdownStyleSheet _planeStyle(ThemeData theme) {
  final Color text = theme.colorScheme.onSurface;
  final TextStyle base = TextStyle(fontFamily: 'JetBrains Mono', fontSize: 14, color: text, height: 1.5);
  final TextStyle semibold = base.copyWith(fontWeight: FontWeight.w600);
  final TextStyle table = base.copyWith(fontSize: 13, height: 1.45);
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    a: base.copyWith(color: theme.colorScheme.primary),
    p: base,
    code: base.copyWith(fontSize: 13, height: 1.4, backgroundColor: theme.cardColor),
    h1: semibold.copyWith(fontSize: 24, height: 1.2),
    h2: semibold.copyWith(fontSize: 22, height: 1.25),
    h3: semibold.copyWith(fontSize: 20, height: 1.3),
    h4: semibold.copyWith(fontSize: 18, height: 1.35),
    h5: semibold.copyWith(fontSize: 16, height: 1.35),
    h6: semibold.copyWith(height: 1.4),
    em: base.copyWith(fontStyle: FontStyle.italic),
    strong: semibold,
    del: base.copyWith(decoration: TextDecoration.lineThrough),
    blockquote: base,
    img: base,
    checkbox: base.copyWith(color: theme.colorScheme.primary),
    listBullet: base,
    tableHead: semibold.copyWith(fontSize: table.fontSize, height: table.height),
    tableBody: table,
    codeblockDecoration: BoxDecoration(color: theme.cardColor),
  );
}
