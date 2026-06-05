import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../services/profile_provider.dart';
import '../../widgets/status_badge.dart';
import 'components/profile_actions_list.dart';
import 'components/profile_details_card.dart';
import 'components/profile_error.dart';
import 'components/profile_header.dart';
import 'components/profile_loading.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(profileProvider.notifier).refreshProfile(),
        color: AppColors.primary,
        child: profileAsync.when(
          loading: () => const ProfileLoading(),
          error: (err, stack) => ProfileError(
            error: err.toString(),
            onRetry: () => ref.read(profileProvider.notifier).refreshProfile(),
          ),
          data: (profile) {
            if (profile == null) {
              return const Center(
                child: Text('No profile data found'),
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                ProfileHeader(profile: profile),
                const SizedBox(height: 64),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        profile.fullName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profile.email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.subText, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: StatusBadge(
                          label: profile.role,
                          color: AppColors.primary,
                          background: AppColors.primarySoft,
                        ),
                      ),
                      const SizedBox(height: 28),
                      ProfileDetailsCard(profile: profile),
                      const SizedBox(height: 28),
                      const ProfileActionsList(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
