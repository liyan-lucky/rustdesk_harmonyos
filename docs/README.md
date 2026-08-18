# RustDesk HarmonyOS 文档索引

## 新接手必读顺序

1. `CURRENT_STATUS.md`：当前仓库事实、功能边界、分支/备份策略、构建状态和合规边界。
2. `AGENT_HANDOFF.md`：新对话交接入口，当前项目状态、工作规则、用户偏好和构建命令。
3. `AGENT_MEMORY.md`：技术经验参考（ArkTS/原生/构建/连接/UI 经验库）。
4. `DIRECTORY_CONVENTIONS.md`：项目目录、路径、构建环境和清理规范。
4. `CORE.md`：核心状态、HAP 构建安装、运行验证清单。
5. `PROGRESS.md`：已完成、未完成和端到端验证状态。
6. `ISSUES.md`：已知问题、根因和处理记录。
7. `UI.md`：UI 结构、主题、图标和交互要求。
8. `FILES.md`：文件职责和目录结构。
9. `HARMONYOS_TOOLCHAIN.md`：SDK/toolchain 使用规则。
10. `RELEASE_ARTIFACT_POLICY.md`：Release 产物规则。
11. `SUPPLY_CHAIN.md`、`SBOM_POLICY.md`、`ASSET_PROVENANCE.md`：供应链、SBOM 和资产来源登记。

## 当前主事实

- 当前主工作分支：`master`。
- 当前备份分支：`backup`，由 `.github/workflows/force-backup-master.yml` 手动输入 `YES` 后强制覆盖。
- 当前维护版本：`0.34.34 (1000279)`，BuildInfo `2026-08-18 22:29`；所有后续修改直接提交到 `master`，不长期保留其他分支。
- `docs/CURRENT_STATUS.md` 是当前状态第一入口；旧的历史构建、历史 SHA、历史 run 和历史验证记录只作为追溯资料，不应替代当前状态判断。
- 判断 App / Core 新旧必须看 hash、mtime、BuildInfo、双架构 CoreBuildInfo、updateTime 和 hilog，不能只看版本号或 Release 名称。

## 文档维护要求

- 当前功能、构建、Release、路径、分支或验收状态变化时，必须同步更新 `CURRENT_STATUS.md`、根 README 和相关专项文档。
- 涉及 native core 时，必须同步核对 `liyan-lucky/librustdesk_core` 的当前 Release 和对应文档。
- 不要把 HarmonyOS SDK、DevEco、hvigor、ohpm、签名材料、私钥、token、用户数据或构建缓存写入公开仓库或 Release。
- 历史记录可以保留在专项历史文档中，但 README 和本文档只展示当前接手入口和当前事实。
