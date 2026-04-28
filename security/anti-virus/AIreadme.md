下面是一套可以直接交给 Codex 实现的**逻辑设计方案**。它不写具体代码，但把模块边界、数据流、配置流、服务流、日志流都说清楚。

方案目标是：

> 开发一个 `os-antivirus` 聚合插件。
> 底层使用 Squid + C-ICAP + ClamAV 独立进程；上层只暴露 `Services → Antivirus` 一个防病毒管理入口。
> 插件负责一键启停、配置对齐、状态检测、EICAR 自测、日志归一化和拦截统计。

OPNsense 官方本身支持通过 ICAP 保护 HTTP/HTTPS 连接，并说明 ClamAV 可以和 C-ICAP 插件配合使用；C-ICAP 文档中也有启用 ClamAV virus-scan plugin 的配置项，所以这条技术路线是成立的。([OPNsense 文档][1])

---

# 1. 总体架构

## 1.1 插件定位

插件名称建议：

```text
os-antivirus
```

菜单入口：

```text
Services → Antivirus
```

插件不实现杀毒引擎，不修改 Squid / C-ICAP / ClamAV 源码，只做五件事：

```text
1. 统一 GUI
2. 统一配置模型
3. 统一服务编排
4. 统一健康检测
5. 统一日志统计
```

底层进程仍然独立：

```text
squid       负责 HTTP/HTTPS 代理与流量接入
c-icap      负责 ICAP 内容适配
clamd       负责病毒扫描
freshclam   负责病毒库更新
```

推荐依赖方式：

```text
os-antivirus
    依赖 os-squid
    或检测 os-squid 是否已安装
    依赖 FreeBSD 包 c-icap
    依赖 FreeBSD 包 c_icap_modules / c-icap-modules
    依赖 FreeBSD 包 clamav
```

注意：**不建议第一版依赖 os-cicap 和 os-clamav 的 GUI 插件**。这样可以避免菜单里出现多个底层管理入口。

---

# 2. 用户视角的数据流

用户只看到一个防病毒入口：

```text
Services → Antivirus
```

里面有四个页面：

```text
General
Dashboard
Logs
Advanced
```

## 2.1 General 页面

负责最小化操作：

```text
Enable Antivirus
Disable Antivirus
Service Status
Virus Database Status
Run EICAR Test
Apply Recommended Configuration
```

General 页面只回答三个问题：

```text
1. 防病毒是否开启？
2. 当前是否健康？
3. 病毒库是否过期？
```

## 2.2 Dashboard 页面

展示统计：

```text
过去 24 小时拦截数
过去 7 天趋势
Top Client IP
Top Virus Signature
Top Domain / URL
最近一次拦截事件
```

## 2.3 Logs 页面

展示归一化后的安全事件，不直接展示原始 C-ICAP / ClamAV 日志。

字段：

```text
时间
客户端 IP
目标 URL
文件名
病毒签名
动作
来源组件
详情
```

## 2.4 Advanced 页面

高级配置：

```text
扫描大小上限
超过大小后的处理方式
Fail Open / Fail Close
白名单域名
白名单客户端 IP
病毒库更新间隔
日志保留天数
HTTPS Inspection 引导
```

---

# 3. 底层流量链路

核心链路如下：

```text
客户端浏览器
    ↓
Squid Proxy
    ↓ ICAP RESPMOD
C-ICAP
    ↓ clamd socket / TCP
ClamAV clamd
    ↓
扫描结果
    ↓
C-ICAP 返回允许 / 阻断页面
    ↓
Squid 返回给客户端
```

建议第一版只做：

```text
RESPMOD 响应体扫描
```

也就是扫描服务器返回给用户的下载内容。

不要第一版就做 REQMOD 请求扫描，收益较低，复杂度更高。

---

# 4. 配置模型

在 OPNsense 配置中建立统一节点：

```text
OPNsense.antivirus
```

建议字段如下。

## 4.1 基础字段

```text
enabled: bool
mode: enum
    explicit_proxy
    transparent_proxy
    disabled

scan_http: bool
scan_https: bool
```

第一版建议：

```text
scan_http = true
scan_https = false
```

HTTPS 只做引导，不自动强启。

---

## 4.2 扫描策略字段

```text
max_scan_size_mb: int
default: 50

oversize_action: enum
    bypass_and_log
    block_and_log
default: bypass_and_log

scan_archives: bool
default: true

scan_filetypes: list
default: recommended
```

推荐资源档位：

