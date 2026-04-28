# ============================================================
# os-antivirus 插件开发任务拆解
# 目标路径: plugins/security/anti-virus
# 参考: plugins/security/clamav / plugins/www/c-icap / plugins/www/squid
# ============================================================

# ============================================================
# TASK 0: 顶层包结构
# ============================================================

# 0.1 创建 Makefile
# 路径: plugins/security/anti-virus/Makefile
# 参考: plugins/security/clamav/Makefile
# 内容要求:
#   - PLUGIN_NAME=     anti-virus
#   - PLUGIN_VERSION=  1.0.0
#   - PLUGIN_COMMENT=  Integrated Antivirus (Squid + c-icap + ClamAV)
#   - PLUGIN_DEPENDS=  os-squid clamav c_icap c_icap_modules
#   - PLUGIN_MAINTAINER= (你的邮箱)
#   - .include "../../Mk/plugins.mk"

# 0.2 创建 pkg-descr
# 路径: plugins/security/anti-virus/pkg-descr
# 内容要求:
#   - 一段英文描述，说明本插件整合 Squid ICAP + c-icap + ClamAV
#   - 注明需要先安装 os-squid
#   - 注明硬件要求: ≥2GB RAM, ≥2GB 可用磁盘


# ============================================================
# TASK 1: 配置模型层 (models)
# 路径前缀: src/opnsense/mvc/app/models/OPNsense/Antivirus/
# 参考: plugins/security/clamav/src/opnsense/mvc/app/models/OPNsense/ClamAV/
#       plugins/www/c-icap/src/opnsense/mvc/app/models/OPNsense/CICAP/
# ============================================================

# 1.1 General.xml — 主配置模型
# 路径: models/OPNsense/Antivirus/General.xml
# mount 节点: //OPNsense/antivirus/general
# 字段清单:
#   enabled             BooleanField  Default=0  Required=Y
#   icap_port           IntegerField  Default=1344  Required=Y
#   icap_bypass_on_err  BooleanField  Default=1  Required=Y
#   max_scan_size       TextField     Default=5M  Required=Y
#   scan_archives       BooleanField  Default=1
#   scan_pe             BooleanField  Default=1
#   scan_pdf            BooleanField  Default=1
#   freshclam_interval  IntegerField  Default=4  (单位: 小时)
#   alert_threshold     IntegerField  Default=5
#   log_retention_days  IntegerField  Default=90

# 1.2 General.php — 模型类
# 路径: models/OPNsense/Antivirus/General.php
# 参考: plugins/security/clamav/src/opnsense/mvc/app/models/OPNsense/ClamAV/General.php
# 内容要求:
#   - 继承 OPNsense\Base\BaseModel
#   - 无需额外逻辑，字段校验由 XML 类型声明驱动

# 1.3 Menu/Menu.xml — 菜单注册
# 路径: models/OPNsense/Antivirus/Menu/Menu.xml
# 参考: plugins/security/clamav/src/opnsense/mvc/app/models/OPNsense/ClamAV/Menu/
# 内容要求:
#   - 挂载在 <Services> 下
#   - 一级菜单: Antivirus, url=/ui/antivirus/general
#   - 子菜单项:
#       General    → /ui/antivirus/general
#       Dashboard  → /ui/antivirus/dashboard
#       Logs       → /ui/antivirus/log
#       Advanced   → /ui/antivirus/advanced

# 1.4 ACL/ACL.xml — 权限声明
# 路径: models/OPNsense/Antivirus/ACL/ACL.xml
# 参考: plugins/security/clamav/src/opnsense/mvc/app/models/OPNsense/ClamAV/ACL/
# 内容要求:
#   - 声明 page-services-antivirus 权限组
#   - 覆盖 /ui/antivirus/* 和 /api/antivirus/* 路径


# ============================================================
# TASK 2: 控制器层 (controllers)
# 路径前缀: src/opnsense/mvc/app/controllers/OPNsense/Antivirus/
# 参考: plugins/security/clamav/src/opnsense/mvc/app/controllers/OPNsense/ClamAV/
#       plugins/www/c-icap/src/opnsense/mvc/app/controllers/OPNsense/CICAP/
# ============================================================

