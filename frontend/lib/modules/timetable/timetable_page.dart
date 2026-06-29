import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../shared/widgets/dashboard_shell.dart';
import 'timetable_provider.dart';

class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key});

  @override
  ConsumerState<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends ConsumerState<TimetablePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Timetable scheduling page state
  String? _selectedClassId;
  String _selectedDay = 'Monday';

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

  // Time conversion helpers
  int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    return hours * 60 + minutes;
  }

  int _todToMinutes(TimeOfDay tod) {
    return tod.hour * 60 + tod.minute;
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  String _formatTimeDisplay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 'N/A';
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final displayMinute = minute.toString().padLeft(2, '0');
      return '$displayHour:$displayMinute $ampm';
    } catch (_) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DashboardShell(
      title: 'Timetable & Classes',
      child: Column(
        children: [
          // Sub-navigation Tabs
          Container(
            color: isDark ? AppColors.darkSurface : Colors.white,
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.accentSoftBlue,
              unselectedLabelColor: isDark ? AppColors.textMuted : AppColors.textSecondary,
              indicatorColor: AppColors.accentSoftBlue,
              tabs: const [
                Tab(text: 'Classes Management'),
                Tab(text: 'Weekly Timetable'),
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildClassesTab(),
                _buildTimetableTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: Classes Management
  // =========================================================================
  Widget _buildClassesTab() {
    final classesAsync = ref.watch(classManagementProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(classManagementProvider.notifier).fetchClasses();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Academic Classes',
                  style: AppTextStyles.heading2.copyWith(
                    color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddClassDialog(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Class'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            classesAsync.when(
              data: (classes) {
                if (classes.isEmpty) {
                  return _buildEmptyState('No active classes registered yet.');
                }

                return Card(
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.resolveWith(
                        (states) => isDark
                            ? AppColors.darkBorder.withOpacity(0.5)
                            : AppColors.backgroundLight,
                      ),
                      columns: const [
                        DataColumn(label: Text('Class Name')),
                        DataColumn(label: Text('Grade Level')),
                        DataColumn(label: Text('Section')),
                        DataColumn(label: Text('Class Teacher')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: classes.map((cls) {
                        final teacher = cls['users'] != null
                            ? cls['users']['full_name'] as String
                            : 'Unassigned';

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                cls['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataCell(Text(cls['grade_level'] ?? '')),
                            DataCell(Text(cls['section'] ?? '-')),
                            DataCell(
                              Text(
                                teacher,
                                style: TextStyle(
                                  color: teacher == 'Unassigned' ? AppColors.dangerRed : null,
                                  fontWeight: teacher == 'Unassigned' ? FontWeight.w500 : null,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: AppColors.accentSoftBlue),
                                    onPressed: () => _showEditClassDialog(context, cls),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_rounded, color: AppColors.dangerRed),
                                    onPressed: () => _confirmDeleteClass(context, cls),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading classes: $err')),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 2: Timetable Configuration
  // =========================================================================
  Widget _buildTimetableTab() {
    final classesAsync = ref.watch(classManagementProvider);
    final timetableAsync = ref.watch(timetableProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return classesAsync.when(
      data: (classes) {
        if (classes.isEmpty) {
          return const Center(child: Text('Create a class first before configuring timetables.'));
        }

        // Auto-select first class if not set
        if (_selectedClassId == null || !classes.any((c) => c['id'] == _selectedClassId)) {
          _selectedClassId = classes[0]['id'];
        }

        final selectedClass = classes.firstWhere((c) => c['id'] == _selectedClassId);
        final className = selectedClass['name'] ?? '';
        final classSec = selectedClass['section'] ?? '';
        final classLabel = classSec.isNotEmpty ? '$className-$classSec' : className;

        return Row(
          children: [
            // Left sidebar: Class Selector & Days Tabs
            Container(
              width: 250,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Class Picker
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      value: _selectedClassId,
                      decoration: const InputDecoration(labelText: 'Select Class'),
                      items: classes.map((cls) {
                        final name = cls['name'] ?? '';
                        final sec = cls['section'] ?? '';
                        final label = sec.isNotEmpty ? '$name-$sec' : name;
                        return DropdownMenuItem(value: cls['id'] as String, child: Text(label));
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedClassId = val;
                        });
                      },
                    ),
                  ),
                  const Divider(),
                  
                  // Days list selector
                  Expanded(
                    child: ListView(
                      children: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'].map((day) {
                        final isSelected = _selectedDay == day;
                        return ListTile(
                          selected: isSelected,
                          selectedColor: AppColors.accentSoftBlue,
                          selectedTileColor: isDark ? AppColors.darkBorder : AppColors.accentSoftBlue.withOpacity(0.05),
                          title: Text(
                            day,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                          onTap: () {
                            setState(() {
                              _selectedDay = day;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            
            // Right contents: Slots display timeline
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weekly Schedule for $classLabel',
                              style: AppTextStyles.heading2.copyWith(
                                color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Displaying slots for $_selectedDay',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showAddSlotDialog(context),
                          icon: const Icon(Icons.add_alarm_rounded),
                          label: const Text('Add Slot'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    Expanded(
                      child: timetableAsync.when(
                        data: (slots) {
                          // Filter slots for selected class and day
                          final daySlots = slots.where((slot) {
                            return slot['class_id'] == _selectedClassId &&
                                slot['day'] == _selectedDay;
                          }).toList();

                          if (daySlots.isEmpty) {
                            return _buildEmptyState('No lectures scheduled for $_selectedDay.');
                          }

                          return ListView.separated(
                            itemCount: daySlots.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final slot = daySlots[index];
                              final teacherName = slot['teachers'] != null && slot['teachers']['users'] != null
                                  ? slot['teachers']['users']['full_name'] as String
                                  : 'No Instructor Assigned';
                              final teacherCode = slot['teachers'] != null
                                  ? slot['teachers']['teacher_code'] as String
                                  : '';
                              
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  child: Row(
                                    children: [
                                      // Time Display
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentSoftBlue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              _formatTimeDisplay(slot['start_time']),
                                              style: const TextStyle(
                                                color: AppColors.accentSoftBlue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.accentSoftBlue),
                                            Text(
                                              _formatTimeDisplay(slot['end_time']),
                                              style: const TextStyle(
                                                color: AppColors.accentSoftBlue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      
                                      // Lecture / Class details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              slot['subject'] ?? '',
                                              style: AppTextStyles.heading3.copyWith(
                                                color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textSecondary),
                                                const SizedBox(width: 6),
                                                Text(
                                                  teacherCode.isNotEmpty ? '$teacherName ($teacherCode)' : teacherName,
                                                  style: AppTextStyles.bodyMedium,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.meeting_room_outlined, size: 16, color: AppColors.textSecondary),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Room: ${slot['room'] ?? 'N/A'}',
                                                  style: AppTextStyles.bodySmall,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Action buttons
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_rounded, color: AppColors.accentSoftBlue),
                                            onPressed: () => _showEditSlotDialog(context, slot),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_forever_rounded, color: AppColors.dangerRed),
                                            onPressed: () => _confirmDeleteSlot(context, slot),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Error loading timetable: $err')),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildEmptyState(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 64,
            color: isDark ? AppColors.darkBorder : AppColors.borderLight,
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.textMuted : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // DIALOGS: Class Management
  // =========================================================================
  void _showAddClassDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final sectionCtrl = TextEditingController();
    final gradeCtrl = TextEditingController();
    String? selectedTeacherId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final teachersAsync = ref.watch(allTeachersProvider);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Create New Class'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Class Name * (e.g. Class 8-B)'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: gradeCtrl,
                            decoration: const InputDecoration(labelText: 'Grade Level * (e.g. 8)'),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: sectionCtrl,
                            decoration: const InputDecoration(labelText: 'Section (e.g. B)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    teachersAsync.when(
                      data: (teachers) => DropdownButtonFormField<String?>(
                        value: selectedTeacherId,
                        decoration: const InputDecoration(labelText: 'Class Teacher'),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                          ...teachers.map((t) {
                            final name = t['users']['full_name'] ?? '';
                            final code = t['teacher_code'] ?? '';
                            return DropdownMenuItem(
                              value: t['users']['id'] as String, // user_id referenced in classes
                              child: Text('$name ($code)'),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            selectedTeacherId = val;
                          });
                        },
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const Text('Error loading instructors'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      try {
                        await ref.read(classManagementProvider.notifier).createClass(
                              name: nameCtrl.text.trim(),
                              section: sectionCtrl.text.trim(),
                              gradeLevel: gradeCtrl.text.trim(),
                              teacherId: selectedTeacherId,
                            );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Class created successfully')),
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
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditClassDialog(BuildContext context, Map<String, dynamic> cls) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: cls['name'] ?? '');
    final sectionCtrl = TextEditingController(text: cls['section'] ?? '');
    final gradeCtrl = TextEditingController(text: cls['grade_level'] ?? '');
    String? selectedTeacherId = cls['teacher_id'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final teachersAsync = ref.watch(allTeachersProvider);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit Class Settings'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Class Name *'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: gradeCtrl,
                            decoration: const InputDecoration(labelText: 'Grade Level *'),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: sectionCtrl,
                            decoration: const InputDecoration(labelText: 'Section'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    teachersAsync.when(
                      data: (teachers) => DropdownButtonFormField<String?>(
                        value: selectedTeacherId,
                        decoration: const InputDecoration(labelText: 'Class Teacher'),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                          ...teachers.map((t) {
                            final name = t['users']['full_name'] ?? '';
                            final code = t['teacher_code'] ?? '';
                            return DropdownMenuItem(
                              value: t['users']['id'] as String,
                              child: Text('$name ($code)'),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            selectedTeacherId = val;
                          });
                        },
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const Text('Error loading instructors'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      try {
                        await ref.read(classManagementProvider.notifier).updateClass(
                              classId: cls['id'],
                              name: nameCtrl.text.trim(),
                              section: sectionCtrl.text.trim(),
                              gradeLevel: gradeCtrl.text.trim(),
                              teacherId: selectedTeacherId,
                            );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Class settings updated')),
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
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteClass(BuildContext context, Map<String, dynamic> cls) {
    final name = cls['name'] ?? 'this class';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Soft Delete Class'),
          content: Text('Are you sure you want to soft delete $name? This will remove it from all active class filters.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
              onPressed: () async {
                try {
                  await ref.read(classManagementProvider.notifier).deleteClass(cls['id']);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Soft deleted $name')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // DIALOGS: Timetable Scheduling
  // =========================================================================
  void _showAddSlotDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final subjectCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    
    String day = _selectedDay;
    String? selectedTeacherId;
    
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 9, minute: 0);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final teachersAsync = ref.watch(allTeachersProvider);
            final timetableAsync = ref.watch(timetableProvider);

            // Dynamic real-time conflict checking
            String? warningMessage;
            final existingSlots = timetableAsync.value ?? [];
            final newStartMin = _todToMinutes(startTime);
            final newEndMin = _todToMinutes(endTime);

            if (newEndMin <= newStartMin) {
              warningMessage = '⚠️ End time must be after start time.';
            } else {
              for (final slot in existingSlots) {
                if (slot['day'] == day) {
                  final slotStartMin = _timeToMinutes(slot['start_time'] ?? '');
                  final slotEndMin = _timeToMinutes(slot['end_time'] ?? '');
                  final overlap = newStartMin < slotEndMin && slotStartMin < newEndMin;

                  if (overlap) {
                    if (slot['class_id'] == _selectedClassId) {
                      warningMessage = '⚠️ Class conflict: This class already has a lecture scheduled from ${_formatTimeDisplay(slot['start_time'])} to ${_formatTimeDisplay(slot['end_time'])} (${slot['subject']}).';
                      break;
                    }
                    if (selectedTeacherId != null && slot['teachers'] != null && slot['teachers']['id'] == selectedTeacherId) {
                      warningMessage = '⚠️ Instructor conflict: This instructor is already booked for class ${slot['classes']?['name'] ?? ''} at this time.';
                      break;
                    }
                  }
                }
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Schedule Lecture Slot'),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: day,
                          decoration: const InputDecoration(labelText: 'Day of Week'),
                          items: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
                              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                day = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: subjectCtrl,
                          decoration: const InputDecoration(labelText: 'Subject Name * (e.g. English, Math)'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        teachersAsync.when(
                          data: (teachers) => DropdownButtonFormField<String?>(
                            value: selectedTeacherId,
                            decoration: const InputDecoration(labelText: 'Assign Instructor *'),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                              ...teachers.map((t) {
                                final name = t['users']['full_name'] ?? '';
                                final code = t['teacher_code'] ?? '';
                                return DropdownMenuItem(
                                  value: t['id'] as String, // Use teacher primary key ID
                                  child: Text('$name ($code)'),
                                );
                              }),
                            ],
                            validator: (val) => val == null ? 'Required' : null,
                            onChanged: (val) {
                              setState(() {
                                selectedTeacherId = val;
                              });
                            },
                          ),
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (_, __) => const Text('Error loading instructors'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: startTime,
                                  );
                                  if (picked != null) {
                                    setState(() => startTime = picked);
                                  }
                                },
                                icon: const Icon(Icons.access_time_rounded),
                                label: Text('Start: ${startTime.format(context)}'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: endTime,
                                  );
                                  if (picked != null) {
                                    setState(() => endTime = picked);
                                  }
                                },
                                icon: const Icon(Icons.access_time_filled_rounded),
                                label: Text('End: ${endTime.format(context)}'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: roomCtrl,
                          decoration: const InputDecoration(labelText: 'Room Number (e.g. Lab-A, Room 201)'),
                        ),
                        if (warningMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.dangerRed.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.dangerRed.withOpacity(0.3)),
                            ),
                            child: Text(
                              warningMessage,
                              style: const TextStyle(color: AppColors.dangerRed, fontSize: 12),
                            ),
                          )
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: warningMessage != null
                      ? null
                      : () async {
                          if (formKey.currentState?.validate() ?? false) {
                            try {
                              await ref.read(timetableProvider.notifier).addSlot(
                                    classId: _selectedClassId!,
                                    teacherId: selectedTeacherId,
                                    subject: subjectCtrl.text.trim(),
                                    day: day,
                                    startTime: _formatTimeOfDay(startTime),
                                    endTime: _formatTimeOfDay(endTime),
                                    room: roomCtrl.text.trim(),
                                  );
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Timetable slot scheduled')),
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
                  child: const Text('Add Slot'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditSlotDialog(BuildContext context, Map<String, dynamic> slot) {
    final formKey = GlobalKey<FormState>();
    final subjectCtrl = TextEditingController(text: slot['subject'] ?? '');
    final roomCtrl = TextEditingController(text: slot['room'] ?? '');
    
    String day = slot['day'] ?? _selectedDay;
    String? selectedTeacherId = slot['teacher_id'];
    
    final startStrParts = (slot['start_time'] as String).split(':');
    final endStrParts = (slot['end_time'] as String).split(':');
    
    TimeOfDay startTime = TimeOfDay(hour: int.parse(startStrParts[0]), minute: int.parse(startStrParts[1]));
    TimeOfDay endTime = TimeOfDay(hour: int.parse(endStrParts[0]), minute: int.parse(endStrParts[1]));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final teachersAsync = ref.watch(allTeachersProvider);
            final timetableAsync = ref.watch(timetableProvider);

            String? warningMessage;
            final existingSlots = timetableAsync.value ?? [];
            final newStartMin = _todToMinutes(startTime);
            final newEndMin = _todToMinutes(endTime);

            if (newEndMin <= newStartMin) {
              warningMessage = '⚠️ End time must be after start time.';
            } else {
              for (final es in existingSlots) {
                // Ignore the current slot itself during validation
                if (es['id'] == slot['id']) continue;

                if (es['day'] == day) {
                  final slotStartMin = _timeToMinutes(es['start_time'] ?? '');
                  final slotEndMin = _timeToMinutes(es['end_time'] ?? '');
                  final overlap = newStartMin < slotEndMin && slotStartMin < newEndMin;

                  if (overlap) {
                    if (es['class_id'] == _selectedClassId) {
                      warningMessage = '⚠️ Class conflict: This class already has a lecture scheduled from ${_formatTimeDisplay(es['start_time'])} to ${_formatTimeDisplay(es['end_time'])} (${es['subject']}).';
                      break;
                    }
                    if (selectedTeacherId != null && es['teachers'] != null && es['teachers']['id'] == selectedTeacherId) {
                      warningMessage = '⚠️ Instructor conflict: This instructor is already booked for class ${es['classes']?['name'] ?? ''} at this time.';
                      break;
                    }
                  }
                }
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit Lecture Slot'),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: day,
                          decoration: const InputDecoration(labelText: 'Day of Week'),
                          items: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
                              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                day = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: subjectCtrl,
                          decoration: const InputDecoration(labelText: 'Subject Name *'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        teachersAsync.when(
                          data: (teachers) => DropdownButtonFormField<String?>(
                            value: selectedTeacherId,
                            decoration: const InputDecoration(labelText: 'Instructor *'),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                              ...teachers.map((t) {
                                final name = t['users']['full_name'] ?? '';
                                final code = t['teacher_code'] ?? '';
                                return DropdownMenuItem(
                                  value: t['id'] as String,
                                  child: Text('$name ($code)'),
                                );
                              }),
                            ],
                            validator: (val) => val == null ? 'Required' : null,
                            onChanged: (val) {
                              setState(() {
                                selectedTeacherId = val;
                              });
                            },
                          ),
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (_, __) => const Text('Error loading instructors'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: startTime,
                                  );
                                  if (picked != null) {
                                    setState(() => startTime = picked);
                                  }
                                },
                                icon: const Icon(Icons.access_time_rounded),
                                label: Text('Start: ${startTime.format(context)}'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: endTime,
                                  );
                                  if (picked != null) {
                                    setState(() => endTime = picked);
                                  }
                                },
                                icon: const Icon(Icons.access_time_filled_rounded),
                                label: Text('End: ${endTime.format(context)}'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: roomCtrl,
                          decoration: const InputDecoration(labelText: 'Room Number'),
                        ),
                        if (warningMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.dangerRed.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.dangerRed.withOpacity(0.3)),
                            ),
                            child: Text(
                              warningMessage,
                              style: const TextStyle(color: AppColors.dangerRed, fontSize: 12),
                            ),
                          )
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: warningMessage != null
                      ? null
                      : () async {
                          if (formKey.currentState?.validate() ?? false) {
                            try {
                              await ref.read(timetableProvider.notifier).updateSlot(
                                    slotId: slot['id'],
                                    classId: _selectedClassId!,
                                    teacherId: selectedTeacherId,
                                    subject: subjectCtrl.text.trim(),
                                    day: day,
                                    startTime: _formatTimeOfDay(startTime),
                                    endTime: _formatTimeOfDay(endTime),
                                    room: roomCtrl.text.trim(),
                                  );
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Timetable slot saved')),
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
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteSlot(BuildContext context, Map<String, dynamic> slot) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Lecture Slot'),
          content: Text('Are you sure you want to remove the lecture ${slot['subject'] ?? ''} scheduled at ${_formatTimeDisplay(slot['start_time'])}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
              onPressed: () async {
                try {
                  await ref.read(timetableProvider.notifier).deleteSlot(slot['id']);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lecture slot deleted')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
