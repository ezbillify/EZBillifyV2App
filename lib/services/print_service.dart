import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

class PrintService {
  static Future<void> printDocument(Map<String, dynamic> data, String docType) async {
    try {
      debugPrint('PrintService: Attempting to print $docType');
      
      // Sanitize data before generation
      final fileName = _getDocFileName(data, docType);
      debugPrint('PrintService: Document filename: $fileName');

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          debugPrint('PrintService: onLayout triggered, converting HTML to PDF...');
          final html = await _generateA4Html(data, docType);
          return await Printing.convertHtml(
            format: format,
            html: html,
          );
        },
        name: fileName,
      );
      
      debugPrint('PrintService: Print layout successfully sent to system.');
    } catch (e, stack) {
      debugPrint('PrintService FATAL ERROR in printDocument: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  /// Download PDF to device storage and return the file path
  static Future<String?> downloadDocument(Map<String, dynamic> data, String docType) async {
    try {
      final pdfBytes = await _generatePdfBytes(data, docType);
      final fileName = _getDocFileName(data, docType);

      // Save to app documents directory
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      debugPrint('PrintService: PDF saved to ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('PrintService.downloadDocument error: $e');
      return null;
    }
  }

  /// Share PDF using share_plus (more reliable than printing package on some devices)
  static Future<void> shareDocument(BuildContext context, Map<String, dynamic> data, String docType) async {
    try {
      debugPrint('EZ_DEBUG: Starting shareDocument for $docType');
      
      // 1. Generate PDF
      final pdfBytes = await _generatePdfBytes(data, docType);
      debugPrint('EZ_DEBUG: PDF bytes generated (${pdfBytes.length} bytes)');

      // 2. Save to temporary file
      final dir = await getTemporaryDirectory();
      final fileName = _getDocFileName(data, docType);
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      debugPrint('EZ_DEBUG: PDF saved to: ${file.path}');

      // 3. Share the file
      final box = context.findRenderObject() as RenderBox?;
      final bounds = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      debugPrint('EZ_DEBUG: Calling Share.shareXFiles');
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Sharing $docType: ${data['invoice_number'] ?? data['document_number'] ?? ''}',
        sharePositionOrigin: bounds,
      );
      
      debugPrint('EZ_DEBUG: shareDocument completed');
    } catch (e) {
      debugPrint('EZ_DEBUG ERROR in shareDocument: $e');
      rethrow;
    }
  }

  /// Generate PDF bytes from data (reusable by print, download, share)
  static Future<Uint8List> _generatePdfBytes(Map<String, dynamic> data, String docType) async {
    final html = await _generateA4Html(data, docType);
    debugPrint('PrintService: Converting HTML to PDF...');
    debugPrint('PrintService: Converting HTML to PDF (format: A4)...');
    try {
      return await Printing.convertHtml(
        format: PdfPageFormat.a4,
        html: html,
      ).timeout(const Duration(seconds: 60), onTimeout: () {
        throw Exception('PDF generation timed out (60s)');
      });
    } catch (e) {
      debugPrint('PrintService ERROR: $e');
      rethrow;
    }
  }

  /// Get a consistent file name for the document
  static String _getDocFileName(Map<String, dynamic> data, String docType) {
    final num = data['invoice_number'] ?? data['document_number'] ?? data['id'] ?? 'doc';
    // Remove slashes and other characters that might break file paths or print spoolers
    final safeNum = num.toString().replaceAll(RegExp(r'[/\\]'), '-').replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '');
    return '${docType}_$safeNum.pdf';
  }

  static Future<String> _generateA4Html(Map<String, dynamic> data, String docType) async {
    String template = await rootBundle.loadString('assets/templates/a4_standard.html');

    // --- Enrich data: re-fetch full customer + items from Supabase ---
    debugPrint('PrintService: Enriching data from Supabase...');
    await _enrichPrintData(data, docType).timeout(const Duration(seconds: 5), onTimeout: () {
      debugPrint('PrintService: Enrichment timed out, using existing data');
    });

    // --- Fetch branch/company details ---
    debugPrint('PrintService: Fetching branch details...');
    final branch = await _fetchBranchDetails(data).timeout(const Duration(seconds: 5), onTimeout: () {
      return {};
    });

    // --- Data Preparation ---
    final allItems = (data['items'] as List?) ?? [];
    final totalAmount = _toDouble(data['total_amount'] ?? allItems.fold<double>(0, (sum, i) => sum + _toDouble(i['total_amount'])));
    final totalTax = _toDouble(data['tax_total'] ?? data['tax_total_amount'] ?? data['tax_amount'] ?? allItems.fold<double>(0, (sum, i) => sum + _toDouble(i['tax_amount'])));
    final subTotal = _toDouble(data['sub_total'] ?? data['subtotal_amount'] ?? (totalAmount - totalTax));

    // --- State / Tax Logic ---
    // --- State / Tax Logic (Matches web's stateCheck and placeOfSupply logic) ---
    final branchState = (branch['state'] ?? '').toString().trim();
    final customerStateRaw = data['customer']?['state']?.toString() ?? '';
    final customerState = customerStateRaw.isNotEmpty ? customerStateRaw : branchState;
    
    // Intra-state if states match (case-insensitive)
    final isIntraState = branchState.toLowerCase() == customerState.toLowerCase();
    
    // In GST, POS is the destination (customer) state. Only fallback to branch if customer state is unknown.
    final placeOfSupply = customerState.isNotEmpty ? customerState : branchState;

    // --- Document Type Logic ---
    final docTitle = _getDocTitle(docType);
    final docNumberLabel = _getDocNumberLabel(docType);
    final docNumber = data['invoice_number'] ?? data['quote_number'] ?? data['so_number'] ?? data['order_number'] ?? data['po_number'] ?? data['document_number'] ?? data['challan_number'] ?? data['credit_note_number'] ?? '-';
    
    // --- Document Subtitle ---
    final isEInvoiceActive = data['irn'] != null && data['einvoice_status'] != 'CANCELLED';
    final docSubtitle = isEInvoiceActive ? '(E-Invoice - Original For Recipient)' : '(Original For Recipient)';

    // --- Date formatting ---
    final dateStr = _formatDate(data['date'] ?? data['invoice_date']);
    final dueDateStr = _formatDate(data['due_date'] ?? data['expiry_date']);
    final dueDateLabel = (docType == 'quote' || docType == 'quotation') ? 'Valid Until:' : (docType == 'order' || docType == 'sales_order') ? 'Delivery Date:' : 'Due Date:';

    // --- Company Details ---
    final companyName = branch['company_name'] ?? branch['name'] ?? 'Your Company';
    final branchName = branch['name']?.toString() ?? '';
    final showBranchName = branchName.isNotEmpty && branchName != companyName;
    
    final companyAddress = branch['address']?.toString() ?? '';
    final companyGstin = (branch['gstin']?.toString() ?? branch['company_gstin']?.toString() ?? '').toUpperCase();
    final companyState = branch['state']?.toString() ?? '-';
    final companyEmail = branch['email']?.toString() ?? '';
    final companyPhone = _buildPhoneString(branch);
    final fssai = branch['fssai_lic_no']?.toString();

    // --- Logo ---
    final logoUrl = branch['logo_url']?.toString() ?? branch['logo']?.toString();
    final logoCell = (logoUrl != null && logoUrl.isNotEmpty)
        ? '<img src="$logoUrl" class="logo-img" alt="Logo" />'
        : '';

    // --- FSSAI Row ---
    final fssaiRow = (fssai != null && fssai.isNotEmpty)
        ? '<tr class="no-border"><td class="no-border" style="font-weight: bold; color: #059669; padding-right: 8pt;">FSSAI:</td><td class="no-border" style="font-weight: bold; color: #059669;">$fssai</td></tr>'
        : '';

    // --- Due Date Row ---
    final dueDateRow = dueDateStr.isNotEmpty
        ? '<tr><td class="label-text" style="padding: 4pt 0;">$dueDateLabel</td><td class="value-text" style="text-align: right; padding: 4pt 0;">$dueDateStr</td></tr>'
        : '';

    // --- Customer Details ---
    final customerName = data['customer']?['name']?.toString() ?? 'Walk-in Customer';
    final customerAddress = _normalizeAddress(data['customer']?['address']);
    final customerGstin = data['customer']?['gstin']?.toString() ?? '-';
    final customerStateDisplay = data['customer']?['state']?.toString() ?? '-';

    // --- Shipping ---
    final shippingAddress = data['shipping_address']?.toString() ?? '';
    final shippingContent = (shippingAddress.isNotEmpty && shippingAddress != customerAddress)
        ? '<div style="font-weight: bold; font-size: 10pt; text-transform: uppercase;">$customerName</div><div style="font-size: 9pt; white-space: pre-line; margin: 4pt 0;">$shippingAddress</div>'
        : '<div style="color: #94A3B8; font-style: italic; margin-top: 10pt;">Same as Billing Address</div>';

    // --- Tax Headers ---
    final taxHeaders = isIntraState
        ? '<th style="width: 40pt;">MRP</th><th style="width: 40pt;">Qty</th><th style="width: 50pt;">Rate</th><th style="width: 35pt;">Disc</th><th style="width: 55pt;">Taxable</th><th style="width: 45pt;">CGST</th><th style="width: 45pt;">SGST</th>'
        : '<th style="width: 40pt;">MRP</th><th style="width: 40pt;">Qty</th><th style="width: 55pt;">Rate</th><th style="width: 35pt;">Disc</th><th style="width: 60pt;">Taxable</th><th style="width: 55pt;">IGST</th>';

    // --- Items Rows ---
    final itemsHtml = StringBuffer();
    for (int i = 0; i < allItems.length; i++) {
      final item = allItems[i];
      final qty = _toDouble(item['quantity']);
      final unitPrice = _toDouble(item['unit_price']);
      final mrp = _toDouble(item['item']?['mrp'] ?? item['mrp']);
      final discount = _toDouble(item['discount'] ?? item['discount_amount']);
      final amount = _toDouble(item['total_amount'] ?? (qty * unitPrice));
      final taxAmt = _toDouble(item['tax_amount'] ?? 0);
      final taxable = _toDouble(item['taxable_amount'] ?? (amount - taxAmt));
      
      final hsnCode = item['hsn_code']?.toString() ?? item['item']?['hsn_code']?.toString() ?? '-';
      final itemName = item['item']?['print_name']?.toString() ?? item['description'] ?? item['item']?['name']?.toString() ?? 'N/A';
      final itemCode = item['item_code']?.toString() ?? '';
      final uom = item['uom']?.toString() ?? '';

      itemsHtml.write('<tr>');
      itemsHtml.write('<td class="text-center">${i + 1}</td>');
      itemsHtml.write('<td class="text-left"><div><strong>$itemName</strong></div>${itemCode.isNotEmpty ? '<div style="font-size: 7pt; color: #666;">Code: $itemCode</div>' : ''}</td>');
      itemsHtml.write('<td class="text-center">$hsnCode</td>');
      itemsHtml.write('<td class="text-center">${mrp > 0 ? mrp.toStringAsFixed(2) : '-'}</td>');
      itemsHtml.write('<td class="text-center"><strong>${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)}</strong> <br><span style="font-size: 7pt;">$uom</span></td>');
      itemsHtml.write('<td class="text-right">${unitPrice.toStringAsFixed(2)}</td>');
      itemsHtml.write('<td class="text-center">${discount > 0 ? discount.toStringAsFixed(2) : '-'}</td>');
      itemsHtml.write('<td class="text-right">${taxable.toStringAsFixed(2)}</td>');
      
      if (isIntraState) {
        itemsHtml.write('<td class="text-right">${(taxAmt / 2).toStringAsFixed(2)}</td>');
        itemsHtml.write('<td class="text-right">${(taxAmt / 2).toStringAsFixed(2)}</td>');
      } else {
        itemsHtml.write('<td class="text-right">${taxAmt.toStringAsFixed(2)}</td>');
      }
      
      itemsHtml.write('<td class="text-right"><strong>${amount.toStringAsFixed(2)}</strong></td>');
      itemsHtml.write('</tr>');
    }

    // --- Tax Summary Rows ---
    final taxSummaryHtml = StringBuffer();
    if (isIntraState) {
      taxSummaryHtml.write('<tr><td class="total-row-label">CGST</td><td class="total-row-value">₹${(totalTax / 2).toStringAsFixed(2)}</td></tr>');
      taxSummaryHtml.write('<tr><td class="total-row-label">SGST</td><td class="total-row-value">₹${(totalTax / 2).toStringAsFixed(2)}</td></tr>');
    } else {
      taxSummaryHtml.write('<tr><td class="total-row-label">IGST</td><td class="total-row-value">₹${totalTax.toStringAsFixed(2)}</td></tr>');
    }

    // --- Round Off ---
    final roundOff = _toDouble(data['round_off']);
    final roundOffRow = roundOff != 0
        ? '<tr><td class="total-row-label">Round Off</td><td class="total-row-value">${roundOff > 0 ? '+' : ''}${roundOff.toStringAsFixed(2)}</td></tr>'
        : '';

    // --- Tax Breakup ---
    final taxBreakupHtml = _buildTaxBreakup(allItems, isIntraState, subTotal, totalTax);

    // --- Bank Details ---
    final bankName = branch['bank_name']?.toString() ?? '-';
    final bankAcc = branch['account_number']?.toString() ?? '-';
    final bankIfsc = branch['ifsc_code']?.toString() ?? '-';
    final bankBranch = branch['bank_branch']?.toString() ?? branch['name']?.toString() ?? '-';

    // --- UPI QR ---
    final upiId = branch['upi_id']?.toString();
    final upiQrCell = (upiId != null && upiId.isNotEmpty)
        ? '<img src="https://quickchart.io/qr?size=150&text=${Uri.encodeComponent('upi://pay?pa=$upiId&pn=${branch['name'] ?? ''}&am=${totalAmount.toStringAsFixed(2)}&tn=$docNumber&cu=INR')}" class="qr-img" alt="QR" /><div class="qr-label">SCAN TO PAY<br>$upiId</div>'
        : '';

    // --- Terms ---
    final termsText = data['terms_conditions']?.toString() ?? data['notes']?.toString() ?? '';
    final termsContent = termsText.isNotEmpty
        ? termsText
        : '1. Goods once sold will not be taken back.\n2. Interest @18% p.a. for delayed payment.\n3. Warranty as per manufacturer terms.';

    // --- Amount in Words ---
    final amountInWords = _amountToWords(totalAmount);

    // --- Compliance Section (IRN & E-Way Bill) ---
    final irn = data['irn']?.toString();
    final ewayBill = data['eway_bill_no']?.toString();
    String complianceSection = '';
    
    if (isEInvoiceActive || (ewayBill != null && ewayBill.isNotEmpty)) {
      final irnQr = data['einvoice_qr_code'] ?? 'https://quickchart.io/qr?size=150&text=${Uri.encodeComponent(irn ?? '')}';
      final ackNo = data['einvoice_ack_no'] ?? '-';
      final ackDate = _formatDate(data['einvoice_ack_date']);
      
      complianceSection = '''
      <tr>
        <td colspan="2" style="border-top: var(--border); padding: 6pt; background: #f9fafb;">
          <table style="width: 100%;">
            <tr>
              <td style="width: 80pt; vertical-align: middle;">
                <div class="label-text" style="font-size: 6.5pt; margin-bottom: 2pt;">E-Invoice QR</div>
                <img src="$irnQr" style="width: 60pt; height: 60pt; border: 1px solid #ddd; padding: 2pt; background: white;" />
              </td>
              <td>
                <table style="font-size: 8pt;">
                  <tr><td style="color: #666; width: 80pt;">IRN:</td><td style="font-weight: bold; word-break: break-all; font-family: monospace; font-size: 7pt;">${irn ?? 'N/A'}</td></tr>
                  <tr><td style="color: #666;">Ack No & Date:</td><td style="font-weight: bold;">$ackNo | $ackDate</td></tr>
                  ${ewayBill != null && ewayBill.isNotEmpty ? '<tr><td style="color: #059669; font-weight: bold;">E-Way Bill No:</td><td style="font-weight: bold; color: #059669; font-size: 9pt;">$ewayBill</td></tr>' : ''}
                </table>
                <div style="margin-top: 4pt; font-size: 6pt; color: #999; font-style: italic;">
                  Certified that the particulars given above are true and correct and the amount indicated represents the price actually charged.
                </div>
              </td>
            </tr>
          </table>
        </td>
      </tr>
      ''';
    }

    // --- Replace all placeholders ---
    template = template
        .replaceAll('{{COMPANY_NAME}}', _escapeHtml(companyName))
        .replaceAll('{{BRANCH_LABEL_HTML}}', showBranchName ? '<span class="branch-subtext"> - ${_escapeHtml(branchName)}</span>' : '')
        .replaceAll('{{COMPANY_ADDRESS}}', _escapeHtml(companyAddress))
        .replaceAll('{{COMPANY_GSTIN}}', _escapeHtml(companyGstin))
        .replaceAll('{{COMPANY_STATE}}', _escapeHtml(companyState))
        .replaceAll('{{COMPANY_EMAIL}}', _escapeHtml(companyEmail))
        .replaceAll('{{COMPANY_PHONE}}', _escapeHtml(companyPhone))
        .replaceAll('{{FSSAI_ROW}}', fssaiRow)
        .replaceAll('{{LOGO_CELL}}', logoCell)
        .replaceAll('{{DOC_TITLE}}', docTitle)
        .replaceAll('{{DOC_SUBTITLE}}', docSubtitle)
        .replaceAll('{{DOC_NUMBER_LABEL}}', docNumberLabel)
        .replaceAll('{{DOC_NUMBER}}', _escapeHtml(docNumber.toString()))
        .replaceAll('{{DATE}}', dateStr)
        .replaceAll('{{DUE_DATE_ROW_NEW}}', dueDateRow)
        .replaceAll('{{POS}}', _escapeHtml(placeOfSupply))
        .replaceAll('{{CUSTOMER_NAME}}', _escapeHtml(customerName))
        .replaceAll('{{CUSTOMER_ADDRESS}}', _escapeHtml(customerAddress))
        .replaceAll('{{CUSTOMER_GSTIN}}', _escapeHtml(customerGstin))
        .replaceAll('{{CUSTOMER_STATE}}', _escapeHtml(customerStateDisplay))
        .replaceAll('{{SHIPPING_CONTENT_CLEAN}}', shippingContent)
        .replaceAll('{{TAX_COLUMNS_HEADER_NEW}}', taxHeaders)
        .replaceAll('{{ITEMS_ROWS_NATIVE}}', itemsHtml.toString())
        .replaceAll('{{AMOUNT_IN_WORDS}}', _escapeHtml(amountInWords))
        .replaceAll('{{SUBTOTAL}}', subTotal.toStringAsFixed(2))
        .replaceAll('{{TAX_SUMMARY_ROWS_NATIVE}}', taxSummaryHtml.toString())
        .replaceAll('{{ROUND_OFF_ROW_NEW}}', roundOffRow)
        .replaceAll('{{GRAND_TOTAL}}', totalAmount.toStringAsFixed(2))
        .replaceAll('{{BANK_NAME}}', _escapeHtml(bankName))
        .replaceAll('{{BANK_ACC}}', _escapeHtml(bankAcc))
        .replaceAll('{{BANK_IFSC}}', _escapeHtml(bankIfsc))
        .replaceAll('{{BANK_BRANCH}}', _escapeHtml(bankBranch))
        .replaceAll('{{UPI_QR_CELL_NEW}}', upiQrCell)
        .replaceAll('{{TERMS_CONTENT_CLEAN}}', termsContent)
        .replaceAll('{{TAX_BREAKUP_SECTION_NATIVE}}', taxBreakupHtml)
        .replaceAll('{{COMPLIANCE_SECTION_NATIVE}}', complianceSection)
        .replaceAll('{{COMPANY_NAME_SHORT}}', _escapeHtml(branch['name']?.toString() ?? companyName));

    return template;
  }

  // --- Helper: Normalize address (JSON object or string → readable string) ---
  // Matches web's normalizeAddress exactly
  static String _normalizeAddress(dynamic addr) {
    if (addr == null) return '';
    
    Map<String, dynamic>? addrMap;
    
    if (addr is Map) {
      addrMap = Map<String, dynamic>.from(addr);
    } else if (addr is String) {
      final trimmed = addr.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          addrMap = Map<String, dynamic>.from(jsonDecode(trimmed));
        } catch (_) {
          return addr;
        }
      } else {
        return addr;
      }
    }
    
    if (addrMap != null) {
      final parts = [
        addrMap['line1'],
        addrMap['line2'],
        addrMap['address'],
        addrMap['city'],
        addrMap['state'],
        addrMap['postal_code'],
        addrMap['pincode'],
        addrMap['zip']
      ].where((e) => e != null && e.toString().trim().isNotEmpty).toList();
      
      if (parts.isEmpty && addrMap.containsKey('full_address')) {
        return addrMap['full_address'].toString();
      }
      
      return parts.join('\n');
    }
    
    return addr.toString();
  }

  // --- Helper: Extract state from address (JSON object or string) ---
  static String _extractState(dynamic addr) {
    if (addr == null) return '';
    if (addr is Map) return addr['state']?.toString() ?? '';
    if (addr is String) {
      final trimmed = addr.trim();
      if (trimmed.startsWith('{')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) return decoded['state']?.toString() ?? '';
        } catch (_) {}
      }
    }
    return '';
  }

  // --- Helper: Enrich print data with full customer/vendor + items + branch ---
  // Mirrors the web's PrintPageContainer mergedData logic exactly
  static Future<void> _enrichPrintData(Map<String, dynamic> data, String docType) async {
    try {
      final supabase = Supabase.instance.client;

      // 1. Fetch full customer/vendor details and normalize address
      final customerId = data['customer_id']?.toString();
      final vendorId = data['vendor_id']?.toString();
      
      if (customerId != null && customerId.isNotEmpty) {
        final customerData = await supabase
            .from('customers')
            .select('name, billing_address, gstin, phone, email, shipping_addresses')
            .eq('id', customerId)
            .maybeSingle();
        if (customerData != null) {
          final normalized = Map<String, dynamic>.from(customerData);
          normalized['address'] = _normalizeAddress(customerData['billing_address'] ?? customerData['address']);
          if ((normalized['state'] == null || normalized['state'].toString().isEmpty) &&
              customerData['billing_address'] != null) {
            normalized['state'] = _extractState(customerData['billing_address']);
          }
          data['customer'] = normalized;
        }
      } else if (vendorId != null && vendorId.isNotEmpty) {
        final vendorData = await supabase
            .from('vendors')
            .select('name, billing_address, gstin, phone, email')
            .eq('id', vendorId)
            .maybeSingle();
        if (vendorData != null) {
          final normalized = Map<String, dynamic>.from(vendorData);
          normalized['address'] = _normalizeAddress(vendorData['billing_address'] ?? vendorData['address']);
          if ((normalized['state'] == null || normalized['state'].toString().isEmpty) &&
              vendorData['billing_address'] != null) {
            normalized['state'] = _extractState(vendorData['billing_address']);
          }
          data['customer'] = normalized; // Use 'customer' key for template parity
        }
      }

      // 2. Re-fetch items with full item details
      final docId = data['id']?.toString();
      if (docId != null && docId.isNotEmpty) {
        final tableInfo = _getItemsTableInfo(docType);
        if (tableInfo != null) {
          final items = await supabase
              .from(tableInfo['table']!)
              .select('*, item:items(name, sku, uom, print_name, mrp, hsn_code)')
              .eq(tableInfo['fk']!, docId);
          if (items.isNotEmpty) {
            data['items'] = List<Map<String, dynamic>>.from(items);
          }
        }
      }
    } catch (e) {
      debugPrint('PrintService._enrichPrintData error: $e');
    }
  }

  // --- Helper: Get items table name and FK for each doc type ---
  static Map<String, String>? _getItemsTableInfo(String docType) {
    switch (docType.toLowerCase()) {
      case 'invoice':
      case 'invoices':
        return {'table': 'sales_invoice_items', 'fk': 'invoice_id'};
      case 'quote':
      case 'quotation':
      case 'quotes':
        return {'table': 'sales_quotation_items', 'fk': 'quotation_id'};
      case 'order':
      case 'sales_order':
      case 'sales_orders':
        return {'table': 'sales_order_items', 'fk': 'order_id'};
      case 'dc':
      case 'delivery_challan':
      case 'delivery_challans':
        return {'table': 'delivery_challan_items', 'fk': 'challan_id'};
      case 'credit_note':
      case 'credit_notes':
        return {'table': 'credit_note_items', 'fk': 'credit_note_id'};
      case 'bill':
      case 'purchase_bill':
        return {'table': 'purchase_bill_items', 'fk': 'bill_id'};
      case 'purchase_order':
      case 'po':
        return {'table': 'purchase_order_items', 'fk': 'po_id'};
      case 'grn':
      case 'purchase_grn':
        return {'table': 'purchase_grn_items', 'fk': 'grn_id'};
      case 'debit_note':
      case 'purchase_debit_note':
        return {'table': 'purchase_debit_note_items', 'fk': 'debit_note_id'};
      case 'rfq':
      case 'purchase_rfq':
        return {'table': 'purchase_rfq_items', 'fk': 'rfq_id'};
      default:
        return null;
    }
  }

  // --- Helper: Fetch branch details from Supabase ---
  // Mirrors the web API route logic: fetches branch with bank_accounts, 
  // then merges default bank account fields into branch (bank_name, account_number, etc.)
  static Future<Map<String, dynamic>> _fetchBranchDetails(Map<String, dynamic> data) async {
    try {
      final supabase = Supabase.instance.client;
      Map<String, dynamic>? branchData;
      String? companyId;

      // STRATEGY 1: Use branch_id from the document (most reliable)
      final branchId = data['branch_id']?.toString();
      if (branchId != null && branchId.isNotEmpty) {
        branchData = await supabase
            .from('branches')
            .select('*, company:companies(*)')
            .eq('id', branchId)
            .maybeSingle();
        if (branchData != null) {
          companyId = branchData['company_id']?.toString();
          debugPrint('PrintService: Fetched branch by branch_id: ${branchData['name']}');
        }
      }

      // STRATEGY 2: Use company_id from the document
      if (branchData == null) {
        companyId = data['company_id']?.toString();
        if (companyId != null && companyId.isNotEmpty) {
          final branches = await supabase
              .from('branches')
              .select('*, company:companies(*)')
              .eq('company_id', companyId)
              .order('is_primary', ascending: false)
              .limit(1);
          if (branches.isNotEmpty) {
            branchData = Map<String, dynamic>.from(branches[0]);
            debugPrint('PrintService: Fetched branch by company_id: ${branchData['name']}');
          }
        }
      }

      // STRATEGY 3: Fallback - lookup via current user
      if (branchData == null) {
        final user = supabase.auth.currentUser;
        if (user == null) return {};

        final profile = await supabase.from('users').select('company_id').eq('auth_id', user.id).maybeSingle();
        if (profile == null) return {};

        companyId = profile['company_id']?.toString();
        final fallbackBranches = await supabase
            .from('branches')
            .select('*, company:companies(*)')
            .eq('company_id', companyId!)
            .order('is_primary', ascending: false)
            .limit(1);

        if (fallbackBranches.isNotEmpty) {
          branchData = Map<String, dynamic>.from(fallbackBranches[0]);
          debugPrint('PrintService: Fetched branch via user fallback: ${branchData['name']}');
        }
      }

      if (branchData == null) return {};

      final b = Map<String, dynamic>.from(branchData);

      // --- Merge company details (matches web's mergedData.branch logic) ---
      final company = b['company'];
      if (company != null && company is Map) {
        b['company_name'] = company['name'] ?? b['name'];
        b['company_gstin'] = company['gstin'] ?? b['gstin'];
        b['company_address'] = company['address'] ?? b['address'];
        
        // Fallback from company if branch doesn't have them
        if (b['phone'] == null || b['phone'].toString().isEmpty) b['phone'] = company['phone'];
        if (b['secondary_phone'] == null || b['secondary_phone'].toString().isEmpty) b['secondary_phone'] = company['secondary_phone'];
        if (b['email'] == null || b['email'].toString().isEmpty) b['email'] = company['email'];
        if (b['gstin'] == null || b['gstin'].toString().isEmpty) b['gstin'] = company['gstin'];
        if (b['address'] == null || b['address'].toString().isEmpty) b['address'] = company['address'];
        if (b['fssai_lic_no'] == null || b['fssai_lic_no'].toString().isEmpty) b['fssai_lic_no'] = company['fssai_lic_no'];
      } else {
        b['company_name'] = b['name'] ?? 'Your Company';
        b['company_gstin'] = b['gstin'];
        b['company_address'] = b['address'];
      }

      // --- Normalize branch address ---
      b['address'] = _normalizeAddress(b['address']);

      // --- Fetch and merge bank account details ---
      // This matches the web API route logic exactly:
      // 1. Try branch-level bank_accounts (default first)
      // 2. Fallback to company-level bank_accounts
      bool bankInfoSet = false;

      if (companyId != null) {
        // Fetch bank accounts for this branch
        final branchBankAccounts = await supabase
            .from('bank_accounts')
            .select('*')
            .eq('branch_id', b['id'])
            .order('is_default', ascending: false);

        if (branchBankAccounts.isNotEmpty) {
          final defaultAcc = branchBankAccounts[0]; // is_default DESC = default first
          b['bank_name'] = defaultAcc['bank_name'];
          b['account_number'] = defaultAcc['account_number'];
          b['ifsc_code'] = defaultAcc['ifsc_code'];
          b['bank_branch'] = defaultAcc['branch_name'];
          b['upi_id'] = defaultAcc['upi_id'];
          bankInfoSet = true;
          debugPrint('PrintService: Bank from branch: ${b['bank_name']}');
        }

        // Fallback: Company-level default bank account
        if (!bankInfoSet) {
          final companyBankAccounts = await supabase
              .from('bank_accounts')
              .select('*')
              .eq('company_id', companyId)
              .eq('is_default', true)
              .maybeSingle();

          if (companyBankAccounts != null) {
            b['bank_name'] = companyBankAccounts['bank_name'];
            b['account_number'] = companyBankAccounts['account_number'];
            b['ifsc_code'] = companyBankAccounts['ifsc_code'];
            b['bank_branch'] = companyBankAccounts['branch_name'];
            b['upi_id'] = companyBankAccounts['upi_id'];
            debugPrint('PrintService: Bank from company default: ${b['bank_name']}');
          }
        }
      }

      debugPrint('PrintService: Final branch data - name: ${b['name']}, gstin: ${b['gstin']}, state: ${b['state']}, bank: ${b['bank_name']}');
      return b;
    } catch (e) {
      debugPrint('PrintService._fetchBranchDetails error: $e');
      return {};
    }
  }

  // --- Helper: Document title ---
  static String _getDocTitle(String docType) {
    switch (docType.toLowerCase()) {
      case 'invoice':
      case 'invoices':
        return 'TAX INVOICE';
      case 'quote':
      case 'quotation':
      case 'quotes':
        return 'QUOTATION';
      case 'order':
      case 'sales_order':
      case 'sales_orders':
        return 'SALES ORDER';
      case 'purchase_order':
      case 'po':
        return 'PURCHASE ORDER';
      case 'credit_note':
      case 'credit_notes':
        return 'CREDIT NOTE';
      case 'dc':
      case 'delivery_challan':
      case 'delivery_challans':
        return 'DELIVERY CHALLAN';
      case 'payment':
        return 'PAYMENT RECEIPT';
      case 'bill':
      case 'purchase_bill':
        return 'PURCHASE BILL';
      case 'grn':
      case 'purchase_grn':
        return 'GOODS RECEIPT NOTE';
      case 'debit_note':
      case 'purchase_debit_note':
        return 'DEBIT NOTE';
      case 'rfq':
      case 'purchase_rfq':
        return 'REQUEST FOR QUOTATION';
      default:
        return 'TAX INVOICE';
    }
  }

  // --- Helper: Document number label ---
  static String _getDocNumberLabel(String docType) {
    switch (docType.toLowerCase()) {
      case 'quote':
      case 'quotation':
        return 'Quote No:';
      case 'order':
      case 'sales_order':
        return 'Order No:';
      case 'purchase_order':
      case 'po':
        return 'PO No:';
      case 'credit_note':
        return 'CN No:';
      case 'dc':
      case 'delivery_challan':
        return 'Challan No:';
      case 'payment':
        return 'Payment No:';
      case 'bill':
      case 'purchase_bill':
        return 'Bill No:';
      case 'grn':
      case 'purchase_grn':
        return 'GRN No:';
      case 'debit_note':
      case 'purchase_debit_note':
        return 'DN No:';
      case 'rfq':
      case 'purchase_rfq':
        return 'RFQ No:';
      default:
        return 'Invoice No:';
    }
  }

  // --- Helper: Format date ---
  static String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '';
    try {
      final date = DateTime.parse(dateValue.toString());
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return dateValue.toString();
    }
  }

  // --- Helper: Build phone string ---
  static String _buildPhoneString(Map<String, dynamic> branch) {
    final phone = branch['phone']?.toString() ?? branch['company']?['phone']?.toString() ?? '';
    final secondary = branch['secondary_phone']?.toString() ?? branch['company']?['secondary_phone']?.toString() ?? '';
    if (phone.isEmpty) return '-';
    if (secondary.isNotEmpty) return '$phone, $secondary';
    return phone;
  }

  // --- Helper: Tax Breakup ---
  static String _buildTaxBreakup(List items, bool isIntraState, double subTotal, double totalTax) {
    // Group items by HSN + tax rate
    final taxGroups = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final hsn = item['hsn_code']?.toString() ?? item['item']?['hsn_code']?.toString() ?? 'N/A';
      final rate = _toDouble(item['tax_rate']);
      final taxable = _toDouble(item['taxable_amount'] ?? (_toDouble(item['total_amount']) - _toDouble(item['tax_amount'])));
      final taxAmt = _toDouble(item['tax_amount']);

      final key = '$hsn-$rate';
      if (!taxGroups.containsKey(key)) {
        taxGroups[key] = {'hsn': hsn, 'rate': rate, 'taxable': 0.0, 'taxAmt': 0.0};
      }
      taxGroups[key]!['taxable'] = (taxGroups[key]!['taxable'] as double) + taxable;
      taxGroups[key]!['taxAmt'] = (taxGroups[key]!['taxAmt'] as double) + taxAmt;
    }

    if (taxGroups.isEmpty) return '';

    final rows = StringBuffer();
    for (final row in taxGroups.values) {
      final hsn = row['hsn'];
      final rate = row['rate'] as double;
      final taxable = row['taxable'] as double;
      final taxAmt = row['taxAmt'] as double;

      rows.write('<tr>');
      rows.write('<td style="border: 1px solid #000; padding: 3pt;">$hsn</td>');
      rows.write('<td style="border: 1px solid #000; padding: 3pt; text-align: right;">${taxable.toStringAsFixed(2)}</td>');
      if (isIntraState) {
        rows.write('<td style="border: 1px solid #000; padding: 3pt; text-align: center;">${(rate / 2).toStringAsFixed(1)}%</td>');
        rows.write('<td style="border: 1px solid #000; padding: 3pt; text-align: right;">${(taxAmt / 2).toStringAsFixed(2)}</td>');
        rows.write('<td style="border: 1px solid #000; padding: 3pt; text-align: center;">${(rate / 2).toStringAsFixed(1)}%</td>');
        rows.write('<td style="border: 1px solid #000; padding: 3pt; text-align: right;">${(taxAmt / 2).toStringAsFixed(2)}</td>');
      } else {
        rows.write('<td style="border: 1px solid #000; padding: 3pt; text-align: center;">${rate.toStringAsFixed(1)}%</td>');
        rows.write('<td style="border: 1px solid #000; padding: 3pt; text-align: right;">${taxAmt.toStringAsFixed(2)}</td>');
      }
      rows.write('<td style="border: 1px solid #000; padding: 3pt; text-align: right;">${taxAmt.toStringAsFixed(2)}</td>');
      rows.write('</tr>');
    }

    // Totals row (cleaner breakdown)
    rows.write('<tr style="background: #f3f4f6; font-weight: bold;">');
    rows.write('<td style="border: 1px solid #000; padding: 3pt;">Total</td>');
    rows.write('<td style="border: 1px solid #000; padding: 3pt; text-align: right;">${subTotal.toStringAsFixed(2)}</td>');
    if (isIntraState) {
      rows.write('<td style="border: 1px solid #000; padding: 3pt; text-align: center;">-</td>');
      rows.write('<td style="border: 1px solid #000; padding: 3pt; text-align: right;">${(totalTax / 2).toStringAsFixed(2)}</td>');
      rows.write('<td style="border: 1px solid #000; padding: 3pt; text-align: center;">-</td>');
      rows.write('<td style="border: 1px solid #000; padding: 3pt; text-align: right;">${(totalTax / 2).toStringAsFixed(2)}</td>');
    } else {
      rows.write('<td style="border: 1px solid #000; padding: 3pt; text-align: center;">-</td>');
      rows.write('<td style="border: 1px solid #000; padding: 3pt; text-align: right;">${totalTax.toStringAsFixed(2)}</td>');
    }
    rows.write('<td style="border: 1px solid #000; padding: 3pt; text-align: right;">${totalTax.toStringAsFixed(2)}</td>');
    rows.write('</tr>');

    final headerCols = isIntraState
        ? '<th style="border: 1px solid #000; padding: 3pt; text-align: center;">CGST Rate</th><th style="border: 1px solid #000; padding: 3pt; text-align: right;">CGST Amt</th><th style="border: 1px solid #000; padding: 3pt; text-align: center;">SGST Rate</th><th style="border: 1px solid #000; padding: 3pt; text-align: right;">SGST Amt</th>'
        : '<th style="border: 1px solid #000; padding: 3pt; text-align: center;">IGST Rate</th><th style="border: 1px solid #000; padding: 3pt; text-align: right;">IGST Amt</th>';

    return '''
    <table style="width: 100%; font-size: 8pt; border-collapse: collapse;">
      <thead>
        <tr style="background: #f9fafb; font-weight: bold;">
          <th style="border: 1px solid #000; padding: 3pt; text-align: left;">HSN/SAC</th>
          <th style="border: 1px solid #000; padding: 3pt; text-align: right;">Taxable Value</th>
          $headerCols
          <th style="border: 1px solid #000; padding: 3pt; text-align: right;">Total Tax</th>
        </tr>
      </thead>
      <tbody>
        ${rows.toString()}
      </tbody>
    </table>
    ''';
  }

  // --- Helper: Number to double ---
  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  // --- Helper: Escape HTML ---
  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  // --- Helper: Amount in Words ---
  static String _amountToWords(double amount) {
    if (amount == 0 || amount.isNaN) return 'Zero';
    try {
      final rounded = amount.round();
      return 'Indian Rupees ${_numberToWords(rounded)}';
    } catch (_) {
      return 'Indian Rupees ${amount.toStringAsFixed(0)} Only';
    }
  }

  static String _numberToWords(int number) {
    if (number == 0) return 'Zero';
    if (number < 0) return 'Minus ${_numberToWords(-number)}';

    final ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
                   'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
                   'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String words = '';

    if (number >= 10000000) {
      words += '${_numberToWords(number ~/ 10000000)} Crore ';
      number %= 10000000;
    }
    if (number >= 100000) {
      words += '${_numberToWords(number ~/ 100000)} Lakh ';
      number %= 100000;
    }
    if (number >= 1000) {
      words += '${_numberToWords(number ~/ 1000)} Thousand ';
      number %= 1000;
    }
    if (number >= 100) {
      words += '${ones[number ~/ 100]} Hundred ';
      number %= 100;
    }
    if (number > 0) {
      if (words.isNotEmpty) words += 'and ';
      if (number < 20) {
        words += ones[number];
      } else {
        words += tens[number ~/ 10];
        if (number % 10 > 0) {
          words += ' ${ones[number % 10]}';
        }
      }
    }

    return words.trim();
  }
}
