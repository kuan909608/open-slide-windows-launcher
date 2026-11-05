# Open Slide Windows Launcher

Windows 一鍵安裝與啟動 [Open Slide](https://open-slide.dev/)，整合 OpenAI Codex CLI，適合不具備 Windows 系統管理員權限的使用者。

## 功能特色

- 首次執行自動安裝 Node.js Portable、Open Slide、Codex CLI
- 後續執行直接啟動 Open Slide
- 不需要 Windows Administrator 權限
- 不修改系統或使用者永久 PATH
- 不建立 Windows Service 或開機自動啟動
- 優先沿用本機 Codex 的既有登入狀態
- 僅監聽 `127.0.0.1:5173`

## 系統需求

- Windows 10 / 11（x64）
- 可連線至 Node.js 官方網站及 npm Registry
- 可執行 CMD、curl、tar 和 certutil
- 安裝及執行相關軟體須符合組織 IT 政策

## 使用方式

1. 從 GitHub Releases 下載 `OpenSlide.bat`。
2. 雙擊 `OpenSlide.bat`。
3. 首次執行時自動安裝相依環境。
4. 啟動後透過瀏覽器開啟 `http://127.0.0.1:5173`。
5. 使用完畢後按 `Ctrl+C` 停止服務。

## 安裝目錄

程式安裝在：

`%LOCALAPPDATA%\OpenSlide`

簡報專案預設存放在：

`%USERPROFILE%\Documents\OpenSlideProjects`

Codex 的登入設定會維持原有位置，不會由本腳本複製或上傳。

## 注意事項

本工具是非官方的 Windows 啟動腳本，並非 Open Slide 或 OpenAI 官方發行版本。

本工具依賴 Open Slide、Node.js 與 Codex CLI。使用前應確認各項軟體的授權條款、版本相容性及組織 IT 政策。

## 專案授權

MIT License（僅適用於本專案自行撰寫的腳本與文件）。
