# Industrial Whitelist v1.5 问题复盘与整改计划

本文档用于说明：
1) 当前插件的业务逻辑与数据流
2) 测试报告中问题的成因分析
3) 下一阶段的改造方案（按优先级分阶段）

---

## 1. 当前业务逻辑与数据流

### 1.1 控制面（UI / API / 配置）

- 入口页面：`Firewall -> Industrial Whitelist -> Configuration`
- 用户在规则表配置：
  - 源/目的、协议、读写控制（AllowedFunctionCodes）、StrictDPI
- 点击 Apply 时，调用 `ServiceController::reconfigureAction()`，执行顺序：
  1. `industrialwhitelist generate`（生成 Suricata 规则文件）
  2. `filter reload`（重载 pf）
  3. `ids reload`（重载 IDS 规则）

配置数据最终落在 `config.xml`，由：
- L4 Hook (`industrialwhitelist.inc`) 读取并注入 pf 规则
- L7 生成器 (`generate_suricata_rules.py`) 读取并编译 Suricata 规则

### 1.2 数据面（L4 与 L7）

#### L4 路径（pf）

- 为每条启用白名单规则注入 `pass in quick ...`（优先级 10000）
- 为受管工业端口注入默认动作（优先级 15000）
- 目标：先在内核快速做准入过滤与基础封堵

#### L7 路径（Suricata）

- 对 L7 协议（modbus_tcp / dnp3 / eip / mqtt）生成功能码/类型级规则
- 每条规则可加 StrictDPI：
  - 开启：生成 anti-spoof `drop app-layer-protocol:!xxx`
  - 关闭：生成 anti-spoof `alert app-layer-protocol:!xxx`
- 目标：在 L4 准入之后做协议语义级约束

### 1.3 日志路径

- 当前日志页面主要读取 pf/filter log 并过滤 `industrialwhitelist` 关键字
- Suricata 的 IPS drop/alert 结果未与插件日志统一聚合展示

---

## 2. 报告问题成因分析

以下分析基于当前代码行为与报告现象对应关系。

### 2.1 阻断不稳定、同策略结果波动

可能根因：

1. **状态残留（state persistence）未清理**
   - Apply 后未做受管流的状态清理，新旧策略切换时旧状态可能继续放行。
   - 典型表现：同配置重复测试时，前几次与后几次结果不一致。

2. **L4/L7 生效窗口不一致**
   - 目前按“生成->pf reload->ids reload”串行执行，但没有“事务化就绪检查”。
   - 在重载窗口期，可能出现短时行为漂移。

3. **非内联或接口绑定不完整时，L7 只能检测不能稳定阻断**
   - 如果 IDS 实际运行不是严格 IPS inline（或接口覆盖不完整），则会出现“能看到告警但实际未挡住”。

4. **规则生成侧的确定性不足**
   - 规则编译虽可用，但缺少“同配置同输出”的强约束校验（顺序、去重策略、冲突规则归并策略等）。

### 2.2 日志与业务结果不一致

可能根因：

1. **日志源异构**
   - 页面主要看 pf 日志，但 L7 行为发生在 Suricata，导致观察面不完整。

2. **日志时序差异**
   - pf 与 Suricata 写日志延迟、采集路径、展示刷新时机不同步。

3. **缺少“策略版本号/应用批次号”**
   - 日志无法标识属于哪次 Apply 生成的规则，排障时难以做因果对齐。

### 2.3 UI 可信度问题

1. **前提提示静态化**
   - 页面提示没有实时读取 IDS/IPS 状态，因此出现“已开启仍提示未开启”。

2. **缺少 Pending Changes 机制**
   - 修改后未 Apply 时没有统一显著提示，容易误判为已生效。

---

## 3. 改造目标

### 3.1 一致性目标

- 同一策略在重复测试中处置结果保持一致
- 策略切换后结果可预测，无明显窗口期漂移
- 读写分类（如 FC03/FC16）具备可重复阻断效果

### 3.2 可观测性目标

- 在一个页面内可同时看到 L4 与 L7 的关键处置证据
- 每条日志可关联到具体策略版本（Apply Revision）
- 具备“生效状态可验证”而非“仅配置成功”

---

## 4. 具体改造方案（计划）

## Phase A：生效链路确定性加固（最高优先）

1. Apply 改为“可验证发布流程”
   - 生成规则到临时文件
   - 语法与可加载性校验通过后再替换正式文件
   - 执行重载并等待状态确认（pf/ids status）
   - 返回结构化结果：成功/失败、失败阶段、错误详情

2. 增加状态清理策略（受管端口定向）
   - Apply 后对受管协议相关状态执行定向清理或按规则范围清理
   - 避免旧状态继续命中新策略

3. 加入“策略版本号（revision）”
   - 每次 Apply 生成唯一 revision
   - 写入规则注释与日志上下文，便于回放与对齐

## Phase B：规则编译确定性与冲突治理

1. 编译输出稳定化
   - 规则排序固定、SID 分配稳定、重复规则去重策略可解释

