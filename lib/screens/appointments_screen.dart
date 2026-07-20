import 'package:flutter/material.dart';
import 'package:pet_care/services/booking_service.dart';
import 'package:pet_care/screens/booking_screen.dart';
import 'package:pet_care/screens/pet_detail_screen.dart';
import 'package:pet_care/utils/responsive.dart';
import 'package:shimmer/shimmer.dart';

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
          _appointments = List.from(data);
          
          // Sắp xếp giảm dần (mới nhất lên trên) theo ngày và giờ
          _appointments.sort((a, b) {
            DateTime aDate = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime.now();
            DateTime bDate = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime.now();
            
            String aTime = '';
            if (a['timeSlot'] != null && a['timeSlot'] is Map) {
              aTime = a['timeSlot']['startTime'] ?? '';
            } else {
              aTime = a['startTime'] ?? '';
            }
            String bTime = '';
            if (b['timeSlot'] != null && b['timeSlot'] is Map) {
              bTime = b['timeSlot']['startTime'] ?? '';
            } else {
              bTime = b['startTime'] ?? '';
            }

            if (aTime.isNotEmpty && aTime.contains(':')) {
              final parts = aTime.split(':');
              if (parts.length >= 2) {
                int h = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                int m = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                if (aTime.toLowerCase().contains('pm') && h < 12) h += 12;
                if (aTime.toLowerCase().contains('am') && h == 12) h = 0;
                aDate = DateTime(aDate.year, aDate.month, aDate.day, h, m);
              }
            }
            if (bTime.isNotEmpty && bTime.contains(':')) {
              final parts = bTime.split(':');
              if (parts.length >= 2) {
                int h = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                int m = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                if (bTime.toLowerCase().contains('pm') && h < 12) h += 12;
                if (bTime.toLowerCase().contains('am') && h == 12) h = 0;
                bDate = DateTime(bDate.year, bDate.month, bDate.day, h, m);
              }
            }
            
            return bDate.compareTo(aDate);
          });
          
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

  Widget _buildAppointmentShimmer(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.all(R.hPad(context)),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade50,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hPad = R.hPad(context);

    final content = _isLoading
        ? _buildAppointmentShimmer(context)
        : _appointments.isEmpty
            ? Center(
                child: Text('Bạn chưa có lịch khám nào.', style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 15))),
              )
            : ListView.builder(
                padding: EdgeInsets.all(hPad),
                itemCount: _appointments.length,
                  itemBuilder: (context, index) {
                    final appt = _appointments[index];
                    final dateStr = appt['date'] ?? '';
                    String formattedDate = dateStr;
                    if (dateStr.isNotEmpty) {
                      final parts = dateStr.split('-');
                      if (parts.length >= 3) {
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
                    final status = (appt['status']?.toString().toLowerCase() ?? 'chờ_xác_nhận').replaceAll(' ', '_');
                    
                    Color statusColor = Colors.orange;
                    String statusText = 'Chờ xác nhận';
                    if (status == 'đã_xác_nhận' || status == 'confirmed') {
                      statusColor = Colors.blue;
                      statusText = 'Đã xác nhận';
                    } else if (status == 'đang_khám') {
                      statusColor = Colors.purple;
                      statusText = 'Đang khám';
                    } else if (status == 'hoàn_thành' || status == 'completed') {
                      statusColor = Colors.green;
                      statusText = 'Hoàn thành';
                    } else if (status == 'đã_hủy' || status == 'cancelled') {
                      statusColor = Colors.red;
                      statusText = 'Đã hủy';
                    }

                    final petIdStr = (appt['pet'] is Map) ? (appt['pet']['_id'] ?? appt['pet']['id']) : ((appt['petId'] is Map) ? (appt['petId']['_id'] ?? appt['petId']['id']) : (appt['petId'] ?? appt['pet']));
                    
                    return GestureDetector(
                      onTap: () {
                        if (petIdStr != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PetDetailScreen(
                                petId: petIdStr.toString(),
                                user: widget.user,
                              ),
                            ),
                          ).then((_) {
                            setState(() => _isLoading = true);
                            _fetchAppointments();
                          });
                        }
                      },
                      child: Card(
                        margin: EdgeInsets.only(bottom: R.isSmall(context) ? 12 : 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: EdgeInsets.all(R.isSmall(context) ? 12 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$formattedDate $startTime'.trim(),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 15), color: const Color(0xFF0F2E53)),
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
                                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: R.sp(context, 11)),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: R.isSmall(context) ? 8 : 12),
                            Row(
                              children: [
                                Icon(Icons.medical_services, size: R.iconSm(context) - 2, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Dịch vụ: $serviceName', style: TextStyle(fontSize: R.sp(context, 13)))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.person, size: R.iconSm(context) - 2, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Bác sĩ: $vetName', style: TextStyle(fontSize: R.sp(context, 13)))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.pets, size: R.iconSm(context) - 2, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Thú cưng: $petName', style: TextStyle(fontSize: R.sp(context, 13)))),
                              ],
                            ),
                            if (status == 'hoàn_thành' || status == 'completed') ...[
                              SizedBox(height: R.isSmall(context) ? 12 : 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => _viewResult(appt),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0F4C81),
                                    side: const BorderSide(color: Color(0xFF0F4C81)),
                                    padding: EdgeInsets.symmetric(vertical: R.isSmall(context) ? 10 : 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text(
                                    serviceName.toLowerCase().contains('tiêm') ? 'Xem thông tin bản tiêm' : 'Xem kết quả',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 13)),
                                  ),
                                ),
                              ),
                            ] else if (status != 'hoàn_thành' && status != 'completed' && status != 'đã_hủy' && status != 'cancelled') ...[
                              SizedBox(height: R.isSmall(context) ? 12 : 16),
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
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hủy lịch thành công')));
                                        setState(() => _isLoading = true);
                                        _fetchAppointments();
                                      } catch (e) {
                                        if (!mounted) return;
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}')));
                                      }
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    padding: EdgeInsets.symmetric(vertical: R.isSmall(context) ? 10 : 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text('Hủy lịch', style: TextStyle(fontSize: R.sp(context, 13))),
                                ),
                              ),
                            ],
                          ],
                        ),
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
          setState(() => _isLoading = true);
          _fetchAppointments();
        });
      },
      backgroundColor: const Color(0xFF0F2E53),
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text('Tạo lịch hẹn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: R.sp(context, 13))),
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
        title: Text(
          'Lịch Khám Của Tôi',
          style: TextStyle(color: const Color(0xFFF07E2B), fontWeight: FontWeight.bold, fontSize: R.sp(context, 18)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFF07E2B),
        elevation: 0,
      ),
      body: content,
      floatingActionButton: fab,
    );
  }

  void _viewResult(dynamic appt) async {
    final petId = (appt['pet'] is Map) ? (appt['pet']['_id'] ?? appt['pet']['id']) : appt['pet'];
    final apptId = appt['_id'] ?? appt['id'];
    if (petId == null || apptId == null) return;

    final isVaccine = appt['service'] != null && appt['service'] is Map 
        ? (appt['service']['name'] ?? '').toString().toLowerCase().contains('tiêm') 
        : false;

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    
    try {
      if (isVaccine) {
        final vaccines = await BookingService().getVaccinationsByPetId(widget.user['token'], petId.toString());
        var targetVax;
        for (var v in vaccines) {
          final aId = v['appointment'] is Map ? (v['appointment']['_id'] ?? v['appointment']['id']) : v['appointment'];
          if (aId == apptId) { targetVax = v; break; }
        }
        if (!mounted) return;
        Navigator.pop(context);
        
        if (targetVax != null) {
          _showVaccinationDialog(targetVax);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy bản tiêm nào.')));
        }
      } else {
        final records = await BookingService().getHealthRecordsByPetId(widget.user['token'], petId.toString());
        var targetHr;
        for (var r in records) {
          final aId = r['appointment'] is Map ? (r['appointment']['_id'] ?? r['appointment']['id']) : r['appointment'];
          if (aId == apptId) { targetHr = r; break; }
        }
        if (!mounted) return;
        Navigator.pop(context);
        
        if (targetHr != null) {
          _showHealthRecordDialog(targetHr);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy kết quả khám nào.')));
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  void _showVaccinationDialog(dynamic vaxData) {
    final vaxName = vaxData['vaccineName'] ?? vaxData['name'] ?? 'Không xác định';
    final disease = vaxData['disease'] ?? 'Không có thông tin';
    final status = vaxData['status'] ?? 'Đã tiêm';
    String dateAdmin = '';
    if (vaxData['dateAdministered'] != null) {
      final p = vaxData['dateAdministered'].toString().split('T')[0].split('-');
      if (p.length >= 3) dateAdmin = '${p[2]}/${p[1]}/${p[0]}';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Thông tin tiêm phòng', style: TextStyle(fontSize: R.sp(context, 17), fontWeight: FontWeight.bold, color: const Color(0xFF0F4C81))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Tên vaccine:', vaxName),
            _buildDetailRow('Ngày tiêm:', dateAdmin.isNotEmpty ? dateAdmin : '--/--/----'),
            _buildDetailRow('Trạng thái:', status),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng', style: TextStyle(color: Color(0xFF0F4C81))),
          ),
        ],
      ),
    );
  }

  void _showHealthRecordDialog(dynamic hrData) {
    final generalAssessment = hrData['generalAssessment'] ?? hrData['diagnosis'] ?? 'Không có thông tin';
    final consultation = hrData['consultation'] ?? hrData['notes'] ?? 'Không có';
    final weight = hrData['weight']?.toString() ?? '--';
    final temperature = hrData['temperature']?.toString() ?? '--';
    
    String dateAdmin = '';
    if (hrData['examinationDate'] != null) {
      final p = hrData['examinationDate'].toString().split('T')[0].split('-');
      if (p.length >= 3) dateAdmin = '${p[2]}/${p[1]}/${p[0]}';
    } else if (hrData['date'] != null) {
      final p = hrData['date'].toString().split('T')[0].split('-');
      if (p.length >= 3) dateAdmin = '${p[2]}/${p[1]}/${p[0]}';
    }

    final List<String> imageUrls = [];
    final rawImages = hrData['images'];
    if (rawImages is List) {
      for (var img in rawImages) {
        if (img is String && img.isNotEmpty) {
          imageUrls.add(img);
        } else if (img is Map) {
          final url = img['url']?.toString() ?? img['path']?.toString() ?? '';
          if (url.isNotEmpty) imageUrls.add(url);
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kết quả khám bệnh', style: TextStyle(fontSize: R.sp(context, 17), fontWeight: FontWeight.bold, color: const Color(0xFF0F4C81))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Ngày khám:', dateAdmin.isNotEmpty ? dateAdmin : '--/--/----'),
              _buildDetailRow('Đánh giá chung:', generalAssessment),
              _buildDetailRow('Tư vấn:', consultation),
              _buildDetailRow('Cân nặng:', '$weight kg'),
              _buildDetailRow('Nhiệt độ:', '$temperature °C'),
              if (imageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Hình ảnh', style: TextStyle(fontSize: R.sp(context, 13), fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: imageUrls.map((url) => GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      builder: (c) => Dialog(
                        child: InteractiveViewer(
                          child: Image.network(url, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng', style: TextStyle(color: Color(0xFF0F4C81))),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: R.sp(context, 12), color: Colors.grey))),
          Expanded(flex: 3, child: Text(value, style: TextStyle(fontSize: R.sp(context, 12), fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
