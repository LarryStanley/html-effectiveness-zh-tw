# 繁體中文（台灣用語）翻譯 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **本計畫的特殊執行模式：** 每個檔案的實際翻譯不由 Opus/Claude subagent 執行，而是**外包給 `ccg -p`（= `claude-glm`，Claude Code 跑在 GLM-5.2 1M context 上）**在獨立行程中就地改檔，以節省 Opus token。Opus 只負責：建立準則檔、下 `ccg` 指令、逐檔審查產出。

**Goal:** 把此 repo 全部 33 個 HTML 內容頁與 `README.md` 的可見文字翻成通順的繁體中文（台灣用語），程式碼保留、去除 AI 翻譯腔，並確保跨檔術語一致。

**Architecture:** 先建立一份共用「翻譯準則檔」（Humanizer 規則 + 使用者準則 + 程式碼保留規則 + 術語對照表），再對每個檔案呼叫一次 `ccg -p --permission-mode bypassPermissions`，讓 GLM 讀準則檔、就地 Edit 該檔。每翻完一批就跑 `verify-translation.sh` 做客觀護欄檢查（`<style>`/`<script>` 位元組不變、`lang` 屬性已改、可見文字 CJK 比例足夠），再由 Opus 抽查品質後 commit。

**Tech Stack:** 純靜態 HTML（無 build、無相依）、`ccg`/`claude-glm`（GLM-5.2）、bash 驗證腳本、git。

## Global Constraints

以下為所有 Task 共同遵守的專案級要求，逐條照抄自使用者需求與 Humanizer-zh-TW 準則，每個 Task 的要求隱含包含本節。

- **翻譯範圍：** 20 個 numbered `*.html` + `unknowns/` 內 12 個 `*.html` + `index.html` + `README.md`，共 34 個翻譯單位。**排除** `LICENSE`、`SECURITY.md`、`CODE_OF_CONDUCT.md`（法律/樣板，維持原文）。
- **一字不漏：** 所有可見文字都要翻，且對中文讀者讀起來通順。不因內容長就分段省略——每個檔案一口氣翻完。
- **人名保留原文**（例：Kevin、Sarah 等作者/署名不譯）。
- **專有名詞中英對照**：技術名詞「首次出現」用「中文（English）」形式，以不影響可讀性為主；同檔後續可只用中文。
- **程式碼保留、只翻註解與敘述**：程式語法、識別字、檔名（如 `middleware/ratelimit.ts`）、變數名、HTTP 狀態碼（如 `429`）、Redis key、CSS class 名、`id`/`href` 錨點值一律**保留原文**；只翻譯程式碼中的**註解**與程式碼周邊的敘述文字。
- **絕不更動：** `<style>`、`<script>` 區塊內容（CSS/JS）、`class`/`id`/`href`/`src`/`data-*` 屬性值、`<code>` 內的識別字與檔名、著作權註解行（`<!-- Copyright 2026 Anthropic PBC ... -->`）。
- **語言屬性：** 每個 HTML 檔的 `<html lang="en">` 改為 `<html lang="zh-Hant-TW">`。
- **去 AI 腔（Humanizer-zh-TW，github.com/kevintsai1202/Humanizer-zh-TW）：** 見準則檔完整清單。重點：避免高頻 AI 詞（此外、至關重要、深入探討、強調、持久的、增強、培養、獲得、突顯、複雜性、關鍵性、展示、寶貴、充滿活力…）；避免破折號濫用、避免「不僅…而是…」負向排比、避免三詞排比（rule of three）、避免空泛歸因與樣板結論；句子長短交錯、用「是」不要刻意迴避繫詞、用具體細節取代抽象吹捧。
- **術語一致：** 全站沿用同一份對照表（見準則檔「術語對照表」節），不要同一詞在不同檔翻成不同中文。
- **執行指令樣板（每檔一次）：**
  ```bash
  ccg -p --permission-mode bypassPermissions \
    "請嚴格依照 docs/superpowers/plans/_translation-contract.md 的全部準則，翻譯檔案 <FILE_PATH>，用 Read 讀取後以 Edit 就地修改該檔（不要另存新檔）。只回報你改了什麼，不要輸出整份檔案。"
  ```

