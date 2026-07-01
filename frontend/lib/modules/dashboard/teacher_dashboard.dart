import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../shared/widgets/dashboard_shell.dart';
import '../assignments/assignments_provider.dart';
import '../attendance/attendance_provider.dart';

// ---------------------------------------------------------------------------
// Provider: today's attendance summary for teacher's classes
// ---------------------------------------------------------------------------
final teacherTodayAttendanceProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return {};

  final teacherRow = await client
      .from('teachers')
      .select('id, users!inner(auth_user_id)')
      .eq('users.auth_user_id', userId)
      .maybeSingle();

  if (teacherRow == null) return {};
  final teacherId = teacherRow['id'] as String;

  // Get all class IDs for this teacher
  final classRows = await client
      .from('class_teachers')
      .select('class_id')
      .eq('teacher_id', teacherId);

  if (classRows.isEmpty) return {};
  final classIds = classRows.map((r) => r['class_id'] as String).toList();

  final today = DateTime.now();
  final todayStr =
      '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

  int present = 0, absent = 0, late = 0, leave = 0, total = 0;

  for (final cid in classIds) {
    final rows = await client
        .from('attendance')
        .select('status')
        .eq('class_id', cid)
        .eq('date', todayStr);

    for (final r in rows) {
      final status = r['status'] as String;
      total++;
      if (status == 'present') present++;
      else if (status == 'absent') absent++;
      else if (status == 'late') late++;
      else if (status == 'leave') leave++;
    }
  }

  return {
    'present': present,
    'absent': absent,
    'late': late,
    'leave': leave,
    'total': total,
    'classCount': classIds.length,
    'today': todayStr,
  };
});

// ---------------------------------------------------------------------------
// Provider: pending submissions for teacher (all their assignments)
// ---------------------------------------------------------------------------
final teacherPendingGradesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];

  final teacherRow = await client
      .from('teachers')
      .select('id, users!inner(auth_user_id)')
      .eq('users.auth_user_id', userId)
      .maybeSingle();

  if (teacherRow == null) return [];
  final teacherId = teacherRow['id'] as String;

  // Get assignments for this teacher
  final assignments = await client
      .from('assignments')
      .select('id, title')
      .eq('teacher_id', teacherId);

  if (assignments.isEmpty) return [];
  final assignmentIds = assignments.map((a) => a['id'] as String).toList();

  // Get ungraded submissions
  final subs = await client
      .from('submissions')
      .select('id, assignment_id, status, students(id, roll_number, users(full_name))')
      .inFilter('assignment_id', assignmentIds)
      .neq('status', 'graded');

  // Attach assignment title
  final assignmentTitles = {for (final a in assignments) a['id'] as String: a['title'] as String};

  return List<Map<String, dynamic>>.from(subs).map((s) {
    return {
      ...s,
      'assignment_title': assignmentTitles[s['assignment_id'] as String] ?? '',
    };
  }).toList();
});

