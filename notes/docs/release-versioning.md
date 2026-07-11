# 版本注入

- Debug 构建使用当前 Git commit 的 8 位短哈希作为应用内版本。
- Release 构建使用发布元数据或 tag 中的 `vx.x.x`，平台构建版本使用去掉 `v` 的 `x.x.x`。
- GitHub Actions 已自动注入 `APP_VERSION`。
- 本地构建优先使用 VS Code Build Task，或手动执行：

```powershell
$version = (git rev-parse --short=8 HEAD).Trim()
flutter build windows --debug --dart-define=APP_VERSION=$version
```

Release 示例：

```powershell
powershell -ExecutionPolicy Bypass -File tool/flutter_build.ps1 `
  -Target windows -Mode release -Version v2.0.0
```
