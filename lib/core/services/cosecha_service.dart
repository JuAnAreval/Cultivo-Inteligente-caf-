import '../config/api_config.dart';
import 'http_client.dart';

class CosechaService {
  static Future<dynamic> getAll(
      {int page = 1, int limit = 10, String search = ''}) async {
    final url =
        '${ApiConfig.cosechaUrl}?page=$page&limit=$limit&search=$search';
    return await HttpClient.get(url);
  }

  static Future<dynamic> getById(String id) async {
    return await HttpClient.get('${ApiConfig.cosechaUrl}/$id');
  }

  static Future<dynamic> create(Map<String, dynamic> data) async {
    return await HttpClient.post(ApiConfig.cosechaUrl, data);
  }

  static Future<dynamic> update(String id, Map<String, dynamic> data) async {
    return await HttpClient.patch('${ApiConfig.cosechaUrl}/$id', data);
  }

  static Future<dynamic> delete(String id) async {
    return await HttpClient.delete('${ApiConfig.cosechaUrl}/$id');
  }
}
