# 🎻 Violin Trainer (小提琴視譜與音高練習器)

這是一個輔助小提琴音準練習的 Android 與 Web 應用程式，結合「物理指板視覺化」、「五線譜視譜」與「聽覺反饋」機制。

- [🎻 Violin Trainer (小提琴視譜與音高練習器)](#-violin-trainer-小提琴視譜與音高練習器)
  - [📋 開發環境需求 (Prerequisites)](#-開發環境需求-prerequisites)
  - [🛠️ 環境架設 (Environment Setup)](#️-環境架設-environment-setup)
    - [1. Flutter SDK 設定](#1-flutter-sdk-設定)
    - [2. Android SDK \& Toolchain](#2-android-sdk--toolchain)
    - [3. Windows 開發者模式](#3-windows-開發者模式)
  - [🚀 執行與偵錯 (Run \& Debug)](#-執行與偵錯-run--debug)
    - [1. 連結專案與 SDK](#1-連結專案與-sdk)
    - [2. 不同模式的執行方式](#2-不同模式的執行方式)
  - [📦 打包與發佈 (Build \& Deploy)](#-打包與發佈-build--deploy)
    - [1. 打包成 Android APK (供人安裝)](#1-打包成-android-apk-供人安裝)
    - [2. 打包成 Web 網站](#2-打包成-web-網站)
  - [🎻 核心功能說明](#-核心功能說明)
    - [專業級指板視覺化](#專業級指板視覺化)
    - [智慧邏輯系統](#智慧邏輯系統)
  - [🛠️ 專案架構 (Refactored)](#️-專案架構-refactored)
  - [🐛 常見問題排除 (Troubleshooting)](#-常見問題排除-troubleshooting)


## 📋 開發環境需求 (Prerequisites)

在開始之前，請確保你的 Windows 環境已安裝以下工具鏈：

1. **Git**: 用於版本控制。
2. **VS Code**: 推薦 IDE，請安裝 `Flutter` 與 `Dart` 擴充套件。
3. **Flutter SDK**: [下載 Stable 版本]()。
4. **Android Studio**: 用於管理 Android SDK 與 Build Tools。

---

## 🛠️ 環境架設 (Environment Setup)

### 1. Flutter SDK 設定

* 解壓縮 Flutter SDK (例如: `D:\flutter`)。
* **環境變數 (Path)**: 將 `D:\flutter\bin` 加入 Windows 系統環境變數 `Path` 中。
* **驗證**: 開啟 PowerShell 輸入 `flutter --version`。

### 2. Android SDK & Toolchain

* 安裝 Android Studio，將 SDK 路徑設為非系統碟 (例如: `D:\Android-sdk`)。
* **必要元件 (SDK Manager)**:
* 開啟 Android Studio -> SDK Manager -> **SDK Tools** 分頁。
* 勾選 **Android SDK Command-line Tools (latest)**。
* 勾選 **Android SDK Build-Tools 34.0.0**。


* **同意授權**:
```powershell
flutter doctor --android-licenses

```



### 3. Windows 開發者模式

* **設定**: Windows 設定 -> 隱私權與安全性 -> 開發人員專用 -> **開啟「開發人員模式」**（解決 Gradle Symlink 問題）。

---

## 🚀 執行與偵錯 (Run & Debug)

### 1. 連結專案與 SDK

* 在 `android/` 資料夾下建立 `local.properties` 檔案：
```properties
sdk.dir=D:\\Android-sdk
flutter.sdk=D:\\flutter

```


* 執行 `flutter pub get` 下載套件。

### 2. 不同模式的執行方式

預設執行右上角會有 **Debug** 字樣，這是為了開發時方便熱重載 (Hot Reload)。

| 目標裝置 | 模式 | 指令 | 說明 |
| --- | --- | --- | --- |
| **Android 手機** | **Debug** | `flutter run` | 支援 Hot Reload，效能較普通。 |
| **Android 手機** | **Release** | `flutter run --release` | **移除右上角 Debug 字樣**，效 |
| **Chrome** | **Debug** | `flutter run -d chrome` | 快速驗證 UI 佈局。 |

---

## 📦 打包與發佈 (Build & Deploy)

如果你想將程式給別人安裝，或架設成網站，請執行以下指令：

### 1. 打包成 Android APK (供人安裝)

執行完後，檔案位於 `build\app\outputs\flutter-apk\app-release.apk`。

```powershell
flutter build apk --release

```

### 2. 打包成 Web 網站

執行完後，將 `build\web\` 資料夾下的所有內容上傳到任何靜態網頁空間 (如 GitHub Pages, Vercel 或自己的主機)。

```powershell
flutter build web --release

```

---

## 🎻 核心功能說明

### 專業級指板視覺化

* **物理座標計算**：根據標準弦長 (325mm) 之對數公式計算，真實還原高把位音距縮短的特性。
* **動態背景圖鑑**：指板會根據目前選擇的調性，自動顯示該音階的所有合法按點（灰色點）。
* **多把位支援**：支援 **第一把位 (First Pos)** 與 **第三把位 (Third Pos)**，可多選進行混合訓練，音域滑桿會自動對齊把位範圍。

### 智慧邏輯系統

* **15 種大調支援**：從 7# (C# Major) 到 7b (Cb Major) 完整覆蓋。
* **三大模式**：看譜找指位、看指位猜音、聽音辨音高 (支援 440/442Hz)。

---

## 🛠️ 專案架構 (Refactored)

為了保持程式碼的可維護性，專案已進行模組化拆分：

* `lib/main.dart`: **UI 介面層**。負責主要佈局、設定選單邏輯及狀態管理。
* `lib/models/`: **資料模型層**。
    * `note.dart`: 定義 `ViolinNote` 類別及所有樂理相關 `Enum`。
    * `scale_data.dart`: 靜態資料庫，包含完整的半音階頻率與各調性音階表。


* `lib/utils/`: **邏輯與工具層**。
    * `violin_logic.dart`: **核心大腦**。負責處理物理座標、指法換算及把位音域檢查。
    * `audio_gen.dart`: 負責即時生成指定頻率的正弦波 (WAV)。


* `lib/widgets/`: **繪圖組件層**。
    * `painters.dart`: 包含五線譜、指板、迷你調號圖示的自定義繪圖器。

---

## 🐛 常見問題排除 (Troubleshooting)

* **Q: 右上角 Debug 標誌如何消失？**
* 使用 `--release` 模式執行，或在打包成 APK 後安裝即會消失。


* **Q: `cmdline-tools component is missing**`
* 去 Android Studio SDK Manager -> SDK Tools 安裝 `Android SDK Command-line Tools`。


* **Q: Node 或按鈕被遮擋？**
* 本版本已將五線譜行距縮小為 10.0，指板視野擴大至 200mm，並採用左右分欄佈局優化空間。

