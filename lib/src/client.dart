import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'errors.dart';
import 'models.dart';

/// Client for the markpdf (Flash PDF to Markdown) API.
///
/// ```dart
/// final client = MarkpdfClient(apiKey: 'YOUR_API_KEY');
/// final result = await client.convertFile(File('report.pdf'));
/// if (result is MarkdownResult) print(result.markdown);
/// ```
class MarkpdfClient {
  final String apiKey;
  final String baseUrl;
  final http.Client _http;

  MarkpdfClient({
    required this.apiKey,
    this.baseUrl = 'https://api.markpdf.tech',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  void close() => _http.close();

  Map<String, String> _headers([Map<String, String>? extra]) => {
        'x-api-key': apiKey,
        ...?extra,
      };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<ConvertResult> _maybePoll(ConvertResult result, ConvertOptions options) async {
    if (result is QueuedResult && options.autoPoll) {
      final job = await waitForJob(result.job.jobId, pollInterval: options.pollInterval);
      return _jobToResult(job);
    }
    return result;
  }

  ConvertResult _jobToResult(Job job) {
    if (job.body is String) return MarkdownResult(job.body as String);
    if (job.body is Map<String, dynamic>) return JsonConvertResult(JsonResult.fromJson(job.body as Map<String, dynamic>));
    return QueuedResult(job);
  }

  ConvertResult _parseConversionResponse(http.Response response) {
    if (response.statusCode == 202) {
      return QueuedResult(Job.fromJson(jsonDecode(response.body) as Map<String, dynamic>));
    }
    final contentType = response.headers['content-type'] ?? '';
    if (response.statusCode >= 400) {
      final dynamic detail = contentType.contains('application/json') ? jsonDecode(response.body) : response.body;
      throw errorForStatus(response.statusCode, detail);
    }
    if (contentType.contains('application/json')) {
      return JsonConvertResult(JsonResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>));
    }
    return MarkdownResult(response.body);
  }

  /// Convert a local file via `POST /convert` (multipart/form-data).
  Future<ConvertResult> convertFile(File file, {ConvertOptions options = const ConvertOptions()}) async {
    final uri = _uri('/convert', options.toQueryParams());
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers())
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    return _maybePoll(_parseConversionResponse(response), options);
  }

  /// Convert an in-memory buffer via `POST /convert/raw` (fastest path; works on Flutter Web too).
  Future<ConvertResult> convertBytes(
    Uint8List data,
    String filename, {
    String contentType = 'application/octet-stream',
    ConvertOptions options = const ConvertOptions(),
  }) async {
    final query = {...options.toQueryParams(), 'filename': filename};
    final response = await _http.post(
      _uri('/convert/raw', query),
      headers: _headers({'content-type': contentType}),
      body: data,
    );
    return _maybePoll(_parseConversionResponse(response), options);
  }

  /// Convert a document the API fetches itself from a pre-signed URL via `POST /convert/from-url`.
  Future<ConvertResult> convertFromUrl(
    String url, {
    String? filename,
    ConvertOptions options = const ConvertOptions(),
  }) async {
    final body = <String, dynamic>{
      'url': url,
      if (filename != null) 'filename': filename,
      'input_format': options.inputFormat.value,
      'mode': options.mode.value,
      'clean': options.clean,
      'ocr': options.ocr,
      'image_ocr': options.imageOcr,
      'hybrid_ocr': options.hybridOcr,
      'response_format': options.responseFormat.value,
      'slim': options.slim,
      if (options.pages != null) 'pages': options.pages,
    };
    final response = await _http.post(
      _uri('/convert/from-url'),
      headers: _headers({'content-type': 'application/json'}),
      body: jsonEncode(body),
    );
    return _maybePoll(_parseConversionResponse(response), options);
  }

  /// Fetch a compact structural index of a PDF (`POST /pdf/index`) without converting it.
  Future<Map<String, dynamic>> pdfIndex(String url, {String? filename}) async {
    final response = await _http.post(
      _uri('/pdf/index'),
      headers: _headers({'content-type': 'application/json'}),
      body: jsonEncode({'url': url, if (filename != null) 'filename': filename}),
    );
    if (response.statusCode >= 400) {
      throw errorForStatus(response.statusCode, _tryDecode(response.body));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Poll the status of an auto-queued conversion (`GET /jobs/{id}`).
  Future<Job> getJob(String jobId) async {
    final response = await _http.get(_uri('/jobs/$jobId'), headers: _headers());
    if (response.statusCode >= 400) {
      throw errorForStatus(response.statusCode, _tryDecode(response.body));
    }
    return Job.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Block until a queued job reaches `completed` or `failed`.
  Future<Job> waitForJob(
    String jobId, {
    Duration pollInterval = const Duration(seconds: 5),
    Duration? timeout,
  }) async {
    final deadline = timeout != null ? DateTime.now().add(timeout) : null;
    while (true) {
      final job = await getJob(jobId);
      if (job.isTerminal) {
        if (job.status == 'failed') {
          throw JobFailedException(job.error ?? 'Job failed');
        }
        return job;
      }
      if (deadline != null && DateTime.now().isAfter(deadline)) {
        throw MarkpdfException('Job $jobId did not finish before timeout');
      }
      await Future.delayed(pollInterval);
    }
  }

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }
}
