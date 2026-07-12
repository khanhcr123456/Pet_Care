import 'package:flutter/material.dart';
import 'package:pet_care/screens/booking_screen.dart';
import 'package:pet_care/services/auth_service.dart';
import 'package:pet_care/utils/responsive.dart';
import 'package:shimmer/shimmer.dart';

class VetsScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const VetsScreen({super.key, this.user});

  @override
  State<VetsScreen> createState() => _VetsScreenState();
}

class _VetsScreenState extends State<VetsScreen> {
  List<dynamic> _vets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVets();
  }

  Future<void> _fetchVets() async {
    try {
      final vets = await AuthService().getVets(limit: 50);
      if (mounted) {
        setState(() {
          _vets = vets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarRadius = R.isSmall(context) ? 34.0 : 40.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        title: Text(
          'Đội ngũ Bác sĩ',
          style: TextStyle(color: const Color(0xFFF07E2B), fontWeight: FontWeight.bold, fontSize: R.sp(context, 18)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFF07E2B),
        elevation: 0,
      ),
      body: _isLoading
          ? ListView.builder(
              padding: EdgeInsets.all(R.hPad(context)),
              itemCount: 5,
              itemBuilder: (_, __) => Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade50,
                child: Container(
                  margin: EdgeInsets.only(bottom: R.isSmall(context) ? 12 : 16),
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            )
          : _vets.isEmpty
              ? Center(child: Text('Không có dữ liệu bác sĩ', style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 14))))
              : ListView.builder(
                  padding: EdgeInsets.all(R.hPad(context)),
                  itemCount: _vets.length,
                  itemBuilder: (context, index) {
                    final doc = _vets[index];
                    final docName = doc['fullName'] ?? doc['name'] ?? 'Bác sĩ';
                    return Container(
                      margin: EdgeInsets.only(bottom: R.isSmall(context) ? 12 : 16),
                      padding: EdgeInsets.all(R.hPad(context)),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: avatarRadius,
                            backgroundColor: Colors.transparent,
                            backgroundImage: (doc['avatar'] != null && doc['avatar'].toString().startsWith('http'))
                                ? NetworkImage(doc['avatar']) as ImageProvider
                                : const AssetImage('assets/images/default_vet.png'),
                          ),
                          SizedBox(width: R.isSmall(context) ? 12 : 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(docName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 17), color: const Color(0xFF0F2E53))),
                                const SizedBox(height: 4),
                                Text(doc['specialization'] ?? 'Bác sĩ thú y', style: TextStyle(color: Colors.grey, fontSize: R.sp(context, 13))),
                                const SizedBox(height: 8),
                                if (doc['experience'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFFFFF9E6), borderRadius: BorderRadius.circular(10)),
                                    child: Text('${doc['experience']} năm kinh nghiệm', style: TextStyle(fontSize: R.sp(context, 12), color: const Color(0xFFF07E2B), fontWeight: FontWeight.w600)),
                                  ),
                                if (doc['email'] != null || doc['phone'] != null) ...[
                                  const SizedBox(height: 8),
                                  const Divider(color: Color(0xFFE5E7EB), height: 1),
                                  const SizedBox(height: 8),
                                  if (doc['email'] != null)
                                    Row(
                                      children: [
                                        Icon(Icons.email_outlined, size: R.iconSm(context) - 2, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(child: Text(doc['email'], style: TextStyle(fontSize: R.sp(context, 12), color: Colors.grey), overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  if (doc['phone'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Icon(Icons.phone_outlined, size: R.iconSm(context) - 2, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(doc['phone'], style: TextStyle(fontSize: R.sp(context, 12), color: Colors.grey))),
                                        ],
                                      ),
                                    ),
                                ],
                                SizedBox(height: R.isSmall(context) ? 12 : 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (widget.user == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để đặt lịch khám!')));
                                        return;
                                      }
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => BookingScreen(
                                          user: widget.user!,
                                          initialVetId: doc['_id'] ?? doc['id'],
                                        )),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF07E2B),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: EdgeInsets.symmetric(vertical: R.isSmall(context) ? 10 : 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text('Đặt lịch ngay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 14))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
