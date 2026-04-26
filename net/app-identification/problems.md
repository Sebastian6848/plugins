━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
【项目背景与任务说明】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

我正在开发一个 OPNsense 插件，路径为 plugins/net/app-identification。

项目目标：
在不修改 ntopng 本体的前提下，通过调用 ntopng REST API 获取数据，
将 ntopng 的以下功能模块用 OPNsense 原生风格重写 UI：
  1. 活动流页面（Active Flows）
  2. 应用程序页面（Applications）
  3. ntopng 配置页面（Settings，从原 os-ntopng 插件迁移）

技术环境：
  - 平台：OPNsense FreeBSD 14.3
  - ntopng 版本：6.6.260409
  - ntopng 运行地址：http://127.0.0.1:3000
  - 后端：PHP 8.x + OPNsense MVC 框架（Phalcon）
  - 前端：Bootstrap 4 + jQuery + DataTables（OPNsense 原生风格）

当前状态：
插件骨架和主要功能已由上一个 Codex 会话完成编写，
但存在若干经过实机调试发现的问题，需要你来修复。
以下所有问题均已通过 SSH 在真实 OPNsense 设备上验证。

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
【实机验证结论（以此为准，不得假设）】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. ntopng REST API 认证方式：
   ✅ API Token 认证可用（推荐）：
      Header: Authorization: Token <token_string>
   ✅ Session Cookie 认证可用（Fallback）：
      先 POST /authorize.html 登录，获取 cookie 名为 session_3000_0

2. 已验证可用的 endpoint：
   ✅ /lua/rest/v2/get/flow/active.lua?ifid=0
      （需要参数 ifid，默认为 0）

3. 已验证不可用的 endpoint（在 ntopng 6.6 中返回 not_found）：
   ❌ /lua/rest/v2/get/system/info.lua
   ❌ /lua/rest/v2/get/ntopng/info.lua
   ❌ /lua/rest/v2/get/interfaces/data.lua

