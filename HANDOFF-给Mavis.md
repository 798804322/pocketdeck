# 交接单：把 PocketDeck 装到 iPhone 上

> 给帮忙的人（Mavis）：
> 这是一份 iOS App 的源码，需要你在 GitHub 上点几下，让 GitHub 的 macOS 机器把它编译成安装包。
> **全程不需要 Mac，不需要装 Xcode，不需要写代码。** 大约 20 分钟。
> 目标产物：一个 `PocketDeck-unsigned.ipa`，装到那台 iPhone 上，接显示器就是一个桌面系统。

---

## 第 0 步：先确认两件事

- [ ] 有一个 GitHub 账号（没有就现场注册，免费）
- [ ] 手上有这台压缩包 `pocketdeck-ios.zip`，解压后第一层必须是这些：

```
project.yml          ← 必须在这一层
PocketDeck/          ← 源码文件夹
.github/             ← 隐藏文件夹，里面有编译脚本
README.md
tools/
```

**重点：`project.yml` 必须在仓库根目录。** 如果多套了一层文件夹，编译会失败。

---

## 第 1 步：把代码放进 GitHub

三种方式，选最顺手的。**推荐 A。**

### A. GitHub Desktop（最稳，鼠标操作）

1. 下载安装 [GitHub Desktop](https://desktop.github.com/)，登录你的账号
2. 菜单 **File → Add Local Repository**，选解压出来的 `pocketdeck-ios` 文件夹
   - 如果提示 "not a git repository"，点它给的 **create a repository** 链接
3. 左下角填个名字（比如 `pocketdeck`），点 **Create Repository**
4. 顶部会变成 **Publish repository**，点它 → 取消勾选 "Keep this code private"（公开仓库的编译时间免费不限）→ **Publish repository**
5. 等 10 秒，浏览器打开 `https://github.com/你的用户名/pocketdeck`

### B. 网页上传（不用装任何软件）

1. GitHub 右上角 **+ → New repository**，名字填 `pocketdeck`，**Public**，点 **Create repository**
2. 页面点 **uploading an existing file**
3. 打开解压出来的文件夹，**全选里面的内容**（`project.yml`、`PocketDeck`、`README.md`、`tools`）拖进浏览器
   - ⚠️ `.github` 是隐藏文件夹，拖拽常常会漏掉。**漏了也没关系，第 1.5 步补。**
4. 底部点 **Commit changes**
5. **第 1.5 步（必做）**：仓库页面点 **Add file → Create new file**，文件名位置输入：

```
.github/workflows/build.yml
```

   把本文件末尾「附录：build.yml 全文」整段粘进去，**Commit changes**

### C. 会用终端的话（最快）

```bash
cd pocketdeck-ios
git init -b main
git add -A          # -A 会把 .github 也带上
git commit -m "init"
git remote add origin https://github.com/你的用户名/pocketdeck.git
git push -u origin main
```

---

## 第 2 步：跑编译，下载 .ipa

1. 打开仓库页面顶部的 **Actions** 标签
   - 如果看到一条提示 "Workflows aren't being run on this repository"，点 **I understand my workflows, go ahead and enable them**
2. 左边选 **Build IPA** → 右边 **Run workflow** → 绿色按钮 **Run workflow**
3. 等 **3~5 分钟**。列表里会出现一次运行，点进去，看它的每一步变绿
4. 全部变绿后，页面**最下面**有 **Artifacts** 区域 → 点 **PocketDeck-ipa** 下载
5. 下载下来是个 zip，解压得到 `PocketDeck-unsigned.ipa`

**成功长什么样**：最后一步叫 "Upload IPA" 打绿勾，Artifacts 里能看到 `PocketDeck-ipa`。

**如果红了**：点开红色的那一步，把从 `** BUILD FAILED **` 往前 100 行的日志复制出来发给我（截图也行，文字更好）。

---

## 第 3 步：装到 iPhone（Windows 上做）

1. 装 [Sideloadly](https://sideloadly.io/)（Windows 版）。它会提示装 Apple 驱动，**同意**（如果没弹，先装一遍 iTunes）
2. iPhone 用数据线插电脑，手机上点「信任此电脑」并输密码
3. 打开 Sideloadly：
   - **Apple ID** 填那台 iPhone 登录的 Apple ID
   - **IPA** 拖入 `PocketDeck-unsigned.ipa`
   - 中间的设备选到那台 iPhone
   - 点 **Start**
4. 会要 Apple ID 密码（只在本机做签名，不联网上传），输入
5. 手机上：**设置 → 通用 → VPN 与设备管理 → 开发者 App → 信任**
6. 主屏出现「口袋电脑」图标，点开

**注意**：免费 Apple ID 签的 App **7 天会过期**（打不开就重做第 3 步的第 3~6 小步，1 分钟）。自己最多同时装 3 个自签 App。

---

## 装好之后怎么用

1. 手机用 **USB-C 转 HDMI** 线接显示器/电视（iPhone 15 及以后；更早的机型要苹果「闪电数字影音转换器」）
2. 大屏出现桌面：菜单栏、窗口、程序坞
3. 手机屏幕变成黑色触控板：滑动移光标，轻点单击
4. 底部四个按钮：**键盘**（打字进大屏笔记）、**应用**（开笔记/浏览器/时钟）、**拖动**（拖窗口）、**收窗**

---

## 常见卡点

| 现象 | 原因 / 怎么办 |
| --- | --- |
| Actions 里没有 Build IPA | `.github/workflows/build.yml` 没传上去，按第 1.5 步手建一次 |
| `project.yml` not found | 仓库里多套了一层文件夹，把内容挪到根目录 |
| 编译红在 `xcodegen` | 换一条 workflow 重跑即可，或把日志发我 |
| Sideloadly 报 `Unable to connect` | 没装 Apple 驱动，装 iTunes 或 Sideloadly 的驱动包 |
| 装上了但打不开 | 没信任证书，设置 → 通用 → VPN 与设备管理 |
| 接上显示器没反应 | 手机是 Lightning 口但用了普通 HDMI 线；需要「闪电数字影音转换器」 |

---

## 附录：build.yml 全文

```yaml
name: Build IPA

on:
  push:
    branches: [main, master]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  build:
    runs-on: macos-14
    timeout-minutes: 25

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Show Xcode version
        run: xcodebuild -version

      - name: Install XcodeGen
        run: brew install xcodegen

      - name: Generate Xcode project
        run: xcodegen generate

      - name: Build (unsigned)
        run: |
          set -o pipefail
          xcodebuild \
            -project PocketDeck.xcodeproj \
            -target PocketDeck \
            -configuration Release \
            -sdk iphoneos \
            -derivedDataPath build \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGN_IDENTITY="" \
            build 2>&1 | tail -n 120

      - name: Package unsigned IPA
        run: |
          set -e
          APP_PATH=$(find build -name "PocketDeck.app" -type d | head -n 1)
          echo "Found app: $APP_PATH"
          test -n "$APP_PATH"
          rm -rf Payload PocketDeck-unsigned.ipa
          mkdir -p Payload
          cp -R "$APP_PATH" Payload/
          zip -qry PocketDeck-unsigned.ipa Payload
          ls -lh PocketDeck-unsigned.ipa

      - name: Upload IPA
        uses: actions/upload-artifact@v4
        with:
          name: PocketDeck-ipa
          path: PocketDeck-unsigned.ipa
          if-no-files-found: error
          retention-days: 30
```

---

## 做完请把这三样发回来

1. 仓库地址（或 Actions 那次运行的链接）
2. 如果编译失败：红色日志
3. iPhone 型号 + iOS 版本（决定要不要换线）
