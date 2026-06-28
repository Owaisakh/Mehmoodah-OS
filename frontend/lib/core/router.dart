import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'supabase.dart';
import '../modules/auth/login_page.dart';
import '../modules/dashboard/admin_dashboard.dart';
import '../modules/dashboard/teacher_dashboard.dart';
import '../modules/dashboard/student_dashboard.dart';
import '../modules/students/students_page.dart';
import '../modules/teachers/teachers_page.dart';
import '../modules/attendance/attendance_page.dart';
import '../modules/results/results_page.dart';
import '../modules/assignments/assignments_page.dart';
import '../modules/timetable/timetable_page.dart';
import '../modules/reports/reports_page.dart';
import '../modules/profile/profile_page.dart';

// ---------------------------------------------------------------------------
// Route name constants
// ---------------------------------------------------------------------------
class AppRoutes {
  static const login = '/login';

  // Admin
  static const adminDashboard   = '/admin/dashboard';
  static const adminStudents    = '/admin/students';
  static const adminTeachers    = '/admin/teachers';
  static const adminTimetable   = '/admin/timetable';
  static const adminReports     = '/admin/reports';
  static const adminProfile     = '/admin/profile';

  // Teacher
  static const teacherDashboard  = '/teacher/dashboard';
  static const teacherAttendance = '/teacher/attendance';
  static const teacherResults    = '/teacher/results';
  static const teacherAssignments= '/teacher/assignments';
  static const teacherProfile    = '/teacher/profile';

  // Student
  static const studentDashboard  = '/student/dashboard';
  static const studentAttendance = '/student/attendance';
  static const studentResults    = '/student/results';
  static const studentHomework   = '/student/homework';
  static const studentTimetable  = '/student/timetable';
  static const studentProfile    = '/student/profile';
}

// ---------------------------------------------------------------------------
// Router provider (Riverpod)
// ---------------------------------------------------------------------------
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(supabaseAuthStateProvider);
  final roleAsync  = ref.watch(userRoleProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.value?.session != null;
      final onLogin    = state.matchedLocation == AppRoutes.login;

      // Not authenticated → always send to login
      if (!isLoggedIn) return onLogin ? null : AppRoutes.login;

      final role = roleAsync.value;

      // If role is still loading, wait on current route.
      if (role == null) return null;

      // Authenticated but still on login → redirect to role dashboard
      if (onLogin) {
        if (role == 'admin')   return AppRoutes.adminDashboard;
        if (role == 'teacher') return AppRoutes.teacherDashboard;
        if (role == 'student') return AppRoutes.studentDashboard;
      }

      // Enforce role-based guards
      final location = state.matchedLocation;
      if (location.startsWith('/admin') && role != 'admin') {
        return role == 'teacher' ? AppRoutes.teacherDashboard : AppRoutes.studentDashboard;
      }
      if (location.startsWith('/teacher') && role != 'teacher') {
        return role == 'admin' ? AppRoutes.adminDashboard : AppRoutes.studentDashboard;
      }
      if (location.startsWith('/student') && role != 'student') {
        return role == 'admin' ? AppRoutes.adminDashboard : AppRoutes.teacherDashboard;
      }

      return null; // no redirect
    },
    routes: [
      // ------------------------------------------------------------------
      // Auth
      // ------------------------------------------------------------------
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (_, __) => const LoginPage(),
      ),

      // ------------------------------------------------------------------
      // Admin shell
      // ------------------------------------------------------------------
      GoRoute(
        path: AppRoutes.adminDashboard,
        name: 'adminDashboard',
        builder: (_, __) => const AdminDashboard(),
      ),
      GoRoute(
        path: AppRoutes.adminStudents,
        name: 'adminStudents',
        builder: (_, __) => const StudentsPage(),
      ),
      GoRoute(
        path: AppRoutes.adminTeachers,
        name: 'adminTeachers',
        builder: (_, __) => const TeachersPage(),
      ),
      GoRoute(
        path: AppRoutes.adminTimetable,
        name: 'adminTimetable',
        builder: (_, __) => const TimetablePage(),
      ),
      GoRoute(
        path: AppRoutes.adminReports,
        name: 'adminReports',
        builder: (_, __) => const ReportsPage(),
      ),
      GoRoute(
        path: AppRoutes.adminProfile,
        name: 'adminProfile',
        builder: (_, __) => const ProfilePage(),
      ),

      // ------------------------------------------------------------------
      // Teacher shell
      // ------------------------------------------------------------------
      GoRoute(
        path: AppRoutes.teacherDashboard,
        name: 'teacherDashboard',
        builder: (_, __) => const TeacherDashboard(),
      ),
      GoRoute(
        path: AppRoutes.teacherAttendance,
        name: 'teacherAttendance',
        builder: (_, __) => const AttendancePage(),
      ),
      GoRoute(
        path: AppRoutes.teacherResults,
        name: 'teacherResults',
        builder: (_, __) => const ResultsPage(),
      ),
      GoRoute(
        path: AppRoutes.teacherAssignments,
        name: 'teacherAssignments',
        builder: (_, __) => const AssignmentsPage(),
      ),
      GoRoute(
        path: AppRoutes.teacherProfile,
        name: 'teacherProfile',
        builder: (_, __) => const ProfilePage(),
      ),

      // ------------------------------------------------------------------
      // Student shell
      // ------------------------------------------------------------------
      GoRoute(
        path: AppRoutes.studentDashboard,
        name: 'studentDashboard',
        builder: (_, __) => const StudentDashboard(),
      ),
      GoRoute(
        path: AppRoutes.studentAttendance,
        name: 'studentAttendance',
        builder: (_, __) => const AttendancePage(),
      ),
      GoRoute(
        path: AppRoutes.studentResults,
        name: 'studentResults',
        builder: (_, __) => const ResultsPage(),
      ),
      GoRoute(
        path: AppRoutes.studentHomework,
        name: 'studentHomework',
        builder: (_, __) => const AssignmentsPage(),
      ),
      GoRoute(
        path: AppRoutes.studentTimetable,
        name: 'studentTimetable',
        builder: (_, __) => const TimetablePage(),
      ),
      GoRoute(
        path: AppRoutes.studentProfile,
        name: 'studentProfile',
        builder: (_, __) => const ProfilePage(),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
