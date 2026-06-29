import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';

/// StateNotifier to manage the list of active teachers and their associated classes.
class TeachersNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  TeachersNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetchTeachers();
  }

  final Ref _ref;

  Future<void> fetchTeachers() async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      // Fetch teachers with users profile and class_teachers (to show assigned classes)
      final response = await client
          .from('teachers')
          .select('*, users(id, full_name, email, phone), class_teachers(classes(id, name, section))')
          .is_('deleted_at', null)
          .order('created_at', ascending: false);

      state = AsyncValue.data(List<Map<String, dynamic>>.from(response));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Create a new teacher by calling the Supabase Edge Function
  Future<void> createTeacher({
    required String fullName,
    required String email,
    required String password,
    required String subject,
    required String joiningDate,
    required String teacherCode,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final response = await client.functions.invoke(
      'create_teacher',
      body: {
        'full_name': fullName,
        'email': email,
        'password': password,
        'subject': subject,
        'joining_date': joiningDate,
        'teacher_code': teacherCode,
      },
    );

    if (response.status != 200 || (response.data is Map && response.data['error'] != null)) {
      final errorMsg = response.data is Map ? response.data['error'] : 'Failed to create teacher';
      throw Exception(errorMsg);
    }

    // Refresh the list
    await fetchTeachers();
  }

  /// Edit existing teacher details
  Future<void> updateTeacher({
    required String teacherId,
    required String userId,
    required String fullName,
    required String subject,
    required String joiningDate,
    required String teacherCode,
  }) async {
    final client = _ref.read(supabaseClientProvider);

    // 1. Update users profile full name
    await client.from('users').update({
      'full_name': fullName,
    }).eq('id', userId);

    // 2. Update teacher fields
    await client.from('teachers').update({
      'subject': subject,
      'joining_date': joiningDate,
      'teacher_code': teacherCode,
    }).eq('id', teacherId);

    // Refresh the list
    await fetchTeachers();
  }

  /// Assign teacher to classes (junction table class_teachers)
  Future<void> assignClasses({
    required String teacherId,
    required List<String> classIds,
  }) async {
    final client = _ref.read(supabaseClientProvider);

    // Remove existing mappings
    await client.from('class_teachers').delete().eq('teacher_id', teacherId);

    // Insert new mappings
    if (classIds.isNotEmpty) {
      final inserts = classIds.map((cid) => {
        'teacher_id': teacherId,
        'class_id': cid,
      }).toList();
      await client.from('class_teachers').insert(inserts);
    }

    // Refresh the list
    await fetchTeachers();
  }

  /// Soft delete teacher
  Future<void> deleteTeacher(String teacherId) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('teachers').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', teacherId);

    // Refresh the list
    await fetchTeachers();
  }
}

final teachersProvider =
    StateNotifierProvider<TeachersNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => TeachersNotifier(ref),
);
