package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"regexp"
	"strings"

	"yesopc.com/services/content-api/internal/config"
	"yesopc.com/services/content-api/internal/handler"
	"yesopc.com/services/content-api/internal/svc"

	"github.com/zeromicro/go-zero/core/conf"
	"github.com/zeromicro/go-zero/rest"
)

var configFile = flag.String("f", "etc/content-api.yaml", "配置文件路径")

func main() {
	flag.Parse()

	var c config.Config
	conf.MustLoad(*configFile, &c)

	if c.DataSource == "" {
		c.DataSource = os.Getenv("DATABASE_URL")
	}
	if c.DefaultNotesUser == "" {
		c.DefaultNotesUser = os.Getenv("DEFAULT_NOTES_USER_ID")
	}
	if c.CORSAllowOrigin == "" {
		c.CORSAllowOrigin = os.Getenv("CORS_ALLOW_ORIGIN")
	}
	if c.SupabaseURL == "" {
		c.SupabaseURL = os.Getenv("SUPABASE_URL")
	}
	if c.SupabaseKey == "" {
		c.SupabaseKey = os.Getenv("SUPABASE_SERVICE_ROLE_KEY")
	}

	// .env / 编辑器可能带入首尾换行或引号，导致 pgx 解析 URI 失败
	c.DataSource = normalizeDatabaseURL(c.DataSource)
	c.DefaultNotesUser = strings.TrimSpace(c.DefaultNotesUser)
	c.CORSAllowOrigin = strings.TrimSpace(c.CORSAllowOrigin)

	ctx, err := svc.NewServiceContext(c)
	if err != nil {
		log.Fatal(err)
	}
	defer func() { _ = ctx.DB.Close() }()

	server := rest.MustNewServer(c.RestConf)
	defer server.Stop()

	server.Use(corsMiddleware(c.CORSAllowOrigin))

	handler.RegisterRoutes(server, ctx)
	server.PrintRoutes()

	fmt.Printf("content-api 启动: http://%s:%d （浏览器打开根路径应看到 yesopc-content-api）\n", c.Host, c.Port)
	server.Start()
}

// Supabase 控制台复制的 URI 常见为 postgres:[密码]@host，方括号不是 URI 标准，Go 会报 invalid userinfo。
var postgresBracketPassword = regexp.MustCompile(`^(postgres(?:ql)?://[^:]+:)\[([^\]]*)\](@)`)

func normalizeDatabaseURL(s string) string {
	s = strings.TrimSpace(s)
	if len(s) >= 2 {
		if (s[0] == '"' && s[len(s)-1] == '"') || (s[0] == '\'' && s[len(s)-1] == '\'') {
			s = strings.TrimSpace(s[1 : len(s)-1])
		}
	}
	s = strings.ReplaceAll(s, "\r", "")
	s = strings.ReplaceAll(s, "\n", "")
	s = strings.TrimSpace(s)
	if postgresBracketPassword.MatchString(s) {
		s = postgresBracketPassword.ReplaceAllString(s, "${1}${2}${3}")
	}
	return s
}

func corsMiddleware(allowOrigin string) rest.Middleware {
	allowAll := strings.TrimSpace(allowOrigin) == "" || strings.TrimSpace(allowOrigin) == "*"
	allowedOrigins := make(map[string]struct{})
	if !allowAll {
		for _, o := range strings.Split(allowOrigin, ",") {
			v := strings.TrimSpace(o)
			if v != "" {
				allowedOrigins[v] = struct{}{}
			}
		}
		if len(allowedOrigins) == 0 {
			allowAll = true
		}
	}

	return func(next http.HandlerFunc) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			reqOrigin := strings.TrimSpace(r.Header.Get("Origin"))
			if allowAll {
				w.Header().Set("Access-Control-Allow-Origin", "*")
			} else if _, ok := allowedOrigins[reqOrigin]; ok {
				// 命中白名单时回写请求 Origin，兼容 localhost / 127.0.0.1 等多源调试。
				w.Header().Set("Access-Control-Allow-Origin", reqOrigin)
				w.Header().Set("Vary", "Origin")
			}
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}
			next(w, r)
		}
	}
}
