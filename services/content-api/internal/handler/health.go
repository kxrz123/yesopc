package handler

import "net/http"

// RootHandler GET / — 确认当前 8888 是否为 YesOPC content-api（若 404 说明 IP/端口指错或不是本服务）
func RootHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{
			"service": "yesopc-content-api",
			"health":  "/api/v1/health",
			"login":   "POST /api/v1/auth/login",
		})
	}
}

// HealthHandler GET /api/v1/health — 用于确认服务与路由已加载（真机/调试可访问）
func HealthHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{
			"ok":      "true",
			"service": "content-api",
		})
	}
}
