# 📋 PROJECT STATE — Mehmoodah Academy OS

> **INSTRUCTIONS FOR AI**: Read this file first before doing anything. It contains the full context of what has been built, what is remaining, and the exact rules to follow when continuing work.

---

## 🏫 Project Overview

**Name**: Mehmoodah Academy School Operating System (V1)  
**Stack**: Flutter Web (frontend) + Supabase (backend)  
**Monorepo**:
- `/frontend` — Flutter Web app (Riverpod + GoRouter + Supabase Flutter SDK)
- `/backend` — Supabase migrations, Edge Functions (Deno/TypeScript), storage config

---

## ✅ COMPLETED WORK

### Backend (100% done)
| File | Status |
|------|--------|
| `backend/database/migrations/00001_initial_schema.sql` | ✅ Complete — all 10 tables, RLS policies, triggers, soft-delete |
| `backend/supabase/config.toml` | ✅ Complete — 5 storage buckets configured |
| `backend/functions/create_student/index.ts` | ✅ Complete — auth user + student_code + DB insert |
| `backend/functions/create_teacher/index.ts` | ✅ Complete — auth user + teacher_code + DB insert |
| `backend/functions/publish_results/index.ts` | ✅ Complete — grade calculation + exam publish |
| `backend/functions/generate_report/index.ts` | ✅ Complete — attendance/results aggregation |
| `backend/functions/upload_assignment/index.ts` | ✅ Complete — file validation + storage upload + DB insert |

### Frontend Core (100% done)
| File | Status |
|------|--------|
| `frontend/pubspec.yaml` | ✅ Complete — all dependencies declared |
| `frontend/lib/main.dart` | ✅ Complete — Supabase init, ProviderScope, dynamic ThemeMode |
| `frontend/lib/core/router.dart` | ✅ Complete — all routes declared + role-based guards |
| `frontend/lib/core/supabase.dart` | ✅ Complete — client, auth stream, role provider |
| `frontend/lib/core/theme.dart` | ✅ Complete — AppColors, AppTextStyles, light/dark themes, themeModeProvider |
| `frontend/lib/modules/auth/auth_notifier.dart` | ✅ Complete — signIn, signOut, resetPassword |
| `frontend/lib/shared/widgets/dashboard_shell.dart` | ✅ Complete — collapsible sidebar (desktop), bottom nav + drawer (mobile), topbar, role menus, theme toggle, user profile popup |

### Phase 3 — Admin Providers (100% done)
| File | Status |
|------|--------|
| `frontend/lib/modules/students/students_provider.dart` | ✅ Complete — classesProvider + studentsProvider; CRUD + Edge Function calls + soft-delete |
| `frontend/lib/modules/teachers/teachers_provider.dart` | ✅ Complete — teachersProvider; CRUD + Edge Function calls + class assignments + soft-delete |
| `frontend/lib/modules/dashboard/admin_dashboard_provider.dart` | ✅ Complete — adminStatsProvider (counts) + announcementsProvider (feed + create) |

### Phase 4 — Timetable Providers (100% done)
| File | Status |
|------|--------|
| `frontend/lib/modules/timetable/timetable_provider.dart` | ✅ Complete — classManagementProvider (CRUD + soft-delete) + timetableProvider (slots CRUD) + allTeachersProvider |

### Phase 5 — Teacher Operations (100% done)
| File | Status |
|------|--------|
| `frontend/lib/modules/attendance/attendance_provider.dart` | ✅ Complete — teacherClassesProvider, classStudentsProvider, existingAttendanceProvider, AttendanceDraft StateNotifier, AttendanceSubmit, studentMonthlyAttendance |
| `frontend/lib/modules/attendance/attendance_page.dart` | ✅ Complete — role-aware: teacher roster view (mark P/A/Late/Leave, bulk mark, upsert), student monthly calendar (colour-coded, % stats) |
| `frontend/lib/modules/results/results_provider.dart` | ✅ Complete — teacherExamsProvider, ExamCreation, ResultsDraft, ResultsSave + publishResults edge call, studentResultsProvider |
| `frontend/lib/modules/results/results_page.dart` | ✅ Complete — role-aware: teacher marks table + save/publish, student grouped published results with grade chips |
| `frontend/lib/modules/assignments/assignments_provider.dart` | ✅ Complete — teacherAssignments, assignmentSubmissions, AssignmentCreation, SubmissionGrade, studentAssignments, studentSubmissions, SubmissionNotifier |
| `frontend/lib/modules/assignments/assignments_page.dart` | ✅ Complete — role-aware: teacher tab (list + grade submissions bottom sheet), student homework cards (submit link dialog, grade/feedback display) |
| `frontend/lib/modules/dashboard/teacher_dashboard.dart` | ✅ Complete — today's attendance summary bar, quick-action gradient cards, my-classes chips, pending-submissions list |

### Frontend Screens
| File | Status |
|------|--------|
| `frontend/lib/modules/auth/login_page.dart` | ✅ Complete — split-screen layout, form validation, loading state, forgot password dialog |
| `frontend/lib/modules/dashboard/admin_dashboard.dart` | ✅ Complete — stat cards, quick action buttons, announcements feed + create dialog |
| `frontend/lib/modules/dashboard/teacher_dashboard.dart` | ✅ Complete — today's attendance summary, quick actions, class chips, pending grades list |
| `frontend/lib/modules/dashboard/student_dashboard.dart` | ❌ Placeholder only |
| `frontend/lib/modules/students/students_page.dart` | ✅ Complete — searchable table/cards, class filter, add/edit/delete dialogs, Edge Function registration |
| `frontend/lib/modules/teachers/teachers_page.dart` | ✅ Complete — card grid, add/edit/delete dialogs, multi-class assignment modal |
| `frontend/lib/modules/attendance/attendance_page.dart` | ✅ Complete — role-aware: teacher roster + student calendar |
| `frontend/lib/modules/results/results_page.dart` | ✅ Complete — role-aware: teacher marks entry + student published results |
| `frontend/lib/modules/assignments/assignments_page.dart` | ✅ Complete — role-aware: teacher create/grade + student submit/view |
| `frontend/lib/modules/timetable/timetable_page.dart` | ✅ Complete — tabbed page: Classes management table + Weekly timetable with real-time overlap detection |
| `frontend/lib/modules/reports/reports_page.dart` | ❌ Placeholder only |
| `frontend/lib/modules/profile/profile_page.dart` | ❌ Placeholder only |