---

### Task 0: 環境設定與翻譯準則檔

**Files:**
- Create: `docs/superpowers/plans/_translation-contract.md`（GLM 每次翻譯都讀的準則檔）
- Create: `docs/superpowers/plans/verify-translation.sh`（客觀護欄檢查腳本）
- Modify: git 分支（建立 `translate-zh-tw`）

**Interfaces:**
- Produces：
  - `_translation-contract.md` — 所有翻譯 Task 的 `ccg` 指令都引用它。
  - `verify-translation.sh <file>` — 回傳非零 exit code 代表該檔未通過護欄；後續每個 Task 都用它驗證。

- [ ] **Step 1: 建立分支**

```bash
cd /Users/stanley/Code/html-effectiveness-zh-tw
git switch -c translate-zh-tw
```

- [ ] **Step 2: 寫入翻譯準則檔**

建立 `docs/superpowers/plans/_translation-contract.md`，內容完全如下：

```markdown
# 翻譯準則（繁體中文・台灣用語）

你是專業的繁體中文（台灣）在地化譯者。請依下列所有準則，就地翻譯指定的 HTML/Markdown 檔案。

## 目標
把檔案中所有「可見文字」翻成通順、自然、像台灣工程師寫的繁體中文。不僅要乾淨，更要鮮活——避免任何機器翻譯腔與 AI 寫作腔。

## 一定要翻
- 標題、段落、清單、按鈕/連結文字、表格內容、側欄標籤、圖說、summary/details 文字。
- 程式碼區塊中的「註解」（`//`、`#`、`/* */`、`<!-- -->` 內的人類敘述）。
- 使用者可見的字串描述、UI 標籤文字。

## 一定要保留原文（絕不更動）
- `<style>`、`<script>` 區塊全部內容（CSS/JS）。
- HTML 屬性值：`class`、`id`、`href`、`src`、`data-*`、`aria-*` 的值；錨點如 `href="#tldr"` 與對應 `id="tldr"`。
- 檔名/路徑（`middleware/ratelimit.ts`、`config/limits.yaml`）、變數名、函式名、型別名、程式語法。
- HTTP 狀態碼（`429`）、數字、指標、Redis key（`rl:{route}:{key}`）、環境變數、指令列。
- 頁首著作權註解：`<!-- Copyright 2026 Anthropic PBC · SPDX-License-Identifier: Apache-2.0 -->`。
- 人名（作者、署名、範例人名如 Sarah、Kevin）保留原文。
- 品牌佔位字 `Acme` 保留原文。

## 語言屬性
把 `<html lang="en">` 改成 `<html lang="zh-Hant-TW">`。

## 專有名詞：中英對照
技術名詞「首次出現」用「中文（English）」，例如：中介層（middleware）、速率限制（rate limiting）。同一檔後續可只用中文。以不影響可讀性為主，不要每次都加括號。

## 台灣用語（避免中國大陸用語）
- 軟體（非「软件」）、程式（非「程序」指 program）、介面（非「接口」）、資料（非「数据」）、預設（非「默认」）、快取（非「缓存」）、部署、相依套件、回報、最佳化（非「优化」→用「最佳化」）、伺服器、使用者（非「用户」可，但偏好「使用者」）、專案（非「项目」）、登入/登出、預覽、切換。
- 標點用全形；句號用「。」。

## 去 AI 腔規則（Humanizer-zh-TW）
避免以下高頻 AI 詞與句式：
- 高頻 AI 詞：此外、至關重要、深入探討、強調、持久的、增強、培養、獲得、突顯、相互作用、複雜性、佈局、關鍵性、展示、寶貴、充滿活力、賦能、打造、值得注意的是、總的來說。
- 句式：不要「不僅…而是/更…」負向排比；不要三個形容詞排比（如「無縫、直觀且強大」）；不要破折號（—）濫用，中文改用逗號或分號或直接斷句；不要空泛歸因（「專家認為」「研究表明」而無出處）；不要樣板式「挑戰與展望」結尾；不要浮誇的意義拔高（「作為…的證明」）。
- 手法：句子長短交錯；該用「是」就用「是」，不要刻意迴避繫詞；用具體細節與實際功能名稱取代抽象吹捧；語氣自然、不諂媚、不加免責聲明、不加表情符號。

