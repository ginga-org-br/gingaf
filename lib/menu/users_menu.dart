import 'package:flutter/material.dart';
import 'package:gingacc/users.dart';

class UsersMenu extends StatefulWidget {
  final Users users;
  final VoidCallback onClose;
  final ValueChanged<UserData>? onUserSelected;

  const UsersMenu({
    super.key,
    required this.users,
    required this.onClose,
    this.onUserSelected,
  });

  @override
  State<UsersMenu> createState() => _UsersMenuState();
}

class _UsersMenuState extends State<UsersMenu> {
  bool _isManaging = false;

  static const List<Color> _avatarColors = [
    Color(0xFF802BB1),
    Color(0xFF00B4D8),
    Color(0xFF43B02A),
    Color(0xFFB81D24),
    Color(0xFF2E77D0),
    Color(0xFFE5A91E),
    Color(0xFFE91E63),
  ];

  void _removeUser(String userId) {
    setState(() {
      widget.users.removeUser(userId);
    });
  }

  void _selectUser(UserData user) {
    if (_isManaging) return;
    widget.users.setCurrentUser(user.id);
    widget.onUserSelected?.call(user);
    widget.onClose();
  }

  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final genderController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F1F1F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text(
            'Add User',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('add_user_name_input'),
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('add_user_age_input'),
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('add_user_gender_input'),
                  controller: genderController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('add_user_cancel_button'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              key: const Key('add_user_save_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final ageText = ageController.text.trim();
                final genderText = genderController.text.trim();

                final initialProperties = <String, dynamic>{};
                if (ageText.isNotEmpty) {
                  final ageNum = int.tryParse(ageText);
                  initialProperties['age'] = ageNum ?? ageText;
                }
                if (genderText.isNotEmpty) {
                  initialProperties['gender'] = genderText;
                }

                final newId = 'u_${DateTime.now().millisecondsSinceEpoch}';
                final newUser = UserData(
                  id: newId,
                  name: name,
                  initialProperties:
                      initialProperties.isNotEmpty ? initialProperties : null,
                );

                widget.users.registerUser(newUser);
                setState(() {});
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allUsers = widget.users.allUsers;
    final activeId = widget.users.currentUser?.id;

    return Material(
      key: const Key('user_selection_overlay'),
      color: const Color(0xFF141414),
      child: Stack(
        children: [
          Positioned(
            top: 24,
            right: 24,
            child: IconButton(
              key: const Key('user_selection_close_button'),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              tooltip: 'Close',
              onPressed: widget.onClose,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Who's watching?",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (allUsers.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No users found',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ),
                    if (_isManaging) _buildAddUserItem(),
                  ] else
                    Wrap(
                      spacing: 28,
                      runSpacing: 28,
                      alignment: WrapAlignment.center,
                      children: [
                        ...List.generate(allUsers.length, (index) {
                          final user = allUsers[index];
                          final avatarColor =
                              _avatarColors[index % _avatarColors.length];
                          final isActive = user.id == activeId;
                          return _buildUserItem(
                            user: user,
                            color: avatarColor,
                            isActive: isActive,
                            index: index,
                          );
                        }),
                        if (_isManaging) _buildAddUserItem(),
                      ],
                    ),
                  const SizedBox(height: 60),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        key: const Key('user_selection_manage_users_button'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey, width: 1.2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _isManaging = !_isManaging;
                          });
                        },
                        child: Text(
                          _isManaging ? 'Done' : 'Manage Users',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserItem({
    required UserData user,
    required Color color,
    required bool isActive,
    required int index,
  }) {
    final displayName = user.name.isNotEmpty ? user.name : user.id;

    return InkWell(
      key: Key('user_card_${user.id}'),
      onTap: () => _selectUser(user),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                    border: isActive
                        ? Border.all(color: Colors.white, width: 3)
                        : Border.all(color: Colors.transparent, width: 3),
                  ),
                  child: CustomPaint(
                    painter: _UserSelectionSmilePainter(styleIndex: index),
                  ),
                ),
                if (_isManaging)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: IconButton(
                          key: Key('remove_user_${user.id}'),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 36,
                          ),
                          onPressed: () => _removeUser(user.id),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 130,
              child: Text(
                displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF808080),
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddUserItem() {
    return InkWell(
      key: const Key('add_user_card'),
      onTap: _showAddUserDialog,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade700, width: 2),
              ),
              child: const Icon(
                Icons.add,
                size: 54,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 130,
              child: Text(
                'Add User',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF808080),
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserSelectionSmilePainter extends CustomPainter {
  final int styleIndex;

  const _UserSelectionSmilePainter({this.styleIndex = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final mouthPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final leftEye = Offset(cx - size.width * 0.22, cy - size.height * 0.08);
    final rightEye = Offset(cx + size.width * 0.22, cy - size.height * 0.08);
    final eyeRadius = size.width * 0.045;

    canvas.drawCircle(leftEye, eyeRadius, eyePaint);
    canvas.drawCircle(rightEye, eyeRadius, eyePaint);

    final mouthPath = Path();
    final mouthLeft = Offset(cx - size.width * 0.24, cy + size.height * 0.12);
    final mouthRight = Offset(cx + size.width * 0.24, cy + size.height * 0.12);
    final mouthBottom = Offset(cx, cy + size.height * 0.25);

    mouthPath.moveTo(mouthLeft.dx, mouthLeft.dy);
    mouthPath.quadraticBezierTo(
      mouthBottom.dx,
      mouthBottom.dy,
      mouthRight.dx,
      mouthRight.dy,
    );
    canvas.drawPath(mouthPath, mouthPaint);
  }

  @override
  bool shouldRepaint(covariant _UserSelectionSmilePainter oldDelegate) =>
      oldDelegate.styleIndex != styleIndex;
}
