# Android 发布签名与本地 APK 构建

本项目已配置为从本地密钥库 `html5syt.jks` 构建签名 Android release。不要把密钥库或任何包含密码的文件提交到仓库。

## 本地构建 APK

1. 确认 `html5syt.jks` 位于仓库根目录：

   ```powershell
   Test-Path .\html5syt.jks
   ```

2. 查看密钥别名。执行命令后，只在 `keytool` 提示时输入密钥库密码：

   ```powershell
   keytool -list -v -keystore .\html5syt.jks
   ```

   输出中的 `Alias name` 就是后续要填写的 `keyAlias`。

3. 复制示例文件并在本机填写密码：

   ```powershell
   Copy-Item .\android\key.properties.example .\android\key.properties
   notepad .\android\key.properties
   ```

   文件内容格式如下：

   ```properties
   storeFile=../html5syt.jks
   storePassword=YOUR_KEYSTORE_PASSWORD
   keyAlias=YOUR_ALIAS_FROM_KEYTOOL
   keyPassword=YOUR_KEY_PASSWORD
   ```

   `storePassword` 是密钥库密码。`keyPassword` 是具体 key 的密码；如果创建密钥时让它和密钥库密码相同，就填同一个值。

4. 构建：

   ```powershell
   flutter pub get
   flutter build apk --release
   ```

   APK 输出位置：

   ```text
   build/app/outputs/flutter-apk/app-release.apk
   ```

   如果要构建应用商店常用的 AAB：

   ```powershell
   flutter build appbundle --release
   ```

## Gradle 下载超时

首次 Android 构建会下载 Gradle wrapper：

```text
https://services.gradle.org/distributions/gradle-9.1.0-bin.zip
```

如果本机网络访问该地址超时，可以使用以下任一方式：

- 在运行 `flutter build` 前为当前 shell 配置正常 HTTPS 代理。
- 用浏览器或可信镜像下载同名 zip，然后放入 Gradle wrapper 缓存目录 `%USERPROFILE%\.gradle\wrapper\dists`。
- 仅作为本地临时方案，把 `android/gradle/wrapper/gradle-wrapper.properties` 中的 `distributionUrl` 改为可信镜像里的同版本 `gradle-9.1.0-bin.zip`，构建完成后再改回官方地址，避免把临时镜像源提交到仓库。

## GitHub Actions Secrets

发布 workflow 会在 GitHub Actions 中通过 Secrets 还原 Android 签名材料。进入：

`GitHub 仓库 -> Settings -> Secrets and variables -> Actions -> New repository secret`

新增以下 4 个仓库级 secret：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

在本机生成 `ANDROID_KEYSTORE_BASE64`：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes(".\html5syt.jks")) |
  Set-Content -NoNewline .\html5syt.jks.base64
```

打开 `html5syt.jks.base64`，复制整行内容，填入 GitHub 的 `ANDROID_KEYSTORE_BASE64`。添加完成后删除临时文件：

```powershell
Remove-Item .\html5syt.jks.base64
```

安全规则：

- 不要提交 `html5syt.jks`。
- 不要提交 `android/key.properties`。
- 不要把密码写进命令行历史；优先使用本机已忽略的 `android/key.properties` 或 GitHub Secrets。
- 如果重置或替换密钥库，要确认你能处理后续应用升级签名问题。

## 发布 Workflow

`.github/workflows/release.yml` 支持两种触发方式：

- 推送 `v*` tag，例如 `v1.0.0`。
- 在 GitHub Actions 页面手动运行 `workflow_dispatch`。

推送 tag 示例：

```powershell
git tag v1.0.0
git push origin v1.0.0
```

workflow 会构建并上传：

- Android APK 和 AAB
- Web tarball
- Linux x64 tarball
- Windows x64 zip
- macOS app zip
- 未签名 iOS app zip

Web 构建使用 fallback 实现：浏览器环境无法使用内置本地后端、拖拽本地文件导入、系统字体扫描和 sherpa-onnx ASR。完整本地后端流程请使用桌面端或移动端构建。

iOS 产物是未签名包，因为 App Store/TestFlight 需要 Apple Developer 证书和 provisioning profile。macOS 和 Windows 产物也只是构建包，当前 workflow 不做公证或代码签名。
