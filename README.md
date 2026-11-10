# OpenSlide Windows Launcher v1.0.0

下載 OpenSlide.bat 後可單獨使用，不需其他檔案。需要 Windows 10/11 x64、內建 Windows PowerShell 5.1 與網路連線。腳本使用內嵌 PowerShell；僅對本次程序設定 ExecutionPolicy，不變更電腦的永久設定。組織若禁止 PowerShell，請向 IT 確認。

## 使用

| 指令 | 行為 |
| --- | --- |
| 雙擊 `OpenSlide.bat` | 首次安裝並停止；已有 Node 與專案時直接啟動，沒有選單或彈出對話框 |
| `OpenSlide.bat install` | 安裝並停止；首次安裝後需手動啟動 |
| `OpenSlide.bat start` | 前景啟動，網址 http://127.0.0.1:5173；Ctrl+C 停止 |
| `OpenSlide.bat repair` | 用 lockfile 重建依賴，補齊缺少的工具；保留簡報與既有版本 |
| `OpenSlide.bat check` | 只查詢版本，不下載或執行最新版 CLI |
| `OpenSlide.bat update` | 顯示明確的 Open Slide/Codex 目標版本，輸入 UPDATE 才更新 |
| `OpenSlide.bat help` | 顯示指令 |

一般使用只需雙擊 BAT：首次安裝完成後停止，再次雙擊即可啟動並開啟瀏覽器。沒有圖形介面或選單；執行期間保留命令視窗，Ctrl+C 停止。進階維護參數仍可使用。

## 預設版本與目錄

- Node.js portable：首次安裝查詢最新 Windows x64 LTS，存放於 `%LOCALAPPDATA%\OpenSlide\node-v<版本>`。ZIP 使用該版本的官方 SHASUMS256.txt 驗證 SHA256。既有安裝沿用已安裝的 Node。
- Open Slide CLI/core：首次建立專案時分別查詢 npm latest 正式版，以明確版本安裝；core 寫入 package.json，後續透過 package-lock.json 與 npm ci 重建。
- Codex CLI：缺少工具時查詢 npm latest 正式版，安裝於 `%LOCALAPPDATA%\OpenSlide\npm-global`，同時安裝相同版本的 Windows x64 optional package 並執行版本驗證。repair 會保留已安裝的 Codex 版本。
- 專案：Windows 實際 Documents 已知資料夾下的 OpenSlideProjects，支援 OneDrive/重新導向目錄。
- 每次操作日誌：`%LOCALAPPDATA%\OpenSlide\logs`。

不需要管理員、不永久修改 PATH、不建立服務、不加入開機啟動。安裝器不會自動登入 Codex。Codex 沿用 `%USERPROFILE%\.codex` 或既有 CODEX_HOME；登入可執行 `"%LOCALAPPDATA%\OpenSlide\npm-global\codex.cmd" login`。

update 只在輸入 UPDATE 後將 Open Slide core 與 Codex 更新為查詢到的明確版本，不對全部依賴執行 npm update。更新前備份 package.json/package-lock.json 至 LocalAppData 下 backup 目錄；失敗可能留下部分已更新的元件，日誌會記錄，並非跨套件交易。要還原專案，將備份兩檔放回專案後執行 repair。update 不更換既有 Node 執行環境；首次安裝或執行環境缺少時才查詢最新 LTS。首次 lockfile 生成時，React 等範本間接依賴依範本範圍解析，之後依 lockfile 固定。

既有非空且不是 Open Slide 專案的目錄會被拒絕覆寫。修復不刪除簡報；npm ci 會重建 node_modules。若 portable Node 本體損壞，錯誤訊息會要求移走該版 Node 目錄後再 repair。執行中會鎖定啟動器，避免另一個實例同時修改依賴；請先停止伺服器再執行 repair/update。

## 官方來源與先前固定版本查核

