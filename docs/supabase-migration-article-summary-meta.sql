-- 文章发布页元数据：摘要、署名、原创标记（执行一次）
alter table articles add column if not exists summary text;
alter table articles add column if not exists author_display text;
alter table articles add column if not exists is_original boolean not null default false;
