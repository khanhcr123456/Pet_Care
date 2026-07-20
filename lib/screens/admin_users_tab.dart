import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pet_care/services/admin_service.dart';
import 'package:pet_care/utils/responsive.dart';

class AdminUsersTab extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminUsersTab({super.key, required this.user});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _users = [];
  List<dynamic> _filtered = [];
  final TextEditingController _searchCtrl = TextEditingController();
  int _rowsPerPage = 10;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await AdminService().getFirebaseUsers(widget.user['token'], limit: 100);
      if (mounted) {
        setState(() {
          _users = res;
          _filtered = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  void _onSearch(String q) {
    setState(() {
      _currentPage = 0;
      if (q.trim().isEmpty) {
        _filtered = List.from(_users);
      } else {
        final lower = q.toLowerCase();
        _filtered = _users.where((u) {
          final email = (u['email'] ?? '').toString().toLowerCase();
          final uid = (u['uid'] ?? u['localId'] ?? '').toString().toLowerCase();
          final phone = (u['phoneNumber'] ?? '').toString().toLowerCase();
          return email.contains(lower) || uid.contains(lower) || phone.contains(lower);
        }).toList();
      }
    });
  }

  String _formatDate(dynamic raw) {
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

  List<dynamic> get _currentPageData {
    final start = _currentPage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  int get _totalPages => (_filtered.length / _rowsPerPage).ceil();

  Widget _providerIcons(dynamic providers) {
    if (providers == null) return const Icon(Icons.person, size: 20, color: Colors.grey);
    final list = providers is List ? providers : [providers];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: list.take(3).map<Widget>((p) {
        final id = (p is Map ? (p['providerId'] ?? '') : p).toString().toLowerCase();
        if (id.contains('google')) {
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(Icons.g_mobiledata, color: Colors.red[400], size: 28),
          );
        }
        if (id.contains('password') || id.contains('email')) {
          return const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.email_outlined, size: 18, color: Colors.blueGrey),
          );
        }
        if (id.contains('phone')) {
          return const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.phone, size: 18, color: Colors.teal),
          );
        }
        return const Padding(
          padding: EdgeInsets.only(right: 4),
          child: Icon(Icons.link, size: 18, color: Colors.grey),
        );
      }).toList(),
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
    final createdAt = _formatDate(u['createdAt'] ?? metadata?['creationTime']);
    final lastLogin = _formatDate(u['lastSignedIn'] ?? u['lastLoginAt'] ?? u['lastSignInTime'] ?? metadata?['lastSignInTime']);

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
                  _detailRow(Icons.fingerprint, 'UID', uid, copyable: true),
                  _detailRow(Icons.email, 'Email', email),
                  _detailRow(Icons.verified, 'Email đã xác thực', emailVerified ? 'Có' : 'Chưa'),
                  if (phone.isNotEmpty) _detailRow(Icons.phone, 'Số điện thoại', phone),
                  _detailRow(Icons.calendar_today, 'Ngày tạo', createdAt),
                  _detailRow(Icons.access_time, 'Đăng nhập gần nhất', lastLogin),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: disabled ? () => _toggleDisable(uid, false) : () => _toggleDisable(uid, true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: disabled ? Colors.green : Colors.orange,
                          side: BorderSide(color: disabled ? Colors.green : Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(disabled ? Icons.check : Icons.block, size: 18),
                            const SizedBox(width: 4),
                            Flexible(child: Text(disabled ? 'Kích hoạt lại' : 'Vô hiệu hóa', overflow: TextOverflow.ellipsis, maxLines: 1)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _confirmDelete(uid),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.delete_outline, size: 18),
                            const SizedBox(width: 4),
                            const Flexible(child: Text('Xóa tài khoản', overflow: TextOverflow.ellipsis, maxLines: 1)),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ],
              )),
            ],
          ),
        ),
      ),
    );
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

  Future<void> _toggleDisable(String uid, bool disable) async {
    Navigator.pop(context);
    try {
      await AdminService().disableFirebaseUser(widget.user['token'], uid, disable);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(disable ? 'Đã vô hiệu hóa tài khoản' : 'Đã kích hoạt lại tài khoản'),
        backgroundColor: disable ? Colors.orange : Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
      _fetchUsers();
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
        _fetchUsers();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      body: Column(
        children: [
          // ---- HEADER SECTION ----
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tài khoản Firebase', style: TextStyle(fontSize: R.sp(context, 18), fontWeight: FontWeight.bold, color: const Color(0xFF0F2E53))),
                    IconButton(icon: const Icon(Icons.refresh, color: Color(0xFFF07E2B)), onPressed: _fetchUsers),
                  ],
                ),
                const SizedBox(height: 12),
                // Search Bar
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo email, UID hoặc số điện thoại...',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: R.sp(context, 13)),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); _onSearch(''); })
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),

          // ---- BODY ----
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF07E2B)))
                : _error != null
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text('Lỗi tải dữ liệu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: R.sp(context, 16))),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: R.sp(context, 13))),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(onPressed: _fetchUsers, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
                      ]))
                    : _filtered.isEmpty
                        ? const Center(child: Text('Không tìm thấy người dùng nào.', style: TextStyle(color: Colors.grey)))
                        : RefreshIndicator(
                            onRefresh: _fetchUsers,
                            color: const Color(0xFFF07E2B),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _currentPageData.length,
                              itemBuilder: (context, index) {
                                final u = _currentPageData[index] as Map<String, dynamic>;
                                final email = u['email'] ?? u['phoneNumber'] ?? '';
                                final disabled = u['disabled'] == true;
                                final metadata = u['metadata'] as Map<String, dynamic>?;
                                final createdAt = _formatDate(u['createdAt'] ?? metadata?['creationTime']);
                                final lastLogin = _formatDate(u['lastSignedIn'] ?? u['lastLoginAt'] ?? u['lastSignInTime'] ?? metadata?['lastSignInTime']);
                                final providers = u['providerData'] ?? u['providers'];

                                return Card(
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                                  ),
                                  child: ListTile(
                                    onTap: () => _showUserDetails(Map<String, dynamic>.from(u)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    leading: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: disabled ? Colors.red[100] : const Color(0xFFE8F0FE),
                                      child: Text(
                                        email.isNotEmpty ? email[0].toUpperCase() : '?',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: disabled ? Colors.red : const Color(0xFF1967D2)),
                                      ),
                                    ),
                                    title: Text(
                                      email.isNotEmpty ? email : 'Không có email',
                                      style: TextStyle(fontSize: R.sp(context, 15), fontWeight: FontWeight.bold, color: disabled ? Colors.grey : const Color(0xFF0F2E53)),
                                      maxLines: 2, overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 6),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Padding(
                                              padding: EdgeInsets.only(top: 2),
                                              child: Icon(Icons.app_registration, size: 12, color: Colors.grey),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Tham gia: $createdAt',
                                                style: TextStyle(fontSize: R.sp(context, 12), color: Colors.grey[700]),
                                                // Không cắt ellipsis để người dùng đọc được hết data dù màn hình hẹp
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _providerIcons(providers),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Padding(
                                              padding: EdgeInsets.only(top: 2),
                                              child: Icon(Icons.login, size: 12, color: Colors.grey),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Đăng nhập gần nhất: $lastLogin',
                                                style: TextStyle(fontSize: R.sp(context, 12), color: Colors.grey[600]),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (disabled)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text('Tài khoản đã bị khóa', style: TextStyle(fontSize: R.sp(context, 12), color: Colors.red, fontWeight: FontWeight.w500)),
                                          )
                                      ],
                                    ),
                                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ),
          ),

          // ---- FOOTER PAGINATION ----
          if (!_isLoading && _error == null && _filtered.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${_currentPage * _rowsPerPage + 1}–${(_currentPage * _rowsPerPage + _rowsPerPage).clamp(0, _filtered.length)} trong tổng số ${_filtered.length}', 
                      style: TextStyle(fontSize: R.sp(context, 13), color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_left, size: 24), color: _currentPage > 0 ? const Color(0xFFF07E2B) : Colors.grey[300], onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null),
                      IconButton(icon: const Icon(Icons.chevron_right, size: 24), color: _currentPage < _totalPages - 1 ? const Color(0xFFF07E2B) : Colors.grey[300], onPressed: _currentPage < _totalPages - 1 ? () => setState(() => _currentPage++) : null),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
