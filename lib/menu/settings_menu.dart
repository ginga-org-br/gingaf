import 'package:flutter/material.dart';

class SettingsMenu extends StatefulWidget {
  final VoidCallback? onReload;
  final VoidCallback? onRestart;
  final VoidCallback onTogglePause;
  final VoidCallback onOpenUsers;
  final bool isPaused;

  const SettingsMenu({
    super.key,
    this.onReload,
    this.onRestart,
    required this.onTogglePause,
    required this.onOpenUsers,
    this.isPaused = false,
  }) : assert(onReload != null || onRestart != null);

  VoidCallback get restartCallback => onRestart ?? onReload!;

  @override
  State<SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<SettingsMenu>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
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
      key: widget.key ?? const Key('floating_control_menu'),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.black87,
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
        SizedBox(
          width: 48,
          height: 48,
          child: FloatingActionButton(
            key: key,
            heroTag: null,
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onPressed: onTap,
            child: Icon(icon, size: 24),
          ),
        ),
      ],
    );
  }
}