## 使用者硬性要求
一字不漏地翻完整個檔案，確保通順。不要因為內容長就分段或省略；一次全部翻完。不要遺漏任何一句話。

## 術語對照表（全站一致，請沿用）
| English | 繁中（台灣） |
|---|---|
| HTML | HTML（保留） |
| rate limiting | 速率限制 |
| token bucket | 權杖桶（token bucket） |
| middleware | 中介層 |
| API key | API 金鑰 |
| design system | 設計系統 |
| component / variant | 元件 / 變體 |
| feature flag | 功能旗標（feature flag） |
| incident report | 事故報告 |
| status report | 狀態報告 |
| pull request / PR | 拉取請求（PR） |
| code review | 程式碼審查 |
| prototype | 原型 |
| flowchart | 流程圖 |
| slide deck | 簡報 |
| prompt tuner | 提示詞調校器（prompt tuner） |
| triage board | 分流看板 |
| explainer | 說明頁 |
| endpoint | 端點 |
| request / response | 請求 / 回應 |
| cache | 快取 |
| deploy / deployment | 部署 |
| dependency | 相依套件 |
| refactor | 重構 |
| edge case | 邊界情境 |
| fallback | 後備（fallback） |
| gotcha | 陷阱/眉角 |
| TL;DR | 一句話重點（TL;DR） |
| On this page | 本頁目錄 |

翻完後，只用一兩句話回報你改了哪些部分即可，不要把整份檔案貼回來。
```

- [ ] **Step 3: 寫入驗證腳本**

建立 `docs/superpowers/plans/verify-translation.sh`，內容完全如下：

```bash
#!/usr/bin/env bash
# 客觀護欄：確認翻譯沒破壞不該動的東西。用法：verify-translation.sh <file>
set -euo pipefail
f="$1"
fail=0

# 1) HTML 檔必須已把 lang 改成 zh-Hant-TW，且不再有 lang="en"
if [[ "$f" == *.html ]]; then
  if ! grep -q 'lang="zh-Hant-TW"' "$f"; then
    echo "  ✗ [$f] 找不到 lang=\"zh-Hant-TW\""; fail=1
  fi
  if grep -q 'lang="en"' "$f"; then
    echo "  ✗ [$f] 仍殘留 lang=\"en\""; fail=1
  fi
fi

# 2) <style> 與 <script> 區塊必須與 git HEAD 版本位元組完全相同（CSS/JS 絕不可改）
extract_protected () {
  awk 'BEGIN{p=0}
       /<style/{p=1} /<script/{p=1}
       {if(p)print}
       /<\/style>/{p=0} /<\/script>/{p=0}' "$1"
}
if [[ "$f" == *.html ]]; then
  before="$(git show "HEAD:$f" 2>/dev/null | awk 'BEGIN{p=0}/<style/{p=1}/<script/{p=1}{if(p)print}/<\/style>/{p=0}/<\/script>/{p=0}')" || before=""
  after="$(extract_protected "$f")"
  if [[ -n "$before" && "$before" != "$after" ]]; then
    echo "  ✗ [$f] <style>/<script> 區塊被更動（CSS/JS 不可翻譯）"; fail=1
  fi
fi

# 3) 可見文字要有足夠中文：CJK 字元數應 > 50（避免整檔沒翻）
cjk=$(grep -oP '[\x{4e00}-\x{9fff}]' "$f" 2>/dev/null | wc -l | tr -d ' ')
if [[ "${cjk:-0}" -lt 50 ]]; then
  echo "  ✗ [$f] CJK 字元只有 ${cjk:-0} 個，疑似未翻或翻太少"; fail=1
fi

