import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';

/// Provider for loading all active teachers (for class teacher or timetable slot instructor assignment).
final allTeachersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('teachers')
      .select('id, teacher_code, users(id, full_name)')
      .is_('deleted_at', null)
      .order('teacher_code');
  return List<Map<String, dynamic>>.from(response);
});

/// StateNotifier to manage classes list
class ClassManagementNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  ClassManagementNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetchClasses();
  }

  final Ref _ref;

  Future<void> fetchClasses() async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      final response = await client
          .from('classes')
          .select('*, users(id, full_name)')
          .is_('deleted_at', null)
          .order('name');
      state = AsyncValue.data(List<Map<String, dynamic>>.from(response));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createClass({
    required String name,
    required String section,
    required String gradeLevel,
    required String? teacherId,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('classes').insert({
      'name': name,
      'section': section,
      'grade_level': gradeLevel,
      'teacher_id': teacherId,
    });
    await fetchClasses();
  }

  Future<void> updateClass({
    required String classId,
    required String name,
    required String section,
    required String gradeLevel,
    required String? teacherId,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('classes').update({
      'name': name,
      'section': section,
      'grade_level': gradeLevel,
      'teacher_id': teacherId,
    }).eq('id', classId);
    await fetchClasses();
  }

  Future<void> deleteClass(String classId) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('classes').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', classId);
    await fetchClasses();
  }
}

final classManagementProvider =
    StateNotifierProvider<ClassManagementNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => ClassManagementNotifier(ref),
);

/// StateNotifier to manage timetable slots
class TimetableNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  TimetableNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetchTimetable();
  }

  final Ref _ref;

  Future<void> fetchTimetable() async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      final response = await client
          .from('timetable')
          .select('*, classes(id, name, section), teachers(id, teacher_code, users(id, full_name))')
          .order('day')
          .order('start_time');
      state = AsyncValue.data(List<Map<String, dynamic>>.from(response));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addSlot({
    required String classId,
    required String? teacherId,
    required String subject,
    required String day,
    required String startTime,
    required String endTime,
    required String room,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('timetable').insert({
      'class_id': classId,
      'teacher_id': teacherId,
      'subject': subject,
      'day': day,
      'start_time': startTime,
      'end_time': endTime,
      'room': room,
    });
    await fetchTimetable();
  }

  Future<void> updateSlot({
    required String slotId,
    required String classId,
    required String? teacherId,
    required String subject,
    required String day,
    required String startTime,
    required String endTime,
    required String room,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('timetable').update({
      'class_id': classId,
      'teacher_id': teacherId,
      'subject': subject,
      'day': day,
      'start_time': startTime,
      'end_time': endTime,
      'room': room,
    }).eq('id', slotId);
    await fetchTimetable();
  }

  Future<void> deleteSlot(String slotId) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('timetable').delete().eq('id', slotId);
    await fetchTimetable();
  }
}

final timetableProvider =
    StateNotifierProvider<TimetableNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => TimetableNotifier(ref),
);
