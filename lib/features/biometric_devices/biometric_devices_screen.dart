import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/permissions/role_manager.dart';
import '../../core/services/biometric_device_service.dart';
import '../../data/models/biometric_device.dart';
import '../../data/repositories/app_repository.dart';

class BiometricDevicesScreen extends StatefulWidget {
  const BiometricDevicesScreen({super.key});

  @override
  State<BiometricDevicesScreen> createState() => _BiometricDevicesScreenState();
}

class _BiometricDevicesScreenState extends State<BiometricDevicesScreen> {
  final BiometricDeviceService _deviceService = BiometricDeviceService.instance;
  bool _isLoading = false;
  String? _testingDeviceId;

  @override
  void initState() {
    super.initState();
    _refreshDevices();
  }

  Future<void> _refreshDevices() async {
    setState(() => _isLoading = true);
    await context.read<AppRepository>().refreshBiometricDevices();
    setState(() => _isLoading = false);
  }

  void _showAddEditDeviceDialog([BiometricDevice? existing]) {
    final nameCtrl = TextEditingController(text: existing?.deviceName ?? '');
    final serialCtrl = TextEditingController(text: existing?.serialNumber ?? '');
    final ipCtrl = TextEditingController(text: existing?.ipAddress ?? '192.168.1.201');
    final portCtrl = TextEditingController(text: existing != null ? existing.port.toString() : '4370');
    final locationCtrl = TextEditingController(text: existing?.locationName ?? 'المدخل الرئيسي');
    final collegeCtrl = TextEditingController(text: existing?.college ?? 'كلية علوم الحاسوب والتنمية البشرية');
    final deptCtrl = TextEditingController(text: existing?.department ?? 'عام');

    String selectedVendor = existing?.vendor ?? 'ZKTeco';
    String selectedModel = existing?.model ?? 'ZK-F18';
    String selectedProtocol = existing?.protocol ?? 'TCP/IP';
    bool isActive = existing?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existing == null ? 'إضافة جهاز بصمة جديد' : 'تعديل بيانات جهاز البصمة'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الجهاز التعريفي *',
                      hintText: 'مثال: جهاز بصمة بوابة الكلية الشرقية',
                      prefixIcon: Icon(Icons.devices_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedVendor,
                          decoration: const InputDecoration(labelText: 'الشركة المصنعة'),
                          items: const [
                            DropdownMenuItem(value: 'ZKTeco', child: Text('ZKTeco')),
                            DropdownMenuItem(value: 'Anviz', child: Text('Anviz')),
                            DropdownMenuItem(value: 'Suprema', child: Text('Suprema')),
                            DropdownMenuItem(value: 'Realand', child: Text('Realand')),
                            DropdownMenuItem(value: 'Generic', child: Text('جهاز شبكي قياسي')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedVendor = val;
                                if (val == 'ZKTeco') selectedModel = 'ZK-F18';
                                if (val == 'Anviz') selectedModel = 'W2 Pro';
                                if (val == 'Suprema') selectedModel = 'BioStation 2';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: serialCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الرقم التسلسلي (S/N) *',
                            hintText: 'مثال: ZK88291039',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: ipCtrl,
                          decoration: const InputDecoration(
                            labelText: 'عنوان IP للجهاز *',
                            hintText: '192.168.1.201',
                            prefixIcon: Icon(Icons.network_check_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: portCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المنفذ (Port) *',
                            hintText: '4370',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'موقع الجهاز داخل الجامعة *',
                      hintText: 'مثال: البوابة الغربية - مدخل الطلاب',
                      prefixIcon: Icon(Icons.location_on_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: collegeCtrl,
                          decoration: const InputDecoration(labelText: 'الكلية التابع لها'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: deptCtrl,
                          decoration: const InputDecoration(labelText: 'القسم التابع له'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('تفعيل الجهاز في النظام'),
                    value: isActive,
                    onChanged: (val) => setDialogState(() => isActive = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded, color: Colors.white),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
              label: const Text('حفظ الجهاز', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final serial = serialCtrl.text.trim();
                final ip = ipCtrl.text.trim();
                final port = int.tryParse(portCtrl.text.trim()) ?? 4370;
                final location = locationCtrl.text.trim();

                if (name.isEmpty || serial.isEmpty || ip.isEmpty || location.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء جميع الحقول الإلزامية (*)')),
                  );
                  return;
                }

                final device = BiometricDevice(
                  id: existing?.id ?? 'DEV-${DateTime.now().millisecondsSinceEpoch}',
                  deviceName: name,
                  serialNumber: serial,
                  vendor: selectedVendor,
                  model: selectedModel,
                  ipAddress: ip,
                  port: port,
                  protocol: selectedProtocol,
                  locationName: location,
                  college: collegeCtrl.text.trim(),
                  department: deptCtrl.text.trim(),
                  status: existing?.status ?? 'غير متصل',
                  isActive: isActive,
                );

                await _deviceService.saveDevice(device);
                if (mounted) {
                  Navigator.pop(ctx);
                  await _refreshDevices();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم حفظ جهاز البصمة ($name) بنجاح'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testConnection(BiometricDevice device) async {
    setState(() => _testingDeviceId = device.id);
    final result = await _deviceService.testDeviceConnection(device);
    setState(() => _testingDeviceId = null);
    await _refreshDevices();

    if (!mounted) return;
    final bool connected = result['connected'] == true;
    final String message = result['message'] ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: connected ? AppColors.success : AppColors.danger,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final devices = repo.biometricDevices;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canManage = RoleManager.canManageBiometricDevices(repo.currentRole);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('إدارة أجهزة البصمة الحيوية'),
        backgroundColor: AppColors.darkBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'فحص الاتصال بجميع الأجهزة',
            onPressed: () async {
              setState(() => _isLoading = true);
              await _deviceService.pingAllDevices();
              await _refreshDevices();
              setState(() => _isLoading = false);
            },
          ),
          if (canManage)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                label: const Text('إضافة جهاز', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.turquoise),
                onPressed: () => _showAddEditDeviceDialog(),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint_rounded, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'لا توجد أجهزة بصمة مسجلة حالياً',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('يمكنك إضافة عدد غير محدود من أجهزة البصمة لمختلف الكليات والأقسام'),
                      const SizedBox(height: 20),
                      if (canManage)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('إضافة أول جهاز بصمة'),
                          onPressed: () => _showAddEditDeviceDialog(),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final d = devices[index];
                    final isOnline = d.isConnected;
                    final isTesting = _testingDeviceId == d.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (isOnline ? AppColors.success : AppColors.danger).withAlpha(25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.fingerprint_rounded,
                                    color: isOnline ? AppColors.success : AppColors.danger,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d.deviceName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'الشركة: ${d.vendor} | الطراز: ${d.model} | S/N: ${d.serialNumber}',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isOnline ? AppColors.success : AppColors.danger).withAlpha(30),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isOnline ? AppColors.success : AppColors.danger,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        d.status,
                                        style: TextStyle(
                                          color: isOnline ? AppColors.success : AppColors.danger,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('العنوان الشبكي: ${d.ipAddress}:${d.port}', style: const TextStyle(fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text('الموقع: ${d.locationName}', style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('الكلية: ${d.college}', style: const TextStyle(fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(
                                        d.latencyMs != null ? 'زمن الاستجابة: ${d.latencyMs} ms' : 'لم يتم قياس السرعة',
                                        style: TextStyle(fontSize: 12, color: isOnline ? AppColors.success : Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  icon: isTesting
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.network_ping_rounded, size: 16),
                                  label: Text(isTesting ? 'جارٍ الفحص...' : 'اختبار الاتصال الحقيقي'),
                                  onPressed: isTesting ? null : () => _testConnection(d),
                                ),
                                const SizedBox(width: 10),
                                if (canManage) ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.primaryBlue),
                                    tooltip: 'تعديل البيانات',
                                    onPressed: () => _showAddEditDeviceDialog(d),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                                    tooltip: 'حذف الجهاز',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('حذف جهاز البصمة'),
                                          content: Text('هل أنت متأكد من حذف الجهاز (${d.deviceName})؟'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                                              onPressed: () => Navigator.pop(c, true),
                                              child: const Text('حذف', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await _deviceService.deleteDevice(d.id);
                                        await _refreshDevices();
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
