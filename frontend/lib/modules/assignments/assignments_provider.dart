import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';

// ---------------------------------------------------------------------------
// Teacher: list of their assignments (with class info)
// ---------------------------------------------------------------------------
final teacherAssignmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];

  final teacherRow = await client
      .from('teachers')
      .select('id, users!inner(auth_user_id)')
      .eq('users.auth_user_id', userId)
      .maybeSingle();

  if (teacherRow == null) return [];
  final teacherId = teacherRow['id'] as String;

  final response = await client
      .from('assignments')
      .select('*, classes(id, name, section)')
      .eq('teacher_id', teacherId)
      .order('due_date', ascending: true);

  return List<Map<String, dynamic>>.from(response);
});

// ---------------------------------------------------------------------------
// Submissions for a specific assignment (teacher view)
// ---------------------------------------------------------------------------
final assignmentSubmissionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, assignmentId) async {
  final client = ref.watch(supabaseClientProvider);

  final response = await client
      .from('submissions')
      .select('*, students(id, roll_number, users(full_name))')
      .eq('assignment_id', assignmentId);

  return List<Map<String, dynamic>>.from(response);
});

// ---------------------------------------------------------------------------
// Teacher: create assignment
// ---------------------------------------------------------------------------
class AssignmentCreationNotifier extends StateNotifier<AsyncValue<void>> {
  AssignmentCreationNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> create({
    required String title,
    required String description,
    required String classId,
    required String dueDate,
    String? fileUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;

      final teacherRow = await client
          .from('teachers')
          .select('id, users!inner(auth_user_id)')
          .eq('users.auth_user_id', userId!)
          .maybeSingle();

      if (teacherRow == null) throw Exception('Teacher profile not found');
      final teacherId = teacherRow['id'] as String;

      await client.from('assignments').insert({
        'teacher_id': teacherId,
        'class_id': classId,
        'title': title,
        'description': description,
        'due_date': dueDate,
        'file_url': fileUrl,
      });

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final assignmentCreationProvider =
    StateNotifierProvider<AssignmentCreationNotifier, AsyncValue<void>>(
  (ref) => AssignmentCreationNotifier(ref),
);

// ---------------------------------------------------------------------------
// Teacher: grade a submission
// ---------------------------------------------------------------------------
class SubmissionGradeNotifier extends StateNotifier<AsyncValue<void>> {
  SubmissionGradeNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> grade({
    required String submissionId,
    required String grade,
    required String feedback,
  }) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.from('submissions').update({
        'grade': grade,
        'feedback': feedback,
        'status': 'graded',
      }).eq('id', submissionId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final submissionGradeProvider =
    StateNotifierProvider<SubmissionGradeNotifier, AsyncValue<void>>(
  (ref) => SubmissionGradeNotifier(ref),
);

// ---------------------------------------------------------------------------
// Student: list of assignments for their class
// ---------------------------------------------------------------------------
final studentAssignmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];

  final studentRow = await client
      .from('students')
      .select('id, class_id, users!inner(auth_user_id)')
      .eq('users.auth_user_id', userId)
      .maybeSingle();

  if (studentRow == null) return [];
  final classId = studentRow['class_id'] as String?;
  if (classId == null) return [];

  final response = await client
      .from('assignments')
      .select('*, teachers(id, teacher_code, users(full_name))')
      .eq('class_id', classId)
      .order('due_date', ascending: true);

  return List<Map<String, dynamic>>.from(response);
});

// ---------------------------------------------------------------------------
// Student: their own submissions
// ---------------------------------------------------------------------------
final studentSubmissionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];

  final studentRow = await client
      .from('students')
      .select('id, users!inner(auth_user_id)')
      .eq('users.auth_user_id', userId)
      .maybeSingle();

  if (studentRow == null) return [];
  final studentId = studentRow['id'] as String;

  final response = await client
      .from('submissions')
      .select('assignment_id, status, grade, feedback, submitted_at')
      .eq('student_id', studentId);

  return List<Map<String, dynamic>>.from(response);
});

// ---------------------------------------------------------------------------
// Student: submit assignment (text URL — file upload handled separately)
// ---------------------------------------------------------------------------
class SubmissionNotifier extends StateNotifier<AsyncValue<void>> {
  SubmissionNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> submit({
    required String assignmentId,
    required String fileUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;

      final studentRow = await client
          .from('students')
          .select('id, users!inner(auth_user_id)')
          .eq('users.auth_user_id', userId!)
          .maybeSingle();

      if (studentRow == null) throw Exception('Student profile not found');
      final studentId = studentRow['id'] as String;

      await client.from('submissions').upsert(
        {
          'assignment_id': assignmentId,
          'student_id': studentId,
          'file_url': fileUrl,
          'status': 'submitted',
          'submitted_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'assignment_id,student_id',
      );

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final submissionNotifierProvider =
    StateNotifierProvider<SubmissionNotifier, AsyncValue<void>>(
  (ref) => SubmissionNotifier(ref),
);