---

## ❌ REMAINING WORK (in order)

### ~~Phase 5 — Teacher Operations~~ ✅ COMPLETE

### Phase 6 — Student Portal
- `student_dashboard.dart` — attendance % widget, announcements feed, upcoming homework alerts
- `attendance_page.dart` (student view) — read-only monthly attendance calendar
- `results_page.dart` (student view) — published exam results with grade chips
- `assignments_page.dart` (student view) — homework list, file submission uploader

### Phase 7 — System Utilities
- Announcements module (create widget for admin, read-only feed on dashboards)
- `reports_page.dart` — charts (attendance rate, grade distribution), CSV/PDF export actions
- `profile_page.dart` — user info display, password reset trigger, theme preference toggle

### Phase 8 — Polish
- Skeleton loading states for all data tables and lists
- Empty state illustrations for zero-data screens
- Mobile layout testing and responsive alignment fixes
- Error boundary widgets

---

## 🏗️ Architecture Rules (DO NOT break these)

1. **All screens must be wrapped in `DashboardShell`** — pass `child` and `title` params
2. **State management is Riverpod only** — no `setState` for data, only for local UI state
3. **Routing is GoRouter only** — always use `context.go(AppRoutes.xxx)` for navigation
4. **All Supabase calls go through providers** — never call `Supabase.instance.client` directly in widgets, use `ref.watch(supabaseClientProvider)`
5. **Colors and text styles from `AppColors` and `AppTextStyles` only** — no hardcoded hex values in widgets
6. **Soft delete** — never do hard `.delete()` on teachers/students/classes. Set `deleted_at = NOW()` instead
7. **Do not rewrite completed files** — only modify placeholders or extend existing files

---

## 🎨 Design System Quick Reference

| Token | Value |
|-------|-------|
| Primary color | `AppColors.primaryDeepNavy` = `#1B365D` |
| Accent / CTA | `AppColors.accentSoftBlue` = `#5C7CFA` |
| Background | `AppColors.backgroundLight` = `#FAFBFC` |
| Success | `AppColors.successGreen` = `#34C759` |
| Warning | `AppColors.warningOrange` = `#FF9F43` |
| Danger | `AppColors.dangerRed` = `#FF5A5F` |
| Font | Inter |
| Card radius | 16px |
| Button radius | 12px |
| Input radius | 12px |

---

## 📦 Database Tables Quick Reference

| Table | Key Columns |
|-------|------------|
| `users` | `id`, `auth_user_id`, `full_name`, `email`, `role` (admin/teacher/student) |
| `teachers` | `id`, `user_id`, `teacher_code`, `subject`, `deleted_at` |
| `students` | `id`, `user_id`, `student_code`, `roll_number`, `class_id`, `deleted_at` |
| `classes` | `id`, `name`, `section`, `grade_level`, `teacher_id`, `deleted_at` |
| `class_teachers` | `class_id`, `teacher_id` (many-to-many) |
| `attendance` | `id`, `student_id`, `class_id`, `date`, `status` (present/absent/late/leave) |
| `exams` | `id`, `name`, `term`, `class_id`, `is_published` |
| `results` | `id`, `exam_id`, `student_id`, `subject`, `marks_obtained`, `total_marks`, `percentage` (generated), `grade` |
| `assignments` | `id`, `teacher_id`, `class_id`, `title`, `file_url`, `due_date` |
| `submissions` | `id`, `assignment_id`, `student_id`, `file_url`, `status` |
| `timetable` | `id`, `class_id`, `teacher_id`, `subject`, `day`, `start_time`, `end_time` |
| `announcements` | `id`, `title`, `content`, `audience` (all/teachers/students), `created_by` |

---

## 🚀 How to Run (once Flutter is installed)

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

> Flutter SDK download: https://flutter.dev/docs/get-started/install/windows

---

## 📝 Git History Summary

| Commit | What Changed |
|--------|-------------|
| `f773d82` | Fix import paths and improve Edge Function error handling |
| `805cb7f` | Fix report data filtering mismatch and add router role guards |
| `c376061` | Implement high-fidelity responsive login screen |
| `afcb0b6` | Implement Phase 3: Admin Students, Teachers, and Dashboard UI |
| `f761ce6` | Implement Phase 4: Class and Timetable management UI with real-time overlap validation |

---

## ⚡ NEXT SESSION: Start Here

**Tell the AI**: *"Read PROJECT_STATE.md in the repo root and continue from Phase 6."*

The AI should:
1. Read this file
2. Start with **Phase 6 — Student Portal**:
   - `student_dashboard.dart` — attendance % widget, announcements feed, upcoming homework alerts
   - `attendance_page.dart` (already done — student calendar view is built)
   - `results_page.dart` (already done — student published results view is built)
   - `assignments_page.dart` (already done — student homework view is built)
3. Then move to **Phase 7 — System Utilities**: `reports_page.dart`, `profile_page.dart`
4. Wrap every screen in `DashboardShell`
5. Commit after each screen
