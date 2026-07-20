import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pet_care/services/admin_firebase_service.dart';
import 'package:pet_care/services/admin_service.dart';
import 'package:pet_care/services/remote_config_service.dart';
import 'package:pet_care/utils/responsive.dart';

class AdminFirebaseScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminFirebaseScreen({super.key, required this.user});

  @override
  State<AdminFirebaseScreen> createState() => _AdminFirebaseScreenState();
}

class _AdminFirebaseScreenState extends State<AdminFirebaseScreen> {
  final AdminFirebaseService _service = AdminFirebaseService();
  final TextEditingController _notificationTitleController = TextEditingController(text: 'Hệ thống bảo trì');
  final TextEditingController _notificationBodyController = TextEditingController(text: 'Ứng dụng sẽ bảo trì vào 12h đêm nay.');
  bool _isLoading = true;
  bool _isSendingNotification = false;

  Map<String, dynamic>? _remoteConfigData;
  Map<String, dynamic>? _fcmBoardData;
  Map<String, dynamic>? _analyticsData;
  Map<String, dynamic>? _firebaseUsersData;
  String? _error;
  String _searchUserQuery = '';

  // ---- CÁC HÀM XỬ LÝ NHƯ TRONG ADMIN_USERS_TAB ----
  String _formatDateTab(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return '—';
    final str = raw.toString();
    try {
      DateTime? dt;
      final ms = int.tryParse(str);
      if (ms != null) {
        dt = DateTime.fromMillisecondsSinceEpoch(ms);
      } else if (str.contains('GMT')) {
        dt = HttpDate.parse(str).toLocal();
      } else {
        dt = DateTime.tryParse(str)?.toLocal();
      }
      if (dt != null) {
        return DateFormat('HH:mm dd/MM/yyyy').format(dt);
      }
    } catch (_) {}
    return str;
  }

