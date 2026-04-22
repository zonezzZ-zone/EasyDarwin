package data

import (
	"easydarwin/internal/conf"
	"github.com/redis/go-redis/v9"
	"path/filepath"
	"strings"
	"time"

	"easydarwin/utils/pkg/orm"
	"easydarwin/utils/pkg/system"

	"github.com/glebarez/sqlite"
	"gorm.io/driver/mysql"    // 核心新增：必须引入 MySQL 驱动
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var DB *gorm.DB

var config *conf.Bootstrap

// SetupDB 初始化数据存储
func SetupDB(c *conf.Bootstrap) (*gorm.DB, error) {
	cfg := c.Data
	dial, isSQLite := getDialector(cfg.Dsn)
	
	// 如果是 SQLite，强制限制连接池（SQLite 不支持高并发连接）
	if isSQLite {
		cfg.MaxIdleConns = 1
		cfg.MaxOpenConns = 1
	}

	db, err := orm.New(true, dial, orm.Config{
		MaxIdleConns:    int(cfg.MaxIdleConns),
		MaxOpenConns:    int(cfg.MaxOpenConns),
		ConnMaxLifetime: time.Duration(cfg.ConnMaxLifetime) * time.Second,
		SlowThreshold:   time.Duration(cfg.SlowThreshold) * time.Millisecond,
	})
	DB = db
	return db, err
}

func GetDatabase() *gorm.DB {
	return DB
}

func GetConfig() *conf.Bootstrap {
	return config
}
func SetConfig(c *conf.Bootstrap) {
	config = c
}

// SetupCache 初始化缓存
func SetupCache() *redis.Client {
	return RedisCli
}

// getDialector 返回 dial 和 是否 sqlite
func getDialector(dsn string) (gorm.Dialector, bool) {
	// 修正点 1：增加 MySQL 识别逻辑
	if strings.Contains(dsn, "@tcp") {
		return mysql.Open(dsn), false
	}

	// 修正点 2：Postgres 保持不变
	if strings.HasPrefix(dsn, "postgres") {
		return postgres.New(postgres.Config{
			DriverName: "pgx",
			DSN:        dsn,
		}), false
	}

	// 修正点 3：只有既不是 MySQL 也不是 Postgres，才走 SQLite
	// 之前的 Error 14 就是因为 MySQL 字符串掉进了这里，被当成了文件名
	return sqlite.Open(filepath.Join(system.GetCWD(), dsn)), true
}
