import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SalesOrderState {
  final String orderNumber;
  final String? branchId;
  final String? branchName;
  final String? customerId;
  final String? customerName;
  final DateTime orderDate;
  final DateTime expectedDelivery;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double totalTax;
  final double totalAmount;
  final bool loading;

  SalesOrderState({
    this.orderNumber = "",
    this.branchId,
    this.branchName,
    this.customerId,
    this.customerName,
    DateTime? orderDate,
    DateTime? expectedDelivery,
    this.items = const [],
    this.subtotal = 0,
    this.totalTax = 0,
    this.totalAmount = 0,
    this.loading = false,
  })  : orderDate = orderDate ?? DateTime.now(),
        expectedDelivery = expectedDelivery ?? DateTime.now().add(const Duration(days: 7));

  SalesOrderState copyWith({
    String? orderNumber,
    String? branchId,
    String? branchName,
    String? customerId,
    String? customerName,
    DateTime? orderDate,
    DateTime? expectedDelivery,
    List<Map<String, dynamic>>? items,
    double? subtotal,
    double? totalTax,
    double? totalAmount,
    bool? loading,
  }) {
    return SalesOrderState(
      orderNumber: orderNumber ?? this.orderNumber,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      orderDate: orderDate ?? this.orderDate,
      expectedDelivery: expectedDelivery ?? this.expectedDelivery,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      totalTax: totalTax ?? this.totalTax,
      totalAmount: totalAmount ?? this.totalAmount,
      loading: loading ?? this.loading,
    );
  }
}

class SalesOrderNotifier extends StateNotifier<SalesOrderState> {
  SalesOrderNotifier() : super(SalesOrderState());

  void setLoading(bool loading) => state = state.copyWith(loading: loading);

  void updateHeader({
    String? orderNumber,
    String? branchId,
    String? branchName,
    String? customerId,
    String? customerName,
    DateTime? orderDate,
    DateTime? expectedDelivery,
  }) {
    state = state.copyWith(
      orderNumber: orderNumber,
      branchId: branchId,
      branchName: branchName,
      customerId: customerId,
      customerName: customerName,
      orderDate: orderDate,
      expectedDelivery: expectedDelivery,
    );
  }

  void addItem(Map<String, dynamic> item) {
    final newItems = List<Map<String, dynamic>>.from(state.items)..add(item);
    _updateItemsAndTotals(newItems);
  }

  void updateItemQuantity(int index, double quantity) {
    if (index < 0 || index >= state.items.length) return;
    final newItems = List<Map<String, dynamic>>.from(state.items);
    newItems[index] = Map<String, dynamic>.from(newItems[index])..['quantity'] = quantity;
    _updateItemsAndTotals(newItems);
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final newItems = List<Map<String, dynamic>>.from(state.items)..removeAt(index);
    _updateItemsAndTotals(newItems);
  }

  void setItems(List<Map<String, dynamic>> items) {
    _updateItemsAndTotals(items);
  }

  void _updateItemsAndTotals(List<Map<String, dynamic>> items) {
    double sub = 0;
    double tax = 0;
    
    final updatedItems = items.map((item) {
      final qty = (item['quantity'] ?? 0).toDouble();
      final price = (item['unit_price'] ?? 0).toDouble();
      final taxRate = (item['tax_rate'] ?? 0).toDouble();

      final totalInclusive = qty * price;
      final lineSub = totalInclusive / (1 + (taxRate / 100));
      final lineTax = totalInclusive - lineSub;

      final updatedItem = Map<String, dynamic>.from(item)
        ..['total_amount'] = double.parse(totalInclusive.toStringAsFixed(2))
        ..['tax_amount'] = double.parse(lineTax.toStringAsFixed(2));

      sub += lineSub;
      tax += lineTax;
      return updatedItem;
    }).toList();

    state = state.copyWith(
      items: updatedItems,
      subtotal: double.parse(sub.toStringAsFixed(2)),
      totalTax: double.parse(tax.toStringAsFixed(2)),
      totalAmount: double.parse((sub + tax).toStringAsFixed(2)),
    );
  }
}

final salesOrderProvider = StateNotifierProvider.autoDispose<SalesOrderNotifier, SalesOrderState>((ref) {
  return SalesOrderNotifier();
});
