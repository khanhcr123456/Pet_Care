import 'package:flutter/material.dart';
import 'package:pet_care/screens/booking_screen.dart';
import 'package:pet_care/services/auth_service.dart';

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
      final vets = await AuthService().getVets(limit: 50); // Get more on a dedicated page
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        title: const Text('Đội ngũ Bác sĩ', style: TextStyle(color: Color(0xFFF07E2B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFF07E2B),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF07E2B)))
          : _vets.isEmpty
              ? const Center(child: Text('Không có dữ liệu bác sĩ', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _vets.length,
                  itemBuilder: (context, index) {
                    final doc = _vets[index];
                    final docName = doc['fullName'] ?? doc['name'] ?? 'Bác sĩ';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.transparent,
                            backgroundImage: (doc['avatar'] != null && doc['avatar'].toString().startsWith('http'))
                                ? NetworkImage(doc['avatar']) as ImageProvider
                                : const AssetImage('assets/images/default_vet.png'),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(docName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F2E53))),
                                const SizedBox(height: 4),
                                Text(doc['specialization'] ?? 'Bác sĩ thú y', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                                const SizedBox(height: 8),
                                if (doc['experience'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFFFFF9E6), borderRadius: BorderRadius.circular(10)),
                                    child: Text('${doc['experience']} năm kinh nghiệm', style: const TextStyle(fontSize: 12, color: Color(0xFFF07E2B), fontWeight: FontWeight.w600)),
                                  ),
                                if (doc['email'] != null || doc['phone'] != null) ...[
                                  const SizedBox(height: 8),
                                  const Divider(color: Color(0xFFE5E7EB), height: 1),
                                  const SizedBox(height: 8),
                                  if (doc['email'] != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(child: Text(doc['email'], style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  if (doc['phone'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(doc['phone'], style: const TextStyle(fontSize: 12, color: Colors.grey))),
                                        ],
                                      ),
                                    ),
                                ],
                                const SizedBox(height: 16),
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
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Đặt lịch ngay', style: TextStyle(fontWeight: FontWeight.bold)),
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
