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
