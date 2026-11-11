package main

import (
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

func main() {
	cfg, err := LoadConfig()
	if err != nil {
		log.Fatalf("配置加载失败: %v", err)
	}

	client := NewDeepSeekClient(*cfg)

	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	r.POST("/api/parse", ParseHandler(client, cfg.ParseTimeout))
	r.GET("/health", HealthHandler)

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           r,
		ReadHeaderTimeout: 5 * time.Second,
		// WriteTimeout 必须大于 8s 解析超时,否则正常响应会被提前掐断
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	log.Printf("服务启动,监听 :%s", cfg.Port)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("服务异常退出: %v", err)
	}
}
