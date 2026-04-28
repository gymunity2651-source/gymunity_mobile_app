import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../store/domain/entities/order_entity.dart';
import '../../../store/presentation/store_ui_utils.dart';
import '../../domain/entities/seller_profile_entity.dart';
import '../providers/seller_providers.dart';

const Color _surface = Color(0xFFFAF9F6);
const Color _surfaceLowest = Color(0xFFFFFFFF);
const Color _surfaceLow = Color(0xFFF4F3F1);
const Color _surfaceHigh = Color(0xFFE9E8E5);
const Color _primary = Color(0xFF822700);
const Color _secondary = Color(0xFFA43C12);
const Color _secondaryContainer = Color(0xFFFE7E4F);
const Color _onSurface = Color(0xFF1A1C1A);
const Color _onSurfaceVariant = Color(0xFF6B625F);
const Color _muted = Color(0xFF9A928E);
const Color _glass = Color(0xCCFAF9F6);
const Color _ambientShadow = Color(0x0D1A1C1A);

class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(sellerProfileProvider);
    final summaryAsync = ref.watch(sellerDashboardSummaryProvider);
    final ordersAsync = ref.watch(sellerOrdersProvider);

    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          const Positioned.fill(child: _DashboardBackdrop()),
          SafeArea(
            child: RefreshIndicator.adaptive(
              color: _primary,
              backgroundColor: _surfaceLowest,
              onRefresh: () async {
                ref.invalidate(sellerProfileProvider);
                ref.invalidate(sellerDashboardSummaryProvider);
                ref.invalidate(sellerOrdersProvider);
                await Future.wait<dynamic>([
                  ref.read(sellerProfileProvider.future),
                  ref.read(sellerDashboardSummaryProvider.future),
                  ref.read(sellerOrdersProvider.future),
                ]);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(30, 18, 30, 128),
                children: [
                  _AtelierTopBar(
                    onMenu: () =>
                        Navigator.pushNamed(context, AppRoutes.sellerProfile),
                    onProfile: () =>
                        Navigator.pushNamed(context, AppRoutes.sellerProfile),
                  ),
                  const SizedBox(height: 34),
                  profileAsync.when(
                    loading: () => const _DashboardHero(profile: null),
                    error: (_, _) => const _DashboardHero(profile: null),
                    data: (profile) => _DashboardHero(profile: profile),
                  ),
                  const SizedBox(height: 50),
                  _QuickActionRail(
                    actions: [
                      _ActionItem(
                        label: 'Add Product',
                        icon: Icons.add_box_rounded,
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.addProduct),
                      ),
                      _ActionItem(
                        label: 'Inventory',
                        icon: Icons.inventory_2_rounded,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.productManagement,
                        ),
                      ),
                      _ActionItem(
                        label: 'Orders',
                        icon: Icons.local_shipping_rounded,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.sellerOrders,
                        ),
                      ),
                      _ActionItem(
                        label: 'Log Out',
                        icon: Icons.logout_rounded,
                        onTap: () => _confirmSellerLogout(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 52),
                  _SummaryBlock(summaryAsync: summaryAsync),
                  const SizedBox(height: 44),
                  _RecentOrdersBlock(ordersAsync: ordersAsync),
                ],
              ),
            ),
          ),
          _GlassSellerNav(
            onHome: () {},
            onInventory: () =>
                Navigator.pushNamed(context, AppRoutes.productManagement),
            onOrders: () =>
                Navigator.pushNamed(context, AppRoutes.sellerOrders),
            onAnalytics: () => ref.invalidate(sellerDashboardSummaryProvider),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSellerLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surfaceLowest,
          title: Text(
            'Log out of seller account?',
            style: GoogleFonts.notoSerif(
              fontWeight: FontWeight.w700,
              color: _onSurface,
            ),
          ),
          content: Text(
            'You will return to the login screen.',
            style: GoogleFonts.manrope(color: _onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: _surfaceLowest,
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !context.mounted) {
      return;
    }

    await ref.read(authControllerProvider.notifier).logout();
    if (!context.mounted) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }
}

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFFFFFFFF), _surface, Color(0xFFF6F1EC)],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Positioned(
          top: -100,
          right: -140,
          child: _AtmosphereOrb(
            size: 310,
            color: _secondaryContainer.withValues(alpha: 0.14),
          ),
        ),
        Positioned(
          top: 300,
          left: -170,
          child: _AtmosphereOrb(
            size: 260,
            color: _primary.withValues(alpha: 0.06),
          ),
        ),
        Positioned(
          bottom: -150,
          right: -120,
          child: _AtmosphereOrb(
            size: 320,
            color: _secondary.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}

class _AtmosphereOrb extends StatelessWidget {
  const _AtmosphereOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: <Color>[color, Colors.transparent]),
      ),
    );
  }
}