# 2.1 GeneralController.php — 页面控制器(General/Advanced)
# 路径: controllers/OPNsense/Antivirus/GeneralController.php
# 参考: plugins/security/clamav/.../ClamAV/GeneralController.php
# 内容要求:
#   - 继承 OPNsense\Base\ControllerBase
#   - indexAction()     → 渲染 general.volt
#   - advancedAction()  → 渲染 advanced.volt
#   - dashboardAction() → 渲染 dashboard.volt
#   - logAction()       → 渲染 log.volt

# 2.2 Api/ServiceController.php — 服务启停 API
# 路径: controllers/OPNsense/Antivirus/Api/ServiceController.php
# 参考: plugins/www/c-icap/.../CICAP/Api/ 下的 ServiceController
# 内容要求:
#   - 继承 OPNsense\Base\ApiControllerBase
#   - startAction()   → 调用 configd: antivirus start
#   - stopAction()    → 调用 configd: antivirus stop
#   - restartAction() → 调用 configd: antivirus restart
#   - statusAction()  → 调用 configd: antivirus status, 返回 JSON
#   - reloadAction()  → 调用 configd: antivirus reload (仅重渲配置+reload服务，不重启)

# 2.3 Api/SettingsController.php — 配置读写 API
# 路径: controllers/OPNsense/Antivirus/Api/SettingsController.php
# 参考: plugins/security/clamav/.../ClamAV/Api/ 下的 SettingsController
# 内容要求:
#   - 继承 OPNsense\Base\ApiMutableModelControllerBase
#   - $internalModelName = 'general'
#   - $internalModelClass = 'OPNsense\Antivirus\General'
#   - 实现标准的 getAction() / setAction()

# 2.4 Api/LogController.php — 日志查询 API
# 路径: controllers/OPNsense/Antivirus/Api/LogController.php
# 内容要求:
#   - searchAction(offset, limit, filter_ip, filter_sig, date_from, date_to)
#     → 查询 /var/db/antivirus/events.db 的 detections 表
#     → 返回 { total, rows: [{ts, src_ip, url, signature, action}] }
#   - statsAction()
#     → 返回聚合数据 JSON:
#       {
#         last24h:  <count>,
#         trend7d:  [{date, count}, ...],   // 按天分组
#         top_ips:  [{ip, count}, ...],     // Top 10
#         top_sigs: [{sig, count}, ...]     // Top 10
#       }
#   - exportAction() → 输出 CSV (Content-Disposition: attachment)

# 2.5 forms/ — 表单字段描述文件
# 路径: controllers/OPNsense/Antivirus/forms/
# 文件清单:
#   general.xml   — General 页面的表单字段 (enabled, icap_port, max_scan_size 等)
#   advanced.xml  — Advanced 页面字段 (scan_archives, scan_pe, scan_pdf,
#                   freshclam_interval, alert_threshold, log_retention_days)
# 参考: plugins/www/c-icap/.../CICAP/forms/ 下的 xml 格式
# 注意:
#   - 每个 <field> 的 <label> 值必须使用翻译键而非硬编码字符串
#     例: <label>antivirus.general.enabled</label>
#   - 翻译文件在 TASK 5 中创建


# ============================================================
# TASK 3: 视图层 (views / Volt 模板)
# 路径前缀: src/opnsense/mvc/app/views/OPNsense/Antivirus/
# 参考: plugins/security/clamav/.../ClamAV/views/
#       plugins/www/c-icap/.../CICAP/views/
# ============================================================

# 3.1 general.volt — General 页面
# 内容要求:
#   - 使用 OPNsense 标准 SimpleActionButton 组件渲染启停按钮
#   - 使用 SimpleForm 渲染 forms/general.xml 中的字段
#   - 顶部状态栏: 三个状态指示灯 (clamd / c-icap / ICAP链路)
#     数据来源: GET /api/antivirus/service/status
#   - 病毒库信息区块: 签名版本、上次更新时间、立即更新按钮
#     数据来源: GET /api/antivirus/service/status (status脚本输出中解析)
#   - 所有展示文字通过 gettext() / _() 函数引用翻译键，禁止硬编码

