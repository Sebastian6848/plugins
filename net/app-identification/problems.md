# AppIdentification 插件改造任务

## 项目背景
这是一个 OPNsense 插件，集成 ntopng 的流量监控能力。插件目录结构为：
- src/opnsense/mvc/app/...

ntopng 活动流 API 返回的单条流数据结构如下：
{
  "key": "3491564609",
  "protocol": { "l4": "TCP", "l7": "TLS.Alibaba" },
  "client": { "ip": "10.10.10.132", "name": "xwy-virtual-machine", "port": 34118 },
  "server": { "ip": "198.18.0.49", "name": "g.alicdn.com", "port": 443 },
  "bytes": 1406847,
  "duration": 2,
  "breakdown": { "cli2srv": 2, "srv2cli": 98 },
  "thpt": { "bps": 0.0, "pps": 0.0 }
}

其中 server.name 是 TLS SNI 解析出的真实域名（最重要的匹配字段），server.ip 是透明代理虚拟 IP（不可靠，不建议作为主要匹配依据）。

---

## 任务一：扩展 Model（AppIdentification.xml）

在现有 <items> 节点内，追加一个名为 rules 的 ArrayField 节点，用于持久化存储自定义规则。

每条规则包含以下字段：
- enabled：BooleanField，默认 1
- description：TextField，非必填
- match_type：OptionField，必填，默认 domain，选项为：
  - domain：域名子串匹配（匹配 server.name）
  - ip：精确 IP 匹配（匹配 server.ip 或 client.ip）
  - cidr：CIDR 范围匹配（匹配 server.ip 或 client.ip）
  - port：目标端口匹配（匹配 server.port）
- match_value：TextField，必填，存储匹配的具体值
- app_label：TextField，必填，存储用户自定义的应用标签名

---

## 任务二：更新规则编辑表单（dialogRule.xml）

完整替换现有内容，表单字段对应 Model 中 rule 节点的五个字段：
enabled、description、match_type（dropdown 类型）、match_value、app_label。
每个字段需要有合适的 label 和 help 说明文字。

---

## 任务三：实现 RuleController.php

路径：Api/RuleController.php
继承 ApiMutableModelControllerBase，model 指向 AppIdentification。

需要实现以下接口：
- GET  /api/appidentification/rule/searchRules   分页查询规则列表，返回所有字段
- GET  /api/appidentification/rule/getRule/{uuid}  获取单条规则
- POST /api/appidentification/rule/addRule         新增规则
- POST /api/appidentification/rule/setRule/{uuid}  更新规则
- POST /api/appidentification/rule/delRule/{uuid}  删除规则
- POST /api/appidentification/rule/toggleRule/{uuid} 启用/禁用规则
- GET  /api/appidentification/rule/list            返回所有已启用规则的简单数组，
                                                   供前端 JS 做流量匹配用，
                                                   无需分页，直接返回 {rules: [...]}

---

## 任务四：改造自定义规则管理页面

使用 OPNsense 标准 UIBootgrid 组件渲染规则表格，列包括：
启用状态、描述、匹配类型、匹配值、应用标签、操作（编辑/删除）。

表格底部有新增按钮，点击弹出 DialogRule 模态框，
模态框加载 dialogRule.xml 对应的表单，保存后刷新表格。

---

## 任务五：改造活动流页面，加入自定义规则匹配

在活动流页面初始化时，调用一次 /api/appidentification/rule/list 获取规则列表并缓存到 JS 变量。

在渲染每条流的协议/应用列时，用缓存的规则列表对该条流做匹配：

匹配逻辑（按优先级顺序，第一个命中即返回对应 app_label）：
1. match_type=domain：检查 server.name 是否包含 match_value（子串匹配，不区分大小写）
2. match_type=ip：检查 server.ip 或 client.ip 是否等于 match_value
3. match_type=cidr：检查 server.ip 或 client.ip 是否在 match_value 的 CIDR 范围内
4. match_type=port：检查 server.port 是否等于 match_value

如果有匹配，在协议列用带有特殊样式（如蓝色 label）的标签显示 app_label，
同时保留原始 protocol.l7 作为 tooltip 或次要显示，让用户知道底层协议仍是什么。

如果没有匹配，按原有逻辑显示 protocol.l7。

规则列表只在页面初始化时加载一次，之后每次刷新流量表格直接复用缓存，不重复请求。

---

## 注意事项

1. RuleController 中 list 接口只返回 enabled=1 的规则。
2. 域名匹配使用子串匹配，例如规则值 alicdn.com 能同时命中 g.alicdn.com 和 img.alicdn.com。
3. CIDR 匹配需要在前端 JS 中实现 IPv4 的位运算判断。
4. 活动流页面的规则匹配完全在前端 JS 完成，不需要后端参与计算。
5. 不要删除或破坏现有的 general 配置页面、活动流页面、应用范围页面的任何已有功能。