class _AtelierTopBar extends StatelessWidget {
  const _AtelierTopBar({required this.onMenu, required this.onProfile});

  final VoidCallback onMenu;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TopIconButton(icon: Icons.menu_rounded, onTap: onMenu),
        Expanded(
          child: Text(
            'Atelier Dashboard',
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSerif(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: _primary,
            ),
          ),
        ),
        _ProfileButton(onTap: onProfile),
      ],
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 30,
        height: 38,
        child: Icon(icon, size: 19, color: _primary),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: _surfaceLow,
          shape: BoxShape.circle,
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: _ambientShadow,
              blurRadius: 30,
              spreadRadius: -8,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: const Icon(Icons.person_rounded, size: 18, color: _primary),
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({required this.profile});

  final SellerProfileEntity? profile;

  @override
  Widget build(BuildContext context) {
    final name = _splitStoreName(profile?.storeName);
    final description = profile?.storeDescription?.trim();

    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WELCOME BACK',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.8,
              color: _onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${name.primary}\n',
                  style: GoogleFonts.notoSerif(
                    fontSize: 39,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    color: _onSurface,
                  ),
                ),
                TextSpan(
                  text: name.accent,
                  style: GoogleFonts.notoSerif(
                    fontSize: 38,
                    height: 1.1,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.8,
                    color: _primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 285),
            child: Text(
              description?.isNotEmpty == true
                  ? description!
                  : 'Your curated inventory and recent orders are performing well this week.',
              style: GoogleFonts.manrope(
                fontSize: 15,
                height: 1.75,
                color: _onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionRail extends StatelessWidget {
  const _QuickActionRail({required this.actions});

  final List<_ActionItem> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 98,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemBuilder: (context, index) {
          final action = actions[index];
          return _ActionTile(action: action);
        },
        separatorBuilder: (_, _) => const SizedBox(width: 18),
        itemCount: actions.length,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final _ActionItem action;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 102,
        height: 94,
        decoration: BoxDecoration(
          color: _surfaceLowest.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(34),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: _ambientShadow,
              blurRadius: 38,
              spreadRadius: -7,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, color: _primary, size: 20),
            const SizedBox(height: 16),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: _onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({required this.summaryAsync});

  final AsyncValue<SellerDashboardSummaryEntity> summaryAsync;

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      loading: () => const Column(
        children: [
          _MetricSkeleton(),
          SizedBox(height: 22),
          _MetricSkeleton(),
          SizedBox(height: 22),
          _MetricSkeleton(isRevenue: true),
        ],
      ),
      error: (error, stackTrace) => _DashboardMessage(
        message: describeStoreError(
          error,
          fallbackMessage: 'GymUnity could not load seller metrics right now.',
        ),
      ),
      data: (summary) => Column(
        children: [
          _MetricCard(
            label: 'PRODUCTS',
            value: '${summary.activeProducts}',
            sublabel: '${summary.totalProducts} total',
            icon: Icons.category_rounded,
          ),
          const SizedBox(height: 22),
          _MetricCard(
            label: 'PENDING ORDERS',
            value: '${summary.pendingOrders}',
            sublabel: summary.inProgressOrders == 0
                ? 'Requires attention'
                : '${summary.inProgressOrders} in progress',
            icon: Icons.local_shipping_rounded,
          ),
          const SizedBox(height: 22),
          _MetricCard(
            label: 'TOTAL REVENUE',
            value: _formatCompactRevenue(summary.grossRevenue),
            sublabel: 'Past 30 days',
            icon: Icons.trending_up_rounded,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String sublabel;
  final IconData icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final foreground = emphasized ? _surfaceLowest : _onSurface;
    final secondary = emphasized
        ? _surfaceLowest.withValues(alpha: 0.78)
        : _onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      decoration: BoxDecoration(
        color: emphasized ? _primary : _surfaceLowest.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(34),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: _ambientShadow,
            blurRadius: 40,
            spreadRadius: -5,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.2,
                  color: secondary,
                ),
              ),
              const Spacer(),
              Icon(
                icon,
                size: 18,
                color: emphasized ? _surfaceLowest : _primary,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            value,
            style: GoogleFonts.notoSerif(
              fontSize: emphasized ? 32 : 38,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: -1.1,
              color: foreground,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            sublabel,
            style: GoogleFonts.manrope(fontSize: 12, color: secondary),
          ),
        ],
      ),
    );
  }
}

class _MetricSkeleton extends StatelessWidget {
  const _MetricSkeleton({this.isRevenue = false});

  final bool isRevenue;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 142,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isRevenue ? _primary.withValues(alpha: 0.86) : _surfaceLow,
        borderRadius: BorderRadius.circular(34),
      ),
    );
  }
}

