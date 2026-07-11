enum InputFormat { auto, pdf, docx, csv, txt, html, xlsx, pptx, zip }

enum ConversionMode { fast, ultraFast, balanced, quality, auto }

enum ResponseFormat { markdown, json }

extension InputFormatValue on InputFormat {
  String get value => switch (this) {
        InputFormat.auto => 'auto',
        InputFormat.pdf => 'pdf',
        InputFormat.docx => 'docx',
        InputFormat.csv => 'csv',
        InputFormat.txt => 'txt',
        InputFormat.html => 'html',
        InputFormat.xlsx => 'xlsx',
        InputFormat.pptx => 'pptx',
        InputFormat.zip => 'zip',
      };
}

extension ConversionModeValue on ConversionMode {
  String get value => switch (this) {
        ConversionMode.fast => 'fast',
        ConversionMode.ultraFast => 'ultra_fast',
        ConversionMode.balanced => 'balanced',
        ConversionMode.quality => 'quality',
        ConversionMode.auto => 'auto',
      };
}

extension ResponseFormatValue on ResponseFormat {
  String get value => this == ResponseFormat.json ? 'json' : 'markdown';
}

/// Options shared by every conversion call. Mirrors the API's query params.
class ConvertOptions {
  final InputFormat inputFormat;
  final ConversionMode mode;
  final bool clean;
  final bool ocr;
  final bool imageOcr;
  final bool hybridOcr;
  final ResponseFormat responseFormat;
  final bool slim;

  /// 1-based page ranges, PDF only. Example: "1,3,5-10".
  final String? pages;

  /// Auto-poll `/jobs/{id}` when the API returns 202.
  final bool autoPoll;
  final Duration pollInterval;

  const ConvertOptions({
    this.inputFormat = InputFormat.auto,
    this.mode = ConversionMode.fast,
    this.clean = true,
    this.ocr = false,
    this.imageOcr = false,
    this.hybridOcr = false,
    this.responseFormat = ResponseFormat.markdown,
    this.slim = false,
    this.pages,
    this.autoPoll = true,
    this.pollInterval = const Duration(seconds: 5),
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{
      'input_format': inputFormat.value,
      'mode': mode.value,
      'clean': clean.toString(),
      'ocr': ocr.toString(),
      'image_ocr': imageOcr.toString(),
      'hybrid_ocr': hybridOcr.toString(),
      'response_format': responseFormat.value,
      'slim': slim.toString(),
    };
    if (pages != null) params['pages'] = pages!;
    return params;
  }
}

/// Parsed body of a conversion response when `responseFormat = json`.
class JsonResult {
  final String filename;
  final String inputFormat;
  final String markdown;
  final String engine;
  final int sizeBytes;
  final int markdownBytes;
  final int? tokenSavedEstimate;
  final Map<String, dynamic> timings;
  final Map<String, dynamic> raw;

  JsonResult({
    required this.filename,
    required this.inputFormat,
    required this.markdown,
    required this.engine,
    required this.sizeBytes,
    required this.markdownBytes,
    this.tokenSavedEstimate,
    required this.timings,
    required this.raw,
  });

  factory JsonResult.fromJson(Map<String, dynamic> json) => JsonResult(
        filename: json['filename'] ?? '',
        inputFormat: json['input_format'] ?? '',
        markdown: json['markdown'] ?? '',
        engine: json['engine'] ?? '',
        sizeBytes: json['size_bytes'] ?? 0,
        markdownBytes: json['markdown_bytes'] ?? 0,
        tokenSavedEstimate: json['token_saved_estimate'],
        timings: Map<String, dynamic>.from(json['timings'] ?? {}),
        raw: json,
      );
}

/// State of a conversion that was auto-queued (HTTP 202).
class Job {
  final String jobId;
  final String status; // queued | processing | completed | failed
  final dynamic body;
  final String? error;
  final Map<String, dynamic> raw;

  Job({required this.jobId, required this.status, this.body, this.error, required this.raw});

  factory Job.fromJson(Map<String, dynamic> json) => Job(
        jobId: json['job_id'] ?? '',
        status: json['status'] ?? '',
        body: json['body'],
        error: json['error'],
        raw: json,
      );

  bool get isTerminal => status == 'completed' || status == 'failed';
}

/// Result of a conversion call: either raw Markdown text, a parsed [JsonResult]
/// (when `responseFormat = json`), or a [Job] (when the API queued the request).
sealed class ConvertResult {}

class MarkdownResult extends ConvertResult {
  final String markdown;
  MarkdownResult(this.markdown);
}

class JsonConvertResult extends ConvertResult {
  final JsonResult result;
  JsonConvertResult(this.result);
}

class QueuedResult extends ConvertResult {
  final Job job;
  QueuedResult(this.job);
}
