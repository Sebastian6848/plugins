项目背景：
    • 目标平台：OPNsense (FreeBSD 14.3)
    • 创建一个新的 OPNsense 插件，路径为 plugins/net/app-identification
    • 插件依赖：os-ntopng（已安装并运行在10.10.10.6:3000）
    • 不允许修改 ntopng 本体源码，只能通过 ntopng REST API 获取数据
    • ntopng REST API 基础路径：http://10.10.10.6:3000/lua/swagger.lua
    • 已提供 ntopng REST API 文档（/home/xwy/Firewall/plugins/net/app-indentification/ntopng_restapi.json）
    
技术栈约束：
    • 后端：PHP 8.x，使用 OPNsense MVC 框架（基于 Phalcon）
    • 前端：Bootstrap 4 + jQuery + DataTables（与 OPNsense 现有插件保持一致）
    • 配置管理：XML Model + Mako 模板
    • 服务控制：configd (.conf 文件定义命令)
设计原则：
    • 完全采用 OPNsense 风格（参考 plugins/net/haproxy 或 plugins/net/nginx 的目录结构）
    • ntopng 原始 Web 界面（端口 3000）继续保留，不影响其功能
新插件只在 OPNsense 主菜单提供"应用识别"入口

plugins/net/app-identification/
│
├── Makefile                                        # 插件元信息：名称、版本、依赖声明（PLUGIN_DEPENDS=ntopng）、冲突声明
├── pkg-descr                                       # pkg 包描述文件，显示在 OPNsense 插件列表中的说明文字
│
└── src/
    ├── etc/
    │   └── inc/
    │       └── plugins.inc.d/
    │           └── ntopng_proxy.inc                # PHP 钩子文件，向 OPNsense 核心注册本插件的服务、菜单和路由
    │
    └── opnsense/
        │
        ├── mvc/                                    # MVC 应用主目录，OPNsense 框架约定结构
        │   └── app/
        │       │
        │       ├── controllers/                    # 控制器层：处理 HTTP 请求，分为页面控制器和 API 控制器
        │       │   └── OPNsense/
        │       │       └── AppIdentification/
        │       │           │
        │       │           ├── Api/                # API 控制器：仅返回 JSON，供前端 Ajax 调用
        │       │           │   ├── GeneralController.php       # 通用 API：ntopng 连接状态、系统信息、代理请求基类
        │       │           │   ├── FlowsController.php         # 活动流 API：查询/过滤活动流数据，代理 ntopng /flow/active
        │       │           │   └── ApplicationsController.php  # 应用程序 API：L7 协议统计、自定义规则 CRUD、重启服务
        │       │           │
        │       │           ├── IndexController.php             # 页面控制器：渲染配置页（Settings），对应 index.volt
        │       │           ├── FlowsController.php             # 页面控制器：渲染活动流页面，对应 flows.volt
        │       │           └── ApplicationsController.php      # 页面控制器：渲染应用程序页面，对应 applications.volt
        │       │
        │       ├── models/                         # 模型层：定义配置数据结构，负责读写 OPNsense 的 config.xml
        │       │   └── OPNsense/
        │       │       └── AppIdentification/
        │       │           ├── AppIdentification.php           # 模型 PHP 类，继承 BaseModel，声明模型与 XML 的绑定关系
        │       │           ├── AppIdentification.xml           # 模型结构定义：所有配置字段、类型、默认值、校验规则
        │       │           └── ACL/
        │       │               └── ACL.xml                     # 权限定义：声明本插件的访问控制节点，控制哪些角色可访问
        │       │
        │       └── views/                          # 视图层：Volt 模板，渲染最终 HTML 页面
        │           └── OPNsense/
        │               └── AppIdentification/
        │                   ├── index.volt          # 配置页面视图：ntopng 服务配置表单（接口、端口、DNS 模式等）
        │                   ├── flows.volt          # 活动流页面视图：实时流量表格、筛选条件、自动刷新
        │                   └── applications.volt   # 应用程序页面视图：L7 流量图表、应用列表、自定义规则管理
        │
        ├── service/                                # configd 服务定义目录
        │   └── conf/
        │       └── actions.d/
        │           └── actions_appidentification.conf  # 定义可被前端调用的后台命令：重启 ntopng、健康检查等
        │
        └── scripts/                                # 后台 Shell/Python 脚本，由 configd 调用
            └── OPNsense/
                └── AppIdentification/
                    └── ntopng_api_proxy.sh         # Shell 脚本：处理需要在系统层执行的操作，如读写 protos.txt、检查进程状态
