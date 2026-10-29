# 差旅报销辅助工具

一个使用 Python 标准库实现的离线命令行 MVP，用于演示科研机构差旅报销的提交前检查、制度版本核对和流程事件追溯。项目以澄岳研究院的合成需求场景为背景；示例单据、制度和事件用于教学与测试，不代表真实单位制度或实际业务结果。

本目录可作为 `JZ-HX1/personal-web` 仓库中的独立子项目。下列命令均在 `travel-reimbursement-assistant` 目录内执行。

## 能做什么

- 检查单据必填信息和发票、出差申请等附件声明。
- 核对金额及项目分摊合计，提示跨项目分摊需要人工确认。
- 核对已批准制度版本；冲突、缺依据或不能确定适用版本时转人工处理。
- 把 CSV 流程事件导入 SQLite 台账，按来源与事件标识去重，并拒绝同一键下的冲突内容。
- 按带时区的事件时间查看单据时间线和周期指标，区分财务复核与付款。

检查结果是辅助意见。通过字段检查不等于发票验真、审核通过或允许付款；系统也不会把“已补交”推断为“已复核”。

## 环境与快速运行

要求 Python 3.10 或以上版本。运行时没有第三方 Python 依赖，无需数据库服务器或模型 API。

```bash
python --version
python examples/demo.py
```

演示脚本可以直接运行，不要求先安装包。它使用项目中的合成数据展示主要功能。需要使用 `python -m my_tool.main` 命令时，先安装本地包：

```bash
python -m pip install -e .
```

然后执行：

```bash
python -m my_tool.main check data/claim.json --policies config/policies.json
python -m my_tool.main import-events data/events.csv --db .local/events.db
python -m my_tool.main timeline DEMO-001 --db .local/events.db
python -m my_tool.main metrics DEMO-001 --db .local/events.db
```

`check` 使用 JSON 文件作为单据和制度输入。`import-events` 会创建或更新指定的本地数据库；`timeline` 和 `metrics` 查询该台账。完整命令说明见 [CLI 接口文档](docs/api.md)。

`check` 输出 `READY_FOR_REVIEW` 表示可交人工审核，`NEEDS_MANUAL_REVIEW` 表示存在待处理问题；二者的进程退出码均为 `0`，必须读取 JSON 中的 `status` 和 `issues`。输入无法读取、JSON 无法解析或事件导入无效等命令错误返回 `2`。

## 验证

在项目目录运行：

```bash
python -m unittest discover -s tests -v
```

本次交付验证通过29项本地测试，覆盖正常单据、缺件、分摊不平、制度冲突、重复导入、事件键冲突、时间线缺口及非 UTF-8 环境下的中文输出。修改后应重新执行，以当次输出为准。示例中的48小时审核周期、72小时付款周期来自人为构造的事件，不是实际业务改善结果。

## 打包与持续集成

生成允许清单内的源码和文档 ZIP：

```bash
python scripts/build.py
```

打包结果位于 `dist/travel-reimbursement-assistant-0.1.0.zip`。脚本排除本地数据库、缓存、虚拟环境和私有目录等内容。此项目没有远程服务部署脚本。

集成到 `personal-web` 后，由父仓库根目录的 `.github/workflows/travel-assistant-ci.yml` 执行验证；子项目内的 `.github/workflows/ci.yml` 仅作为独立仓库使用时的模板，不会被父仓库自动执行。

## 项目结构

```text
travel-reimbursement-assistant/
├─ README.md
├─ CHANGELOG.md
├─ CONTRIBUTING.md
├─ config/                 # 合成制度配置
├─ data/                   # 合成单据和事件
├─ docs/                   # 行业报告、设计与接口说明
├─ examples/               # 可直接运行的演示
├─ scripts/                # 辅助脚本
├─ src/my_tool/            # Python 包与命令行入口
├─ tests/                  # unittest 测试
└─ .github/                # 问题与 PR 文本模板
```

## 文档与选型依据

- [行业分析报告](docs/industry-report.docx)：行业背景、开源候选方案和完整方案设想；不代表所有设想都已由离线原型实现。
- [设计方案与流程图](docs/design.md)：需求映射、现状与改进流程、MVP边界。
- [CLI 接口说明](docs/api.md)：命令、输入输出和持久化行为。
- [参考资料](docs/references.md)：Frappe、Odoo、OCA 与官方行业资料。
- [贡献指南](CONTRIBUTING.md)和[变更记录](CHANGELOG.md)。

GitHub 上已有费用报销与审批方案，因此本项目引用其产品思路，针对合成场景实现一个小型离线辅助工具。此版本没有复制 Frappe HRMS、Odoo 或 OCA 的业务源码，也没有把这些产品安装或集成为依赖。本项目新增代码与原创说明采用 [MIT 许可证](LICENSE)；报告中保留的学校模板和外部引用不因此改变原有权利，范围见 [NOTICE](NOTICE.md)。

## 当前边界

本工具没有 HTTP 服务、登录认证、租户隔离、真实 ERP/OA 连接、发票查验接口、OCR、生成式 AI 或支付能力。人工审核、项目确认、财务复核与付款均通过合成事件演示，不执行真实业务操作。附件声明检查不读取和鉴定真实票据文件。

SQLite 台账用于单机原型，尚不提供防篡改审计存储、生产备份恢复或高并发服务保障。未记录的节点显示为未知或缺失，不能据此补造审核或付款事件。

周期计算采用首次明确提交、复核通过和付款事件之间的自然时间小时数，不计算工作日、实际操作工时或各节点排队时间，也不拆分同一业务编号的多次报销周期。

案例中的“9天降至3天”“补件率低于15%”是待验证目标；真实试点应先约定观察范围、自然日或工作日口径以及分母。案例的90天暂留设定仅用于合成试点评价记录，不能用作真实会计档案保存期限。

制度配置采用 JSON，便于标准库直接解析；这是为保持本 MVP 无第三方运行依赖所作的实现选择。后续若改用 YAML，需要单独引入解析器并更新安装与测试说明。

作为个人网站仓库的子目录，`.github` 下的模板可供复制参考；GitHub 自动识别的仓库级模板需位于整个仓库根目录的 `.github/` 下。本子项目不会自行覆盖父仓库配置。