class _RecentOrdersBlock extends StatelessWidget {
  const _RecentOrdersBlock({required this.ordersAsync});

  final AsyncValue<List<OrderEntity>> ordersAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Orders',
          style: GoogleFonts.notoSerif(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: _onSurface,
          ),
        ),
        const SizedBox(height: 24),
        ordersAsync.when(
          loading: () => const Column(
            children: [
              _OrderSkeleton(),
              SizedBox(height: 20),
              _OrderSkeleton(),
            ],
          ),
          error: (error, stackTrace) => _DashboardMessage(
            message: describeStoreError(
              error,
              fallbackMessage:
                  'GymUnity could not load recent orders right now.',
            ),
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return const _DashboardMessage(
                message:
                    'No seller orders exist yet. New customer checkouts will appear in this atelier ledger.',
              );
            }

            final recentOrders = orders.take(4).toList(growable: false);
            return Column(
              children: [
                for (final order in recentOrders) ...[
                  _OrderCard(order: order),
                  if (order != recentOrders.last) const SizedBox(height: 20),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    final productTitle = order.items.isNotEmpty
        ? order.items.first.productTitle
        : 'Curated Order';
    final customer = _customerName(order);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.sellerOrders),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: _surfaceLowest.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(34),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: _ambientShadow,
              blurRadius: 40,
              spreadRadius: -7,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Row(
          children: [
            _OrderThumbnail(title: productTitle, status: order.status),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSerif(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: _onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Order #${_shortOrderId(order.id)}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      height: 1.35,
                      color: _onSurfaceVariant,
                    ),
                  ),
                  Text(
                    customer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      height: 1.35,
                      color: _onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_currencySymbol(order.currency)}${order.totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.notoSerif(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                _StatusPill(status: order.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderThumbnail extends StatelessWidget {
  const _OrderThumbnail({required this.title, required this.status});

  final String title;
  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = _thumbnailPalette(title, status);

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: _surfaceLow,
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: palette),
      ),
      child: Icon(
        _thumbnailIcon(title),
        color: _surfaceLowest.withValues(alpha: 0.92),
        size: 27,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _statusTint(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        formatOrderStatus(status).toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: _primary,
        ),
      ),
    );
  }
}

class _OrderSkeleton extends StatelessWidget {
  const _OrderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(34),
      ),
    );
  }
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(34),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: 14,
          height: 1.6,
          color: _onSurfaceVariant,
        ),
      ),
    );
  }
}

class _GlassSellerNav extends StatelessWidget {
  const _GlassSellerNav({
    required this.onHome,
    required this.onInventory,
    required this.onOrders,
    required this.onAnalytics,
  });

