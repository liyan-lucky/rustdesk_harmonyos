# Git 发布说明

> 当前本地项目目录和 GitHub 展示目录已经统一为项目根结构。更新仓库前先读本文，避免重新引入旧的 `rustdesk_harmonyos/` 套娃目录。

> 2026-06-24 v0.33.14 审计修复：commit `c0131e9`（fix: 13 critical/high audit findings），版本 `0.33.14` / versionCode `1000190`，BuildInfo `2026-06-24 18:36`，仓库 HEAD `ac5555a`。CoreBuildInfo arm64 `132,777,178` bytes / SHA256 `EE881BEB9DE44835EE126BACC86D3B373E779334FB58A5D63F4B4D7974077314`，x86_64 `130,416,964` bytes / SHA256 `8ACD4AD130EAE9A36D4AE04A93860193CE8773E91E5CCEA5E34E815BFE633ED4`。设备验证 PID `19288`，`coreReady=true`，5轮审计 154 PASS / 0 FAIL / 1 SKIP。备份 `rustdesk_harmonyos_20260624_224200.zip`，1,453,149 bytes，SHA256 `0FB0630EF13A3AEEBE245F90E640CCA66074127F918CF8936CD393A7BE2A4E29`。

> 2026-06-21 23:48 发布候选基线：本地签名 HAP SHA256 `1D5C7395753D4E8F143FA051E0E931CCFB6C48FFEDA03A8DF91282DD007EC8D2`，arm64/x86_64 均为当日本地同源码构建并写入 CoreBuildInfo，最终 100 轮全审计 15400 PASS / 0 FAIL / 100 预期 SKIP，连接链 84/84。推送后必须等待线上 Core/HAP workflow，下载线上 asset 到 `99_Temp\release_inspect\11_Rustdesk_harmonyos`，复核签名、双 ABI、BuildInfo、双架构 CoreBuildInfo 和 SHA256，再把 run、commit、asset、hash 写回文档。版本号相同不代表包相同。

> 2026-06-22 00:25 已发布：Core `a7f7795` / run `27920089950` / `core-34`；App `3ebdc726` / run `27920708116` / `OpenRustdesk-Build-v0.33.6`。最终线上 HAP SHA256 `3D2711AF46FFF6C999362431FFDC7855A485BBBC5BBC1ACE629FA885F8A4E35C`，tag 已重指实际构建提交。若已有同名 Release，重新上传资产不会自动移动 tag，必须显式核对并修正 tag 指针。

> 2026-06-22 00:30 双设备验收完成：线上包在 arm64 真机和 x86_64 虚拟机均安装/冷启动通过；虚拟机 `updateTime=1782084584518`，NAPI 413 functions，`coreReady=true`。

## 当前规则

`%VSCODE_ROOT%` 表示当前机器上的工作区根目录，必须同时包含 `11_Rustdesk_harmonyos/` 和 `99_Temp/`。它会随 U 盘在借用电脑上的盘符变化，不要把盘符写死进新文档或脚本。

- 本地工作目录：`%VSCODE_ROOT%\11_Rustdesk_harmonyos`
- 本地 Git 根目录：`%VSCODE_ROOT%\11_Rustdesk_harmonyos`
- GitHub 仓库顶层直接显示 `AppScope/`、`docs/`、`entry/`、`scripts/` 等目录。
- 线上仓库默认介绍使用根目录 `README.md`，标题为 `项目设计要求`，内容为完整设计要求。
- `99_Temp/` 与项目目录保持同级；构建、签名、缓存和备份默认从项目根的上一层查找 `99_Temp`。

## 禁止项

- 不要再创建或提交顶层 `rustdesk_harmonyos/` 子目录。
- 不要提交 `.hvigor/`、`.idea/`、`oh_modules/`、`entry/build/`、`entry/.cxx/`、`native_rust_core/target/`、`*.hap`、`*.a`、`*.so` 等生成物。
- 不要在 `99_Temp` 下创建新的散落备份目录；项目备份固定使用 `99_Temp/rustdesk_harmonyos_backups/`。
- U 盘文件系统触发 Git dubious ownership 时，使用单次 `git -c safe.directory=<项目根> ...` 或配置当前项目 safe.directory，不要改动目录结构来消除提示。

## 发布流程

```powershell
$env:VSCODE_ROOT = (Resolve-Path ..).Path
Set-Location "$env:VSCODE_ROOT\11_Rustdesk_harmonyos"

$repo = (Resolve-Path .).Path
git -c safe.directory=$repo status --short
git -c safe.directory=$repo rm -r --cached --ignore-unmatch rustdesk_harmonyos
git -c safe.directory=$repo add -A -- . ':!entry-default-signed.hap' ':!check_i18n.py' ':!check_result.txt' ':!rustdesk_harmonyos'
git -c safe.directory=$repo diff --cached --name-only | rg '(^|/)(\.cxx|\.hvigor|\.idea|\.appanalyzer|native_rust_core/target|entry/build|node_modules|oh_modules)(/|$)|\.hap$|\.a$|\.so$'
if ($LASTEXITCODE -eq 0) {
  throw 'Staged snapshot contains generated artifacts'
}

git -c safe.directory=$repo commit -m "Update HarmonyOS project"
git -c safe.directory=$repo push origin master
```

## 发布后检查

```powershell
$repo = (Resolve-Path .).Path
git -c safe.directory=$repo ls-tree --name-only HEAD
```

顶层应直接出现：

```text
.clang-tidy
.clangd
.gitignore
AppScope
CHANGELOG.md
README.md
build-profile.json5
docs
entry
hvigor
hvigorfile.ts
native_rust_core
oh-package.json5
package-lock.json
scripts
signing
```

本地如果残留无法删除的 `rustdesk_harmonyos/` 空缓存壳，通常是旧 DevEco/clangd 生成目录权限问题；它已被 `.gitignore` 忽略，关闭 VS Code/DevEco 后可再清理，不能提交到远端。