2. 严格模式冲突归并
   - 同协议同端口存在 strict/non-strict 混用时，给出明确优先级（建议 strict 优先）
   - 在 UI/Apply 结果中提示冲突归并行为

3. 别名与地址解析策略明确化
   - 对无法转为 Suricata 可用地址对象的规则给出显式告警
   - 避免“L4 生效、L7 跳过”但用户无感知

## Phase C：可观测性与日志平面统一

1. 日志聚合
   - 插件日志页同时聚合 pf 与 Suricata 关键事件
   - 可按 revision、协议、动作过滤

2. 实时性增强
   - 增加最近一次 Apply 生效状态卡片（时间、revision、引擎状态）
   - 明确当前为“已生效配置”还是“待应用配置”

## Phase D：UI 交互完善

1. 前提提示动态化
   - 实时读取 IDS Enabled / IPS mode / monitored interfaces
   - 满足前提后自动隐藏警告

2. Pending Changes 指示
   - 规则/设置变更后显示“未应用变更”横幅
   - Apply 成功后自动清除

---

## 5. 验收标准（Definition of Done）

1. 一致性回归
   - 同一配置下，连续 30 轮重复测试处置一致

2. 读写控制回归
   - 以 Modbus 为例：只读策略必须稳定阻断写操作，反向策略同理

3. 观测一致性
   - 插件日志、抓包、业务端结果三者可对齐
   - 每条关键事件可定位到具体 revision

4. UI 可用性
   - 前提状态实时正确
   - 未 Apply 变更有显著提示，Apply 后状态正确清除

---

## 6. 风险与边界

- 若部署环境非严格内联 IPS 路径，L7 阻断目标无法完全保证
- 不同协议解析器成熟度不同，需按协议分别做稳定性基线
- 高并发下状态清理策略需控制影响范围，避免误伤无关业务流

---

## 7. 下一步执行顺序

建议按以下顺序实施：
1. Phase A（生效链路 + 状态清理 + revision）
2. Phase B（规则确定性 + 冲突治理）
3. Phase C（日志聚合）
4. Phase D（UI 体验）

先完成 Phase A/B 后再进行你当前报告同场景复测，可显著提升“同策略同处置”的确定性。

---

## 8. 实施进度（当前）

### Phase A：已实现

已落地内容：

1. Apply 发布流水线重构（`ServiceController`）
   - 引入阶段化执行与阶段结果回传（`stages[]`）
   - 引入失败即停（generate/reload/flush/verify 任一失败直接返回 failed）
   - 增加 IDS 状态健康检查（`ids status`）

2. revision 与时间戳持久化
   - 每次 Apply 生成唯一 revision
   - 写入配置节点：`general.last_apply_revision`、`general.last_apply_timestamp`

3. 状态清理机制
   - 新增 `flush_states.sh`，优先按 `IW-HOOK` 标签清理关联 state
   - 新增 configd 动作：`industrialwhitelist flush_states`

4. Suricata 规则原子发布
   - 生成器改为“临时文件 + 校验 + `os.replace` 原子替换”
   - 输出头部附带 `apply_revision` / `apply_timestamp`

说明：Phase B/C/D 仍待继续实施。

### Phase B：已实现

已落地内容：

1. strict/non-strict 冲突归并（strict 优先）
   - anti-spoof 规则按 `(proto, port, app)` 聚合
   - 同一目标上若出现 strict 与 non-strict 混用，最终动作统一为 `drop`

2. 编译输出确定性增强
   - 输入规则按 `sequence -> protocol -> source -> destination -> description` 稳定排序
   - 读写分类按固定类别顺序编译，避免用户选择顺序导致输出波动

3. 规则去重与可解释性
   - pass 规则按 `(protocol, src, dst, function)` 去重
   - 协议兜底 deny 规则按 `(protocol, src, dst)` 去重
   - anti-spoof 规则统一在尾部按稳定顺序输出

### Phase C：已实现

已落地内容：

1. 日志聚合
   - 插件日志 API 已聚合 pf 与 Suricata 两条链路
   - 输出统一字段：`timestamp/engine/source/destination/protocol_port/revision/action/message`

2. revision 可观测性
   - pf 规则描述与 Suricata 规则 `msg` 均注入 `rev:<revision>` 标签
   - 日志页支持按 revision 过滤与导出

3. 生效状态卡片
   - 日志页展示最近一次 Apply 的 `revision`、`timestamp` 与 IDS 运行状态

### Phase D：已实现

已落地内容：

1. 前提提示动态化
   - 新增 `service/prereq_status` API，实时读取 IDS 开关/模式/接口状态
   - 配置页“前置条件提示”按状态自动显示/隐藏

2. Pending Changes 提示
   - 新增“未 Apply 变更”横幅
   - 设置项变更、规则增删改/排序后自动置为待应用
   - Apply 成功后自动清除

说明：当前 A/B/C/D 四个阶段均已完成首版实现，可进入综合回归测试与调优阶段。
