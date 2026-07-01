import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../shared/widgets/dashboard_shell.dart';
import 'student_dashboard_provider.dart';

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardDataAsync = ref.watch(studentDashboardDataProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DashboardShell(
      title: 'Student Dashboard',
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(studentDashboardDataProvider);
        },
        child: dashboardDataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading dashboard: $err')),
          data: (data) {
            if (data.studentProfile == null) {
              return _buildNoProfileState(context, isDark);
            }

            final profile = data.studentProfile!;
            final user = profile['users'] as Map<String, dynamic>? ?? {};
            final cls = profile['classes'] as Map<String, dynamic>? ?? {};
            final fullName = user['full_name'] ?? 'Student';
            final className = cls['name'] ?? 'Unassigned';
            final classSection = cls['section'] ?? '';
            final rollNumber = profile['roll_number'] ?? '--';

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header Section
                  _buildHeader(context, fullName, className, classSection, rollNumber, isDark),
                  const SizedBox(height: 28),

                  // Quick Action Grid (e.g. View Attendance, Homework, Results)
                  _buildQuickActions(context, isDark),
                  const SizedBox(height: 28),

                  // Attendance Widget
                  _buildAttendanceSection(context, data, isDark),
                  const SizedBox(height: 28),

                  // Main Two Column Layout (or column on small screens)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _buildHomeworkSection(context, data.pendingHomework, isDark),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 4,
                              child: _buildAnnouncementsSection(context, data.announcements, isDark),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildHomeworkSection(context, data.pendingHomework, isDark),
                            const SizedBox(height: 28),
                            _buildAnnouncementsSection(context, data.announcements, isDark),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Welcome Header
  Widget _buildHeader(
    BuildContext context,
    String name,
    String className,
    String section,
    dynamic roll,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.darkSurface, AppColors.darkBackground]
              : [AppColors.primaryDeepNavy, AppColors.accentSoftBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeepNavy.withOpacity(isDark ? 0.05 : 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'S',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Back, $name!',
                  style: AppTextStyles.heading2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _headerInfoChip(Icons.class_rounded, '$className ($section)'),
                    _headerInfoChip(Icons.pin_outlined, 'Roll No: $roll'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Quick Action cards redirecting to specific details
  Widget _buildQuickActions(BuildContext context, bool isDark) {
    final actions = [
      (
        label: 'My Homework',
        icon: Icons.homework_rounded,
        color: AppColors.accentSoftBlue,
        route: AppRoutes.studentHomework,
      ),
      (
        label: 'My Attendance',
        icon: Icons.date_range_rounded,
        color: AppColors.successGreen,
        route: AppRoutes.studentAttendance,
      ),
      (
        label: 'Exam Results',
        icon: Icons.grade_rounded,
        color: AppColors.warningOrange,
        route: AppRoutes.studentResults,
      ),
      (
        label: 'Timetable',
        icon: Icons.calendar_month_rounded,
        color: AppColors.primaryDeepNavy,
        route: AppRoutes.studentTimetable,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = 16;
        final int crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;
        final width = (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions.map((a) {
            return InkWell(
              onTap: () => context.go(a.route),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: width,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: a.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(a.icon, color: a.color, size: 24),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      a.label,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View info & updates',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // Attendance rate and status counts
  Widget _buildAttendanceSection(BuildContext context, StudentDashboardData data, bool isDark) {
    final present = data.totalPresent;
    final late = data.totalLate;
    final absent = data.totalAbsent;
    final leave = data.totalLeave;
    final rate = data.attendanceRate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attendance Summary',
                style: AppTextStyles.heading3.copyWith(
                  color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                ),
              ),
              TextButton.icon(
                onPressed: () => context.go(AppRoutes.studentAttendance),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('View Calendar'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final childWidgets = [
                // Radial Rate or Linear Indicator
                Expanded(
                  flex: isMobile ? 0 : 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(
                              value: rate / 100,
                              strokeWidth: 10,
                              backgroundColor: isDark ? AppColors.darkBorder : AppColors.borderLight,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                rate >= 75 ? AppColors.successGreen : AppColors.warningOrange,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${rate.toStringAsFixed(1)}%',
                                style: AppTextStyles.heading3.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Rate',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isMobile) const SizedBox(height: 20),
                // Stat Pills
                Expanded(
                  flex: isMobile ? 0 : 3,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _attendanceStatCard('Present', present, AppColors.successGreen, isDark),
                          const SizedBox(width: 12),
                          _attendanceStatCard('Late', late, AppColors.warningOrange, isDark),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _attendanceStatCard('Absent', absent, AppColors.dangerRed, isDark),
                          const SizedBox(width: 12),
                          _attendanceStatCard('Leave', leave, AppColors.textSecondary, isDark),
                        ],
                      ),
                    ],
                  ),
                ),
              ];

              return isMobile
                  ? Column(children: childWidgets.map((w) => w is Expanded ? w.child : w).toList())
                  : Row(children: childWidgets);
            },
          ),
        ],
      ),
    );
  }

  Widget _attendanceStatCard(String label, int count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.borderLight,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count.toString(),
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Icon(Icons.check_circle_outline_rounded, color: color.withOpacity(0.7), size: 24),
          ],
        ),
      ),
    );
  }

  // Homework Alerts Section
  Widget _buildHomeworkSection(BuildContext context, List<Map<String, dynamic>> pendingHomework, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upcoming Homework Alerts',
                style: AppTextStyles.heading3.copyWith(
                  color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (pendingHomework.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.dangerRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${pendingHomework.length} Pending',
                    style: const TextStyle(
                      color: AppColors.dangerRed,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (pendingHomework.isEmpty)
            _buildEmptyState(
              context,
              Icons.done_all_rounded,
              'All caught up!',
              'You have no pending homework assignments.',
              isDark,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingHomework.length > 4 ? 4 : pendingHomework.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final a = pendingHomework[index];
                final title = a['title'] ?? 'Assignment';
                final dueDateStr = a['due_date'] ?? '';
                final teacher = a['teachers'] as Map<String, dynamic>? ?? {};
                final teacherUser = teacher['users'] as Map<String, dynamic>? ?? {};
                final teacherName = teacherUser['full_name'] ?? 'Teacher';

                DateTime? due;
                bool isOverdue = false;
                if (dueDateStr.isNotEmpty) {
                  due = DateTime.tryParse(dueDateStr);
                  if (due != null) {
                    isOverdue = due.isBefore(DateTime.now());
                  }
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBackground : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoftBlue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.assignment_rounded, color: AppColors.accentSoftBlue, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTextStyles.labelLarge.copyWith(
                                color: isDark ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'By $teacherName',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            due != null ? '${due.day}/${due.month}/${due.year}' : '--',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isOverdue ? AppColors.dangerRed : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isOverdue ? 'Overdue' : 'Due Date',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOverdue ? AppColors.dangerRed : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => context.go(AppRoutes.studentHomework),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Announcements Feed
  Widget _buildAnnouncementsSection(BuildContext context, List<Map<String, dynamic>> announcements, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
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
          Text(
            'Announcements Feed',
            style: AppTextStyles.heading3.copyWith(
              color: isDark ? Colors.white : AppColors.primaryDeepNavy,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (announcements.isEmpty)
            _buildEmptyState(
              context,
              Icons.campaign_outlined,
              'All quiet here',
              'No new announcements posted.',
              isDark,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: announcements.length > 5 ? 5 : announcements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = announcements[index];
                final title = item['title'] ?? '';
                final content = item['content'] ?? '';
                final author = item['users'] != null ? item['users']['full_name'] : 'System';
                final dateStr = item['created_at'] ?? '';
                DateTime? date = DateTime.tryParse(dateStr);
                final formattedDate = date != null
                    ? '${date.day} ${_getMonthName(date.month)}'
                    : '';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBackground : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppTextStyles.labelLarge.copyWith(
                                color: isDark ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedDate,
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        content,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? AppColors.textSecondary : AppColors.textSecondary,
                        ),
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'By $author',
                            style: AppTextStyles.caption.copyWith(
                              color: isDark ? AppColors.textSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, IconData icon, String title, String description, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.borderLight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: isDark ? AppColors.darkBorder : AppColors.borderLight),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(
              color: isDark ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoProfileState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.dangerRed),
            const SizedBox(height: 16),
            Text(
              'Profile Not Found',
              style: AppTextStyles.heading2.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No student profile is associated with this account. Please contact school administration.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }
}