# 3.2 dashboard.volt — Dashboard 页面
# 内容要求:
#   - 四个统计卡片，数据来源: GET /api/antivirus/log/stats
#       卡片1: 过去 24h 拦截数 (last24h)
#       卡片2: 7 天趋势折线图 (trend7d, 使用 Chart.js 或 OPNsense 内置图表组件)
#       卡片3: Top 10 感染源 IP 列表 (top_ips)
#       卡片4: Top 10 病毒签名列表 (top_sigs)
#   - 页面加载时自动请求数据，无需手动刷新按钮
#   - 所有标签通过翻译键

# 3.3 log.volt — Logs 页面
# 内容要求:
#   - 使用 OPNsense 标准 Bootgrid 表格组件
#   - 列定义: 时间、来源IP、URL、病毒签名、动作
#   - 过滤器: 时间范围选择器、IP 输入框、签名关键词输入框
#   - 分页: 每页 50 条，支持翻页
#   - 导出按钮: 调用 /api/antivirus/log/export 下载 CSV
#   - 数据来源: GET /api/antivirus/log/search (带分页参数)

# 3.4 advanced.volt — Advanced 页面
# 内容要求:
#   - 使用 SimpleForm 渲染 forms/advanced.xml
#   - SSL Bump 引导区块 (只读提示，不做配置，告知用户去 os-squid 配置)
#   - 硬件资源提示区块 (磁盘/内存需求说明)
#   - 所有文字通过翻译键


# ============================================================
# TASK 4: 服务层 (configd actions + 配置模板)
# 路径前缀: src/opnsense/service/
# ============================================================

# 4.1 configd action 定义
# 路径: service/conf/actions.d/actions_antivirus.conf
# 参考: plugins/security/clamav/.../actions_clamav.conf
# 动作清单 (每个动作的 type/command/message 字段):
#
#   [antivirus.start]
#     type=script
#     command=/usr/local/opnsense/scripts/OPNsense/Antivirus/start.sh
#     message=starting antivirus stack
#
#   [antivirus.stop]
#     type=script
#     command=/usr/local/opnsense/scripts/OPNsense/Antivirus/stop.sh
#     message=stopping antivirus stack
#
#   [antivirus.restart]
#     type=script
#     command=/usr/local/opnsense/scripts/OPNsense/Antivirus/stop.sh &&
#             /usr/local/opnsense/scripts/OPNsense/Antivirus/start.sh
#     message=restarting antivirus stack
#
#   [antivirus.reload]
#     type=script
#     command=/usr/local/opnsense/scripts/OPNsense/Antivirus/reload.sh
#     message=reloading antivirus config
#
#   [antivirus.status]
#     type=script_output
#     command=/usr/local/opnsense/scripts/OPNsense/Antivirus/status.sh
#     message=query antivirus status
#
#   [antivirus.update_sigs]
#     type=script_output
#     command=/usr/local/sbin/freshclam --no-warnings
#     message=updating ClamAV signatures

# 4.2 配置模板 — c-icap.conf
# 路径: service/templates/OPNsense/Antivirus/c-icap.conf
# 参考: plugins/www/c-icap/src/opnsense/service/templates/ 下的模板
# 渲染变量来源: //OPNsense/antivirus/general
# 关键字段:
#   - ServerPort       → {{ icap_port }}
#   - MaxServers       → 固定或可配
#   - ServerLog        → /var/log/c-icap/server.log
#   - AccessLog        → /var/log/c-icap/access.log
#   - Service squidclamav squidclamav.so
#   - 仅当 enabled=1 时渲染完整配置，否则渲染最小空配置

# 4.3 配置模板 — squidclamav.conf
# 路径: service/templates/OPNsense/Antivirus/squidclamav.conf
# 关键字段:
#   - clamd_local      → /var/run/clamav/clamd.sock  (固定)
#   - maxsize          → {{ max_scan_size }} (从 General 模型读取)
#   - scan_archive     → {{ scan_archives }}
#   - redirect         → http://127.0.0.1/antivirus_block.html  (拦截跳转页)