// ---------------------------------------------------------------------------
// Teacher Dashboard Screen
// ---------------------------------------------------------------------------
class TeacherDashboard extends ConsumerWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(teacherTodayAttendanceProvider);
    final pendingAsync = ref.watch(teacherPendingGradesProvider);
    final classesAsync = ref.watch(teacherClassesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final client = ref.watch(supabaseClientProvider);
    final email = client.auth.currentUser?.email ?? '';

    return DashboardShell(
      title: 'Teacher Dashboard',
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(teacherTodayAttendanceProvider);
          ref.invalidate(teacherPendingGradesProvider);
          ref.invalidate(teacherClassesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back! 👋',
                          style: AppTextStyles.heading1.copyWith(
                            color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Date chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoftBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accentSoftBlue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.today_rounded,
                            size: 16, color: AppColors.accentSoftBlue),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(DateTime.now()),
                          style: const TextStyle(
                            color: AppColors.accentSoftBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Quick actions
              _buildQuickActions(context, isDark),
              const SizedBox(height: 28),

              // Today's attendance summary
              Text(
                "Today's Attendance",
                style: AppTextStyles.heading2.copyWith(
                  color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                ),
              ),
              const SizedBox(height: 16),
              attendanceAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (data) => _buildAttendanceSummary(context, data, isDark),
              ),
              const SizedBox(height: 28),

              // My classes
              Text(
                'My Classes',
                style: AppTextStyles.heading2.copyWith(
                  color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                ),
              ),
              const SizedBox(height: 16),
              classesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (classes) => _buildClassChips(classes, isDark),
              ),
              const SizedBox(height: 28),

              // Pending assignments to grade
              Row(
                children: [
                  Text(
                    'Pending to Grade',
                    style: AppTextStyles.heading2.copyWith(
                      color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  pendingAsync.when(
                    data: (subs) => subs.isEmpty
                        ? const SizedBox()
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warningOrange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${subs.length}',
                              style: const TextStyle(
                                color: AppColors.warningOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              pendingAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (subs) => _buildPendingList(context, subs, isDark),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    final actions = [
      (
        label: 'Mark Attendance',
        icon: Icons.check_circle_rounded,
        color: AppColors.successGreen,
        route: AppRoutes.teacherAttendance,
      ),
      (
        label: 'Enter Results',
        icon: Icons.grade_rounded,
        color: AppColors.accentSoftBlue,
        route: AppRoutes.teacherResults,
      ),
      (
        label: 'Assignments',
        icon: Icons.assignment_rounded,
        color: AppColors.warningOrange,
        route: AppRoutes.teacherAssignments,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return isWide
            ? Row(
                children: actions
                    .map((a) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: _quickActionCard(
                                context, a.label, a.icon, a.color, a.route, isDark),
                          ),
                        ))
                    .toList(),
              )
            : Column(
                children: actions
                    .map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _quickActionCard(
                              context, a.label, a.icon, a.color, a.route, isDark),
                        ))
                    .toList(),
              );
      },
    );
  }

  Widget _quickActionCard(BuildContext context, String label, IconData icon,
      Color color, String route, bool isDark) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.85), color.withOpacity(0.65)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSummary(
      BuildContext context, Map<String, dynamic> data, bool isDark) {
    if (data.isEmpty) {
      return _infoCard(
        icon: Icons.check_circle_outline_rounded,
        message: 'No attendance recorded today.',
        subtext: 'Go to Attendance to mark your classes.',
        isDark: isDark,
      );
    }

    final total = (data['total'] as int?) ?? 0;
    final present = (data['present'] as int?) ?? 0;
    final absent = (data['absent'] as int?) ?? 0;
    final late = (data['late'] as int?) ?? 0;
    final leave = (data['leave'] as int?) ?? 0;
    final classCount = (data['classCount'] as int?) ?? 0;
    final pct = total > 0 ? (present / total * 100).toStringAsFixed(1) : '--';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$classCount class${classCount == 1 ? '' : 'es'} · $total students marked',
                style: AppTextStyles.bodySmall,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pct% present',
                  style: const TextStyle(
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total > 0 ? present / total : 0,
              backgroundColor:
                  isDark ? AppColors.darkBorder : AppColors.borderLight,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.successGreen),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          // Stats
          Row(
            children: [
              _statPill('Present', present, AppColors.successGreen),
              const SizedBox(width: 10),
              _statPill('Absent', absent, AppColors.dangerRed),
              const SizedBox(width: 10),
              _statPill('Late', late, AppColors.warningOrange),
              const SizedBox(width: 10),
              _statPill('Leave', leave, AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildClassChips(List<Map<String, dynamic>> classes, bool isDark) {
    if (classes.isEmpty) {
      return _infoCard(
        icon: Icons.class_outlined,
        message: 'No classes assigned yet.',
        isDark: isDark,
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: classes.map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.accentSoftBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${c['name']} – Sec ${c['section']}',
                style: AppTextStyles.labelLarge.copyWith(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Grade ${c['grade_level']}',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPendingList(
      BuildContext context, List<Map<String, dynamic>> subs, bool isDark) {
    if (subs.isEmpty) {
      return _infoCard(
        icon: Icons.task_alt_rounded,
        message: 'All caught up!',
        subtext: 'No pending submissions to grade.',
        isDark: isDark,
        color: AppColors.successGreen,
      );
    }

    return Column(
      children: subs.take(5).map((s) {
        final student = s['students'] as Map<String, dynamic>? ?? {};
        final user = student['users'] as Map<String, dynamic>? ?? {};
        final name = user['full_name'] as String? ?? 'Unknown';
        final roll = student['roll_number'] as String? ?? '';
        final title = s['assignment_title'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.warningOrange.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warningOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pending_rounded,
                    color: AppColors.warningOrange, size: 18),
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
                      ),
                    ),
                    Text(
                      '$name · Roll $roll',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => context.go(AppRoutes.teacherAssignments),
                icon: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String message,
    String? subtext,
    required bool isDark,
    Color? color,
  }) {
    final c = color ?? (isDark ? AppColors.darkBorder : AppColors.borderLight);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, size: 36, color: c),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                if (subtext != null) ...[
                  const SizedBox(height: 4),
                  Text(subtext, style: AppTextStyles.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday]}, ${d.day} ${months[d.month]} ${d.year}';
  }
}
