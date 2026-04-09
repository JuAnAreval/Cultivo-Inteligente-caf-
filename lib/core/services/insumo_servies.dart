import '../config/api_config.dart';
import 'http_client.dart';

class InsumoService {
  static Future<dynamic> getAll(
      {int page = 1, int limit = 10, String search = ''}) async {
    final url = '${ApiConfig.insumoUrl}?page=$page&limit=$limit&search=$search';
    return await HttpClient.get(url);
  }

  static Future<dynamic> getById(String id) async {
    return await HttpClient.get('${ApiConfig.insumoUrl}/$id');
  }

  static Future<dynamic> create(Map<String, dynamic> data) async {
    return await HttpClient.post(ApiConfig.insumoUrl, data);
  }

  static Future<dynamic> update(String id, Map<String, dynamic> data) async {
    return await HttpClient.patch('${ApiConfig.insumoUrl}/$id', data);
  }

  static Future<dynamic> delete(String id) async {
    return await HttpClient.delete('${ApiConfig.insumoUrl}/$id');
  }
}