  Future<void> _toggleDisable(String uid, bool disable) async {
    Navigator.pop(context); // Tắt bottom sheet
    try {
      await AdminService().disableFirebaseUser(widget.user['token'], uid, disable);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(disable ? 'Đã vô hiệu hóa tài khoản' : 'Đã kích hoạt lại tài khoản'),
        backgroundColor: disable ? Colors.orange : Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _confirmDelete(String uid) async {
    Navigator.pop(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 10), Text('Xóa tài khoản')]),
        content: const Text('Bạn có chắc muốn xóa vĩnh viễn tài khoản này khỏi Firebase không? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await AdminService().deleteFirebaseUser(widget.user['token'], uid);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa tài khoản'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
        _fetchData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      }
    }
  }

  Widget _detailRow(IconData icon, String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 2),
          Row(children: [
            Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
            if (copyable) GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép UID'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)));
              },
              child: const Icon(Icons.copy, size: 16, color: Colors.grey),
            )
          ]),
        ])),
      ]),
    );
  }

  void _showUserDetails(Map<String, dynamic> u) {
    final uid = u['uid'] ?? u['localId'] ?? '';
    final email = u['email'] ?? 'Không có email';
    final emailVerified = u['emailVerified'] == true;
    final disabled = u['disabled'] == true;
    final displayName = u['displayName'] ?? u['name'] ?? '';
    final phone = u['phoneNumber'] ?? '';
    final photoURL = u['photoURL'] ?? u['photoUrl'] ?? '';
    final metadata = u['metadata'] as Map<String, dynamic>?;
    final createdAt = _formatDateTab(u['createdAt'] ?? metadata?['creationTime'] ?? u['created']);
    final lastLogin = _formatDateTab(u['lastSignedIn'] ?? u['lastLoginAt'] ?? u['lastSignInTime'] ?? metadata?['lastSignInTime'] ?? u['lastLogin']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Center(child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              )),
              Expanded(child: ListView(
                controller: sc,
                padding: const EdgeInsets.all(20),
                children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
                      backgroundColor: const Color(0xFF0F2E53),
                      child: photoURL.isEmpty ? Text(email.isNotEmpty ? email[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 22)) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(displayName.isNotEmpty ? displayName : email, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(disabled ? Icons.block : Icons.check_circle, size: 16, color: disabled ? Colors.red : Colors.green),
                        const SizedBox(width: 4),
                        Text(disabled ? 'Bị vô hiệu hóa' : 'Đang hoạt động', style: TextStyle(color: disabled ? Colors.red : Colors.green, fontSize: 13)),
                      ]),
                    ])),
                  ]),
                  const SizedBox(height: 20),
                  const Divider(),
                  _detailRow(Icons.fingerprint, 'UID', uid.toString(), copyable: true),
                  _detailRow(Icons.email, 'Email', email),
                  _detailRow(Icons.verified, 'Email đã xác thực', emailVerified ? 'Có' : 'Chưa'),
                  if (phone.isNotEmpty) _detailRow(Icons.phone, 'Số điện thoại', phone),
                  _detailRow(Icons.calendar_today, 'Ngày tạo', createdAt),
                  _detailRow(Icons.access_time, 'Đăng nhập gần nhất', lastLogin),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: disabled ? () => _toggleDisable(uid.toString(), false) : () => _toggleDisable(uid.toString(), true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: disabled ? Colors.green : Colors.orange,
                            side: BorderSide(color: disabled ? Colors.green : Colors.orange),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(disabled ? Icons.check_circle_outline : Icons.block_outlined, size: 18),
                          label: Text(disabled ? 'Kích hoạt lại tài khoản' : 'Vô hiệu hóa tài khoản', overflow: TextOverflow.ellipsis, maxLines: 1),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmDelete(uid.toString()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Xóa tài khoản khỏi Firebase', overflow: TextOverflow.ellipsis, maxLines: 1),
                        ),
                      ),
                    ],
                  ),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }


  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Thay Đổi Giao Diện Firebase', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
            const SizedBox(height: 16),
            ...['NORMAL', 'NOEL', 'TET', 'HALLOWEEN'].map((theme) {
              final current = RemoteConfigService().themeEvent.toUpperCase();
              return ListTile(
                title: Text(theme, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: (current == theme || (current.isEmpty && theme == 'NORMAL')) ? const Icon(Icons.check_circle, color: Colors.green) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    // Hiển thị loading
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đang gửi API cập nhật Firebase...'), backgroundColor: Colors.orange));
                    await AdminFirebaseService().updateRemoteConfigTheme(widget.user['token'], theme);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật Theme thành công! Đang tải lại...'), backgroundColor: Colors.green));
                    // Ép làm mới
                    await RemoteConfigService().forceFetchAndActivate();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
                  }
                },
              );
            }).toList(),
            const SizedBox(height: 20),
          ]
        )
      )
    );
  }

  // Trạng thái các cột biểu đồ FCM
  bool _showSends = true;
  bool _showReceived = true;
  bool _showImpressions = true;
  bool _showOpenCount = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _notificationTitleController.dispose();
    _notificationBodyController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = widget.user['token'];
      await RemoteConfigService().forceFetchAndActivate();
      final results = await Future.wait([
        _service.getRemoteConfig(token).catchError((e) => {'error': e.toString()}),
        _service.getFcmBoard(token).catchError((e) => {'error': e.toString()}),
        _service.getAnalytics(token).catchError((e) => {'error': e.toString()}),
        _service.getFirebaseUsers(token).catchError((e) => {'error': e.toString()}),
      ]);

      if (mounted) {
        setState(() {
          _remoteConfigData = _extractData(results[0]);
          _fcmBoardData = _extractData(results[1]);
          _analyticsData = _extractData(results[2]);
          _firebaseUsersData = _extractData(results[3]);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _extractData(Map<String, dynamic>? data) {
    if (data == null) return {};
    if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
      return data['data'];
    }
    return data;
  }

  Future<void> _sendNotificationAll() async {
    final title = _notificationTitleController.text.trim();
    final body = _notificationBodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tiêu đề và nội dung thông báo'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_isSendingNotification) return;

    setState(() => _isSendingNotification = true);
    try {
      final result = await _service.sendNotificationAll(
        token: widget.user['token'],
        title: title,
        body: body,
        data: {},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Đã gửi thông báo thành công'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi gửi thông báo: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingNotification = false);
      }
    }
  }

  Widget _buildSendNotificationSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active, color: Color(0xFFF07E2B), size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Gửi thông báo cho toàn bộ hệ thống', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D3B66))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Tạo thông báo nhanh cho người dùng đang dùng ứng dụng.', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 16),
          TextField(
            controller: _notificationTitleController,
            decoration: const InputDecoration(
              labelText: 'Tiêu đề',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notificationBodyController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Nội dung thông báo',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.message_outlined),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSendingNotification ? null : _sendNotificationAll,
              icon: _isSendingNotification
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(_isSendingNotification ? 'Đang gửi...' : 'Gửi thông báo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF07E2B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFcmMetricCheckbox(String title, int value, Color color, bool isChecked, Function(bool?) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: isChecked,
            onChanged: onChanged,
            activeColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Icon(Icons.help_outline, size: 14, color: Colors.grey.shade400),
              ],
            ),
            Text(value.toString(), style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w400)),
          ],
        )
      ],
    );
  }

  Widget _buildFcmBoardSection() {
    final data = _fcmBoardData ?? {};
    
    // Bóc tách dữ liệu Tổng
    int sends = data['sends'] ?? data['totalSent'] ?? data['success'] ?? 0;
    int received = data['received'] ?? 0;
    int impressions = data['impressions'] ?? 0;
    int openCount = data['openCount'] ?? data['opens'] ?? 0;

    // Phân tích dữ liệu THEO TỪNG NGÀY (Lịch sử mảng)
    List<FlSpot> spotSends = [];
    List<FlSpot> spotReceived = [];
    List<FlSpot> spotImpressions = [];
    List<FlSpot> spotOpens = [];
    List<String> xLabels = [];

    List<dynamic> history = [];
    if (data['history'] is List) history = data['history'];
    else if (data['timeline'] is List) history = data['timeline'];
    else if (data['data'] is List) history = data['data'];
    else {
      for (var val in data.values) {
        if (val is List && val.isNotEmpty && (val.first is Map)) {
          history = val;
          break;
        }
      }
    }

    if (history.isNotEmpty) {
      // Sắp xếp tăng dần theo thời gian (nếu có trường ngày/tháng)
      history.sort((a, b) {
        String dateA = (a['date'] ?? a['createdAt'] ?? a['time'] ?? '').toString();
        String dateB = (b['date'] ?? b['createdAt'] ?? b['time'] ?? '').toString();
        return dateA.compareTo(dateB);
      });

      for (int i = 0; i < history.length; i++) {
        var row = history[i];
        
        // Trích xuất label X (nhỏ gọn mm/dd)
        String dateStr = (row['date'] ?? row['createdAt'] ?? row['time'] ?? '').toString();
        if (dateStr.isNotEmpty) {
           if (dateStr.contains('T')) dateStr = dateStr.split('T')[0];
           List<String> parts = dateStr.split('-');
           if (parts.length >= 3) {
             xLabels.add('${parts[2]}/${parts[1]}'); // Đổi thành DD/MM
           } else {
             xLabels.add(dateStr);
           }
        } else {
           xLabels.add('Day ${i+1}');
        }

        // Bóc tách giá trị trục Y của từng ngày
        double rs = double.tryParse((row['sends'] ?? row['success'] ?? row['totalSent'] ?? row['sent'] ?? 0).toString()) ?? 0;
        double rr = double.tryParse((row['received'] ?? row['receive'] ?? 0).toString()) ?? 0;
        double ri = double.tryParse((row['impressions'] ?? row['impression'] ?? 0).toString()) ?? 0;
        double ro = double.tryParse((row['openCount'] ?? row['opens'] ?? row['open'] ?? 0).toString()) ?? 0;

        spotSends.add(FlSpot(i.toDouble(), rs));
        spotReceived.add(FlSpot(i.toDouble(), rr));
        spotImpressions.add(FlSpot(i.toDouble(), ri));
        spotOpens.add(FlSpot(i.toDouble(), ro));
      }
      
      // Update lại biến tổng để khớp chính xác tổng các cột nếu API chưa trả tổng
      if (sends == 0 && spotSends.isNotEmpty) sends = spotSends.map((e) => e.y).reduce((a, b) => a + b).toInt();
      if (received == 0 && spotReceived.isNotEmpty) received = spotReceived.map((e) => e.y).reduce((a, b) => a + b).toInt();
      if (impressions == 0 && spotImpressions.isNotEmpty) impressions = spotImpressions.map((e) => e.y).reduce((a, b) => a + b).toInt();
      if (openCount == 0 && spotOpens.isNotEmpty) openCount = spotOpens.map((e) => e.y).reduce((a, b) => a + b).toInt();
      
    } else {
      // Logic fallback (Chưa có API theo list -> Tạo Dummy)
      spotSends = [const FlSpot(0, 0), FlSpot(8, sends * 0.1), FlSpot(10, sends.toDouble())];
      spotReceived = [const FlSpot(0, 0), FlSpot(10, received.toDouble())];
      spotImpressions = [const FlSpot(0, 0), FlSpot(10, impressions.toDouble())];
      spotOpens = [const FlSpot(0, 0), FlSpot(10, openCount.toDouble())];
      xLabels = ['Apr 26', '', 'May 10', '', 'May 24', '', 'Jun 7', '', 'Jun 28', '', 'Jul 19'];
    }

    double maxY = 15;
    for (var spot in spotSends) { if (spot.y > maxY) maxY = spot.y; }
    for (var spot in spotReceived) { if (spot.y > maxY) maxY = spot.y; }
    maxY = maxY * 1.5; // Dư ra 50% chóp biểu đồ
    
    double maxX = spotSends.isNotEmpty && spotSends.length > 1 ? (spotSends.length - 1).toDouble() : 10.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300)
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list, size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Text('Filter', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    ],
                  ),
                )
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 500;
                
                final metricColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFcmMetricCheckbox('Sends', sends, const Color(0xFF4285F4), _showSends, (v) => setState(() => _showSends = v ?? true)),
                    const SizedBox(height: 16),
                    _buildFcmMetricCheckbox('Received', received, const Color(0xFFF4B400), _showReceived, (v) => setState(() => _showReceived = v ?? true)),
                    const SizedBox(height: 16),
                    _buildFcmMetricCheckbox('Impressions', impressions, const Color(0xFFE91E63), _showImpressions, (v) => setState(() => _showImpressions = v ?? true)),
                    const SizedBox(height: 16),
                    _buildFcmMetricCheckbox('Open count', openCount, const Color(0xFF00BCD4), _showOpenCount, (v) => setState(() => _showOpenCount = v ?? true)),
                  ],
                );

                final chartWidget = AspectRatio(
                  aspectRatio: isWide ? 2.5 : 1.5,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 2,
                        getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: (maxX > 10) ? (maxX / 5).floorToDouble() : 1,
                            getTitlesWidget: (value, meta) {
                              int idx = value.toInt();
                              if (idx >= 0 && idx < xLabels.length) {
                                return Text(xLabels[idx], style: const TextStyle(fontSize: 9, color: Colors.grey));
                              }
                              return const Text('');
                            },
                          )
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            interval: 2,
                            getTitlesWidget: (value, _) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(
                        show: true, 
                        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1), left: BorderSide(color: Colors.grey.shade300, width: 1))
                      ),
                      minX: 0,
                      maxX: maxX,
                      minY: 0,
                      maxY: maxY,
                      lineBarsData: [
                        if (_showSends)
                          LineChartBarData(
                            spots: spotSends,
                            isCurved: true,
                            preventCurveOverShooting: true,
                            color: const Color(0xFF4285F4),
                            barWidth: 2,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3, color: const Color(0xFF4285F4), strokeWidth: 0, strokeColor: Colors.transparent)
                            ),
                          ),
                        if (_showReceived)
                          LineChartBarData(
                            spots: spotReceived,
                            isCurved: true,
                            preventCurveOverShooting: true,
                            color: const Color(0xFFF4B400),
                            barWidth: 2,
                            dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3, color: const Color(0xFFF4B400), strokeWidth: 0, strokeColor: Colors.transparent)),
                          ),
                        if (_showImpressions)
                          LineChartBarData(
                            spots: spotImpressions,
                            isCurved: true,
                            preventCurveOverShooting: true,
                            color: const Color(0xFFE91E63),
                            barWidth: 2,
                            dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3, color: const Color(0xFFE91E63), strokeWidth: 0, strokeColor: Colors.transparent)),
                          ),
                        if (_showOpenCount)
                          LineChartBarData(
                            spots: spotOpens,
                            isCurved: true,
                            preventCurveOverShooting: true,
                            color: const Color(0xFF00BCD4),
                            barWidth: 2,
                            dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3, color: const Color(0xFF00BCD4), strokeWidth: 0, strokeColor: Colors.transparent)),
                          ),
                      ]
                    ),
                  ),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 150, child: metricColumn),
                      Expanded(child: Padding(padding: const EdgeInsets.only(left: 16), child: chartWidget)),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildFcmMetricCheckbox('Sends', sends, const Color(0xFF4285F4), _showSends, (v) => setState(() => _showSends = v ?? true)),
                          _buildFcmMetricCheckbox('Received', received, const Color(0xFFF4B400), _showReceived, (v) => setState(() => _showReceived = v ?? true)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           _buildFcmMetricCheckbox('Impressions', impressions, const Color(0xFFE91E63), _showImpressions, (v) => setState(() => _showImpressions = v ?? true)),
                           _buildFcmMetricCheckbox('Opens', openCount, const Color(0xFF00BCD4), _showOpenCount, (v) => setState(() => _showOpenCount = v ?? true)),
                        ],
                      ),
                      const SizedBox(height: 32),
                      chartWidget,
                    ],
                  );
                }
              },
            ),
          ),
          
          // Legends bottom
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(const Color(0xFF4285F4), 'Sends'),
                const SizedBox(width: 12),
                _buildLegendItem(const Color(0xFFF4B400), 'Received (0%)'),
                const SizedBox(width: 12),
                _buildLegendItem(const Color(0xFFE91E63), 'Impressions (0%)'),
                const SizedBox(width: 12),
                _buildLegendItem(const Color(0xFF00BCD4), 'Open count (0%)'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.black87)),
      ],
    );
  }

  // ==== WIDGETS GOOGLE ANALYTICS MÔ PHỎNG ======
  Widget _buildGoogleAnalyticsDashboard() {
    final data = _analyticsData ?? {};
    
    int active30 = data['active30m'] ?? data['active_users'] ?? 1;
    int active5 = data['active5m'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Map Overlay & Active Users Bar Chart
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0), // Gray Map background
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // Giả lập Bản đồ
              Positioned(
                top: 40, right: 60,
                child: Column(
                  children: [
                    Icon(Icons.location_on, color: Colors.blue.withOpacity(0.7), size: 32),
                    const Text('Ho Chi Minh\nCity', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                  ],
                ),
              ),
              // Floating Card
              Positioned(
                top: 16, left: 16, bottom: 16, right: 16,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 10,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('NGƯỜI DÙNG HOẠT ĐỘNG 30 PHÚT QUA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dashed)),
                                  Text('$active30', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('NGƯỜI DÙNG HOẠT ĐỘNG 5 PHÚT QUA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dashed)),
                                  Text('$active5', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('NGƯỜI DÙNG HOẠT ĐỘNG MỖI PHÚT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 16),
                        Expanded(
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceEvenly,
                              maxY: 1.2,
                              barTouchData: BarTouchData(enabled: false),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      switch (value.toInt()) {
                                        case 0: return const Text('-30 min', style: TextStyle(fontSize: 9, color: Colors.grey));
                                        case 5: return const Text('-25 min', style: TextStyle(fontSize: 9, color: Colors.grey));
                                        case 10: return const Text('-20 min', style: TextStyle(fontSize: 9, color: Colors.grey));
                                        case 15: return const Text('-15 min', style: TextStyle(fontSize: 9, color: Colors.grey));
                                        case 20: return const Text('-10 min', style: TextStyle(fontSize: 9, color: Colors.grey));
                                        case 25: return const Text('-5 min', style: TextStyle(fontSize: 9, color: Colors.grey));
                                        case 29: return const Text('-1 min', style: TextStyle(fontSize: 9, color: Colors.grey));
                                        default: return const Text('');
                                      }
                                    },
                                    reservedSize: 20,
                                  ),
                                ),
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (value, meta) {
                                      if (value == 0.5) return const Text('0.5', style: TextStyle(fontSize: 10));
                                      if (value == 1.0) return const Text('1', style: TextStyle(fontSize: 10));
                                      return const Text('');
                                    }
                                  )
                                ),
                              ),
                              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 0.5),
                              borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
                              barGroups: List.generate(30, (i) {
                                double y = 0;
                                if (i == 14 || i == 24) y = 1.0; 
                                return BarChartGroupData(
                                  x: i,
                                  barRods: [BarChartRodData(toY: y, color: const Color(0xFF1A73E8), width: 6, borderRadius: BorderRadius.zero)]
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Bảng số liệu danh sách phân mảnh (3 thẻ ngang nếu màn hình lớn, hoặc 1 cột nếu phone)
        LayoutBuilder(
          builder: (context, constraints) {
            double cardWidth = constraints.maxWidth > 800 ? constraints.maxWidth / 3 - 12 : (constraints.maxWidth > 500 ? constraints.maxWidth / 2 - 8 : constraints.maxWidth);
            
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(width: cardWidth, child: _buildGA4Card('Người dùng theo Đối tượng', 'ĐỐI TƯỢNG', 'SỐ LƯỢNG', [
                  {'name': 'Tất cả người dùng', 'count': 1, 'percent': 1.0},
                ])),
                SizedBox(width: cardWidth, child: _buildGA4Card('Lượt xem theo Tiêu đề và Màn hình', 'TIÊU ĐỀ TRANG', 'LƯỢT XEM', [
                  {'name': '/', 'count': 2, 'percent': 0.5},
                  {'name': 'AdminDashboardScr...', 'count': 2, 'percent': 0.5},
                ])),
                SizedBox(width: cardWidth, child: _buildGA4Card('Sự kiện theo Tên sự kiện', 'TÊN SỰ KIỆN', 'SỐ LƯỢNG', [
                  {'name': 'screen_view', 'count': 6, 'percent': 0.75},
                  {'name': 'visit_page', 'count': 2, 'percent': 0.25},
                ])),
              ],
            );
          }
        ),
      ],
    );
  }

  Widget _buildGA4Card(String title, String col1, String col2, List<Map<String, dynamic>> items) {
    String topVal = items.isNotEmpty ? items[0]['count'].toString() : '-';
    String topTitle = items.isNotEmpty ? items[0]['name'].toString() : '-';
    String topPercent = items.isNotEmpty ? '${(items[0]['percent'] * 100).toInt()}%' : '';

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dashed)),
            const SizedBox(height: 16),
            if (items.isEmpty) ...[
              const SizedBox(height: 24),
              const Center(child: Text('Không có dữ liệu', style: TextStyle(color: Colors.grey, fontSize: 13))),
              const SizedBox(height: 24),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text('#1 $topTitle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1),
                         const SizedBox(height: 2),
                         Text(topVal, style: const TextStyle(fontSize: 24)),
                         Text(topPercent, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                       ],
                     ),
                   ),
                   // Mini Chart Dummy
                   Row(
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                       Container(width: 4, height: 24, color: const Color(0xFF1A73E8)),
                       const SizedBox(width: 8),
                       Container(width: 4, height: 24, color: const Color(0xFF1A73E8)),
                     ],
                   )
                ],
              )
            ],
            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(col1, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dashed)),
                Text(col2, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dashed)),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Không có dữ liệu', style: TextStyle(color: Colors.grey, fontSize: 12))))
            else
              ...items.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e['name'], style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Container(
                            height: 2, 
                            width: 100 * (e['percent'] as double),
                            color: const Color(0xFF1A73E8),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1, 
                      child: Text(e['count'].toString(), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
                    )
                  ],
                ),
              )).toList(),
          ],
        ),
      ),
    );
  }
  // ==== WIDGETS Dành cho Remote Config ====
  Widget _buildOverviewMetrics(Map<String, dynamic> data, Color primaryColor) {
    if (data.containsKey('error')) return Text('Lỗi tải dữ liệu: ${data['error']}', style: const TextStyle(color: Colors.red));
    final Map<String, String> stats = {};
    data.forEach((key, value) {
      if (value is num || value is String || value is bool) stats[key] = value.toString();
    });
    if (stats.isEmpty) return const Text('Không có thông số tĩnh');
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stats.entries.map((e) => Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: primaryColor.withOpacity(0.3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e.key.toUpperCase(), style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1),
            const SizedBox(height: 4),
            Text(e.value, style: TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildListItems(Map<String, dynamic> data, Color primaryColor) {
    final List<Widget> listWidgets = [];
    data.forEach((key, value) {
      if (value is List) {
        listWidgets.add(Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Text('Chi tiết: $key', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))));
        for (var item in value) {
          if (item is Map) {
            String title = item['title'] ?? item['name'] ?? item['id'] ?? item.keys.first.toString();
            String subTitle = item['body'] ?? item['description'] ?? item['count']?.toString() ?? item.toString();
            listWidgets.add(Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: primaryColor.withOpacity(0.1), child: Icon(Icons.data_usage, color: primaryColor, size: 20)),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(subTitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              )
            ));
          }
        }
      }
    });
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: listWidgets);
  }

  Widget _buildRemoteConfigSection() {
    String currentTheme = RemoteConfigService().themeEvent.toUpperCase();
    if (currentTheme.isEmpty || currentTheme == 'NORMAL') {
      currentTheme = 'MẶC ĐỊNH';
    }

    // Xác định icon và màu theo theme
    IconData themeIcon = Icons.color_lens;
    Color themeColor = const Color(0xFFFF5722);
    String themeName = currentTheme.toUpperCase();

    if (themeName == 'NOEL') {
      themeIcon = Icons.ac_unit;
      themeColor = Colors.lightBlue;
      themeName = 'GIÁNG SINH (NOEL)';
    } else if (themeName == 'TET' || themeName == 'TẾT') {
      themeIcon = Icons.celebration;
      themeColor = Colors.red;
      themeName = 'TẾT NGUYÊN ĐÁN';
    } else if (themeName == 'HALLOWEEN') {
      themeIcon = Icons.hardware;
      themeColor = Colors.deepOrange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: themeColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))),
            child: Row(
              children: [
                const Icon(Icons.tune, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Cấu Hình Hệ Thống (Remote Config)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Trạng thái Giao diện (Theme) hoạt động', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                ]))
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: InkWell(
              onTap: _showThemeSelector,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8), // Add padding for InkWell ripple effect
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: themeColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(themeIcon, size: 40, color: themeColor),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('GIAO DIỆN HIỆN TẠI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(themeName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: themeColor)),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit, color: Colors.grey, size: 20),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  // ==== WIDGETS Dành cho Firebase Users (Tài khoản Firebase) ====
  Widget _buildFirebaseUsersSection() {
    final data = _firebaseUsersData ?? {};
    
    List<dynamic> users = [];
    if (data.containsKey('users') && data['users'] is List) {
       users = data['users'];
    } else if (data.containsKey('data') && data['data'] is List) {
       users = data['data'];
    }

    // Lọc theo tìm kiếm
    if (_searchUserQuery.isNotEmpty) {
       users = users.where((u) {
         final identifier = (u['email'] ?? u['phone'] ?? u['identifier'] ?? '').toString().toLowerCase();
         final uid = (u['uid'] ?? u['_id'] ?? '').toString().toLowerCase();
         final q = _searchUserQuery.toLowerCase();
         return identifier.contains(q) || uid.contains(q);
       }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Refresh
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tài khoản Firebase', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D3B66))),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFFFF8A65)),
              onPressed: _fetchData,
            )
          ],
        ),
        const SizedBox(height: 8),

        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            onChanged: (val) {
              setState(() {
                _searchUserQuery = val;
              });
            },
            decoration: const InputDecoration(
              icon: Icon(Icons.search, color: Colors.grey),
              hintText: 'Tìm theo email, UID hoặc số điện thoại...',
              hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Danh sách Card
        if (users.isEmpty)
           const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Không tìm thấy tài khoản', style: TextStyle(color: Colors.grey))))
        else
           Column(
             children: users.map((u) {
               String identifier = (u['email'] ?? u['phone'] ?? u['identifier'] ?? 'Unknown').toString();
               // Lấy ngày tạo và đăng nhập từ Firebase Auth metadata
               String created = 'N/A';
               String lastLogin = 'N/A';
               if (u['metadata'] != null) {
                 created = (u['metadata']['creationTime'] ?? u['createdAt'] ?? 'N/A').toString();
                 lastLogin = (u['metadata']['lastSignInTime'] ?? u['lastLogin'] ?? 'N/A').toString();
               } else {
                 created = (u['created'] ?? u['createdAt'] ?? 'N/A').toString();
                 lastLogin = (u['lastLogin'] ?? u['lastSignInTime'] ?? 'N/A').toString();
               }

               // Format date cho gọn
               if (created.contains('GMT')) {
                 try { created = DateFormat('HH:mm dd/MM/yyyy').format(HttpDate.parse(created).toLocal()); } catch(e){}
               }
               if (lastLogin.contains('GMT')) {
                 try { lastLogin = DateFormat('HH:mm dd/MM/yyyy').format(HttpDate.parse(lastLogin).toLocal()); } catch(e){}
               }

               // Randomize avatar letter
               String initial = identifier.isNotEmpty && identifier != 'Unknown' ? identifier[0].toUpperCase() : 'U';

               // Provider icon từ mảng Firebase
               String provider = 'email';
               if (u['providerData'] != null && u['providerData'] is List && (u['providerData'] as List).isNotEmpty) {
                 provider = (u['providerData'][0]['providerId'] ?? 'email').toString().toLowerCase();
               } else if (u['provider'] != null) {
                 provider = u['provider'].toString().toLowerCase();
               }

               Widget providerWidget = const Icon(Icons.email, size: 16, color: Colors.grey);
               if (provider.contains('google')) {
                 providerWidget = const Text('G', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16));
               } else if (provider.contains('phone')) {
                 providerWidget = const Icon(Icons.phone, size: 16, color: Colors.green);
               } else if (provider.contains('facebook')) {
                 providerWidget = const Text('f', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16));
               }

               return InkWell(
                 onTap: () {
                   // Gọi hàm hiển thị Bottom Sheet cao cấp 
                   _showUserDetails(Map<String, dynamic>.from(u));
                 },
                 child: Container(
                   margin: const EdgeInsets.only(bottom: 12),
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: const Color(0xFFFAF3E0),
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(color: Colors.orange.shade100, width: 0.5),
                   ),
                   child: Row(
                     crossAxisAlignment: CrossAxisAlignment.center,
                     children: [
                       // Avatar
                       CircleAvatar(
                         radius: 20,
                         backgroundColor: const Color(0xFFE3F2FD),
                         child: Text(initial, style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold, fontSize: 18)),
                       ),
                       const SizedBox(width: 16),
                       
                       // Info
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(identifier, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D3B66))),
                             const SizedBox(height: 8),
                             Row(
                               children: [
                                 const Icon(Icons.grid_on, size: 12, color: Colors.grey),
                                 const SizedBox(width: 4),
                                 Text('Tham gia: $created', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                               ],
                             ),
                             const SizedBox(height: 4),
                             Row(
                               children: [
                                 const Icon(Icons.login, size: 12, color: Colors.grey),
                                 const SizedBox(width: 4),
                                 Text('Đăng nhập gần nhất: $lastLogin', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                               ],
                             ),
                           ],
                         ),
                       ),
                       
                       // Trailing
                       Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           providerWidget,
                           const SizedBox(height: 8),
                           const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                         ],
                       )
                     ],
                   ),
                 ),
               );
             }).toList(),
           ),
           
        // Pagination Bottom
        if (users.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1–${users.length} trong tổng số ${users.length}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.chevron_left, color: Colors.grey), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.chevron_right, color: Colors.grey), onPressed: () {}),
                  ],
                )
              ],
            ),
          )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RemoteConfigService(),
      builder: (context, _) {
        final bool isNoel = RemoteConfigService().themeEvent == 'NOEL';
        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          appBar: AppBar(
            title: Text(isNoel ? 'Bảng Sự kiện ❄️' : 'Bảng Sự kiện (Dashboard)', style: TextStyle(color: isNoel ? const Color(0xFFE53935) : const Color(0xFF1A73E8), fontWeight: FontWeight.w600)),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            iconTheme: IconThemeData(color: isNoel ? const Color(0xFFE53935) : const Color(0xFF1A73E8)),
          ),
          body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  color: const Color(0xFF1A73E8),
                  child: ListView(
                    padding: EdgeInsets.all(R.hPad(context)),
                    children: [
                      // ==== SECTION 1: ANALYTICS ====
                      const SizedBox(height: 8),
                      const Text('1. Realtime Analytics)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
                      const SizedBox(height: 16),
                      _buildGoogleAnalyticsDashboard(),

                      const SizedBox(height: 32),
                      Divider(color: Colors.grey.shade300, thickness: 2),
                      const SizedBox(height: 24),

                      // ==== SECTION 2: NOTIFICATION ==== 
                      const Text('2. Gửi Thông Báo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFF07E2B))),
                      const SizedBox(height: 16),
                      _buildSendNotificationSection(),

                      const SizedBox(height: 24),
                      Divider(color: Colors.grey.shade300, thickness: 2),
                      const SizedBox(height: 24),

                      // ==== SECTION 3: AUTHENTICATION ==== 
                      const Text('3. Quản Lý Tài Khoản (Authentication)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E88E5))),
                      const SizedBox(height: 16),
                      _buildFirebaseUsersSection(),

                      const SizedBox(height: 32),
                      Divider(color: Colors.grey.shade300, thickness: 2),
                      const SizedBox(height: 24),

                      // ==== SECTION 4: MESSAGING FCM ====
                      const Text('4. Cloud Messaging', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F9D58))),
                      const SizedBox(height: 16),
                      _buildFcmBoardSection(),
                      
                      const SizedBox(height: 32),
                      Divider(color: Colors.grey.shade300, thickness: 2),
                      const SizedBox(height: 24),
                      
                      // ==== SECTION 5: REMOTE CONFIG ====
                      const Text('5. Cấu Hình Giao Diện (Remote Config)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFFF5722))),
                      const SizedBox(height: 16),
                      _buildRemoteConfigSection(),
                      
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

