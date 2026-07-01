import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../shared/widgets/dashboard_shell.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/skeleton_loading.dart';
import '../../shared/widgets/error_boundary.dart';
import '../attendance/attendance_provider.dart';
import 'results_provider.dart';

class ResultsPage extends ConsumerStatefulWidget {
  const ResultsPage({super.key});

  @override
  ConsumerState<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends ConsumerState<ResultsPage> {
  String? _selectedClassId;
  String? _selectedExamId;
  bool _marksLoaded = false;
  String _subjectFilter = '';

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(userRoleProvider);
    final role = roleAsync.value ?? 'student';

    return DashboardShell(
      title: 'Results & Grades',
      child: role == 'teacher' ? _buildTeacherView() : _buildStudentView(),
    );
  }

  // ===========================================================================
  // TEACHER VIEW — Select class → exam → enter marks
  // ===========================================================================
  Widget _buildTeacherView() {
    final classesAsync = ref.watch(teacherClassesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return classesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24.0),
        child: SkeletonListLoader(itemCount: 3),
      ),
      error: (e, _) => AppErrorState(
        errorMessage: 'Error loading classes: $e',
        onRetry: () => ref.invalidate(teacherClassesProvider),
      ),
      data: (classes) {
        if (classes.isEmpty) {
          return const AppEmptyState(
            icon: Icons.class_outlined,
            title: 'No Classes Assigned',
            description: 'You are not assigned to any classes as a teacher.',
          );
        }

        if (_selectedClassId == null && classes.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedClassId = classes.first['id'] as String);
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Results & Grades',
                  style: AppTextStyles.heading1.copyWith(
                    color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                  )),
              const SizedBox(height: 6),
              Text('Manage exam marks and publish results to students.',
                  style: AppTextStyles.bodyMedium),
              const SizedBox(height: 24),

              // Class selector
              _sectionLabel('Select Class', isDark),
              const SizedBox(height: 8),
              _classDropdown(classes, isDark),
              const SizedBox(height: 20),

              // Exam selector + actions
              if (_selectedClassId != null) ...[
                _sectionLabel('Select Exam', isDark),
                const SizedBox(height: 8),
                _examSelector(isDark),
                const SizedBox(height: 24),
              ],

              // Marks table
              if (_selectedExamId != null) _marksSection(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _classDropdown(List<Map<String, dynamic>> classes, bool isDark) {
    return _dropdownContainer(
      isDark,
      DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedClassId,
          dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
          items: classes.map((c) {
            return DropdownMenuItem<String>(
              value: c['id'] as String,
              child: Text(
                '${c['name']} – Sec ${c['section']} (Grade ${c['grade_level']})',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedClassId = val;
              _selectedExamId = null;
              _marksLoaded = false;
            });
          },
        ),
      ),
    );
  }

