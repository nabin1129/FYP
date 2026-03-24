import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/notification_service.dart';
import 'notification_panel.dart';

/// Reusable notification bell icon with unread badge.
/// Tapping opens an animated dropdown overlay anchored below the bell icon.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  final GlobalKey _bellKey = GlobalKey();
  int _unreadCount = 0;
  StreamSubscription<List<AppNotification>>? _subscription;
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _slideAnim = Tween<Offset>(begin: const Offset(0, -0.04), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    _unreadCount = _notificationService.unreadCount;
    _subscription = _notificationService.notificationStream.listen((list) {
      if (mounted) {
        setState(() {
          _unreadCount = list.where((n) => !n.isRead).length;
        });
      }
    });
    _loadCount();
  }

  Future<void> _loadCount() async {
    final count = await _notificationService.getUnreadCountAsync();
    if (mounted) {
      setState(() => _unreadCount = count);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _removeOverlay(animate: false);
    _animController.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final renderBox = _bellKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenWidth = MediaQuery.of(context).size.width;

    const dropdownWidth = 340.0;
    double left = position.dx + size.width - dropdownWidth;
    if (left < 8) left = 8;
    if (left + dropdownWidth > screenWidth - 8) {
      left = screenWidth - dropdownWidth - 8;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Animated scrim
          FadeTransition(
            opacity: _fadeAnim,
            child: Positioned.fill(
              child: GestureDetector(
                onTap: _removeOverlay,
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.05)),
              ),
            ),
          ),
          // Animated dropdown panel
          Positioned(
            top: position.dy + size.height + 4,
            left: left,
            child: SlideTransition(
              position: _slideAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                alignment: Alignment.topRight,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Material(
                    elevation: 8,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      child: SizedBox(
                        width: dropdownWidth,
                        height: 420,
                        child: NotificationPanel(onClose: _removeOverlay),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animController.forward();
    setState(() => _isOpen = true);
  }

  void _removeOverlay({bool animate = true}) {
    if (_overlayEntry == null) return;

    if (animate && _animController.isAnimating || animate && _isOpen) {
      _animController.reverse().then((_) {
        _overlayEntry?.remove();
        _overlayEntry = null;
        if (mounted) setState(() => _isOpen = false);
      });
    } else {
      _animController.reset();
      _overlayEntry?.remove();
      _overlayEntry = null;
      if (mounted) setState(() => _isOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _bellKey,
      children: [
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              _isOpen ? Icons.notifications : Icons.notifications_outlined,
              key: ValueKey(_isOpen),
              size: 30,
            ),
          ),
          onPressed: _toggleDropdown,
          tooltip: 'Notifications',
        ),
        // Animated badge
        Positioned(
          right: 8,
          top: 8,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.elasticOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: _unreadCount > 0
                ? Container(
                    key: ValueKey(_unreadCount),
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppTheme.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppTheme.fontXS,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey(0)),
          ),
        ),
      ],
    );
  }
}
