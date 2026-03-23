# Clipboard History App

这个目录是正式版工程。后面开发、编译 `.app`、生成 `.dmg`，都只看这里。

## 目录说明

当前结构是：

```text
copy/
  App/
    Package.swift
    Sources/
    README.md
    .build/        # Swift 编译自动生成的隐藏目录
  archive/
    node-cli/
    python-prototype/
```

说明：

- [Package.swift](/Users/q/Desktop/copy/App/Package.swift)：Swift 工程配置文件，不是第二个版本
- [Sources](/Users/q/Desktop/copy/App/Sources)：正式版 App 的全部主要源码
- `.build`：Swift 编译缓存和中间产物，自动生成，不是源码
- [archive/node-cli](/Users/q/Desktop/copy/archive/node-cli)：旧的 Node 命令行原型
- [archive/python-prototype](/Users/q/Desktop/copy/archive/python-prototype)：旧的 Python 图形原型

## 这版要实现的功能

- 菜单栏常驻
- 全局快捷键 `Command + Shift + V`
- 关闭窗口只隐藏，不退出
- 文本和图片剪切板历史
- 自动清理未固定项
- 显示条数、磁盘占用、内存占用、文本数、图片数、固定项数

## 自动清理策略

- 最多保留 `500` 条历史
- 总磁盘占用超过 `1GB` 时，自动删除最早未固定项
- 固定项不会被自动删除

## 主要源码

- [ClipboardHistoryStore.swift](/Users/q/Desktop/copy/App/Sources/ClipboardHistoryStore.swift)
- [ClipboardHistoryView.swift](/Users/q/Desktop/copy/App/Sources/ClipboardHistoryView.swift)
- [AppDelegate.swift](/Users/q/Desktop/copy/App/Sources/AppDelegate.swift)
- [GlobalHotKeyMonitor.swift](/Users/q/Desktop/copy/App/Sources/GlobalHotKeyMonitor.swift)
- [AppMain.swift](/Users/q/Desktop/copy/App/Sources/AppMain.swift)

## 从这里开始构建

先进入正式版目录：

```bash
cd /Users/q/Desktop/copy/App
```

### 1. 检查本机工具链

```bash
swift --version
xcodebuild -version
```

如果这里报错或者版本不匹配，要先修好 Xcode / Command Line Tools。

### 2. 编译 release

```bash
swift build -c release
```

成功后，二进制通常会在：

```bash
/Users/q/Desktop/copy/App/.build/release/ClipboardHistoryApp
```

### 3. 组装成 `.app`

先创建标准 macOS App 目录：

```bash
mkdir -p Release/ClipboardHistory.app/Contents/MacOS
mkdir -p Release/ClipboardHistory.app/Contents/Resources
```

复制可执行文件：

```bash
cp .build/release/ClipboardHistoryApp Release/ClipboardHistory.app/Contents/MacOS/
```

然后准备一个 `Info.plist` 到这里：

```bash
Release/ClipboardHistory.app/Contents/Info.plist
```

### 4. 生成 `.dmg`

先准备 dmg 根目录：

```bash
mkdir -p DmgRoot
cp -R Release/ClipboardHistory.app DmgRoot/
ln -s /Applications DmgRoot/Applications
```

再执行：

```bash
hdiutil create -volname "ClipboardHistory" \
  -srcfolder DmgRoot \
  -ov -format UDZO ClipboardHistory.dmg
```

生成后的文件位置：

```bash
/Users/q/Desktop/copy/App/ClipboardHistory.dmg
```

## 当前状态

这台机器当前的 Swift 编译器和 Command Line Tools SDK 版本不匹配，所以原生工程现在还没法在这个会话里完整编译通过。下一步最关键的是先把本机构建环境修好，然后再继续做 `.app` 和 `.dmg`。
