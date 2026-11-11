# money-parser-demo

口语记账解析 demo:把「午饭35,打车22.5」这样的自然语言解析成结构化账目(金额 + 分类 + 方向),服务端调 DeepSeek 完成解析,Flutter App 负责交互展示。验证目标见 `docs/scope.md` 的 P0。

## 架构

```
┌──────────────┐   POST /api/parse   ┌──────────────────────┐   OpenAI 兼容   ┌──────────┐
│  Flutter App │ ──────────────────► │  Go + Gin 解析服务    │ ──────────────► │ DeepSeek │
│   (./app)    │ ◄────────────────── │      (./server)      │ ◄────────────── │ (LLM)    │
└──────────────┘   原样透传 LLM JSON  └──────────────────────┘                 └──────────┘
```

- `server/` — Go + Gin 服务,8s 超时调 DeepSeek(`response_format: json_object`),LLM 输出原样透传
- `app/` — Flutter 单页:输入 → 解析(loading 防重复)→ 列表**累计、最新在上**;失败红色 SnackBar,「手动添加」入口始终可用(本地表单,不走网络)
- `docs/` — 契约(`api_contract.md`)、验收范围(`scope.md`)、各阶段实现计划与真机验收说明

## 服务端

```bash
cd server
export DEEPSEEK_API_KEY=sk-xxx   # 必填,缺失则启动失败
go run .
```

| 环境变量 | 默认值 | 说明 |
|---|---|---|
| `PORT` | `8080` | HTTP 监听端口 |
| `DEEPSEEK_API_KEY` | (必填) | DeepSeek API Key |
| `DEEPSEEK_BASE_URL` | `https://api.deepseek.com` | DeepSeek API 地址 |
| `DEEPSEEK_MODEL` | `deepseek-chat` | 模型名 |
| `PARSE_TIMEOUT_SECONDS` | `8` | 单次解析超时(秒) |

接口契约(`docs/api_contract.md`):

- `POST /api/parse`,body `{"text":"午饭35,打车22.5"}` —— 200 原样返回 LLM JSON;空输入 400;超时/上游失败 502(均含 `manual_required:true`)
- `GET /health` → `{"status":"ok"}`

## App

```bash
cd app
flutter run          # Android 模拟器自动走 http://10.0.2.2:8080;其他平台 http://localhost:8080
flutter run --dart-define=BASE_URL=http://<你的服务地址>:8080   # 真机/自定义地址
```

功能:顶部输入框 →「解析」→ 列表累计展示(最新在上);「手动添加」弹底部表单(金额/8 项分类/支出收入),金额非法时表单内提示;4xx/5xx/超时/断网统一红色 SnackBar,不崩溃、手动入口始终可见。

## 测试

```bash
cd server && go test ./...        # 16 个: handler + DeepSeek 客户端 + 配置
cd app && flutter test            # 18 个: widget + ParseApi
```

## 文档索引

| 文档 | 内容 |
|---|---|
| `docs/scope.md` | 核心需求与 P0 验收项 |
| `docs/api_contract.md` | 前后端接口契约 |
| `docs/server_plan.md` | 服务端实现计划(已确认) |
| `docs/app_plan.md` | App UI 骨架实现计划 |
| `docs/app_api_plan.md` | 接口接入计划(含真机验收修订) |

## 环境要求

- Go ≥ 1.26
- Flutter 3.47+(Android 模拟器需 Android SDK 36 与 JDK 21;iOS 需完整 Xcode)
