import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/print_service.dart';
import '../../services/print_settings_service.dart';
import '../../core/theme_service.dart';
import 'package:ez_billify_v2_app/services/status_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final TextEditingController _ipController = TextEditingController();
  
  String _selectedType = 'network';
  String _selectedPaperSize = '80mm';
  String? _savedBtAddress;
  String? _savedBtName;
  
  bool _isLoading = true;
  bool _isScanning = false;
  bool? _isOnline;
  bool _isCheckingStatus = false;
  List<ScanResult> _scanResults = [];
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final config = await PrintSettingsService.getPrinterConfig();
    if (mounted) {
      setState(() {
        _ipController.text = config['ip'] ?? '';
        _selectedType = config['type'] ?? 'network';
        _selectedPaperSize = config['paperSize'] ?? '80mm';
        _savedBtAddress = config['btAddress'];
        _isLoading = false;
      });
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    if (_isCheckingStatus) return;
    setState(() => _isCheckingStatus = true);
    final status = await PrintService.checkPrinterStatus();
    if (mounted) {
      setState(() {
        _isOnline = status;
        _isCheckingStatus = false;
      });
    }
  }

  void _stopScan() {
    try {
      FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
    } catch (_) {}
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _scanResults = [];
    });

    try {
      // 1. Permissions
      if (Platform.isAndroid) {
        await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
      } else {
        await Permission.bluetooth.request();
      }

      _stopScan();

      // Check adapter state
      BluetoothAdapterState adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        if (mounted) StatusService.show(context, 'Please turn on Bluetooth');
        setState(() => _isScanning = false);
        return;
      }

      final systemDevices = await FlutterBluePlus.systemDevices([]);
      
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;
        
        setState(() {
          final Map<String, ScanResult> uniqueDevices = {};
          
          // 1. Add System Devices (dummy results for already paired devices)
          for (var d in systemDevices) {
            uniqueDevices[d.remoteId.str] = ScanResult(
              device: d,
              advertisementData: AdvertisementData(
                advName: d.platformName,
                txPowerLevel: null,
                appearance: 0,
                connectable: true,
                manufacturerData: {},
                serviceUuids: [],
                serviceData: {},
              ),
              rssi: -50,
              timeStamp: DateTime.now(),
            );
          }

          // 2. Add/Overwrite with Active Scan Results (real-time advertising)
          for (var r in results) {
            uniqueDevices[r.device.remoteId.str] = r;
          }

          _scanResults = uniqueDevices.values.toList();

          // 3. Intelligent Sorting: Named devices first, then by signal strength
          _scanResults.sort((a, b) {
            final aName = a.device.platformName.isNotEmpty ? a.device.platformName : a.advertisementData.advName;
            final bName = b.device.platformName.isNotEmpty ? b.device.platformName : b.advertisementData.advName;
            
            if (aName.isNotEmpty && bName.isEmpty) return -1;
            if (aName.isEmpty && bName.isNotEmpty) return 1;
            return b.rssi.compareTo(a.rssi);
          });
        });
      });

      // Start scan with aggressive discovery for industrial printers
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );
      
    } catch (e) {
      debugPrint('Scan error: $e');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _saveSettings({String? btAddress, String? btName}) async {
    await PrintSettingsService.setPrinterConfig(
      ip: _ipController.text,
      type: _selectedType,
      paperSize: _selectedPaperSize,
      btAddress: btAddress ?? _savedBtAddress,
    );
    
    if (btAddress != null) {
      setState(() {
        _savedBtAddress = btAddress;
        _savedBtName = btName;
      });
    }

    if (mounted) {
      StatusService.show(context, btAddress != null ? 'Printer linked!' : 'Settings saved', backgroundColor: AppColors.success);
      _checkStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final surfaceColor = context.surfaceBg;
    final borderColor = context.borderColor;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Printer Setup", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildInfoCard(surfaceColor, borderColor, textSecondary),
                  const SizedBox(height: 24),
                  _buildSectionHeader("Connection Mode"),
                  _buildSelectionCard([
                    _buildRadioTile("Direct Bluetooth (BLE/Classic)", 'bluetooth', Icons.bluetooth_audio_rounded),
                    _buildRadioTile("Network / Wi-Fi", 'network', Icons.lan_outlined),
                  ], surfaceColor, borderColor),
                  
                  const SizedBox(height: 24),
                  
                  if (_selectedType == 'bluetooth') ...[
                    _buildSavedBtCard(surfaceColor, borderColor),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader("Nearby Printers"),
                        if (_isScanning)
                          const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          TextButton.icon(
                            onPressed: _startScan,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text("Scan", style: TextStyle(fontSize: 12)),
                          )
                      ],
                    ),
                    _buildBtScanList(surfaceColor, borderColor),
                  ] else ...[
                    _buildSectionHeader("Printer IP Address"),
                    Container(
                      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                      child: TextField(
                        controller: _ipController,
                        style: TextStyle(fontFamily: 'Outfit', color: textPrimary),
                        onSubmitted: (_) => _checkStatus(),
                        decoration: InputDecoration(
                          hintText: "e.g. 192.168.1.100",
                          prefixIcon: Icon(Icons.settings_ethernet_rounded, color: textSecondary),
                          suffixIcon: _buildStatusIndicator(),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  _buildSectionHeader("Paper Width"),
                  _buildSelectionCard([
                    _buildPaperSizeTile("80mm (Desktop)", '80mm'),
                    _buildPaperSizeTile("58mm (Mobile)", '58mm'),
                  ], surfaceColor, borderColor),
                  
                  const SizedBox(height: 40),
                  FadeInUp(
                    child: Column(
                      children: [
                        if (_savedBtAddress != null || _selectedType == 'network')
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  StatusService.show(context, 'Starting Test Print...');
                                  await PrintService.printTestPage();
                                } catch (e) {
                                  if (mounted) {
                                    StatusService.show(context, 'Print Error: ${e.toString()}', backgroundColor: Colors.red);
                                  }
                                }
                              },
                              icon: const Icon(Icons.receipt_long_rounded, size: 18),
                              label: const Text("Run Test Print", style: TextStyle(fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: BorderSide(color: AppColors.primaryBlue),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _saveSettings(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text("Save Configuration", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSavedBtCard(Color surface, Color border) {
    if (_savedBtAddress == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (_isOnline == true ? AppColors.success : AppColors.primaryBlue).withOpacity(0.05), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: (_isOnline == true ? AppColors.success : AppColors.primaryBlue).withOpacity(0.2))
      ),
      child: Row(
        children: [
          _buildStatusIndicator(large: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Linked Printer", style: TextStyle(fontSize: 11, color: context.textSecondary)),
                Text(_savedBtName ?? _savedBtAddress!, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          TextButton(onPressed: () => setState(() => _savedBtAddress = null), child: const Text("Unlink", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator({bool large = false}) {
    if (_isCheckingStatus) {
      return SizedBox(
        width: large ? 20 : 16, 
        height: large ? 20 : 16, 
        child: const CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.blue))
      );
    }

    if (_isOnline == null) return Icon(Icons.help_outline_rounded, size: large ? 24 : 18, color: context.textSecondary);

    return InkWell(
      onTap: _checkStatus,
      child: Icon(
        _isOnline! ? Icons.check_circle_rounded : Icons.error_rounded,
        color: _isOnline! ? AppColors.success : Colors.red,
        size: large ? 24 : 18,
      ),
    );
  }

  Widget _buildBtScanList(Color surface, Color border) {
    if (_scanResults.isEmpty && !_isScanning) {
      return Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
        child: Column(children: [
          Icon(Icons.bluetooth_searching_rounded, color: context.textSecondary.withOpacity(0.2), size: 48),
          const SizedBox(height: 12),
          Text("No Bluetooth devices found", style: TextStyle(color: context.textSecondary, fontSize: 13)),
        ]),
      );
    }
    return Container(
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _scanResults.length,
        separatorBuilder: (ctx, i) => Divider(height: 1, color: border),
        itemBuilder: (ctx, i) {
          final result = _scanResults[i];
          String name = '';
          try {
            name = result.device.platformName.isNotEmpty 
              ? result.device.platformName 
              : result.advertisementData.advName.isNotEmpty 
                ? result.advertisementData.advName 
                : 'Thermal Printer';
          } catch (_) {
            name = 'Unknown Device';
          }
          
          return ListTile(
            leading: const Icon(Icons.print_rounded),
            title: Text(name),
            subtitle: Text(result.device.remoteId.str),
            trailing: TextButton(
              onPressed: () => _saveSettings(btAddress: result.device.remoteId.str, btName: name),
              child: const Text("Link"),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.textSecondary.withOpacity(0.7), letterSpacing: 1.2)),
    );
  }

  Widget _buildInfoCard(Color bg, Color border, Color textSec) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue),
        const SizedBox(width: 12),
        Expanded(child: Text("Scanning for Bluetooth LE printers. Ensure your printer is on and discoverable.", style: TextStyle(fontSize: 13, color: textSec))),
      ]),
    );
  }

  Widget _buildSelectionCard(List<Widget> children, Color surfaceColor, Color borderColor) {
    return Container(decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)), child: Column(children: children));
  }

  Widget _buildRadioTile(String title, String value, IconData icon) {
    final isSelected = _selectedType == value;
    return ListTile(
      onTap: () => setState(() => _selectedType = value),
      leading: Icon(icon, color: isSelected ? AppColors.primaryBlue : context.textSecondary),
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue) : const Icon(Icons.circle_outlined),
    );
  }

  Widget _buildPaperSizeTile(String title, String value) {
    final isSelected = _selectedPaperSize == value;
    return ListTile(
      onTap: () => setState(() => _selectedPaperSize = value),
      leading: Icon(Icons.description_outlined, color: isSelected ? AppColors.primaryBlue : context.textSecondary),
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue) : const Icon(Icons.circle_outlined),
    );
  }
}