```text
Low memory: 10 MB
Balanced: 50 MB
Performance: 100 MB
```

不要默认 5MB，实际效果偏弱。

---

## 4.3 故障策略字段

```text
bypass_on_failure: bool
default: true
```

映射到 Squid ICAP：

```text
bypass_on_failure = true  → icap_service bypass=1
bypass_on_failure = false → icap_service bypass=0
```

默认建议 Fail Open：

```text
bypass_on_failure = true
```

原因是 ClamAV / C-ICAP 异常时，不应默认导致全网下载或网页访问中断。

---

## 4.4 白名单字段

```text
whitelist_domains: list
whitelist_client_ips: list
whitelist_mime_types: list
```

白名单作用：

```text
域名白名单 → 不送 ICAP 扫描
客户端 IP 白名单 → 不送 ICAP 扫描
MIME 类型白名单 → 不送 ICAP 扫描
```

第一版可以只做域名白名单。

---

## 4.5 日志与统计字段

```text
log_retention_days: int
default: 90

event_db_path: string
default: /var/db/opnsense-antivirus/events.sqlite

alert_threshold_per_ip_1h: int
default: 5
```

MVP 可以先不做告警，只保留字段。

---

# 5. 配置生成逻辑

OPNsense 后端支持通过 configd action 做服务交互，也支持通过 Jinja2 模板生成配置文件。官方文档说明 configd 用于服务交互和配置生成，模板文件放在 `/usr/local/opnsense/service/templates/`。([OPNsense 文档][2])

你的插件应使用：

```text
config.xml → Jinja2 模板 → 生成底层配置片段
```

不要手工拼接配置文件。

---

## 5.1 Squid 配置片段

不要直接覆盖：

```text
/usr/local/etc/squid/squid.conf
```

而是生成独立片段：

```text
/usr/local/etc/squid/pre-auth/00-antivirus-icap.conf
```

历史上 OPNsense 用户也曾通过 `/usr/local/etc/squid/pre-auth/00-icap.conf` 注入 ICAP 配置以解决 Squid 与 C-ICAP 自动配置问题。([GitHub][3])

该片段逻辑包含：

```text
启用 ICAP
启用 preview
发送客户端 IP
定义 ICAP RESPMOD 服务
定义 adaptation_access 规则
定义白名单绕过规则
```

逻辑示例：

```text
如果 Antivirus disabled：
    删除或清空 00-antivirus-icap.conf
    reload squid

如果 Antivirus enabled：
    生成 00-antivirus-icap.conf
    reload squid
```

需要保证：

```text
C-ICAP 地址固定为 127.0.0.1
C-ICAP 端口固定为 1344
ICAP service name 固定，例如 av_resp
```

---

## 5.2 C-ICAP 配置

生成你自己的 C-ICAP 配置或最小配置片段。

关键逻辑：

```text
ListenAddress = 127.0.0.1
Port = 1344
启用 ClamAV ICAP service module
日志输出到固定路径
临时目录使用受控路径
```

注意：实现前要让 Codex / 开发环境确认实际模块名称。

不要在设计里写死一定是：

```text
squidclamav
```

而应抽象为：

```text
ClamAV ICAP service module
```

实机确认：

```text
c-icap-modules 中具体提供的 ClamAV 模块名称
服务名
配置文件路径
日志格式
```

因为 OPNsense 文档说的是 c-icap-modules 的 ClamAV virus-scan plugin。([OPNsense 文档][4])

---

## 5.3 ClamAV 配置

第一版只接管最小必要配置。

不要完整覆盖系统默认：

```text
clamd.conf
freshclam.conf
```

只保证以下关键项和 C-ICAP 对齐：

```text
clamd socket 路径
或者 TCP 监听地址 127.0.0.1:3310
MaxFileSize
MaxScanSize
日志路径
病毒库路径
```

推荐优先使用 Unix socket：

```text
/var/run/clamav/clamd.sock
```

如果权限问题较多，再使用：

```text
127.0.0.1:3310
```

---

## 5.4 Freshclam 配置

freshclam 负责病毒库更新。

逻辑：

```text
安装后不立即强制启用扫描
用户点击 Enable 时：
    检查病毒库是否存在
    如果不存在，先执行 freshclam 更新
    更新成功后再启动 clamd
```

General 页面展示：

```text
病毒库版本
上次更新时间
是否超过 48 小时未更新
```

---

# 6. 服务编排逻辑

所有服务动作通过 configd action 暴露。

