import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';
import '../attendance/attendance_provider.dart';

// ---------------------------------------------------------------------------
// Exams for a teacher's classes
// ---------------------------------------------------------------------------
final teacherExamsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, classId) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('exams')
      .select('id, name, term, class_id, is_published')
      .eq('class_id', classId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

// ---------------------------------------------------------------------------
// Results for a specific exam (teacher view: all students)
// ---------------------------------------------------------------------------
final examResultsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, examId) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('results')
      .select('id, exam_id, student_id, subject, marks_obtained, total_marks, percentage, grade, students(id, roll_number, users(full_name))')
      .eq('exam_id', examId);
  return List<Map<String, dynamic>>.from(response);
});

// ---------------------------------------------------------------------------
// StateNotifier: manage result marks before saving
// ---------------------------------------------------------------------------
class ResultsMarksNotifier extends StateNotifier<Map<String, Map<String, dynamic>>> {
  // Map: studentId → {subject, marks_obtained, total_marks}
  ResultsMarksNotifier() : super({});

  void init(List<Map<String, dynamic>> existingResults, List<Map<String, dynamic>> students, String defaultSubject) {
    final map = <String, Map<String, dynamic>>{};
    for (final s in students) {
      final sid = s['id'] as String;
      final existing = existingResults.where((r) => r['student_id'] == sid).toList();
      if (existing.isNotEmpty) {
        final r = existing.first;
        map[sid] = {
          'subject': r['subject'] ?? defaultSubject,
          'marks_obtained': r['marks_obtained']?.toString() ?? '0',
          'total_marks': r['total_marks']?.toString() ?? '100',
        };
      } else {
        map[sid] = {
          'subject': defaultSubject,
          'marks_obtained': '',
          'total_marks': '100',
        };
      }
    }
    state = map;
  }

  void updateMarks(String studentId, String marks) {
    state = {
      ...state,
      studentId: {...(state[studentId] ?? {}), 'marks_obtained': marks},
    };
  }

  void updateTotal(String studentId, String total) {
    state = {
      ...state,
      studentId: {...(state[studentId] ?? {}), 'total_marks': total},
    };
  }

  void updateSubject(String studentId, String subject) {
    state = {
      ...state,
      studentId: {...(state[studentId] ?? {}), 'subject': subject},
    };
  }
}

final resultsDraftProvider =
    StateNotifierProvider<ResultsMarksNotifier, Map<String, Map<String, dynamic>>>(
  (ref) => ResultsMarksNotifier(),
);

// ---------------------------------------------------------------------------
// Exam creation notifier
// ---------------------------------------------------------------------------
class ExamCreationNotifier extends StateNotifier<AsyncValue<void>> {
  ExamCreationNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<String?> createExam({
    required String name,
    required String term,
    required String classId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      final response = await client.from('exams').insert({
        'name': name,
        'term': term,
        'class_id': classId,
        'is_published': false,
      }).select('id').single();
      state = const AsyncValue.data(null);
      return response['id'] as String?;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final examCreationProvider =
    StateNotifierProvider<ExamCreationNotifier, AsyncValue<void>>(
  (ref) => ExamCreationNotifier(ref),
);

// ---------------------------------------------------------------------------
// Save / Publish results
// ---------------------------------------------------------------------------
class ResultsSaveNotifier extends StateNotifier<AsyncValue<void>> {
  ResultsSaveNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> saveResults({
    required String examId,
    required Map<String, Map<String, dynamic>> marksMap,
  }) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      final rows = marksMap.entries
          .where((e) => (e.value['marks_obtained'] as String).isNotEmpty)
          .map((e) {
        final marks = double.tryParse(e.value['marks_obtained'] as String) ?? 0;
        final total = double.tryParse(e.value['total_marks'] as String) ?? 100;
        return {
          'exam_id': examId,
          'student_id': e.key,
          'subject': e.value['subject'],
          'marks_obtained': marks,
          'total_marks': total,
        };
      }).toList();

      if (rows.isEmpty) throw Exception('No marks entered.');

      await client.from('results').upsert(
            rows,
            onConflict: 'exam_id,student_id,subject',
          );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> publishResults(String examId) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.functions.invoke('publish_results', body: {'exam_id': examId});
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final resultsSaveProvider =
    StateNotifierProvider<ResultsSaveNotifier, AsyncValue<void>>(
  (ref) => ResultsSaveNotifier(ref),
);

// ---------------------------------------------------------------------------
// Student's own published results
// ---------------------------------------------------------------------------
final studentResultsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];

  // Get student id
  final studentRow = await client
      .from('students')
      .select('id, users!inner(auth_user_id)')
      .eq('users.auth_user_id', userId)
      .maybeSingle();

  if (studentRow == null) return [];
  final studentId = studentRow['id'] as String;

  final response = await client
      .from('results')
      .select('id, subject, marks_obtained, total_marks, percentage, grade, exams(id, name, term, class_id, is_published)')
      .eq('student_id', studentId);

  // Filter published only
  return List<Map<String, dynamic>>.from(response)
      .where((r) => r['exams'] != null && r['exams']['is_published'] == true)
      .toList();
});

// Re-export so results_page can access teacherClassesProvider
export '../attendance/attendance_provider.dart' show teacherClassesProvider, classStudentsProvider;
