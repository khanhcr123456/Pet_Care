import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pet_care/services/pet_service.dart';
import 'package:pet_care/screens/booking_screen.dart';
import 'package:pet_care/utils/responsive.dart';
import 'package:shimmer/shimmer.dart';

class ServicesScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const ServicesScreen({super.key, this.user});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<dynamic> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      final services = await PetService().getServices();
      if (mounted) {
        setState(() {
          _services = services;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String formatCurrency(num amount) {
    final str = amount.toInt().toString();
    String result = '';
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      count++;
      result = str[i] + result;
      if (count % 3 == 0 && i != 0) {
        result = '.$result';
      }
    }
    return '$result đ';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ListView.builder(
        padding: EdgeInsets.all(R.hPad(context) + 4),
        itemCount: 4,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade50,
          child: Container(
            margin: EdgeInsets.only(bottom: R.isSmall(context) ? 16 : 20),
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    if (_services.isEmpty) {
      return Center(child: Text('Không có dịch vụ nào', style: TextStyle(fontSize: R.sp(context, 16), color: Colors.grey)));
    }

    return ListView.builder(
      padding: EdgeInsets.all(R.hPad(context) + 4),
      itemCount: _services.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.only(bottom: R.isSmall(context) ? 16 : 24, top: 10),
            child: Text(
              'Các Dịch Vụ Của PetCare',
              style: TextStyle(
                fontSize: R.sp(context, 22),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F2E53),
              ),
            ),
          );
        }

        final service = _services[index - 1];
        final images = service['images'] as List<dynamic>?;
        final imageUrl = (images != null && images.isNotEmpty) ? images[0].toString() : null;
        final imgHeight = R.heroHeight(context);

        return Container(
          margin: EdgeInsets.only(bottom: R.isSmall(context) ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
            ],
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: InkWell(
            onTap: () {
              if (widget.user == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để đặt lịch khám!')));
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BookingScreen(
                  user: widget.user!,
                  initialServiceId: service['_id'] ?? service['id'],
                )),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      imageUrl,
                      height: imgHeight,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        height: imgHeight,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 50),
                      ),
                    ),
                  )
                else
                  Container(
                    height: imgHeight,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF9E6),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: const Icon(Icons.medical_services_outlined, color: Color(0xFFFFD740), size: 60),
                  ),
                Padding(
                  padding: EdgeInsets.all(R.hPad(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              service['name'] ?? 'Dịch vụ chưa cập nhật',
                              style: TextStyle(
                                fontSize: R.sp(context, 17),
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F2E53),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE566),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              formatCurrency(service['price'] ?? 0),
                              style: TextStyle(
                                fontSize: R.sp(context, 13),
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F2E53),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: R.isSmall(context) ? 8 : 12),
                      Text(
                        service['description'] ?? 'Mô tả dịch vụ đang được cập nhật...',
                        style: TextStyle(
                          fontSize: R.sp(context, 13),
                          color: const Color(0xFF4B5563),
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: R.isSmall(context) ? 10 : 16),
                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                      SizedBox(height: R.isSmall(context) ? 8 : 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.orange, size: R.iconSm(context)),
                              const SizedBox(width: 4),
                              Text(
                                service['type'] == 'vaccination' ? 'Tiêm phòng' : 'Khám chữa bệnh',
                                style: TextStyle(
                                  fontSize: R.sp(context, 12),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'Đặt lịch ngay',
                                style: TextStyle(
                                  fontSize: R.sp(context, 13),
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F2E53),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios, size: 13, color: Color(0xFF0F2E53)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
