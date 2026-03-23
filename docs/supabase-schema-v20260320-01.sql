-- YesOPC Admin Supabase/PostgreSQL schema
-- Version: v20260320-01
-- Notes:
-- - PostgreSQL (Supabase) compatible
-- - Includes updated_at trigger
-- - Reading count anti-spam uses article_reads with UNIQUE(article_id, user_id, read_date)

create extension if not exists pgcrypto;

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-----------------------
-- users
-----------------------
create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  username text not null,
  email text,
  password_hash text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint users_username_uniq unique (username),
  constraint users_email_uniq unique (email)
);

drop trigger if exists trg_users_updated_at on users;
create trigger trg_users_updated_at
before update on users
for each row execute function set_updated_at();

-----------------------
-- sessions (optional)
-----------------------
create table if not exists sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  token_hash text not null,
  expires_at timestamptz not null
);

create index if not exists idx_sessions_user_id on sessions(user_id);

-----------------------
-- notes (动态 / 备忘录：独立存正文)
-----------------------
create table if not exists notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  content_text text not null,
  visibility text not null default 'private',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notes_visibility_chk check (visibility in ('private','public'))
);

drop trigger if exists trg_notes_updated_at on notes;
create trigger trg_notes_updated_at
before update on notes
for each row execute function set_updated_at();

create index if not exists idx_notes_user_created_at on notes(user_id, created_at desc);

-----------------------
-- tags
-----------------------
create table if not exists tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  constraint tags_user_name_uniq unique (user_id, name)
);

create index if not exists idx_tags_user_id on tags(user_id);

-----------------------
-- note_tags (m2m)
-----------------------
create table if not exists note_tags (
  note_id uuid not null references notes(id) on delete cascade,
  tag_id uuid not null references tags(id) on delete cascade,
  constraint note_tags_pk primary key (note_id, tag_id)
);

create index if not exists idx_note_tags_tag_id on note_tags(tag_id);

-----------------------
-- articles（文章：正文富文本独立存）
-----------------------
create table if not exists articles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  title text not null,
  body_html text not null,
  status text not null default 'draft',
  published_at timestamptz,
  read_count bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint articles_status_chk check (status in ('draft','published'))
);

drop trigger if exists trg_articles_updated_at on articles;
create trigger trg_articles_updated_at
before update on articles
for each row execute function set_updated_at();

create index if not exists idx_articles_user_status_updated on articles(user_id, status, updated_at desc);
create index if not exists idx_articles_published_at on articles(published_at);

-----------------------
-- article_reads（阅读量防刷明细）
-- 规则：每用户每篇每天只算 1 次（read_date 为业务日：DATE）
-----------------------
create table if not exists article_reads (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references articles(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  read_date date not null,
  created_at timestamptz not null default now(),
  constraint article_reads_uniq unique (article_id, user_id, read_date)
);

create index if not exists idx_article_reads_article_date on article_reads(article_id, read_date desc);
create index if not exists idx_article_reads_user_date on article_reads(user_id, read_date desc);

-----------------------
-- notifications
-----------------------
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade, -- 接收人
  type text not null,
  title text not null,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_user_created on notifications(user_id, created_at desc);

-----------------------
-- notification_user_state（每用户每通知的 read/archive 状态）
-----------------------
create table if not exists notification_user_state (
  notification_id uuid not null references notifications(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  read_at timestamptz,
  archived_at timestamptz,
  constraint notification_user_state_pk primary key (notification_id, user_id)
);

create index if not exists idx_notification_user_state_user on notification_user_state(user_id);

-----------------------
-- files（附件元数据）
-----------------------
create table if not exists files (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade, -- 上传者
  storage_key text not null,      -- 对象存储路径/Key
  original_name text,
  mime text,
  size_bytes bigint,
  created_at timestamptz not null default now()
);

create index if not exists idx_files_user on files(user_id);

-----------------------
-- article_attachments / note_attachments（关联表）
-----------------------
create table if not exists article_attachments (
  article_id uuid not null references articles(id) on delete cascade,
  file_id uuid not null references files(id) on delete cascade,
  sort_order integer not null default 0,
  constraint article_attachments_pk primary key (article_id, file_id)
);

create index if not exists idx_article_attachments_article_sort on article_attachments(article_id, sort_order);

create table if not exists note_attachments (
  note_id uuid not null references notes(id) on delete cascade,
  file_id uuid not null references files(id) on delete cascade,
  sort_order integer not null default 0,
  constraint note_attachments_pk primary key (note_id, file_id)
);

create index if not exists idx_note_attachments_note_sort on note_attachments(note_id, sort_order);

