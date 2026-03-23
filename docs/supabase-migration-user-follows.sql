-- 用户关注关系（执行一次）
create table if not exists user_follows (
  user_id uuid not null references users(id) on delete cascade,
  follow_user_id uuid not null references users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint user_follows_pk primary key (user_id, follow_user_id),
  constraint user_follows_not_self check (user_id <> follow_user_id)
);

create index if not exists idx_user_follows_follow_user on user_follows(follow_user_id, created_at desc);

