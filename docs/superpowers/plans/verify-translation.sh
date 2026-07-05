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

# 2) <style> 區塊必須與 git HEAD 版本位元組完全相同（CSS 無可譯內容，絕不可改）
#    註：<script> 允許差異，因為 JS 內可能含使用者可見字串（note/innerHTML）需翻譯。
if [[ "$f" == *.html ]]; then
  # 比較時忽略 content:"..." 字串（::before/::after 的可見文字允許翻譯）
  norm_style () { awk 'BEGIN{p=0}/<style/{p=1}{if(p)print}/<\/style>/{p=0}' | sed -E 's/content:[[:space:]]*"[^"]*"/content:"_"/g'; }
  before="$(git show "HEAD:$f" 2>/dev/null | norm_style)" || before=""
  after="$(norm_style < "$f")"
  if [[ -n "$before" && "$before" != "$after" ]]; then
    echo "  ✗ [$f] <style> 區塊結構被更動（CSS 不可翻譯，content 字串除外）"; fail=1
  fi
fi

# 2b) HTML 標籤結構必須與 git HEAD 一致（抓截斷/遺漏整段，免受散文換行影響 → 一字不漏）
if [[ "$f" == *.html ]] && headtxt="$(git show "HEAD:$f" 2>/dev/null)"; then
  tagcount () { grep -oE '<[a-zA-Z][a-zA-Z0-9]*' | sort | uniq -c; }
  hb="$(printf '%s' "$headtxt" | tagcount)"
  ab="$(tagcount < "$f")"
  if [[ -n "$hb" && "$hb" != "$ab" ]]; then
    echo "  ✗ [$f] HTML 標籤結構與原始不符，疑似遺漏或多出整段內容："
    diff <(printf '%s' "$hb") <(printf '%s' "$ab") | grep -E '^[<>]' | head -6 | sed 's/^/      /'
    fail=1
  fi
fi

# 3) 可見文字要有足夠中文：CJK 字元數應 > 50（避免整檔沒翻）
if grep -oP '[\x{4e00}-\x{9fff}]' "$f" >/dev/null 2>&1; then
  cjk=$(grep -oP '[\x{4e00}-\x{9fff}]' "$f" 2>/dev/null | wc -l | tr -d ' ')
else
  cjk=$(perl -CSD -ne 'print for /[\x{4e00}-\x{9fff}]/g' "$f" | wc -c | tr -d ' ')
fi
if [[ "${cjk:-0}" -lt 50 ]]; then
  echo "  ✗ [$f] CJK 字元只有 ${cjk:-0} 個，疑似未翻或翻太少"; fail=1
fi

# 4) 著作權行必須保留
if [[ "$f" == *.html ]] && ! grep -q 'Copyright 2026 Anthropic PBC' "$f"; then
  echo "  ✗ [$f] 著作權註解行遺失"; fail=1
fi

if [[ "$fail" == 0 ]]; then echo "  ✓ [$f] 通過護欄"; fi
exit "$fail"
