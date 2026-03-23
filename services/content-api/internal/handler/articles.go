package handler

import (
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"yesopc.com/services/content-api/internal/svc"
)

type articleRow struct {
	ID            string     `json:"id"`
	Title         string     `json:"title"`
	HTML          string     `json:"body_html"`
	CoverImage    string     `json:"cover_image"`
	Status        string     `json:"status"`
	PublishedAt   *time.Time `json:"published_at"`
	ReadCount     int64      `json:"read_count"`
	AuthorID      string     `json:"author_id"`
	Author        string     `json:"author"`
	Summary       string     `json:"summary"`
	AuthorDisplay string     `json:"author_display"`
	IsOriginal    bool       `json:"is_original"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
}

type createArticleReq struct {
	ID            string `json:"id"`
	Title         string `json:"title"`
	BodyHTML      string `json:"body_html"`
	CoverImage    string `json:"cover_image"`
	Status        string `json:"status"`
	Summary       string `json:"summary"`
	AuthorDisplay string `json:"author_display"`
	IsOriginal    bool   `json:"is_original"`
}

type listArticlesResp struct {
	Items    []articleRow `json:"items"`
	Total    int64        `json:"total"`
	Page     int          `json:"page"`
	PageSize int          `json:"page_size"`
	Status   string       `json:"status,omitempty"`
}

// ListArticlesHandler GET /api/v1/articles
func ListArticlesHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}

		q := r.URL.Query()
		status := strings.TrimSpace(q.Get("status"))
		authorID := strings.TrimSpace(q.Get("author_id"))
		if status != "" && status != "draft" && status != "published" {
			writeErr(w, http.StatusBadRequest, "status 仅支持 draft/published")
			return
		}

		page := 1
		pageSize := 10
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

		var draftUID string
		if status == "draft" {
			var ok bool
			draftUID, ok = AuthUserID(r, svcCtx)
			if !ok {
				writeErr(w, http.StatusUnauthorized, "请先登录")
				return
			}
		}

		var items []articleRow
		var rows *sql.Rows
		var err error

		switch status {
		case "draft":
			rows, err = svcCtx.DB.QueryContext(r.Context(), `
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
				FROM articles
				LEFT JOIN users ON articles.user_id = users.id
				WHERE articles.status = 'draft' AND articles.user_id = $1::uuid
				ORDER BY articles.created_at DESC
				LIMIT $2 OFFSET $3`, draftUID, pageSize, offset)
		case "published":
			if authorID != "" {
				rows, err = svcCtx.DB.QueryContext(r.Context(), `
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
					FROM articles
					LEFT JOIN users ON articles.user_id = users.id
					WHERE articles.status = 'published' AND articles.user_id = $1::uuid
					ORDER BY articles.created_at DESC
					LIMIT $2 OFFSET $3`, authorID, pageSize, offset)
			} else {
				rows, err = svcCtx.DB.QueryContext(r.Context(), `
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
					FROM articles
					LEFT JOIN users ON articles.user_id = users.id
					WHERE articles.status = 'published'
					ORDER BY articles.created_at DESC
					LIMIT $1 OFFSET $2`, pageSize, offset)
			}
		default:
			rows, err = svcCtx.DB.QueryContext(r.Context(), `
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
				FROM articles
				LEFT JOIN users ON articles.user_id = users.id
				ORDER BY articles.created_at DESC
				LIMIT $1 OFFSET $2`, pageSize, offset)
		}
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		defer rows.Close()

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
		switch status {
		case "draft":
			err = svcCtx.DB.QueryRowContext(r.Context(), `
				SELECT count(*) FROM articles WHERE status = 'draft' AND user_id = $1::uuid`, draftUID).Scan(&total)
		case "published":
			if authorID != "" {
				err = svcCtx.DB.QueryRowContext(r.Context(), `SELECT count(*) FROM articles WHERE status = 'published' AND user_id = $1::uuid`, authorID).Scan(&total)
			} else {
				err = svcCtx.DB.QueryRowContext(r.Context(), `SELECT count(*) FROM articles WHERE status = 'published'`).Scan(&total)
			}
		default:
			if authorID != "" {
				err = svcCtx.DB.QueryRowContext(r.Context(), `SELECT count(*) FROM articles WHERE user_id = $1::uuid`, authorID).Scan(&total)
			} else {
				err = svcCtx.DB.QueryRowContext(r.Context(), `SELECT count(*) FROM articles`).Scan(&total)
			}
		}
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}

		resp := listArticlesResp{
			Items:    items,
			Total:    total,
			Page:     page,
			PageSize: pageSize,
			Status:   status,
		}
		writeJSON(w, http.StatusOK, resp)
	}
}

// CreateArticleHandler POST /api/v1/articles
func CreateArticleHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
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

		authorUsername := ""
		if err := svcCtx.DB.QueryRowContext(r.Context(), `
			SELECT COALESCE(username, '') 
			FROM users 
			WHERE id = $1::uuid
			LIMIT 1`, uid).Scan(&authorUsername); err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}

		var req createArticleReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeErr(w, http.StatusBadRequest, "invalid json body")
			return
		}

		id := strings.TrimSpace(req.ID)
		title := strings.TrimSpace(req.Title)
		if title == "" {
			writeErr(w, http.StatusBadRequest, "title 不能为空")
			return
		}
		body := strings.TrimSpace(req.BodyHTML)
		if body == "" {
			writeErr(w, http.StatusBadRequest, "body_html 不能为空")
			return
		}
		coverImage := strings.TrimSpace(req.CoverImage)
		summary := strings.TrimSpace(req.Summary)
		authorDisplay := strings.TrimSpace(req.AuthorDisplay)
		isOriginal := req.IsOriginal

		status := strings.TrimSpace(req.Status)
		if status == "" {
			status = "draft"
		}
		if status != "draft" && status != "published" {
			writeErr(w, http.StatusBadRequest, "status 必须是 draft 或 published")
			return
		}

		var a articleRow
		var publishedAtNull sql.NullTime
		if status == "published" {
			now := time.Now().UTC()
			publishedAtNull = sql.NullTime{Time: now, Valid: true}
		}

		coverImageNull := sql.NullString{String: coverImage, Valid: coverImage != ""}

		if id != "" {
			err := svcCtx.DB.QueryRowContext(r.Context(), `
				UPDATE articles
				SET
					title = $2,
					body_html = $3,
					status = $4,
					cover_image = $6,
					summary = $7,
					author_display = $8,
					is_original = $9,
					published_at = CASE WHEN $4 = 'published' THEN now() ELSE NULL END,
					updated_at = now()
				WHERE id = $1::uuid AND user_id = $5::uuid
				RETURNING
					id::text, title, body_html, COALESCE(cover_image,''), status, published_at, read_count,
					COALESCE(summary,''), COALESCE(author_display,''), is_original, created_at, updated_at`,
				id, title, body, status, uid, coverImageNull, summary, authorDisplay, isOriginal,
			).Scan(&a.ID, &a.Title, &a.HTML, &a.CoverImage, &a.Status, &publishedAtNull, &a.ReadCount, &a.Summary, &a.AuthorDisplay, &a.IsOriginal, &a.CreatedAt, &a.UpdatedAt)
			if err != nil {
				if errors.Is(err, sql.ErrNoRows) {
					writeErr(w, http.StatusNotFound, "article not found")
					return
				}
				writeErr(w, http.StatusInternalServerError, err.Error())
				return
			}
			if publishedAtNull.Valid {
				a.PublishedAt = &publishedAtNull.Time
			}
			a.AuthorID = uid
			a.Author = authorUsername
			writeJSON(w, http.StatusOK, a)
			return
		}

		err := svcCtx.DB.QueryRowContext(r.Context(), `
			INSERT INTO articles (user_id, title, body_html, cover_image, status, published_at, summary, author_display, is_original)
			VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, $8, $9)
			RETURNING
				id::text, title, body_html, COALESCE(cover_image,''), status, published_at, read_count,
				COALESCE(summary,''), COALESCE(author_display,''), is_original, created_at, updated_at`,
			uid, title, body, coverImageNull, status, publishedAtNull, summary, authorDisplay, isOriginal,
		).Scan(&a.ID, &a.Title, &a.HTML, &a.CoverImage, &a.Status, &publishedAtNull, &a.ReadCount, &a.Summary, &a.AuthorDisplay, &a.IsOriginal, &a.CreatedAt, &a.UpdatedAt)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		if publishedAtNull.Valid {
			a.PublishedAt = &publishedAtNull.Time
		}
		a.AuthorID = uid
		a.Author = authorUsername

		writeJSON(w, http.StatusCreated, a)
	}
}
