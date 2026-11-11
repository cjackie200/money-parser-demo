package main

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

// fakeLLM 实现 LLMClient 接口,行为由测试定制。
type fakeLLM struct {
	content string // 成功时返回的内容
	err     error  // 返回的错误
	block   bool   // 为 true 时阻塞到 ctx 结束,模拟上游超时
}

func (f *fakeLLM) ParseText(ctx context.Context, _ string) (string, error) {
	if f.block {
		<-ctx.Done()
		return "", ctx.Err()
	}
	return f.content, f.err
}

// setupRouter 构造测试用路由。
func setupRouter(llm LLMClient, timeout time.Duration) *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.POST("/api/parse", ParseHandler(llm, timeout))
	r.GET("/health", HealthHandler)
	return r
}

// doParse 发起一次 POST /api/parse 请求。
func doParse(t *testing.T, llm LLMClient, timeout time.Duration, body string) *httptest.ResponseRecorder {
	t.Helper()
	r := setupRouter(llm, timeout)
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/parse", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	return w
}

// assertErrorBody 断言错误响应体与约定一致。
func assertErrorBody(t *testing.T, w *httptest.ResponseRecorder, wantMsg string) {
	t.Helper()
	var resp parseErrorResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("响应体不是合法 JSON: %v, body=%s", err, w.Body.String())
	}
	if !resp.ManualRequired {
		t.Errorf("manual_required 应为 true, body=%s", w.Body.String())
	}
	if len(resp.Errors) != 1 || resp.Errors[0] != wantMsg {
		t.Errorf("errors 应为 [%q], body=%s", wantMsg, w.Body.String())
	}
}

func TestParseEmptyText(t *testing.T) {
	w := doParse(t, &fakeLLM{}, 8*time.Second, `{"text":""}`)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("空 text 应返回 400, got=%d", w.Code)
	}
	assertErrorBody(t, w, "输入为空")
}

func TestParseWhitespaceText(t *testing.T) {
	w := doParse(t, &fakeLLM{}, 8*time.Second, `{"text":"   "}`)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("纯空白 text 应返回 400, got=%d", w.Code)
	}
	assertErrorBody(t, w, "输入为空")
}

func TestParseMalformedJSONBody(t *testing.T) {
	w := doParse(t, &fakeLLM{}, 8*time.Second, `{"text":`)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("畸形 JSON body 应返回 400, got=%d", w.Code)
	}
	assertErrorBody(t, w, "输入为空")
}

func TestParseLLMErrorReturns502(t *testing.T) {
	w := doParse(t, &fakeLLM{err: errors.New("上游 500")}, 8*time.Second, `{"text":"午饭35"}`)
	if w.Code != http.StatusBadGateway {
		t.Fatalf("LLM 返回错误时应返回 502, got=%d", w.Code)
	}
	assertErrorBody(t, w, "解析超时")
}

func TestParseTimeoutReturns502(t *testing.T) {
	// 注入 50ms 短超时,不用真等 8 秒
	w := doParse(t, &fakeLLM{block: true}, 50*time.Millisecond, `{"text":"午饭35"}`)
	if w.Code != http.StatusBadGateway {
		t.Fatalf("解析超时应返回 502, got=%d", w.Code)
	}
	assertErrorBody(t, w, "解析超时")
}

func TestParseSuccessPassthrough(t *testing.T) {
	// 带多余字段的 JSON:若 handler 做了二次解析再编码,extra_field 会丢失
	want := `{"entries":[{"amount":35,"category":"餐饮","direction":"expense"}],"errors":[],"extra_field":1}`
	w := doParse(t, &fakeLLM{content: want}, 8*time.Second, `{"text":"午饭35"}`)
	if w.Code != http.StatusOK {
		t.Fatalf("正常解析应返回 200, got=%d", w.Code)
	}
	if w.Body.String() != want {
		t.Errorf("成功响应必须与 LLM 输出字节级一致\ngot:  %s\nwant: %s", w.Body.String(), want)
	}
	if ct := w.Header().Get("Content-Type"); !strings.Contains(ct, "application/json") {
		t.Errorf("Content-Type 应为 application/json, got=%q", ct)
	}
}

func TestHealth(t *testing.T) {
	r := setupRouter(&fakeLLM{}, 8*time.Second)
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("GET /health 应返回 200, got=%d", w.Code)
	}
	if w.Body.String() != `{"status":"ok"}` {
		t.Errorf("GET /health 响应体应为 {\"status\":\"ok\"}, got=%s", w.Body.String())
	}
}
