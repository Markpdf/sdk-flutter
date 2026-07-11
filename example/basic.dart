import 'dart:io';

import 'package:markpdf/markpdf.dart';

Future<void> main() async {
  final client = MarkpdfClient(apiKey: Platform.environment['MARKPDF_API_KEY']!);

  try {
    final result = await client.convertFile(
      File('report.pdf'),
      options: const ConvertOptions(mode: ConversionMode.fast),
    );
    if (result is MarkdownResult) {
      print(result.markdown);
    }
  } on MarkpdfException catch (e) {
    print('Conversion failed (${e.statusCode}): ${e.message}');
  } finally {
    client.close();
  }
}
