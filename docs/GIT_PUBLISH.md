# Git 发布说明

> 当前本地项目目录和 GitHub 展示目录已经统一为项目根结构。更新仓库前先读本文，避免重新引入旧的 `rustdesk_harmonyos/` 套娃目录。

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