OPNsense 官方文档说明，前端可调用的动作应注册 configd action，并尽量使用标准 rc 脚本做 start / stop。([OPNsense 文档][5])

建议提供以下动作：

```text
antivirus start
antivirus stop
antivirus restart
antivirus reload
antivirus status
antivirus apply
antivirus repair
antivirus eicar_test
antivirus update_db
antivirus parse_logs
```

---

## 6.1 Apply 动作

用户点击“Apply”时执行。

逻辑：

```text
1. 读取 OPNsense.antivirus 配置
2. 校验 os-squid 是否安装
3. 校验 c-icap / clamav 包是否存在
4. 生成 Squid ICAP 片段
5. 生成 C-ICAP 配置
6. 生成 ClamAV 最小必要配置
7. 检查配置语法
8. 根据 enabled 状态决定是否启动或停止服务
```

---

## 6.2 Start 动作

启动顺序必须固定：

```text
1. 检查病毒库是否存在
2. 如果病毒库不存在或过期，提示或执行 freshclam
3. 启动 freshclam
4. 启动 clamd
5. 等待 clamd socket / TCP 就绪
6. 启动 c-icap
7. 等待 c-icap 127.0.0.1:1344 就绪
8. 生成或确认 Squid ICAP include 片段
9. reload squid
10. 执行状态检测
11. 返回 JSON 状态给 GUI
```

等待 clamd 时要有超时：

```text
最多等待 120 秒
每 2 秒检查一次
```

原因是 ClamAV 加载病毒库可能较慢。

---

## 6.3 Stop 动作

停止顺序：

```text
1. 禁用 Squid ICAP include
2. reload squid
3. 停止 c-icap
4. 可选停止 clamd
5. freshclam 默认保留运行或按配置停止
6. 返回状态
```

建议区分两种关闭：

```text
Soft Disable:
    只移除 Squid ICAP
    保留 clamd / freshclam / c-icap

Full Disable:
    移除 Squid ICAP
    停止 c-icap
    停止 clamd
    freshclam 可保留
```

默认使用 Soft Disable，减少网络影响。

---

## 6.4 Reload 动作

用于配置变更后不中断服务：

```text
1. 重新渲染配置
2. reload c-icap
3. reload squid
4. 如果 ClamAV 关键配置变更，再 restart clamd
```

---

## 6.5 Repair 动作

用于配置漂移修复。

逻辑：

```text
1. 检查 Squid include 是否存在
2. 检查 Squid 运行配置是否包含 icap_enable / icap_service
3. 检查 c-icap 监听是否正确
4. 检查 clamd socket 是否正确
5. 重新生成所有推荐配置片段
6. 按顺序 reload / restart 服务
7. 再执行 status
```

---

# 7. 状态检测逻辑

General 页面每次加载时调用：

```text
antivirus status
```

返回统一状态。

## 7.1 状态字段

```json
{
  "enabled": true,
  "overall": "healthy",
  "squid": {
    "installed": true,
    "running": true,
    "icap_include_present": true,
    "icap_runtime_enabled": true
  },
  "cicap": {
    "installed": true,
    "running": true,
    "listening": true,
    "address": "127.0.0.1",
    "port": 1344
  },
  "clamav": {
    "installed": true,
    "clamd_running": true,
    "socket_ready": true,
    "db_version": "xxx",
    "db_updated_at": "2026-04-28T..."
  },
  "detections": {
    "last_24h": 0,
    "last_7d": 0,
    "last_detection": null
  }
}
```

## 7.2 总体状态枚举

```text
disabled
healthy
degraded
misconfigured
starting
error
```

含义：

```text
disabled:
    用户未启用

healthy:
    Squid ICAP、C-ICAP、ClamAV 全部正常

degraded:
    某个非关键组件异常，例如 freshclam 更新过期

misconfigured:
    配置漂移，例如 Squid include 缺失、C-ICAP 地址不一致

starting:
    ClamAV 正在加载病毒库

error:
    关键链路不可用
```

---

# 8. 健康检测逻辑

第一版不建议做强自动重启。

建议做：

```text
检测 + 明确提示 + 一键修复
```

## 8.1 检测项

```text
1. os-squid 是否安装
2. Squid 是否运行
3. Squid include 文件是否存在
4. Squid 运行配置是否包含 ICAP 服务
5. C-ICAP 是否运行
6. C-ICAP 是否监听 127.0.0.1:1344
7. ClamAV 是否安装
8. clamd 是否运行
9. clamd socket 或 TCP 是否可访问
10. freshclam 最近更新时间是否超过 48 小时
11. /var 和 /tmp 空间是否充足
12. SQLite 事件库是否可写
```

