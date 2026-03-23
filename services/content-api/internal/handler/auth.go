package handler

import (
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"regexp"
	"strings"
	"time"

	"yesopc.com/services/content-api/internal/svc"

	"golang.org/x/crypto/bcrypt"
)

var usernameRe = regexp.MustCompile(`^[a-zA-Z0-9_]{2,32}$`)

type loginReq struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type userInfo struct {
	ID       string `json:"id"`
	Username string `json:"username"`
}

type loginResp struct {
	Token string   `json:"token"`
	User  userInfo `json:"user"`
}

func hashSessionToken(raw string) string {
	h := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(h[:])
}

func generateSessionToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// BearerToken 从 Authorization: Bearer <token> 解析
func BearerToken(r *http.Request) string {
	h := strings.TrimSpace(r.Header.Get("Authorization"))
	if len(h) < 8 || !strings.EqualFold(h[:7], "Bearer ") {
		return ""
	}
	return strings.TrimSpace(h[7:])
}

// AuthUserID 校验 session，返回用户 id
func AuthUserID(r *http.Request, svcCtx *svc.ServiceContext) (string, bool) {
	raw := BearerToken(r)
	if raw == "" {
		return "", false
	}
	th := hashSessionToken(raw)
	var uid string
	err := svcCtx.DB.QueryRowContext(r.Context(), `
		SELECT user_id::text FROM sessions
		WHERE token_hash = $1 AND expires_at > now()`,
		th).Scan(&uid)
	if err != nil {
		return "", false
	}
	return uid, true
}

func validUsername(u string) bool {
	return usernameRe.MatchString(u)
}

// RegisterHandler POST /api/v1/auth/register — 第一版：用户名 + 密码
func RegisterHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		var req loginReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeErr(w, http.StatusBadRequest, "invalid json")
			return
		}
		u := strings.TrimSpace(req.Username)
		p := req.Password
		if u == "" || p == "" {
			writeErr(w, http.StatusBadRequest, "username and password required")
			return
		}
		if !validUsername(u) {
			writeErr(w, http.StatusBadRequest, "用户名 2–32 位，仅字母数字下划线")
			return
		}
		if len(p) < 6 {
			writeErr(w, http.StatusBadRequest, "密码至少 6 位")
			return
		}
		hashed, err := bcrypt.GenerateFromPassword([]byte(p), bcrypt.DefaultCost)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		var id string
		err = svcCtx.DB.QueryRowContext(r.Context(), `
			INSERT INTO users (username, password_hash)
			VALUES ($1, $2)
			RETURNING id::text`,
			u, string(hashed)).Scan(&id)
		if err != nil {
			if strings.Contains(err.Error(), "unique") || strings.Contains(err.Error(), "duplicate") {
				writeErr(w, http.StatusConflict, "用户名已存在")
				return
			}
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, map[string]any{
			"id":       id,
			"username": u,
		})
	}
}

// LoginHandler POST /api/v1/auth/login
func LoginHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		var req loginReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeErr(w, http.StatusBadRequest, "invalid json")
			return
		}
		u := strings.TrimSpace(req.Username)
		p := req.Password
		if u == "" || p == "" {
			writeErr(w, http.StatusBadRequest, "username and password required")
			return
		}
		var userID, hash string
		err := svcCtx.DB.QueryRowContext(r.Context(), `
			SELECT id::text, COALESCE(password_hash, '') FROM users WHERE username = $1`,
			u).Scan(&userID, &hash)
		if err == sql.ErrNoRows {
			writeErr(w, http.StatusUnauthorized, "用户名或密码错误")
			return
		}
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		if hash == "" {
			writeErr(w, http.StatusUnauthorized, "该账号尚未设置密码，请联系管理员或使用注册")
			return
		}
		if err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(p)); err != nil {
			writeErr(w, http.StatusUnauthorized, "用户名或密码错误")
			return
		}
		rawToken, err := generateSessionToken()
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		tokenHash := hashSessionToken(rawToken)
		expires := time.Now().Add(30 * 24 * time.Hour)
		_, err = svcCtx.DB.ExecContext(r.Context(), `
			INSERT INTO sessions (user_id, token_hash, expires_at)
			VALUES ($1::uuid, $2, $3)`,
			userID, tokenHash, expires)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		var resp loginResp
		resp.Token = rawToken
		resp.User.ID = userID
		resp.User.Username = u
		writeJSON(w, http.StatusOK, resp)
	}
}

// LogoutHandler POST /api/v1/auth/logout — 作废当前 token
func LogoutHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		raw := BearerToken(r)
		if raw == "" {
			writeErr(w, http.StatusUnauthorized, "missing token")
			return
		}
		th := hashSessionToken(raw)
		_, _ = svcCtx.DB.ExecContext(r.Context(), `DELETE FROM sessions WHERE token_hash = $1`, th)
		writeJSON(w, http.StatusOK, map[string]string{"ok": "true"})
	}
}

// MeHandler GET /api/v1/auth/me
func MeHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		uid, ok := AuthUserID(r, svcCtx)
		if !ok {
			writeErr(w, http.StatusUnauthorized, "未登录或 token 已失效")
			return
		}
		var username string
		err := svcCtx.DB.QueryRowContext(r.Context(), `
			SELECT username FROM users WHERE id = $1::uuid`, uid).Scan(&username)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, userInfo{ID: uid, Username: username})
	}
}
