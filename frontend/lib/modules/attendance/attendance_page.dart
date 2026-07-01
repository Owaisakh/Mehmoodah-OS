import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../shared/widgets/dashboard_shell.dart';
import 'attendance_provider.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  String? _selectedClassId;
  DateTime _selectedDate = DateTime.now();
  bool _attendanceLoaded = false;

  // For student calendar view
  int _calendarYear = DateTime.now().year;
  int _calendarMonth = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(userRoleProvider);
    final role = roleAsync.value ?? 'student';

    return DashboardShell(
      title: 'Attendance',
      child: role == 'teacher'
          ? _buildTeacherView()
          : _buildStudentView(),
    );
  }

  // ===========================================================================
  // TEACHER VIEW — Mark attendance for a class
  // ===========================================================================
  Widget _buildTeacherView() {
    final classesAsync = ref.watch(teacherClassesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return classesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (classes) {
        if (classes.isEmpty) {
          return _buildEmptyState(
            icon: Icons.class_outlined,
            message: 'No classes assigned to you.',
            subtext: 'Contact your administrator to assign classes.',
          );
        }

        // Auto-select first class
        if (_selectedClassId == null && classes.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedClassId = classes.first['id'] as String;
              });
            }
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Mark Attendance',
                style: AppTextStyles.heading1.copyWith(
                  color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Select a class and date, then set each student\'s status.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 24),

              // Class + Date Selectors Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  return isWide
                      ? Row(
                          children: [
                            Expanded(child: _buildClassDropdown(classes, isDark)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildDatePicker(isDark)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildClassDropdown(classes, isDark),
                            const SizedBox(height: 16),
                            _buildDatePicker(isDark),
                          ],
                        );
                },
              ),

              const SizedBox(height: 24),

              // Student Roster
              if (_selectedClassId != null) _buildStudentRoster(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClassDropdown(List<Map<String, dynamic>> classes, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderLight),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedClassId,
          hint: const Text('Select Class'),
          dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
          items: classes.map((c) {
            return DropdownMenuItem<String>(
              value: c['id'] as String,
              child: Text(
                '${c['name']} – Section ${c['section']} (Grade ${c['grade_level']})',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedClassId = val;
              _attendanceLoaded = false;
            });
          },
        ),
      ),
    );
  }

  Widget _buildDatePicker(bool isDark) {
    final formatted =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            _selectedDate = picked;
            _attendanceLoaded = false;
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderLight),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.accentSoftBlue),
            const SizedBox(width: 12),
            Text(
              formatted,
              style: AppTextStyles.bodyLarge.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_drop_down_rounded,
                color: isDark ? AppColors.textMuted : AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentRoster(bool isDark) {
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    final studentsAsync = ref.watch(classStudentsProvider(_selectedClassId!));
    final existingAsync = ref.watch(
        existingAttendanceProvider((classId: _selectedClassId!, date: dateStr)));
    final draft = ref.watch(attendanceDraftProvider);
    final submitState = ref.watch(attendanceSubmitProvider);

    // Load existing attendance into draft when data arrives
    existingAsync.whenData((existing) {
      if (!_attendanceLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(attendanceDraftProvider.notifier).init(existing);
          if (mounted) setState(() => _attendanceLoaded = true);
        });
      }
    });

    return studentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading students: $e')),
      data: (students) {
        if (students.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_outline,
            message: 'No students enrolled in this class.',
          );
        }

        final studentIds = students.map((s) => s['id'] as String).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bulk actions bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Text(
                    'Mark All As:',
                    style: AppTextStyles.labelLarge.copyWith(
                        color: isDark ? Colors.white : AppColors.textPrimary),
                  ),
                  const SizedBox(width: 16),
                  _bulkBtn('Present', AppColors.successGreen, studentIds),
                  const SizedBox(width: 8),
                  _bulkBtn('Absent', AppColors.dangerRed, studentIds),
                  const SizedBox(width: 8),
                  _bulkBtn('Late', AppColors.warningOrange, studentIds),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Student list
            ...students.map((s) {
              final sid = s['id'] as String;
              final name = (s['users'] as Map<String, dynamic>?)?['full_name'] ?? 'Unknown';
              final roll = s['roll_number'] ?? '';
              final status = draft[sid] ?? 'present';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderLight),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.accentSoftBlue.withOpacity(0.12),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: AppColors.accentSoftBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTextStyles.labelLarge.copyWith(
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Roll: $roll',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      // Status chips
                      Wrap(
                        spacing: 8,
                        children: ['present', 'absent', 'late', 'leave'].map((st) {
                          final isSelected = status == st;
                          return _statusChip(
                            label: st[0].toUpperCase() + st.substring(1),
                            status: st,
                            isSelected: isSelected,
                            onTap: () {
                              ref.read(attendanceDraftProvider.notifier).setStatus(sid, st);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: submitState.isLoading
                    ? null
                    : () async {
                        try {
                          await ref.read(attendanceSubmitProvider.notifier).submit(
                                classId: _selectedClassId!,
                                date: dateStr,
                                attendanceMap: draft,
                              );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Attendance saved successfully!'),
                                backgroundColor: AppColors.successGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                icon: submitState.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(submitState.isLoading ? 'Saving...' : 'Save Attendance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentSoftBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _bulkBtn(String label, Color color, List<String> studentIds) {
    return ElevatedButton(
      onPressed: () {
        ref.read(attendanceDraftProvider.notifier).setAll(studentIds, label.toLowerCase());
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.12),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _statusChip({
    required String label,
    required String status,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    Color color;
    switch (status) {
      case 'present':
        color = AppColors.successGreen;
        break;
      case 'absent':
        color = AppColors.dangerRed;
        break;
      case 'late':
        color = AppColors.warningOrange;
        break;
      default:
        color = AppColors.textSecondary;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STUDENT VIEW — Monthly attendance calendar
  // ===========================================================================
  Widget _buildStudentView() {
    final classesAsync = ref.watch(studentClassesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return classesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (classes) {
        if (classes.isEmpty) {
          return _buildEmptyState(
            icon: Icons.class_outlined,
            message: 'You are not enrolled in any class.',
          );
        }

        final cls = classes.first;
        if (_selectedClassId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedClassId = cls['id'] as String);
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Attendance',
                style: AppTextStyles.heading1.copyWith(
                  color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Class: ${cls['name']} – Section ${cls['section']}',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 24),

              // Month navigator
              _buildMonthNavigator(isDark),
              const SizedBox(height: 20),

              if (_selectedClassId != null)
                _buildStudentCalendar(_selectedClassId!, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthNavigator(bool isDark) {
    final monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                if (_calendarMonth == 1) {
                  _calendarMonth = 12;
                  _calendarYear--;
                } else {
                  _calendarMonth--;
                }
              });
            },
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(
            '${monthNames[_calendarMonth]} $_calendarYear',
            style: AppTextStyles.heading3.copyWith(
              color: isDark ? Colors.white : AppColors.primaryDeepNavy,
            ),
          ),
          IconButton(
            onPressed: _calendarMonth == DateTime.now().month &&
                    _calendarYear == DateTime.now().year
                ? null
                : () {
                    setState(() {
                      if (_calendarMonth == 12) {
                        _calendarMonth = 1;
                        _calendarYear++;
                      } else {
                        _calendarMonth++;
                      }
                    });
                  },
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCalendar(String classId, bool isDark) {
    final attendanceAsync = ref.watch(studentMonthlyAttendanceProvider(
      (classId: classId, year: _calendarYear, month: _calendarMonth),
    ));

    return attendanceAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (records) {
        final statusMap = <int, String>{};
        for (final r in records) {
          final date = DateTime.tryParse(r['date'] as String);
          if (date != null) statusMap[date.day] = r['status'] as String;
        }

        // Stats
        final present = records.where((r) => r['status'] == 'present').length;
        final absent = records.where((r) => r['status'] == 'absent').length;
        final late = records.where((r) => r['status'] == 'late').length;
        final leave = records.where((r) => r['status'] == 'leave').length;
        final total = present + absent + late + leave;
        final percentage = total > 0
            ? ((present + late) / total * 100).toStringAsFixed(1)
            : '--';

        return Column(
          children: [
            // Stats summary row
            Row(
              children: [
                _attendanceStat('Present', present, AppColors.successGreen, isDark),
                const SizedBox(width: 12),
                _attendanceStat('Absent', absent, AppColors.dangerRed, isDark),
                const SizedBox(width: 12),
                _attendanceStat('Late', late, AppColors.warningOrange, isDark),
                const SizedBox(width: 12),
                _attendanceStat('Leave', leave, AppColors.textSecondary, isDark),
              ],
            ),
            const SizedBox(height: 16),

            // Attendance percentage card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentSoftBlue.withOpacity(0.8),
                    AppColors.primaryDeepNavy.withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 32),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Attendance Rate',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        '$percentage%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Calendar grid
            _buildCalendarGrid(statusMap, isDark),
          ],
        );
      },
    );
  }

  Widget _attendanceStat(String label, int count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderLight),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(Map<int, String> statusMap, bool isDark) {
    final firstDay = DateTime(_calendarYear, _calendarMonth, 1);
    final daysInMonth = DateTime(_calendarYear, _calendarMonth + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=Sun

    final days = <Widget>[];

    // Day headers
    for (final d in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']) {
      days.add(Center(
        child: Text(
          d,
          style: AppTextStyles.caption.copyWith(
            color: isDark ? AppColors.textMuted : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ));
    }

    // Empty cells before first day
    for (int i = 0; i < startWeekday; i++) {
      days.add(const SizedBox());
    }

    // Day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final status = statusMap[day];
      Color? bgColor;
      Color textColor = isDark ? Colors.white : AppColors.textPrimary;

      if (status == 'present') {
        bgColor = AppColors.successGreen;
        textColor = Colors.white;
      } else if (status == 'absent') {
        bgColor = AppColors.dangerRed;
        textColor = Colors.white;
      } else if (status == 'late') {
        bgColor = AppColors.warningOrange;
        textColor = Colors.white;
      } else if (status == 'leave') {
        bgColor = AppColors.textSecondary.withOpacity(0.5);
        textColor = Colors.white;
      }

      days.add(Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: bgColor ?? (isDark ? AppColors.darkSurface : AppColors.backgroundLight),
          borderRadius: BorderRadius.circular(8),
          border: bgColor == null
              ? Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderLight)
              : null,
        ),
        child: Center(
          child: Text(
            day.toString(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderLight),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1,
            children: days,
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _legendItem('Present', AppColors.successGreen),
              _legendItem('Absent', AppColors.dangerRed),
              _legendItem('Late', AppColors.warningOrange),
              _legendItem('Leave', AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? subtext,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: isDark ? AppColors.darkBorder : AppColors.borderLight),
            const SizedBox(height: 20),
            Text(
              message,
              style: AppTextStyles.heading3.copyWith(
                color: isDark ? AppColors.textMuted : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtext != null) ...[
              const SizedBox(height: 8),
              Text(subtext, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