## 8.2 状态处理

```text
如果 Squid 未安装：
    General 页面显示“请先安装 os-squid”
    Disable Enable 按钮
    提供跳转说明

如果 Squid 未运行：
    显示 degraded
    提供“启动 Squid”或“重新应用配置”

如果 C-ICAP 未监听：
    显示 error
    提供“Repair”

如果 ClamAV 病毒库不存在：
    显示 starting / warning
    提供“Update Virus Database”

如果 freshclam 超过 48 小时未更新：
    显示 yellow warning
```

---

# 9. EICAR 自测逻辑

这是 MVP 必须有的功能。

不要只测试：

```text
clamdscan EICAR
```

因为那只能证明 ClamAV 可用，不能证明完整链路可用。

应该测试完整链路：

```text
Squid → ICAP → C-ICAP → ClamAV → 阻断
```

## 9.1 测试流程

```text
1. 插件发起一个本机 HTTP 请求
2. 请求通过本机 Squid 代理
3. 目标是 EICAR 测试文件
4. Squid 将响应送入 C-ICAP
5. C-ICAP 调用 ClamAV
6. ClamAV 返回 Eicar-Test-Signature
7. C-ICAP 返回阻断响应
8. 插件检查 HTTP 响应、C-ICAP 日志或事件库
9. GUI 显示 Test Passed / Test Failed
```

## 9.2 测试结果

```text
passed:
    完整链路成功拦截

failed_clamav:
    ClamAV 没识别 EICAR

failed_cicap:
    C-ICAP 没有调用 ClamAV

failed_squid:
    Squid 没有把响应送到 ICAP

failed_unknown:
    其他错误
```

---

# 10. 日志数据流

你要解决的核心问题是：

```text
ClamAV 不直观显示拦截结果，用户只能看 C-ICAP 日志。
```

所以插件必须有**日志归一化层**。

---

## 10.1 原始日志来源

采集：

```text
C-ICAP access log
C-ICAP server log
ClamAV clamd log
Squid access log，可选
```

MVP 最少采集：

```text
C-ICAP access log
ClamAV clamd log
```

---

## 10.2 归一化事件格式

统一存入 SQLite：

```text
/var/db/opnsense-antivirus/events.sqlite
```

主表：

```text
detections
```

字段：

```text
id
ts
src_ip
src_port
dst_host
url
filename
mime_type
file_size
signature
action
engine
source_log
raw_line_hash
created_at
```

`action` 枚举：

```text
blocked
allowed
skipped_large_file
skipped_whitelist
scan_error
test_blocked
```

MVP 可以只记录：

```text
ts
src_ip
url
signature
action
source_log
raw_line_hash
```

---

## 10.3 日志解析方式

MVP 不使用 `tail -F` 常驻进程。

使用定时增量解析：

```text
每 1 分钟运行一次 parse_logs
```

解析器保存状态：

```text
/var/db/opnsense-antivirus/parser_state.json
```

内容：

```json
{
  "cicap_access": {
    "path": "...",
    "inode": "...",
    "offset": 123456
  },
  "clamd": {
    "path": "...",
    "inode": "...",
    "offset": 78910
  }
}
```

逻辑：

```text
1. 打开日志文件
2. 检查 inode 是否变化
3. 如果 inode 未变化，从上次 offset 继续读
4. 如果 inode 变化，说明 logrotate，重新从头读或从新文件读
5. 对新增行做正则解析
6. 生成标准事件
7. 根据 raw_line_hash 去重
8. 写入 SQLite
9. 更新 offset
```

---

## 10.4 统计数据流

Dashboard 不直接解析日志。

Dashboard 只读 SQLite。

数据流：

```text
C-ICAP / ClamAV 原始日志
    ↓
parse_logs 定时增量解析
    ↓
detections 表
    ↓
summary 查询
    ↓
Dashboard / Logs GUI
```

---

# 11. Dashboard 查询逻辑

## 11.1 过去 24 小时拦截数

```text
COUNT detections
WHERE ts >= now - 24h
AND action IN blocked, test_blocked
```

注意：正式统计可以排除测试事件：

```text
正式统计不计 test_blocked
```

## 11.2 过去 7 天趋势

```text
GROUP BY date(ts)
WHERE ts >= now - 7d
AND action = blocked
```

