-- Supabase/PostgreSQL migration: global tags (cross-user)
-- Version: v20260320-01
--
-- Target design:
-- - tags 变为“全局标签字典”
-- - 通过 name_norm（归一化后的标签名）实现跨用户唯一
-- - note_tags 不需要改（仍是 notes <-> tags 的 M2M）
--
-- Assumptions:
-- - 你已经有 tags 表（来自你之前的 schema：包含 user_id + name 列）
-- - 你希望尽量少破坏现有数据/外键，因此不直接 drop tags 表
--
-- Normalization rule for name_norm:
-- - 去掉前导 #（多个 # 都去）
-- - trim
-- - 折叠连续空白为 1 个空格
-- - lower case
--
-- Examples:
--   '#AI'         -> 'ai'
--   '# AI  '      -> 'ai'
--   '#AI   开发'  -> 'ai 开发'
--

begin;

-- 1) 增加归一化字段 name_norm（若不存在）
alter table tags
  add column if not exists name_norm text;

-- 2) 如果 tags 已有数据，把 name 归一化写入 name_norm
--    （即使你在应用层已经归一化，也可以保持一致）
update tags
set name_norm = lower(
  regexp_replace(
    regexp_replace(trim(name), '^#+', ''),  -- 去掉前导 #
    '\s+',                                    -- 折叠空白
    ' ',
    'g'
  )
)
where name_norm is null;

-- 3) 让 name_norm 非空（需要你已有数据的 name 能正常归一化到非空）
--    若存在 name 为空/纯符号，需先清理数据。
alter table tags
  alter column name_norm set not null;

-- 4) 去掉旧的“(user_id, name)”唯一约束（如果存在）
--    你之前的版本里该约束名通常是 tags_user_name_uniq
alter table tags
  drop constraint if exists tags_user_name_uniq;

-- 5) 创建全局唯一：name_norm 唯一
create unique index if not exists tags_name_norm_uniq_idx
on tags (name_norm);

-- 6) （可选）如果你希望快速按 name_norm 查，唯一索引已满足；
--    这里不额外建重复索引。

commit;

