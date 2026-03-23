package handler

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"yesopc.com/services/content-api/internal/svc"
)

type favoriteStatusResp struct {
	Favorited bool `json:"favorited"`
}

type addFavoriteReq struct {
	ArticleID string `json:"article_id"`
}

// ListFavoritesHandler GET /api/v1/favorites — 当前用户收藏的文章（仅已发布），按收藏时间倒序
func ListFavoritesHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		uid, ok := AuthUserID(r, svcCtx)
		if !ok {
			writeErr(w, http.StatusUnauthorized, "请先登录")
			return
		}

		q := r.URL.Query()
		page := 1
		pageSize := 20
		if v := strings.TrimSpace(q.Get("page")); v != "" {
			if n, err := strconv.Atoi(v); err == nil && n > 0 {
				page = n
			}
		}
		if v := strings.TrimSpace(q.Get("page_size")); v != "" {
			if n, err := strconv.Atoi(v); err == nil && n > 0 {
				if n > 50 {
					n = 50
				}
				pageSize = n
			}
		}
		offset := (page - 1) * pageSize

		rows, err := svcCtx.DB.QueryContext(r.Context(), `
			SELECT
				articles.id::text,
				articles.title,
				articles.body_html,
				COALESCE(articles.cover_image, '') as cover_image,
				articles.status,
				articles.published_at,
				articles.read_count,
				COALESCE(users.id::text, '') as author_id,
				COALESCE(users.username, '') as author,
				COALESCE(articles.summary, '') as summary,
				COALESCE(articles.author_display, '') as author_display,
				articles.is_original,
				articles.created_at,
				articles.updated_at
			FROM user_article_favorites f
			INNER JOIN articles ON articles.id = f.article_id AND articles.status = 'published'
			LEFT JOIN users ON articles.user_id = users.id
			WHERE f.user_id = $1::uuid
			ORDER BY f.created_at DESC
			LIMIT $2 OFFSET $3`,
			uid, pageSize, offset)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		defer rows.Close()

		var items []articleRow
		for rows.Next() {
			var a articleRow
			var publishedAt sql.NullTime
			if err := rows.Scan(
				&a.ID,
				&a.Title,
				&a.HTML,
				&a.CoverImage,
				&a.Status,
				&publishedAt,
				&a.ReadCount,
				&a.AuthorID,
				&a.Author,
				&a.Summary,
				&a.AuthorDisplay,
				&a.IsOriginal,
				&a.CreatedAt,
				&a.UpdatedAt,
			); err != nil {
				writeErr(w, http.StatusInternalServerError, err.Error())
				return
			}
			if publishedAt.Valid {
				a.PublishedAt = &publishedAt.Time
			}
			items = append(items, a)
		}

		var total int64
		err = svcCtx.DB.QueryRowContext(r.Context(), `
			SELECT count(*) FROM user_article_favorites f
			INNER JOIN articles a ON a.id = f.article_id AND a.status = 'published'
			WHERE f.user_id = $1::uuid`, uid).Scan(&total)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}

		writeJSON(w, http.StatusOK, listArticlesResp{
			Items:    items,
			Total:    total,
			Page:     page,
			PageSize: pageSize,
		})
	}
}

// AddFavoriteHandler POST /api/v1/favorites — body: { "article_id": "uuid" }
func AddFavoriteHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		uid, ok := AuthUserID(r, svcCtx)
		if !ok {
			writeErr(w, http.StatusUnauthorized, "请先登录")
			return
		}
		var req addFavoriteReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeErr(w, http.StatusBadRequest, "invalid json")
			return
		}
		aid := strings.TrimSpace(req.ArticleID)
		if aid == "" {
			writeErr(w, http.StatusBadRequest, "article_id 必填")
			return
		}
		var exists bool
		err := svcCtx.DB.QueryRowContext(r.Context(), `
			SELECT EXISTS(SELECT 1 FROM articles WHERE id = $1::uuid AND status = 'published')`,
			aid).Scan(&exists)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		if !exists {
			writeErr(w, http.StatusNotFound, "文章不存在或未发布")
			return
		}
		_, err = svcCtx.DB.ExecContext(r.Context(), `
			INSERT INTO user_article_favorites (user_id, article_id)
			VALUES ($1::uuid, $2::uuid)
			ON CONFLICT (user_id, article_id) DO NOTHING`,
			uid, aid)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	}
}

// RemoveFavoriteHandler DELETE /api/v1/favorites?article_id=uuid
func RemoveFavoriteHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodDelete {
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		uid, ok := AuthUserID(r, svcCtx)
		if !ok {
			writeErr(w, http.StatusUnauthorized, "请先登录")
			return
		}
		aid := strings.TrimSpace(r.URL.Query().Get("article_id"))
		if aid == "" {
			writeErr(w, http.StatusBadRequest, "article_id 必填")
			return
		}
		_, err := svcCtx.DB.ExecContext(r.Context(), `
			DELETE FROM user_article_favorites
			WHERE user_id = $1::uuid AND article_id = $2::uuid`,
			uid, aid)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	}
}

// FavoriteStatusHandler GET /api/v1/favorites/status?article_id=uuid
func FavoriteStatusHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		uid, ok := AuthUserID(r, svcCtx)
		if !ok {
			writeJSON(w, http.StatusOK, favoriteStatusResp{Favorited: false})
			return
		}
		aid := strings.TrimSpace(r.URL.Query().Get("article_id"))
		if aid == "" {
			writeErr(w, http.StatusBadRequest, "article_id 必填")
			return
		}
		var favorited bool
		err := svcCtx.DB.QueryRowContext(r.Context(), `
			SELECT EXISTS(
				SELECT 1 FROM user_article_favorites
				WHERE user_id = $1::uuid AND article_id = $2::uuid
			)`, uid, aid).Scan(&favorited)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, favoriteStatusResp{Favorited: favorited})
	}
}
