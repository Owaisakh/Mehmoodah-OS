import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';

/// Aggregated stats for the Admin Dashboard
class AdminDashboardStats {
  final int totalStudents;
  final int totalTeachers;
  final int totalClasses;

  const AdminDashboardStats({
    required this.totalStudents,
    required this.totalTeachers,
    required this.totalClasses,
  });
}

/// Provider to fetch Admin stats
final adminStatsProvider = FutureProvider<AdminDashboardStats>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  // We perform three count queries in parallel
  final responses = await Future.wait([
    client.from('students').select('id').is_('deleted_at', null),
    client.from('teachers').select('id').is_('deleted_at', null),
    client.from('classes').select('id').is_('deleted_at', null),
  ]);

  return AdminDashboardStats(
    totalStudents: (responses[0] as List).length,
    totalTeachers: (responses[1] as List).length,
    totalClasses: (responses[2] as List).length,
  );
});

/// StateNotifier to manage announcements list and creation.
class AnnouncementsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  AnnouncementsNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetchAnnouncements();
  }

  final Ref _ref;

  Future<void> fetchAnnouncements() async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      final response = await client
          .from('announcements')
          .select('*, users(full_name)')
          .order('created_at', descending: true);
      
      state = AsyncValue.data(List<Map<String, dynamic>>.from(response));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Create a new announcement
  Future<void> createAnnouncement({
    required String title,
    required String content,
    required String audience,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Get current public user's primary key ID
    final userProfile = await client
        .from('users')
        .select('id')
        .eq('auth_user_id', userId)
        .single();
    final profileId = userProfile['id'];

    await client.from('announcements').insert({
      'title': title,
      'content': content,
      'audience': audience,
      'created_by': profileId,
    });

    await fetchAnnouncements();
  }
}

final announcementsProvider =
    StateNotifierProvider<AnnouncementsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => AnnouncementsNotifier(ref),
);
