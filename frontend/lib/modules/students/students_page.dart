import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../shared/widgets/dashboard_shell.dart';
import 'students_provider.dart';

class StudentsPage extends ConsumerStatefulWidget {
  const StudentsPage({super.key});

  @override
  ConsumerState<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends ConsumerState<StudentsPage> {
  String _searchQuery = '';
  String? _selectedClassFilter;

  // Helpers to format dates
  String _formatDate(String? isoString) {
    if (isoString == null) return 'N/A';
    final date = DateTime.tryParse(isoString);
    if (date == null) return 'N/A';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final classesAsync = ref.watch(classesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DashboardShell(
      title: 'Students Registry',
      child: RefreshIndicator(
        onRefresh: () async {
          ref.read(studentsProvider.notifier).fetchStudents();
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
                        hintText: 'Search by student name, roll number, or code...',
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
                  classesAsync.when(
                    data: (classes) => SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String?>(
                        value: _selectedClassFilter,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Class',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Classes'),
                          ),
                          ...classes.map((cls) {
                            final name = cls['name'] ?? '';
                            final section = cls['section'] ?? '';
                            final label = section.isNotEmpty ? '$name-$section' : name;
                            return DropdownMenuItem<String?>(
                              value: cls['id'],
                              child: Text(label),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedClassFilter = val;
                          });
                        },
                      ),
                    ),
                    loading: () => const SizedBox(
                      width: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const SizedBox(),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddStudentDialog(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Student'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Students List / Table
              Expanded(
                child: studentsAsync.when(
                  data: (students) {
                    // Filter students locally
                    final filteredStudents = students.where((student) {
                      final user = student['users'] ?? {};
                      final name = (user['full_name'] ?? '').toString().toLowerCase();
                      final email = (user['email'] ?? '').toString().toLowerCase();
                      final code = (student['student_code'] ?? '').toString().toLowerCase();
                      final roll = (student['roll_number'] ?? '').toString().toLowerCase();
                      
                      final matchesSearch = name.contains(_searchQuery.toLowerCase()) ||
                          email.contains(_searchQuery.toLowerCase()) ||
                          code.contains(_searchQuery.toLowerCase()) ||
                          roll.contains(_searchQuery.toLowerCase());
                      
                      final matchesClass = _selectedClassFilter == null ||
                          student['class_id'] == _selectedClassFilter;

                      return matchesSearch && matchesClass;
                    }).toList();

                    if (filteredStudents.isEmpty) {
                      return _buildEmptyState();
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 800;

                        if (isMobile) {
                          // Render as clean cards on mobile
                          return ListView.separated(
                            itemCount: filteredStudents.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final student = filteredStudents[index];
                              return _buildStudentCard(context, student);
                            },
                          );
                        }

                        // Render as robust data table on desktop
                        return Card(
                          child: SingleChildScrollView(
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.resolveWith(
                                  (states) => isDark
                                      ? AppColors.darkBorder.withOpacity(0.5)
                                      : AppColors.backgroundLight,
                                ),
                                columns: const [
                                  DataColumn(label: Text('Code')),
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Roll No')),
                                  DataColumn(label: Text('Class')),
                                  DataColumn(label: Text('Guardian')),
                                  DataColumn(label: Text('Adm. Date')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: filteredStudents.map((student) {
                                  final user = student['users'] ?? {};
                                  final cls = student['classes'] ?? {};
                                  final clsLabel = cls['section'] != null && cls['section'].isNotEmpty
                                      ? '${cls['name']}-${cls['section']}'
                                      : (cls['name'] ?? 'Unassigned');

                                  final status = student['status'] ?? 'active';
                                  final statusColor = status == 'active'
                                      ? AppColors.successGreen
                                      : AppColors.textMuted;

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          student['student_code'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      DataCell(
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              user['full_name'] ?? '',
                                              style: AppTextStyles.labelLarge,
                                            ),
                                            Text(
                                              user['email'] ?? '',
                                              style: AppTextStyles.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(student['roll_number'] ?? '')),
                                      DataCell(Text(clsLabel)),
                                      DataCell(
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(student['guardian_name'] ?? 'N/A', style: AppTextStyles.bodyMedium),
                                            Text(student['guardian_phone'] ?? '', style: AppTextStyles.bodySmall),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(_formatDate(student['admission_date']))),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_rounded, color: AppColors.accentSoftBlue),
                                              onPressed: () => _showEditStudentDialog(context, student),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_rounded, color: AppColors.dangerRed),
                                              onPressed: () => _confirmDeleteStudent(context, student),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading students: $err')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context, Map<String, dynamic> student) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = student['users'] ?? {};
    final cls = student['classes'] ?? {};
    final clsLabel = cls['section'] != null && cls['section'].isNotEmpty
        ? '${cls['name']}-${cls['section']}'
        : (cls['name'] ?? 'Unassigned');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  user['full_name'] ?? '',
                  style: AppTextStyles.heading3.copyWith(
                    color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoftBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    student['student_code'] ?? '',
                    style: const TextStyle(
                      color: AppColors.accentSoftBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(user['email'] ?? '', style: AppTextStyles.bodyMedium),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCardMeta('Roll No', student['roll_number'] ?? ''),
                _buildCardMeta('Class', clsLabel),
                _buildCardMeta('Status', (student['status'] ?? 'active').toUpperCase()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCardMeta('Guardian', student['guardian_name'] ?? 'N/A'),
                _buildCardMeta('Phone', student['guardian_phone'] ?? 'N/A'),
                _buildCardMeta('Adm. Date', _formatDate(student['admission_date'])),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showEditStudentDialog(context, student),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _confirmDeleteStudent(context, student),
                  icon: const Icon(Icons.delete_rounded, size: 18, color: AppColors.dangerRed),
                  label: const Text('Delete', style: TextStyle(color: AppColors.dangerRed)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCardMeta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.labelLarge),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 64,
            color: isDark ? AppColors.darkBorder : AppColors.borderLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No students found.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.textMuted : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStudentDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
    final guardianCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    String? selectedClassId;
    DateTime selectedDob = DateTime(2010, 1, 1);
    DateTime selectedAdmissionDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final classesAsync = ref.watch(classesProvider);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Register New Student'),
              content: SizedBox(
                width: 600,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Full Name *'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: emailCtrl,
                                decoration: const InputDecoration(labelText: 'Email *'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: passCtrl,
                                obscureText: true,
                                decoration: const InputDecoration(labelText: 'Password *'),
                                validator: (val) => val == null || val.length < 6 ? 'Min 6 characters' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: rollCtrl,
                                decoration: const InputDecoration(labelText: 'Roll Number *'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: classesAsync.when(
                                data: (classes) => DropdownButtonFormField<String>(
                                  value: selectedClassId,
                                  decoration: const InputDecoration(labelText: 'Assign Class *'),
                                  items: classes.map((cls) {
                                    final name = cls['name'] ?? '';
                                    final section = cls['section'] ?? '';
                                    final label = section.isNotEmpty ? '$name-$section' : name;
                                    return DropdownMenuItem(value: cls['id'] as String, child: Text(label));
                                  }).toList(),
                                  validator: (val) => val == null ? 'Required' : null,
                                  onChanged: (val) {
                                    setState(() {
                                      selectedClassId = val;
                                    });
                                  },
                                ),
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (_, __) => const Text('Error loading classes'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: guardianCtrl,
                                decoration: const InputDecoration(labelText: 'Guardian Name'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: phoneCtrl,
                                decoration: const InputDecoration(labelText: 'Guardian Phone'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDob,
                                    firstDate: DateTime(1990),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setState(() => selectedDob = picked);
                                  }
                                },
                                icon: const Icon(Icons.cake_rounded),
                                label: Text('DOB: ${_formatDate(selectedDob.toIso8601String())}'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedAdmissionDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() => selectedAdmissionDate = picked);
                                  }
                                },
                                icon: const Icon(Icons.calendar_today_rounded),
                                label: Text('Adm: ${_formatDate(selectedAdmissionDate.toIso8601String())}'),
                              ),
                            ),
                          ],
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
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(child: CircularProgressIndicator()),
                        );

                        await ref.read(studentsProvider.notifier).createStudent(
                              fullName: nameCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              password: passCtrl.text,
                              rollNumber: rollCtrl.text.trim(),
                              classId: selectedClassId!,
                              dob: _formatDate(selectedDob.toIso8601String()),
                              guardianName: guardianCtrl.text.trim(),
                              guardianPhone: phoneCtrl.text.trim(),
                              admissionDate: _formatDate(selectedAdmissionDate.toIso8601String()),
                            );

                        if (context.mounted) {
                          // Pop loader, then dialog
                          Navigator.pop(context);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Student registered successfully')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context); // Pop loader
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

  void _showEditStudentDialog(BuildContext context, Map<String, dynamic> student) {
    final formKey = GlobalKey<FormState>();
    final user = student['users'] ?? {};

    final nameCtrl = TextEditingController(text: user['full_name'] ?? '');
    final rollCtrl = TextEditingController(text: student['roll_number'] ?? '');
    final guardianCtrl = TextEditingController(text: student['guardian_name'] ?? '');
    final phoneCtrl = TextEditingController(text: student['guardian_phone'] ?? '');

    String? selectedClassId = student['class_id'];
    String status = student['status'] ?? 'active';
    DateTime selectedDob = DateTime.tryParse(student['dob'] ?? '') ?? DateTime(2010, 1, 1);
    DateTime selectedAdmissionDate = DateTime.tryParse(student['admission_date'] ?? '') ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final classesAsync = ref.watch(classesProvider);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit Student Profile'),
              content: SizedBox(
                width: 600,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Full Name *'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: rollCtrl,
                                decoration: const InputDecoration(labelText: 'Roll Number *'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: classesAsync.when(
                                data: (classes) => DropdownButtonFormField<String>(
                                  value: selectedClassId,
                                  decoration: const InputDecoration(labelText: 'Class *'),
                                  items: classes.map((cls) {
                                    final name = cls['name'] ?? '';
                                    final section = cls['section'] ?? '';
                                    final label = section.isNotEmpty ? '$name-$section' : name;
                                    return DropdownMenuItem(value: cls['id'] as String, child: Text(label));
                                  }).toList(),
                                  validator: (val) => val == null ? 'Required' : null,
                                  onChanged: (val) {
                                    setState(() {
                                      selectedClassId = val;
                                    });
                                  },
                                ),
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (_, __) => const Text('Error loading classes'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: guardianCtrl,
                                decoration: const InputDecoration(labelText: 'Guardian Name'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: phoneCtrl,
                                decoration: const InputDecoration(labelText: 'Guardian Phone'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(value: 'active', child: Text('ACTIVE')),
                            DropdownMenuItem(value: 'inactive', child: Text('INACTIVE')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                status = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDob,
                                    firstDate: DateTime(1990),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setState(() => selectedDob = picked);
                                  }
                                },
                                icon: const Icon(Icons.cake_rounded),
                                label: Text('DOB: ${_formatDate(selectedDob.toIso8601String())}'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedAdmissionDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() => selectedAdmissionDate = picked);
                                  }
                                },
                                icon: const Icon(Icons.calendar_today_rounded),
                                label: Text('Adm: ${_formatDate(selectedAdmissionDate.toIso8601String())}'),
                              ),
                            ),
                          ],
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

                        await ref.read(studentsProvider.notifier).updateStudent(
                              studentId: student['id'],
                              userId: user['id'],
                              fullName: nameCtrl.text.trim(),
                              rollNumber: rollCtrl.text.trim(),
                              classId: selectedClassId!,
                              dob: _formatDate(selectedDob.toIso8601String()),
                              guardianName: guardianCtrl.text.trim(),
                              guardianPhone: phoneCtrl.text.trim(),
                              admissionDate: _formatDate(selectedAdmissionDate.toIso8601String()),
                              status: status,
                            );

                        if (context.mounted) {
                          Navigator.pop(context);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Student profile updated successfully')),
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

  void _confirmDeleteStudent(BuildContext context, Map<String, dynamic> student) {
    final user = student['users'] ?? {};
    final fullName = user['full_name'] ?? 'this student';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Soft Delete Student'),
          content: Text('Are you sure you want to soft delete $fullName? This will mark their profile as inactive and hide it from listings.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
              onPressed: () async {
                try {
                  await ref.read(studentsProvider.notifier).deleteStudent(student['id']);
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
