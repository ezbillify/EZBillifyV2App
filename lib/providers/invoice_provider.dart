import 'package:flutter_riverpod/flutter_riverpod.dart';

class InvoiceState {
  final bool loading;
  final String? companyId;
  final String? internalUserId;
  final String? branchId;
  final String? branchName;
  final String? customerId;
  final String? customerName;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final String invoiceNumber;
  final String? quotationId;
  final String? orderId;
  final String? dcId;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double totalTax;
  final double totalAmount;
  final double existingPaid;

  InvoiceState({
    this.loading = false,
    this.companyId,
    this.internalUserId,
    this.branchId,
    this.branchName,
    this.customerId,
    this.customerName,
    DateTime? invoiceDate,
    DateTime? dueDate,
    this.invoiceNumber = "",
    this.quotationId,
    this.orderId,
    this.dcId,
    this.items = const [],
    this.subtotal = 0,
    this.totalTax = 0,
    this.totalAmount = 0,
    this.existingPaid = 0,
  })  : invoiceDate = invoiceDate ?? DateTime.now(),
        dueDate = dueDate ?? DateTime.now().add(const Duration(days: 7));

  InvoiceState copyWith({
    bool? loading,
    String? companyId,
    String? internalUserId,
    String? branchId,
    String? branchName,
    String? customerId,
    String? customerName,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? invoiceNumber,
    String? quotationId,
    String? orderId,
    String? dcId,
    List<Map<String, dynamic>>? items,
    double? subtotal,
    double? totalTax,
    double? totalAmount,
    double? existingPaid,
  }) {
    return InvoiceState(
      loading: loading ?? this.loading,
      companyId: companyId ?? this.companyId,
      internalUserId: internalUserId ?? this.internalUserId,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      quotationId: quotationId ?? this.quotationId,
      orderId: orderId ?? this.orderId,
      dcId: dcId ?? this.dcId,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      totalTax: totalTax ?? this.totalTax,
      totalAmount: totalAmount ?? this.totalAmount,
      existingPaid: existingPaid ?? this.existingPaid,
    );
  }
}

class InvoiceNotifier extends StateNotifier<InvoiceState> {
  InvoiceNotifier() : super(InvoiceState());

  void setInitialData({
    required String companyId,
    required String internalUserId,
    String? branchId,
    String? branchName,
    String? customerId,
    String? customerName,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? invoiceNumber,
    String? quotationId,
    String? orderId,
    String? dcId,
    List<Map<String, dynamic>>? items,
    double? existingPaid,
  }) {
    state = state.copyWith(
      companyId: companyId,
      internalUserId: internalUserId,
      branchId: branchId,
      branchName: branchName,
      customerId: customerId,
      customerName: customerName,
      invoiceDate: invoiceDate,
      dueDate: dueDate,
      invoiceNumber: invoiceNumber,
      quotationId: quotationId,
      orderId: orderId,
      dcId: dcId,
      items: items,
      existingPaid: existingPaid,
    );
    if (items != null) _calculateTotals(items);
  }

  void setLoading(bool loading) {
    state = state.copyWith(loading: loading);
  }

  void updateHeader({
    String? branchId,
    String? branchName,
    String? customerId,
    String? customerName,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? invoiceNumber,
  }) {
    state = state.copyWith(
      branchId: branchId ?? state.branchId,
      branchName: branchName ?? state.branchName,
      customerId: customerId ?? state.customerId,
      customerName: customerName ?? state.customerName,
      invoiceDate: invoiceDate ?? state.invoiceDate,
      dueDate: dueDate ?? state.dueDate,
      invoiceNumber: invoiceNumber ?? state.invoiceNumber,
    );
  }

  void setItems(List<Map<String, dynamic>> items) {
    _calculateTotals(items);
  }

  void _calculateTotals(List<Map<String, dynamic>> items) {
    double sub = 0;
    double tax = 0;
    final updatedItems = items.map((item) {
      final qty = (item['quantity'] ?? 0).toDouble();
      final price = (item['unit_price'] ?? 0).toDouble();
      final taxRate = (item['tax_rate'] ?? 0).toDouble();

      final totalInclusive = qty * price;
      final lineSub = totalInclusive / (1 + (taxRate / 100));
      final lineTax = totalInclusive - lineSub;

      final newItem = Map<String, dynamic>.from(item);
      newItem['total_amount'] = double.parse(totalInclusive.toStringAsFixed(2));
      newItem['tax_amount'] = double.parse(lineTax.toStringAsFixed(2));

      sub += lineSub;
      tax += lineTax;
      return newItem;
    }).toList();

    state = state.copyWith(
      items: updatedItems,
      subtotal: double.parse(sub.toStringAsFixed(2)),
      totalTax: double.parse(tax.toStringAsFixed(2)),
      totalAmount: double.parse((sub + tax).toStringAsFixed(2)),
    );
  }
}

final invoiceProvider = StateNotifierProvider.autoDispose<InvoiceNotifier, InvoiceState>((ref) {
  return InvoiceNotifier();
});
