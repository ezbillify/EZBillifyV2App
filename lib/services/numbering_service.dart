import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NumberingService {
  static const Map<String, String> typePrefixMap = {
    'SALES_QUOTATION': 'QTN',
    'SALES_ORDER': 'SO',
    'SALES_INVOICE': 'INV',
    'DELIVERY_CHALLAN': 'DC',
    'CREDIT_NOTE': 'CN',
    'PURCHASE_ORDER': 'PO',
    'RFQ': 'RFQ',
    'PURCHASE_RFQ': 'RFQ',
    'GRN': 'GRN',
    'PURCHASE_GRN': 'GRN',
    'PURCHASE_INVOICE': 'PINV',
    'PURCHASE_PAYMENT': 'PAY',
    'SALES_PAYMENT': 'RCPT',
    'DEBIT_NOTE': 'DN',
    'PURCHASE_DEBIT_NOTE': 'DN'
  };

  /// Gets the next document number, optionally incrementing the sequence.
  /// Set [previewOnly] to true for display in forms, false for actual saving.
  static Future<String> getNextDocumentNumber({
    required String companyId,
    required String documentType,
    String? branchId,
    bool previewOnly = false,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      // 1. Try to find existing sequence
      var query = supabase
          .from('document_sequences')
          .select('*')
          .eq('company_id', companyId)
          .eq('document_type', documentType);

      if (branchId != null) {
        query = query.eq('branch_id', branchId);
      } else {
        query = query.isFilter('branch_id', null);
      }

      var seq = await query.maybeSingle();

      // 2. If not found, create default sequence (matching web logic)
      if (seq == null) {
        final shortPrefix = typePrefixMap[documentType] ?? documentType.replaceAll('_', '').substring(0, 3);
        String prefix = '${shortPrefix.toUpperCase()}-';

        if (branchId != null) {
          try {
            final branch = await supabase.from('branches').select('code').eq('id', branchId).single();
            if (branch['code'] != null) {
              prefix = '${branch['code']}-${shortPrefix.toUpperCase()}-';
            }
          } catch (e) {
            debugPrint("Error fetching branch code: $e");
          }
        }

        // Calculate Financial Year Suffix (April to March)
        final now = DateTime.now();
        final startYear = now.month >= 4 ? now.year : now.year - 1;
        final shortYear = startYear % 100;
        final suffix = '/$shortYear-${shortYear + 1}';

        seq = await supabase
            .from('document_sequences')
            .insert({
              'company_id': companyId,
              'branch_id': branchId,
              'document_type': documentType,
              'prefix': prefix,
              'suffix': suffix,
              'padding_zeros': 5,
              'current_value': 0,
            })
            .select()
            .single();
      }

      // 3. Roll-over check (New financial year reset)
      final now = DateTime.now();
      final targetStartYear = now.month >= 4 ? now.year : now.year - 1;
      final targetShortYear = targetStartYear % 100;
      final targetSuffix = '/$targetShortYear-${targetShortYear + 1}';

      if (seq['suffix'] != targetSuffix && (seq['reset_yearly'] ?? true)) {
        seq = await supabase
            .from('document_sequences')
            .update({
              'current_value': 0,
              'suffix': targetSuffix,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', seq['id'])
            .select()
            .single();
      }

      // 4. Calculate next value
      final nextVal = (seq['current_value'] ?? 0) + 1;

      // 5. Update DB if not preview
      if (!previewOnly) {
        await supabase
            .from('document_sequences')
            .update({
              'current_value': nextVal,
              'updated_at': DateTime.now().toIso8601String()
            })
            .eq('id', seq['id']);
      }

      // 6. Format using stored settings
      final padding = seq['padding_zeros'] ?? 5;
      final numStr = nextVal.toString().padLeft(padding, '0');
      final prefix = seq['prefix'] ?? '';
      final suffix = seq['suffix'] ?? '';
      
      return "$prefix$numStr$suffix";
    } catch (e) {
      debugPrint("Error in NumberingService: $e");
      // Fallback if everything fails
      return _getFallbackNumber(documentType);
    }
  }

  static String _getFallbackNumber(String type) {
    final prefix = typePrefixMap[type] ?? 'DOC';
    final now = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    return "$prefix-$now";
  }
}
