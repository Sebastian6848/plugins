# ============================================================
# os-antivirus MVP 任务拆解 (精简版，无多语言)
# 目标: 流量经过 Squid 时能检测并拦截病毒
# 路径: plugins/security/anti-virus
# 技术栈: virus_scan.so + clamd_mod.so + clamd unix socket
#
# 重要: 所有文件的结构、命名规范、数据链路必须与以下两个插件完全一致:
#   - plugins/www/c-icap
#   - plugins/security/clamav
# 遇到任何实现细节不确定的地方，优先参考这两个插件的对应文件，
# 不要自行发明新的写法。
# ============================================================


# ============================================================
# TASK 0: 顶层包结构
# 完全参考 plugins/security/clamav/Makefile 的格式
# ============================================================

# 0.1 Makefile
# 路径: plugins/security/anti-virus/Makefile
# 参考: plugins/security/clamav/Makefile
# 内容:
#   PLUGIN_NAME=        anti-virus
#   PLUGIN_VERSION=     1.0.0
#   PLUGIN_COMMENT=     Integrated Antivirus proxy (c-icap + ClamAV)
#   PLUGIN_DEPENDS=     os-squid clamav c_icap
#   PLUGIN_MAINTAINER=  你的邮箱
#   .include "../../Mk/plugins.mk"

# 0.2 pkg-descr
# 路径: plugins/security/anti-virus/pkg-descr
# 参考: plugins/security/clamav/pkg-descr
# 内容: 简短英文描述，说明本插件整合 c-icap + ClamAV，依赖 os-squid


# ============================================================
# TASK 1: 配置模型层
# 完全参考 plugins/security/clamav/src/opnsense/mvc/app/models/OPNsense/ClamAV/
# 目录结构、文件命名、XML 格式必须与 ClamAV 插件完全一致
# ============================================================

# 1.1 General.xml
# 路径: src/opnsense/mvc/app/models/OPNsense/Antivirus/General.xml
# 参考: plugins/security/clamav/.../ClamAV/General.xml
# mount: //OPNsense/antivirus/general
# 字段 (只有两个):
#   enabled         BooleanField  Default=0  Required=Y
#   max_scan_size   TextField     Default=5M Required=Y

# 1.2 General.php
# 路径: src/opnsense/mvc/app/models/OPNsense/Antivirus/General.php
# 参考: plugins/security/clamav/.../ClamAV/General.php
# 直接照抄，只改类名和 namespace 为 Antivirus

# 1.3 Menu/Menu.xml
# 路径: src/opnsense/mvc/app/models/OPNsense/Antivirus/Menu/Menu.xml
# 参考: plugins/security/clamav/.../ClamAV/Menu/Menu.xml
# 只注册一个菜单入口:
#   Services > Antivirus → /ui/antivirus/general

# 1.4 ACL/ACL.xml
# 路径: src/opnsense/mvc/app/models/OPNsense/Antivirus/ACL/ACL.xml
# 参考: plugins/security/clamav/.../ClamAV/ACL/ACL.xml
# 直接照抄，只改权限组名称为 page-services-antivirus
# 覆盖路径: /ui/antivirus/* 和 /api/antivirus/*


# ============================================================
# TASK 2: 控制器层
# 完全参考 plugins/security/clamav/src/opnsense/mvc/app/controllers/OPNsense/ClamAV/
# 和 plugins/www/c-icap/src/opnsense/mvc/app/controllers/OPNsense/CICAP/
# ============================================================

# 2.1 GeneralController.php
# 路径: src/opnsense/mvc/app/controllers/OPNsense/Antivirus/GeneralController.php
# 参考: plugins/security/clamav/.../ClamAV/GeneralController.php
# 直接照抄，只改 namespace、类名、view 路径为 Antivirus
# indexAction() → 渲染 general.volt