4. 活动流 API 实际返回的 JSON 结构（字段以此为准）：
{
  "rc": 0,
  "rc_str": "OK",
  "rc_str_hr": "OK",
  "rsp": {
    "totalRows": 33,
    "currentPage": 1,
    "perPage": 10,
    "sort": [["column_", "desc"]],
    "data": [
      {
        "key": "336878088",
        "hash_id": "12420",
        "duration": 507,
        "first_seen": 1777206427,
        "last_seen": 1777206933,
        "bytes": 1071328,
        "vlan": 0,
        "protocol": { "l4": "TCP", "l7": "SSH" },
        "client": {
          "ip": "10.10.10.1", "port": 64303,
          "name": "lzd-20260309psk", "country": "",
          "is_blacklisted": false, "is_dhcp": false,
          "is_broadcast_domain": true
        },
        "server": {
          "ip": "10.10.10.6", "port": 22,
          "name": "OPNsense", "country": "",
          "is_blacklisted": false, "is_dhcp": false,
          "is_broadcast": true
        },
        "thpt": { "bps": 1099.55, "pps": 2.00 },
        "breakdown": { "cli2srv": 36, "srv2cli": 64 }
      }
    ]
  }
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
【待修复问题列表（按优先级排序）】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

── P0 阻断性问题 ──────────────────

问题 1：REST API 基址硬编码
文件：GeneralController.php:25
现状：IP 地址被硬编码为某个固定值，换机器部署即失效
修复：
  - 从模型 AppIdentification 动态读取 rest_host（默认 127.0.0.1）和 rest_port（默认 3000）
  - 在 AppIdentification.xml 中声明这两个字段
  - 在 Settings 页面 UI 中暴露这两个字段供用户配置

问题 2：认证方式错误导致"Invalid JSON returned by ntopng"
文件：GeneralController.php proxyRequest 方法
现状：未正确处理 ntopng 认证，ntopng 返回 302 跳转到登录页，
      PHP 将 HTML 当 JSON 解析失败，前端报错
修复：实现以下认证逻辑

  private function proxyRequest(string $endpoint, array $params = []): array
  {
      $host  = $this->getModel()->rest_host ?? '127.0.0.1';
      $port  = $this->getModel()->rest_port ?? '3000';
      $token = trim((string)($this->getModel()->auth_token ?? ''));

      $url = "http://{$host}:{$port}/{$endpoint}";
      if (!empty($params)) {
          $url .= '?' . http_build_query($params);
      }

      $headers = ['Accept: application/json'];
      $cookieStr = '';

      if (!empty($token)) {
          // 优先：Token 认证
          $headers[] = "Authorization: Token {$token}";
      } else {
          // Fallback：Session Cookie 认证
          $cookieStr = $this->getNtopngSession();
          if (empty($cookieStr)) {
              return ['status' => 'error', 'message' => '请在设置页面配置 ntopng API Token 或用户名密码'];
          }
      }

      $ch = curl_init($url);
      curl_setopt_array($ch, [
          CURLOPT_RETURNTRANSFER => true,
          CURLOPT_HTTPHEADER     => $headers,
          CURLOPT_TIMEOUT        => 10,
          CURLOPT_FOLLOWLOCATION => false,
      ]);
      if (!empty($cookieStr)) {
          curl_setopt($ch, CURLOPT_COOKIE, $cookieStr);
      }

      $body     = curl_exec($ch);
      $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
      curl_close($ch);

      if ($httpCode === 302) {
          syslog(LOG_ERR, 'AppIdentification: ntopng 认证失败(302)，请检查 Token 或账号密码');
          return ['status' => 'error', 'message' => 'ntopng 认证失败，请检查 Settings 中的认证配置'];
      }

      $data = json_decode($body, true);
      if (json_last_error() !== JSON_ERROR_NONE) {
          syslog(LOG_ERR, 'AppIdentification: ntopng 返回非 JSON 内容: ' . substr($body, 0, 300));
          return ['status' => 'error', 'message' => 'Invalid JSON returned by ntopng'];
      }
      return $data;
  }

  // Session Cookie 登录方法（Fallback）
  // 注意：ntopng 的 cookie 名称格式为 session_{port}_{index}，如 session_3000_0
  private function getNtopngSession(): string
  {
      $host = $this->getModel()->rest_host ?? '127.0.0.1';
      $port = $this->getModel()->rest_port ?? '3000';
      $user = $this->getModel()->auth_username ?? 'admin';
      $pass = $this->getModel()->auth_password ?? '';

      $ch = curl_init("http://{$host}:{$port}/authorize.html");
      curl_setopt_array($ch, [
          CURLOPT_POST           => true,
          CURLOPT_POSTFIELDS     => http_build_query(['user' => $user, 'password' => $pass]),
          CURLOPT_RETURNTRANSFER => true,
          CURLOPT_HEADER         => true,
          CURLOPT_FOLLOWLOCATION => false,
          CURLOPT_TIMEOUT        => 10,
      ]);
      $response = curl_exec($ch);
      curl_close($ch);

      if (strpos($response, 'wrong-credentials') !== false) {
          syslog(LOG_ERR, 'AppIdentification: ntopng 用户名或密码错误');
          return '';
      }

      // cookie 名称格式：session_{port}_{index}
      preg_match('/Set-Cookie:\s*(session_' . $port . '_\d+=[^;]+)/i', $response, $matches);
      return $matches[1] ?? '';
  }

问题 3：API endpoint 路径错误
文件：GeneralController.php、FlowsController.php、ApplicationsController.php
现状：代码中使用的 endpoint 路径在 ntopng 6.6 中不存在，返回 not_found
修复：
  - 将所有对 /lua/rest/v2/get/system/info.lua 的引用
    改为用活动流 endpoint 探测存活状态：
    lua/rest/v2/get/flow/active.lua?ifid=0&perPage=1
  - 所有需要 ifid 的 endpoint 统一通过 getIfid() 方法获取：
    private function getIfid(): int {
        return (int)($this->getModel()->ifid ?? 0);
    }

问题 4：ntopng_proxy.inc reconfigure 钩子硬编码
文件：src/etc/inc/plugins.inc.d/ntopng_proxy.inc:44
现状：reconfigure 使用硬编码参数，系统重启时会覆盖用户配置
修复：改为读取 AppIdentification 模型当前配置动态构造参数，
      与 Settings 页面 Save 走同一个配置生成入口

── P1 功能缺失 ────────────────────

问题 5：活动流字段映射错误
文件：FlowsController.php mapFlowRecord 方法
现状：字段映射与实际 JSON 结构不符，导致表格列数据为空
修复：完全基于已验证的 JSON 结构重写映射：

  private function mapFlowRecord(array $flow): array
  {
      $client = $flow['client'] ?? [];
      $server = $flow['server'] ?? [];
      $proto  = $flow['protocol'] ?? [];
      $thpt   = $flow['thpt'] ?? [];

      $duration    = (int)($flow['duration'] ?? 0);
      $durationFmt = sprintf('%02d:%02d', intdiv($duration, 60), $duration % 60);

      $bytes    = (int)($flow['bytes'] ?? 0);
      $bytesFmt = $this->formatBytes($bytes);

      $bps     = (float)($thpt['bps'] ?? 0);
      $thptFmt = $this->formatBps($bps);

      return [
          'flow_key'    => $flow['key'] ?? $flow['hash_id'] ?? '',
          'hash_id'     => $flow['hash_id'] ?? '',
          'last_seen'   => date('H:i:s', $flow['last_seen'] ?? time()),
          'duration'    => $durationFmt,
          'protocol'    => ($proto['l4'] ?? '') . ':' . ($proto['l7'] ?? ''),
          'l4_proto'    => $proto['l4'] ?? '',
          'l7_proto'    => $proto['l7'] ?? '',
          'score'       => $flow['score'] ?? 0,
          'client'      => ($client['name'] ?: ($client['ip'] ?? '')) . ':' . ($client['port'] ?? ''),
          'client_ip'   => $client['ip'] ?? '',
          'server'      => ($server['name'] ?: ($server['ip'] ?? '')) . ':' . ($server['port'] ?? ''),
          'server_ip'   => $server['ip'] ?? '',
          'throughput'  => $thptFmt,
          'total_bytes' => $bytesFmt,
          'bytes_raw'   => $bytes,
          'breakdown'   => $flow['breakdown'] ?? [],
          'is_blacklisted' => ($client['is_blacklisted'] ?? false)
                           || ($server['is_blacklisted'] ?? false),
      ];
  }

  private function formatBytes(int $bytes): string
  {
      if ($bytes >= 1073741824) return round($bytes / 1073741824, 2) . ' GB';
      if ($bytes >= 1048576)    return round($bytes / 1048576, 2) . ' MB';
      if ($bytes >= 1024)       return round($bytes / 1024, 2) . ' KB';
      return $bytes . ' B';
  }

  private function formatBps(float $bps): string
  {
      if ($bps >= 1000000) return round($bps / 1000000, 2) . ' Mbps';
      if ($bps >= 1000)    return round($bps / 1000, 2) . ' Kbps';
      return round($bps, 2) . ' bps';
  }

问题 6：规则写入未走特权脚本链路
文件：ApplicationsController.php:293、:468
现状：PHP 直接写 protos.txt，跳过了 ntopng_api_proxy.sh 的备份和属主处理
修复：改为通过 configd 调用脚本：
  $backend  = new Backend();
  $response = $backend->configdpRun('appidentification write_rules', [json_encode($rules)]);
  // 写入成功后自动触发 reload
  $backend->configdRun('appidentification reload');

问题 7：保存规则后不自动 reload
文件：applications.volt:172
现状：保存规则后只刷新列表，需要用户手动点 Apply 才能生效
修复：在保存成功回调中自动级联调用 applyRules endpoint：
  // 保存成功后
  $.ajax({
      url: '/api/appidentification/applications/applyRules',
      method: 'POST',
      success: function() {
          // 显示"规则已保存并应用"
      }
  });

问题 8：L7 应用统计 endpoint 不可用时无降级处理
文件：ApplicationsController.php listAction()
现状：若 L7 endpoint 返回 not_found，应用程序页面完全空白
修复：添加降级逻辑，从活动流数据聚合 L7 统计：

  if (($result['rc'] ?? -1) !== 0) {
      $flowResult = $this->proxyRequest(
          'lua/rest/v2/get/flow/active.lua',
          ['ifid' => $this->getIfid(), 'perPage' => 100]
      );
      $result = $this->aggregateL7FromFlows($flowResult['rsp']['data'] ?? []);
  }

  private function aggregateL7FromFlows(array $flows): array
  {
      $stats = [];
      foreach ($flows as $flow) {
          $l7 = $flow['protocol']['l7'] ?? 'Unknown';
          if (!isset($stats[$l7])) {
              $stats[$l7] = ['protocol' => $l7, 'flows' => 0, 'bytes' => 0];
          }
          $stats[$l7]['flows']++;
          $stats[$l7]['bytes'] += (int)($flow['bytes'] ?? 0);
      }
      usort($stats, fn($a, $b) => $b['bytes'] - $a['bytes']);
      return ['rc' => 0, 'rsp' => array_values($stats)];
  }

── P2 优化建议 ────────────────────

问题 9：模型缺少认证字段
文件：AppIdentification.xml、forms/general.xml
修复：补充以下字段：
  <auth_token type="TextField">       <!-- API Token，推荐 -->
      <default></default>
  </auth_token>
  <auth_username type="TextField">    <!-- 用户名，Fallback -->
      <default>admin</default>
  </auth_username>
  <auth_password type="TextField">    <!-- 密码，Fallback -->
      <default></default>
  </auth_password>

在 Settings 页面 UI 中：
  - auth_token 标注"推荐：在 ntopng → 用户设置 → API Token 中生成"
  - auth_username / auth_password 标注"备用：Token 为空时使用"
  - 提供"测试连接"按钮，调用 statusAction() 验证配置是否有效

问题 10：前端缺少统一错误处理
文件：flows.volt、applications.volt、index.volt
修复：所有 Ajax 调用统一添加 error 回调，使用 BootstrapDialog 显示错误：
  error: function(xhr) {
      var msg = xhr.responseJSON ? xhr.responseJSON.message : '网络请求失败';
      BootstrapDialog.show({
          type: BootstrapDialog.TYPE_DANGER,
          title: '加载失败',
          message: msg,
          buttons: [{ label: '关闭', action: function(d){ d.close(); } }]
      });
  }

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
【验收标准】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

所有修复完成后，逐项确认：

□ Settings 页面填入 API Token 后点击"测试连接"，
  显示"连接成功，当前活动流 N 条"

□ ActiveFlows 页面正常加载，显示真实流量数据，
  列信息完整（协议/客户端/服务器/吞吐量/总字节数/持续时间）

□ 应用范围页面正常加载，Top 10 图表有数据

□ 自定义规则添加后无需手动点 Apply 即自动生效

□ 关闭 ntopng 服务后访问任意页面，
  显示统一风格的错误弹窗而非白屏

□ 修改 ntopng 密码后，Token 认证不受影响

□ 不再出现"Invalid JSON returned by ntopng"错误

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
【修复完成后输出】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

请输出：
1. 所有修改的文件列表及每个文件的关键变更摘要
2. 重新走一遍三条数据链路（活动流展示 / 规则保存 / 配置保存），
   确认每一跳均正确衔接
3. 是否引入了新的依赖或潜在问题
