import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';

/// The user profile state holding basic info and role-specific details
class UserProfileData {
  final Map<String, dynamic> userFields;
  final Map<String, dynamic>? roleSpecificFields;
  final Map<String, dynamic>? classFields; // for students

  const UserProfileData({
    required this.userFields,
    this.roleSpecificFields,
    this.classFields,
  });
}

/// Provider to fetch user profile details
final userProfileProvider = FutureProvider<UserProfileData>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw Exception('User not authenticated');

  // Fetch basic user profile
  final userRow = await client
      .from('users')
      .select('*')
      .eq('auth_user_id', userId)
      .single();

  final role = userRow['role'] as String;
  final internalUserId = userRow['id'] as String;

  Map<String, dynamic>? roleSpecific;
  Map<String, dynamic>? classInfo;

  if (role == 'student') {
    final studentRow = await client
        .from('students')
        .select('*, classes(id, name, section)')
        .eq('user_id', internalUserId)
        .maybeSingle();

    if (studentRow != null) {
      roleSpecific = Map<String, dynamic>.from(studentRow);
      classInfo = studentRow['classes'] != null
          ? Map<String, dynamic>.from(studentRow['classes'] as Map)
          : null;
    }
  } else if (role == 'teacher') {
    final teacherRow = await client
        .from('teachers')
        .select('*')
        .eq('user_id', internalUserId)
        .maybeSingle();

    if (teacherRow != null) {
      roleSpecific = Map<String, dynamic>.from(teacherRow);
    }
  }

  return UserProfileData(
    userFields: Map<String, dynamic>.from(userRow),
    roleSpecificFields: roleSpecific,
    classFields: classInfo,
  );
});

/// State notifier to manage profile update actions
class ProfileActionNotifier extends StateNotifier<AsyncValue<void>> {
  ProfileActionNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  /// Update user profile details
  Future<void> updateProfile({
    required String fullName,
    required String? phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await client.from('users').update({
        'full_name': fullName,
        'phone': phone,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('auth_user_id', userId);

      // Invalidate profile to trigger reload
      _ref.invalidate(userProfileProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update user password
  Future<void> updatePassword(String newPassword) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final profileActionProvider =
    StateNotifierProvider<ProfileActionNotifier, AsyncValue<void>>(
  (ref) => ProfileActionNotifier(ref),
);
