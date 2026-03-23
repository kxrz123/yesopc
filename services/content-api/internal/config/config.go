package config

import "github.com/zeromicro/go-zero/rest"

// Config 应用配置：数据库连 Supabase Postgres，仅作存储，不经由 PostgREST。
type Config struct {
	rest.RestConf
	DataSource       string `json:",optional"`
	DefaultNotesUser string `json:",optional"`
	CORSAllowOrigin  string `json:",optional"`
	SupabaseURL      string `json:",optional"`
	SupabaseKey      string `json:",optional"` // service_role key，用于 Storage 上传
}