# 4.4 配置模板 — clamd.conf 片段
# 路径: service/templates/OPNsense/Antivirus/clamd.conf
# 参考: plugins/security/clamav/src/opnsense/service/templates/OPNsense/ClamAV/
# 说明: 本插件管理自己的 clamd.conf，与 os-clamav 插件路径区分开
#       (如果用户同时装了 os-clamav，两份配置会冲突——在安装检测脚本中处理)
# 关键字段:
#   - ScanArchive      → {{ scan_archives }}
#   - ScanPE           → {{ scan_pe }}
#   - ScanPDF          → {{ scan_pdf }}
#   - MaxScanSize      → {{ max_scan_size }}
#   - LocalSocket      → /var/run/clamav/clamd.sock

# 4.5 配置模板 — squid_icap_include.conf
# 路径: service/templates/OPNsense/Antivirus/squid_icap_include.conf
# 说明: 这是注入到 squid.conf 的 ICAP 配置片段
#       通过 squid.conf 末尾的 include 指令引入，不修改 os-squid 主模板
# 内容 (仅当 enabled=1 时渲染，否则输出空文件):
#   icap_enable on
#   icap_service service_av_req  reqmod_precache icap://127.0.0.1:{{ icap_port }}/squidclamav
#   icap_service service_av_resp respmod_precache icap://127.0.0.1:{{ icap_port }}/squidclamav
#   adaptation_access service_av_req  allow all
#   adaptation_access service_av_resp allow all
#   icap_preview_enable on
#   icap_send_client_ip on
#   icap_connect_timeout 5
#   icap_service_failure_limit {{ icap_bypass_on_err == 1 ? -1 : 0 }}

# 4.6 freshclam.conf 模板
# 路径: service/templates/OPNsense/Antivirus/freshclam.conf
# 参考: plugins/security/clamav/src/opnsense/service/templates/OPNsense/ClamAV/freshclam.conf
# 关键字段:
#   - Checks           → {{ freshclam_interval }} (每天检查次数 = 24/interval)
#   - DatabaseMirror   → database.clamav.net
#   - UpdateLogFile    → /var/log/clamav/freshclam.log


# ============================================================
# TASK 5: 后台脚本层
# 路径前缀: src/opnsense/scripts/OPNsense/Antivirus/
# ============================================================

# 5.1 start.sh — 有序启动脚本
# 逻辑:
#   1. 检查 os-squid 是否已安装，未安装则 exit 1 并输出错误信息
#   2. 检查 os-clamav 插件是否已安装（冲突检测），若已安装输出警告
#   3. 渲染所有配置模板: configctl template reload OPNsense/Antivirus
#   4. 将 squid_icap_include.conf 软链接或 include 到 squid 配置目录
#   5. service clamav-clamd onestart
#   6. 轮询等待 /var/run/clamav/clamd.sock 出现，超时 120 秒
#   7. service c-icap onestart
#   8. configctl proxy restart  (触发 Squid reload，使 ICAP include 生效)
#   9. service clamav-freshclam onestart

# 5.2 stop.sh — 有序停止脚本
# 逻辑:
#   1. configctl proxy restart  (先让 Squid 断开 ICAP 连接)
#   2. service c-icap onestop
#   3. service clamav-clamd onestop
#   4. service clamav-freshclam onestop
#   5. 清空 squid_icap_include.conf 内容（输出空文件）
#   6. configctl proxy restart  (使 Squid 以无 ICAP 模式重载)

# 5.3 reload.sh — 热重载配置（不重启服务）
# 逻辑:
#   1. 重新渲染所有模板: configctl template reload OPNsense/Antivirus
#   2. 向 clamd 发送 RELOAD 命令 (通过 clamdscan --reload 或 echo RELOAD | nc)
#   3. service c-icap onereload
#   4. configctl proxy restart

# 5.4 status.sh — 状态查询脚本，输出 JSON
# 输出格式:
#   {
#     "clamd":    "running" | "stopped",
#     "cicap":    "running" | "stopped",
#     "squid_icap": "active" | "inactive" | "unknown",
#     "sig_version": "<版本号字符串>",
#     "sig_updated": "<ISO8601 时间戳>",
#     "freshclam": "running" | "stopped"
#   }
# 逻辑:
#   - clamd 状态: 检查 /var/run/clamav/clamd.sock 是否存在
#   - c-icap 状态: 检查 1344 端口是否监听
#   - squid_icap: 解析 squid_icap_include.conf 是否非空
#   - sig_version: 解析 /var/db/clamav/*.cvd 或 sigtool --info 输出
#   - sig_updated: 读取 /var/log/clamav/freshclam.log 最后更新时间戳

