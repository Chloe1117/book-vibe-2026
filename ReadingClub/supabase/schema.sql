-- BookVibe 2026 — Supabase 테이블 생성 + RLS + Realtime
-- [SQL Editor]에 붙여넣은 뒤 [Run] 하세요.
-- publication 오류가 나면(이미 등록됨) 해당 줄만 생략하면 됩니다.

-- ── 클럽 멤버(참고용 메타). 앱은 기본값으로 Chad / Chlod / 정은 사용.
CREATE TABLE IF NOT EXISTS public.club_members (
  id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0
);

INSERT INTO public.club_members (id, display_name, sort_order) VALUES
  ('chad', 'Chad', 1),
  ('chlod', 'Chlod', 2),
  ('jeongeun', '정은', 3)
ON CONFLICT (id) DO NOTHING;

-- ── 책 10권: 표지(cover_url), 분기별 3인 문장(milestones JSONB), Fast-track(past_import) 등
CREATE TABLE IF NOT EXISTS public.books (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL DEFAULT '',
  author TEXT NOT NULL DEFAULT '',
  cover_url TEXT,
  past_import BOOLEAN NOT NULL DEFAULT FALSE,
  milestones JSONB NOT NULL DEFAULT '{}'::jsonb,
  final_sentence TEXT,
  final_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 기본 milestones 구조 (1~4분기 × 3인)
COMMENT ON COLUMN public.books.milestones IS '예: {"1":{"chad":"","chlod":"","jeongeun":""},"2":{...},"3":{...},"4":{...}}';

-- 10권 시드 (이미 있으면 건너뜀)
INSERT INTO public.books (id, title, author, milestones)
SELECT
  'b' || n,
  '2026 독서 ' || n,
  '',
  jsonb_build_object(
    '1', jsonb_build_object('chad', '', 'chlod', '', 'jeongeun', '')::jsonb,
    '2', jsonb_build_object('chad', '', 'chlod', '', 'jeongeun', '')::jsonb,
    '3', jsonb_build_object('chad', '', 'chlod', '', 'jeongeun', '')::jsonb,
    '4', jsonb_build_object('chad', '', 'chlod', '', 'jeongeun', '')::jsonb
  )
FROM generate_series(1, 10) AS n
ON CONFLICT (id) DO NOTHING;

-- ── 오프라인 모임 (사진 URL·base64 배열을 JSONB로 저장)
CREATE TABLE IF NOT EXISTS public.meetings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  book_id TEXT NOT NULL REFERENCES public.books (id) ON DELETE CASCADE,
  meeting_date DATE NOT NULL,
  place TEXT NOT NULL DEFAULT '',
  photos JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS meetings_book_id_idx ON public.meetings (book_id);
CREATE INDEX IF NOT EXISTS meetings_created_at_idx ON public.meetings (created_at);

-- ── RLS (anon 키로 클럽 앱 접근 — 프로덕션에서는 정책을 좁히세요)
ALTER TABLE public.books ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.club_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bookvibe_books_anon" ON public.books;
CREATE POLICY "bookvibe_books_anon"
  ON public.books FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "bookvibe_meetings_anon" ON public.meetings;
CREATE POLICY "bookvibe_meetings_anon"
  ON public.meetings FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "bookvibe_members_read" ON public.club_members;
CREATE POLICY "bookvibe_members_read"
  ON public.club_members FOR SELECT
  TO anon, authenticated
  USING (true);

-- ── Realtime (대시보드 실시간 반영)
-- 이미 등록되어 있으면 오류 무시
ALTER PUBLICATION supabase_realtime ADD TABLE public.books;
ALTER PUBLICATION supabase_realtime ADD TABLE public.meetings;

-- (선택) updated_at 트리거는 Postgres 버전에 따라 문법이 다를 수 있어 생략했습니다.
-- 앱에서 UPDATE 시 updated_at을 함께 보냅니다.
