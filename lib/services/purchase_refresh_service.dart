import 'package:flutter/material.dart';

class PurchaseRefreshService {
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  static void triggerRefresh() {
    refreshNotifier.value++;
  }
}
