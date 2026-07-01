import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';

/// Aggregated data for Student Dashboard
class StudentDashboardData {
  final Map<String, dynamic>? studentProfile;
  final double attendanceRate;
  final int totalPresent;
  final int totalAbsent;
  final int totalLate;
  final int totalLeave;
  final List<Map<String, dynamic>> announcements;
  final List<Map<String, dynamic>> pendingHomework; // Assignments not submitted or graded

  const StudentDashboardData({
    required this.studentProfile,
    required this.attendanceRate,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalLate,
    required this.totalLeave,
    required this.announcements,
    required this.pendingHomework,
  });
}

/// Provider to fetch all Student Dashboard data
final studentDashboardDataProvider = FutureProvider<StudentDashboardData>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    throw Exception('User not authenticated');
  }

  // 1. Get student profile with class details
  final studentProfileResponse = await client
      .from('students')
      .select('*, users(id, full_name, email), classes(id, name, section)')
      .eq('users.auth_user_id', userId)
      .maybeSingle();

  if (studentProfileResponse == null) {
    return const StudentDashboardData(
      studentProfile: null,
      attendanceRate: 0.0,
      totalPresent: 0,
      totalAbsent: 0,
      totalLate: 0,
      totalLeave: 0,
      announcements: [],
      pendingHomework: [],
    );
  }

  final studentProfile = Map<String, dynamic>.from(studentProfileResponse);
  final studentId = studentProfile['id'] as String;
  final classId = studentProfile['class_id'] as String?;

  // 2. Fetch attendance records to compute rate
  final attendanceResponse = await client
      .from('attendance')
      .select('status')
      .eq('student_id', studentId);

  int present = 0;
  int absent = 0;
  int late = 0;
  int leave = 0;

  for (final record in attendanceResponse) {
    final status = record['status'] as String?;
    if (status == 'present') present++;
    if (status == 'absent') absent++;
    if (status == 'late') late++;
    if (status == 'leave') leave++;
  }

  final totalAttendance = present + absent + late + leave;
  final attendanceRate = totalAttendance > 0
      ? ((present + late) / totalAttendance * 100)
      : 0.0;

  // 3. Fetch Announcements for students audience
  final announcementsResponse = await client
      .from('announcements')
      .select('*, users(full_name)')
      .inFilter('audience', ['all', 'students'])
      .order('created_at', descending: true);

  final announcements = List<Map<String, dynamic>>.from(announcementsResponse);

  // 4. Fetch pending homework alerts
  List<Map<String, dynamic>> pendingHomework = [];
  if (classId != null) {
    // Fetch all assignments for class
    final assignmentsResponse = await client
        .from('assignments')
        .select('*, teachers(id, users(full_name))')
        .eq('class_id', classId)
        .order('due_date', ascending: true);

    // Fetch student's submissions
    final submissionsResponse = await client
        .from('submissions')
        .select('assignment_id, status')
        .eq('student_id', studentId);

    final submittedAssignmentIds = submissionsResponse
        .map((s) => s['assignment_id'] as String)
        .toSet();

    final assignments = List<Map<String, dynamic>>.from(assignmentsResponse);
    
    // Filter assignments that are not submitted yet
    pendingHomework = assignments.where((a) {
      final assignmentId = a['id'] as String;
      return !submittedAssignmentIds.contains(assignmentId);
    }).toList();
  }

  return StudentDashboardData(
    studentProfile: studentProfile,
    attendanceRate: attendanceRate,
    totalPresent: present,
    totalAbsent: absent,
    totalLate: late,
    totalLeave: leave,
    announcements: announcements,
    pendingHomework: pendingHomework,
  );
});
