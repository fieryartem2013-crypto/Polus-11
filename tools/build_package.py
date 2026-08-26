#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_package.py — собирает снапшот-архив POLUS11_SERVER_vX.Y.Z.zip

Что кладёт:
    garrysmod/            — весь сервер (гейммод, autorun, звук, cfg)
    README.md INSTALL.md  — старые документы
    docs/                 — патчноуты, аналитики, установка
    tools/                — линтер и аудит (для разработчика)

Имена файлов пишутся в UTF-8 (флаг 0x800), чтобы русские имена не
превращались в «кракозябры» при распаковке на Windows.

Запуск:  python3 tools/build_package.py 5.8.29
"""
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

INCLUDE_DIRS = ["garrysmod", "docs", "tools"]
INCLUDE_FILES = ["README.md", "INSTALL.md"]
SKIP_DIRS = {".git", "__pycache__", ".arena", ".cache", "node_modules"}


def collect():
    out = []
    for d in INCLUDE_DIRS:
        base = os.path.join(ROOT, d)
        if not os.path.isdir(base):
            continue
        for dp, dn, fn in os.walk(base):
            dn[:] = [x for x in dn if x not in SKIP_DIRS]
            for f in sorted(fn):
                p = os.path.join(dp, f)
                out.append(os.path.relpath(p, ROOT).replace("\\", "/"))
    for f in INCLUDE_FILES:
        if os.path.exists(os.path.join(ROOT, f)):
            out.append(f)
    return sorted(out)


def build(version):
    name = "POLUS11_SERVER_v%s.zip" % version
    path = os.path.join(ROOT, name)
    files = collect()
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for rel in files:
            full = os.path.join(ROOT, rel)
            zi = zipfile.ZipInfo.from_file(full, rel)
            zi.flag_bits |= 0x800          # UTF-8 имена
            zi.compress_type = zipfile.ZIP_DEFLATED
            with open(full, "rb") as fh:
                z.writestr(zi, fh.read())
    size = os.path.getsize(path)
    print("✅ %s" % name)
    print("   файлов: %d" % len(files))
    print("   размер: %.2f МБ" % (size / 1048576))
    return path, files


if __name__ == "__main__":
    ver = sys.argv[1] if len(sys.argv) > 1 else "0.0.0"
    build(ver)
