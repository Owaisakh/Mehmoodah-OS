-- =============================================================================
-- Migration: 00001_initial_schema.sql
-- Project:   Mehmoodah Academy School Operating System (V1)
-- =============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- ENUMS
-- =============================================================================

CREATE TYPE user_role AS ENUM ('admin', 'teacher', 'student');
CREATE TYPE attendance_status AS ENUM ('present', 'absent', 'late', 'leave');
CREATE TYPE submission_status AS ENUM ('pending', 'submitted', 'graded');
CREATE TYPE announcement_audience AS ENUM ('all', 'teachers', 'students');
CREATE TYPE day_of_week AS ENUM ('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday');

-- =============================================================================
-- TABLE: users
-- Mirrors auth.users — stores role + profile metadata.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.users (
  id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_user_id UUID        UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name    TEXT        NOT NULL,
  email        TEXT        NOT NULL UNIQUE,
  role         user_role   NOT NULL DEFAULT 'student',
  avatar_url   TEXT,
  phone        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index on role for fast role-based queries
CREATE INDEX idx_users_role ON public.users(role);
CREATE INDEX idx_users_auth_user_id ON public.users(auth_user_id);

-- =============================================================================
-- TABLE: classes
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.classes (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT        NOT NULL,          -- e.g. "Class 8-B"
  section     TEXT,                          -- e.g. "B"
  grade_level TEXT        NOT NULL,          -- e.g. "8"
  teacher_id  UUID        REFERENCES public.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ                    -- soft delete
);

CREATE INDEX idx_classes_teacher_id ON public.classes(teacher_id);
CREATE INDEX idx_classes_deleted_at ON public.classes(deleted_at) WHERE deleted_at IS NULL;

-- =============================================================================
-- TABLE: teachers
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.teachers (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID        NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  teacher_code  TEXT        NOT NULL UNIQUE,  -- e.g. "TCH-001"
  subject       TEXT        NOT NULL,
  joining_date  DATE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ                    -- soft delete
);

CREATE INDEX idx_teachers_user_id    ON public.teachers(user_id);
CREATE INDEX idx_teachers_deleted_at ON public.teachers(deleted_at) WHERE deleted_at IS NULL;

-- =============================================================================
-- TABLE: class_teachers  (many-to-many: teachers can be assigned to many classes)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.class_teachers (
  class_id    UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  teacher_id  UUID NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (class_id, teacher_id)
);

CREATE INDEX idx_class_teachers_teacher ON public.class_teachers(teacher_id);
CREATE INDEX idx_class_teachers_class   ON public.class_teachers(class_id);

-- =============================================================================
-- TABLE: students
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.students (
  id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID        NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  student_code    TEXT        NOT NULL UNIQUE,    -- e.g. "STD-2026-001"
  roll_number     TEXT        NOT NULL,
  class_id        UUID        REFERENCES public.classes(id) ON DELETE SET NULL,
  dob             DATE,
  guardian_name   TEXT,
  guardian_phone  TEXT,
  admission_date  DATE,
  status          TEXT        NOT NULL DEFAULT 'active',  -- active | inactive
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at      TIMESTAMPTZ                             -- soft delete
);

CREATE INDEX idx_students_user_id    ON public.students(user_id);
CREATE INDEX idx_students_class_id   ON public.students(class_id);
CREATE INDEX idx_students_code       ON public.students(student_code);
CREATE INDEX idx_students_deleted_at ON public.students(deleted_at) WHERE deleted_at IS NULL;

-- =============================================================================
-- TABLE: attendance
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.attendance (
  id          UUID              PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id  UUID              NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  class_id    UUID              NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  teacher_id  UUID              REFERENCES public.teachers(id) ON DELETE SET NULL,
  date        DATE              NOT NULL,
  status      attendance_status NOT NULL DEFAULT 'present',
  note        TEXT,
  created_at  TIMESTAMPTZ       NOT NULL DEFAULT NOW(),

  -- Enforce one attendance entry per student per day
  CONSTRAINT uq_attendance_student_date UNIQUE (student_id, date)
);

CREATE INDEX idx_attendance_student_id ON public.attendance(student_id);
CREATE INDEX idx_attendance_class_id   ON public.attendance(class_id);
CREATE INDEX idx_attendance_date       ON public.attendance(date);

-- =============================================================================
-- TABLE: exams
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.exams (
  id             UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  name           TEXT        NOT NULL,   -- e.g. "Mid Term Exam 2026"
  term           TEXT        NOT NULL,   -- e.g. "Mid Term" | "Final"
  class_id       UUID        NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  exam_date      DATE,
  is_published   BOOLEAN     NOT NULL DEFAULT FALSE,
  published_at   TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_exams_class_id ON public.exams(class_id);

-- =============================================================================
-- TABLE: results
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.results (
  id             UUID    PRIMARY KEY DEFAULT uuid_generate_v4(),
  exam_id        UUID    NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
  student_id     UUID    NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  subject        TEXT    NOT NULL,
  marks_obtained NUMERIC(5,2),
  total_marks    NUMERIC(5,2) NOT NULL DEFAULT 100,
  percentage     NUMERIC(5,2) GENERATED ALWAYS AS (
                   CASE WHEN total_marks > 0
                     THEN ROUND((marks_obtained / total_marks) * 100, 2)
                   ELSE 0 END
                 ) STORED,
  grade          TEXT,         -- Computed & stored by Edge Function on publish
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- One result per student per exam per subject
  CONSTRAINT uq_results_student_exam_subject UNIQUE (exam_id, student_id, subject)
);

CREATE INDEX idx_results_exam_id    ON public.results(exam_id);
CREATE INDEX idx_results_student_id ON public.results(student_id);

-- =============================================================================
-- TABLE: assignments
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.assignments (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id  UUID        NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
  class_id    UUID        NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  title       TEXT        NOT NULL,
  description TEXT,
  file_url    TEXT,                  -- Supabase storage URL
  due_date    DATE        NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_assignments_class_id   ON public.assignments(class_id);
CREATE INDEX idx_assignments_teacher_id ON public.assignments(teacher_id);
CREATE INDEX idx_assignments_due_date   ON public.assignments(due_date);

-- =============================================================================
-- TABLE: submissions
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.submissions (
  id            UUID              PRIMARY KEY DEFAULT uuid_generate_v4(),
  assignment_id UUID              NOT NULL REFERENCES public.assignments(id) ON DELETE CASCADE,
  student_id    UUID              NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  file_url      TEXT,
  status        submission_status NOT NULL DEFAULT 'pending',
  submitted_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ       NOT NULL DEFAULT NOW(),

  -- One submission per student per assignment
  CONSTRAINT uq_submissions_student_assignment UNIQUE (assignment_id, student_id)
);

CREATE INDEX idx_submissions_assignment_id ON public.submissions(assignment_id);
CREATE INDEX idx_submissions_student_id    ON public.submissions(student_id);

-- =============================================================================
-- TABLE: timetable
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.timetable (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  class_id    UUID        NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  teacher_id  UUID        REFERENCES public.teachers(id) ON DELETE SET NULL,
  subject     TEXT        NOT NULL,
  day         day_of_week NOT NULL,
  start_time  TIME        NOT NULL,
  end_time    TIME        NOT NULL,
  room        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Prevent teacher double-booking on same day/time
  CONSTRAINT uq_timetable_teacher_slot UNIQUE (teacher_id, day, start_time),
  -- Prevent class double-booking on same day/time
  CONSTRAINT uq_timetable_class_slot   UNIQUE (class_id, day, start_time),
  -- Ensure end_time > start_time
  CONSTRAINT chk_timetable_times CHECK (end_time > start_time)
);

CREATE INDEX idx_timetable_class_id   ON public.timetable(class_id);
CREATE INDEX idx_timetable_teacher_id ON public.timetable(teacher_id);

-- =============================================================================
-- TABLE: announcements
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.announcements (
  id         UUID                    PRIMARY KEY DEFAULT uuid_generate_v4(),
  title      TEXT                    NOT NULL,
  content    TEXT                    NOT NULL,
  audience   announcement_audience   NOT NULL DEFAULT 'all',
  created_by UUID                    NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ             NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_announcements_audience   ON public.announcements(audience);
CREATE INDEX idx_announcements_created_at ON public.announcements(created_at DESC);

-- =============================================================================
-- AUTO-UPDATE: updated_at trigger function
-- =============================================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Attach trigger to all tables with updated_at
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'users','classes','teachers','students',
    'exams','results','assignments','submissions','timetable'
  ] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%1$s_updated_at
       BEFORE UPDATE ON public.%1$s
       FOR EACH ROW EXECUTE FUNCTION update_updated_at();', tbl
    );
  END LOOP;
END;
$$;

-- =============================================================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================================================

-- Enable RLS on all tables
ALTER TABLE public.users         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teachers      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exams         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.results       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignments   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submissions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timetable     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- Helper function: get current user's role from public.users
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS user_role LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM public.users WHERE auth_user_id = auth.uid();
$$;

-- Helper function: get current user's teacher id
CREATE OR REPLACE FUNCTION get_my_teacher_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT t.id FROM public.teachers t
  JOIN public.users u ON u.id = t.user_id
  WHERE u.auth_user_id = auth.uid();
$$;

-- Helper function: get current user's student id
CREATE OR REPLACE FUNCTION get_my_student_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT s.id FROM public.students s
  JOIN public.users u ON u.id = s.user_id
  WHERE u.auth_user_id = auth.uid();
$$;

-- ---------------------------------------------------------------------------
-- POLICIES: users
-- ---------------------------------------------------------------------------
CREATE POLICY "admin_all_users"
  ON public.users FOR ALL
  USING (get_my_role() = 'admin');

CREATE POLICY "self_read_user"
  ON public.users FOR SELECT
  USING (auth_user_id = auth.uid());

CREATE POLICY "self_update_user"
  ON public.users FOR UPDATE
  USING (auth_user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- POLICIES: teachers
-- ---------------------------------------------------------------------------
CREATE POLICY "admin_all_teachers"
  ON public.teachers FOR ALL
  USING (get_my_role() = 'admin');

CREATE POLICY "teacher_read_own"
  ON public.teachers FOR SELECT
  USING (user_id = (
    SELECT id FROM public.users WHERE auth_user_id = auth.uid()
  ));

-- ---------------------------------------------------------------------------
-- POLICIES: students
-- ---------------------------------------------------------------------------
CREATE POLICY "admin_all_students"
  ON public.students FOR ALL
  USING (get_my_role() = 'admin');

CREATE POLICY "teacher_read_assigned_students"
  ON public.students FOR SELECT
  USING (
    get_my_role() = 'teacher'
    AND class_id IN (
      SELECT class_id FROM public.class_teachers
      WHERE teacher_id = get_my_teacher_id()
    )
  );

CREATE POLICY "student_read_own"
  ON public.students FOR SELECT
  USING (user_id = (
    SELECT id FROM public.users WHERE auth_user_id = auth.uid()
  ));

-- ---------------------------------------------------------------------------
-- POLICIES: classes
-- ---------------------------------------------------------------------------
CREATE POLICY "admin_all_classes"
  ON public.classes FOR ALL
  USING (get_my_role() = 'admin');

CREATE POLICY "teacher_read_assigned_classes"
  ON public.classes FOR SELECT
  USING (
    get_my_role() = 'teacher'
    AND id IN (
      SELECT class_id FROM public.class_teachers
      WHERE teacher_id = get_my_teacher_id()
    )
  );

CREATE POLICY "student_read_own_class"
  ON public.classes FOR SELECT
  USING (
    get_my_role() = 'student'
    AND id = (
      SELECT class_id FROM public.students
      WHERE user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- POLICIES: attendance
-- ---------------------------------------------------------------------------
CREATE POLICY "admin_all_attendance"
  ON public.attendance FOR ALL
  USING (get_my_role() = 'admin');

CREATE POLICY "teacher_manage_attendance"
  ON public.attendance FOR ALL
  USING (
    get_my_role() = 'teacher'
    AND class_id IN (
      SELECT class_id FROM public.class_teachers
      WHERE teacher_id = get_my_teacher_id()
    )
  );

CREATE POLICY "student_read_own_attendance"
  ON public.attendance FOR SELECT
  USING (student_id = get_my_student_id());

-- ---------------------------------------------------------------------------
-- POLICIES: exams
-- ---------------------------------------------------------------------------
CREATE POLICY "admin_all_exams"
  ON public.exams FOR ALL
  USING (get_my_role() = 'admin');

CREATE POLICY "teacher_manage_class_exams"
  ON public.exams FOR ALL
  USING (
    get_my_role() = 'teacher'
    AND class_id IN (
      SELECT class_id FROM public.class_teachers
      WHERE teacher_id = get_my_teacher_id()
    )
  );

CREATE POLICY "student_read_published_exams"
  ON public.exams FOR SELECT
  USING (
    get_my_role() = 'student'
    AND is_published = TRUE
    AND class_id = (
      SELECT class_id FROM public.students
      WHERE user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- POLICIES: results
-- ---------------------------------------------------------------------------
CREATE POLICY "admin_all_results"
  ON public.results FOR ALL
  USING (get_my_role() = 'admin');

CREATE POLICY "teacher_manage_class_results"
  ON public.results FOR ALL
  USING (
    get_my_role() = 'teacher'
    AND exam_id IN (
      SELECT e.id FROM public.exams e
      JOIN public.class_teachers ct ON ct.class_id = e.class_id
      WHERE ct.teacher_id = get_my_teacher_id()
    )
  );

CREATE POLICY "student_read_own_results"
  ON public.results FOR SELECT
  USING (student_id = get_my_student_id());

-- ---------------------------------------------------------------------------
-- POLICIES: assignments
-- ---------------------------------------------------------------------------
CREATE POLICY "admin_all_assignments"
  ON public.assignments FOR ALL
  USING (get_my_role() = 'admin');

CREATE POLICY "teacher_manage_own_assignments"
  ON public.assignments FOR ALL
  USING (teacher_id = get_my_teacher_id());

CREATE POLICY "student_read_class_assignments"
  ON public.assignments FOR SELECT
  USING (
    get_my_role() = 'student'
    AND class_id = (
      SELECT class_id FROM public.students
      WHERE user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- POLICIES: submissions
-- ---------------------------------------------------------------------------
CREATE POLICY "admin_all_submissions"
  ON public.submissions FOR ALL
  USING (get_my_role() = 'admin');

CREATE POLICY "teacher_read_class_submissions"
  ON public.submissions FOR SELECT
  USING (
    get_my_role() = 'teacher'
    AND assignment_id IN (
      SELECT id FROM public.assignments
      WHERE teacher_id = get_my_teacher_id()
    )
  );

CREATE POLICY "student_manage_own_submissions"
  ON public.submissions FOR ALL
  USING (student_id = get_my_student_id());

-- ---------------------------------------------------------------------------
-- POLICIES: timetable
-- ---------------------------------------------------------------------------
CREATE POLICY "admin_all_timetable"
  ON public.timetable FOR ALL
  USING (get_my_role() = 'admin');

CREATE POLICY "teacher_read_own_timetable"
  ON public.timetable FOR SELECT
  USING (teacher_id = get_my_teacher_id());

CREATE POLICY "student_read_class_timetable"
  ON public.timetable FOR SELECT
  USING (
    get_my_role() = 'student'
    AND class_id = (
      SELECT class_id FROM public.students
      WHERE user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- POLICIES: announcements
-- ---------------------------------------------------------------------------
CREATE POLICY "admin_all_announcements"
  ON public.announcements FOR ALL
  USING (get_my_role() = 'admin');

CREATE POLICY "teacher_read_announcements"
  ON public.announcements FOR SELECT
  USING (
    get_my_role() = 'teacher'
    AND audience IN ('all', 'teachers')
  );

CREATE POLICY "student_read_announcements"
  ON public.announcements FOR SELECT
  USING (
    get_my_role() = 'student'
    AND audience IN ('all', 'students')
  );

-- =============================================================================
-- AUTO-SYNC: New Supabase auth user → public.users row
-- (triggered via Supabase hook or Edge Function on signup)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.users (auth_user_id, full_name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Unknown'),
    NEW.email,
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'student')
  );
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- =============================================================================
-- STORAGE BUCKETS (apply via Supabase Dashboard or CLI)
-- Declared here as reference comments only:
--
--   Bucket: student-photos    (private)
--   Bucket: teacher-photos    (private)
--   Bucket: assignments       (private)
--   Bucket: submissions       (private)
--   Bucket: reports           (private)
--
-- Path convention: {bucket}/{year}/{month}/{filename}
-- =============================================================================
