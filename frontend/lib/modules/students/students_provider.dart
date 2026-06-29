import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';

/// Provider for loading all active classes (used in filters & dropdowns).
final classesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('classes')
      .select('id, name, section, grade_level')
      .is_('deleted_at', null)
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});

/// StateNotifier to manage the list of active students.
class StudentsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  StudentsNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetchStudents();
  }

  final Ref _ref;

  Future<void> fetchStudents() async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      // Fetch students with joined users profile and classes details
      final response = await client
          .from('students')
          .select('*, users(id, full_name, email, phone), classes(id, name, section)')
          .is_('deleted_at', null)
          .order('created_at', ascending: false);
      
      state = AsyncValue.data(List<Map<String, dynamic>>.from(response));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Create a new student by calling the Supabase Edge Function
  Future<void> createStudent({
    required String fullName,
    required String email,
    required String password,
    required String rollNumber,
    required String classId,
    required String dob,
    required String guardianName,
    required String guardianPhone,
    required String admissionDate,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final response = await client.functions.invoke(
      'create_student',
      body: {
        'full_name': fullName,
        'email': email,
        'password': password,
        'roll_number': rollNumber,
        'class_id': classId,
        'dob': dob,
        'guardian_name': guardianName,
        'guardian_phone': guardianPhone,
        'admission_date': admissionDate,
      },
    );

    if (response.status != 200 || (response.data is Map && response.data['error'] != null)) {
      final errorMsg = response.data is Map ? response.data['error'] : 'Failed to create student';
      throw Exception(errorMsg);
    }

    // Refresh the list
    await fetchStudents();
  }

  /// Edit existing student record (updates users and students tables)
  Future<void> updateStudent({
    required String studentId,
    required String userId,
    required String fullName,
    required String rollNumber,
    required String classId,
    required String dob,
    required String guardianName,
    required String guardianPhone,
    required String admissionDate,
    required String status,
  }) async {
    final client = _ref.read(supabaseClientProvider);

    // 1. Update user profile name
    await client.from('users').update({
      'full_name': fullName,
    }).eq('id', userId);

    // 2. Update student specific fields
    await client.from('students').update({
      'roll_number': rollNumber,
      'class_id': classId,
      'dob': dob,
      'guardian_name': guardianName,
      'guardian_phone': guardianPhone,
      'admission_date': admissionDate,
      'status': status,
    }).eq('id', studentId);

    // Refresh the list
    await fetchStudents();
  }

  /// Soft delete student by setting deleted_at = NOW()
  Future<void> deleteStudent(String studentId) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('students').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', studentId);

    // Refresh the list
    await fetchStudents();
  }
}

final studentsProvider =
    StateNotifierProvider<StudentsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => StudentsNotifier(ref),
);
