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
)

type noteRow struct {
	ID          string    `json:"id"`
	ContentText string    `json:"content_text"`
	Visibility  string    `json:"visibility"`
	Author      string    `json:"author"`
	CreatedAt   time.Time `json:"created_at"`
}

type createNoteReq struct {
	ContentText string `json:"content_text"`
	Visibility  string `json:"visibility"`
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

// ListNotesHandler GET /api/v1/notes
// - 默认：仅返回全站公开笔记（发现频道等）
// - ?mine=1 或 ?mine=true：返回 DEFAULT_NOTES_USER_ID 对应用户的全部备忘录（含 private），供社群页「我的发布」
// - ?author_id=uuid：返回指定用户公开备忘录（个人主页）
func ListNotesHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		mine := strings.TrimSpace(r.URL.Query().Get("mine"))
		mineOnly := mine == "1" || strings.EqualFold(mine, "true")
		authorID := strings.TrimSpace(r.URL.Query().Get("author_id"))

		var rows *sql.Rows
		var err error
		if mineOnly {
			uid, ok := AuthUserID(r, svcCtx)
			if !ok {
				writeErr(w, http.StatusUnauthorized, "请先登录")
				return
			}
			rows, err = svcCtx.DB.QueryContext(r.Context(), `
				SELECT
					notes.id::text,
					notes.content_text,
					notes.visibility::text,
					COALESCE(users.username, '') AS author,
					notes.created_at
				FROM notes
				LEFT JOIN users ON notes.user_id = users.id
				WHERE notes.user_id = $1::uuid
				ORDER BY notes.created_at DESC
				LIMIT 200`,
				uid)
		} else if authorID != "" {
			rows, err = svcCtx.DB.QueryContext(r.Context(), `
				SELECT
					notes.id::text,
					notes.content_text,
					notes.visibility::text,
					COALESCE(users.username, '') AS author,
					notes.created_at
				FROM notes
				LEFT JOIN users ON notes.user_id = users.id
				WHERE notes.visibility = 'public' AND notes.user_id = $1::uuid
				ORDER BY notes.created_at DESC
				LIMIT 100`, authorID)
		} else {
			rows, err = svcCtx.DB.QueryContext(r.Context(), `
				SELECT
					notes.id::text,
					notes.content_text,
					notes.visibility::text,
					COALESCE(users.username, '') AS author,
					notes.created_at
				FROM notes
				LEFT JOIN users ON notes.user_id = users.id
				WHERE notes.visibility = 'public'
				ORDER BY notes.created_at DESC
				LIMIT 100`)
		}
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		defer rows.Close()

		var out []noteRow
		for rows.Next() {
			var n noteRow
			if err := rows.Scan(&n.ID, &n.ContentText, &n.Visibility, &n.Author, &n.CreatedAt); err != nil {
				writeErr(w, http.StatusInternalServerError, err.Error())
				return
			}
			out = append(out, n)
		}
		if out == nil {
			out = []noteRow{}
		}
		writeJSON(w, http.StatusOK, out)
	}
}

// CreateNoteHandler POST /api/v1/notes
func CreateNoteHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
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

		var req createNoteReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeErr(w, http.StatusBadRequest, "invalid json body")
			return
		}
		text := strings.TrimSpace(req.ContentText)
		if text == "" {
			writeErr(w, http.StatusBadRequest, "content_text 不能为空")
			return
		}
		vis := strings.TrimSpace(req.Visibility)
		if vis == "" {
			vis = "public"
		}
		if vis != "private" && vis != "public" {
			writeErr(w, http.StatusBadRequest, "visibility 必须是 private 或 public")
			return
		}

		// 使用事务保证：notes / tags / note_tags 同步写入
		tx, err := svcCtx.DB.BeginTx(r.Context(), nil)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		defer func() { _ = tx.Rollback() }()

		var n noteRow
		if err := tx.QueryRowContext(r.Context(), `
			INSERT INTO notes (user_id, content_text, visibility)
			VALUES ($1::uuid, $2, $3)
			RETURNING
				id::text,
				content_text,
				visibility::text,
				(SELECT COALESCE(username, '') FROM users WHERE users.id = $1::uuid),
				created_at`,
			uid, text, vis,
		).Scan(&n.ID, &n.ContentText, &n.Visibility, &n.Author, &n.CreatedAt); err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}

		// 自动解析正文里的 hashtags，写入 tags + note_tags
		// 兼容：
		// - ASCII: #YesOPC
		// - 全角：＃YesOPC
		// - # 与标签之间允许空格：# YesOPC
		hashtagRe := regexp.MustCompile(`[#＃]\s*([\p{L}\p{N}_]+)`)
		matches := hashtagRe.FindAllStringSubmatch(text, -1)
		if len(matches) > 0 {
			// 去重：以 name_norm 为准
			type tagKey struct {
				cleanName string
				nameNorm  string
			}
			tagMap := make(map[string]tagKey, len(matches)) // key=nameNorm
			for _, m := range matches {
				if len(m) < 2 {
					continue
				}
				cleanName, nameNorm := normalizeTagName(m[1])
				if cleanName == "" || nameNorm == "" {
					continue
				}
				tagMap[nameNorm] = tagKey{cleanName: cleanName, nameNorm: nameNorm}
			}

			for _, tk := range tagMap {
				// 1) upsert tag：tags 具有 name_norm 非空约束
				var tagID string
				err := tx.QueryRowContext(r.Context(), `
					INSERT INTO tags (user_id, name, name_norm)
					VALUES ($1::uuid, $2, $3)
					ON CONFLICT DO NOTHING
					RETURNING id::text`,
					uid, tk.cleanName, tk.nameNorm,
				).Scan(&tagID)

				// ON CONFLICT DO NOTHING => 可能没有返回行
				if err != nil {
					if errors.Is(err, sql.ErrNoRows) {
						// 由于 tags 可能是“全局唯一 name_norm”，这里按 name_norm 查询即可
						if qErr := tx.QueryRowContext(r.Context(), `
							SELECT id::text
							FROM tags
							WHERE name_norm = $1
							LIMIT 1`,
							tk.nameNorm,
						).Scan(&tagID); qErr != nil {
							writeErr(w, http.StatusInternalServerError, qErr.Error())
							return
						}
					} else {
						writeErr(w, http.StatusInternalServerError, err.Error())
						return
					}
				}

				// 2) 关联 note <-> tag
				_, err = tx.ExecContext(r.Context(), `
					INSERT INTO note_tags (note_id, tag_id)
					VALUES ($1::uuid, $2::uuid)
					ON CONFLICT DO NOTHING`,
					n.ID, tagID,
				)
				if err != nil {
					writeErr(w, http.StatusInternalServerError, err.Error())
					return
				}
			}
		}

		if err := tx.Commit(); err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, n)
	}
}
