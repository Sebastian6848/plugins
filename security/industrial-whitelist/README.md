# Industrial Whitelist Plugin (MVP)

## 1. 插件目标

Industrial Whitelist 是一个面向工业协议场景的 OPNsense 防火墙插件，提供“白名单放行 + 默认动作控制”的最小可用能力。

当前实现目标：
- 对以下工业协议建立白名单规则（L4 固定端口）：
  - Modbus TCP (502)
  - S7Comm (102)
  - EtherNet/IP (TCP/UDP 44818, UDP 2222)
  - IEC 60870-5-104 (TCP 2404)
  - DNP3 (TCP/UDP 20000)
  - BACnet (UDP 47808)
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
  - 开启/关闭插件强制过滤逻辑。
- Default Action
  - `block`
  - `log_only`

Apply 行为：
- 点击 Apply 后调用后端 reconfigure 接口。
- 后端执行 `filter reload`，重新生成并应用 pf 规则。

---

### 2.3 Rules（白名单规则管理）

已实现字段：
- Enabled
- Sequence
- Source（支持 IP/CIDR/Alias/any）
- Destination（支持 IP/CIDR/Alias/any）
- Protocol（Modbus TCP / S7Comm）
- Protocol（Modbus TCP / S7Comm / EtherNet-IP / IEC104 / DNP3 / BACnet）
- Description

已实现操作：
- 新增、编辑、删除、启用/禁用
- 拖拽排序（前端拖拽后提交 sequence）

规则优先级：
- 按 Sequence 升序匹配。

---

### 2.4 高优先级强制过滤逻辑（MVP）

插件通过防火墙 Hook 使用高优先级直接注入规则，优先于普通 Interface Rules：

- 白名单放行规则：Priority `10000`
  - 为每条启用规则按协议字典动态生成 `pass in quick <tcp|udp> ...`
  - 协议映射：
    - `modbus_tcp` -> 502
    - `s7comm` -> 102
    - `eip` -> tcp/44818, udp/44818, udp/2222
    - `iec104` -> tcp/2404
    - `dnp3` -> tcp/20000, udp/20000
    - `bacnet` -> udp/47808

- 默认动作规则：Priority `15000`
  - 对所有受管工业协议端口注入默认策略（TCP/UDP 组合）
  - `default_action = block` 时：`block in quick <tcp|udp> ... log`
  - `default_action = log_only` 时：`pass in quick <tcp|udp> ... log`

该模型确保工业端口流量在进入普通规则（通常优先级 50000+）之前即被处理。

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
- 高优先级 Hook 强制过滤（白名单放行 + 工业端口默认策略）
- 应用配置并重载 filter

未覆盖：
- DPI 功能码级过滤（如 Modbus 读写区分）
- 自动资产发现
- Suricata L7 策略自动生成
- HA 同步
- 动态端口协商协议（如 OPC DA/DCOM）

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
- pf Hook 注入逻辑
  - `src/etc/inc/plugins.inc.d/industrialwhitelist.inc`

---

## 5. 后续建议

建议下一阶段优先做：
1. 日志过滤增强（精确匹配 502/102 + 规则描述字段）。
2. Source/Destination 字段类型进一步收敛到专用 Alias/Network 字段。
3. 增加规则冲突可视化（与现有 Firewall 规则优先级对照）。
