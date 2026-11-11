package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// chatCompletionBody 构造 OpenAI 兼容格式的 chat completion 响应体。
func chatCompletionBody(content, finishReason string) string {
	payload := map[string]any{
		"choices": []any{
			map[string]any{
				"message":       map[string]any{"role": "assistant", "content": content},
				"finish_reason": finishReason,
			},
		},
	}
	b, _ := json.Marshal(payload)
	return string(b)
}

// newTestDeepSeekClient 用假上游构造 DeepSeekClient。
func newTestDeepSeekClient(t *testing.T, handler http.HandlerFunc) *DeepSeekClient {
	t.Helper()
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	return NewDeepSeekClient(Config{
		APIKey:  "test-key",
		BaseURL: srv.URL,
		Model:   "deepseek-chat",
	})
}

func TestParseTextUpstream500(t *testing.T) {
	client := newTestDeepSeekClient(t, func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	})

	if _, err := client.ParseText(context.Background(), "午饭35"); err == nil {
		t.Fatal("上游 500 应返回 error")
	}
}

func TestParseTextEmptyChoices(t *testing.T) {
	client := newTestDeepSeekClient(t, func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"choices":[]}`)
	})

	if _, err := client.ParseText(context.Background(), "午饭35"); err == nil {
		t.Fatal("choices 为空应返回 error")
	}
}

func TestParseTextFinishReasonLength(t *testing.T) {
	body := chatCompletionBody(`{"entries":[]}`, "length")
	client := newTestDeepSeekClient(t, func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, body)
	})

	if _, err := client.ParseText(context.Background(), "午饭35"); err == nil {
		t.Fatal("finish_reason=length 应返回 error")
	}
}

func TestParseTextBlankContent(t *testing.T) {
	body := chatCompletionBody("   ", "stop")
	client := newTestDeepSeekClient(t, func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, body)
	})

	if _, err := client.ParseText(context.Background(), "午饭35"); err == nil {
		t.Fatal("content 为纯空白应返回 error")
	}
}

func TestParseTextSuccessPassthrough(t *testing.T) {
	want := `{"entries":[{"amount":35,"category":"餐饮","direction":"expense"}],"errors":[]}`
	body := chatCompletionBody(want, "stop")
	client := newTestDeepSeekClient(t, func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, body)
	})

	got, err := client.ParseText(context.Background(), "午饭35")
	if err != nil {
		t.Fatalf("正常响应不应报错: %v", err)
	}
	if got != want {
		t.Errorf("应原样返回上游 content\ngot:  %q\nwant: %q", got, want)
	}
}

func TestParseTextRequestParams(t *testing.T) {
	body := chatCompletionBody(`{"entries":[]}`, "stop")
	var (
		gotPath string
		gotAuth string
		gotBody []byte
	)
	client := newTestDeepSeekClient(t, func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		gotAuth = r.Header.Get("Authorization")
		gotBody, _ = io.ReadAll(r.Body)
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, body)
	})

	if _, err := client.ParseText(context.Background(), "午饭35"); err != nil {
		t.Fatalf("ParseText 意外失败: %v", err)
	}

	if gotPath != "/chat/completions" {
		t.Errorf("请求路径应为 /chat/completions, got=%q", gotPath)
	}
	if gotAuth != "Bearer test-key" {
		t.Errorf("Authorization 头应为 Bearer test-key, got=%q", gotAuth)
	}

	var req struct {
		Model          string  `json:"model"`
		MaxTokens      int64   `json:"max_tokens"`
		Temperature    float64 `json:"temperature"`
		ResponseFormat struct {
			Type string `json:"type"`
		} `json:"response_format"`
		Messages []struct {
			Role    string `json:"role"`
			Content string `json:"content"`
		} `json:"messages"`
	}
	if err := json.Unmarshal(gotBody, &req); err != nil {
		t.Fatalf("请求体解析失败: %v, body=%s", err, gotBody)
	}
	if req.Model != "deepseek-chat" {
		t.Errorf("model 应为 deepseek-chat, got=%q", req.Model)
	}
	if req.MaxTokens != 1024 {
		t.Errorf("max_tokens 应为 1024, got=%d", req.MaxTokens)
	}
	if req.Temperature != 0.1 {
		t.Errorf("temperature 应为 0.1, got=%v", req.Temperature)
	}
	if req.ResponseFormat.Type != "json_object" {
		t.Errorf("response_format.type 应为 json_object, got=%q", req.ResponseFormat.Type)
	}
	if len(req.Messages) != 2 {
		t.Fatalf("messages 应有 2 条, got=%d", len(req.Messages))
	}
	if req.Messages[0].Role != "system" || !strings.Contains(req.Messages[0].Content, "json") {
		t.Errorf("第一条消息应为含 json 字样的 system 消息, got role=%q content=%q",
			req.Messages[0].Role, req.Messages[0].Content)
	}
	if req.Messages[1].Role != "user" || req.Messages[1].Content != "午饭35" {
		t.Errorf("第二条消息应为用户输入, got role=%q content=%q",
			req.Messages[1].Role, req.Messages[1].Content)
	}
}
