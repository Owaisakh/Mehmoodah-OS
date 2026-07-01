import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Reusable high-fidelity Error Boundary / Error State Widget
class AppErrorState extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;

  const AppErrorState({
    super.key,
    required this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.dangerRed.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.dangerRed.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.dangerRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something Went Wrong',
              style: AppTextStyles.heading3.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                errorMessage,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A global Flutter Error boundary wrapper widget to catch widget rendering failures
class AppErrorBoundary extends StatefulWidget {
  final Widget child;

  const AppErrorBoundary({super.key, required this.child});

  @override
  State<AppErrorBoundary> createState() => _AppErrorBoundaryState();
}

class _AppErrorBoundaryState extends State<AppErrorBoundary> {
  Object? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: AppErrorState(
          errorMessage: _error.toString(),
          onRetry: () {
            setState(() {
              _error = null;
            });
          },
        ),
      );
    }

    // Capture flutter framework errors within this tree
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Scaffold(
        body: AppErrorState(
          errorMessage: details.exceptionAsString(),
        ),
      );
    };

    return widget.child;
  }
}