# 4) 著作權行必須保留
if [[ "$f" == *.html ]] && grep -q 'Copyright 2026 Anthropic' "$(git show HEAD:"$f" >/dev/null 2>&1 && echo /dev/stdin || echo "$f")" 2>/dev/null; then :; fi
if [[ "$f" == *.html ]] && ! grep -q 'Copyright 2026 Anthropic PBC' "$f"; then
  echo "  ✗ [$f] 著作權註解行遺失"; fail=1
fi

if [[ "$fail" == 0 ]]; then echo "  ✓ [$f] 通過護欄"; fi
exit "$fail"
```

- [ ] **Step 4: 設定腳本可執行並驗證環境**

Run:
```bash
chmod +x docs/superpowers/plans/verify-translation.sh
grep -oP '[\x{4e00}-\x{9fff}]' README.md | head -1 >/dev/null 2>&1 && echo "grep -P OK" || echo "grep -P 需改用其他方式"
ccg -p --permission-mode bypassPermissions "回覆兩個字：就緒" 2>&1 | tail -3
```
Expected: 印出 `grep -P OK`（macOS 若無 GNU grep，Step 5 改用 perl 版本）；且 `ccg` 回覆包含「就緒」，代表 GLM 可用。

- [ ] **Step 5: （條件式）macOS grep 相容處理**

若 Step 4 顯示 `grep -P 需改用其他方式`（macOS 內建 BSD grep 不支援 `-P`），把 `verify-translation.sh` 第 3 項的 CJK 計數改為 perl：
```bash
cjk=$(perl -CSD -ne 'print for /[\x{4e00}-\x{9fff}]/g' "$f" | wc -c | tr -d ' ')
```
若 Step 4 已 OK，跳過本步。

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/plans/_translation-contract.md docs/superpowers/plans/verify-translation.sh docs/superpowers/plans/2026-07-05-translate-zh-tw.md
git commit -m "chore: add zh-TW translation contract, verify script, and plan"
```

---

### Task 1: 試翻校準 — `index.html`（首頁）

先翻最重要、最曝光的首頁，確認 `ccg` 指令與準則檔能產出合格結果，並校準準則檔（例如補術語）。

**Files:**
- Modify: `index.html`

**Interfaces:**
- Consumes：Task 0 的 `_translation-contract.md`、`verify-translation.sh`。
- Produces：校準後的 `_translation-contract.md`（若試翻發現問題就回補術語/規則），供後續所有 Task 沿用。

- [ ] **Step 1: 呼叫 GLM 翻譯 index.html**

Run:
```bash
ccg -p --permission-mode bypassPermissions \
  "請嚴格依照 docs/superpowers/plans/_translation-contract.md 的全部準則，翻譯檔案 index.html，用 Read 讀取後以 Edit 就地修改該檔（不要另存新檔）。只回報你改了什麼，不要輸出整份檔案。"
```

- [ ] **Step 2: 跑護欄檢查**

Run:
```bash
bash docs/superpowers/plans/verify-translation.sh index.html
```
Expected: `✓ [index.html] 通過護欄`（exit 0）。若失敗，看訊息修正（見 Step 4）。

- [ ] **Step 3: Opus 人工抽查品質**

由 Opus 讀 `index.html` 檢查：
- 標題 `<h1>`、`.intro`、各分類卡片標題/說明是否翻得通順且台灣用語。
- 有無殘留 AI 腔（破折號濫用、三詞排比、「賦能/打造」等）。
- 專有名詞是否中英對照且與術語表一致。
- `class`/`id`/`href` 錨點、CSS 變數、著作權行是否原封不動。
- 頁面在瀏覽器開啟排版是否正常（`open index.html`）。

- [ ] **Step 4: 修正與校準（若需要）**

若品質不足：
- 小問題直接 Edit `index.html` 修字。
- 系統性問題（術語不一致、某類 AI 腔反覆出現）→ 更新 `_translation-contract.md` 對應規則或術語表，再重跑 Step 1（GLM 會重讀準則）。

- [ ] **Step 5: Commit**

```bash
git add index.html docs/superpowers/plans/_translation-contract.md
git commit -m "i18n: translate index.html to zh-TW"
```

---

