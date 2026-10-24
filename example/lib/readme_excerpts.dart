// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

// #docregion CreateMarkdownWithEmojiExtension
import 'package:markdown/markdown.dart' as md;

// #enddocregion CreateMarkdownWithEmojiExtension

/// Replace the plain text result with your app's syntax highlighting.
// #docregion SyntaxHighlighter
class AppSyntaxHighlighter implements SyntaxHighlighter {
  @override
  TextSpan format(String source, {String? language}) {
    // Use language to select your app's highlighting rules and theme.
    return TextSpan(text: source);
  }
}
// #enddocregion SyntaxHighlighter

/// Create a simple `Markdown` wdget.
void createMarkdown() {
  const String markdownSource = '';

  // #docregion CreateMarkdown
  const Markdown(data: markdownSource);
  // #enddocregion CreateMarkdown
}

/// Create a simple `MarkdownBody` widget.
void createMarkdownBody() {
  const String markdownSource = '';

  // #docregion CreateMarkdownBody
  const MarkdownBody(data: markdownSource);
  // #enddocregion CreateMarkdownBody
}

/// Create a simple `Markdown` widget with an emoji.
void createMarkdownWithEmoji() {
  final ScrollController controller = ScrollController();

  // #docregion CreateMarkdownWithEmoji
  Markdown(controller: controller, selectable: true, data: 'Insert emoji here😀 ');
  // #enddocregion CreateMarkdownWithEmoji
}

/// Create a simple `Markdown` widget with an emoji extension.
void createMarkdownWithEmojiExtension() {
  final ScrollController controller = ScrollController();

  // #docregion CreateMarkdownWithEmojiExtension
  Markdown(
    controller: controller,
    selectable: true,
    data: 'Insert emoji :smiley: here',
    extensionSet: md.ExtensionSet(md.ExtensionSet.gitHubFlavored.blockSyntaxes, <md.InlineSyntax>[
      md.EmojiSyntax(),
      ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
    ]),
  );
  // #enddocregion CreateMarkdownWithEmojiExtension
}
