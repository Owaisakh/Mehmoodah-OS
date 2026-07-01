import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';

/// Notifier to fetch aggregated report data from the Edge Function or Database
class ReportsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  ReportsNotifier(this._ref) : super(const AsyncValue.data([]));

  final Ref _ref;

  Future<void> fetchReport({
    required String reportType,
    required String? classId,
    required String fromDate,
    required String toDate,
  }) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      
      // Invoke generate_report edge function
      final response = await client.functions.invoke(
        'generate_report',
        body: {
          'report_type': reportType,
          if (classId != null && classId.isNotEmpty) 'class_id': classId,
          'from_date': fromDate,
          'to_date': toDate,
        },
      );

      if (response.status != 200 || (response.data is Map && response.data['error'] != null)) {
        final errorMsg = response.data is Map ? response.data['error'] : 'Failed to generate report';
        throw Exception(errorMsg);
      }

      final dataList = response.data['data'] as List?;
      final list = dataList != null
          ? List<Map<String, dynamic>>.from(dataList.map((x) => Map<String, dynamic>.from(x as Map)))
          : <Map<String, dynamic>>[];

      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final reportsProvider =
    StateNotifierProvider<ReportsNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => ReportsNotifier(ref),
);