# 2.2 Api/ServiceController.php
# 路径: src/opnsense/mvc/app/controllers/OPNsense/Antivirus/Api/ServiceController.php
# 参考: plugins/www/c-icap/.../CICAP/Api/ 下的 ServiceController
# 参考: plugins/security/clamav/.../ClamAV/Api/ 下的 ServiceController
# 方法:
#   startAction()   → configctl antivirus start
#   stopAction()    → configctl antivirus stop
#   statusAction()  → configctl antivirus status，返回 JSON

# 2.3 Api/SettingsController.php
# 路径: src/opnsense/mvc/app/controllers/OPNsense/Antivirus/Api/SettingsController.php
# 参考: plugins/security/clamav/.../ClamAV/Api/ 下的 SettingsController
# 直接照抄，只改:
#   $internalModelName  = 'general'
#   $internalModelClass = 'OPNsense\Antivirus\General'
# 实现标准 getAction() / setAction()

# 2.4 forms/general.xml
# 路径: src/opnsense/mvc/app/controllers/OPNsense/Antivirus/forms/general.xml
# 参考: plugins/security/clamav/.../ClamAV/forms/ 下的任意表单文件
# 参考: plugins/www/c-icap/.../CICAP/forms/ 下的任意表单文件
# 字段只有两个:
#   enabled        (对应 General.xml 中的 enabled 字段)
#   max_scan_size  (对应 General.xml 中的 max_scan_size 字段)


# ============================================================
# TASK 3: 视图层
# 参考 plugins/security/clamav/.../ClamAV/views/
# 和   plugins/www/c-icap/.../CICAP/views/
# ============================================================

# 3.1 general.volt
# 路径: src/opnsense/mvc/app/views/OPNsense/Antivirus/general.volt
# 参考: plugins/security/clamav/.../ClamAV/views/ 下的 volt 文件
# 参考: plugins/www/c-icap/.../CICAP/views/ 下的 volt 文件
# 内容:
#   - 两个状态指示灯: ClamAV Engine / ICAP Service
#     数据来源: GET /api/antivirus/service/status
#     返回 JSON: {"clamd":"running|stopped","cicap":"running|stopped"}
#     running 显示绿色，stopped 显示红色
#   - SimpleForm 渲染 forms/general.xml (enabled + max_scan_size 两个字段)
#   - 保存按钮 → POST /api/antivirus/settings/set
#   - 应用按钮 → 根据 enabled 值调用 start 或 stop


# ============================================================
# TASK 4: 服务层
# 完全参考 plugins/security/clamav/src/opnsense/service/
# 和       plugins/www/c-icap/src/opnsense/service/
# 目录结构、文件格式必须与这两个插件完全一致
# ============================================================

# 4.1 actions_antivirus.conf
# 路径: src/opnsense/service/conf/actions.d/actions_antivirus.conf
# 参考: plugins/security/clamav/.../service/conf/actions.d/actions_clamav.conf
# 参考: plugins/www/c-icap/.../service/conf/actions.d/ 下的 action 文件
# 格式必须与参考文件完全一致，包括字段顺序和缩进方式
# 动作清单:
#
#   [antivirus.start]
#   command: /usr/local/opnsense/scripts/OPNsense/Antivirus/start.sh
#   type: script
#   message: starting antivirus
#
#   [antivirus.stop]
#   command: /usr/local/opnsense/scripts/OPNsense/Antivirus/stop.sh
#   type: script
#   message: stopping antivirus
#
#   [antivirus.reload]
#   command: /usr/local/opnsense/scripts/OPNsense/Antivirus/reload.sh
#   type: script
#   message: reloading antivirus config
#
#   [antivirus.status]
#   command: /usr/local/opnsense/scripts/OPNsense/Antivirus/status.sh
#   type: script_output
#   message: query antivirus status

# 4.2 +TARGETS
# 路径: src/opnsense/service/templates/OPNsense/Antivirus/+TARGETS
# 参考: plugins/security/clamav/.../service/templates/OPNsense/ClamAV/+TARGETS
# 参考: plugins/www/c-icap/.../service/templates/ 下的 +TARGETS
# 格式必须与参考文件完全一致
# 内容 (两条映射):
#   c-icap.conf:/usr/local/etc/c-icap/c-icap.conf
#   squid_icap_include.conf:/usr/local/etc/squid/post-auth/antivirus_icap.conf

