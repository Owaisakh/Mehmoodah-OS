import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../shared/widgets/dashboard_shell.dart';
import '../students/students_provider.dart'; // for classesProvider
import 'export_helper_stub.dart' if (dart.library.html) 'export_helper_web.dart' as helper;
import 'reports_provider.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  String _reportType = 'attendance'; // 'attendance' | 'results'
  String? _selectedClassId;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  bool _dataFetched = false;

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider);
    final reportsAsync = ref.watch(reportsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DashboardShell(
      title: 'Reports & Analytics',
      child: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading classes: $err')),
        data: (classes) {
          // Initialize first class if needed (optional - or allow all classes as null)
          if (!_dataFetched) {
            _fetchReportData();
            _dataFetched = true;
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Header & Report Type Toggle
                _buildHeader(isDark),
                const SizedBox(height: 24),

                // Filters (Class + Date Range Picker)
                _buildFilters(classes, isDark),
                const SizedBox(height: 28),

                // Report Content & Charts
                reportsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Text('Error generating report: $err', style: const TextStyle(color: AppColors.dangerRed)),
                  ),
                  data: (data) {
                    if (data.isEmpty) {
                      return _buildEmptyState(isDark);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Export Actions Bar
                        _buildExportActions(data, isDark),
                        const SizedBox(height: 24),

                        // Analytics Charts
                        if (_reportType == 'attendance')
                          _buildAttendanceAnalytics(data, isDark)
                        else
                          _buildResultsAnalytics(data, isDark),
                        const SizedBox(height: 28),

                        // Data Table View
                        _buildReportDataTable(data, isDark),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Fetch data
  void _fetchReportData() {
    final fromStr = '${_fromDate.year}-${_fromDate.month.toString().padLeft(2, '0')}-${_fromDate.day.toString().padLeft(2, '0')}';
    final toStr = '${_toDate.year}-${_toDate.month.toString().padLeft(2, '0')}-${_toDate.day.toString().padLeft(2, '0')}';
    ref.read(reportsProvider.notifier).fetchReport(
          reportType: _reportType,
          classId: _selectedClassId,
          fromDate: fromStr,
          toDate: toStr,
        );
  }

  Widget _buildHeader(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            
            final toggle = SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'attendance',
                  label: Text('Attendance Analytics'),
                  icon: Icon(Icons.check_circle_outline_rounded),
                ),
                ButtonSegment<String>(
                  value: 'results',
                  label: Text('Grades & Performance'),
                  icon: Icon(Icons.grade_outlined),
                ),
              ],
              selected: {_reportType},
              onSelectionChanged: (val) {
                setState(() {
                  _reportType = val.first;
                });
                _fetchReportData();
              },
            );

            if (isWide) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'School Analytics Reports',
                        style: AppTextStyles.heading2.copyWith(
                          color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Generate detailed visual metrics and export data', style: AppTextStyles.bodySmall),
                    ],
                  ),
                  toggle,
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'School Analytics Reports',
                    style: AppTextStyles.heading2.copyWith(
                      color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: toggle),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildFilters(List<Map<String, dynamic>> classes, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report Filter Controls',
              style: AppTextStyles.labelLarge.copyWith(
                color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 750;
                
                final classDropdown = DropdownButtonFormField<String>(
                  value: _selectedClassId,
                  decoration: const InputDecoration(
                    labelText: 'Class (Optional)',
                    prefixIcon: Icon(Icons.class_rounded),
                  ),
                  dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Classes'),
                    ),
                    ...classes.map((c) => DropdownMenuItem<String>(
                          value: c['id'] as String,
                          child: Text('${c['name']} (${c['section']})'),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedClassId = val;
                    });
                    _fetchReportData();
                  },
                );

                final datePicker = InkWell(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _fromDate = picked.start;
                        _toDate = picked.end;
                      });
                      _fetchReportData();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date Range Range',
                      prefixIcon: Icon(Icons.date_range_rounded),
                    ),
                    child: Text(
                      '${_fromDate.day}/${_fromDate.month}/${_fromDate.year} - ${_toDate.day}/${_toDate.month}/${_toDate.year}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: classDropdown),
                      const SizedBox(width: 16),
                      Expanded(child: datePicker),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      classDropdown,
                      const SizedBox(height: 16),
                      datePicker,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportActions(List<Map<String, dynamic>> data, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: () => _exportToCSV(data),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Export CSV Report'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // Visual Graphics: Attendance rate stack metrics
  Widget _buildAttendanceAnalytics(List<Map<String, dynamic>> data, bool isDark) {
    int present = 0, absent = 0, late = 0, leave = 0;
    for (final r in data) {
      final status = r['status'] as String?;
      if (status == 'present') present++;
      if (status == 'absent') absent++;
      if (status == 'late') late++;
      if (status == 'leave') leave++;
    }

    final total = present + absent + late + leave;
    final rate = total > 0 ? ((present + late) / total * 100) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Visual Metrics',
              style: AppTextStyles.heading3.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                
                final chartWidget = SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 130,
                        height: 130,
                        child: CircularProgressIndicator(
                          value: rate / 100,
                          strokeWidth: 12,
                          backgroundColor: isDark ? AppColors.darkBorder : AppColors.borderLight,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            rate >= 80 ? AppColors.successGreen : (rate >= 60 ? AppColors.warningOrange : AppColors.dangerRed),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${rate.toStringAsFixed(1)}%',
                            style: AppTextStyles.heading2.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          Text('Overall Rate', style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ],
                  ),
                );

                final barDistribution = Column(
                  children: [
                    _buildProgressBarMetric('Present', present, total, AppColors.successGreen, isDark),
                    const SizedBox(height: 12),
                    _buildProgressBarMetric('Absent', absent, total, AppColors.dangerRed, isDark),
                    const SizedBox(height: 12),
                    _buildProgressBarMetric('Late', late, total, AppColors.warningOrange, isDark),
                    const SizedBox(height: 12),
                    _buildProgressBarMetric('Leave', leave, total, AppColors.textSecondary, isDark),
                  ],
                );

                if (isWide) {
                  return Row(
                    children: [
                      const SizedBox(width: 20),
                      chartWidget,
                      const SizedBox(width: 48),
                      Expanded(child: barDistribution),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Center(child: chartWidget),
                      const SizedBox(height: 24),
                      barDistribution,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBarMetric(String label, int count, int total, Color color, bool isDark) {
    final pct = total > 0 ? (count / total) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: isDark ? AppColors.darkBorder : AppColors.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          textAlign: TextAlign.end,
          child: Text(
            '$count (${(pct * 100).toStringAsFixed(1)}%)',
            style: AppTextStyles.bodySmall,
          ),
        ),
      ],
    );
  }

  // Visual Graphics: Grade Distribution Custom Bar chart
  Widget _buildResultsAnalytics(List<Map<String, dynamic>> data, bool isDark) {
    int gradeAPlus = 0, gradeA = 0, gradeB = 0, gradeC = 0, gradeD = 0, gradeF = 0;
    double totalMarks = 0;
    double obtainedMarks = 0;

    for (final r in data) {
      final grade = r['grade'] as String?;
      final obtained = (r['marks_obtained'] as num?)?.toDouble() ?? 0;
      final total = (r['total_marks'] as num?)?.toDouble() ?? 100;

      totalMarks += total;
      obtainedMarks += obtained;

      if (grade == 'A+') gradeAPlus++;
      else if (grade == 'A') gradeA++;
      else if (grade == 'B') gradeB++;
      else if (grade == 'C') gradeC++;
      else if (grade == 'D') gradeD++;
      else if (grade == 'F') gradeF++;
    }

    final overallRate = totalMarks > 0 ? (obtainedMarks / totalMarks * 100) : 0.0;
    final gradesCounts = [gradeAPlus, gradeA, gradeB, gradeC, gradeD, gradeF];
    final gradesLabels = ['A+', 'A', 'B', 'C', 'D', 'F'];
    final maxCount = gradesCounts.reduce((curr, next) => curr > next ? curr : next);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Grade Distribution Metrics',
                  style: AppTextStyles.heading3.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoftBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Avg: ${overallRate.toStringAsFixed(1)}%',
                    style: const TextStyle(color: AppColors.accentSoftBlue, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Custom drawn bar chart
            SizedBox(
              height: 180,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(gradesLabels.length, (index) {
                  final label = gradesLabels[index];
                  final count = gradesCounts[index];
                  final pctHeight = maxCount > 0 ? (count / maxCount) : 0.0;

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          count.toString(),
                          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: (120 * pctHeight).clamp(6.0, 120.0),
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.accentSoftBlue, AppColors.primaryDeepNavy],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Data view table
  Widget _buildReportDataTable(List<Map<String, dynamic>> data, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Report Data Entries',
              style: AppTextStyles.labelLarge.copyWith(
                color: isDark ? Colors.white : AppColors.primaryDeepNavy,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: _buildTableColumns(),
                  rows: data.map((item) => _buildTableRow(item, isDark)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    if (_reportType == 'attendance') {
      return const [
        DataColumn(label: Text('Student Code')),
        DataColumn(label: Text('Student Name')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Status')),
      ];
    } else {
      return const [
        DataColumn(label: Text('Student Code')),
        DataColumn(label: Text('Student Name')),
        DataColumn(label: Text('Subject')),
        DataColumn(label: Text('Exam')),
        DataColumn(label: Text('Marks Obtained')),
        DataColumn(label: Text('Total Marks')),
        DataColumn(label: Text('Grade')),
      ];
    }
  }

  DataRow _buildTableRow(Map<String, dynamic> item, bool isDark) {
    final student = item['students'] as Map<String, dynamic>? ?? {};
    final user = student['users'] as Map<String, dynamic>? ?? {};
    final code = student['student_code'] ?? '--';
    final name = user['full_name'] ?? 'Unknown';

    if (_reportType == 'attendance') {
      final date = item['date'] ?? '--';
      final status = item['status'] as String? ?? 'present';
      
      Color statusColor = AppColors.successGreen;
      if (status == 'absent') statusColor = AppColors.dangerRed;
      if (status == 'late') statusColor = AppColors.warningOrange;
      if (status == 'leave') statusColor = AppColors.textSecondary;

      return DataRow(
        cells: [
          DataCell(Text(code)),
          DataCell(Text(name)),
          DataCell(Text(date)),
          DataCell(Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          )),
        ],
      );
    } else {
      final subject = item['subject'] ?? 'N/A';
      final exam = item['exams'] != null ? item['exams']['name'] ?? 'Exam' : 'Exam';
      final obtained = item['marks_obtained']?.toString() ?? '0';
      final total = item['total_marks']?.toString() ?? '100';
      final grade = item['grade'] ?? 'F';

      return DataRow(
        cells: [
          DataCell(Text(code)),
          DataCell(Text(name)),
          DataCell(Text(subject)),
          DataCell(Text(exam)),
          DataCell(Text(obtained)),
          DataCell(Text(total)),
          DataCell(_buildGradeChip(grade)),
        ],
      );
    }
  }

  Widget _buildGradeChip(String grade) {
    Color color = AppColors.successGreen;
    if (grade == 'F') color = AppColors.dangerRed;
    else if (grade == 'D') color = Colors.orange.shade800;
    else if (grade == 'C') color = AppColors.warningOrange;
    else if (grade == 'B') color = AppColors.accentSoftBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        grade,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Export helper logic to generate and download CSV
  void _exportToCSV(List<Map<String, dynamic>> data) {
    final buffer = StringBuffer();
    
    // Header
    if (_reportType == 'attendance') {
      buffer.writeln('Student Code,Student Name,Date,Status');
      for (final r in data) {
        final s = r['students'] as Map?;
        final u = s?['users'] as Map?;
        final code = s?['student_code'] ?? '';
        final name = u?['full_name'] ?? '';
        final date = r['date'] ?? '';
        final status = r['status'] ?? '';
        buffer.writeln('"$code","$name","$date","$status"');
      }
    } else {
      buffer.writeln('Student Code,Student Name,Subject,Exam,Marks Obtained,Total Marks,Grade');
      for (final r in data) {
        final s = r['students'] as Map?;
        final u = s?['users'] as Map?;
        final exam = r['exams'] as Map?;
        final code = s?['student_code'] ?? '';
        final name = u?['full_name'] ?? '';
        final subject = r['subject'] ?? '';
        final examName = exam?['name'] ?? '';
        final obtained = r['marks_obtained'] ?? '';
        final total = r['total_marks'] ?? '';
        final grade = r['grade'] ?? '';
        buffer.writeln('"$code","$name","$subject","$examName",$obtained,$total,"$grade"');
      }
    }

    final dateStr = '${DateTime.now().year}${DateTime.now().month}${DateTime.now().day}';
    final fileName = 'report_${_reportType}_$dateStr.csv';
    
    // Trigger download
    helper.downloadFile(buffer.toString(), fileName, 'text/csv');
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.borderLight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 72, color: isDark ? AppColors.darkBorder : AppColors.borderLight),
          const SizedBox(height: 20),
          Text(
            'No Report Entries Found',
            style: AppTextStyles.heading3.copyWith(
              color: isDark ? AppColors.textMuted : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Try modifying class filters or extending date ranges.', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
