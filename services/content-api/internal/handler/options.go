package handler

import "net/http"

// OptionsHandler 统一处理浏览器 CORS 预检请求。
func OptionsHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}
}