# 4.3 c-icap.conf 模板
# 路径: src/opnsense/service/templates/OPNsense/Antivirus/c-icap.conf
# 参考: plugins/www/c-icap/.../service/templates/ 下的 conf 模板
# 变量语法必须与参考文件完全一致 (OPNsense Jinja2 模板语法)
# 变量来源: //OPNsense/antivirus/general
# 内容:
#   ServerPort 1344
#   TmpDir /tmp
#   MaxMemObject 4096
#   Module common clamd_mod.so
#   clamd_mod.ClamdSocket /var/run/clamav/clamd.sock
#   Service antivirus virus_scan.so
#   virus_scan.ScanFileTypes TEXT DATA EXECUTABLE ARCHIVE GIF JPEG MSOFFICE
#   virus_scan.Allow204Responces on
#   virus_scan.PassOnError on
#   virus_scan.MaxObjectSize [max_scan_size 的模板变量，语法参考 clamav 模板]

# 4.4 squid_icap_include.conf 模板
# 路径: src/opnsense/service/templates/OPNsense/Antivirus/squid_icap_include.conf
# 参考: plugins/www/c-icap/.../service/templates/ 下带条件判断的模板写法
# 逻辑: enabled=1 时渲染以下内容，enabled=0 时输出空文件
# 条件判断语法必须参考 clamav 或 c-icap 模板里的 if 写法，不要自行发明
# 内容 (enabled=1 时):
#   icap_enable on
#   icap_service service_av respmod_precache icap://127.0.0.1:1344/antivirus
#   adaptation_access service_av allow all
#   icap_preview_enable on
#   icap_send_client_ip on
#   icap_service_failure_limit -1


# ============================================================
# TASK 5: 脚本层
# 参考 plugins/security/clamav/src/opnsense/scripts/OPNsense/ClamAV/
# 和   plugins/www/c-icap/src/opnsense/scripts/OPNsense/CICAP/
# shell 脚本的风格、错误处理方式必须与参考文件保持一致
# ============================================================

# 5.1 start.sh
# 路径: src/opnsense/scripts/OPNsense/Antivirus/start.sh
# 执行步骤 (严格按顺序，每步失败立即 exit 1):
#   1. configctl template reload OPNsense/Antivirus
#   2. 检查 /var/run/clamav/clamd.sock 是否存在
#      不存在则执行 service clamav-clamd onestart
#      每秒轮询一次，最多等待 120 秒
#      超时则输出错误并 exit 1
#   3. service c-icap onestart
#   4. configctl proxy restart

# 5.2 stop.sh
# 路径: src/opnsense/scripts/OPNsense/Antivirus/stop.sh
# 执行步骤:
#   1. service c-icap onestop
#   2. 向 /usr/local/etc/squid/post-auth/antivirus_icap.conf 写入空内容
#   3. configctl proxy restart

# 5.3 reload.sh
# 路径: src/opnsense/scripts/OPNsense/Antivirus/reload.sh
# 执行步骤:
#   1. configctl template reload OPNsense/Antivirus
#   2. service c-icap onereload
#   3. configctl proxy restart

# 5.4 status.sh
# 路径: src/opnsense/scripts/OPNsense/Antivirus/status.sh
# 参考: plugins/security/clamav/.../ClamAV/ 下的 status 相关脚本
# 输出合法 JSON，检查两项:
#   clamd: /var/run/clamav/clamd.sock 存在则 running，否则 stopped
#   cicap: sockstat -l 输出中包含 1344 则 running，否则 stopped
# 输出格式严格为:
#   {"clamd":"running","cicap":"running"}


# ============================================================
# TASK 6: 安装钩子
# 完全参考 plugins/security/clamav/src/etc/inc/plugins.inc.d/clamav.inc
# ============================================================

