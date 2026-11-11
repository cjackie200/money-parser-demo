# server

money-parser-demo 的解析服务:调用 DeepSeek 将口语记账文本解析为结构化 JSON。

## 运行

```bash
export DEEPSEEK_API_KEY=sk-xxx
go run .
```

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `PORT` | `8080` | HTTP 监听端口 |
| `DEEPSEEK_API_KEY` | (必填) | DeepSeek API Key,缺失则启动失败 |
| `DEEPSEEK_BASE_URL` | `https://api.deepseek.com` | DeepSeek API 地址 |
| `DEEPSEEK_MODEL` | `deepseek-chat` | 模型名 |
| `PARSE_TIMEOUT_SECONDS` | `8` | 单次解析超时(秒) |

## 接口

- `POST /api/parse`,请求 `{"text":"午饭35,打车22.5"}`。成功时原样返回 LLM 的 JSON
  输出;失败时按约定返回 400/502,详见 `../docs/api_contract.md`。
- `GET /health` 返回 `{"status":"ok"}`。

## 测试

```bash
go test ./...
```
