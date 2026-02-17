
# Violin Pitch Trainer (Flutter App)

這是一個輔助小提琴音準練習的 Android APP，結合「視覺（五線譜）」與「聽覺（唱名/頻率）」的反饋機制。

## 📋 開發環境需求 (Prerequisites)

在開始之前，請確保你的 Windows 環境已安裝以下工具鏈：

1. **Git**: 用於版本控制。
2. **VS Code**: 推薦的 IDE，請安裝 `Flutter` 與 `Dart` 擴充套件。
3. **Flutter SDK**: [下載 Stable 版本]()。
4. **Android Studio**: 用於管理 Android SDK 與 Build Tools。

---

## 🛠️ 環境架設 (Environment Setup)

如果你是剛重灌電腦或全新環境，請依照以下步驟設定：

### 1. Flutter SDK 設定

* 解壓縮 Flutter SDK (例如: `D:\flutter`)。
* **環境變數 (Path)**: 將 `D:\flutter\bin` 加入 Windows 的系統環境變數 `Path` 中。
* 驗證: 開啟 PowerShell 輸入 `flutter --version`。

### 2. Android SDK & Toolchain

* 安裝 Android Studio 時，建議選擇 **Custom** 安裝，將 SDK 路徑設為非系統碟 (例如: `D:\Android-sdk`) 以節省 C 槽空間。
* **必要元件 (SDK Manager)**:
* 開啟 Android Studio -> SDK Manager -> **SDK Tools** 分頁。
* 勾選 **Android SDK Command-line Tools (latest)** (這很重要，預設不會裝)。
* 勾選 **Android SDK Build-Tools 34.0.0** (專案指定版本)。


* **同意授權**:
```powershell
flutter doctor --android-licenses
# 全部按 y 同意

```



### 3. Windows 開發者模式 (解決 Symlink 問題)

Flutter 的 Gradle 插件需要建立符號連結。

* **設定**: Windows 設定 -> 隱私權與安全性 -> 開發人員專用 -> **開啟「開發人員模式」**。

---

## 🚀 安裝與執行 (Installation & Run)

### 1. 取得專案

```powershell
git clone https://github.com/你的帳號/violin_trainer.git
cd violin_trainer

```

### 2. 連結 Android SDK (關鍵步驟)

剛 Clone 下來的專案沒有 `local.properties`，你需要建立它來告訴 Gradle SDK 在哪裡。

* 在 `android/` 資料夾下建立檔案 `local.properties`。
* 填入你的 SDK 路徑 (注意路徑分隔符號):
```properties
sdk.dir=D:\\Android-sdk
flutter.sdk=D:\\flutter

```



### 3. 下載依賴套件

```powershell
flutter pub get

```

### 4. 執行 APP

確保手機已連接並開啟 USB 偵錯模式。

* **執行在 Android 手機 (Debug Mode)**:
```powershell
flutter run

```


*(第一次執行會進行 `assembleDebug` 編譯，需等待約 2-5 分鐘)*
* **執行在 Chrome (快速驗證 UI)**:
```powershell
flutter run -d chrome

```



---

## 🐛 常見問題排除 (Troubleshooting)

### Q1: `cmdline-tools component is missing`

* **解法**: 去 Android Studio SDK Manager -> SDK Tools -> 勾選 `Android SDK Command-line Tools` 並安裝。

### Q2: Build failed with `25.0.2` or version mismatch

* **原因**: Gradle 找不到合適的 Build Tools，回退到預設錯誤版本。
* **解法**:
1. 確認 `android/app/build.gradle` 中已強制指定 `buildToolsVersion "34.0.0"`。
2. 確認 SDK Manager 中已安裝 **34.0.0** 版本。
3. 執行 `flutter clean` 後重試。



### Q3: `java.lang.System` Warnings

* **現象**: 控制台出現一堆紅色 `WARNING`。
* **解法**: 這是 Java 版本過新導致的 Gradle 警告，通常不影響編譯，可忽略。

---

## 🎹 專案結構簡介

* `lib/main.dart`: 程式進入點、UI 邏輯、五線譜繪製 (`StaffPainter`)。
* `android/app/build.gradle`: Android 建置設定 (SDK 版本控制)。
* `pubspec.yaml`: 專案依賴管理 (如 `audioplayers`)。