# 5.5 healthcheck.py — 看门狗（常驻后台）
# 运行方式: 由 rc.d 脚本或 cron 每 60 秒调用一次
# 逻辑:
#   1. 读取 /conf/config.xml 中 enabled 字段，若为 0 则直接退出
#   2. 检查 clamd socket 是否存在
#   3. 检查 c-icap 1344 端口是否响应
#   4. 任一异常: 调用 configctl antivirus start 尝试拉起
#   5. 写入 /var/db/antivirus/healthcheck.log，记录每次检查结果和恢复动作

# 5.6 log_parser.py — 日志采集守护进程
# 运行方式: 随 antivirus start 一起启动，常驻后台
# 逻辑:
#   1. tail -F 监听 /var/log/c-icap/access.log
#   2. 正则匹配拦截行，提取五元组:
#      (timestamp, src_ip, method, url, virus_signature)
#      匹配模式参考 squidclamav 的 access.log 格式:
#      "DATE, SRC_IP, METHOD, URL, VIRUS FOUND: SIGNAME"
#   3. 将匹配结果 INSERT 到 /var/db/antivirus/events.db 的 detections 表
#   4. 定期执行清理: DELETE FROM detections WHERE ts < (NOW - retention_days*86400)
#      retention_days 从 /conf/config.xml 读取

# 5.7 db_init.py — 数据库初始化脚本（首次启动时调用）
# 逻辑:
#   1. 若 /var/db/antivirus/ 目录不存在则创建
#   2. 若 events.db 不存在则创建，建表:
#      CREATE TABLE IF NOT EXISTS detections (
#        id        INTEGER PRIMARY KEY AUTOINCREMENT,
#        ts        INTEGER NOT NULL,
#        src_ip    TEXT,
#        url       TEXT,
#        signature TEXT,
#        action    TEXT DEFAULT 'blocked'
#      );
#      CREATE INDEX IF NOT EXISTS idx_ts ON detections(ts);
#      CREATE INDEX IF NOT EXISTS idx_src_ip ON detections(src_ip);
#      CREATE INDEX IF NOT EXISTS idx_sig ON detections(signature);


# ============================================================
# TASK 6: 多语言支持
# 路径前缀: src/opnsense/mvc/app/
# ============================================================

# 6.1 翻译目录结构
# 路径: src/opnsense/mvc/app/locale/
# 子目录规范 (参考 OPNsense 核心多语言约定):
#   locale/en_US/LC_MESSAGES/OPNsense.Antivirus.po  ← 英文 (主语言)
#   locale/zh_CN/LC_MESSAGES/OPNsense.Antivirus.po  ← 简体中文
# 说明:
#   - 所有 .volt 视图和 forms/*.xml 中的展示文字
#     必须通过 gettext 域 "OPNsense.Antivirus" 引用翻译键
#   - 视图中使用: {{ lang._('antivirus.general.enabled') }}
#   - forms XML 中使用: <label>antivirus.general.enabled</label>
#     (OPNsense 表单框架会自动对 label 值做 gettext 查找)

