import 'package:http/http.dart' as http;

class ActoApi {
  final _client = http.Client();
  final _url = String.fromEnvironment('ACTO_URL', defaultValue: 'https://api.acto.com');

  Future<String> getUrl() async {
    final response = await _client.get(Uri.parse('https://api.acto.com'));

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to load URL');
    }
  }
}