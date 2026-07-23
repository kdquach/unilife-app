import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/user_profile.dart';
import '../../../services/api_client.dart';

class ProfileHeader extends StatelessWidget {
  final UserProfile profile;

  /// Optional — shows a small camera badge on the avatar when provided.
  final VoidCallback? onEditAvatar;

  const ProfileHeader({
    super.key,
    required this.profile,
    this.onEditAvatar,
  });

  static const double _bannerHeight = 168;
  static const double _avatarRadius = 44;

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      final first = parts.first.isNotEmpty ? parts.first[0] : '';
      final last = parts.last.isNotEmpty ? parts.last[0] : '';
      return (first + last).toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String? _resolveAvatarUrl() {
    final avatarUrl = profile.avatarUrl;
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('http')) return avatarUrl;
    final uri = Uri.parse(ApiClient.baseUrl);
    final host = '${uri.scheme}://${uri.authority}';
    return '$host$avatarUrl';
  }

  @override
  Widget build(BuildContext context) {
    final fullAvatarUrl = _resolveAvatarUrl();

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Container(
        height: _bannerHeight,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10B981), Color(0xFF3B82F6), Color(0xFFF97316)],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ─── Decorative circles for depth ───────────────────────────────
            Positioned(
              right: -30,
              top: -30,
              child: _decorCircle(120, Colors.white.withValues(alpha: 0.12)),
            ),
            Positioned(
              left: -20,
              bottom: -40,
              child: _decorCircle(100, Colors.white.withValues(alpha: 0.10)),
            ),
            Positioned(
              right: 40,
              bottom: -10,
              child: _decorCircle(48, Colors.white.withValues(alpha: 0.15)),
            ),

            // ─── Info (left) + Avatar (right) sitting on the banner ─────────
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          profile.fullName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                          ),
                          child: Text(
                            profile.role,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildAvatar(fullAvatarUrl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decorCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Avatar — white ring, soft shadow, optional camera/edit badge
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildAvatar(String? fullAvatarUrl) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: _avatarRadius,
            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
            child: fullAvatarUrl == null
                ? Text(
                    _getInitials(profile.fullName),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  )
                : ClipOval(
                    child: Image.network(
                      fullAvatarUrl,
                      fit: BoxFit.cover,
                      width: _avatarRadius * 2,
                      height: _avatarRadius * 2,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            _getInitials(profile.fullName),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
        if (onEditAvatar != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: onEditAvatar,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 13,
                  color: Color(0xFF10B981),
                ),
              ),
            ),
          ),
      ],
    );
  }
}