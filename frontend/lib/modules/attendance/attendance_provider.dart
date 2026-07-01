import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';

// ---------------------------------------------------------------------------
// Provider: teacher's assigned classes (via class_teachers join)
// ---------------------------------------------------------------------------
final teacherClassesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];

  // First resolve auth user → teachers.id
  final teacherRow = await client
      .from('teachers')
      .select('id, users!inner(auth_user_id)')
      .eq('users.auth_user_id', userId)
      .maybeSingle();

  if (teacherRow == null) return [];
  final teacherId = teacherRow['id'] as String;

  // Fetch classes through many-to-many class_teachers
  final rows = await client
      .from('class_teachers')
      .select('classes(id, name, section, grade_level)')
      .eq('teacher_id', teacherId);

  return rows
      .map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r['classes'] as Map))
      .toList();
});

// ---------------------------------------------------------------------------
// Provider: current teacher's DB id
// ---------------------------------------------------------------------------
final currentTeacherIdProvider = FutureProvider<String?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  final row = await client
      .from('teachers')
      .select('id, users!inner(auth_user_id)')
      .eq('users.auth_user_id', userId)
      .maybeSingle();

  return row?['id'] as String?;
});

// ---------------------------------------------------------------------------
// Provider: students in a selected class
// ---------------------------------------------------------------------------
final classStudentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, classId) async {
  final client = ref.watch(supabaseClientProvider);

  final response = await client
      .from('students')
      .select('id, roll_number, users(id, full_name)')
      .eq('class_id', classId)
      .is_('deleted_at', null)
      .order('roll_number');

  return List<Map<String, dynamic>>.from(response);
});

// ---------------------------------------------------------------------------
// Provider: existing attendance records for a class + date
// ---------------------------------------------------------------------------
final existingAttendanceProvider = FutureProvider.family<
    Map<String, String>, // studentId → status
    ({String classId, String date})>((ref, params) async {
  final client = ref.watch(supabaseClientProvider);

  final rows = await client
      .from('attendance')
      .select('student_id, status')
      .eq('class_id', params.classId)
      .eq('date', params.date);

  final map = <String, String>{};
  for (final r in rows) {
    map[r['student_id'] as String] = r['status'] as String;
  }
  return map;
});

// ---------------------------------------------------------------------------
// StateNotifier: manage in-memory attendance draft + submit
// ---------------------------------------------------------------------------
class AttendanceNotifier extends StateNotifier<Map<String, String>> {
  AttendanceNotifier() : super({});

  void init(Map<String, String> existing) {
    state = Map<String, String>.from(existing);
  }

  void setStatus(String studentId, String status) {
    state = {...state, studentId: status};
  }

  void setAll(List<String> studentIds, String status) {
    final updated = Map<String, String>.from(state);
    for (final id in studentIds) {
      updated[id] = status;
    }
    state = updated;
  }
}

final attendanceDraftProvider =
    StateNotifierProvider<AttendanceNotifier, Map<String, String>>(
  (ref) => AttendanceNotifier(),
);

// ---------------------------------------------------------------------------
// Action: upsert attendance for all students in a class
// ---------------------------------------------------------------------------
class AttendanceSubmitNotifier extends StateNotifier<AsyncValue<void>> {
  AttendanceSubmitNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> submit({
    required String classId,
    required String date,
    required Map<String, String> attendanceMap,
  }) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      final rows = attendanceMap.entries
          .map((e) => {
                'class_id': classId,
                'student_id': e.key,
                'date': date,
                'status': e.value,
              })
          .toList();

      await client.from('attendance').upsert(
            rows,
            onConflict: 'student_id,class_id,date',
          );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final attendanceSubmitProvider =
    StateNotifierProvider<AttendanceSubmitNotifier, AsyncValue<void>>(
  (ref) => AttendanceSubmitNotifier(ref),
);

// ---------------------------------------------------------------------------
// Student's own monthly attendance (read-only calendar)
// ---------------------------------------------------------------------------
final studentMonthlyAttendanceProvider = FutureProvider.family<
    List<Map<String, dynamic>>,
    ({String classId, int year, int month})>((ref, params) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];

  // Resolve student id
  final studentRow = await client
      .from('students')
      .select('id, users!inner(auth_user_id)')
      .eq('users.auth_user_id', userId)
      .maybeSingle();

  if (studentRow == null) return [];
  final studentId = studentRow['id'] as String;

  final startDate = '${params.year}-${params.month.toString().padLeft(2, '0')}-01';
  final endDay =
      DateTime(params.year, params.month + 1, 0).day; // last day of month
  final endDate =
      '${params.year}-${params.month.toString().padLeft(2, '0')}-${endDay.toString().padLeft(2, '0')}';

  final rows = await client
      .from('attendance')
      .select('date, status')
      .eq('student_id', studentId)
      .eq('class_id', params.classId)
      .gte('date', startDate)
      .lte('date', endDate)
      .order('date');

  return List<Map<String, dynamic>>.from(rows);
});

// ---------------------------------------------------------------------------
// Student's own classes provider
// ---------------------------------------------------------------------------
final studentClassesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];

  final studentRow = await client
      .from('students')
      .select('id, class_id, classes(id, name, section), users!inner(auth_user_id)')
      .eq('users.auth_user_id', userId)
      .maybeSingle();

  if (studentRow == null) return [];
  final cls = studentRow['classes'];
  if (cls == null) return [];
  return [Map<String, dynamic>.from(cls as Map)];
});
