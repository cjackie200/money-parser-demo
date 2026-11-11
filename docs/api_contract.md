POST /api/parse
Body: {"text":"午饭35,打车22.5"}

200 成功:
{"entries":[{"amount":35.0, "category":"餐饮", "direction":"expense"}, {"amount":22.5, "category":"交通", "direction":"expense"}], "errors":[]}

502 上游超时/失败:
{"errors":["解析超时"], "manual_required":true}

400 空输入
{"errors":["输入为空"], "manual_required":true}