# 6.1 antivirus.inc
# 路径: src/etc/inc/plugins.inc.d/antivirus.inc
# 参考: plugins/security/clamav/src/etc/inc/plugins.inc.d/clamav.inc
# 函数 (格式与 clamav.inc 完全一致，只改函数名前缀和具体逻辑):
#
#   antivirus_enabled()
#     读取 //OPNsense/antivirus/general/enabled
#     返回 true/false
#
#   antivirus_configure()
#     调用 configctl template reload OPNsense/Antivirus
#     调用 configctl antivirus reload
#
#   antivirus_install()
#     检查 /usr/local/etc/squid/post-auth/ 目录是否存在，不存在则创建
#     创建空的 antivirus_icap.conf（若不存在）

# 6.2 +POST-INSTALL
# 路径: src/+POST-INSTALL
# 参考: plugins/security/clamav/ 下的 +POST-INSTALL (若存在)
# 内容: 调用 antivirus_install()

# 6.3 +POST-DEINSTALL
# 路径: src/+POST-DEINSTALL
# 内容:
#   执行 stop.sh
#   删除 /usr/local/etc/squid/post-auth/antivirus_icap.conf


# ============================================================
# TASK 7: 完整目录树
# ============================================================

# plugins/security/anti-virus/
# ├── Makefile
# ├── pkg-descr
# └── src/
#     ├── etc/
#     │   └── inc/plugins.inc.d/
#     │       └── antivirus.inc
#     └── opnsense/
#         ├── mvc/app/
#         │   ├── controllers/OPNsense/Antivirus/
#         │   │   ├── Api/
#         │   │   │   ├── ServiceController.php
#         │   │   │   └── SettingsController.php
#         │   │   ├── forms/
#         │   │   │   └── general.xml
#         │   │   └── GeneralController.php
#         │   ├── models/OPNsense/Antivirus/
#         │   │   ├── ACL/ACL.xml
#         │   │   ├── Menu/Menu.xml
#         │   │   ├── General.php
#         │   │   └── General.xml
#         │   └── views/OPNsense/Antivirus/
#         │       └── general.volt
#         ├── scripts/OPNsense/Antivirus/
#         │   ├── start.sh
#         │   ├── stop.sh
#         │   ├── reload.sh
#         │   └── status.sh
#         └── service/
#             ├── conf/actions.d/
#             │   └── actions_antivirus.conf
#             └── templates/OPNsense/Antivirus/
#                 ├── +TARGETS
#                 ├── c-icap.conf
#                 └── squid_icap_include.conf


# ============================================================
# Codex 执行顺序
# ============================================================

# STEP 1: 建立完整目录骨架，创建所有空文件占位
#         完成后确认目录树与 TASK 7 完全一致

# STEP 2: Makefile + pkg-descr
#         完成后确认 make 不报错

# STEP 3: General.xml + General.php + Menu.xml + ACL.xml
#         完成后确认 XML 无语法错误

# STEP 4: +TARGETS + c-icap.conf 模板 + squid_icap_include.conf 模板
#         完成后手动验证:
#           configctl template reload OPNsense/Antivirus
#           cat /usr/local/etc/c-icap/c-icap.conf        ← 检查内容正确
#           cat /usr/local/etc/squid/post-auth/antivirus_icap.conf ← 检查内容正确

# STEP 5: actions_antivirus.conf
#         完成后验证:
#           service configd restart
#           configctl antivirus status   ← 不报 "No such action" 即为成功

# STEP 6: start.sh / stop.sh / reload.sh / status.sh
#         完成后验证:
#           configctl antivirus start
#           sockstat -l | grep 1344      ← 有输出则 c-icap 启动成功
#           configctl antivirus status   ← 两个字段均为 running

# STEP 7: forms/general.xml + GeneralController.php
#         + Api/ServiceController.php + Api/SettingsController.php

# STEP 8: general.volt
#         完成后在浏览器中打开 Services > Antivirus
#         确认状态指示灯、表单字段、按钮均正常显示

# STEP 9: antivirus.inc + +POST-INSTALL + +POST-DEINSTALL

# STEP 10: 端到端验证
#           通过代理下载 http://www.eicar.org/download/eicar.com
#           确认请求被拦截，未收到文件内容
