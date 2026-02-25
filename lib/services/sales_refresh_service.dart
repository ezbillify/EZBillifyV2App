import 'package:flutter/foundation.dart';

class SalesRefreshService {
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);
  
  /// Triggers a refresh for all listeners (usually the list screens in Sales Module)
  static void triggerRefresh() {
    refreshNotifier.value++;
  }
}
