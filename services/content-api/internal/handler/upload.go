package handler

import (
	"fmt"
	"io"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"yesopc.com/services/content-api/internal/svc"
)

const maxUploadSize = 5 << 20 // 5 MB

// UploadHandler POST /api/v1/upload
// 接收 multipart file，上传到 Supabase Storage covers bucket，返回公开 URL。
func UploadHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		if _, ok := AuthUserID(r, svcCtx); !ok {
			writeErr(w, http.StatusUnauthorized, "请先登录")
			return
		}

		supaURL := strings.TrimRight(svcCtx.Config.SupabaseURL, "/")
		supaKey := svcCtx.Config.SupabaseKey
		if supaURL == "" || supaKey == "" {
			writeErr(w, http.StatusInternalServerError, "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 未配置")
			return
		}

		r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)
		if err := r.ParseMultipartForm(maxUploadSize); err != nil {
			writeErr(w, http.StatusBadRequest, "文件过大（最大 5MB）")
			return
		}

		file, header, err := r.FormFile("file")
		if err != nil {
			writeErr(w, http.StatusBadRequest, "缺少 file 字段")
			return
		}
		defer file.Close()

		ext := strings.ToLower(filepath.Ext(header.Filename))
		if ext == "" {
			ext = ".png"
		}
		allowed := map[string]bool{".jpg": true, ".jpeg": true, ".png": true, ".gif": true, ".webp": true}
		if !allowed[ext] {
			writeErr(w, http.StatusBadRequest, "仅支持 jpg/png/gif/webp")
			return
		}

		objectName := fmt.Sprintf("%d%s", time.Now().UnixMilli(), ext)

		contentType := header.Header.Get("Content-Type")
		if contentType == "" {
			contentType = "application/octet-stream"
		}

		uploadURL := fmt.Sprintf("%s/storage/v1/object/covers/%s", supaURL, objectName)

		req, err := http.NewRequestWithContext(r.Context(), http.MethodPost, uploadURL, file)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, err.Error())
			return
		}
		req.Header.Set("apikey", supaKey)
		req.Header.Set("Content-Type", contentType)
		req.Header.Set("x-upsert", "true")

		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			writeErr(w, http.StatusBadGateway, "上传 Storage 失败: "+err.Error())
			return
		}
		defer resp.Body.Close()

		if resp.StatusCode >= 300 {
			body, _ := io.ReadAll(resp.Body)
			writeErr(w, http.StatusBadGateway, fmt.Sprintf("Storage 返回 %d: %s", resp.StatusCode, string(body)))
			return
		}

		publicURL := fmt.Sprintf("%s/storage/v1/object/public/covers/%s", supaURL, objectName)
		writeJSON(w, http.StatusOK, map[string]string{"url": publicURL})
	}
}
