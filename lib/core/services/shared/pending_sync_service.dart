import 'package:app_flutter_ai/core/services/shared/database_helper.dart';
import 'package:flutter/foundation.dart';

class PendingSyncService {
  static final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  static Future<void> refreshPendingCount() async {
    final count = await DatabaseHelper().getPendingChangesCount();
    pendingCount.value = count;
  }
}