  Widget _examSelector(bool isDark) {
    final examsAsync = ref.watch(teacherExamsProvider(_selectedClassId!));

    return examsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
      data: (exams) {
        return Row(
          children: [
            Expanded(
              child: _dropdownContainer(
                isDark,
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedExamId,
                    hint: const Text('Choose exam...'),
                    dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                    items: exams.map((e) {
                      final published = e['is_published'] == true;
                      return DropdownMenuItem<String>(
                        value: e['id'] as String,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${e['name']} (${e['term']})',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (published)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.successGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('Published',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.successGreen,
                                        fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedExamId = val;
                        _marksLoaded = false;
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _showCreateExamDialog(isDark),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New Exam'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _marksSection(bool isDark) {
    final studentsAsync = ref.watch(classStudentsProvider(_selectedClassId!));
    final existingResultsAsync = ref.watch(examResultsProvider(_selectedExamId!));
    final draft = ref.watch(resultsDraftProvider);
    final saveState = ref.watch(resultsSaveProvider);

    return studentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: SkeletonListLoader(itemCount: 4),
      ),
      error: (e, _) => AppErrorState(
        errorMessage: 'Error loading roster: $e',
        onRetry: () => ref.invalidate(classStudentsProvider(_selectedClassId!)),
      ),
      data: (students) {
        return existingResultsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: SkeletonTableLoader(rows: 4),
          ),
          error: (e, _) => AppErrorState(
            errorMessage: 'Error loading results: $e',
            onRetry: () => ref.invalidate(examResultsProvider(_selectedExamId!)),
          ),
          data: (existing) {
            if (!_marksLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref
                    .read(resultsDraftProvider.notifier)
                    .init(existing, students, 'General');
                if (mounted) setState(() => _marksLoaded = true);
              });
            }

            if (students.isEmpty) {
              return _emptyState(icon: Icons.people_outline, message: 'No students in class.');
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('Enter Marks', isDark),
                const SizedBox(height: 16),

                // Header row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.primaryDeepNavy.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Expanded(flex: 3, child: Text('Student', style: AppTextStyles.labelLarge)),
                      const Expanded(flex: 2, child: Text('Subject', style: AppTextStyles.labelLarge)),
                      const Expanded(flex: 2, child: Text('Marks Obtained', style: AppTextStyles.labelLarge)),
                      const Expanded(flex: 2, child: Text('Total Marks', style: AppTextStyles.labelLarge)),
                      const Expanded(flex: 1, child: Text('Grade', style: AppTextStyles.labelLarge)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                ...students.map((s) {
                  final sid = s['id'] as String;
                  final name = (s['users'] as Map<String, dynamic>?)?['full_name'] ?? 'Unknown';
                  final roll = s['roll_number'] ?? '';
                  final d = draft[sid] ?? {};
                  final marksStr = d['marks_obtained'] as String? ?? '';
                  final totalStr = d['total_marks'] as String? ?? '100';
                  final marks = double.tryParse(marksStr);
                  final total = double.tryParse(totalStr) ?? 100;
                  final pct = marks != null ? (marks / total * 100) : null;
                  final grade = _computeGrade(pct);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.borderLight),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
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
                        Expanded(
                          flex: 2,
                          child: _compactField(
                            hint: 'Subject',
                            value: d['subject'] as String? ?? '',
                            onChanged: (v) => ref
                                .read(resultsDraftProvider.notifier)
                                .updateSubject(sid, v),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _compactField(
                            hint: 'e.g. 78',
                            value: marksStr,
                            onChanged: (v) => ref
                                .read(resultsDraftProvider.notifier)
                                .updateMarks(sid, v),
                            isDark: isDark,
                            isNumeric: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _compactField(
                            hint: '100',
                            value: totalStr,
                            onChanged: (v) => ref
                                .read(resultsDraftProvider.notifier)
                                .updateTotal(sid, v),
                            isDark: isDark,
                            isNumeric: true,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: _gradeChip(grade),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saveState.isLoading
                            ? null
                            : () async {
                                try {
                                  await ref
                                      .read(resultsSaveProvider.notifier)
                                      .saveResults(
                                          examId: _selectedExamId!,
                                          marksMap: draft);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Results saved!'),
                                        backgroundColor: AppColors.successGreen,
                                      ),
                                    );
                                    ref.invalidate(examResultsProvider(_selectedExamId!));
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Draft'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: saveState.isLoading
                            ? null
                            : () => _confirmPublish(isDark),
                        icon: saveState.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.publish_rounded),
                        label: Text(saveState.isLoading ? 'Publishing...' : 'Publish Results'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmPublish(bool isDark) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Publish Results',
            style: AppTextStyles.heading3.copyWith(
              color: isDark ? Colors.white : AppColors.primaryDeepNavy,
            )),
        content: const Text(
            'This will make results visible to all students in the class. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(resultsSaveProvider.notifier)
                    .publishResults(_selectedExamId!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Results published successfully!'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                  ref.invalidate(teacherExamsProvider(_selectedClassId!));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.successGreen),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
  }

  void _showCreateExamDialog(bool isDark) {
    final nameCtrl = TextEditingController();
    String term = 'Term 1';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Create New Exam',
              style: AppTextStyles.heading3.copyWith(
                color: isDark ? Colors.white : AppColors.primaryDeepNavy,
              )),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Exam Name',
                      hintText: 'e.g. Mid-Term Mathematics',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: term,
                    decoration: const InputDecoration(labelText: 'Term'),
                    items: ['Term 1', 'Term 2', 'Term 3', 'Final']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDlgState(() => term = v);
                    },
                  ),
                ],
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
                  final id = await ref.read(examCreationProvider.notifier).createExam(
                        name: nameCtrl.text.trim(),
                        term: term,
                        classId: _selectedClassId!,
                      );
                  if (mounted) {
                    Navigator.pop(context);
                    if (id != null) {
                      ref.invalidate(teacherExamsProvider(_selectedClassId!));
                      setState(() {
                        _selectedExamId = id;
                        _marksLoaded = false;
                      });
                    }
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // STUDENT VIEW — Published results with grade chips
  // ===========================================================================
  Widget _buildStudentView() {
    final resultsAsync = ref.watch(studentResultsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return resultsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24.0),
        child: SkeletonTableLoader(rows: 4),
      ),
      error: (e, _) => AppErrorState(
        errorMessage: 'Error loading results: $e',
        onRetry: () => ref.invalidate(studentResultsProvider),
      ),
      data: (results) {
        if (results.isEmpty) {
          return const AppEmptyState(
            icon: Icons.grade_outlined,
            title: 'No Results Published',
            description: 'Your teacher has not published any exam results for you yet.',
          );
        }

        // Group by exam
        final Map<String, List<Map<String, dynamic>>> byExam = {};
        for (final r in results) {
          final exam = r['exams'] as Map<String, dynamic>? ?? {};
          final key = '${exam['name']} (${exam['term']})';
          byExam.putIfAbsent(key, () => []).add(r);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Results',
                  style: AppTextStyles.heading1.copyWith(
                    color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                  )),
              const SizedBox(height: 6),
              Text('Published exam results from your teachers.',
                  style: AppTextStyles.bodyMedium),
              const SizedBox(height: 24),

              ...byExam.entries.map((entry) {
                final examName = entry.key;
                final examResults = entry.value;
                final totalMarks = examResults.fold<double>(
                    0, (p, r) => p + ((r['total_marks'] as num?)?.toDouble() ?? 0));
                final obtainedMarks = examResults.fold<double>(
                    0, (p, r) => p + ((r['marks_obtained'] as num?)?.toDouble() ?? 0));
                final overallPct =
                    totalMarks > 0 ? (obtainedMarks / totalMarks * 100) : 0.0;
                final overallGrade = _computeGrade(overallPct);

                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Exam header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryDeepNavy.withOpacity(0.9),
                              AppColors.accentSoftBlue.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    examName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${obtainedMarks.toStringAsFixed(0)} / ${totalMarks.toStringAsFixed(0)} marks',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                _gradeChipLarge(overallGrade),
                                const SizedBox(height: 4),
                                Text(
                                  '${overallPct.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Per-subject rows
                      ...examResults.map((r) {
                        final subject = r['subject'] ?? 'N/A';
                        final marks = (r['marks_obtained'] as num?)?.toDouble() ?? 0;
                        final total = (r['total_marks'] as num?)?.toDouble() ?? 100;
                        final pct = total > 0 ? (marks / total * 100) : 0.0;
                        final grade = _computeGrade(pct);

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  subject,
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color:
                                        isDark ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                '${marks.toStringAsFixed(0)} / ${total.toStringAsFixed(0)}',
                                style: AppTextStyles.bodyMedium,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${pct.toStringAsFixed(1)}%',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: _gradeColor(grade),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              _gradeChip(grade),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================
  String _computeGrade(double? pct) {
    if (pct == null) return '--';
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B';
    if (pct >= 60) return 'C';
    if (pct >= 50) return 'D';
    return 'F';
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return AppColors.successGreen;
      case 'B':
        return AppColors.accentSoftBlue;
      case 'C':
        return AppColors.warningOrange;
      case 'D':
        return Colors.orange.shade800;
      case 'F':
        return AppColors.dangerRed;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _gradeChip(String grade) {
    final color = _gradeColor(grade);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        grade,
        style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _gradeChipLarge(String grade) {
    final color = _gradeColor(grade);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Text(
        grade,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
      ),
    );
  }

  Widget _compactField({
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
    required bool isDark,
    bool isNumeric = false,
  }) {
    return TextFormField(
      initialValue: value,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: AppTextStyles.bodyMedium.copyWith(
        color: isDark ? Colors.white : AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.accentSoftBlue, width: 1.5),
        ),
        fillColor: isDark ? AppColors.darkBackground : AppColors.backgroundLight,
        filled: true,
      ),
      onChanged: onChanged,
    );
  }

  Widget _dropdownContainer(bool isDark, Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.borderLight),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: AppTextStyles.heading3.copyWith(
        color: isDark ? Colors.white : AppColors.primaryDeepNavy,
      ),
    );
  }

  }
}
