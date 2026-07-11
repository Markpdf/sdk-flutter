# markpdf (Dart / Flutter)

Official Dart/Flutter SDK for the [markpdf](https://markpdf.tech) API.

## Install

```yaml
dependencies:
  markpdf: ^0.1.0
```

## Quickstart

```dart
import 'dart:io';
import 'package:markpdf/markpdf.dart';

final client = MarkpdfClient(apiKey: 'YOUR_API_KEY');
final result = await client.convertFile(File('report.pdf'));
if (result is MarkdownResult) print(result.markdown);
```

On Flutter Web (no `dart:io` file access), use `convertBytes` with the bytes from an `XFile` / file picker instead of `convertFile`.

## Features

- `convertFile` (mobile/desktop, multipart), `convertBytes` (cross-platform, raw), `convertFromUrl`, `pdfIndex`, `getJob`/`waitForJob`.
- Automatic handling of `202` auto-queued jobs (`ConvertOptions.autoPoll = true` by default).
- Typed exceptions per HTTP status code (`AuthenticationException`, `RateLimitException`, ...), all extending `MarkpdfException`.
- `ConvertResult` is a sealed class (`MarkdownResult`, `JsonConvertResult`, `QueuedResult`).

Full documentation: https://docs.markpdf.tech
