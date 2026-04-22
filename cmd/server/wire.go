package main

import (
	"easydarwin/internal/conf"
	"easydarwin/internal/core/source"
	"easydarwin/internal/data"
	"easydarwin/internal/web/api"
	"fmt"
	"net/http"
	"strings" // 必须引入
)

func wireApp(cfg *conf.Bootstrap) (http.Handler, error) {
	db, err := data.SetupDB(cfg)
	if err != nil {
		return nil, err
	}

	// 核心修正：仅当配置中不含 @tcp（即非 MySQL）时才执行 SQLite 专属的 VACUUM 命令
	if !strings.Contains(cfg.Data.Dsn, "@tcp") {
		db.Exec("VACUUM;")
	}

	liveStreamcore := api.NewLiveStream(db)
	api.NewUserCore(db)
	api.NewVodCore(db)

	source.InitDb(liveStreamcore)
	handler := api.NewHTTPHandler(cfg)
	if handler == nil {
		return nil, fmt.Errorf("handle is nil")
	}
	data.SetConfig(cfg)
	return handler, nil
}
