
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme_service.dart';

class ScannerModalContent<T> extends StatefulWidget {
  final List<T> allItems;
  final List<T> selectedItems;
  final Function(List<T>) onSelectionChanged;
  final VoidCallback? onConfirm;
  final String? Function(T) barcodeMapper;
  final String Function(T) labelMapper;
  final bool isMultiple;

  const ScannerModalContent({
    super.key,
    required this.allItems,
    required this.selectedItems,
    required this.onSelectionChanged,
    this.onConfirm,
    required this.barcodeMapper,
    required this.labelMapper,
    required this.isMultiple,
  });

  @override
  State<ScannerModalContent<T>> createState() => _ScannerModalContentState<T>();
}

class _ScannerModalContentState<T> extends State<ScannerModalContent<T>> {
  late MobileScannerController _controller;
  final List<T> _currentSelected = [];
  DateTime? _lastScanTime;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.ean13, BarcodeFormat.code128, BarcodeFormat.upcA, BarcodeFormat.qrCode, BarcodeFormat.all],
      detectionSpeed: DetectionSpeed.normal, // Allow duplicates
    );
    _currentSelected.addAll(widget.selectedItems);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(String code) {
    // Debounce duplicate scans within 1.5 seconds
    if (code == _lastScannedCode && 
        _lastScanTime != null && 
        DateTime.now().difference(_lastScanTime!) < const Duration(milliseconds: 1500)) {
      return;
    }
    
    _lastScanTime = DateTime.now();
    _lastScannedCode = code;

    final found = widget.allItems.where((item) {
      final b = widget.barcodeMapper(item)?.toLowerCase() ?? "";
      return b.contains(code.toLowerCase());
    }).firstOrNull;

    if (found != null) {
      if (widget.isMultiple) {
        // Allow duplicates for quantity scanning
        setState(() {
          _currentSelected.add(found);
        });
        widget.onSelectionChanged(_currentSelected);
      } else {
        widget.onSelectionChanged([found]);
         Navigator.pop(context);
         if(widget.onConfirm != null) widget.onConfirm!();
      }
    }
  }

  List<MapEntry<T, int>> _getGroupedItems() {
    final Map<T, int> counts = {};
    // Iterate in reverse to show newest first? 
    // No, standard map preserves insertion order.
    // If we want newest scanned at top, we might need a different structure or just reverse the result of unique keys.
    // Let's just group them.
    for (final item in _currentSelected) {
      counts[item] = (counts[item] ?? 0) + 1;
    }
    return counts.entries.toList().reversed.toList(); // Newest (by creation of group) approx at top if we assume standard map behavior.
    // Actually, to bubble the recently scanned item to top, we'd need to re-order.
    // Let's stick to a simple reversed unique list for now.
  }

  void _incrementItem(T item) {
    setState(() {
      _currentSelected.add(item);
    });
    widget.onSelectionChanged(_currentSelected);
  }

  void _decrementItem(T item) {
     setState(() {
      _currentSelected.remove(item);
    });
    widget.onSelectionChanged(_currentSelected);
  }

  void _removeItemFully(T item) {
    setState(() {
      _currentSelected.removeWhere((e) => e == item);
    });
    widget.onSelectionChanged(_currentSelected);
  }

  @override
  Widget build(BuildContext context) {
    final groupedItems = _getGroupedItems();

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.surfaceBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Scan Items", style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Scanner Area (Top 20-25%)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: (capture) {
                          final List<Barcode> barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            if (barcode.rawValue != null) {
                              _handleBarcode(barcode.rawValue!);
                              break; // Handle first valid barcode per frame
                            }
                          }
                        },
                      ),
                      // Overlay
                      Center(
                        child: Container(
                          width: 200,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 4)]
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                            child: const Text("Point camera at barcode", style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text("Scanned Items", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text("${_currentSelected.length}", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryBlue)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: groupedItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.barcode_reader, size: 48, color: context.textSecondary.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text("No items scanned yet", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: groupedItems.length,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemBuilder: (context, index) {
                      final entry = groupedItems[index];
                      final item = entry.key;
                      final count = entry.value;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.borderColor),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))
                            ]
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                alignment: Alignment.center,
                                child: Text("${index + 1}", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.labelMapper(item), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: context.textPrimary)),
                                    const SizedBox(height: 4),
                                    Text("Scanned x$count", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(border: Border.all(color: context.borderColor), borderRadius: BorderRadius.circular(8)),
                                      child: Icon(Icons.remove_rounded, size: 16, color: context.textPrimary)
                                    ),
                                    onPressed: () => _decrementItem(item),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Text("$count", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                                  IconButton(
                                    icon: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: AppColors.primaryBlue, borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.add_rounded, size: 16, color: Colors.white)
                                    ),
                                    onPressed: () => _incrementItem(item),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red.withOpacity(0.7)),
                                    onPressed: () => _removeItemFully(item),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close Scanner Modal
                    widget.onConfirm?.call(); // Trigger action in parent (Selection Sheet)
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: AppColors.primaryBlue.withOpacity(0.4),
                  ),
                  child: Text("Add ${groupedItems.length} Products", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
