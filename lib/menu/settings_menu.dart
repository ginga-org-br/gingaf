import 'dart:async';

import 'package:flutter/material.dart';

class SettingsMenu extends StatefulWidget {
  final VoidCallback? onReload;
  final VoidCallback? onRestart;
  final VoidCallback onTogglePause;
  final VoidCallback? onForward2s;
  final VoidCallback onOpenUsers;
  final bool isPaused;

  const SettingsMenu({
    super.key,
    this.onReload,
    this.onRestart,
    required this.onTogglePause,
    this.onForward2s,
    required this.onOpenUsers,
    this.isPaused = false,
  }) : assert(onReload != null || onRestart != null);

  VoidCallback get restartCallback => onRestart ?? onReload!;

  @override
  State<SettingsMenu> createState() => SettingsMenuState();
}

class SettingsMenuState extends State<SettingsMenu>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  bool get isOpen => _isOpen;

  void toggle() => _toggle();
  void open() {
    if (!_isOpen) _toggle();
  }
  void close() {
    if (_isOpen) _toggle();
  }

  Key? _activeButtonKey;
  Timer? _pressTimer;

  void triggerPress(Key key) {
    if (!mounted) return;
    _pressTimer?.cancel();
    setState(() {
      _activeButtonKey = key;
    });
    _pressTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _activeButtonKey = null;
        });
      }
    });
  }

  void clickForward2s() {
    triggerPress(const Key('floating_forward_2s_button'));
    widget.onForward2s?.call();
  }

  void clickTogglePause() {
    triggerPress(const Key('floating_pause_button'));
    widget.onTogglePause();
  }
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;

  static const Color _buttonColor = Color(0xFF2E2E2E);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward(from: 0.0);
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: const Key('floating_control_menu'),
      bottom: 24,
      right: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isOpen)
            ScaleTransition(
              alignment: Alignment.bottomRight,
              scale: _expandAnimation,
              child: FadeTransition(
                opacity: _expandAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildActionButton(
                      key: const Key('floating_users_button'),
                      icon: Icons.people,
                      label: 'Users',
                      color: _buttonColor,
                      onTap: () {
                        _toggle();
                        widget.onOpenUsers();
                      },
                    ),
                    if (widget.onForward2s != null) ...[
                      const SizedBox(height: 12),
                      _buildActionButton(
                        key: const Key('floating_forward_2s_button'),
                        icon: Icons.fast_forward,
                        label: 'Forward 2s',
                        color: _buttonColor,
                        onTap: widget.onForward2s!,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildActionButton(
                      key: const Key('floating_pause_button'),
                      icon: widget.isPaused ? Icons.play_arrow : Icons.pause,
                      label: widget.isPaused ? 'Resume' : 'Pause',
                      color: _buttonColor,
                      onTap: widget.onTogglePause,
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      key: const Key('floating_restart_button'),
                      icon: Icons.refresh,
                      label: 'Restart',
                      color: _buttonColor,
                      onTap: () {
                        _toggle();
                        widget.restartCallback();
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          SizedBox(
            width: 48,
            height: 48,
            child: FloatingActionButton(
              key: const Key('floating_menu_toggle_button'),
              heroTag: null,
              backgroundColor: _buttonColor,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: _toggle,
              child: Icon(_isOpen ? Icons.close : Icons.settings, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required Key key,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isPressed = _activeButtonKey == key;
    final effectiveColor = isPressed ? const Color(0xFF1E88E5) : color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: isPressed ? const Color(0xFF1E88E5) : Colors.black87,
          borderRadius: BorderRadius.circular(4),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Transform.scale(
          scale: isPressed ? 0.92 : 1.0,
          child: SizedBox(
            width: 48,
            height: 48,
            child: FloatingActionButton(
              key: key,
              heroTag: null,
              backgroundColor: effectiveColor,
              foregroundColor: Colors.white,
              elevation: isPressed ? 1 : 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: () {
                triggerPress(key);
                onTap();
              },
              child: Icon(icon, size: 24),
            ),
          ),
        ),
      ],
    );
  }
}
