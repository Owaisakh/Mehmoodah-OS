import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../modules/auth/auth_notifier.dart';

class SidebarItem {
  final String title;
  final IconData icon;
  final String route;

  const SidebarItem({
    required this.title,
    required this.icon,
    required this.route,
  });
}

class DashboardShell extends ConsumerStatefulWidget {
  final Widget child;
  final String title;

  const DashboardShell({
    super.key,
    required this.child,
    required this.title,
  });

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  bool _isCollapsed = false;

  List<SidebarItem> _getMenuItems(String role) {
    if (role == 'admin') {
      return const [
        SidebarItem(title: 'Dashboard', icon: Icons.dashboard_rounded, route: AppRoutes.adminDashboard),
        SidebarItem(title: 'Students', icon: Icons.people_rounded, route: AppRoutes.adminStudents),
        SidebarItem(title: 'Teachers', icon: Icons.school_rounded, route: AppRoutes.adminTeachers),
        SidebarItem(title: 'Timetable', icon: Icons.calendar_today_rounded, route: AppRoutes.adminTimetable),
        SidebarItem(title: 'Reports', icon: Icons.analytics_rounded, route: AppRoutes.adminReports),
        SidebarItem(title: 'Profile', icon: Icons.person_rounded, route: AppRoutes.adminProfile),
      ];
    } else if (role == 'teacher') {
      return const [
        SidebarItem(title: 'Dashboard', icon: Icons.dashboard_rounded, route: AppRoutes.teacherDashboard),
        SidebarItem(title: 'Attendance', icon: Icons.check_circle_rounded, route: AppRoutes.teacherAttendance),
        SidebarItem(title: 'Results', icon: Icons.grade_rounded, route: AppRoutes.teacherResults),
        SidebarItem(title: 'Assignments', icon: Icons.assignment_rounded, route: AppRoutes.teacherAssignments),
        SidebarItem(title: 'Profile', icon: Icons.person_rounded, route: AppRoutes.teacherProfile),
      ];
    } else {
      return const [
        SidebarItem(title: 'Dashboard', icon: Icons.dashboard_rounded, route: AppRoutes.studentDashboard),
        SidebarItem(title: 'Attendance', icon: Icons.check_circle_outline_rounded, route: AppRoutes.studentAttendance),
        SidebarItem(title: 'Results', icon: Icons.grade_outlined, route: AppRoutes.studentResults),
        SidebarItem(title: 'Homework', icon: Icons.homework_rounded, route: AppRoutes.studentHomework),
        SidebarItem(title: 'Timetable', icon: Icons.calendar_month_rounded, route: AppRoutes.studentTimetable),
        SidebarItem(title: 'Profile', icon: Icons.person_rounded, route: AppRoutes.studentProfile),
      ];
    }
  }

