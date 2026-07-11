# AGENTS.md — markpdf (Dart / Flutter)

Guidance for AI agents generating or modifying code that uses this package.

## What this is

Dart client for the markpdf API, built on `package:http`. Works in Flutter (iOS/Android/desktop/web) and plain Dart (CLI, server).

## Layout

```
lib/
  markpdf.dart          # package entrypoint — ALWAYS import `package:markpdf/markpdf.dart`
  src/client.dart         # MarkpdfClient — all HTTP logic
  src/models.dart          # ConvertOptions, JsonResult, Job, ConvertResult (sealed class) + enums
  src/errors.dart           # MarkpdfException and subclasses + errorForStatus()
```

## Public surface

`MarkpdfClient(apiKey: ..., baseUrl: ...)`:
- `convertFile(File file, {options})` → `POST /convert` multipart. **Mobile/desktop only** — uses `dart:io.File`, doesn't compile/work on Flutter Web.
- `convertBytes(Uint8List data, String filename, {options})` → `POST /convert/raw`. **This is the cross-platform path**, including Flutter Web.
- `convertFromUrl(url, {filename, options})` → `POST /convert/from-url`
- `pdfIndex(url, {filename})` → `Map<String, dynamic>`
- `getJob(jobId)` / `waitForJob(jobId, {pollInterval, timeout})` → `Job`

`ConvertResult` is a `sealed class` with 3 subtypes: `MarkdownResult`, `JsonConvertResult`, `QueuedResult`. **Use exhaustive pattern matching** (`switch` or an `is` chain) — the Dart compiler warns if a case is missing because it's `sealed`.

## Rules when generating code with this SDK

1. **If the target includes Flutter Web, use `convertBytes`, never `convertFile`.** `convertFile` imports `dart:io`, which doesn't compile on web. To get bytes on web from a file picker, use `file_picker` or `image_picker` with `XFile.readAsBytes()`.
2. **Don't treat `ConvertOptions` as mutable** — it's an immutable class with a `const` constructor and named params (`ConvertOptions(mode: ConversionMode.fast, ocr: true)`), no setters.
3. **Catch `MarkpdfException`**, not generic `Exception` — subclasses (`AuthenticationException`, `RateLimitException`, `PayloadTooLargeException`, etc) live in `src/errors.dart` and all expose `.statusCode`.
4. **Close the client** with `client.close()` when done (releases the internal `http.Client`), especially in tests or short-lived scripts.
5. **`autoPoll` defaults to `true`** in `ConvertOptions` — if the server queues (202), `convertFile`/`convertBytes`/`convertFromUrl` already wait for the final result before returning. Don't add your own polling loop unless you pass `autoPoll: false` explicitly.

## Commands

```bash
dart pub get
dart test
```

## Full reference

Public docs: https://docs.markpdf.tech/docs/sdks/flutter
