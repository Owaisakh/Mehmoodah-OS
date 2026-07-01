import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../shared/widgets/dashboard_shell.dart';
import 'profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final actionState = ref.watch(profileActionProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return DashboardShell(
      title: 'Profile Settings',
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userProfileProvider);
        },
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading profile: $err')),
          data: (data) {
            if (!_initialized) {
              _nameController.text = data.userFields['full_name'] ?? '';
              _phoneController.text = data.userFields['phone'] ?? '';
              _initialized = true;
            }

            final email = data.userFields['email'] ?? '';
            final role = data.userFields['role'] ?? 'student';
            final fullName = data.userFields['full_name'] ?? '';

            // Extract role metadata
            String codeLabel = 'Code';
            String codeVal = '--';
            List<Widget> metadataWidgets = [];

            if (role == 'student' && data.roleSpecificFields != null) {
              codeLabel = 'Student Code';
              codeVal = data.roleSpecificFields!['student_code'] ?? '--';
              final roll = data.roleSpecificFields!['roll_number'] ?? '--';
              final cls = data.classFields != null ? '${data.classFields!['name']} - Sec ${data.classFields!['section']}' : 'Unassigned';
              final adm = data.roleSpecificFields!['admission_date'] ?? '--';

              metadataWidgets = [
                _buildMetaRow(Icons.pin_outlined, 'Roll Number', roll, isDark),
                _buildMetaRow(Icons.class_rounded, 'Class', cls, isDark),
                _buildMetaRow(Icons.date_range_rounded, 'Admission Date', adm, isDark),
              ];
            } else if (role == 'teacher' && data.roleSpecificFields != null) {
              codeLabel = 'Teacher Code';
              codeVal = data.roleSpecificFields!['teacher_code'] ?? '--';
              final subject = data.roleSpecificFields!['subject'] ?? '--';
              final joinDate = data.roleSpecificFields!['joining_date'] ?? '--';

              metadataWidgets = [
                _buildMetaRow(Icons.subject_rounded, 'Primary Subject', subject, isDark),
                _buildMetaRow(Icons.date_range_rounded, 'Joining Date', joinDate, isDark),
              ];
            } else if (role == 'admin') {
              codeLabel = 'Admin Privileges';
              codeVal = 'Full Access';
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  
                  final profileInfoCard = _buildProfileInfoCard(
                    fullName,
                    email,
                    role,
                    codeLabel,
                    codeVal,
                    metadataWidgets,
                    isDark,
                  );

                  final formsColumn = Column(
                    children: [
                      _buildThemeSettingsCard(isDark),
                      const SizedBox(height: 24),
                      _buildEditProfileCard(actionState.isLoading, isDark),
                      const SizedBox(height: 24),
                      _buildChangePasswordCard(actionState.isLoading, isDark),
                    ],
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: profileInfoCard),
                        const SizedBox(width: 24),
                        Expanded(flex: 3, child: formsColumn),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        profileInfoCard,
                        const SizedBox(height: 24),
                        formsColumn,
                      ],
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // Left Column Card: Overview and Role Info
  Widget _buildProfileInfoCard(
    String name,
    String email,
    String role,
    String codeLabel,
    String codeVal,
    List<Widget> metaItems,
    bool isDark,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Big Avatar
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.accentSoftBlue.withOpacity(0.12),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.accentSoftBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 36,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              name,
              style: AppTextStyles.heading2.copyWith(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: role == 'admin'
                    ? AppColors.primaryDeepNavy.withOpacity(0.1)
                    : (role == 'teacher' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: role == 'admin'
                      ? AppColors.primaryDeepNavy.withOpacity(0.2)
                      : (role == 'teacher' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2)),
                ),
              ),
              child: Text(
                role.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: role == 'admin'
                      ? AppColors.primaryDeepNavy
                      : (role == 'teacher' ? Colors.green : Colors.orange),
                ),
              ),
            ),
            const Divider(height: 36),
            _buildMetaRow(Icons.badge_outlined, codeLabel, codeVal, isDark),
            ...metaItems,
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accentSoftBlue),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Right Column: Edit Profile details card
  Widget _buildEditProfileCard(bool isLoading, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _profileFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Profile Details',
                style: AppTextStyles.heading3.copyWith(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (_profileFormKey.currentState?.validate() ?? false) {
                            try {
                              await ref.read(profileActionProvider.notifier).updateProfile(
                                    fullName: _nameController.text.trim(),
                                    phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
                                  );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profile updated successfully'),
                                    backgroundColor: AppColors.successGreen,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error updating profile: $e')),
                                );
                              }
                            }
                          }
                        },
                  icon: isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save Profile Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Right Column: Change Password Card
  Widget _buildChangePasswordCard(bool isLoading, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _passwordFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change Password',
                style: AppTextStyles.heading3.copyWith(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter a password';
                  if (val.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
                validator: (val) {
                  if (val != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (_passwordFormKey.currentState?.validate() ?? false) {
                            try {
                              await ref.read(profileActionProvider.notifier).updatePassword(
                                    _passwordController.text,
                                  );
                              _passwordController.clear();
                              _confirmPasswordController.clear();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Password updated successfully'),
                                    backgroundColor: AppColors.successGreen,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error changing password: $e')),
                                );
                              }
                            }
                          }
                        },
                  icon: const Icon(Icons.vpn_key_rounded),
                  label: const Text('Update Password'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDeepNavy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Right Column: Theme selection Settings
  Widget _buildThemeSettingsCard(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme Preference',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isDark ? 'Dark Mode Active' : 'Light Mode Active',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
            Switch(
              value: isDark,
              activeColor: AppColors.accentSoftBlue,
              onChanged: (val) {
                ref.read(themeModeProvider.notifier).update(
                      (state) => val ? ThemeMode.dark : ThemeMode.light,
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}
