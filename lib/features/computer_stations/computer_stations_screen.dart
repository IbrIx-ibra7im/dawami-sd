import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/local/hive_helper.dart';
import '../../data/models/computer_station.dart';

class ComputerStationsScreen extends StatefulWidget {
  const ComputerStationsScreen({super.key});

  @override
  State<ComputerStationsScreen> createState() => _ComputerStationsScreenState();
}

class _ComputerStationsScreenState extends State<ComputerStationsScreen> {
  final HiveHelper _hive = HiveHelper.instance;
  List<ComputerStation> _stations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoading = true);
    final list = await _hive.getComputerStations();
    setState(() {
      _stations = list;
      _isLoading = false;
    });
  }

  void _showAddEditStationDialog([ComputerStation? existing]) {
    final nameCtrl = TextEditingController(text: existing?.machineName ?? '');
    final idCtrl = TextEditingController(text: existing?.machineId ?? '');
    final ipCtrl = TextEditingController(text: existing?.ipAddress ?? '192.168.1.100');
    final locCtrl = TextEditingController(text: existing?.locationName ?? 'المدخل الرئيسي');
    final collegeCtrl = TextEditingController(text: existing?.college ?? 'كلية علوم الحاسوب والتنمية البشرية');

    bool cam = existing?.cameraEnabled ?? true;
    bool bar = existing?.barcodeReaderEnabled ?? true;
    bool bio = existing?.biometricReaderEnabled ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existing == null ? 'تسجيل محطة كمبيوتر جديدة' : 'تعديل محطة الكمبيوتر'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'اسم المحطة *', hintText: 'مثال: محطة المدخل الرئيسي'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: idCtrl,
                    decoration: const InputDecoration(labelText: 'معرف الحاسوب (Machine ID) *', hintText: 'PC-GATE-01'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ipCtrl,
                    decoration: const InputDecoration(labelText: 'عنوان IP *', hintText: '192.168.1.100'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locCtrl,
                    decoration: const InputDecoration(labelText: 'الموقع في الكلية *'),
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const Text('الملحقات والأجهزة المتصلة بالحاسوب', style: TextStyle(fontWeight: FontWeight.bold)),
                  SwitchListTile(
                    title: const Text('كاميرا الكمبيوتر (Webcam)'),
                    value: cam,
                    onChanged: (v) => setDialogState(() => cam = v),
                  ),
                  SwitchListTile(
                    title: const Text('قارئ الباركود USB (Barcode Gun)'),
                    value: bar,
                    onChanged: (v) => setDialogState(() => bar = v),
                  ),
                  SwitchListTile(
                    title: const Text('قارئ البصمة USB (Optical Scanner)'),
                    value: bio,
                    onChanged: (v) => setDialogState(() => bio = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || idCtrl.text.trim().isEmpty) return;
                final station = ComputerStation(
                  id: existing?.id ?? 'STATION-${DateTime.now().millisecondsSinceEpoch}',
                  machineName: nameCtrl.text.trim(),
                  machineId: idCtrl.text.trim(),
                  ipAddress: ipCtrl.text.trim(),
                  locationName: locCtrl.text.trim(),
                  college: collegeCtrl.text.trim(),
                  cameraEnabled: cam,
                  barcodeReaderEnabled: bar,
                  biometricReaderEnabled: bio,
                  lastSeenAt: DateTime.now().toIso8601String(),
                );
                await _hive.saveComputerStation(station);
                Navigator.pop(ctx);
                await _loadStations();
              },
              child: const Text('حفظ المحطة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('ربط وإدارة محطات الكمبيوتر داخل الكلية'),
        backgroundColor: AppColors.darkBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'إضافة محطة كمبيوتر',
            onPressed: () => _showAddEditStationDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _stations.length,
              itemBuilder: (context, idx) {
                final s = _stations[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.computer_rounded, color: AppColors.primaryBlue, size: 28),
                    ),
                    title: Text(s.machineName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('المعرف: ${s.machineId} | IP: ${s.ipAddress} | الموقع: ${s.locationName}'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (s.cameraEnabled)
                              Chip(
                                label: const Text('الكاميرا', style: TextStyle(fontSize: 11)),
                                avatar: const Icon(Icons.camera_alt, size: 14),
                              ),
                            if (s.barcodeReaderEnabled)
                              Chip(
                                label: const Text('قارئ باركود USB', style: TextStyle(fontSize: 11)),
                                avatar: const Icon(Icons.qr_code_scanner, size: 14),
                              ),
                            if (s.biometricReaderEnabled)
                              Chip(
                                label: const Text('قارئ بصمة USB', style: TextStyle(fontSize: 11)),
                                avatar: const Icon(Icons.fingerprint, size: 14),
                              ),
                          ],
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_rounded, color: AppColors.primaryBlue),
                      onPressed: () => _showAddEditStationDialog(s),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
