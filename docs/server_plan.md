# Parse 服务实现计划(已确认)

> 状态:已确认(2026-11-11)。服务端代码位于 `./server`。

## 目标

用 Go + Gin 实现口语记账文本解析服务,调用 DeepSeek(OpenAI 兼容 API)将文本解析为结构化 JSON,原样透传给客户端。

## 技术选型

| 项 | 决定 |
|---|---|
| 模块名 | `github.com/cjackie200/money-parser-demo/server`(与 git remote 一致) |
| Go 版本 | 1.26.2 |
| HTTP 层 | gin(最新稳定版) |
| LLM 客户端 | `github.com/openai/openai-go`(官方 SDK,`BaseURL` 指向 DeepSeek) |
| 模型 | `deepseek-chat`,API 地址 `https://api.deepseek.com` |
| CORS | 不加(客户端为安卓/iOS 原生 App,无浏览器同源限制) |

## 文件结构

```
server/
├── go.mod             // module github.com/cjackie200/money-parser-demo/server
├── main.go            // 装配: 加载配置 → 建 client → 注册路由 → 启动 http.Server
├── config.go          // Config 结构体 + LoadConfig() 读环境变量
├── prompt.go          // 系统提示词(固定分类表)+ buildMessages() 构造请求消息
├── llm.go             // LLMClient 接口 + DeepSeekClient(openai-go 封装)
├── handlers.go        // ParseHandler / HealthHandler
├── handlers_test.go   // handler 层单测(fake LLMClient,不真实调 DeepSeek)
├── llm_test.go        // DeepSeekClient 单测(httptest.Server 模拟上游)
└── README.md          // 运行方式 + 环境变量 + 接口说明
```

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `PORT` | `8080` | HTTP 监听端口 |
| `DEEPSEEK_API_KEY` | (必填) | 缺失则启动失败 |
| `DEEPSEEK_BASE_URL` | `https://api.deepseek.com` | DeepSeek API 地址 |
| `DEEPSEEK_MODEL` | `deepseek-chat` | 模型名 |
| `PARSE_TIMEOUT_SECONDS` | `8` | 单次解析超时(秒) |

## 关键函数签名

```go
// config.go
type Config struct {
    Port         string        // env PORT,默认 "8080"
    APIKey       string        // env DEEPSEEK_API_KEY,必填
    BaseURL      string        // env DEEPSEEK_BASE_URL,默认 "https://api.deepseek.com"
    Model        string        // env DEEPSEEK_MODEL,默认 "deepseek-chat"
    ParseTimeout time.Duration // env PARSE_TIMEOUT_SECONDS,默认 8s
}
func LoadConfig() (*Config, error) // APIKey 为空返回 error,main 直接退出

// llm.go —— 接口化便于测试注入 fake
type LLMClient interface {
    // ParseText 调用 LLM 解析口语记账文本,返回 LLM 输出的 JSON 字符串(原样,未二次解析)
    ParseText(ctx context.Context, text string) (string, error)
}
type DeepSeekClient struct { client *openai.Client; model string }
func NewDeepSeekClient(cfg Config) *DeepSeekClient
func (c *DeepSeekClient) ParseText(ctx context.Context, text string) (string, error)

// handlers.go
type parseRequest struct { Text string `json:"text"` }
type parseErrorResponse struct {
    Errors         []string `json:"errors"`
    ManualRequired bool     `json:"manual_required"`
}
func ParseHandler(llm LLMClient, timeout time.Duration) gin.HandlerFunc
func HealthHandler(c *gin.Context)
```

`timeout` 作为参数注入而非包级常量,单测可用 50ms 快速验证超时路径。

## 处理流程

### POST /api/parse

1. 请求体限 8KB(`http.MaxBytesReader`),`ShouldBindJSON` 失败或 `strings.TrimSpace(text)==""`
   → **400** `{"errors":["输入为空"],"manual_required":true}`
2. `context.WithTimeout(r.Context(), 8s)`
3. `ParseText` 返回 error → **502** `{"errors":["解析超时"],"manual_required":true}`,错误细节只写服务端日志
4. 成功 → `c.Data(200, "application/json; charset=utf-8", []byte(content))`,
   **原样透传字节,不 Unmarshal 再 Marshal**

### GET /health

→ `200 {"status":"ok"}`

## http.Server 超时策略

| 项 | 值 | 说明 |
|---|---|---|
| `ReadHeaderTimeout` | 5s | 防慢连接 |
| `WriteTimeout` | 15s | **必须大于 8s 解析超时**,否则响应会被提前掐断 |
| `IdleTimeout` | 60s | keep-alive 连接卫生 |

## DeepSeek 调用参数与失败判定

| 项 | 值 |
|---|---|
| `response_format` | `{"type":"json_object"}` |
| `temperature` | 0.1(显式,保证多次解析结果稳定) |
| `max_tokens` | 1024(防截断) |
| 重试 | 保留 openai-go 默认(2 次,仅 429/5xx/连接错误),受 8s context 约束,不会突破超时 |

`ParseText` 视为失败的场景(→ 返回 error → 502):

- 上游非 200(openai-go 抛 apierror)
- `len(resp.Choices) == 0`
- `strings.TrimSpace(content) == ""`(DeepSeek JSON 模式会把非法输出替换为空格)
- `finish_reason != "stop"`(含 `length` 截断,此时 content 是残缺 JSON)

## 系统提示词(固定分类表)

```
你是一个记账文本解析助手。将用户输入的中文口语记账文本解析为一个 json 对象,不要输出任何其他内容。

输出格式必须严格为:
{"entries":[{"amount":数字,"category":"分类","direction":"expense|income"}],"errors":[]}

规则:
- 分类只能从以下列表选择: 餐饮、购物、交通、居住、娱乐、医疗、教育、其他
- direction: expense 表示支出, income 表示收入
- 口语金额转数字:"五块八" → 5.8
- 多笔交易必须全部解析,不合并、不遗漏
- 无法解析时 errors 数组放入原因
```

(DeepSeek JSON 模式要求 prompt 中出现 "json" 字样,已包含。)

## 测试计划

### handlers_test.go(fake LLMClient,测 handler 行为)

| 用例 | 断言 |
|---|---|
| 空 text / 纯空白 / 畸形 JSON body | 400 + `manual_required:true` |
| fake 返回 error | 502 + `errors:["解析超时"]` |
| fake 阻塞到 ctx 超时(注入 50ms 短超时) | 502 |
| fake 返回任意 JSON 字符串 | 200,body 字节级一致(证无二次解析) |
| GET /health | 200 `{"status":"ok"}` |

### llm_test.go(httptest.Server 模拟 DeepSeek 上游,直测 DeepSeekClient)

| 用例 | 断言 |
|---|---|
| 上游返回 500 | error |
| `choices` 为空数组 | error |
| `finish_reason: "length"` | error |
| content 为纯空格 | error |
| 正常 JSON | 原样返回 |
| 请求参数(解包上游收到的 body) | `model=deepseek-chat`、`response_format.type=json_object`、`temperature=0.1`、`max_tokens=1024`、`Authorization: Bearer ***` |

## 决策记录

- 上游非 200 与超时统一返回 502 + `解析超时` 文案(严格按 spec;真实原因仅入服务端日志)
- 空 content / 截断视为失败 → 502(DeepSeek 官方文档警告 JSON 模式会用空格清空非法输出)
- 无 CORS:客户端为安卓/iOS 原生 App
- 分类表 8 项:餐饮、购物、交通、居住、娱乐、医疗、教育、其他