# 6.2 en_US 翻译键清单 (OPNsense.Antivirus.po)
# 需覆盖以下键 (msgid → msgstr):
#
#   General 页面:
#     antivirus.general.title          → "Antivirus"
#     antivirus.general.enabled        → "Enable Antivirus"
#     antivirus.general.icap_port      → "ICAP Port"
#     antivirus.general.max_scan_size  → "Max Scan Size"
#     antivirus.general.status_clamd   → "ClamAV Engine"
#     antivirus.general.status_cicap   → "ICAP Service"
#     antivirus.general.status_chain   → "Proxy Chain"
#     antivirus.general.sig_version    → "Signature Version"
#     antivirus.general.sig_updated    → "Last Updated"
#     antivirus.general.update_now     → "Update Now"
#
#   Dashboard 页面:
#     antivirus.dashboard.title        → "Threat Dashboard"
#     antivirus.dashboard.last24h      → "Threats Blocked (24h)"
#     antivirus.dashboard.trend7d      → "7-Day Trend"
#     antivirus.dashboard.top_ips      → "Top Source IPs"
#     antivirus.dashboard.top_sigs     → "Top Signatures"
#
#   Logs 页面:
#     antivirus.log.title              → "Detection Log"
#     antivirus.log.col_ts             → "Time"
#     antivirus.log.col_src_ip         → "Source IP"
#     antivirus.log.col_url            → "URL"
#     antivirus.log.col_sig            → "Signature"
#     antivirus.log.col_action         → "Action"
#     antivirus.log.export             → "Export CSV"
#
#   Advanced 页面:
#     antivirus.advanced.title            → "Advanced Settings"
#     antivirus.advanced.scan_archives    → "Scan Archives"
#     antivirus.advanced.scan_pe          → "Scan PE Executables"
#     antivirus.advanced.scan_pdf         → "Scan PDF Files"
#     antivirus.advanced.freshclam_int    → "Signature Update Interval (hours)"
#     antivirus.advanced.alert_threshold  → "Alert Threshold (detections/hour)"
#     antivirus.advanced.log_retention    → "Log Retention (days)"
#     antivirus.advanced.ssl_bump_hint    → "To scan HTTPS traffic, configure SSL Bump in Services > Web Proxy > Administration."
#     antivirus.advanced.hw_req_hint      → "Requires at least 2 GB RAM and 2 GB free disk space."
#
# 6.3 zh_CN 翻译键清单 (OPNsense.Antivirus.po)
# 与 en_US 键名相同，msgstr 替换为对应中文，示例:
#   antivirus.general.enabled       → "启用防病毒"
#   antivirus.dashboard.last24h     → "过去 24 小时拦截威胁数"
#   antivirus.log.col_sig           → "病毒签名"
#   antivirus.advanced.ssl_bump_hint→ "如需扫描 HTTPS 流量，请在 服务 > Web 代理 > 管理 中配置 SSL Bump。"
#   (其余键按照同样规则补全)


# ============================================================
# TASK 7: rc.d 启动脚本与开机自启
# ============================================================

# 7.1 rc.d 脚本
# 路径: src/etc/rc.d/antivirus
# 参考: FreeBSD rc.subr 规范
# 内容要求:
#   - name="antivirus"
#   - command="/usr/local/opnsense/scripts/OPNsense/Antivirus/start.sh"
#   - stop_cmd="/usr/local/opnsense/scripts/OPNsense/Antivirus/stop.sh"
#   - 依赖 (REQUIRE): LOGIN clamav-clamd c-icap
#   - 默认 antivirus_enable="NO" (安装后不自动启动)

# 7.2 开机自启配置
# 路径: src/etc/rc.conf.d/antivirus
# 内容:
#   antivirus_enable="NO"
# 说明: 用户在 GUI 打开总开关后，插件的 setAction() 应同时将此值改为 YES
#       写入 /etc/rc.conf.d/antivirus（通过 OPNsense configd 机制）

# 7.3 看门狗 cron 注册 (接上文)
# 路径: src/etc/cron.d/antivirus-healthcheck
# 内容:
#   */1 * * * * root /usr/local/opnsense/scripts/OPNsense/Antivirus/healthcheck.py
# 说明:
#   - healthcheck.py 内部读取 enabled 字段，若为 0 则立即退出，不产生实际开销
#   - 因此 cron 条目可以无条件注册，不需要随插件启停动态增删

# 7.4 log_parser 守护进程注册
# 路径: src/etc/rc.d/antivirus-logparser
# 内容要求:
#   - name="antivirus_logparser"
#   - command="/usr/local/opnsense/scripts/OPNsense/Antivirus/log_parser.py"
#   - pidfile="/var/run/antivirus_logparser.pid"
#   - 在 start.sh 的第 9 步之后启动，在 stop.sh 的第 1 步之前停止
#   - 异常退出后由 healthcheck.py 负责重新拉起


# ============================================================
# TASK 8: 安装/卸载钩子
# 路径前缀: src/
# ============================================================