### Task 2: 內容頁批次 A — Exploration + Code（`01`–`06`）

**Files（逐一就地翻譯）:**
- Modify: `01-exploration-code-approaches.html`
- Modify: `02-exploration-visual-designs.html`
- Modify: `03-code-review-pr.html`
- Modify: `04-code-understanding.html`
- Modify: `05-design-system.html`
- Modify: `06-component-variants.html`

**Interfaces:**
- Consumes：`_translation-contract.md`、`verify-translation.sh`。
- Produces：6 個翻好的 HTML；沿用同一術語表（`code review`→程式碼審查、`design system`→設計系統、`component/variant`→元件/變體）。

- [ ] **Step 1: 逐檔呼叫 GLM 翻譯**

Run（可一次跑完，或逐行跑以便逐檔看回報）：
```bash
for f in 01-exploration-code-approaches.html 02-exploration-visual-designs.html \
         03-code-review-pr.html 04-code-understanding.html \
         05-design-system.html 06-component-variants.html; do
  echo "=== translating $f ==="
  ccg -p --permission-mode bypassPermissions \
    "請嚴格依照 docs/superpowers/plans/_translation-contract.md 的全部準則，翻譯檔案 $f，用 Read 讀取後以 Edit 就地修改該檔（不要另存新檔）。特別注意：程式碼片段、diff、檔名、變數名一律保留原文，只翻程式碼註解與敘述。只回報你改了什麼。"
done
```

- [ ] **Step 2: 逐檔跑護欄**

Run:
```bash
for f in 01-exploration-code-approaches.html 02-exploration-visual-designs.html \
         03-code-review-pr.html 04-code-understanding.html \
         05-design-system.html 06-component-variants.html; do
  bash docs/superpowers/plans/verify-translation.sh "$f" || echo "  !! $f 需處理"
done
```
Expected: 每檔 `✓ 通過護欄`。任何 `✗` 依訊息修正後重跑該檔。

- [ ] **Step 3: Opus 抽查（重點：程式碼保留）**

Opus 至少抽查 `03-code-review-pr.html` 與 `04-code-understanding.html`（程式碼密度最高）：確認 diff、函式名、檔名、行號原封不動，只有註解與敘述被翻；術語與 Task 1 一致；無 AI 腔。其餘四檔快速掃視標題與段落。必要時直接 Edit 修正。

- [ ] **Step 4: Commit**

```bash
git add 0[1-6]-*.html
git commit -m "i18n: translate examples 01-06 (exploration + code) to zh-TW"
```

---

### Task 3: 內容頁批次 B — Prototyping + Communication（`07`–`12`）

**Files（逐一就地翻譯）:**
- Modify: `07-prototype-animation.html`
- Modify: `08-prototype-interaction.html`
- Modify: `09-slide-deck.html`
- Modify: `10-svg-illustrations.html`
- Modify: `11-status-report.html`
- Modify: `12-incident-report.html`

**Interfaces:**
- Consumes：`_translation-contract.md`、`verify-translation.sh`。
- Produces：6 個翻好的 HTML。注意 `07`/`08` 為互動/動畫原型，JS 與 CSS 動畫**不可動**，只翻 UI 文字；`10` 的 SVG 內 `<text>` 文字要翻但 `<path>`/座標不動。

- [ ] **Step 1: 逐檔呼叫 GLM 翻譯**

Run:
```bash
for f in 07-prototype-animation.html 08-prototype-interaction.html \
         09-slide-deck.html 10-svg-illustrations.html \
         11-status-report.html 12-incident-report.html; do
  echo "=== translating $f ==="
  ccg -p --permission-mode bypassPermissions \
    "請嚴格依照 docs/superpowers/plans/_translation-contract.md 的全部準則，翻譯檔案 $f，用 Read 讀取後以 Edit 就地修改該檔（不要另存新檔）。特別注意：<script> 與 <style>（含動畫）完全不可改；SVG 只翻 <text> 內文字，座標與 <path> 不動。只回報你改了什麼。"
done
```

- [ ] **Step 2: 逐檔跑護欄**

