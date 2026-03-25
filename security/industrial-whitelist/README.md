# Industrial Whitelist Plugin (v1.5)

## 1. 核心架构：L4 + L7 纵深防御

v1.5 将策略执行分为两个阶段：

- 第一层（L4 / pf）：
  - 使用 `registerFilterRule()` 在内核层做白名单准入控制。
  - 规则优先级：白名单放行 `10000`，默认动作 `15000`。
  - 目标：高吞吐下先拦截未授权访问，降低扫描流量对防火墙性能冲击。

- 第二层（L7 / Suricata IPS）：
  - 为通过 L4 的合法工业流量生成 Suricata 自定义规则。
  - 目标：按协议功能码拦截越权指令和协议伪装流量。

## 2. 协议支持边界

### 2.1 L7 深度管控（全功能）

- Modbus TCP (`502`)
- DNP3 (`20000`)
- EtherNet/IP / CIP (`44818`, `2222`)
- MQTT (`1883`, `8883`)

### 2.2 L4 端口管控（降级）

- S7Comm (`102`)
- IEC 104 (`2404`)
- BACnet (`47808`)

说明：L4-only 协议不生成 Suricata 功能码规则，避免脆弱字节匹配导致误报。

## 3. 控制面改造

### 3.1 模型字段

规则模型新增：

- `AllowedFunctionCodes`（多选）
  - `read_only` (FC 1-4)
  - `write_single` (FC 5-6)
  - `write_multiple` (FC 15-16)
  - `diagnostic` (FC 8)

### 3.2 UI 动态联动

在规则编辑弹窗中：

- 选择 `Modbus TCP` / `DNP3`：显示 `Allowed Function Codes`。
- 选择其它协议：隐藏该字段，并提示“当前协议仅支持网络层 (IP/端口) 访问控制”。

## 4. 数据面编译与下发

### 4.1 L4 注入

所有启用规则继续由 `industrialwhitelist.inc` 注入 pf：

- `pass in quick ...`（命中白名单）
- `block|pass in quick ... log`（默认动作）

覆盖端口：`502/102/44818/2222/2404/20000/1883/8883/47808`（按 TCP/UDP 协议组）。

### 4.2 L7 规则生成

新增 Python 编译器：

- 脚本路径：`src/opnsense/scripts/OPNsense/IndustrialWhitelist/generate_suricata_rules.py`
- 输出文件：`/usr/local/etc/suricata/custom_industrial.rules`

编译规则：

- 遍历 `config.xml` 中 IndustrialWhitelist 规则。
- 仅对 `Modbus TCP` / `DNP3` 且配置了 `AllowedFunctionCodes` 的规则生成 `pass` 功能码规则。
- 追加同源同目的 `drop` 兜底规则，阻断未授权功能码。
- 文件末尾追加协议伪装防护（`app-layer-protocol`）规则。

## 5. Apply 工作流

点击 Apply 后，后端执行顺序：

1. `industrialwhitelist generate`（生成 Suricata 自定义规则）
2. `filter reload`（刷新 pf）
3. `ids reload`（重载 IDS 规则）

前提：需在 `Services -> Intrusion Detection -> Administration` 启用 `Enabled` 与 `IPS mode`，并选择监听接口。

## 6. 关键文件

- `src/etc/inc/plugins.inc.d/industrialwhitelist.inc`
- `src/opnsense/mvc/app/models/OPNsense/IndustrialWhitelist/IndustrialWhitelist.xml`
- `src/opnsense/mvc/app/controllers/OPNsense/IndustrialWhitelist/forms/dialogRule.xml`
- `src/opnsense/mvc/app/views/OPNsense/IndustrialWhitelist/index.volt`
- `src/opnsense/mvc/app/controllers/OPNsense/IndustrialWhitelist/Api/ServiceController.php`
- `src/opnsense/service/conf/actions.d/actions_industrialwhitelist.conf`
- `src/opnsense/scripts/OPNsense/IndustrialWhitelist/generate_suricata_rules.py`
