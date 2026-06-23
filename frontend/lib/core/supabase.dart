import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for the global Supabase client instance.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Stream provider for auth state updates.
final supabaseAuthStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// Provider indicating whether the user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(supabaseAuthStateProvider).value;
  return authState?.session != null;
});

/// Provider for the current user's profile metadata and role.
/// In a fully realized feature, this would fetch from public.users.
final userRoleProvider = FutureProvider<String?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  try {
    final response = await client
        .from('users')
        .select('role')
        .eq('auth_user_id', userId)
        .maybeSingle();
    return response?['role'] as String?;
  } catch (_) {
    return null;
  }
});
