import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../shared/widgets/dashboard_shell.dart';
import '../students/students_provider.dart'; // import classesProvider
import 'teachers_provider.dart';

class TeachersPage extends ConsumerStatefulWidget {
  const TeachersPage({super.key});

  @override
  ConsumerState<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends ConsumerState<TeachersPage> {
  String _searchQuery = '';

  String _formatDate(String? isoString) {
    if (isoString == null) return 'N/A';
    final date = DateTime.tryParse(isoString);
    if (date == null) return 'N/A';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(teachersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DashboardShell(
      title: 'Instructors Registry',
      child: RefreshIndicator(
        onRefresh: () async {
          ref.read(teachersProvider.notifier).fetchTeachers();
          ref.invalidate(classesProvider);
        },
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'Search instructors by name, code, or subject...',
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddTeacherDialog(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Add Instructor'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Teacher Cards Grid
              Expanded(
                child: teachersAsync.when(
                  data: (teachers) {
                    // Filter teachers locally
                    final filteredTeachers = teachers.where((teacher) {
                      final user = teacher['users'] ?? {};
                      final name = (user['full_name'] ?? '').toString().toLowerCase();
                      final code = (teacher['teacher_code'] ?? '').toString().toLowerCase();
                      final subject = (teacher['subject'] ?? '').toString().toLowerCase();
                      
                      return name.contains(_searchQuery.toLowerCase()) ||
                          code.contains(_searchQuery.toLowerCase()) ||
                          subject.contains(_searchQuery.toLowerCase());
                    }).toList();

                    if (filteredTeachers.isEmpty) {
                      return _buildEmptyState();
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth >= 1200
                            ? 3
                            : (constraints.maxWidth >= 800 ? 2 : 1);

                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent: 260,
                          ),
                          itemCount: filteredTeachers.length,
                          itemBuilder: (context, index) {
                            final teacher = filteredTeachers[index];
                            return _buildTeacherCard(context, teacher);
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading instructors: $err')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherCard(BuildContext context, Map<String, dynamic> teacher) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = teacher['users'] ?? {};
    final classTeachers = teacher['class_teachers'] as List? ?? [];
    
    final classNames = classTeachers.map((ct) {
      final cls = ct['classes'] ?? {};
      final name = cls['name'] ?? '';
      final sec = cls['section'] ?? '';
      return sec.isNotEmpty ? '$name-$sec' : name;
    }).where((n) => n.isNotEmpty).join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.accentSoftBlue.withOpacity(0.1),
                  child: Text(
                    (user['full_name'] ?? 'T')[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.accentSoftBlue,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['full_name'] ?? '',
                        style: AppTextStyles.heading3.copyWith(
                          color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user['email'] ?? '',
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    teacher['teacher_code'] ?? '',
                    style: const TextStyle(
                      color: AppColors.successGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('Subject: ${teacher['subject'] ?? 'N/A'}', style: AppTextStyles.labelLarge),
            const SizedBox(height: 4),
            Text('Joined: ${_formatDate(teacher['joining_date'])}', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 8),
            Text(
              'Assigned Classes: ${classNames.isEmpty ? "None" : classNames}',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: classNames.isEmpty ? AppColors.dangerRed : (isDark ? Colors.white70 : AppColors.textPrimary),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Assign Classes',
                  icon: const Icon(Icons.app_registration_rounded, color: AppColors.warningOrange),
                  onPressed: () => _showAssignClassesDialog(context, teacher),
                ),
                IconButton(
                  tooltip: 'Edit Profile',
                  icon: const Icon(Icons.edit_rounded, color: AppColors.accentSoftBlue),
                  onPressed: () => _showEditTeacherDialog(context, teacher),
                ),
                IconButton(
                  tooltip: 'Delete Profile',
                  icon: const Icon(Icons.delete_rounded, color: AppColors.dangerRed),
                  onPressed: () => _confirmDeleteTeacher(context, teacher),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: isDark ? AppColors.darkBorder : AppColors.borderLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No instructors found.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.textMuted : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTeacherDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final codeCtrl = TextEditingController();

    DateTime selectedJoiningDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Instructor'),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Full Name *'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email *'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: passCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password *'),
                          validator: (val) => val == null || val.length < 6 ? 'Min 6 characters' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: subjectCtrl,
                          decoration: const InputDecoration(labelText: 'Primary Subject *'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: codeCtrl,
                          decoration: const InputDecoration(labelText: 'Instructor Code * (e.g. TCH-04)'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedJoiningDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => selectedJoiningDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today_rounded),
                          label: Text('Joining Date: ${_formatDate(selectedJoiningDate.toIso8601String())}'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      try {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(child: CircularProgressIndicator()),
                        );

                        await ref.read(teachersProvider.notifier).createTeacher(
                              fullName: nameCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              password: passCtrl.text,
                              subject: subjectCtrl.text.trim(),
                              joiningDate: _formatDate(selectedJoiningDate.toIso8601String()),
                              teacherCode: codeCtrl.text.trim(),
                            );

                        if (context.mounted) {
                          Navigator.pop(context);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Instructor added successfully')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Register'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditTeacherDialog(BuildContext context, Map<String, dynamic> teacher) {
    final formKey = GlobalKey<FormState>();
    final user = teacher['users'] ?? {};

    final nameCtrl = TextEditingController(text: user['full_name'] ?? '');
    final subjectCtrl = TextEditingController(text: teacher['subject'] ?? '');
    final codeCtrl = TextEditingController(text: teacher['teacher_code'] ?? '');

    DateTime selectedJoiningDate = DateTime.tryParse(teacher['joining_date'] ?? '') ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit Instructor Profile'),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Full Name *'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: subjectCtrl,
                          decoration: const InputDecoration(labelText: 'Subject *'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: codeCtrl,
                          decoration: const InputDecoration(labelText: 'Instructor Code *'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedJoiningDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => selectedJoiningDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today_rounded),
                          label: Text('Joining Date: ${_formatDate(selectedJoiningDate.toIso8601String())}'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      try {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(child: CircularProgressIndicator()),
                        );

                        await ref.read(teachersProvider.notifier).updateTeacher(
                              teacherId: teacher['id'],
                              userId: user['id'],
                              fullName: nameCtrl.text.trim(),
                              subject: subjectCtrl.text.trim(),
                              joiningDate: _formatDate(selectedJoiningDate.toIso8601String()),
                              teacherCode: codeCtrl.text.trim(),
                            );

                        if (context.mounted) {
                          Navigator.pop(context);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Instructor profile saved')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context);
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

  void _showAssignClassesDialog(BuildContext context, Map<String, dynamic> teacher) {
    final classTeachers = teacher['class_teachers'] as List? ?? [];
    final initialClassIds = classTeachers.map((ct) => ct['classes']['id'] as String).toList();
    List<String> selectedClassIds = List.from(initialClassIds);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final classesAsync = ref.watch(classesProvider);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Assign Classes'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: classesAsync.when(
                  data: (classes) {
                    if (classes.isEmpty) {
                      return const Center(child: Text('No active classes exist. Set up classes first.'));
                    }

                    return ListView.builder(
                      itemCount: classes.length,
                      itemBuilder: (context, index) {
                        final cls = classes[index];
                        final id = cls['id'] as String;
                        final name = cls['name'] ?? '';
                        final sec = cls['section'] ?? '';
                        final label = sec.isNotEmpty ? '$name-$sec' : name;
                        final isSelected = selectedClassIds.contains(id);

                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(label),
                          subtitle: Text('Grade: ${cls['grade_level'] ?? ''}'),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                selectedClassIds.add(id);
                              } else {
                                selectedClassIds.remove(id);
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading classes: $err')),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );

                      await ref.read(teachersProvider.notifier).assignClasses(
                            teacherId: teacher['id'],
                            classIds: selectedClassIds,
                          );

                      if (context.mounted) {
                        Navigator.pop(context);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Class assignments updated')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteTeacher(BuildContext context, Map<String, dynamic> teacher) {
    final user = teacher['users'] ?? {};
    final fullName = user['full_name'] ?? 'this instructor';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Soft Delete Instructor'),
          content: Text('Are you sure you want to soft delete $fullName? This will mark their profile as inactive.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
              onPressed: () async {
                try {
                  await ref.read(teachersProvider.notifier).deleteTeacher(teacher['id']);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Soft deleted $fullName')),
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
