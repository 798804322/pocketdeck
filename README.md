# PocketDeck iOS — 原生外接屏桌面

一个真·iOS App：把 iPhone 接到显示器/电视上，大屏出现一套桌面（菜单栏、窗口、程序坞、光标），手机变成触控板和键盘。

和网页版的区别，就一句话：**它用 iOS 的 `UIScene` 外接显示器能力，在显示器上独立渲染界面，不是镜像投屏、没有黑边。**

---

## 先看这面墙

iOS 的 App **必须在 macOS 上用 Xcode 编译**。这台电脑是 Windows，所以代码我写完了，但最后“变成能装到手机上的 App”这一步，需要下面两条路之一。

---

## 路线 A：手边有 Mac（10 分钟）

1. Mac 上装 [Xcode 15+](https://apps.apple.com/app/xcode/id497799835)（App Store 免费）
2. 打开「终端」，装工程生成工具：
   ```bash
   brew install xcodegen
   ```
3. 进入这个文件夹，生成工程：
   ```bash
   cd pocketdeck-ios
   xcodegen generate
   ```
4. 双击 `PocketDeck.xcodeproj`，Xcode 里选中你的 iPhone（手机用数据线连 Mac，第一次要在手机上「信任」）
5. 点左上角 ▶️ 运行。首次会要求在 Xcode 里登录你的 Apple ID（免费账号即可），并在手机上
   「设置 → 通用 → VPN 与设备管理」里信任你的开发者证书。

跑起来之后，把手机插上显示器，桌面就会出现在大屏上。

## 路线 B：没有 Mac，用 GitHub 免费编译（20 分钟，一次配置长期用）

GitHub 的 macOS 机器免费借用，仓库公开或私有都行。

1. 注册/登录 [github.com](https://github.com)
2. 右上角 **+ → New repository**，名字随便（比如 `pocketdeck`），Private 也可以，点 **Create**
3. 在仓库页面点 **uploading an existing file**，把 `pocketdeck-ios` 文件夹里的
   **全部内容**（`PocketDeck/`、`project.yml`、`.github/`）拖进去，**Commit changes**
   - 注意 `.github` 是隐藏文件夹，用 GitHub Desktop 或网页上传整个文件夹更省事
4. 仓库顶部点 **Actions** → 左边选 **Build IPA** → 右边 **Run workflow**
5. 等 3~5 分钟，构建完成后点进这次运行，页面底部 **Artifacts → PocketDeck-ipa** 下载（是个 zip，解压出 `PocketDeck-unsigned.ipa`）
6. Windows 上装 [Sideloadly](https://sideloadly.io/)，iPhone 用数据线连电脑
7. 把 `.ipa` 拖进 Sideloadly，填你的 Apple ID，点 **Start**（会要 Apple ID 密码，用于本地签名，不上传）
8. iPhone 上「设置 → 通用 → VPN 与设备管理」→ 信任你的 Apple ID
9. 回到主屏，图标叫「口袋电脑」，点开

> 免费 Apple ID 的限制：自签 App **7 天过期**，自己最多装 3 个。过期就重做第 6~8 步（1 分钟）。不想折腾就买个 $99/年的开发者账号，能签 1 年。

---

## 用法

1. **USB-C 转 HDMI** 线把 iPhone 连到显示器/电视（iPhone 15 及以后是 USB-C；更早的机型用苹果「闪电数字影音转换器」）
2. 显示器亮起后，手机屏幕上出现一块黑色触控板
3. 在触控板上滑动 → 大屏上的光标移动；轻点 → 单击
4. 底部四个按钮：
   - **键盘**：调出 iOS 键盘，打的字出现在大屏的「笔记」窗口里
   - **应用**：在大屏上打开 笔记 / 浏览器 / 时钟
   - **拖动**：打开后滑动就是拖窗口
   - **收窗**：关掉所有窗口
5. 也可以配蓝牙键盘和鼠标

---

## 代码结构

```
pocketdeck-ios/
├─ project.yml                    XcodeGen 工程描述（免手写 .xcodeproj）
├─ PocketDeck/
│  ├─ Info.plist                  关键：声明外接屏场景角色
│  ├─ AppDelegate.swift           按场景角色分发：手机 / 外接屏
│  ├─ Core/DeckModel.swift        唯一状态源（窗口、光标、焦点）
│  ├─ Desktop/
│  │  ├─ DesktopSceneDelegate.swift   显示器上的那个场景
│  │  ├─ DesktopViewController.swift  布局与刷新
│  │  ├─ DesktopChrome.swift          壁纸、菜单栏、程序坞、光标
│  │  └─ DeckWindowView.swift         窗口 + 三种内容
│  └─ Phone/
│     ├─ PhoneSceneDelegate.swift
│     ├─ PhoneViewController.swift    触控板 + 键盘 + 启动器
│     └─ TrackpadView.swift
└─ .github/workflows/build.yml    免费 macOS 编译 → 出 .ipa
```

关键实现点：

- `Info.plist` 里 `UIWindowSceneSessionRoleExternalDisplayNonInteractive` 声明了外接屏场景
- `AppDelegate.application(_:configurationForConnecting:options:)` 根据 `session.role` 决定用哪个 Delegate
- 外接屏场景里自己 `UIWindow(windowScene:)`，所以能画任意界面，且不受手机屏幕比例限制
- 手机和外接屏通过 `DeckModel` 单例 + `NotificationCenter` 通信，没有网络、没有延迟

---

## 现在这版的能力边界

- ✅ 大屏原生分辨率、窗口、程序坞、光标、真键盘输入
- ✅ 手机当触控板，不需要额外硬件
- ⛔ 窗口里只有我写的三个应用 + 网页，**不能把别的 iOS App 放进窗口**（iOS 不允许 A 窗口里跑 B 的界面，DeskState 也一样）
- ⛔ 外接屏上不能用鼠标指针（苹果在 iPhone 上不给；iPad 的台前调度才有）
- ⛔ 这版是原型：没有缩放窗口、没有多桌面、浏览器没有地址栏

## 编译报错怎么办

把 Actions 里红色的日志（从 `** BUILD FAILED **` 往前 100 行）贴给我，我直接改。第一次跑 CI 大概率会有几个 API 名字对不上，属于正常流程。