- [Node.js 官方發布索引](https://nodejs.org/dist/index.json)：首次安裝從索引選擇最新 Windows x64 LTS，再下載該版本的 ZIP 與官方校驗檔。
- [Open Slide CLI 2.0.0 發布資料](https://registry.npmjs.org/@open-slide%2fcli/2.0.0)：先前已檢查此版程式碼。啟動器現改為下載 latest CLI 並直接複製其官方範本，保留隱藏檔，再設定 package.json；上游若改變範本結構，可能需調整啟動器。
- [Open Slide core 2.0.0 發布資料](https://registry.npmjs.org/@open-slide%2fcore/2.0.0)：已檢查 dev --host/--port 的實際程式碼。
- [Codex CLI 官方文件](https://developers.openai.com/codex/cli)
- [Codex 0.130.0 發布資料](https://registry.npmjs.org/@openai%2fcodex/0.130.0)：已確認 Windows x64 套件別名。

此為非官方啟動器。僅安裝與啟動 CLI，不呼叫 OpenAI API、不需要把 API key 寫入 BAT。


## 最新版預設值驗證

已通過 PowerShell 語法解析、help、latest 正式版本解析與非法版本拒絕、Node 路徑切換，以及隔離的模擬首次安裝／repair 測試：首次安裝使用查詢到的明確 CLI/core/Codex 版本，repair 保留原 core/Codex 版本。此輪未實際下載最新套件或驗證最新上游範本的相容性。

## 先前固定版本的本機測試紀錄

在 Windows CMD 執行隔離測試，專案與 LocalAppData 使用工作目錄內含中文、空格、!、&、括號的資料夾。通過 help、未知指令錯誤碼、完整網路安裝、固定版 Codex 執行、安裝後不啟動伺服器、前景啟動與 HTTP 200、連接埠占用拒絕、並行操作鎖定。因本機 5173 已有其他服務，伺服器 HTTP 測試使用僅改測試副本為 15173；交付版仍為 5173。實際升級不在測試中變更既有版本。

安裝時 npm audit 回報範本依賴有 7 項問題（3 low、4 moderate）；尚未逐項判定影響，未自動執行會改變依賴版本的 audit fix。
repair、check、拒絕 update（輸入 NO）、重複 install 亦已通過；取消更新後 Open Slide 仍為 2.0.0、Codex 仍為 0.130.0。

## 移除

先在伺服器視窗按 Ctrl+C，並關閉使用此工具安裝的 Codex CLI，再執行：

```cmd
OpenSlide.bat uninstall
```

畫面顯示移除範圍後，輸入大寫 `UNINSTALL` 才會刪除 `%LOCALAPPDATA%\OpenSlide`，其中包含 Node.js、Codex CLI、npm 快取、備份和日誌。其他輸入會取消。此指令不連網。

簡報專案、共用的 `%USERPROFILE%\.codex`／CODEX_HOME 設定，以及 BAT 本身會保留。若連作品也不需要，請自行備份後刪除 Documents 中的 OpenSlideProjects。BAT 可最後手動刪除。

若有啟動器或工具仍在執行，移除會停止。若安裝路徑包含符號連結或 junction，也會停止，需先核對連結目標後手動處理。檔案被其他程式鎖住時可能部分移除；錯誤會顯示在目前視窗。

uninstall 已以隔離的含中文與特殊字元路徑測試取消、確認刪除及重複移除；沒有對實際安裝目錄執行移除。


更新修正：update 會比較實際安裝的 core/Codex package.json 版本，只升級版本較新的元件。相同版本或本機較新時不詢問、不重裝、不降級；缺少版本資料時要求先 repair。有新版仍需在命令視窗輸入 UPDATE 同意。已用隔離測試驗證版本相同、本機較新、僅 core 較新、僅 Codex 較新與取消更新，未實際套用升級。



啟動器不修改第三方套件原始碼，也不關閉 Node 警告。若先前使用過含套件修補的版本，可使用 repair 依 lockfile 重新安裝官方套件；修復會重建 node_modules，保留簡報。警告是否消失取決於上游正式版本的修正。

不想手動輸入指令時，將 Update-OpenSlide.bat、Uninstall-OpenSlide.bat 與 OpenSlide.bat 放在同一資料夾，雙擊對應檔案即可。更新需輸入 UPDATE 才套用，移除需輸入 UNINSTALL 才刪除工具；沒有新版不會要求更新。操作前請先停止服務。主 BAT 本身仍可獨立使用，兩個輔助檔僅提供雙擊入口。
