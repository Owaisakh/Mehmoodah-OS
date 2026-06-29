import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../shared/widgets/dashboard_shell.dart';
import 'admin_dashboard_provider.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final announcementsAsync = ref.watch(announcementsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DashboardShell(
      title: 'Admin Dashboard',
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminStatsProvider);
          ref.read(announcementsProvider.notifier).fetchAnnouncements();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Text(
                'Welcome Back, Administrator',
                style: AppTextStyles.heading1.copyWith(
                  color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Here is the overview of Mehmoodah Academy today.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Stats Cards Grid
              statsAsync.when(
                data: (stats) => LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 32) / 3;
                    final isMobile = constraints.maxWidth < 600;

                    if (isMobile) {
                      return Column(
                        children: [
                          _buildStatCard(
                            context,
                            'Total Students',
                            stats.totalStudents.toString(),
                            Icons.people_rounded,
                            AppColors.accentSoftBlue,
                          ),
                          const SizedBox(height: 16),
                          _buildStatCard(
                            context,
                            'Total Teachers',
                            stats.totalTeachers.toString(),
                            Icons.school_rounded,
                            AppColors.successGreen,
                          ),
                          const SizedBox(height: 16),
                          _buildStatCard(
                            context,
                            'Total Classes',
                            stats.totalClasses.toString(),
                            Icons.class_rounded,
                            AppColors.warningOrange,
                          ),
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            context,
                            'Total Students',
                            stats.totalStudents.toString(),
                            Icons.people_rounded,
                            AppColors.accentSoftBlue,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            context,
                            'Total Teachers',
                            stats.totalTeachers.toString(),
                            Icons.school_rounded,
                            AppColors.successGreen,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            context,
                            'Total Classes',
                            stats.totalClasses.toString(),
                            Icons.class_rounded,
                            AppColors.warningOrange,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading stats: $err')),
              ),
              const SizedBox(height: 32),

              // Quick Actions Panel
              Text(
                'Quick Actions',
                style: AppTextStyles.heading2.copyWith(
                  color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                ),
              ),
              const SizedBox(height: 16),
              _buildQuickActions(context),
              const SizedBox(height: 32),

              // Recent Announcements section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Announcements',
                    style: AppTextStyles.heading2.copyWith(
                      color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showCreateAnnouncementDialog(context, ref),
                    icon: const Icon(Icons.add_comment_rounded, size: 18),
                    label: const Text('New Announcement'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              announcementsAsync.when(
                data: (announcements) {
                  if (announcements.isEmpty) {
                    return _buildEmptyState(context, 'No announcements posted yet.');
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: announcements.length > 5 ? 5 : announcements.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = announcements[index];
                      return _buildAnnouncementCard(context, item);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading announcements: $err')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: AppTextStyles.heading1.copyWith(
                      color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildActionButton(
          context,
          'Register Student',
          'Add a new student profile and trigger email details.',
          Icons.person_add_rounded,
          AppColors.accentSoftBlue,
          () => context.go(AppRoutes.adminStudents),
        ),
        _buildActionButton(
          context,
          'Add Instructor',
          'Setup new teacher credentials and assign subjects.',
          Icons.group_add_rounded,
          AppColors.successGreen,
          () => context.go(AppRoutes.adminTeachers),
        ),
        _buildActionButton(
          context,
          'Setup Timetable',
          'Manage class times and avoid teacher schedule conflicts.',
          Icons.date_range_rounded,
          AppColors.warningOrange,
          () => context.go(AppRoutes.adminTimetable),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final buttonWidth = width >= 900 ? 260.0 : (width >= 600 ? 220.0 : double.infinity);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: buttonWidth,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.borderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.labelLarge.copyWith(
                color: isDark ? Colors.white : AppColors.primaryDeepNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.textSecondary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(BuildContext context, Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final createdBy = item['users'] != null ? item['users']['full_name'] : 'System';
    final date = DateTime.tryParse(item['created_at'] ?? '')?.toLocal();
    final formattedDate = date != null
        ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        : '';
    final audience = item['audience'] ?? 'all';

    Color audienceColor;
    if (audience == 'all') {
      audienceColor = AppColors.accentSoftBlue;
    } else if (audience == 'teachers') {
      audienceColor = AppColors.successGreen;
    } else {
      audienceColor = AppColors.warningOrange;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: audienceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    audience.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: audienceColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  formattedDate,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.textMuted : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item['title'] ?? '',
              style: AppTextStyles.heading3.copyWith(
                color: isDark ? Colors.white : AppColors.primaryDeepNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item['content'] ?? '',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.textSecondary : AppColors.textSecondary,
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  Icons.person_pin_rounded,
                  size: 16,
                  color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Posted by $createdBy',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.textSecondary : AppColors.textSecondary,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 64,
              color: isDark ? AppColors.darkBorder : AppColors.borderLight,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.textMuted : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAnnouncementDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedAudience = 'all';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'New Announcement',
                style: AppTextStyles.heading3.copyWith(
                  color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                ),
              ),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            hintText: 'Enter title',
                          ),
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedAudience,
                          decoration: const InputDecoration(
                            labelText: 'Audience',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(value: 'teachers', child: Text('Teachers Only')),
                            DropdownMenuItem(value: 'students', child: Text('Students Only')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                selectedAudience = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: contentController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Content',
                            hintText: 'Enter announcement content',
                          ),
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      try {
                        await ref.read(announcementsProvider.notifier).createAnnouncement(
                              title: titleController.text.trim(),
                              content: contentController.text.trim(),
                              audience: selectedAudience,
                            );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Announcement posted successfully')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Post'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
