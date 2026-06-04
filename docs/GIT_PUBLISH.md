# Git 发布说明

> 本项目本地工作目录和 GitHub 展示目录刻意不同。更新仓库前必须先读本文件，避免把本地目录结构改乱。

## 当前规则

- 本地工作目录保持：`E:\Visual_Studio_Code\11_Rustdesk\rustdesk_harmonyos`
- 本地 Git 根目录保持：`E:\Visual_Studio_Code\11_Rustdesk`
- GitHub 仓库展示为项目根结构，顶层直接显示 `AppScope/`、`docs/`、`entry/`、`scripts/` 等目录。
- 不要为了修复 GitHub 展示，把本地 `rustdesk_harmonyos/` 内容移动到 `E:\Visual_Studio_Code\11_Rustdesk` 根目录。

## 重要禁止项

- 不要在本地工作仓库直接执行普通 `git pull` 合并远端 `master`。
- 不要在本地工作仓库直接把 `rustdesk_harmonyos/` 提升到仓库根目录。
- 不要把 `.hvigor/`、`.idea/`、`oh_modules/`、`entry/build/`、`entry/.cxx/`、`native_rust_core/target/`、`*.hap`、`*.a`、`*.so` 等生成物发布到远端。
- 不要在 `99_Temp` 下创建新的散落备份目录；项目备份固定使用 `99_Temp/rustdesk_harmonyos_backups/`。

## 为什么本地会显示 behind

远端 `master` 使用“发布用根目录结构”，本地工作仓库保留“外层仓库 + `rustdesk_harmonyos/` 子目录结构”。因此本地执行 `git fetch origin` 后，可能看到：

```text
## master...origin/master [behind 1]
```

这是正常状态。不要用普通 `git pull` 去消除这个提示，否则会把远端根目录结构合并到本地工作目录。

## 正确发布流程

以下流程只在 `99_Temp` 下创建临时发布目录，不改变本地项目结构。

```powershell
cd E:\Visual_Studio_Code\11_Rustdesk

$root = Resolve-Path .
$project = Join-Path $root 'rustdesk_harmonyos'
$tempParent = [System.IO.Path]::GetFullPath((Join-Path $root '..\99_Temp'))
$publish = Join-Path $tempParent 'rustdesk_harmonyos_publish_root'

if (-not (Test-Path -LiteralPath $project)) {
  throw "Project folder not found: $project"
}

if (Test-Path -LiteralPath $publish) {
  Remove-Item -LiteralPath $publish -Recurse -Force
}

git clone --no-checkout https://github.com/liyan-lucky/rustdesk_harmonyos.git $publish
Set-Location $publish
git checkout master
git rm -r --ignore-unmatch .

$excludeDirs = @(
  '.hvigor',
  '.idea',
  '.appanalyzer',
  '.local_sdk',
  '.hvigor_home',
  'node_modules',
  'oh_modules',
  'entry\build',
  'entry\.cxx',
  'native_rust_core\target'
)

$excludeFiles = @(
  '*.log',
  '*.tmp',
  '*.bak',
  '*.hap',
  '*.a',
  '*.so',
  '*.dll',
  '*.exe',
  '*.o',
  '*.obj'
)

$robocopyArgs = @($project, $publish, '/E', '/XD') + $excludeDirs + @('/XF') + $excludeFiles
& robocopy @robocopyArgs
if ($LASTEXITCODE -gt 7) {
  throw "robocopy failed with exit code $LASTEXITCODE"
}

$ohpmLock = Join-Path $project 'oh_modules\.ohpm\lock.json5'
if (Test-Path -LiteralPath $ohpmLock) {
  New-Item -ItemType Directory -Force -Path (Join-Path $publish 'oh_modules\.ohpm') | Out-Null
  Copy-Item -LiteralPath $ohpmLock -Destination (Join-Path $publish 'oh_modules\.ohpm\lock.json5')
}

git add -A
git diff --cached --name-only | rg '(^|/)(\.cxx|\.hvigor|\.idea|\.appanalyzer|native_rust_core/target|entry/build|node_modules)(/|$)|\.hap$|\.a$|\.so$'
if ($LASTEXITCODE -eq 0) {
  throw 'Publish snapshot contains generated artifacts'
}

git status --short
git commit -m "Publish HarmonyOS project at repository root"
git push origin master
```

## 发布后检查

```powershell
cd E:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_publish_root
git ls-tree --name-only HEAD
```

顶层应直接出现：

```text
.clang-tidy
.clangd
.gitignore
AppScope
CHANGELOG.md
build-profile.json5
docs
entry
hvigor
hvigorfile.ts
native_rust_core
oh-package.json5
oh_modules
package-lock.json
scripts
signing
```

本地工作目录仍应保持：

```powershell
Get-ChildItem -Force E:\Visual_Studio_Code\11_Rustdesk
```

顶层只应包含 `.git`、`.codeartsdoer`、`rustdesk_harmonyos/` 以及少量手工产物。

## 根目录版脚本路径

临时发布目录中的脚本运行环境是“仓库根就是项目根”，因此发布快照里的脚本默认应从项目根的上一级寻找 `99_Temp`：

- 根目录发布版：`$PROJECT_ROOT\..\99_Temp`
- 本地工作版：`$PROJECT_ROOT\..\..\99_Temp`

如果只是在本地 `rustdesk_harmonyos/` 中开发，不要把脚本改成根目录发布版路径。
