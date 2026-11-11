package main

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

// Config 服务配置,全部来自环境变量。
type Config struct {
	Port         string        // HTTP 监听端口
	APIKey       string        // DeepSeek API Key
	BaseURL      string        // DeepSeek API 地址(OpenAI 兼容)
	Model        string        // 模型名
	ParseTimeout time.Duration // 单次解析超时
}

// LoadConfig 从环境变量加载配置,缺少 API Key 时返回错误。
func LoadConfig() (*Config, error) {
	cfg := &Config{
		Port:         getenv("PORT", "8080"),
		APIKey:       os.Getenv("DEEPSEEK_API_KEY"),
		BaseURL:      getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com"),
		Model:        getenv("DEEPSEEK_MODEL", "deepseek-chat"),
		ParseTimeout: 8 * time.Second,
	}

	if secs := os.Getenv("PARSE_TIMEOUT_SECONDS"); secs != "" {
		n, err := strconv.Atoi(secs)
		if err != nil || n <= 0 {
			return nil, fmt.Errorf("PARSE_TIMEOUT_SECONDS 非法: %q", secs)
		}
		cfg.ParseTimeout = time.Duration(n) * time.Second
	}

	if cfg.APIKey == "" {
		return nil, fmt.Errorf("缺少 DEEPSEEK_API_KEY 环境变量")
	}
	return cfg, nil
}

// getenv 返回环境变量值,为空时返回默认值。
func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