  final VoidCallback onHome;
  final VoidCallback onInventory;
  final VoidCallback onOrders;
  final VoidCallback onAnalytics;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: _glass,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _HomeNavButton(onTap: onHome),
                    _NavButton(
                      label: 'Inventory',
                      icon: Icons.inventory_2_rounded,
                      onTap: onInventory,
                    ),
                    _NavButton(
                      label: 'Orders',
                      icon: Icons.receipt_long_rounded,
                      onTap: onOrders,
                    ),
                    _NavButton(
                      label: 'Analytics',
                      icon: Icons.insights_rounded,
                      onTap: onAnalytics,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeNavButton extends StatelessWidget {
  const _HomeNavButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[_primary, _secondaryContainer],
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: _ambientShadow,
              blurRadius: 40,
              spreadRadius: -5,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: const Icon(Icons.grid_view_rounded, color: _surfaceLowest),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: _muted),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _StoreNameParts {
  const _StoreNameParts({required this.primary, required this.accent});

  final String primary;
  final String accent;
}

_StoreNameParts _splitStoreName(String? rawName) {
  final trimmed = rawName?.trim();
  final resolved = trimmed == null || trimmed.isEmpty ? 'Your Store' : trimmed;
  final parts = resolved.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    return _StoreNameParts(primary: parts.first, accent: 'Atelier');
  }
  return _StoreNameParts(primary: parts.first, accent: parts.skip(1).join(' '));
}

String _formatCompactRevenue(double value) {
  final abs = value.abs();
  if (abs >= 1000000) {
    return '\$${(value / 1000000).toStringAsFixed(1)}m';
  }
  if (abs >= 1000) {
    return '\$${(value / 1000).toStringAsFixed(1)}k';
  }
  return '\$${value.toStringAsFixed(0)}';
}

String _shortOrderId(String id) {
  if (id.length <= 6) {
    return id.toUpperCase();
  }
  return id.substring(0, 6).toUpperCase();
}

String _customerName(OrderEntity order) {
  final memberName = order.memberName?.trim();
  if (memberName != null && memberName.isNotEmpty) {
    return memberName;
  }
  final recipient = order.shippingAddress['recipient_name']?.toString().trim();
  if (recipient != null && recipient.isNotEmpty) {
    return recipient;
  }
  return 'Customer';
}

String _currencySymbol(String currency) {
  switch (currency.toUpperCase()) {
    case 'USD':
      return '\$';
    case 'EGP':
      return 'EGP ';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    default:
      return '$currency ';
  }
}

Color _statusTint(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return _secondaryContainer.withValues(alpha: 0.22);
    case 'paid':
    case 'processing':
      return _surfaceHigh;
    case 'shipped':
      return const Color(0xFFE9E1D6);
    case 'delivered':
      return const Color(0xFFDDE7DA);
    case 'cancelled':
      return const Color(0xFFEADAD6);
    default:
      return _surfaceHigh;
  }
}

IconData _thumbnailIcon(String title) {
  final normalized = title.toLowerCase();
  if (normalized.contains('protein') ||
      normalized.contains('supplement') ||
      normalized.contains('nutrition')) {
    return Icons.science_rounded;
  }
  if (normalized.contains('shirt') ||
      normalized.contains('apparel') ||
      normalized.contains('wear')) {
    return Icons.checkroom_rounded;
  }
  if (normalized.contains('mug') ||
      normalized.contains('cup') ||
      normalized.contains('vase')) {
    return Icons.local_cafe_rounded;
  }
  return Icons.inventory_2_rounded;
}

List<Color> _thumbnailPalette(String title, String status) {
  final normalized = title.toLowerCase();
  if (normalized.contains('mug') ||
      normalized.contains('cup') ||
      normalized.contains('vase')) {
    return const <Color>[Color(0xFFD9D0BE), Color(0xFF77725E)];
  }
  if (status.toLowerCase() == 'delivered') {
    return const <Color>[Color(0xFFBBD8CF), Color(0xFF467167)];
  }
  if (status.toLowerCase() == 'shipped') {
    return const <Color>[Color(0xFFEBC474), Color(0xFF8C5E1E)];
  }
  return const <Color>[Color(0xFFD7B79F), _primary];
}
