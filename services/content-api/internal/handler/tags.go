package handler

import (
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"regexp"
	"strings"
	"time"

	"yesopc.com/services/content-api/internal/svc"

	"github.com/jackc/pgx/v5/pgconn"
)

type tagRow struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
}

type createTagReq struct {
	Name string `json:"name"`
}

var tagSpaceRe = regexp.MustCompile(`\s+`)

// normalizeTagName 兼容 tags-global migration 的 name_norm 规则：
// - 去掉前导 #（多个 #）
// - trim
// - 折叠连续空白为 1 个空格
// - lower case
func normalizeTagName(raw string) (cleanName string, nameNorm string) {
	s := strings.TrimSpace(raw)
	// 去掉前导 #（多个）
	for strings.HasPrefix(s, "#") {
		s = strings.TrimSpace(strings.TrimPrefix(s, "#"))
	}
	// 折叠空白
	s = tagSpaceRe.ReplaceAllString(s, " ")
	cleanName = strings.TrimSpace(s)
	nameNorm = strings.ToLower(cleanName)
	return cleanName, nameNorm
}

// ListTagsHandler GET /api/v1/tags
func ListTagsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
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

		rows, err := svcCtx.DB.QueryContext(r.Context(), `
			SELECT id::text, name, created_at
			FROM tags
			WHERE user_id = $1::uuid
			ORDER BY created_at DESC
			LIMIT 50`, uid)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		defer rows.Close()

		var out []tagRow
		for rows.Next() {
			var t tagRow
			if err := rows.Scan(&t.ID, &t.Name, &t.CreatedAt); err != nil {
				writeErr(w, http.StatusInternalServerError, err.Error())
				return
			}
			out = append(out, t)
		}
		if out == nil {
			out = []tagRow{}
		}
		writeJSON(w, http.StatusOK, out)
	}
}

// CreateTagHandler POST /api/v1/tags
func CreateTagHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
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

		var req createTagReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeErr(w, http.StatusBadRequest, "invalid json body")
			return
		}

		name := strings.TrimSpace(req.Name)
		if name == "" {
			writeErr(w, http.StatusBadRequest, "name 不能为空")
			return
		}

		cleanName, nameNorm := normalizeTagName(name)
		if cleanName == "" {
			writeErr(w, http.StatusBadRequest, "name 不能为空")
			return
		}

		// 尝试插入；若遇到唯一约束冲突（如 tags_user_name_uniq），则查询已有记录返回
		var t tagRow
		err := svcCtx.DB.QueryRowContext(r.Context(), `
			INSERT INTO tags (user_id, name, name_norm)
			VALUES ($1::uuid, $2, $3)
			RETURNING id::text, name, created_at`,
			uid, cleanName, nameNorm,
		).Scan(&t.ID, &t.Name, &t.CreatedAt)

		if err != nil {
			var pgErr *pgconn.PgError
			if errors.As(err, &pgErr) && pgErr.Code == "23505" {
				// duplicate key => select existing
				_ = svcCtx.DB.QueryRowContext(r.Context(), `
					SELECT id::text, name, created_at
					FROM tags
					WHERE user_id = $1::uuid AND name_norm = $2
					LIMIT 1`,
					uid, nameNorm,
				).Scan(&t.ID, &t.Name, &t.CreatedAt)

				// 即使再次没取到，也回原错（避免吞错误）
				writeJSON(w, http.StatusOK, t)
				return
			}
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}

		writeJSON(w, http.StatusCreated, t)
	}
}

// 保留 sql 包依赖；后续会用于更多 handler 扩展（例如 note_tags）。
var _ = sql.NullString{}