## 11.3 Top Client IP

```text
GROUP BY src_ip
WHERE ts >= now - 24h 或 7d
ORDER BY count DESC
LIMIT 10
```

## 11.4 Top Virus Signature

```text
GROUP BY signature
WHERE ts >= now - 7d
ORDER BY count DESC
LIMIT 10
```

## 11.5 最近事件

```text
ORDER BY ts DESC
LIMIT 20
```

---

# 12. 配置漂移检测

由于 Squid 仍由 os-squid 管理，必须检测配置是否被用户或升级覆盖。

## 12.1 漂移检测项

```text
Squid include 文件是否存在
Squid include 文件内容 hash 是否与当前配置匹配
Squid 运行配置是否包含 antivirus icap_service
C-ICAP 配置中的 clamd socket 是否与 ClamAV 配置一致
C-ICAP 实际监听地址是否是 127.0.0.1:1344
ClamAV socket 是否存在且权限可访问
```

## 12.2 漂移结果

```text
no_drift:
    正常

squid_include_missing:
    Squid ICAP 片段缺失

squid_runtime_missing:
    Squid 没加载 ICAP 配置

cicap_mismatch:
    C-ICAP 地址、端口或 service 名称不一致

clamav_socket_mismatch:
    C-ICAP 配置和 clamd 实际 socket 不一致
```

## 12.3 GUI 行为

如果发现漂移：

```text
显示：
检测到底层配置与 Antivirus 插件配置不一致，防病毒可能未生效。

按钮：
[重新应用推荐配置]
```

点击后调用：

```text
antivirus repair
```

---

# 13. HTTPS Inspection 设计

第一版不要自动开启 HTTPS 解密。

Advanced 页面只做引导：

```text
HTTPS Inspection: Not configured
[Open HTTPS Inspection Wizard]
```

引导说明必须写清楚：

```text
1. HTTPS Inspection 会让 OPNsense 作为 TLS 中间人代理。
2. 客户端必须安装并信任 OPNsense CA。
3. 证书固定应用可能无法访问。
4. 银行、医疗、政务、支付类网站建议默认绕过。
5. HTTP/3 / QUIC 流量无法按传统 Squid SSL Bump 方式处理。
6. 启用前需确认组织合规要求。
```

第一版可以只显示状态和说明，不做自动配置。

---

# 14. 卸载逻辑

卸载时只清理你自己创建的东西。

默认删除：

```text
Antivirus 插件配置节点
Squid antivirus include 片段
configd actions
Jinja2 templates
SQLite 事件库，可选
parser state
插件日志
```

默认保留：

```text
ClamAV 病毒库
clamav 包
c-icap 包
os-squid 配置
系统级日志
```

原因：ClamAV 可能被其他组件复用。OPNsense 文档也提到 ClamAV 可以和 C-ICAP、rspamd 等配合使用。([OPNsense 文档][6])

卸载时如果要删除事件库，建议提供选项：

```text
Remove detection history: yes / no
Remove ClamAV virus database: no by default
```

---

# 15. 分阶段交付方案

## 15.1 MVP：先解决“一键可用”

MVP 只做这些：

```text
1. Services → Antivirus 菜单
2. General 页面
3. 配置模型
4. 生成 Squid ICAP include
5. 生成 C-ICAP / ClamAV 最小配置
6. 一键 Enable / Disable
7. 固定启停顺序
8. status 健康检测
9. 病毒库更新时间显示
10. EICAR 完整链路自测
```

MVP 不做：

```text
Dashboard 趋势图
复杂日志搜索
告警通知
HTTPS 自动配置
自动自愈
常驻日志采集 daemon
```

目标：

```text
用户安装后，只需要点一次 Enable，就能完成 HTTP 下载防病毒扫描。
```

---

## 15.2 Beta：做“可视化拦截”

Beta 增加：

```text
1. 定时日志解析
2. SQLite detections 表
3. 过去 24 小时拦截数
4. 最近 20 条拦截事件
5. Logs 页面
6. CSV 导出
7. 配置漂移检测
8. Repair 按钮
```

目标：

```text
用户可以在 GUI 里看到“过去 24 小时拦截了 N 个病毒”。
```

---

## 15.3 RC：做“产品化体验”

RC 增加：

```text
1. Dashboard 趋势图
2. Top Client IP
3. Top Virus Signature
4. Top Domain
5. 告警阈值
6. OPNsense 通知集成
7. HTTPS Inspection Wizard
8. 有限自动修复
9. 日志保留策略
10. 卸载清理选项
```

