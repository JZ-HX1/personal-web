# 命令行接口说明

此文档描述本项目的本地 CLI。当前没有 HTTP API、Web 服务或远程接口；以下子命令不会连接 ERP/OA、税务或支付系统。

## 调用约定

在子项目根目录安装可编辑包后调用：

```bash
python -m pip install -e .
python -m my_tool.main --help
```

输入文件使用 UTF-8。单据与制度为 JSON，事件为 CSV；`data/claim.json`、`config/policies.json` 和 `data/events.csv` 是本版本可运行输入示例。命令中的相对路径以当前工作目录为基准。

## 检查单据

```bash
python -m my_tool.main check data/claim.json --policies config/policies.json
```

| 参数 | 含义 |
|---|---|
| `check` 后的位置参数 | 单据 JSON 路径 |
| `--policies` | 必填，制度 JSON 路径 |

单据 JSON 顶层为对象，字段如下：

| 字段 | 格式 |
|---|---|
| `id`、`employee_id`、`policy_id` | 非空字符串，分别标识单据、员工和制度 |
| `travel_date` | 有效 `YYYY-MM-DD` 日期 |
| `amount` | 正数十进制字符串，最多两位小数，如 `"100.00"` |
| `project_codes` | 非空且不重复的项目编码字符串列表 |
| `attachments` | 附件类型字符串列表，要求包含 `invoice`、`travel_approval` |
| `allocations` | 非空对象列表，每项含 `project_code` 和十进制字符串 `amount` |

所有列出的字段均为检查合同的一部分。项目分摊必须覆盖本单项目且每个项目仅出现一次，合计与报销金额一致；多项目即使金额一致也要求人工确认。附件检查只关注类型声明，不读取或鉴定真实附件文件。

制度 JSON 顶层为列表，每条包含 `policy_id`、`version`、`effective_from`、`effective_to`、`project_codes`、`clause` 和布尔值 `confirmed`。生效期包含边界日；`effective_to` 可为 `null` 或省略，表示未设结束日。项目范围必须为非空列表，空列表不表示通配。只有唯一适用、已确认且候选记录有效的版本才可列入结果；存在多个适用版本或未确认规则时需人工处理。

JSON 结果包含 `claim_id`、`status`、`issues`、`policy` 和 `source_preserved`。`issues` 中每项含 `code` 与 `message`；可选定制度时 `policy` 保存版本及条款信息，否则为 `null`。

- `READY_FOR_REVIEW`：未发现预检问题，仅表示可以交人工审核。
- `NEEDS_MANUAL_REVIEW`：发现缺件、格式、金额、制度或其他待处理事项。

这两种结果的进程退出码都是 `0`，调用方必须检查 `status` 和 `issues`。不能仅凭退出成功认定业务批准。多项目分摊、制度冲突和依据不足均不构成自动审核通过。

随附普通单据的结果示例：

```json
{
  "claim_id": "DEMO-001",
  "status": "READY_FOR_REVIEW",
  "issues": [],
  "policy": {
    "policy_id": "DEMO-TRAVEL",
    "version": "2026-demo-1",
    "effective_from": "2026-01-01",
    "effective_to": "2026-12-31",
    "project_codes": ["P-DEMO-01", "P-DEMO-02"],
    "clause": "教学规则第1条：提交票据和出差申请，分摊总额应与单据金额一致。",
    "confirmed": true
  },
  "source_preserved": true
}
```

此命令不修改输入单据、制度文件或外部系统。

## 导入事件

```bash
python -m my_tool.main import-events data/events.csv --db .local/events.db
```

| 参数 | 含义 |
|---|---|
| `import-events` 后的位置参数 | 事件 CSV 路径 |
| `--db` | SQLite 数据库文件路径，默认 `.local/events.db` |

CSV 必需列为 `event_id,claim_id,event_type,event_time,source,source_version`，各列值均不能留空。事件键为 `(source, event_id)`；不同来源可有相同事件标识。额外命名列被忽略，重复表头、缺列或超出表头的行数据被拒绝。

`event_time` 为带时区的 ISO 日期时间，例如 `2026-10-20T09:00:00+08:00` 或 `2026-10-20T01:00:00Z`。入库前统一为 UTC，必需字段两侧空白会去除。支持的 `event_type` 为：

```text
submitted
supplement_requested
supplement_submitted
initial_approved
project_confirmed
review_approved
paid
```

不得将不含时区的本地时间作为可直接比较的业务时间。样例 `DEMO-001` 仅为合成业务编号。

导入会创建或更新指定数据库。一次文件导入是原子的：数据校验或同键内容冲突失败时，不留下该文件的部分事件。同一事件键且规范化内容相同的重复导入忽略；同一键内容不同视为冲突，不覆盖已有内容。成功输出 `{"imported": 5, "duplicates": 0}` 等统计，数量依实际输入而定。

重复导入是幂等性的验证方式，不能通过删除旧事件再导入来掩盖冲突。来源数据确需修正时，应先明确更正策略；当前命令不提供静默覆盖开关。

## 查看时间线

```bash
python -m my_tool.main timeline DEMO-001 --db .local/events.db
```

位置参数为要查询的单据编号。输出 JSON 事件列表，字段同导入合同，时间已规范化为 UTC；按 `event_time`、`event_id`、`source` 排序。没有该单据事件时返回空列表。尚未导入的节点不能出现在结果中；不能由“补交”事件生成“复核通过”或“付款完成”。

命令用于查询，不执行审批、补件、支付或业务写回。

## 查看周期指标

```bash
python -m my_tool.main metrics DEMO-001 --db .local/events.db
```

位置参数为单据编号。输出 JSON 包含：

| 字段 | 含义 |
|---|---|
| `review_hours` | 首次 `submitted` 至首次明确 `review_approved` 的自然时间小时数 |
| `payment_hours` | 首次 `submitted` 至首次明确 `paid` 的自然时间小时数 |
| `issues` | 缺失节点或事件顺序矛盾的代码列表 |

缺少必要节点或出现时间矛盾时，对应指标为 `null`。付款周期还要求有效复核节点，不能仅有付款事件就推断审批成立。已有中间审批节点会用于检查顺序，缺失的中间节点不会补造。

该命令不拆分同一单据的重复报销周期，不计算节点排队时间或人员操作工时，也不转换为工作日。合成样例输出48小时审核与72小时付款，只是构造时间戳的差值。

案例中的3天目标还需约定自然日或工作日及达标比例。CLI 结果不能直接证明该目标已在真实业务达成。

## 错误与复现

输入不是合法 JSON/CSV、缺少必要字段、金额或时间格式不合法以及事件标识冲突时，应先修复输入，再重试。复现材料应包括完整命令、Python 版本、最小合成输入和实际输出；不附真实票据或个人敏感数据。

成功生成业务结果时退出码为 `0`；输入无法读取、JSON 无法解析、无效 CSV、事件键冲突或数据库错误等返回 `2`，错误 JSON 写入标准错误流。参数错误由命令行解析器显示用法并返回 `2`；`--help` 返回 `0`。字段语义不满足检查规则可能作为 `NEEDS_MANUAL_REVIEW` 返回 `0`，不能将它与语法解析失败混同。

`timeline`、`metrics` 要求数据库文件已经存在，否则返回错误。自动化集成应锁定版本，读取 JSON 字段与代码，不解析未经约定的自然语言提示文案。

## 无需安装的演示入口

```bash
python examples/demo.py
```

此入口用于快速验证本地环境和合成业务流程；它不是部署脚本。演示数据库位于临时目录，演示结束后清理，不会操作真实 ERP/OA 或支付账户。
