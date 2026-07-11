---
name: markpdf-flutter
description: Best practices for the markpdf Dart/Flutter package. Use when writing Dart code that imports "package:markpdf/markpdf.dart" — platform-specific method choice, sealed ConvertResult handling, error handling.
---

# Best practices — markpdf (Dart / Flutter)

## Platform-aware method choice

| Target | Method |
|---|---|
| iOS / Android / desktop, have a `dart:io.File` | `convertFile(file)` |
| Flutter Web, or any target with only bytes (`XFile`, picker result) | `convertBytes(bytes, filename)` |
| Multi-platform app (mobile + web) | Always `convertBytes` for shared code paths — avoids `dart:io` compile errors on web |

```dart
// Cross-platform (works on web too)
final bytes = await pickedXFile.readAsBytes();
final result = await client.convertBytes(bytes, pickedXFile.name);

// Mobile/desktop only
final result = await client.convertFile(File(path));
```

## Handling `ConvertResult` exhaustively

```dart
switch (result) {
  case MarkdownResult(:final markdown):
    print(markdown);
  case JsonConvertResult(:final result):
    print(result.markdown);
  case QueuedResult(:final job):
    print('queued: ${job.jobId}');
}
```

Don't cast with `as MarkdownResult` and skip the other cases — the whole point of the sealed class is that the compiler catches a missing case at build time.

## Error handling

```dart
try {
  final result = await client.convertFile(File('report.pdf'));
} on RateLimitException {
  // exponential backoff, retry
} on ConversionException {
  // retry with ConvertOptions(mode: ConversionMode.balanced)
} on MarkpdfException catch (e) {
  print('Conversion failed (${e.statusCode}): ${e.message}');
}
```

Order matters: catch specific subclasses before the general `MarkpdfException`.

## Resources

- Docs: https://docs.markpdf.tech/docs/sdks/flutter
- See `AGENTS.md` in this folder.
