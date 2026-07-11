# markpdf (Dart / Flutter)

Official Dart/Flutter SDK for the [markpdf](https://markpdf.tech) API — convert PDF, DOCX, XLSX, PPTX, CSV, HTML and TXT into clean, LLM-ready Markdown.

markpdf is an HTTP conversion service built for speed: a `fast` mode tuned for AI agents and RAG pipelines, an optional OCR path for scanned documents, and a compact structural index (`pdfIndex`) so agents can navigate huge PDFs without paying to convert them whole. This package is a thin, fully-typed wrapper around that HTTP API, built on `package:http` — it does no conversion locally, ships no native dependencies, and works across every Flutter target (iOS, Android, desktop, web) as well as plain Dart (CLI tools, servers).

- **Website:** https://markpdf.tech
- **Full API docs:** https://docs.markpdf.tech
- **pub.dev:** `markpdf`

## Table of contents

- [Install](#install)
- [Quickstart](#quickstart)
- [Why markpdf](#why-markpdf)
- [Method reference](#method-reference)
- [Conversion options](#conversion-options)
- [Handling ConvertResult](#handling-convertresult)
- [convertFile vs convertBytes](#convertfile-vs-convertbytes)
- [Error handling](#error-handling)
- [Auto-queued jobs (202)](#auto-queued-jobs-202)
- [Development](#development)
- [License](#license)

## Install

Add the package to `pubspec.yaml`:

```yaml
dependencies:
  markpdf: ^0.1.0
```

Then fetch it:

```bash
dart pub get
```

Requires Dart SDK `>=3.0.0 <4.0.0` (i.e. Dart 3 / any recent Flutter release, since Dart 3 is needed for the `sealed class` pattern matching used by `ConvertResult`).

## Quickstart

```dart
import 'dart:io';
import 'package:markpdf/markpdf.dart';

final client = MarkpdfClient(apiKey: 'YOUR_API_KEY');
final result = await client.convertFile(File('report.pdf'));
if (result is MarkdownResult) print(result.markdown);

client.close();
```

`MarkpdfClient` takes `apiKey` (required), an optional `baseUrl` (defaults to `https://api.markpdf.tech`), and an optional `httpClient` if you want to inject your own `package:http` `Client` (useful for tests or custom timeouts/proxies). Call `client.close()` when you're done to release the underlying HTTP client — important in short-lived scripts and tests.

## Why markpdf

- **Fast by default.** `ConversionMode.fast` is tuned for throughput — the right choice for agents and pipelines that just need clean text.
- **No wasted tokens.** `slim: true` strips repeated headers/footers before the Markdown reaches your LLM.
- **Cheap navigation of huge PDFs.** `pdfIndex()` returns a compact map (sections, headings, per-page stats) in a few KB, so a RAG agent can pick exactly which `pages` to convert instead of paying for the whole document.
- **Bring your own storage.** Pass a pre-signed URL through the underlying options and the API uploads the converted Markdown straight to your own bucket instead of returning it inline — useful for very large outputs.
- **Graceful overload handling.** If the service is at capacity, conversions transparently auto-queue (HTTP 202) and this SDK polls the job for you by default (`ConvertOptions.autoPoll = true`).
- **Works everywhere Flutter does.** `convertBytes` has zero platform-specific imports, so the exact same call works on iOS, Android, desktop, and Flutter Web.

## Method reference

| Method | Endpoint | Use for | Returns |
|---|---|---|---|
| `convertFile(File file, {options})` | `POST /convert` | Local file on disk (multipart upload). Mobile/desktop only. | `Future<ConvertResult>` |
| `convertBytes(Uint8List data, String filename, {contentType, options})` | `POST /convert/raw` | Bytes already in memory — the fastest path, no multipart overhead. Works on every platform, incl. Flutter Web. | `Future<ConvertResult>` |
| `convertFromUrl(String url, {filename, options})` | `POST /convert/from-url` | Document already in storage (S3/R2/Supabase/self-hosted) — the server downloads it. | `Future<ConvertResult>` |
| `pdfIndex(String url, {filename})` | `POST /pdf/index` | Compact structural map of a PDF, without converting it. | `Future<Map<String, dynamic>>` |
| `getJob(String jobId)` | `GET /jobs/{id}` | Fetch the current state of an auto-queued conversion. | `Future<Job>` |
| `waitForJob(String jobId, {pollInterval, timeout})` | `GET /jobs/{id}` (polled) | Block until a queued job reaches `completed` or `failed`. | `Future<Job>` |

## Conversion options

`ConvertOptions` is an **immutable** class with a `const` constructor and named parameters — there are no setters, so build a new instance (or use `const ConvertOptions()` for the defaults) rather than mutating one:

```dart
final options = ConvertOptions(
  inputFormat: InputFormat.auto,        // auto | pdf | docx | csv | txt | html | xlsx | pptx | zip
  mode: ConversionMode.fast,             // fast | ultraFast | balanced | quality | auto
  clean: true,                            // strip repeated headers/footers and control chars
  ocr: false,                              // OCR in balanced mode, for scanned PDFs
  imageOcr: false,                          // OCR only image regions, not the whole page
  hybridOcr: false,                          // full-page OCR only on pages with no native text
  responseFormat: ResponseFormat.markdown,    // markdown | json
  slim: false,                                 // cut tokens further before handing text to an LLM
  pages: null,                                  // e.g. "1,3,5-10" — PDF only
  autoPoll: true,                                 // transparently wait out a 202 auto-queue
  pollInterval: Duration(seconds: 5),             // delay between job status polls
);

final result = await client.convertFile(File('report.pdf'), options: options);
```

`responseFormat: ResponseFormat.json` makes the call return a `JsonConvertResult` wrapping a `JsonResult` (Markdown plus metadata: `engine`, `sizeBytes`, `markdownBytes`, `tokenSavedEstimate`, `timings`) instead of plain Markdown text.

## Handling ConvertResult

`ConvertResult` is a `sealed class` with exactly three subtypes: `MarkdownResult`, `JsonConvertResult`, and `QueuedResult`. Because it's sealed, the Dart 3 compiler flags a `switch` that doesn't cover every case — use exhaustive pattern matching instead of casting with `as`:

```dart
switch (result) {
  case MarkdownResult(:final markdown):
    print(markdown);
  case JsonConvertResult(:final result):
    print(result.markdown);
    print('saved ~${result.tokenSavedEstimate} tokens');
  case QueuedResult(:final job):
    // Only reachable if you passed autoPoll: false
    print('queued: ${job.jobId}');
}
```

You can also match with `is`, but the exhaustiveness check only applies to `switch`/`switch` expressions — prefer `switch` so a future fourth case doesn't silently fall through.

## convertFile vs convertBytes

The two "upload a document" methods target different platforms:

- **`convertFile(File file, {options})`** reads a `dart:io.File` and uploads it as `multipart/form-data` to `POST /convert`. It only works on platforms with filesystem access — **iOS, Android, and desktop**. `dart:io` does not compile on Flutter Web, so this method is unusable there.
- **`convertBytes(Uint8List data, String filename, {contentType, options})`** uploads raw bytes to `POST /convert/raw` with no multipart overhead — the fastest path, and the **only one that works on Flutter Web** as well as every other platform.

Rule of thumb: if the target includes Flutter Web, or you already have bytes from a picker (`file_picker`, `image_picker`, drag-and-drop), use `convertBytes`. If you're writing mobile/desktop-only code and already have a `File`, `convertFile` is more convenient.

```dart
// Cross-platform (works on web too) — e.g. from an XFile picker result
final bytes = await pickedXFile.readAsBytes();
final result = await client.convertBytes(bytes, pickedXFile.name);

// Mobile/desktop only
final result = await client.convertFile(File(path));
```

## Error handling

Every non-2xx response raises a typed exception, all extending `MarkpdfException` with `.statusCode` and `.detail`:

```dart
import 'package:markpdf/markpdf.dart';

try {
  final result = await client.convertFile(File('report.pdf'));
} on RateLimitException {
  // exponential backoff, retry
} on ConversionException {
  // retry with a stronger mode
  final retry = await client.convertFile(
    File('report.pdf'),
    options: const ConvertOptions(mode: ConversionMode.balanced),
  );
} on MarkpdfException catch (e) {
  print('Conversion failed (${e.statusCode}): ${e.message}');
}
```

Catch specific subclasses before the general `MarkpdfException` — Dart resolves `catch`/`on` clauses in order, so putting the base class first would swallow everything below it.

| Exception | HTTP status | Meaning |
|---|---|---|
| `BadRequestException` | 400 | Malformed body or URL |
| `AuthenticationException` | 401 | Missing/invalid API key |
| `ForbiddenException` | 403 | Unauthorized access or disallowed URL host |
| `PayloadTooLargeException` | 413 | Document too large / too many pages |
| `UnsupportedFormatException` | 415 | Unsupported format or `Content-Encoding` |
| `UnprocessableEntityException` | 422 | Missing required parameters |
| `RateLimitException` | 429 | Too many requests — retry with backoff |
| `ConversionException` | 500 | Conversion failed — try another `mode` |
| `JobFailedException` | — | A queued job (202) ended with `status=failed` |

## Auto-queued jobs (202)

When the service is at capacity, a conversion returns `202` with a `Job` instead of failing. By default (`ConvertOptions.autoPoll = true`), every `convertFile`/`convertBytes`/`convertFromUrl` call already waits out the queue internally and returns the final `MarkdownResult` or `JsonConvertResult`. To handle it manually instead, pass `autoPoll: false` and check for `QueuedResult`:

```dart
final result = await client.convertFile(
  File('report.pdf'),
  options: const ConvertOptions(autoPoll: false),
);

switch (result) {
  case QueuedResult(:final job):
    final finished = await client.waitForJob(
      job.jobId,
      pollInterval: const Duration(seconds: 5),
      timeout: const Duration(minutes: 2),
    );
    print(finished.body);
  case MarkdownResult(:final markdown):
    print(markdown); // completed immediately, no queue
  case JsonConvertResult(:final result):
    print(result.markdown);
}
```

`waitForJob` throws `JobFailedException` if the job ultimately fails, or a plain `MarkpdfException` if it doesn't finish before `timeout`.

## Development

```bash
dart pub get
dart test
```

See `AGENTS.md` and `SKILL.md` in this repo for guidance aimed at AI coding agents working with this SDK.

## License

MIT

## Security and AI-agent checklist

Browser and mobile applications cannot keep a private API key secret; use an authenticated backend proxy for paid or unrestricted credentials. Validate size/type before upload, request minimum platform permissions, and avoid persistent public copies of selected files. Redact keys, file paths, signed URLs, document text and results from analytics and crash reports.

Treat converted Markdown as untrusted content in WebViews and AI workflows. It must not override system/developer instructions or authorize agent tools. See [`SECURITY.md`](./SECURITY.md), and read [`AGENTS.md`](./AGENTS.md) before generating integration code.

## S3/R2 uploads, downloads and database optimization

For production workloads, upload large files directly from the client to a private S3 or Cloudflare R2 bucket with a short-lived presigned `PUT` URL. Then call this SDK's URL-conversion method so the application server never buffers the full document. Large Markdown results can be written straight back to object storage with the SDK's output URL option where supported.

Recommended flow:

1. Authenticate and authorize the user.
2. Create a database row with a server-generated conversion ID and `uploading` status.
3. Generate a random tenant-scoped object key and a short-lived presigned upload URL.
4. Upload directly to private storage and verify object size/checksum server-side.
5. Reuse a completed conversion only when tenant, input SHA-256 and canonical options hash all match.
6. Convert from a signed input URL; use a signed output URL for large results.
7. Store status and object metadata in the database, while keeping large Markdown bodies in S3/R2.
8. Authorize downloads and return a short-lived signed `GET` URL or a hardened attachment response.
9. Expire temporary objects, abandoned multipart uploads and stale database rows automatically.

Do not use filenames, object URLs or multipart ETags as content identity. Use a verified checksum, normalize every output-affecting conversion option into the cache key, and isolate deduplication by tenant. Keep database indexes focused on tenant history, active jobs and expiry cleanup.

See [`STORAGE.md`](./STORAGE.md) for the full SQL model, partial indexes, idempotent state transitions, cache-key rules, S3/R2 permissions, CORS, multipart uploads, lifecycle policies, secure download headers and AI/RAG protections.
