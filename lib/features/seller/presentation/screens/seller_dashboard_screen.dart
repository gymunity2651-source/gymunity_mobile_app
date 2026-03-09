import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';

class SellerDashboardScreen extends StatelessWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void navigate(String route) {
      Navigator.pushNamed(context, route);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E90FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.storefront,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GymUnity Seller',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Welcome back, Iron Fitness Hub',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => navigate(AppRoutes.notifications),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white54,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () => navigate(AppRoutes.sellerProfile),
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Quick Actions',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _QuickAction(
                    icon: Icons.add_box_outlined,
                    label: 'Add Product',
                    color: const Color(0xFF1E90FF),
                    filled: true,
                    onTap: () => navigate(AppRoutes.addProduct),
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: Icons.inventory_2_outlined,
                    label: 'Inventory',
                    color: const Color(0xFF1C2030),
                    onTap: () => navigate(AppRoutes.productManagement),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _QuickAction(
                    icon: Icons.campaign_outlined,
                    label: 'Promotions',
                    color: const Color(0xFF1C2030),
                    onTap: () => showAppFeedback(
                      context,
                      'Promotions will be enabled after campaign tools are connected.',
                    ),
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: Icons.mail_outline,
                    label: 'Messages',
                    color: const Color(0xFF1C2030),
                    onTap: () => navigate(AppRoutes.helpSupport),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _StatCard(
                title: 'Total Sales',
                value: '1,284',
                change: '+12%',
              ),
              const SizedBox(height: 14),
              const _StatCard(
                title: 'Active Orders',
                value: '86',
                change: '+5%',
              ),
              const SizedBox(height: 14),
              const _StatCard(
                title: 'Revenue',
                value: '\$12,450',
                change: '+18%',
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Recent Orders',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => navigate(AppRoutes.sellerOrders),
                          child: Text(
                            'View All ->',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF60A5FA),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _tableHeader('ORDER ID'),
                        _tableHeader('CUSTOMER'),
                        _tableHeader('PRODUCT'),
                      ],
                    ),
                    const Divider(color: Color(0xFF1F2937)),
                    _orderRow('#ORD-9921', 'Alex Johnson', 'Whey Isola...'),
                    _orderRow('#ORD-9920', 'Sarah Miller', 'Dumbbell S...'),
                    _orderRow('#ORD-9919', 'Mike Ross', 'Resistance...'),
                    _orderRow('#ORD-9918', 'Emma Wilson', 'Yoga Mat P...'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          border: Border(top: BorderSide(color: Color(0xFF1F2937))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.grid_view, 'Home', true),
                _navItem(
                  Icons.shopping_cart_outlined,
                  'Orders',
                  false,
                  onTap: () => navigate(AppRoutes.sellerOrders),
                ),
                _navItem(
                  Icons.inventory_2_outlined,
                  'Products',
                  false,
                  onTap: () => navigate(AppRoutes.productManagement),
                ),
                _navItem(
                  Icons.settings_outlined,
                  'Settings',
                  false,
                  onTap: () => navigate(AppRoutes.settings),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _navItem(
    IconData icon,
    String label,
    bool active, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active ? const Color(0xFF60A5FA) : Colors.white38,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? const Color(0xFF60A5FA) : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _tableHeader(String text) {
    return Expanded(
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white38,
          letterSpacing: 1,
        ),
      ),
    );
  }

  static Widget _orderRow(String id, String customer, String product) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              id,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF60A5FA),
              ),
            ),
          ),
          Expanded(
            child: Text(
              customer,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
            ),
          ),
          Expanded(
            child: Text(
              product,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: filled ? null : Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.change,
  });

  final String title;
  final String value;
  final String change;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white54),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  change,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          CustomPaint(
            size: const Size(double.infinity, 40),
            painter: _SparklinePainter(),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final points = List.generate(
      8,
      (i) => Offset(
        i * size.width / 7,
        size.height * (0.2 + rng.nextDouble() * 0.6),
      ),
    );

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final cp1 = Offset(
        (points[i - 1].dx + points[i].dx) / 2,
        points[i - 1].dy,
      );
      final cp2 = Offset((points[i - 1].dx + points[i].dx) / 2, points[i].dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i].dx, points[i].dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF3B82F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
