# Plane Markdown preview
A paragraph with **semibold**, *italic*, ***both***, ~~deleted text~~, `inline code`, and a [link](https://flutter.dev).

Another paragraph tests ordinary block spacing. Resize the card to see how the same text wraps without changing the spacing between blocks.

## Lists and wrapping
- A long list item that wraps across several lines in the narrow card, so you can judge line height independently of the gaps between items.
- Second item
  - Nested item with enough text to wrap onto another line in the narrow card.
  - Another nested item
- Third item

1. First ordered item
2. Second ordered item
   1. Nested ordered item
   2. Another nested item

- [x] Completed task
- [ ] Task with enough text to wrap onto multiple lines in the narrow card without extra gaps between those lines.

### Paragraphs within list items
- A loose list item.

  Another paragraph in that same item.

- Another loose item.

## Heading transitions
### Heading after heading
Paragraph after a heading.

#### Fourth level
##### Fifth level
###### Sixth level
Text after the smallest heading.

## Quotes
> A quote with **formatting**.
>
> Another paragraph in the quote.
>
> - A quoted list item
> - Another quoted item

## Code
```dart
void main() {
  print('Hello, Plane');
}
```

## Table
| Feature | Status |
| :--- | ---: |
| Wrapped lists | Ready |
| Math | $E = mc^2$ |

---

## Bundled image
![Flutter logo](resource:assets/logo.png)

## Math
Inline math: $a^2 + b^2 = c^2$.

$$
\int_0^1 x^2\,dx = \frac{1}{3}
$$
