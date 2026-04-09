import '../config/api_config.dart';
import 'http_client.dart';

class FincaService {
  static Future<Map<String, dynamic>> getAll({
    int page = 1,
    int limit = 10,
    String search = '',
  }) async {
    final queryParameters = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };

    if (search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }

    final url = Uri.parse(
      ApiConfig.fincaUrl,
    ).replace(queryParameters: queryParameters).toString();

    return HttpClient.get(url);
  }

  static Future<Map<String, dynamic>> getById(String id) async {
    final url = '${ApiConfig.fincaUrl}/$id';
    return HttpClient.get(url);
  }

  static Future<Map<String, dynamic>> create(
    Map<String, dynamic> finca,
  ) async {
    return HttpClient.post(ApiConfig.fincaUrl, finca);
  }

  static Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> finca,
  ) async {
    final url = '${ApiConfig.fincaUrl}/$id';
    return HttpClient.patch(url, finca);
  }

  static Future<Map<String, dynamic>> delete(String id) async {
    final url = '${ApiConfig.fincaUrl}/$id';
    return HttpClient.delete(url);
  }
}
