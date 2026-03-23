-- 用户收藏文章（在 Supabase SQL Editor 执行一次）
-- Version: 20260323-favorites
--
-- 若 articles 尚无 cover_image 列，请先执行：
--   alter table articles add column if not exists cover_image text;

create table if not exists user_article_favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  article_id uuid not null references articles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint user_article_favorites_uniq unique (user_id, article_id)
);

create index if not exists idx_user_article_favorites_user_created
  on user_article_favorites(user_id, created_at desc);

create index if not exists idx_user_article_favorites_article
  on user_article_favorites(article_id);
