"""粗糙但有用的静态检查：plist 是否合法、Swift 括号是否平衡、常见拼写。"""

import os
import re
import sys
import xml.dom.minidom

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
errors = []

plist = os.path.join(ROOT, "PocketDeck", "Info.plist")
try:
    xml.dom.minidom.parse(plist)
    print("[ok] Info.plist 是合法 XML")
except Exception as exc:  # noqa: BLE001
    errors.append(f"Info.plist 解析失败: {exc}")


def strip_code(src: str) -> str:
    out = []
    i = 0
    n = len(src)
    in_line_comment = False
    in_block = False
    in_string = False
    while i < n:
        two = src[i:i + 2]
        ch = src[i]
        if in_line_comment:
            if ch == "\n":
                in_line_comment = False
                out.append(ch)
            i += 1
            continue
        if in_block:
            if two == "*/":
                in_block = False
                i += 2
                continue
            i += 1
            continue
        if in_string:
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                in_string = False
            i += 1
            continue
        if two == "//":
            in_line_comment = True
            i += 2
            continue
        if two == "/*":
            in_block = True
            i += 2
            continue
        if ch == '"':
            in_string = True
            i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


swift_files = []
for base, _dirs, files in os.walk(os.path.join(ROOT, "PocketDeck")):
    for name in files:
        if name.endswith(".swift"):
            swift_files.append(os.path.join(base, name))

pairs = {"{": "}", "(": ")", "[": "]"}
for path in sorted(swift_files):
    src = open(path, encoding="utf-8").read()
    code = strip_code(src)
    stack = []
    for pos, ch in enumerate(code):
        if ch in pairs:
            stack.append((ch, pos))
        elif ch in pairs.values():
            if not stack:
                errors.append(f"{os.path.basename(path)}: 多余的 '{ch}'")
                break
            opener, _ = stack.pop()
            if pairs[opener] != ch:
                errors.append(f"{os.path.basename(path)}: '{opener}' 与 '{ch}' 不匹配")
                break
    if stack:
        opener, _ = stack[-1]
        errors.append(f"{os.path.basename(path)}: 有 {len(stack)} 个未闭合的 '{opener}'")
    rel = os.path.relpath(path, ROOT)
    print(f"[{'ok' if not stack else '??'}] {rel}  ({len(src.splitlines())} 行)")

# 常见笔误
suspicious = ["self?.model.", "model.reportScreen(", "windowExternalDisplayNonInteractive"]
all_src = "\n".join(open(p, encoding="utf-8").read() for p in swift_files)
for token in suspicious:
    print(f"[info] {token} 出现 {all_src.count(token)} 次")

if errors:
    print("\n发现问题：")
    for e in errors:
        print(" -", e)
    sys.exit(1)

print("\n全部检查通过")
