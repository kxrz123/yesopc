package svc

import (
	"database/sql"
	"fmt"

	"yesopc.com/services/content-api/internal/config"

	_ "github.com/jackc/pgx/v5/stdlib"
)

type ServiceContext struct {
	Config config.Config
	DB     *sql.DB
}

func NewServiceContext(c config.Config) (*ServiceContext, error) {
	if c.DataSource == "" {
		return nil, fmt.Errorf("DATABASE_URL 未配置")
	}
	db, err := sql.Open("pgx", c.DataSource)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(2)
	if err := db.Ping(); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("数据库连接失败: %w", err)
	}
	return &ServiceContext{Config: c, DB: db}, nil
}