Run:
```bash
for f in 07-prototype-animation.html 08-prototype-interaction.html \
         09-slide-deck.html 10-svg-illustrations.html \
         11-status-report.html 12-incident-report.html; do
  bash docs/superpowers/plans/verify-translation.sh "$f" || echo "  !! $f 需處理"
done
```
Expected: 每檔 `✓ 通過護欄`。

- [ ] **Step 3: Opus 抽查（重點：互動與 SVG）**

Opus 在瀏覽器開 `07`、`08` 確認互動/動畫仍正常、只有文字變中文；開 `10` 確認 SVG 圖說已翻且圖形沒跑掉；掃視 `09`/`11`/`12` 標題與內文（事故報告用「事故報告」、狀態報告用「狀態報告」）。必要時 Edit 修正。

- [ ] **Step 4: Commit**

```bash
git add 0[7-9]-*.html 1[0-2]-*.html
git commit -m "i18n: translate examples 07-12 (prototyping + communication) to zh-TW"
```

---

### Task 4: 內容頁批次 C — Diagrams / Research / Editors（`13`–`20`）

**Files（逐一就地翻譯）:**
- Modify: `13-flowchart-diagram.html`
- Modify: `14-research-feature-explainer.html`
- Modify: `15-research-concept-explainer.html`
- Modify: `16-implementation-plan.html`
- Modify: `17-pr-writeup.html`
- Modify: `18-editor-triage-board.html`
- Modify: `19-editor-feature-flags.html`
- Modify: `20-editor-prompt-tuner.html`

**Interfaces:**
- Consumes：`_translation-contract.md`、`verify-translation.sh`。
- Produces：8 個翻好的 HTML。`18`–`20` 為互動編輯器（含 JS 狀態），只翻 UI 文字與標籤，JS 邏輯不動；`13` 流程圖節點 `<text>` 要翻。

- [ ] **Step 1: 逐檔呼叫 GLM 翻譯**

Run:
```bash
for f in 13-flowchart-diagram.html 14-research-feature-explainer.html \
         15-research-concept-explainer.html 16-implementation-plan.html \
         17-pr-writeup.html 18-editor-triage-board.html \
         19-editor-feature-flags.html 20-editor-prompt-tuner.html; do
  echo "=== translating $f ==="
  ccg -p --permission-mode bypassPermissions \
    "請嚴格依照 docs/superpowers/plans/_translation-contract.md 的全部準則，翻譯檔案 $f，用 Read 讀取後以 Edit 就地修改該檔（不要另存新檔）。特別注意：互動編輯器的 <script> 邏輯與 data 屬性完全不可改，只翻 UI 標籤/按鈕/說明文字；流程圖 SVG 只翻 <text>。只回報你改了什麼。"
done
```

- [ ] **Step 2: 逐檔跑護欄**

Run:
```bash
for f in 13-flowchart-diagram.html 14-research-feature-explainer.html \
         15-research-concept-explainer.html 16-implementation-plan.html \
         17-pr-writeup.html 18-editor-triage-board.html \
         19-editor-feature-flags.html 20-editor-prompt-tuner.html; do
  bash docs/superpowers/plans/verify-translation.sh "$f" || echo "  !! $f 需處理"
done
```
Expected: 每檔 `✓ 通過護欄`。

- [ ] **Step 3: Opus 抽查（重點：編輯器互動）**

Opus 在瀏覽器開 `18`、`19`、`20` 確認編輯器互動（拖曳、切換旗標、輸入）仍正常、只有文字中文化；開 `13` 確認流程圖節點文字已翻且連線沒亂；掃視 `14`–`17` 內文，確認 `14` 的 rate limiting 段落沿用「速率限制／權杖桶」術語。必要時 Edit 修正。

- [ ] **Step 4: Commit**

```bash
git add 1[3-9]-*.html 20-*.html
git commit -m "i18n: translate examples 13-20 (diagrams, research, editors) to zh-TW"
```

---

### Task 5: `unknowns/` 子頁（index + `01`–`11`）

