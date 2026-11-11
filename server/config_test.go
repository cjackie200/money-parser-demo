package main

import (
	"testing"
	"time"
)

// clearConfigEnv 清空所有配置相关环境变量,保证测试不受外部环境影响。
func clearConfigEnv(t *testing.T) {
	t.Helper()
	for _, key := range []string{
		"PORT", "DEEPSEEK_API_KEY", "DEEPSEEK_BASE_URL", "DEEPSEEK_MODEL", "PARSE_TIMEOUT_SECONDS",
	} {
		t.Setenv(key, "")
	}
}

func TestLoadConfigMissingAPIKey(t *testing.T) {
	clearConfigEnv(t)

	if _, err := LoadConfig(); err == nil {
		t.Fatal("缺少 DEEPSEEK_API_KEY 时 LoadConfig 应返回错误")
	}
}

func TestLoadConfigDefaults(t *testing.T) {
	clearConfigEnv(t)
	t.Setenv("DEEPSEEK_API_KEY", "sk-test")

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatalf("LoadConfig 意外失败: %v", err)
	}
	if cfg.Port != "8080" {
		t.Errorf("Port 默认值应为 8080, got=%q", cfg.Port)
	}
	if cfg.BaseURL != "https://api.deepseek.com" {
		t.Errorf("BaseURL 默认值应为 https://api.deepseek.com, got=%q", cfg.BaseURL)
	}
	if cfg.Model != "deepseek-chat" {
		t.Errorf("Model 默认值应为 deepseek-chat, got=%q", cfg.Model)
	}
	if cfg.ParseTimeout != 8*time.Second {
		t.Errorf("ParseTimeout 默认值应为 8s, got=%v", cfg.ParseTimeout)
	}
}

func TestLoadConfigOverrides(t *testing.T) {
	clearConfigEnv(t)
	t.Setenv("DEEPSEEK_API_KEY", "sk-test")
	t.Setenv("PORT", "9090")
	t.Setenv("DEEPSEEK_BASE_URL", "https://example.com")
	t.Setenv("DEEPSEEK_MODEL", "deepseek-reasoner")
	t.Setenv("PARSE_TIMEOUT_SECONDS", "3")

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatalf("LoadConfig 意外失败: %v", err)
	}
	if cfg.Port != "9090" {
		t.Errorf("Port 应为 9090, got=%q", cfg.Port)
	}
	if cfg.BaseURL != "https://example.com" {
		t.Errorf("BaseURL 应为 https://example.com, got=%q", cfg.BaseURL)
	}
	if cfg.Model != "deepseek-reasoner" {
		t.Errorf("Model 应为 deepseek-reasoner, got=%q", cfg.Model)
	}
	if cfg.ParseTimeout != 3*time.Second {
		t.Errorf("ParseTimeout 应为 3s, got=%v", cfg.ParseTimeout)
	}
}

func TestLoadConfigInvalidTimeout(t *testing.T) {
	clearConfigEnv(t)
	t.Setenv("DEEPSEEK_API_KEY", "sk-test")

	t.Setenv("PARSE_TIMEOUT_SECONDS", "abc")
	if _, err := LoadConfig(); err == nil {
		t.Fatal("非数字超时值应返回错误")
	}

	t.Setenv("PARSE_TIMEOUT_SECONDS", "0")
	if _, err := LoadConfig(); err == nil {
		t.Fatal("超时值为 0 应返回错误")
	}
}
