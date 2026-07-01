import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../shared/widgets/dashboard_shell.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/skeleton_loading.dart';
import '../../shared/widgets/error_boundary.dart';
import '../attendance/attendance_provider.dart';
import 'assignments_provider.dart';

class AssignmentsPage extends ConsumerStatefulWidget {
  const AssignmentsPage({super.key});

  @override
  ConsumerState<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends ConsumerState<AssignmentsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(userRoleProvider);
    final role = roleAsync.value ?? 'student';

    return DashboardShell(
      title: role == 'teacher' ? 'Assignments' : 'Homework',
      child: role == 'teacher' ? _buildTeacherView() : _buildStudentView(),
    );
  }

  // ===========================================================================
  // TEACHER VIEW
  // ===========================================================================
  Widget _buildTeacherView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Tab bar
        Container(
          color: isDark ? AppColors.darkSurface : Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.accentSoftBlue,
            unselectedLabelColor:
                isDark ? AppColors.textMuted : AppColors.textSecondary,
            indicatorColor: AppColors.accentSoftBlue,
            tabs: const [
              Tab(text: 'My Assignments'),
              Tab(text: 'Submissions'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _teacherAssignmentsList(isDark),
              _teacherSubmissionsList(isDark),
            ],
          ),
        ),
      ],
    );
  }

  // --- Teacher: list assignments
  Widget _teacherAssignmentsList(bool isDark) {
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(teacherAssignmentsProvider),
      child: assignmentsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24.0),
          child: SkeletonListLoader(itemCount: 4),
        ),
        error: (e, _) => AppErrorState(
          errorMessage: 'Error loading assignments: $e',
          onRetry: () => ref.invalidate(teacherAssignmentsProvider),
        ),
        data: (assignments) {
          return Stack(
            children: [
              if (assignments.isEmpty)
                const AppEmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No Assignments',
                  description: 'You have not created any assignments yet. Tap the button below to add one.',
                )
              else
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                  itemCount: assignments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final a = assignments[i];
                    return _assignmentTeacherCard(a, isDark);
                  },
                ),

              // FAB for create
              Positioned(
                bottom: 24,
                right: 24,
                child: FloatingActionButton.extended(
                  onPressed: () => _showCreateDialog(isDark),
                  backgroundColor: AppColors.accentSoftBlue,
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: const Text('New Assignment',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _assignmentTeacherCard(Map<String, dynamic> a, bool isDark) {
    final cls = a['classes'] as Map<String, dynamic>? ?? {};
    final dueDate = a['due_date'] as String? ?? '';
    final title = a['title'] as String? ?? '';

    DateTime? due;
    bool isOverdue = false;
    if (dueDate.isNotEmpty) {
      due = DateTime.tryParse(dueDate);
      if (due != null) isOverdue = due.isBefore(DateTime.now());
    }

    return InkWell(
      onTap: () => _showSubmissionsFor(a, isDark),
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoftBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_rounded,
                      color: AppColors.accentSoftBlue, size: 20),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 2),
                      Text(
                        '${cls['name'] ?? ''} – Sec ${cls['section'] ?? ''}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                _dueBadge(dueDate, isOverdue),
              ],
            ),
            if ((a['description'] as String?) != null &&
                (a['description'] as String).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                a['description'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.textSecondary : AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.people_outline, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('Tap to view submissions',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.accentSoftBlue,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dueBadge(String dueDate, bool isOverdue) {
    if (dueDate.isEmpty) return const SizedBox();
    final date = DateTime.tryParse(dueDate);
    if (date == null) return const SizedBox();
    final formatted =
        '${date.day}/${date.month}/${date.year}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOverdue
            ? AppColors.dangerRed.withOpacity(0.1)
            : AppColors.warningOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverdue
              ? AppColors.dangerRed.withOpacity(0.3)
              : AppColors.warningOrange.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 12,
            color: isOverdue ? AppColors.dangerRed : AppColors.warningOrange,
          ),
          const SizedBox(width: 4),
          Text(
            formatted,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOverdue ? AppColors.dangerRed : AppColors.warningOrange,
            ),
          ),
        ],
      ),
    );
  }

  // --- Teacher: view submissions for specific assignment
  void _showSubmissionsFor(Map<String, dynamic> assignment, bool isDark) {
    final aid = assignment['id'] as String;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scrollCtrl) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Consumer(
              builder: (context, ref, _) {
                final subsAsync = ref.watch(assignmentSubmissionsProvider(aid));
                return subsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (submissions) => Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                assignment['title'] as String? ?? '',
                                style: AppTextStyles.heading3.copyWith(
                                  color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                                ),
                              ),
                            ),
                            _submissionCountBadge(submissions.length),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: submissions.isEmpty
                            ? Center(
                                child: Text('No submissions yet.',
                                    style: AppTextStyles.bodyMedium))
                            : ListView.builder(
                                controller: scrollCtrl,
                                padding: const EdgeInsets.all(16),
                                itemCount: submissions.length,
                                itemBuilder: (_, i) => _submissionCard(
                                    submissions[i], isDark, ref),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _submissionCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentSoftBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count submitted',
        style: const TextStyle(
            color: AppColors.accentSoftBlue,
            fontWeight: FontWeight.bold,
            fontSize: 13),
      ),
    );
  }

  Widget _submissionCard(
      Map<String, dynamic> sub, bool isDark, WidgetRef ref) {
    final student = sub['students'] as Map<String, dynamic>? ?? {};
    final users = student['users'] as Map<String, dynamic>? ?? {};
    final name = users['full_name'] as String? ?? 'Unknown';
    final roll = student['roll_number'] as String? ?? '';
    final status = sub['status'] as String? ?? 'submitted';
    final grade = sub['grade'] as String?;
    final fileUrl = sub['file_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accentSoftBlue.withOpacity(0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.accentSoftBlue,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        )),
                    Text('Roll: $roll', style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              _statusBadge(status, grade),
            ],
          ),
          if (fileUrl != null && fileUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('📎 $fileUrl',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.accentSoftBlue,
                ),
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () =>
                _showGradeDialog(sub['id'] as String, isDark, ref),
            icon: const Icon(Icons.grade_rounded, size: 16),
            label: Text(grade != null ? 'Update Grade' : 'Grade'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status, String? grade) {
    Color color;
    String label;
    if (status == 'graded') {
      color = AppColors.successGreen;
      label = grade != null ? 'Grade: $grade' : 'Graded';
    } else {
      color = AppColors.warningOrange;
      label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  void _showGradeDialog(String submissionId, bool isDark, WidgetRef ref) {
    final gradeCtrl = TextEditingController();
    final feedbackCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Grade Submission',
            style: AppTextStyles.heading3.copyWith(
              color: isDark ? Colors.white : AppColors.primaryDeepNavy,
            )),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: gradeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Grade (e.g. A, 85/100)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: feedbackCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Feedback (optional)',
                  hintText: 'Write feedback for the student...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(submissionGradeProvider.notifier).grade(
                      submissionId: submissionId,
                      grade: gradeCtrl.text.trim(),
                      feedback: feedbackCtrl.text.trim(),
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Submission graded!'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save Grade'),
          ),
        ],
      ),
    );
  }

  // --- Teacher: all submissions tab
  Widget _teacherSubmissionsList(bool isDark) {
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);

    return assignmentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24.0),
        child: SkeletonListLoader(itemCount: 4),
      ),
      error: (e, _) => AppErrorState(
        errorMessage: 'Error loading submissions: $e',
        onRetry: () => ref.invalidate(teacherAssignmentsProvider),
      ),
      data: (assignments) {
        if (assignments.isEmpty) {
          return const AppEmptyState(
            icon: Icons.assignment_turned_in_outlined,
            title: 'No Work to Grade',
            description: 'There are no assignments with student submissions to review yet.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: assignments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, i) {
            final a = assignments[i];
            final aid = a['id'] as String;
            final subsAsync = ref.watch(assignmentSubmissionsProvider(aid));
            final pending = subsAsync.value
                    ?.where((s) => s['status'] != 'graded')
                    .length ??
                0;

            return InkWell(
              onTap: () => _showSubmissionsFor(a, isDark),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_rounded,
                        color: AppColors.accentSoftBlue),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        a['title'] as String? ?? '',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (pending > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warningOrange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$pending to grade',
                          style: const TextStyle(
                              color: AppColors.warningOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Create dialog
  void _showCreateDialog(bool isDark) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedClassId;
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final classesAsync = ref.watch(teacherClassesProvider);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Create Assignment',
                style: AppTextStyles.heading3.copyWith(
                  color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                )),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'e.g. Chapter 5 Worksheet',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Instructions for students...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      classesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error: $e'),
                        data: (classes) => DropdownButtonFormField<String>(
                          value: selectedClassId,
                          decoration: const InputDecoration(labelText: 'Class'),
                          items: classes
                              .map((c) => DropdownMenuItem<String>(
                                    value: c['id'] as String,
                                    child: Text(
                                        '${c['name']} – Sec ${c['section']}'),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setDlg(() => selectedClassId = v),
                          validator: (v) =>
                              v == null ? 'Please select a class' : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: dueDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDlg(() => dueDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'Due Date'),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded,
                                  size: 18, color: AppColors.accentSoftBlue),
                              const SizedBox(width: 8),
                              Text(
                                '${dueDate.day}/${dueDate.month}/${dueDate.year}',
                                style: AppTextStyles.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState?.validate() ?? false) {
                    try {
                      await ref.read(assignmentCreationProvider.notifier).create(
                            title: titleCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            classId: selectedClassId!,
                            dueDate:
                                '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
                          );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ref.invalidate(teacherAssignmentsProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Assignment created!'),
                            backgroundColor: AppColors.successGreen,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // STUDENT VIEW — Homework list with submission button
  // ===========================================================================
  Widget _buildStudentView() {
    final assignmentsAsync = ref.watch(studentAssignmentsProvider);
    final mySubsAsync = ref.watch(studentSubmissionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(studentAssignmentsProvider);
        ref.invalidate(studentSubmissionsProvider);
      },
      child: assignmentsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24.0),
          child: SkeletonListLoader(itemCount: 4),
        ),
        error: (e, _) => AppErrorState(
          errorMessage: 'Error loading homework: $e',
          onRetry: () {
            ref.invalidate(studentAssignmentsProvider);
            ref.invalidate(studentSubmissionsProvider);
          },
        ),
        data: (assignments) {
          if (assignments.isEmpty) {
            return const AppEmptyState(
              icon: Icons.homework_rounded,
              title: 'No Homework Posted',
              description: 'You are completely caught up! No homework has been posted.',
            );
          }

          // Build submission map
          final Map<String, Map<String, dynamic>> submissionByAssignment = {};
          mySubsAsync.whenData((subs) {
            for (final s in subs) {
              submissionByAssignment[s['assignment_id'] as String] = s;
            }
          });

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: assignments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) {
              final a = assignments[i];
              final aid = a['id'] as String;
              final mySubmission = submissionByAssignment[aid];
              return _studentAssignmentCard(a, mySubmission, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _studentAssignmentCard(
      Map<String, dynamic> a, Map<String, dynamic>? submission, bool isDark) {
    final title = a['title'] as String? ?? '';
    final description = a['description'] as String? ?? '';
    final dueDate = a['due_date'] as String? ?? '';
    final teacher = a['teachers'] as Map<String, dynamic>? ?? {};
    final teacherUsers = teacher['users'] as Map<String, dynamic>? ?? {};
    final teacherName = teacherUsers['full_name'] as String? ?? 'Teacher';

    DateTime? due;
    bool isOverdue = false;
    if (dueDate.isNotEmpty) {
      due = DateTime.tryParse(dueDate);
      if (due != null) isOverdue = due.isBefore(DateTime.now());
    }

    final hasSubmitted = submission != null;
    final isGraded = submission?['status'] == 'graded';
    final grade = submission?['grade'] as String?;
    final feedback = submission?['feedback'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGraded
              ? AppColors.successGreen.withOpacity(0.3)
              : (isDark ? AppColors.darkBorder : AppColors.borderLight),
        ),
        boxShadow: isGraded
            ? [BoxShadow(color: AppColors.successGreen.withOpacity(0.05), blurRadius: 8)]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isGraded
                            ? AppColors.successGreen
                            : (hasSubmitted
                                ? AppColors.warningOrange
                                : AppColors.accentSoftBlue))
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isGraded
                        ? Icons.assignment_turned_in_rounded
                        : (hasSubmitted
                            ? Icons.pending_rounded
                            : Icons.assignment_rounded),
                    color: isGraded
                        ? AppColors.successGreen
                        : (hasSubmitted
                            ? AppColors.warningOrange
                            : AppColors.accentSoftBlue),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: isDark ? Colors.white : AppColors.primaryDeepNavy,
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
                _dueBadge(dueDate, isOverdue),
              ],
            ),

            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.textSecondary : AppColors.textSecondary,
                ),
              ),
            ],

            if (isGraded && grade != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.successGreen.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.grade_rounded,
                            size: 16, color: AppColors.successGreen),
                        const SizedBox(width: 6),
                        Text(
                          'Grade: $grade',
                          style: const TextStyle(
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (feedback != null && feedback.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        feedback,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? AppColors.textSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Submit button or status
            if (!hasSubmitted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isOverdue
                      ? null
                      : () => _showSubmitDialog(
                          a['id'] as String, title, isDark),
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  label: Text(isOverdue ? 'Deadline passed' : 'Submit Work'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isOverdue ? AppColors.textMuted : AppColors.accentSoftBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              )
            else if (!isGraded)
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.warningOrange, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Submitted – awaiting grade',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.warningOrange),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showSubmitDialog(String assignmentId, String title, bool isDark) {
    final urlCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Submit: $title',
            style: AppTextStyles.heading3.copyWith(
              color: isDark ? Colors.white : AppColors.primaryDeepNavy,
            )),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'File URL or Link',
                hintText: 'Paste a Google Drive / OneDrive link...',
                prefixIcon: Icon(Icons.link_rounded),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Please enter a link' : null,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                try {
                  await ref.read(submissionNotifierProvider.notifier).submit(
                        assignmentId: assignmentId,
                        fileUrl: urlCtrl.text.trim(),
                      );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ref.invalidate(studentSubmissionsProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Assignment submitted!'),
                        backgroundColor: AppColors.successGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  }
}