**Files（逐一就地翻譯）:**
- Modify: `unknowns/index.html`
- Modify: `unknowns/01-blindspot-pass.html`
- Modify: `unknowns/02-color-grading-explainer.html`
- Modify: `unknowns/03-design-directions.html`
- Modify: `unknowns/04-toolbar-mock.html`
- Modify: `unknowns/05-churn-brainstorm.html`
- Modify: `unknowns/06-interview.html`
- Modify: `unknowns/07-reference-port.html`
- Modify: `unknowns/08-implementation-plan.html`
- Modify: `unknowns/09-implementation-notes.html`
- Modify: `unknowns/10-pitch-doc.html`
- Modify: `unknowns/11-change-quiz.html`

**Interfaces:**
- Consumes：`_translation-contract.md`、`verify-translation.sh`。
- Produces：12 個翻好的 HTML，術語與主目錄一致。

- [ ] **Step 1: 逐檔呼叫 GLM 翻譯**

Run:
```bash
for f in unknowns/index.html unknowns/01-blindspot-pass.html \
         unknowns/02-color-grading-explainer.html unknowns/03-design-directions.html \
         unknowns/04-toolbar-mock.html unknowns/05-churn-brainstorm.html \
         unknowns/06-interview.html unknowns/07-reference-port.html \
         unknowns/08-implementation-plan.html unknowns/09-implementation-notes.html \
         unknowns/10-pitch-doc.html unknowns/11-change-quiz.html; do
  echo "=== translating $f ==="
  ccg -p --permission-mode bypassPermissions \
    "請嚴格依照 docs/superpowers/plans/_translation-contract.md 的全部準則，翻譯檔案 $f，用 Read 讀取後以 Edit 就地修改該檔（不要另存新檔）。程式碼、檔名、變數名、data 屬性保留原文，只翻註解與敘述。只回報你改了什麼。"
done
```

- [ ] **Step 2: 逐檔跑護欄**

Run:
```bash
for f in unknowns/index.html unknowns/0[1-9]-*.html unknowns/1[01]-*.html; do
  bash docs/superpowers/plans/verify-translation.sh "$f" || echo "  !! $f 需處理"
done
```
Expected: 每檔 `✓ 通過護欄`。

- [ ] **Step 3: Opus 抽查**

Opus 掃視 `unknowns/index.html`（子頁目錄，連結文字要翻但 `href` 不動）與 `unknowns/11-change-quiz.html`（若有 JS 測驗互動，確認邏輯不動、選項文字翻好）。其餘檔快速掃視標題與首段。必要時 Edit 修正。

- [ ] **Step 4: Commit**

```bash
git add unknowns/
git commit -m "i18n: translate unknowns/ subpages to zh-TW"
```

---

### Task 6: `README.md`

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes：`_translation-contract.md`。
- Produces：翻好的 README；表格分類名沿用術語表；程式碼區塊/檔名/指令保留原文。

- [ ] **Step 1: 呼叫 GLM 翻譯**

Run:
```bash
ccg -p --permission-mode bypassPermissions \
  "請嚴格依照 docs/superpowers/plans/_translation-contract.md 的全部準則，翻譯檔案 README.md，用 Read 讀取後以 Edit 就地修改。Markdown 結構（標題層級、表格、程式碼區塊、連結目標）保留，只翻文字；檔名如 index.html、SECURITY.md、LICENSE 與連結路徑不動；『Sample code. Not maintained...』警語要翻。只回報你改了什麼。"
```

- [ ] **Step 2: 跑護欄**

Run:
```bash
bash docs/superpowers/plans/verify-translation.sh README.md
```
Expected: `✓ [README.md] 通過護欄`（README 非 html，只檢 CJK 數量）。

- [ ] **Step 3: Opus 抽查**