目标：

```text
体验接近商业防火墙 UTM 的防病毒页面。
```

---

# 16. 给 Codex 的实现任务拆分

你可以让 Codex 按以下任务顺序实现。

## Task 1：创建插件骨架

```text
创建 os-antivirus 插件目录结构
注册菜单 Services → Antivirus
创建 General 页面
创建 ACL
创建基础 Controller / API
创建基础 Model XML
```

## Task 2：实现配置模型

```text
添加 enabled
添加 max_scan_size_mb
添加 bypass_on_failure
添加 oversize_action
添加 whitelist_domains
添加 log_retention_days
添加 freshclam stale threshold
```

## Task 3：实现模板渲染

```text
生成 Squid ICAP include
生成 C-ICAP 配置
生成 ClamAV 最小配置
确保路径、socket、端口一致
```

## Task 4：实现 configd actions

```text
apply
start
stop
restart
reload
status
repair
eicar_test
update_db
```

## Task 5：实现服务编排脚本

```text
start:
    freshclam check
    clamd start
    wait clamd ready
    c-icap start
    wait c-icap ready
    squid reload

stop:
    disable squid icap
    squid reload
    stop c-icap
    optionally stop clamd
```

## Task 6：实现状态检测

```text
检查 squid
检查 c-icap
检查 clamd
检查 freshclam
检查病毒库更新时间
检查配置漂移
输出统一 JSON
```

## Task 7：实现 EICAR 测试

```text
通过 Squid 发起 EICAR 下载
检查是否被 ICAP / ClamAV 拦截
输出 passed / failed_xxx
```

## Task 8：实现日志解析

```text
定时运行 parse_logs
读取 C-ICAP / ClamAV 新增日志
解析为 detections
写 SQLite
做去重
保存 offset / inode
```

## Task 9：实现 Dashboard / Logs

```text
Dashboard:
    last_24h count
    last_7d trend
    top clients
    top signatures

Logs:
    Bootgrid 表格
    时间/IP/签名过滤
    CSV 导出
```

---

# 17. 最终逻辑总图

```text
用户点击 Enable
    ↓
GUI 调用 API
    ↓
API 调用 configd apply/start
    ↓
读取 OPNsense.antivirus 配置
    ↓
渲染 Squid / C-ICAP / ClamAV 配置
    ↓
启动 clamd
    ↓
等待 clamd ready
    ↓
启动 c-icap
    ↓
等待 127.0.0.1:1344 ready
    ↓
reload squid
    ↓
status 检查完整链路
    ↓
EICAR 自测
    ↓
GUI 显示 Healthy
```

运行期：

```text
客户端下载文件
    ↓
Squid 接收响应
    ↓
ICAP RESPMOD 送 C-ICAP
    ↓
C-ICAP 调用 ClamAV
    ↓
发现病毒
    ↓
C-ICAP 返回阻断页
    ↓
写入 C-ICAP / ClamAV 日志
    ↓
parse_logs 定时解析
    ↓
写入 SQLite detections
    ↓
Dashboard 显示过去 24 小时拦截数
```

---

# 18. 最终建议

你的最终方案应该定位为：

```text
os-antivirus 是一个 OPNsense 防病毒聚合管理插件。
它不重写杀毒能力，而是把 Squid、C-ICAP、ClamAV 通过统一配置、统一启停、统一检测、统一日志做成一个产品化功能。
```

第一版目标不要定太大。最合理的落地顺序是：

```text
先做一键启用和完整链路自测；
再做日志统计；
最后做 Dashboard、告警和 HTTPS 引导。
```

[1]: https://docs.opnsense.org/manual/antivirus.html?utm_source=chatgpt.com "Anti Virus Engine"
[2]: https://docs.opnsense.org/development/backend.html?utm_source=chatgpt.com "Backend"
[3]: https://github.com/opnsense/plugins/issues/1194?utm_source=chatgpt.com "Some squid/c-icap/clamd autoconfig issues #1194"
[4]: https://docs.opnsense.org/manual/how-tos/c-icap.html?utm_source=chatgpt.com "c-icap"
[5]: https://docs.opnsense.org/development/backend/configd.html?utm_source=chatgpt.com "Using configd"
[6]: https://docs.opnsense.org/manual/how-tos/proxyicapantivirusinternal.html?utm_source=chatgpt.com "Setup Anti Virus Protection using OPNsense Plugins"