  // Choose the 4 main items to display on mobile bottom nav
  List<SidebarItem> _getMobileNavItems(String role, List<SidebarItem> allItems) {
    if (role == 'admin') {
      return [
        allItems[0], // Dashboard
        allItems[1], // Students
        allItems[2], // Teachers
        allItems[5], // Profile
      ];
    } else if (role == 'teacher') {
      return [
        allItems[0], // Dashboard
        allItems[1], // Attendance
        allItems[2], // Results
        allItems[4], // Profile
      ];
    } else {
      return [
        allItems[0], // Dashboard
        allItems[1], // Attendance
        allItems[2], // Results
        allItems[5], // Profile
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(userRoleProvider);
    final role = roleAsync.value ?? 'student';
    final email = ref.watch(supabaseClientProvider).auth.currentUser?.email ?? '';

    final menuItems = _getMenuItems(role);
    final mobileNavItems = _getMobileNavItems(role, menuItems);
    
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    
    // Check if current route is part of mobile bottom nav
    int currentMobileNavIndex = -1;
    for (int i = 0; i < mobileNavItems.length; i++) {
      if (currentRoute == mobileNavItems[i].route) {
        currentMobileNavIndex = i;
        break;
      }
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Sidebar
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isCollapsed ? 80 : 260,
              color: isDark ? AppColors.darkSurface : AppColors.primaryDeepNavy,
              child: Column(
                children: [
                  // Logo / Header
                  Container(
                    height: 70,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.primaryDeepNavy.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.auto_stories_rounded,
                          color: AppColors.accentSoftBlue,
                          size: 32,
                        ),
                        if (!_isCollapsed) ...[
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Mehmoodah',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Menu Items
                  Expanded(
                    child: ListView.builder(
                      itemCount: menuItems.length,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemBuilder: (context, index) {
                        final item = menuItems[index];
                        final isActive = currentRoute == item.route;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Tooltip(
                            message: _isCollapsed ? item.title : '',
                            child: ListTile(
                              onTap: () => context.go(item.route),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              selected: isActive,
                              selectedTileColor: isDark
                                  ? AppColors.darkBorder
                                  : Colors.white.withOpacity(0.1),
                              leading: Icon(
                                item.icon,
                                color: isActive
                                    ? AppColors.accentSoftBlue
                                    : (isDark ? AppColors.textMuted : Colors.white.withOpacity(0.7)),
                              ),
                              title: _isCollapsed
                                  ? null
                                  : Text(
                                      item.title,
                                      style: TextStyle(
                                        color: isActive
                                            ? Colors.white
                                            : (isDark ? AppColors.textSecondary : Colors.white.withOpacity(0.8)),
                                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Collapse Button at the bottom
                  Divider(
                    color: isDark ? AppColors.darkBorder : Colors.white.withOpacity(0.1),
                  ),
                  ListTile(
                    onTap: () {
                      setState(() {
                        _isCollapsed = !_isCollapsed;
                      });
                    },
                    leading: Icon(
                      _isCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                      color: isDark ? AppColors.textMuted : Colors.white.withOpacity(0.7),
                    ),
                    title: _isCollapsed
                        ? null
                        : Text(
                            'Collapse Sidebar',
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondary : Colors.white.withOpacity(0.8),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            
            // Main content
            Expanded(
              child: Container(
                color: isDark ? AppColors.darkBackground : AppColors.backgroundLight,
                child: Column(
                  children: [
                    // Topbar
                    Container(
                      height: 70,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.surfaceWhite,
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                            width: 1,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          
                          // Theme mode switcher
                          IconButton(
                            onPressed: () {
                              ref.read(themeModeProvider.notifier).update(
                                    (state) => state == ThemeMode.light
                                        ? ThemeMode.dark
                                        : ThemeMode.light,
                                  );
                            },
                            icon: Icon(
                              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              color: isDark ? Colors.amber : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // User badge + profile dropdown
                          PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'logout') {
                                ref.read(authNotifierProvider.notifier).signOut();
                              } else if (val == 'profile') {
                                final profileRoute = role == 'admin' 
                                  ? AppRoutes.adminProfile 
                                  : (role == 'teacher' ? AppRoutes.teacherProfile : AppRoutes.studentProfile);
                                context.go(profileRoute);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                enabled: false,
                                child: Text(
                                  email,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'profile',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_outline_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text('Profile Settings'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
                                    SizedBox(width: 8),
                                    Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                            ],
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.accentSoftBlue.withOpacity(0.2),
                                  child: Text(
                                    role[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.accentSoftBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: role == 'admin'
                                        ? AppColors.primaryDeepNavy.withOpacity(0.1)
                                        : (role == 'teacher' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: role == 'admin'
                                          ? AppColors.primaryDeepNavy.withOpacity(0.2)
                                          : (role == 'teacher' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2)),
                                    ),
                                  ),
                                  child: Text(
                                    role.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: role == 'admin'
                                          ? AppColors.primaryDeepNavy
                                          : (role == 'teacher' ? Colors.green : Colors.orange),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Body child
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile / Tablet Layout
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              onPressed: () {
                ref.read(themeModeProvider.notifier).update(
                      (state) => state == ThemeMode.light
                          ? ThemeMode.dark
                          : ThemeMode.light,
                    );
              },
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              ),
            ),
          ],
        ),
        drawer: Drawer(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.primaryDeepNavy,
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    role[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primaryDeepNavy,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                accountName: Text(
                  role.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(email),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: menuItems.length,
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    final isActive = currentRoute == item.route;

                    return ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        context.go(item.route);
                      },
                      selected: isActive,
                      leading: Icon(item.icon),
                      title: Text(item.title),
                    );
                  },
                ),
              ),
              const Divider(),
              ListTile(
                onTap: () {
                  Navigator.pop(context);
                  ref.read(authNotifierProvider.notifier).signOut();
                },
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        body: Container(
          color: isDark ? AppColors.darkBackground : AppColors.backgroundLight,
          child: widget.child,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentMobileNavIndex == -1 ? 0 : currentMobileNavIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.accentSoftBlue,
          unselectedItemColor: isDark ? AppColors.textMuted : AppColors.textSecondary,
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surfaceWhite,
          onTap: (index) {
            context.go(mobileNavItems[index].route);
          },
          items: mobileNavItems.map((item) {
            return BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.title,
            );
          }).toList(),
        ),
      );
    }
  }
}
