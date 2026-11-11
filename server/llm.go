package main

import (
	"context"
	"fmt"
	"strings"

	"github.com/openai/openai-go"
	"github.com/openai/openai-go/option"
	"github.com/openai/openai-go/shared"
)

// LLMClient 抽象上游解析能力,便于 handler 测试注入 fake。
type LLMClient interface {
	// ParseText 解析口语记账文本,返回 LLM 输出的 JSON 字符串(原样,未二次解析)。
	ParseText(ctx context.Context, text string) (string, error)
}

// DeepSeekClient 基于 openai-go SDK 的 DeepSeek 客户端。
type DeepSeekClient struct {
	client openai.Client
	model  string
}

// NewDeepSeekClient 创建 DeepSeek 客户端。
func NewDeepSeekClient(cfg Config) *DeepSeekClient {
	return &DeepSeekClient{
		client: openai.NewClient(
			option.WithAPIKey(cfg.APIKey),
			option.WithBaseURL(cfg.BaseURL),
		),
		model: cfg.Model,
	}
}

// ParseText 调用 DeepSeek 解析文本。
// 上游非 200、空 choices、空 content、finish_reason 非 stop 均视为失败。
func (c *DeepSeekClient) ParseText(ctx context.Context, text string) (string, error) {
	// response_format 要求 DeepSeek 返回 JSON(OpenAI 兼容参数)
	rf := shared.NewResponseFormatJSONObjectParam()

	resp, err := c.client.Chat.Completions.New(ctx, openai.ChatCompletionNewParams{
		Model:    openai.ChatModel(c.model),
		Messages: buildMessages(text),
		ResponseFormat: openai.ChatCompletionNewParamsResponseFormatUnion{
			OfJSONObject: &rf,
		},
		Temperature: openai.Float(0.1),
		MaxTokens:   openai.Int(1024),
	})
	if err != nil {
		return "", fmt.Errorf("DeepSeek 调用失败: %w", err)
	}
	if len(resp.Choices) == 0 {
		return "", fmt.Errorf("DeepSeek 返回空 choices")
	}
	choice := resp.Choices[0]
	if choice.FinishReason != "stop" {
		return "", fmt.Errorf("DeepSeek 输出未正常结束: finish_reason=%q", choice.FinishReason)
	}
	if strings.TrimSpace(choice.Message.Content) == "" {
		return "", fmt.Errorf("DeepSeek 返回空 content")
	}
	return choice.Message.Content, nil
}
