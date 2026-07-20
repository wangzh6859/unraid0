# Unraid Mobile

一个从零开始、完全通过 **GitHub 云端 Actions** 打包的 Unraid NAS 手机管理 App。
本地不需要安装 Android Studio / Flutter SDK / Java，只需要一个 GitHub 账号。

功能：
- 📊 仪表盘：主机名、CPU / 内存占用环形图、磁盘阵列状态、每块磁盘温度
- 🐳 Docker 容器管理：查看所有容器状态，启动 / 停止 / 暂停 / 恢复
- 🔄 应用内更新提醒：自动检测 GitHub 上的新版本，一键跳转下载
- 📱 手机上可以**原地升级安装**，不需要先卸载旧版（见下方原理说明）

---

## 一、准备工作：开启 Unraid 的 GraphQL API

1. 打开 Unraid WebGUI，进入 **Settings → Management Access → Developer Options**，
   打开 **GraphQL Sandbox** 开关。
2. 进入 **Settings → Management Access → API Keys**，创建一个新的 API Key，
   角色选择 `Admin`（或者只勾选 Docker / Info / Array 相关权限），保存后复制这个 Key，
   稍后要填到手机 App 的登录页里。
3. 记下 NAS 在局域网里的 IP，比如 `192.168.1.10`。

> 如果你在 Settings 里没找到上面这两个入口，把 Settings 页面截图发我，我帮你定位（不同 Unraid 小版本菜单位置可能略有出入）。

---

## 二、把这个项目推送到你的 GitHub 仓库

在电脑上（不需要装 Flutter，只需要 git）：

```bash
cd unraid-mobile
git init
git add .
git commit -m "init: unraid mobile app"
git branch -M main
git remote add origin https://github.com/<你的用户名>/<你的仓库名>.git
git push -u origin main
```

> 如果你连本地 git 都不想用，也可以直接在 GitHub 网页里新建仓库，然后把这个文件夹里的所有文件手动上传（Add file → Upload files）。

---

## 三、生成签名证书（只需要做一次，非常重要）

这一步是实现"手机上直接升级安装、不用先卸载"的关键。原理很简单：
**Android 只有在新旧安装包使用同一份签名证书、且新包的版本号更高时，才允许"原地覆盖安装"。**
如果每次 CI 构建都用不同的临时证书，你每次都得先卸载旧版才能装新版，非常麻烦。

操作步骤：

1. 打开你仓库的 **Actions** 标签页
2. 左侧选择 **Generate Signing Keystore (只需运行一次)**
3. 点击右侧 **Run workflow** 按钮 → 再点一次绿色的 **Run workflow** 确认
4. 等待运行完成（大约 30 秒），点进这次运行记录，在最下方 **Artifacts** 里下载
   `unraid-mobile-keystore` 压缩包
5. 解压后你会看到三个文件：
   - `keystore-info.txt` —— 打开它，里面写清楚了接下来要填的 4 个密钥
   - `release_base64.txt` —— 待会要复制这里面的内容
   - `release.jks` —— 证书本体，**请额外备份一份到网盘或电脑里**，遗失后无法恢复
6. 回到仓库 **Settings → Secrets and variables → Actions → New repository secret**，
   依次添加 4 个 Secret（名字必须完全一致）：

   | Secret 名称 | 值 |
   |---|---|
   | `KEYSTORE_BASE64` | 打开 `release_base64.txt`，把整行内容粘贴进去 |
   | `KEYSTORE_PASSWORD` | 抄 `keystore-info.txt` 里的密码 |
   | `KEY_ALIAS` | `unraidmobile` |
   | `KEY_PASSWORD` | 抄 `keystore-info.txt` 里的密码（和 storePassword 相同）|

完成后这一步就再也不用做了，以后每次打包都会自动复用这份证书。

---

## 四、触发第一次云端打包

添加完 4 个 Secret 后：

- 直接对仓库随便 push 一次代码（哪怕只改一个字），或者
- 到 **Actions → Build & Release APK → Run workflow** 手动触发一次

打包大约需要 3-6 分钟。完成后，仓库主页右侧 **Releases** 里会自动出现一个新版本，
里面有一个 `.apk` 文件。

## 五、手机上安装

1. 手机浏览器打开你仓库的 Releases 页面（地址形如
   `https://github.com/<用户名>/<仓库名>/releases/latest`）
2. 点击 `.apk` 文件下载
3. 第一次安装：系统会提示"未知来源"，去 设置 → 允许该浏览器安装应用，然后正常安装即可
4. **以后每次更新**：重复上面第 1-2 步，下载新的 apk 点击安装，
   手机会直接提示"更新"而不是"卸载重装"——因为签名证书和版本号机制已经处理好了

打开 App 后填入 NAS 局域网地址和第一步生成的 API Key 即可开始使用。

---

## 六、（可选）打开应用内"发现新版本"提醒

`lib/services/update_service.dart` 里有一行：

```dart
static const String githubRepo = 'YOUR_GITHUB_USERNAME/unraid-mobile';
```

把它改成你自己的 `用户名/仓库名`，重新 push 触发一次打包后，
App 首页顶部会自动检测并提示"发现新版本 vX，点击下载安装"。

---

## 项目结构

```
unraid-mobile/
├── .github/workflows/
│   ├── generate-keystore.yml   # 一次性：生成签名证书
│   └── build-apk.yml           # 每次 push：云端编译 + 发布 Release
├── android_overrides/
│   └── app_build.gradle.kts    # CI 会用它覆盖 flutter create 生成的默认签名配置
├── lib/
│   ├── main.dart
│   ├── theme/app_theme.dart    # 深色 + 橙色品牌配色
│   ├── models/                 # SystemStats / DockerContainerInfo
│   ├── services/
│   │   ├── unraid_api.dart     # GraphQL 请求封装（已核对官方最新 Schema）
│   │   ├── storage_service.dart
│   │   └── update_service.dart
│   ├── screens/                # 登录页 / 主页 / 仪表盘 / Docker 页
│   └── widgets/                # 统计卡片 / 环形图 / 容器列表项
└── pubspec.yaml
```

`android/`、`ios/` 等平台目录**故意没有提交到仓库**——它们由 `build-apk.yml`
在云端构建时通过 `flutter create` 自动生成，这样你本地完全不需要装任何 Android 环境。

---

## 后续可以扩展的方向

- 虚拟机（VM）管理页面（接口已在 `unraid_api.dart` 里预留了相似的写法可以照抄 `VmMutations`）
- 阵列启动 / 停止操作（`ArrayMutations.setState`）
- 通知中心（未读告警数量角标）
- 深色/浅色主题切换、多语言

如果需要我继续加这些功能，直接告诉我就行。

---

## 常见问题

**Q: push 后 Actions 报错 "缺少 KEYSTORE_BASE64 secret"**
A: 说明第三步的 4 个 Secret 还没配置完整，去 Settings → Secrets 检查名称是否完全一致（区分大小写）。

**Q: App 提示"无法连接到 NAS"**
A: 确认手机和 NAS 在同一局域网下，且 Unraid 的 GraphQL Sandbox 已经打开；
如果 Unraid 开了 HTTPS，登录页记得打开"使用 HTTPS"开关。

**Q: 想改应用图标 / 名称**
A: 应用名称在 `android_overrides/app_build.gradle.kts` 里搜索不到（那是包名），
名称显示文本在 CI 生成的 `android/app/src/main/AndroidManifest.xml` 里的 `android:label`，
如果需要我可以帮你加一个自动替换步骤和自定义图标的完整方案。
