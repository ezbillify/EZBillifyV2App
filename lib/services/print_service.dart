import 'dart:io';
import 'package:ez_billify_v2_app/services/status_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'print_settings_service.dart';
import 'auth_service.dart';
import 'settings_service.dart';

import '../core/utils/number_to_words.dart';

class PrintService {
  static Future<bool> checkPrinterStatus() async {
    try {
      final config = await PrintSettingsService.getPrinterConfig();
      final type = config['type'] ?? 'network';
      final ip = config['ip'];
      final btAddress = config['btAddress'];

      if (type == 'bluetooth' && btAddress != null) {
        final device = BluetoothDevice.fromId(btAddress);
        // Fast connection probe
        await device.connect(timeout: const Duration(seconds: 4), autoConnect: false);
        await device.disconnect().catchError((_) {});
        return true;
      } else if (type == 'network' && ip != null && ip.isNotEmpty) {
        final socket = await Socket.connect(ip, 9100, timeout: const Duration(seconds: 2));
        await socket.close();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('PrintService: Status check failed: $e');
      return false;
    }
  }

  static Future<void> printDocument(Map<String, dynamic> data, String docType, [BuildContext? context]) async {
    try {
      debugPrint('PrintService: Starting direct hardware print for $docType');
      
      final printerConfig = await PrintSettingsService.getPrinterConfig();
      final printerType = printerConfig['type'] ?? 'network';
      final ip = printerConfig['ip'];
      final btAddress = printerConfig['btAddress'];

      // Check if configured
      bool isConfigured = (printerType == 'bluetooth' && btAddress != null) || 
                          (printerType == 'network' && ip != null && ip.isNotEmpty);

      if (!isConfigured) {
        if (context != null && context.mounted) {
          StatusService.show(context, 'Printer not configured. Please go to Settings > Printer.', backgroundColor: Colors.orange);
        }
        return;
      }

      // Show "Connecting" status
      if (context != null && context.mounted) {
        StatusService.show(context, 'Connecting to ${printerType.toUpperCase()} printer...', isLoading: true, persistent: true);
      }

      // Ensure we have all data
      final richData = await _fetchMissingPrintData(data);

      // Perform Printing
      await _printDirectlyToThermal(richData, docType, printerConfig);

      // Show "Success"
      if (context != null && context.mounted) {
        StatusService.show(context, 'Print job sent successfully!', backgroundColor: Colors.green);
      }

    } catch (e, stack) {
      debugPrint('PrintService FATAL ERROR: $e');
      debugPrint(stack.toString());
      
      if (context != null && context.mounted) {
        StatusService.show(context, 'Print Failed: ${e.toString().replaceAll('Exception:', '')}', backgroundColor: Colors.red);
      }
    }
  }

  static Future<Map<String, dynamic>> _fetchMissingPrintData(Map<String, dynamic> data) async {
    try {
      debugPrint('PrintService: Fetching missing data for print (Timeout enabled)...');
      final auth = AuthService();
      final user = await auth.getCurrentUser().timeout(const Duration(seconds: 3), onTimeout: () => null);
      
      final String companyId = data['company_id'] ?? user?.companyId ?? '';
      if (companyId.isEmpty) {
        debugPrint('PrintService: No companyId found, returning raw data');
        return data;
      }
      
      final branchId = data['branch_id'] ?? user?.branchId;
      final settings = SettingsService();

      // Parallel fetch with timeouts to prevent UI hang
      final results = await Future.wait([
        settings.getCompanyProfile(companyId).timeout(const Duration(seconds: 4), onTimeout: () => {}),
        (branchId != null ? settings.getBranches(companyId) : Future.value([])).timeout(const Duration(seconds: 4), onTimeout: () => []),
      ]);

      final company = results[0] as Map<String, dynamic>;
      final branches = results[1] as List<Map<String, dynamic>>;
      
      Map<String, dynamic>? branch;
      if (branchId != null && branches.isNotEmpty) {
        branch = branches.firstWhere((b) => b['id'].toString() == branchId.toString(), orElse: () => branches[0]);
      }

      // Fetch Bank Account (UPI)
      Map<String, dynamic>? bankAccount;
      try {
        final query = Supabase.instance.client.from('bank_accounts').select('*');
        if (branchId != null) {
          bankAccount = await query.eq('branch_id', branchId).eq('is_default', true).maybeSingle().timeout(const Duration(seconds: 3), onTimeout: () => null);
        }
        if (bankAccount == null) {
          bankAccount = await query.eq('company_id', companyId).eq('is_default', true).maybeSingle().timeout(const Duration(seconds: 3), onTimeout: () => null);
        }
      } catch (e) {
        debugPrint('PrintService: Bank fetch error: $e');
      }

      final activeData = branch ?? company;
      final Map<String, dynamic> branding = (activeData['branding'] is Map) ? Map<String, dynamic>.from(activeData['branding']) : 
                                            (company['branding'] is Map) ? Map<String, dynamic>.from(company['branding']) : {};
      
      dynamic addressRaw = activeData['address'] ?? company['address'];
      if (addressRaw is String && addressRaw.startsWith('{')) {
        try { addressRaw = json.decode(addressRaw); } catch (_) {}
      }

      String? _val(dynamic v) => (v != null && v.toString().trim().isNotEmpty && v.toString() != 'null') ? v.toString().trim() : null;

      return {
        ...data,
        'company_name': _val(company['name']) ?? _val(company['company_name']) ?? _val(data['company_name']) ?? 'EZBILLIFY SHOP',
        'branch_name': (branch != null && branch['name'] != null && 
                        branch['name'].toString().trim().toUpperCase() != (_val(company['name']) ?? '').toString().trim().toUpperCase()) 
                       ? _val(branch['name']) : null,
        'company_address': addressRaw,
        'company_gstin': _val(activeData['gstin']) ?? _val(activeData['gst_no']) ?? _val(company['gstin']) ?? _val(data['company_gstin']) ?? '',
        'company_phone': _val(activeData['phone']) ?? _val(company['phone']) ?? _val(data['company_phone']) ?? '',
        'thermal_logo': _val(activeData['thermal_logo_url']) ?? _val(company['thermal_logo_url']) ?? _val(activeData['logo_url']) ?? _val(company['logo_url']),
        'upi_id': _val(bankAccount?['upi_id']) ?? _val(branding['upi_id']) ?? _val(branding['upi']) ?? _val(activeData['upi_id']) ?? _val(activeData['upi']) ?? _val(company['upi_id']) ?? _val(company['upi']) ?? _val(data['upi_id']),
        'fssai_lic_no': _val(activeData['fssai_lic_no']) ?? _val(activeData['lic_no']) ?? _val(activeData['license_no']) ?? _val(activeData['fssai']) ?? _val(activeData['fssai_no']) ?? _val(company['fssai_lic_no']) ?? _val(company['lic_no']) ?? '',
        'bank_name': _val(bankAccount?['bank_name']) ?? '-',
        'bank_acc': _val(bankAccount?['account_number']) ?? '-',
        'bank_ifsc': _val(bankAccount?['ifsc_code']) ?? '-',
        'bank_branch': _val(bankAccount?['branch_name']) ?? '-',
      };
    } catch (e) {
      debugPrint('PrintService Data Fetch Handled Error: $e');
      return data;
    }
  }

  static bool _isPrinting = false;

  static Future<void> _printDirectlyToThermal(
    Map<String, dynamic> data, 
    String docType, 
    Map<String, String?> config
  ) async {
    if (_isPrinting) {
      debugPrint('PrintService: Another print job is in progress. Ignoring request.');
      return;
    }
    _isPrinting = true;

    final paperSize = config['paperSize'] ?? '80mm';
    final printerType = config['type'] ?? 'network';
    final is58mm = paperSize == '58mm';
    final ip = config['ip'];
    final btAddress = config['btAddress'];

    dynamic transport;
    BluetoothCharacteristic? writeChar;
    
    try {
      // 1. Connection with Retry Logic
      int retryCount = 0;
      const int maxRetries = 2;
      
      while (retryCount <= maxRetries) {
        try {
          if (printerType == 'bluetooth' && btAddress != null) {
            debugPrint('PrintService: Connecting to Bluetooth printer (Attempt ${retryCount + 1})...');
            final device = BluetoothDevice.fromId(btAddress);
            
            BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
            if (state != BluetoothAdapterState.on) throw Exception("Bluetooth adapter is not ON ($state)");

            // Reconnect if needed
            final connectionState = await device.connectionState.first;
            
            // Proactive disconnect on retry to clear stale stack
            if (retryCount > 0 || (connectionState != BluetoothConnectionState.connected && connectionState != BluetoothConnectionState.disconnected)) {
               await device.disconnect().catchError((_) {});
               await Future.delayed(const Duration(milliseconds: 300));
            }

            if (await device.connectionState.first != BluetoothConnectionState.connected) {
              await device.connect(
                timeout: const Duration(seconds: 10), 
                autoConnect: false,
              ).catchError((e) => throw Exception("Connection failed: $e"));
            }
            
            // MTU Negotiation (Crucial for stability on Android)
            if (Platform.isAndroid) {
              await device.requestMtu(512).timeout(const Duration(seconds: 2)).catchError((_) => 0);
            }

            final services = await device.discoverServices().timeout(const Duration(seconds: 7));
            for (var service in services) {
              for (var char in service.characteristics) {
                if (char.properties.write || char.properties.writeWithoutResponse) {
                  writeChar = char; break;
                }
              }
              if (writeChar != null) break;
            }
            transport = device;
          } else if (printerType == 'network' && ip != null) {
            debugPrint('PrintService: Connecting to Network printer at $ip (Attempt ${retryCount + 1})...');
            transport = await Socket.connect(ip, 9100, timeout: const Duration(seconds: 5));
          }
          
          if (transport != null && (printerType != 'bluetooth' || writeChar != null)) break; // Success
        } catch (e) {
          debugPrint('PrintService: Connection attempt ${retryCount + 1} failed: $e');
          retryCount++;
          if (retryCount > maxRetries) rethrow;
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (transport == null || (printerType == 'bluetooth' && writeChar == null)) {
        throw Exception("Could not establish connection to printer.");
      }

      final profile = await CapabilityProfile.load();
      final generator = Generator(is58mm ? PaperSize.mm58 : PaperSize.mm80, profile);

      // --- PRINT CONTENT GENERATION ---
      debugPrint('PrintService: Formatting document...');
      List<int> bytes = [];
      bytes += generator.reset();
      
      // 1. Logo
      final logoUrl = data['thermal_logo']?.toString();
      if (logoUrl != null && logoUrl.startsWith('http')) {
        try {
          final response = await http.get(Uri.parse(logoUrl)).timeout(const Duration(seconds: 4));
          final imgObj = img.decodeImage(response.bodyBytes);
          if (imgObj != null) {
             bytes += generator.image(img.grayscale(img.copyResize(imgObj, width: is58mm ? 180 : 250)), align: PosAlign.center);
          }
        } catch (e) { debugPrint('Logo error: $e'); }
      }

      // 2. Header
      bytes += generator.text((data['company_name'] ?? '').toString().toUpperCase(), 
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1, fontType: PosFontType.fontA));
      
      final branchName = data['branch_name']?.toString();
      if (branchName != null && branchName.isNotEmpty) {
        bytes += generator.text(branchName.toUpperCase(), styles: const PosStyles(align: PosAlign.center, bold: true, fontType: PosFontType.fontA));
      }
      
      final addressRaw = data['company_address'];
      String addressStr = '';
      if (addressRaw is Map) {
        final line1 = addressRaw['line1'] ?? addressRaw['address_line_1'] ?? '';
        final city = addressRaw['city'] ?? '';
        final state = addressRaw['state'] ?? '';
        final pincode = addressRaw['pincode'] ?? '';
        addressStr = [line1, city, state, pincode].where((s) => s != null && s.toString().isNotEmpty).join(', ');
      } else {
        addressStr = addressRaw?.toString() ?? '';
      }
      
      if (addressStr.isNotEmpty) bytes += generator.text(addressStr, styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontA));
      
      final gstin = data['company_gstin']?.toString() ?? '';
      if (gstin.isNotEmpty) bytes += generator.text('GSTIN: $gstin', styles: const PosStyles(align: PosAlign.center, bold: true, fontType: PosFontType.fontA));
      
      final fssai = data['fssai_lic_no']?.toString() ?? '';
      if (fssai.isNotEmpty && fssai != 'null' && fssai != '-') {
        bytes += generator.text('FSSAI: $fssai', styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontA));
      }

      final phone = data['company_phone']?.toString() ?? '';
      if (phone.isNotEmpty) bytes += generator.text('PH: $phone', styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontA));
      
      bytes += generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontA));
      bytes += generator.text((docType.toUpperCase()), styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, fontType: PosFontType.fontA));
      
      bytes += generator.row([
        PosColumn(text: 'NO: ${(data['invoice_number'] ?? data['bill_number'] ?? '-').toString()}', width: 7, styles: const PosStyles(fontType: PosFontType.fontA)),
        PosColumn(text: _formatDate(data['date']?.toString()), width: 5, styles: const PosStyles(align: PosAlign.right, fontType: PosFontType.fontA)),
      ]);
      
      final customer = data['customer'];
      final custName = (customer is Map ? customer['name'] : (customer ?? "WALK-IN")).toString().toUpperCase();
      bytes += generator.text('CUST: $custName', styles: const PosStyles(bold: true, fontType: PosFontType.fontA));
      bytes += generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontA));
      
      // 3. Items
      final items = data['items'] as List? ?? [];
      Map<String, Map<String, double>> taxGroups = {};
      
      for (var item in items) {
        final name = (item['item'] is Map ? item['item']['name'] : (item['name'] ?? 'N/A')).toString().toUpperCase();
        final hsn = (item['hsn_code'] ?? (item['item'] is Map ? item['item']['hsn_code'] : null))?.toString();
        final qty = (item['quantity'] ?? 1).toDouble();
        final total = (item['total_amount'] ?? 0).toDouble();
        
        final rate = (item['tax_rate'] ?? 0).toDouble();
        final taxAmt = (item['tax_amount'] ?? 0).toDouble();
        final taxable = total - taxAmt;

        if (rate > 0) {
          final key = rate.toStringAsFixed(0);
          if (!taxGroups.containsKey(key)) taxGroups[key] = {'rate': rate, 'taxable': 0, 'taxAmt': 0};
          taxGroups[key]!['taxable'] = (taxGroups[key]!['taxable'] ?? 0) + taxable;
          taxGroups[key]!['taxAmt'] = (taxGroups[key]!['taxAmt'] ?? 0) + taxAmt;
        }

        bytes += generator.text(name, styles: const PosStyles(bold: true, fontType: PosFontType.fontA));
        if (hsn != null && hsn != 'null' && hsn.isNotEmpty) bytes += generator.text('HSN: $hsn', styles: const PosStyles(fontType: PosFontType.fontA));
        
        bytes += generator.row([
          PosColumn(text: 'Qty: ${qty.toStringAsFixed(0)}', width: 6, styles: const PosStyles(fontType: PosFontType.fontA)),
          PosColumn(text: 'Rs. ${total.toStringAsFixed(2)}', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true, fontType: PosFontType.fontA)),
        ]);
        bytes += generator.emptyLines(1);
      }
      bytes += generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontA));

      // 4. Totals
      final totalAmt = (data['total_amount'] ?? 0).toDouble().toStringAsFixed(2);
      final subTotalValue = (data['sub_total'] ?? 0).toDouble();
      final taxTotalValue = (data['tax_total'] ?? data['total_tax'] ?? 0).toDouble();
      
      bytes += generator.row([
        PosColumn(text: 'SUBTOTAL', width: 6, styles: const PosStyles(fontType: PosFontType.fontA)),
        PosColumn(text: 'Rs. ${subTotalValue.toStringAsFixed(2)}', width: 6, styles: const PosStyles(align: PosAlign.right, fontType: PosFontType.fontA)),
      ]);
      
      if (taxTotalValue > 0) {
        bytes += generator.row([
          PosColumn(text: 'TAX TOTAL', width: 6, styles: const PosStyles(fontType: PosFontType.fontA)),
          PosColumn(text: 'Rs. ${taxTotalValue.toStringAsFixed(2)}', width: 6, styles: const PosStyles(align: PosAlign.right, fontType: PosFontType.fontA)),
        ]);
      }
      
      bytes += generator.row([
        PosColumn(text: 'GRAND TOTAL', width: 7, styles: const PosStyles(bold: true, height: PosTextSize.size2, fontType: PosFontType.fontA)),
        PosColumn(text: 'Rs. $totalAmt', width: 5, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2, fontType: PosFontType.fontA)),
      ]);

      // 4.5 Amount in Words
      final grandTotalValue = (data['total_amount'] ?? 0).toDouble();
      final amountInWords = NumberToWords.convert(grandTotalValue);
      bytes += generator.text(amountInWords.toUpperCase(), styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB));

      // 5. Tax Breakup
      if (taxGroups.isNotEmpty) {
        bytes += generator.emptyLines(1);
        bytes += generator.text('TAX BREAKUP', styles: const PosStyles(align: PosAlign.center, bold: true, fontType: PosFontType.fontA));
        bytes += generator.row([
          PosColumn(text: 'TAX%', width: 3, styles: const PosStyles(bold: true, fontType: PosFontType.fontA)),
          PosColumn(text: 'TAXABLE', width: 5, styles: const PosStyles(align: PosAlign.right, bold: true, fontType: PosFontType.fontA)),
          PosColumn(text: 'AMT', width: 4, styles: const PosStyles(align: PosAlign.right, bold: true, fontType: PosFontType.fontA)),
        ]);
        taxGroups.forEach((key, val) {
          bytes += generator.row([
            PosColumn(text: '${val['rate']?.toStringAsFixed(0)}%', width: 3, styles: const PosStyles(fontType: PosFontType.fontA)),
            PosColumn(text: val['taxable']!.toStringAsFixed(2), width: 5, styles: const PosStyles(align: PosAlign.right, fontType: PosFontType.fontA)),
            PosColumn(text: val['taxAmt']!.toStringAsFixed(2), width: 4, styles: const PosStyles(align: PosAlign.right, fontType: PosFontType.fontA)),
          ]);
        });
        bytes += generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontA));
      }

      // 6. QR & Footer
      final upiId = data['upi_id']?.toString();
      if (upiId != null && upiId.isNotEmpty && upiId != 'null') {
        bytes += generator.emptyLines(1);
        bytes += generator.text('SCAN TO PAY', styles: const PosStyles(align: PosAlign.center, bold: true, fontType: PosFontType.fontA));
        final tn = Uri.encodeComponent(data['invoice_number']?.toString() ?? 'Invoice');
        final qrUrl = 'https://quickchart.io/qr?size=450&text=${Uri.encodeComponent('upi://pay?pa=$upiId&pn=EZBILLIFY&am=$totalAmt&cu=INR&tn=$tn')}';
        try {
          final response = await http.get(Uri.parse(qrUrl)).timeout(const Duration(seconds: 4));
          final qrImg = img.decodeImage(response.bodyBytes);
          if (qrImg != null) {
            bytes += generator.image(img.grayscale(img.copyResize(qrImg, width: is58mm ? 250 : 350)), align: PosAlign.center);
          }
        } catch (e) {
          debugPrint('QR Error: $e');
        }
        bytes += generator.text(upiId, styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontA));
      }

      bytes += generator.emptyLines(1);
      bytes += generator.text("THANK YOU! VISIT AGAIN", styles: const PosStyles(align: PosAlign.center, bold: true, fontType: PosFontType.fontA));
      bytes += generator.text("Powered by EZBillify", styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB));
      
      bytes += generator.feed(2);
      bytes += generator.cut();

      // 7. Dispatch Data
      debugPrint('PrintService: Dispatching ${bytes.length} bytes to printer...');
      await _directTransport(transport, writeChar, bytes);
      debugPrint('PrintService: Print successful.');

    } catch (e, stack) {
      debugPrint('PrintService Critical Failure: $e');
      debugPrint(stack.toString());
      rethrow;
    } finally {
      // Small cooling period for the hardware
      await Future.delayed(const Duration(milliseconds: 1000));
      if (transport is BluetoothDevice) await transport.disconnect().catchError((_) {});
      if (transport is Socket) await transport.close();
      _isPrinting = false;
    }
  }

  static Future<void> _directTransport(dynamic transport, BluetoothCharacteristic? char, List<int> bytes) async {
    if (transport is Socket) {
      transport.add(bytes);
      await transport.flush();
    } else if (char != null) {
      // Chunking with hardware synchronization
      const int targetChunkSize = 128; // Standard BLE / ESC-POS packet target
      for (int i = 0; i < bytes.length; i += targetChunkSize) {
        final end = (i + targetChunkSize < bytes.length) ? i + targetChunkSize : bytes.length;
        final chunk = bytes.sublist(i, end);
        
        // Every 4th chunk, write WITH response to ensure the printer buffer isn't overwhelmed
        // This acts as a physical handshake for stability.
        bool withResponse = (i / targetChunkSize) % 4 == 0;
        
        try {
          await char.write(chunk, withoutResponse: !withResponse);
          // Small safety delay for the printer CPU to process the buffer
          await Future.delayed(Duration(milliseconds: withResponse ? 5 : 20));
        } catch (e) {
          debugPrint('PrintService: Transport write failed at offset $i: $e');
          rethrow;
        }
      }
    }
  }


  static String _generateHeaderHtml(Map<String, dynamic> data, bool is58mm) {
    // Legacy mapping - hybrid mode uses native text now
    return '';
  }

  static String _generateFooterHtml(Map<String, dynamic> data, bool is58mm) {
    // Legacy mapping - hybrid mode uses native text now
    return '';
  }

  static String _getDocFileName(Map<String, dynamic> data, String docType) {
    final cleanDocType = docType.replaceAll(' ', '_').toUpperCase();
    final number = (data['invoice_number'] ?? data['bill_number'] ?? data['po_number'] ?? data['document_number'] ?? DateTime.now().millisecondsSinceEpoch).toString().replaceAll('/', '_');
    return '${cleanDocType}_$number';
  }

  static String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  static Future<void> printTestPage() async {
    final printerConfig = await PrintSettingsService.getPrinterConfig();
    final testData = {
      'company_name': 'EZBILLIFY POS TEST',
      'company_address': 'Sector 5, HSR Layout, Bangalore - 560102',
      'company_gstin': '29ABCDE1234F1Z5',
      'fssai_lic_no': '12345678901234',
      'invoice_number': 'BILL-2024-001',
      'date': DateTime.now().toIso8601String(),
      'time': DateFormat('hh:mm a').format(DateTime.now()),
      'customer': {'name': 'Retail Customer', 'phone': '9876543210'},
      'total_amount': 210.00,
      'sub_total': 200.00,
      'tax_total': 10.00,
      'upi_id': 'ezbillify@paytm',
      'items': [
        {
          'item': {'name': 'PREMIUM SODA PITCHER', 'hsn_code': '2202'},
          'quantity': 2,
          'unit_price': 100.00,
          'total_amount': 210.00,
          'tax_rate': 5.0,
          'tax_amount': 10.0,
          'hsn_code': '2202'
        }
      ]
    };
    final richData = await _fetchMissingPrintData(testData);
    await _printDirectlyToThermal(richData, 'Test Print', printerConfig);
  }

  static Future<String?> downloadDocument(Map<String, dynamic> data, String docType, [BuildContext? context]) async {
    try {
      final richData = await _fetchMissingPrintData(data);
      final fileName = _getDocFileName(richData, docType);
      
      // Generate PDF Bytes
      final pdfBytes = await _generatePdfBytes(richData, docType);
      
      if (Platform.isAndroid) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName.pdf');
        await file.writeAsBytes(pdfBytes);
        
        // Android 11+ Best Practice: Explicit mimeType and context-less share
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Download $docType: $fileName',
        );
        return 'system_dialog'; 
      }

      final directory = await getApplicationDocumentsFiles();
      final path = '${directory.path}/$fileName.pdf';
      final file = File(path);
      await file.writeAsBytes(pdfBytes);
      return path;
    } catch (e) {
      debugPrint('PrintService Download Error: $e');
      return null;
    }
  }

  static Future<void> shareDocument(BuildContext context, Map<String, dynamic> data, String docType) async {
    try {
      debugPrint('PrintService: Preparing share for $docType...');
      final richData = await _fetchMissingPrintData(data);
      final pdfBytes = await _generatePdfBytes(richData, docType);
      final fileName = _getDocFileName(richData, docType);
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName.pdf');
      await file.writeAsBytes(pdfBytes);

      // On iOS/iPad, sharePositionOrigin is REQUIRED to prevent crash or non-responsiveness
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      final Rect? origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      debugPrint('PrintService: Launching Share modal...');
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Share $docType: $fileName',
        sharePositionOrigin: origin,
      );
      debugPrint('PrintService: Share modal closed');
    } catch (e, stack) {
      debugPrint('PrintService Share Error: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  /// Expose for internal previewing
  static Future<Uint8List> generatePdfBytesForPreview(Map<String, dynamic> data, String docType) async {
    final richData = await _fetchMissingPrintData(data);
    return await _generatePdfBytes(richData, docType);
  }

  static Future<Uint8List> _generatePdfBytes(Map<String, dynamic> data, String docType, {PdfPageFormat? format, TemplateType? forceTemplate}) async {
    final templateType = forceTemplate ?? await PrintSettingsService.getTemplate(docType);
    final isThermal = templateType == TemplateType.thermal80mm || templateType == TemplateType.thermal58mm;
    final html = isThermal ? await _generateThermalHtml(data, docType, templateType) : await _generateA4Html(data, docType);
    
    // CRITICAL: On Android, convertHtml with double.infinity often fails or produces empty PDFs.
    // We use a large but finite height for thermal PDFs if no format is provided.
    // 1000mm (1 meter) covers even the longest retail receipts.
    final pdfFormat = format ?? (isThermal 
      ? PdfPageFormat((templateType == TemplateType.thermal80mm ? 80.0 : 58.0) * PdfPageFormat.mm, 1000 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm)
      : PdfPageFormat.a4);
      
    final pdfBytes = await Printing.convertHtml(format: pdfFormat, html: html);
    if (pdfBytes.isEmpty) throw Exception("Generated PDF is empty. Check HTML content.");
    return pdfBytes;
  }

  static Future<String> _generateA4Html(Map<String, dynamic> data, String docType) async {
    String template = await rootBundle.loadString('assets/templates/a4_standard.html');
    return _populateTemplate(template, data, docType, templateType: TemplateType.a4Standard);
  }

  static Future<String> _generateThermalHtml(Map<String, dynamic> data, String docType, TemplateType templateType) async {
    String template = await rootBundle.loadString('assets/templates/thermal_v3.html');
    return _populateTemplate(template, data, docType, templateType: templateType);
  }

  static String _populateTemplate(String template, Map<String, dynamic> data, String docType, {required TemplateType templateType}) {
    String output = template;
    final isA4 = templateType == TemplateType.a4Standard;
    
    // Basic replacements
    output = output.replaceAll('{{COMPANY_NAME}}', (data['company_name'] ?? 'EZBILLIFY SHOP').toString().toUpperCase());
    output = output.replaceAll('{{BRANCH_NAME_TEXT}}', (data['branch_name'] ?? 'MAIN BRANCH').toString().toUpperCase());
    
    // Header Logic
    String docTitle = docType.replaceAll('_', ' ').toUpperCase();
    if (docType.contains('quote')) docTitle = "QUOTATION";
    else if (docType.contains('purchase_order')) docTitle = "PURCHASE ORDER";
    else if (docType.contains('sales_order')) docTitle = "SALES ORDER";
    else docTitle = "TAX INVOICE";

    output = output.replaceAll('{{DOC_TITLE}}', docTitle);
    output = output.replaceAll('{{DOC_COPY_LABEL}}', data['irn'] != null ? '(E-Invoice - Original For Recipient)' : '(Original For Recipient)');
    output = output.replaceAll('{{DOC_NUMBER_LABEL}}', docType.contains('quote') ? 'Quote No:' : docType.contains('order') ? 'Order No:' : 'Invoice No:');
    
    output = output.replaceAll('{{DATE}}', _formatDate(data['date']?.toString()));
    output = output.replaceAll('{{DUE_DATE}}', _formatDate(data['due_date']?.toString()));
    output = output.replaceAll('{{DOC_NUMBER}}', (data['invoice_number'] ?? data['bill_number'] ?? data['po_number'] ?? data['document_number'] ?? '-').toString());
    
    // State Logic for Tax
    final companyState = (data['company_state'] ?? '').toString().trim().toLowerCase();
    final customerState = (data['customer']?['state'] ?? data['vendor']?['state'] ?? companyState).toString().trim().toLowerCase();
    final isIntraState = companyState == customerState;
    output = output.replaceAll('{{POS}}', (data['place_of_supply'] ?? data['company_state'] ?? '-').toString().toUpperCase());

    // Address & Company Info
    final addressRaw = data['company_address'];
    String addressStr = '';
    if (addressRaw is Map) {
      final line1 = addressRaw['line1'] ?? addressRaw['address_line_1'] ?? '';
      final city = addressRaw['city'] ?? '';
      final state = addressRaw['state'] ?? '';
      final pincode = addressRaw['pincode'] ?? '';
      addressStr = [line1, city, state, pincode].where((s) => s != null && s.toString().isNotEmpty).join(', ');
    } else addressStr = addressRaw?.toString() ?? '';
    
    output = output.replaceAll('{{COMPANY_ADDRESS}}', addressStr);
    output = output.replaceAll('{{COMPANY_GSTIN}}', data['company_gstin']?.toString() ?? '-');
    output = output.replaceAll('{{COMPANY_STATE}}', data['company_state']?.toString() ?? '-');
    output = output.replaceAll('{{COMPANY_PHONE}}', data['company_phone']?.toString() ?? '-');
    output = output.replaceAll('{{COMPANY_EMAIL}}', data['company_email']?.toString() ?? '-');
    
    final fssai = data['fssai_lic_no']?.toString();
    if (fssai != null && fssai.isNotEmpty && fssai != 'null' && fssai != '-') {
      output = output.replaceAll('{{FSSAI_ROW_NATIVE}}', '<tr><td style="font-weight: bold; color: #059669; padding-right: 8pt; border:none;">FSSAI:</td><td style="font-weight: bold; color: #059669; border:none;">$fssai</td></tr>');
    } else {
      output = output.replaceAll('{{FSSAI_ROW_NATIVE}}', '');
    }

    final logoUrl = data['thermal_logo']?.toString();
    if (logoUrl != null && logoUrl.startsWith('http')) {
      output = output.replaceAll('{{LOGO_IMG_TAG}}', '<img src="$logoUrl" style="width:70pt; height:70pt; object-fit:contain;" />');
    } else {
      output = output.replaceAll('{{LOGO_IMG_TAG}}', '');
    }

    // Party Info
    final party = data['customer'] ?? data['vendor'];
    final partyName = (party is Map ? party['name'] : (party ?? 'WALK-IN CUSTOMER')).toString().toUpperCase();
    final partyAddress = (party is Map ? (party['address'] ?? party['billing_address'] ?? 'N/A') : '').toString();
    output = output.replaceAll('{{CUSTOMER_NAME}}', partyName);
    output = output.replaceAll('{{CUSTOMER_ADDRESS}}', partyAddress.isEmpty ? '-' : partyAddress);
    output = output.replaceAll('{{CUSTOMER_GSTIN}}', (party is Map ? (party['gstin'] ?? party['gst_no']) : '')?.toString() ?? '-');
    output = output.replaceAll('{{CUSTOMER_STATE}}', (party is Map ? party['state'] : null)?.toString() ?? '-');
    output = output.replaceAll('{{SHIPPING_ADDRESS_TEXT}}', partyAddress.isEmpty ? 'Same as Billing Address' : partyAddress);

    // Items Logic
    final items = data['items'] as List? ?? [];
    String expandedRows = "";
    double subtotalValue = 0;
    double cgstTotalValue = 0;
    double sgstTotalValue = 0;
    double igstTotalValue = 0;
    Map<String, Map<String, dynamic>> taxGroups = {};

    // Tax Column Headers
    if (isIntraState) {
      output = output.replaceAll('{{TAX_HEADER_NATIVE}}', '<th style="width: 7%; text-align: right;">CGST</th><th style="width: 7%; text-align: right;">SGST</th>');
    } else {
      output = output.replaceAll('{{TAX_HEADER_NATIVE}}', '<th style="width: 8%; text-align: right;">IGST</th>');
    }

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final name = (item['item'] is Map ? item['item']['name'] : (item['name'] ?? item['description'] ?? 'Item')).toString();
      final hsn = (item['hsn_code'] ?? (item['item'] is Map ? item['item']['hsn_code'] : null))?.toString() ?? '-';
      final mrp = (item['item'] is Map ? item['item']['mrp'] : item['mrp'])?.toString() ?? '-';
      final qty = (item['quantity'] ?? 1).toDouble();
      final rate = (item['unit_price'] ?? 0).toDouble();
      final disc = (item['discount'] ?? 0).toDouble();
      final total = (item['total_amount'] ?? (qty * rate)).toDouble();
      final taxRate = (item['tax_rate'] ?? 0).toDouble();
      final taxAmt = (item['tax_amount'] ?? 0).toDouble();
      
      final taxableValue = total - taxAmt;
      subtotalValue += taxableValue;

      // Grouping for tax breakup
      final key = "$hsn-$taxRate";
      if (!taxGroups.containsKey(key)) taxGroups[key] = {'hsn': hsn, 'rate': taxRate, 'taxable': 0.0, 'taxAmt': 0.0};
      taxGroups[key]!['taxable'] += taxableValue;
      taxGroups[key]!['taxAmt'] += taxAmt;

      expandedRows += "<tr>";
      expandedRows += "<td class='text-center'>${i + 1}</td>";
      expandedRows += "<td class='bold'>$name</td>";
      expandedRows += "<td class='text-center'>$hsn</td>";
      expandedRows += "<td class='text-center'>$mrp</td>";
      expandedRows += "<td class='text-center bold'>${qty.toStringAsFixed(0)}</td>";
      expandedRows += "<td class='text-right'>${rate.toStringAsFixed(2)}</td>";
      expandedRows += "<td class='text-center'>${disc > 0 ? disc.toStringAsFixed(0) : '-'}</td>";
      expandedRows += "<td class='text-right bold'>${taxableValue.toStringAsFixed(2)}</td>";
      
      if (isIntraState) {
        cgstTotalValue += taxAmt / 2;
        sgstTotalValue += taxAmt / 2;
        expandedRows += "<td class='text-right' style='font-size:7pt;'>${(taxAmt / 2).toStringAsFixed(2)}</td>";
        expandedRows += "<td class='text-right' style='font-size:7pt;'>${(taxAmt / 2).toStringAsFixed(2)}</td>";
      } else {
        igstTotalValue += taxAmt;
        expandedRows += "<td class='text-right' style='font-size:7pt;'>${taxAmt.toStringAsFixed(2)}</td>";
      }
      
      expandedRows += "<td class='text-right bold'>${total.toStringAsFixed(2)}</td>";
      expandedRows += "</tr>";
    }
    output = output.replaceAll('{{ITEMS_ROWS_EXPANDED}}', expandedRows);
    
    final grandTotalValue = (data['total_amount'] ?? (subtotalValue + cgstTotalValue + sgstTotalValue + igstTotalValue)).toDouble();
    output = output.replaceAll('{{SUBTOTAL}}', subtotalValue.toStringAsFixed(2));
    
    String taxSummary = "";
    if (isIntraState) {
      taxSummary += "<tr><td style='padding:3pt 6pt; border:none; color:#666;'>CGST</td><td style='padding:3pt 6pt; border:none; text-align:right;'>₹${cgstTotalValue.toStringAsFixed(2)}</td></tr>";
      taxSummary += "<tr><td style='padding:3pt 6pt; border:none; color:#666;'>SGST</td><td style='padding:3pt 6pt; border:none; text-align:right;'>₹${sgstTotalValue.toStringAsFixed(2)}</td></tr>";
    } else {
      taxSummary += "<tr><td style='padding:3pt 6pt; border:none; color:#666;'>IGST</td><td style='padding:3pt 6pt; border:none; text-align:right;'>₹${igstTotalValue.toStringAsFixed(2)}</td></tr>";
    }
    output = output.replaceAll('{{TAX_SUMMARY_ROWS_NATIVE}}', taxSummary);
    output = output.replaceAll('{{GRAND_TOTAL}}', grandTotalValue.toStringAsFixed(2));
    output = output.replaceAll('{{AMOUNT_IN_WORDS}}', NumberToWords.convert(grandTotalValue));

    // Tax Breakup Expanded
    if (isIntraState) {
      output = output.replaceAll('{{TAX_BREAKUP_HEADER_NATIVE}}', '<th style="text-align:center;">CGST Rate</th><th style="text-align:right;">CGST Amt</th><th style="text-align:center;">SGST Rate</th><th style="text-align:right;">SGST Amt</th>');
    } else {
      output = output.replaceAll('{{TAX_BREAKUP_HEADER_NATIVE}}', '<th style="text-align:center;">IGST Rate</th><th style="text-align:right;">IGST Amt</th>');
    }

    String taxBreakupRows = "";
    taxGroups.forEach((key, val) {
      final t = val['taxAmt'] as double;
      taxBreakupRows += "<tr>";
      taxBreakupRows += "<td>${val['hsn']}</td>";
      taxBreakupRows += "<td class='text-right'>${(val['taxable'] as double).toStringAsFixed(2)}</td>";
      if (isIntraState) {
        taxBreakupRows += "<td class='text-center'>${(val['rate'] / 2).toStringAsFixed(1)}%</td>";
        taxBreakupRows += "<td class='text-right'>${(t / 2).toStringAsFixed(2)}</td>";
        taxBreakupRows += "<td class='text-center'>${(val['rate'] / 2).toStringAsFixed(1)}%</td>";
        taxBreakupRows += "<td class='text-right'>${(t / 2).toStringAsFixed(2)}</td>";
      } else {
        taxBreakupRows += "<td class='text-center'>${val['rate'].toStringAsFixed(1)}%</td>";
        taxBreakupRows += "<td class='text-right'>${t.toStringAsFixed(2)}</td>";
      }
      taxBreakupRows += "<td class='text-right bold'>${t.toStringAsFixed(2)}</td>";
      taxBreakupRows += "</tr>";
    });
    output = output.replaceAll('{{TAX_BREAKUP_EXPANDED}}', taxBreakupRows);

    // E-Invoice Section
    if (data['irn'] != null) {
      final irn = data['irn'];
      final ackNo = data['einvoice_ack_no'] ?? '-';
      final ackDate = _formatDate(data['einvoice_ack_date']?.toString());
      final eway = data['eway_bill_no'];
      final qrUrl = data['einvoice_qr_code'] ?? 'https://quickchart.io/qr?size=150&text=${Uri.encodeComponent(irn)}';
      
      output = output.replaceAll('{{EINVOICE_SECTION_NATIVE}}', '''
        <div style="padding: 5pt; border: 1px solid #000; border-top: none; background: #f9fafb;">
            <table style="width: 100%;">
                <tr>
                    <td style="width: 15%; border:none; padding-right: 10pt;">
                        <div style="font-size: 7pt; color: #666; font-weight: bold; margin-bottom: 2pt; text-transform: uppercase;">E-Invoice Details</div>
                        <img src="$qrUrl" style="width: 50pt; height: 50pt; border: 1px solid #ddd; padding: 2pt;" />
                    </td>
                    <td style="width: 85%; border:none;">
                        <table style="font-size: 8pt;">
                            <tr><td style="color: #666; width: 70pt; border:none;">IRN:</td><td style="font-weight: bold; border:none; word-break: break-all; font-family: monospace; font-size:6pt;">$irn</td></tr>
                            <tr><td style="color: #666; border:none;">Ack No & Date:</td><td style="font-weight: bold; border:none;">$ackNo | $ackDate</td></tr>
                            ${eway != null ? '<tr><td style="color: #059669; border:none; fontWeight: bold;">E-Way Bill No:</td><td style="font-weight: bold; color: #059669; border:none;">$eway</td></tr>' : ''}
                        </table>
                    </td>
                </tr>
            </table>
        </div>
      ''');
    } else {
      output = output.replaceAll('{{EINVOICE_SECTION_NATIVE}}', '');
    }

    // Footers
    output = output.replaceAll('{{BANK_NAME}}', (data['bank_name'] ?? data['branch']?['bank_name'] ?? '-').toString().toUpperCase());
    output = output.replaceAll('{{BANK_ACC}}', (data['branch']?['account_number'] ?? data['bank_acc'] ?? '-'));
    output = output.replaceAll('{{BANK_IFSC}}', (data['branch']?['ifsc_code'] ?? data['bank_ifsc'] ?? '-'));
    output = output.replaceAll('{{BANK_BRANCH}}', (data['branch']?['bank_branch'] ?? data['bank_branch'] ?? '-'));
    output = output.replaceAll('{{TERMS_CONTENT_CLEAN}}', data['terms_conditions'] ?? data['notes'] ?? '1. Goods once sold will not be taken back.\n2. Interest @18% p.a. for delayed payment.\n3. Subject to Local Jurisdiction.');
    output = output.replaceAll('{{COMPANY_NAME_SHORT}}', (data['company_name'] ?? 'EZBILLIFY').toString().toUpperCase());
    output = output.replaceAll('{{UPI_ID_TEXT}}', data['upi_id'] ?? data['branch']?['upi_id'] ?? '-');

    final upiId = data['upi_id'] ?? data['branch']?['upi_id'];
    if (upiId != null && upiId.isNotEmpty && upiId != 'null') {
      final tn = Uri.encodeComponent(data['invoice_number']?.toString() ?? 'Invoice');
      final qrUrl = 'https://quickchart.io/qr?size=250&text=${Uri.encodeComponent('upi://pay?pa=$upiId&pn=EZBILLIFY&am=${grandTotalValue.toStringAsFixed(2)}&cu=INR&tn=$tn')}';
      output = output.replaceAll('{{QR_CODE_TAG}}', '<img src="$qrUrl" class="qr-img" />');
    } else {
      output = output.replaceAll('{{QR_CODE_TAG}}', '');
    }

    if (data['due_date'] != null) {
      output = output.replaceAll('{{DUE_DATE_ROW_NATIVE}}', '<tr style="border-bottom: 1px dotted #ccc;"><td style="font-weight: bold; color: #666; border:none; padding: 2pt 0;">Due Date:</td><td style="text-align: right; border:none; padding: 2pt 0;">${_formatDate(data['due_date']?.toString())}</td></tr>');
    } else {
      output = output.replaceAll('{{DUE_DATE_ROW_NATIVE}}', '');
    }

    final roundOff = (data['round_off'] ?? 0).toDouble();
    if (roundOff != 0) {
      output = output.replaceAll('{{ROUND_OFF_ROW_NATIVE}}', '<tr style="border-bottom: 1px solid #ddd;"><td style="padding: 3pt 6pt; border:none; color: #666;">Round Off</td><td style="padding: 3pt 6pt; border:none; text-align: right;">${roundOff > 0 ? '+' : ''}${roundOff.toStringAsFixed(2)}</td></tr>');
    } else {
      output = output.replaceAll('{{ROUND_OFF_ROW_NATIVE}}', '');
    }

    return output;
  }

  static Future<Directory> getApplicationDocumentsFiles() async {
    if (Platform.isIOS) return await getApplicationDocumentsDirectory();
    return await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
  }
}
