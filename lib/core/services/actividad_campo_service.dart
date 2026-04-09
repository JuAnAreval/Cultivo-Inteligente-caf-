import '../config/api_config.dart';
import 'http_client.dart';

class ActividadCampoService {
  static Future<dynamic> getAll(
      {int page = 1, int limit = 10, String search = ''}) async {
    final url =
        '${ApiConfig.actividadUrl}?page=$page&limit=$limit&search=$search';
    return await HttpClient.get(url);
  }

  static Future<dynamic> getById(String id) async {
    return await HttpClient.get('${ApiConfig.actividadUrl}/$id');
  }

  static Future<dynamic> create(Map<String, dynamic> data) async {
    return await HttpClient.post(ApiConfig.actividadUrl, data);
  }

  static Future<dynamic> update(String id, Map<String, dynamic> data) async {
    return await HttpClient.patch('${ApiConfig.actividadUrl}/$id', data);
  }

  static Future<dynamic> delete(String id) async {
    return await HttpClient.delete('${ApiConfig.actividadUrl}/$id');
  }
}
