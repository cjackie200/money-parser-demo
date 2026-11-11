package main

import "github.com/openai/openai-go"

// systemPrompt 指导 DeepSeek 将口语记账文本解析为 JSON。
// 注意: DeepSeek JSON 模式要求 prompt 中出现 "json" 字样。
const systemPrompt = `你是一个记账文本解析助手。将用户输入的中文口语记账文本解析为一个 json 对象,不要输出任何其他内容。

输出格式必须严格为:
{"entries":[{"amount":数字,"category":"分类","direction":"expense|income"}],"errors":[]}

规则:
- 分类只能从以下列表选择: 餐饮、购物、交通、居住、娱乐、医疗、教育、其他
- direction: expense 表示支出, income 表示收入
- 口语金额转数字:"五块八" → 5.8
- 多笔交易必须全部解析,不合并、不遗漏
- 无法解析时 errors 数组放入原因`

// buildMessages 构造请求消息: 系统提示词 + 用户输入。
func buildMessages(text string) []openai.ChatCompletionMessageParamUnion {
	return []openai.ChatCompletionMessageParamUnion{
		openai.SystemMessage(systemPrompt),
		openai.UserMessage(text),
	}
}
