# content-api（go-zero）

前端只调本服务；本服务用 PostgreSQL 连接串直连数据库，不把 PostgREST / Edge Functions 暴露给浏览器。

## 接口

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/notes` | 最近 100 条**公开** `notes`（`visibility=public`），含 `author`，按 `created_at` 倒序 |
| POST | `/api/v1/notes` | 创建 note：`{ "content_text", "visibility" }` |
| GET | `/api/v1/articles` | 最近 50 条 `articles`，按 `created_at` 倒序 |
| POST | `/api/v1/articles` | 创建 article：`{ "title", "body_html", "status" }` |
| GET | `/api/v1/tags` | 最近 50 条 `tags`（当前默认用户作用域） |
| POST | `/api/v1/tags` | 创建 tag：`{ "name" }` |
| GET | `/api/v1/favorites` | 我的收藏（需登录，仅已发布文章） |
| GET | `/api/v1/favorites/status?article_id=` | 是否已收藏（未登录返回 false） |
| POST | `/api/v1/favorites` | 收藏：`{ "article_id" }`（需登录） |
| DELETE | `/api/v1/favorites?article_id=` | 取消收藏（需登录） |

数据库：在 Supabase 执行 `docs/supabase-migration-user-article-favorites.sql` 创建 `user_article_favorites` 表。

## 本地运行

```bash
cd services/content-api
# 使用你现有的 values（建议复制同一份 .env 或在启动命令中 source 旧目录的 .env）
go run . -f etc/content-api.yaml
```

默认监听 `http://0.0.0.0:8888`。