Opus 讀 `README.md`：確認分類表（Exploration→探索、Code→程式碼…）用術語表；連結 `[index.html](index.html)` 目標未變；Markdown 表格對齊未破壞。必要時 Edit 修正。

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "i18n: translate README to zh-TW"
```

---

### Task 7: 全站終檢與一致性

翻完全部後做一次整體驗證：無殘留、術語一致、頁面可正常開啟。

**Files:**
- Modify（僅必要修正）：任一未通過的檔案。

**Interfaces:**
- Consumes：全部已翻檔案、`verify-translation.sh`。

- [ ] **Step 1: 全檔跑護欄**

Run:
```bash
cd /Users/stanley/Code/html-effectiveness-zh-tw
pass=0; fail=0
for f in *.html unknowns/*.html README.md; do
  if bash docs/superpowers/plans/verify-translation.sh "$f" >/dev/null 2>&1; then
    pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $f"; fi
done
echo "通過 $pass 個，失敗 $fail 個"
```
Expected: `失敗 0 個`（共 34 個檔通過）。有失敗就回到對應 Task 修正。

- [ ] **Step 2: 殘留 lang="en" 全域掃描**

Run:
```bash
grep -rl 'lang="en"' *.html unknowns/*.html && echo "!! 仍有殘留" || echo "全部 lang 已改"
```
Expected: `全部 lang 已改`。

- [ ] **Step 3: 術語一致性抽查**

Run（檢查易分歧的詞是否出現兩種譯法）：
```bash
echo "--- design system ---"; grep -roh '設計系統\|設計體系' *.html | sort | uniq -c
echo "--- pull request ---"; grep -roh '拉取請求\|合併請求\|PR' *.html unknowns/*.html | sort | uniq -c
echo "--- middleware ---"; grep -roh '中介層\|中間件\|中介軟體' *.html | sort | uniq -c
```
Expected: 每個詞只出現準則表指定的譯法（如「設計系統」而非「設計體系」；「中介層」而非「中間件」）。發現分歧→用 `sed`/Edit 統一，或針對該檔重跑 GLM。

- [ ] **Step 4: 逐頁目視（抽樣）**

Run:
```bash
open index.html 01-exploration-code-approaches.html 18-editor-triage-board.html unknowns/index.html
```
Opus/使用者確認排版正常、無破圖、互動可用、無明顯 AI 腔或未翻段落。

- [ ] **Step 5: 最終 commit 與收尾**

```bash
git add -A
git commit -m "i18n: final zh-TW consistency pass across all pages" || echo "無額外變更"
git log --oneline translate-zh-tw ^main
```
之後依 superpowers:finishing-a-development-branch 決定合併 / 開 PR。

---

## Self-Review

**1. Spec coverage（對照使用者需求）：**
- 全部翻成繁中台灣用語 → Task 1–6 涵蓋 34 個翻譯單位；Task 7 確認無殘留。✓
- 用 Humanizer-zh-TW 去 AI 腔 → 準則檔「去 AI 腔規則」節（Task 0 Step 2）+ 每檔 Opus 抽查。✓
- 一字不漏、通順、不分段省略 → 準則檔「使用者硬性要求」節明列；護欄 CJK 數量檢查抓「翻太少」。✓
- 人名保原文、專有名詞中英對照 → 準則檔「保留原文」與「專有名詞中英對照」節 + 術語表。✓
- 省 token → 全部實際翻譯由 `ccg`（GLM-5.2）在獨立行程執行，Opus 只審查。✓

**2. Placeholder scan：** 每個 `ccg` 指令、驗證腳本、commit 訊息、準則檔內容均為完整可執行內容，無 TBD/TODO。✓

**3. Type/命名一致：** 全程指令引用同一路徑 `docs/superpowers/plans/_translation-contract.md` 與 `verify-translation.sh`；`lang="zh-Hant-TW"`、術語表在準則檔單一來源，各 Task 一致。✓

## 已知風險與備援
- **GLM 可能漏改 `lang` 或動到 CSS** → `verify-translation.sh` 的護欄會擋下（lang 檢查 + `<style>/<script>` 位元組比對），失敗即重跑或手動 Edit。
- **GLM 可能把該保留的程式碼識別字翻掉** → 每批 Task 的 Opus 抽查專門盯程式碼密集檔（`03`、`04`、`18`–`20`）。
- **macOS grep 無 `-P`** → Task 0 Step 5 提供 perl 版 CJK 計數備援。
