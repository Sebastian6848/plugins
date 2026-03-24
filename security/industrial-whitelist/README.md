# Industrial Whitelist Plugin (MVP)

## 1. 插件目标

Industrial Whitelist 是一个面向工业协议场景的 OPNsense 防火墙插件，提供“白名单放行 + 默认动作控制”的最小可用能力。

当前实现目标：
- 对 Modbus TCP (502) / S7Comm (102) 建立白名单规则。
- 允许按源地址、目的地址、协议类型进行规则管理。
- 未命中白名单时执行默认动作（Block 或 Log Only）。
- 提供独立配置页与日志页。

---

## 2. 当前已实现功能

### 2.1 菜单与页面结构

侧边栏路径：
- Firewall -> Industrial Whitelist -> Configuration
- Firewall -> Industrial Whitelist -> Logs

其中：
- Configuration 页内包含 2 个 Tab：
  - General Settings
  - Rules
- Logs 页为独立页面，用于展示与插件规则相关的日志记录。

---

### 2.2 General Settings

已实现字段：
- Enable
  - 开启/关闭插件托管规则同步。
- Default Action
  - `block`
  - `log_only`

Apply 行为：
- 点击 Apply 后调用后端 reconfigure 接口。
- 后端先同步托管 Alias + 原生 Firewall Rules，再执行 `filter reload`。

---

### 2.3 Rules（白名单规则管理）

已实现字段：
- Enabled
- Sequence
- Source（支持 IP/CIDR/Alias/any）
- Destination（支持 IP/CIDR/Alias/any）
- Protocol（Modbus TCP / S7Comm）
- Description

已实现操作：
- 新增、编辑、删除、启用/禁用
- 拖拽排序（前端拖拽后提交 sequence）

规则优先级：
- 按 Sequence 升序匹配。

---

### 2.4 原生规则托管逻辑（MVP）

插件不再通过钩子直接注入隐藏的 pf 规则，而是在 Apply 时自动维护一组“可见的原生 Firewall 规则”。

托管策略：
- 先清理上一轮由插件创建的托管规则和托管 Alias（描述前缀：`IW-MANAGED`）。
- 根据插件 Rules 生成托管 Alias（按规则源/目的地址自动创建）。
- 为每条启用规则生成一条原生 `pass` 规则（协议端口映射：502/102）。
- 最后追加两条托管默认规则（502 与 102）用于 `block` 或 `log_only`。

收益：
- 规则可在原生 `Firewall -> Rules` 中可见并可拖拽。
- 管理员可直接调整优先级，降低“黑盒注入”冲突风险。

说明：
- `log_only` 是“放行并记录日志”，不是阻断。

---

### 2.5 日志页面

日志页实现方式：
- 调用 `/api/diagnostics/firewall/log?limit=500` 读取防火墙日志。
- 在前端过滤包含 `industrialwhitelist` 关键字的记录。
- 表格列：
  - Timestamp
  - Source
  - Destination
  - Protocol/Port
  - Action
- 即使没有匹配日志，也会显示空表格并展示提示行。

---

### 2.6 ACL 与访问控制

已配置 ACL 模式覆盖：
- `ui/industrialwhitelist/*`
- `api/industrialwhitelist/settings/*`
- `api/industrialwhitelist/rules/*`
- `api/industrialwhitelist/service/*`
- `ui/diagnostics/log/core/filter*`

---

## 3. 当前实现边界（MVP）

已覆盖：
- 独立菜单、配置页与日志页
- 白名单规则 CRUD 与排序
- 原生规则托管同步（Alias + Firewall Rules）
- 应用配置并重载 filter

未覆盖：
- DPI 功能码级过滤（如 Modbus 读写区分）
- 自动资产发现
- Suricata L7 策略自动生成
- HA 同步

---

## 4. 关键文件

- 模型
  - `src/opnsense/mvc/app/models/OPNsense/IndustrialWhitelist/IndustrialWhitelist.xml`
- 菜单
  - `src/opnsense/mvc/app/models/OPNsense/IndustrialWhitelist/Menu/Menu.xml`
- ACL
  - `src/opnsense/mvc/app/models/OPNsense/IndustrialWhitelist/ACL/ACL.xml`
- 配置页面
  - `src/opnsense/mvc/app/views/OPNsense/IndustrialWhitelist/index.volt`
- 日志页面
  - `src/opnsense/mvc/app/views/OPNsense/IndustrialWhitelist/logs.volt`
- 规则 API
  - `src/opnsense/mvc/app/controllers/OPNsense/IndustrialWhitelist/Api/RulesController.php`
- Apply API
  - `src/opnsense/mvc/app/controllers/OPNsense/IndustrialWhitelist/Api/ServiceController.php`
- 历史钩子入口（当前已禁用直接注入）
  - `src/etc/inc/plugins.inc.d/industrialwhitelist.inc`

---

## 5. 后续建议

建议下一阶段优先做：
1. 日志过滤增强（精确匹配 502/102 + 规则描述字段）。
2. Source/Destination 字段类型进一步收敛到专用 Alias/Network 字段。
3. 增加规则冲突可视化（与现有 Firewall 规则优先级对照）。
