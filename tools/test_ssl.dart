import 'dart:io';

void main() async {
  print('Testing connection to https://pub.dev...');
  final stopwatch = Stopwatch()..start();
  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('https://pub.dev/api/packages/intl'));
    final response = await request.close();
    print('Connected in ${stopwatch.elapsedMilliseconds}ms with status: ${response.statusCode}');
  } catch (e, st) {
    print('Failed in ${stopwatch.elapsedMilliseconds}ms');
    print('Error type: ${e.runtimeType}');
    print('Error: $e');
    print('StackTrace: $st');
  }
}
