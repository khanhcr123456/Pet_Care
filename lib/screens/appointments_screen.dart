import 'package:flutter/material.dart';
import 'package:pet_care/services/booking_service.dart';
import 'package:pet_care/screens/booking_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool isEmbedded;

  const AppointmentsScreen({super.key, required this.user, this.isEmbedded = false});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  bool _isLoading = true;
  List<dynamic> _appointments = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    try {
      final data = await BookingService().getAppointments(widget.user['token']);
      if (mounted) {
        setState(() {
          _appointments = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi tải danh sách lịch khám')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFF07E2B)))
        : _appointments.isEmpty
            ? const Center(
                child: Text('Bạn chưa có lịch khám nào.', style: TextStyle(color: Colors.grey, fontSize: 16)),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _appointments.length,
                  itemBuilder: (context, index) {
                    final appt = _appointments[index];
                    final dateStr = appt['date'] ?? '';
                    String formattedDate = dateStr;
                    if (dateStr.isNotEmpty) {
                      final parts = dateStr.split('-');
                      if (parts.length >= 3) {
                        // Handle potential time parts in the date string just in case
                        final day = parts[2].split('T')[0]; 
                        formattedDate = '$day/${parts[1]}/${parts[0]}';
                      }
                    }
                    
                    String startTime = '';
                    if (appt['timeSlot'] != null && appt['timeSlot'] is Map) {
                      startTime = appt['timeSlot']['startTime'] ?? '';
                    } else if (appt['startTime'] != null) {
                      startTime = appt['startTime'];
                    }

                    final vetName = (appt['vet'] is Map) ? (appt['vet']['fullName'] ?? appt['vet']['name'] ?? 'Bác sĩ') : 'Bác sĩ';
                    final petName = (appt['pet'] is Map) ? (appt['pet']['name'] ?? 'Thú cưng') : 'Thú cưng';
                    final serviceName = (appt['service'] is Map) ? (appt['service']['name'] ?? 'Dịch vụ') : 'Dịch vụ';
                    final status = (appt['status']?.toString().toLowerCase() ?? 'pending');
                    
                    Color statusColor = Colors.orange;
                    String statusText = 'Chờ xác nhận';
                    if (status == 'confirmed') {
                      statusColor = Colors.blue;
                      statusText = 'Đã xác nhận';
                    } else if (status == 'completed') {
                      statusColor = Colors.green;
                      statusText = 'Hoàn thành';
                    } else if (status == 'cancelled') {
                      statusColor = Colors.red;
                      statusText = 'Đã hủy';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$formattedDate $startTime'.trim(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F2E53)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.medical_services, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Dịch vụ: $serviceName')),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.person, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Bác sĩ: $vetName')),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.pets, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Thú cưng: $petName')),
                              ],
                            ),
                            if (status != 'completed' && status != 'cancelled') ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Xác nhận hủy'),
                                        content: const Text('Bạn có chắc chắn muốn hủy lịch khám này không?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('Không'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Có, hủy', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      if (!mounted) return;
                                      try {
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (ctx) => const Center(child: CircularProgressIndicator()),
                                        );
                                        final apptId = appt['_id'] ?? appt['id'];
                                        await BookingService().cancelAppointment(widget.user['token'], apptId);
                                        if (!mounted) return;
                                        Navigator.pop(context); // close progress dialog
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hủy lịch thành công')));
                                        setState(() => _isLoading = true);
                                        _fetchAppointments();
                                      } catch (e) {
                                        if (!mounted) return;
                                        Navigator.pop(context); // close progress dialog
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}')));
                                      }
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Hủy lịch'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );

    final fab = FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BookingScreen(user: widget.user)),
        ).then((_) {
          // Refresh list when coming back
          setState(() => _isLoading = true);
          _fetchAppointments();
        });
      },
      backgroundColor: const Color(0xFF0F2E53),
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('Tạo lịch hẹn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );

    if (widget.isEmbedded) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6FAFD),
        body: content,
        floatingActionButton: fab,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        title: const Text('Lịch Khám Của Tôi', style: TextStyle(color: Color(0xFFF07E2B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFF07E2B),
        elevation: 0,
      ),
      body: content,
      floatingActionButton: fab,
    );
  }
}