# 8.1 安装后初始化钩子
# 路径: src/etc/inc/plugins.inc.d/antivirus.inc
# 参考: plugins/security/clamav/src/etc/inc/plugins.inc.d/clamav.inc
# 函数清单:
#
#   antivirus_enabled()
#     → 读取 //OPNsense/antivirus/general/enabled
#     → 返回 true/false
#     → 供 OPNsense 核心在系统启动时判断是否需要拉起本插件服务
#
#   antivirus_configure()
#     → 调用 configctl template reload OPNsense/Antivirus
#     → 调用 configctl antivirus reload
#     → 供 OPNsense 配置变更事件回调（例如网络接口变更后重载）
#
#   antivirus_install()
#     → 首次安装时执行:
#       1. 调用 db_init.py 初始化 SQLite 数据库
#       2. 创建 /var/log/c-icap/ 目录并设置权限
#       3. 创建 /var/db/antivirus/ 目录并设置权限
#       4. 检测 os-squid 是否已安装，未安装则在日志中写入提示
#       5. 检测 os-clamav 是否已安装，已安装则写入冲突警告
#
#   antivirus_uninstall()
#     → 卸载时执行:
#       1. 调用 stop.sh 停止所有服务
#       2. 清空 squid_icap_include.conf
#       3. 调用 configctl proxy restart 使 Squid 以无 ICAP 模式运行
#       4. 删除 /var/db/antivirus/ 目录（含 SQLite 数据库）
#       5. 删除 /var/log/c-icap/ 目录下本插件产生的日志
#       6. 从 /conf/config.xml 中移除 <antivirus> 节点
#       注意: 不删除 clamav / c-icap FreeBSD 包本体（可能被其他东西依赖）

# 8.2 pkg 安装后脚本
# 路径: src/+POST-INSTALL
# 内容要求:
#   - 调用 antivirus_install() (通过 pluginctl 机制)
#   - 输出安装完成提示，告知用户去 Services > Antivirus 完成配置


# ============================================================
# TASK 9: 拦截页面 (Virus Block Page)
# ============================================================

# 9.1 静态拦截页 HTML
# 路径: src/usr/local/www/antivirus_block.html
# 内容要求:
#   - 简洁的"访问被拦截"页面，风格与 OPNsense 错误页保持一致
#   - 显示内容: 拦截原因 (Virus Detected)、检测到的签名名称、来源 URL
#     (签名和 URL 由 squidclamav 通过 redirect 参数的 query string 传入)
#   - 提供"返回上一页"链接
#   - 页面文字通过 URL 参数动态填充 (JavaScript 读取 ?sig=xxx&url=xxx)
#   - 禁止硬编码任何语言文字，所有展示文字通过 JS 变量定义在页面顶部
#     方便后续多语言扩展

# 9.2 squidclamav redirect 参数配置
# 在 squidclamav.conf 模板 (TASK 4.3) 中:
#   redirect http://127.0.0.1/antivirus_block.html?url=%url&sig=%virus
# 说明:
#   - %url 和 %virus 是 squidclamav 的内置替换变量
#   - 拦截页通过 JS 的 URLSearchParams 解析这两个参数并展示


# ============================================================
# TASK 10: 完整目录树总览（供 Codex 建立文件骨架）
# ============================================================

