package handler

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"yesopc.com/services/content-api/internal/svc"
)

type followReq struct {
	UserID string `json:"user_id"`
}

type followUserRow struct {
	ID         string    `json:"id"`
	Username   string    `json:"username"`
	FollowedAt time.Time `json:"followed_at"`
	Followers  int64     `json:"followers"`
	Following  int64     `json:"following"`
}

type listFollowingResp struct {
	Items    []followUserRow `json:"items"`
	Total    int64           `json:"total"`
	Page     int             `json:"page"`
	PageSize int             `json:"page_size"`
}

type followStatusResp struct {
	Following bool `json:"following"`
}

type userProfileResp struct {
	ID          string `json:"id"`
	Username    string `json:"username"`
	Followers   int64  `json:"followers"`
	Following   int64  `json:"following"`
	IsFollowing bool   `json:"is_following"`
	IsMe        bool   `json:"is_me"`
}

func optionalAuthUserID(r *http.Request, svcCtx *svc.ServiceContext) string {
	raw := BearerToken(r)
	if raw == "" {
		return ""
	}
	th := hashSessionToken(raw)
	var uid string
	err := svcCtx.DB.QueryRowContext(r.Context(), `
		SELECT user_id::text
		FROM sessions
		WHERE token_hash = $1 AND expires_at > now()
		LIMIT 1`, th).Scan(&uid)
	if err != nil {
		return ""
	}
	return uid
}

// UserProfileHandler GET /api/v1/users/profile?user_id=uuid
func UserProfileHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}

		targetID := strings.TrimSpace(r.URL.Query().Get("user_id"))
		if targetID == "" {
			writeErr(w, http.StatusBadRequest, "user_id 必填")
			return
		}

		var username string
		err := svcCtx.DB.QueryRowContext(r.Context(), `
			SELECT username FROM users WHERE id = $1::uuid`, targetID).Scan(&username)
		if err == sql.ErrNoRows {
			writeErr(w, http.StatusNotFound, "user not found")
			return
		}
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}

		var followers, following int64
		_ = svcCtx.DB.QueryRowContext(r.Context(), `SELECT count(*) FROM user_follows WHERE follow_user_id = $1::uuid`, targetID).Scan(&followers)
		_ = svcCtx.DB.QueryRowContext(r.Context(), `SELECT count(*) FROM user_follows WHERE user_id = $1::uuid`, targetID).Scan(&following)

		currentUID := optionalAuthUserID(r, svcCtx)
		isMe := currentUID != "" && currentUID == targetID
		isFollowing := false
		if currentUID != "" && !isMe {
			var exists bool
			_ = svcCtx.DB.QueryRowContext(r.Context(), `
				SELECT EXISTS(
					SELECT 1 FROM user_follows
					WHERE user_id = $1::uuid AND follow_user_id = $2::uuid
				)`, currentUID, targetID).Scan(&exists)
			isFollowing = exists
		}

		writeJSON(w, http.StatusOK, userProfileResp{
			ID:          targetID,
			Username:    username,
			Followers:   followers,
			Following:   following,
			IsFollowing: isFollowing,
			IsMe:        isMe,
		})
	}
}

// FollowStatusHandler GET /api/v1/follows/status?user_id=uuid
func FollowStatusHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
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
		targetID := strings.TrimSpace(r.URL.Query().Get("user_id"))
		if targetID == "" {
			writeErr(w, http.StatusBadRequest, "user_id 必填")
			return
		}
		if uid == targetID {
			writeJSON(w, http.StatusOK, followStatusResp{Following: false})
			return
		}
		var exists bool
		if err := svcCtx.DB.QueryRowContext(r.Context(), `
			SELECT EXISTS(
				SELECT 1 FROM user_follows
				WHERE user_id = $1::uuid AND follow_user_id = $2::uuid
			)`, uid, targetID).Scan(&exists); err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, followStatusResp{Following: exists})
	}
}

// AddFollowHandler POST /api/v1/follows body: { "user_id": "uuid" }
func AddFollowHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
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
		var req followReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeErr(w, http.StatusBadRequest, "invalid json body")
			return
		}
		targetID := strings.TrimSpace(req.UserID)
		if targetID == "" {
			writeErr(w, http.StatusBadRequest, "user_id 必填")
			return
		}
		if targetID == uid {
			writeErr(w, http.StatusBadRequest, "不能关注自己")
			return
		}
		var existsTarget bool
		if err := svcCtx.DB.QueryRowContext(r.Context(), `
			SELECT EXISTS(SELECT 1 FROM users WHERE id = $1::uuid)`, targetID).Scan(&existsTarget); err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		if !existsTarget {
			writeErr(w, http.StatusNotFound, "目标用户不存在")
			return
		}
		if _, err := svcCtx.DB.ExecContext(r.Context(), `
			INSERT INTO user_follows (user_id, follow_user_id)
			VALUES ($1::uuid, $2::uuid)
			ON CONFLICT (user_id, follow_user_id) DO NOTHING`, uid, targetID); err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"ok": "true"})
	}
}

// RemoveFollowHandler DELETE /api/v1/follows?user_id=uuid
func RemoveFollowHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
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
		targetID := strings.TrimSpace(r.URL.Query().Get("user_id"))
		if targetID == "" {
			writeErr(w, http.StatusBadRequest, "user_id 必填")
			return
		}
		if _, err := svcCtx.DB.ExecContext(r.Context(), `
			DELETE FROM user_follows
			WHERE user_id = $1::uuid AND follow_user_id = $2::uuid`, uid, targetID); err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"ok": "true"})
	}
}

// ListFollowingHandler GET /api/v1/follows?page=1&page_size=20
func ListFollowingHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
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
				u.id::text,
				u.username,
				f.created_at,
				(SELECT count(*) FROM user_follows ff WHERE ff.follow_user_id = u.id) AS followers,
				(SELECT count(*) FROM user_follows ff WHERE ff.user_id = u.id) AS following
			FROM user_follows f
			INNER JOIN users u ON u.id = f.follow_user_id
			WHERE f.user_id = $1::uuid
			ORDER BY f.created_at DESC
			LIMIT $2 OFFSET $3`, uid, pageSize, offset)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		defer rows.Close()

		var items []followUserRow
		for rows.Next() {
			var it followUserRow
			if err := rows.Scan(&it.ID, &it.Username, &it.FollowedAt, &it.Followers, &it.Following); err != nil {
				writeErr(w, http.StatusInternalServerError, err.Error())
				return
			}
			items = append(items, it)
		}

		var total int64
		if err := svcCtx.DB.QueryRowContext(r.Context(), `
			SELECT count(*) FROM user_follows WHERE user_id = $1::uuid`, uid).Scan(&total); err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, listFollowingResp{
			Items:    items,
			Total:    total,
			Page:     page,
			PageSize: pageSize,
		})
	}
}
