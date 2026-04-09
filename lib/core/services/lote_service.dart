import '../config/api_config.dart';
import 'http_client.dart';

class LoteService {
  static Future<dynamic> getAll(
      {int page = 1, int limit = 10, String search = ''}) async {
    final url = '${ApiConfig.loteUrl}?page=$page&limit=$limit&search=$search';
    return await HttpClient.get(url);
  }

  static Future<dynamic> getById(String id) async {
    return await HttpClient.get('${ApiConfig.loteUrl}/$id');
  }

  static Future<dynamic> create(Map<String, dynamic> data) async {
    return await HttpClient.post(ApiConfig.loteUrl, data);
  }

  static Future<dynamic> update(String id, Map<String, dynamic> data) async {
    return await HttpClient.patch('${ApiConfig.loteUrl}/$id', data);
  }

  static Future<dynamic> delete(String id) async {
    return await HttpClient.delete('${ApiConfig.loteUrl}/$id');
  }
}
