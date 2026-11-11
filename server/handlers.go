package main

import (
	"context"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// maxBodyBytes 请求体上限,口语记账一句话远用不到 8KB,防止滥用。
const maxBodyBytes = 8 << 10

// parseRequest POST /api/parse 请求体。
type parseRequest struct {
	Text string `json:"text"`
}

// parseErrorResponse 错误响应,与 docs/api_contract.md 约定一致。
type parseErrorResponse struct {
	Errors         []string `json:"errors"`
	ManualRequired bool     `json:"manual_required"`
}

// ParseHandler 处理 POST /api/parse。
// timeout 作为参数注入,便于测试用短超时验证 502 路径。
func ParseHandler(llm LLMClient, timeout time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBodyBytes)

		var req parseRequest
		if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.Text) == "" {
			c.JSON(http.StatusBadRequest, parseErrorResponse{
				Errors:         []string{"输入为空"},
				ManualRequired: true,
			})
			return
		}

		ctx, cancel := context.WithTimeout(c.Request.Context(), timeout)
		defer cancel()

		content, err := llm.ParseText(ctx, req.Text)
		if err != nil {
			// 真实原因只写服务端日志,对外统一按约定返回
			log.Printf("解析失败: %v", err)
			c.JSON(http.StatusBadGateway, parseErrorResponse{
				Errors:         []string{"解析超时"},
				ManualRequired: true,
			})
			return
		}

		// 原样透传 LLM 输出,不做二次解析
		c.Data(http.StatusOK, "application/json; charset=utf-8", []byte(content))
	}
}

// HealthHandler 处理 GET /health。
func HealthHandler(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