# plugins/security/anti-virus/
# ├── Makefile
# ├── pkg-descr
# └── src/
#     ├── etc/
#     │   ├── cron.d/
#     │   │   └── antivirus-healthcheck
#     │   ├── inc/
#     │   │   └── plugins.inc.d/
#     │   │       └── antivirus.inc
#     │   ├── rc.conf.d/
#     │   │   └── antivirus
#     │   └── rc.d/
#     │       ├── antivirus
#     │       └── antivirus-logparser
#     ├── usr/
#     │   └── local/
#     │       └── www/
#     │           └── antivirus_block.html
#     └── opnsense/
#         ├── mvc/
#         │   └── app/
#         │       ├── controllers/
#         │       │   └── OPNsense/
#         │       │       └── Antivirus/
#         │       │           ├── Api/
#         │       │           │   ├── ServiceController.php
#         │       │           │   ├── SettingsController.php
#         │       │           │   └── LogController.php
#         │       │           ├── forms/
#         │       │           │   ├── general.xml
#         │       │           │   └── advanced.xml
#         │       │           └── GeneralController.php
#         │       ├── locale/
#         │       │   ├── en_US/
#         │       │   │   └── LC_MESSAGES/
#         │       │   │       └── OPNsense.Antivirus.po
#         │       │   └── zh_CN/
#         │       │       └── LC_MESSAGES/
#         │       │           └── OPNsense.Antivirus.po
#         │       ├── models/
#         │       │   └── OPNsense/
#         │       │       └── Antivirus/
#         │       │           ├── ACL/
#         │       │           │   └── ACL.xml
#         │       │           ├── Menu/
#         │       │           │   └── Menu.xml
#         │       │           ├── General.php
#         │       │           └── General.xml
#         │       └── views/
#         │           └── OPNsense/
#         │               └── Antivirus/
#         │                   ├── general.volt
#         │                   ├── dashboard.volt
#         │                   ├── log.volt
#         │                   └── advanced.volt
#         ├── scripts/
#         │   └── OPNsense/
#         │       └── Antivirus/
#         │           ├── start.sh
#         │           ├── stop.sh
#         │           ├── reload.sh
#         │           ├── status.sh
#         │           ├── healthcheck.py
#         │           ├── log_parser.py
#         │           └── db_init.py
#         └── service/
#             ├── conf/
#             │   └── actions.d/
#             │       └── actions_antivirus.conf
#             └── templates/
#                 └── OPNsense/
#                     └── Antivirus/
#                         ├── c-icap.conf
#                         ├── squidclamav.conf
#                         ├── clamd.conf
#                         ├── freshclam.conf
#                         └── squid_icap_include.conf

# ============================================================
# TASK 11: 补充缺失项
# ============================================================

# 11.1 .mo 编译产物
# 在 Makefile 中追加 build 目标:
#   对 locale/en_US/LC_MESSAGES/OPNsense.Antivirus.po 执行 msgfmt
#   对 locale/zh_CN/LC_MESSAGES/OPNsense.Antivirus.po 执行 msgfmt
#   输出 .mo 文件到同目录
# 同时在 +POST-INSTALL 中补充:
#   若 .mo 不存在则执行 msgfmt（兜底，应对直接 pkg install 的场景）

# 11.2 +TARGETS 模板索引文件
# 路径: src/opnsense/service/templates/OPNsense/Antivirus/+TARGETS
# 内容: 五条模板→目标路径映射（见上方格式）
# 注意: squid_icap_include.conf 的目标路径需与
#       os-squid 的 include 指令引用路径严格一致

# 11.3 +POST-DEINSTALL 卸载后脚本
# 路径: src/+POST-DEINSTALL
# 内容要求:
#   1. 执行 stop.sh 停止所有服务
#   2. 清空 /usr/local/etc/squid/antivirus_icap.conf
#   3. 执行 configctl proxy restart
#   4. 删除 /var/db/antivirus/ 目录
#   5. 删除 /var/log/c-icap/ 目录下本插件的日志文件

# 11.4 Squid include 注入机制（需先确认 os-squid 支持方式）
# 调查步骤:
#   查看 plugins/www/squid/src/opnsense/service/templates/OPNsense/Proxy/
#   下的 squid.conf 模板末尾是否有 include 占位符或 %include% 指令
#
# 若 os-squid 模板支持外部 include 目录（如 conf.d/）:
#   → +TARGETS 中将 squid_icap_include.conf 目标路径设为
#     /usr/local/etc/squid/conf.d/antivirus_icap.conf
#   → 无需修改 os-squid 任何文件
#
# 若 os-squid 模板不支持:
#   → start.sh 在渲染模板后，检查 squid.conf 末尾是否已有 include 行
#   → 若没有则 echo 追加一行:
#     "include /usr/local/etc/squid/antivirus_icap.conf"
#   → stop.sh 在停止服务后，用 sed 删除该行
#   → 这个方式有副作用: os-squid 下次渲染 squid.conf 时会覆盖追加的行
#     因此 start.sh 需要在每次 configctl proxy restart 之前重新追加
#
# 建议: 优先确认 os-squid 模板是否有 conf.d 支持，
#        这是最干净的注入方式，不依赖 sed 字符串操作

