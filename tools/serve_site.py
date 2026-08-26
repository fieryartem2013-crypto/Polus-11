#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
serve_site.py — локальная витрина сборок (меню + скачивание ZIP)

Что делает:
  1) складывает в site/pkg/ снапшот-архивы POLUS11_SERVER_v*.zip из корня репо
     и нужные документы (патчноут, аналитика, установка, правила);
  2) пишет site/pkg/packages.json — витрина читает его сама, ничего руками
     прописывать не надо;
  3) поднимает HTTP-сервер на 0.0.0.0:<порт> (по умолчанию 8765).

Запуск:  python3 tools/serve_site.py [порт]
site/pkg/ — временная папка, в git не попадает (см. .gitignore).
"""
import json
import os
import shutil
import sys
import hashlib
import http.server
import socketserver

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = os.path.join(ROOT, "site")
PKG = os.path.join(SITE, "pkg")

DOCS = [
    "docs/TZ_v5.8.30_OTCHET.md",
    "docs/PATCHNOTES_v5.8.30.md",
    "docs/PATCHNOTES_v5.8.29.md",
    "docs/ANALITIKA_POLNAYA_v5.8.29.md",
    "docs/УСТАНОВКА_DARKRP_v5.8.29.md",
    "docs/ПРАВИЛА_РАБОТЫ.md",
    "docs/PATCHNOTES_v5.8.28.md",
]


def sha256(path, limit=8):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()[:limit]


def collect():
    os.makedirs(PKG, exist_ok=True)
    for f in os.listdir(PKG):
        os.remove(os.path.join(PKG, f))

    packages = []
    for name in sorted(os.listdir(ROOT), reverse=True):
        if not (name.startswith("POLUS11_SERVER_v") and name.endswith(".zip")):
            continue
        src = os.path.join(ROOT, name)
        shutil.copy2(src, os.path.join(PKG, name))
        ver = name[len("POLUS11_SERVER_v"):-len(".zip")]
        packages.append({
            "version": ver,
            "file": "pkg/" + name,
            "size": os.path.getsize(src),
            "sha256_8": sha256(src),
            "mtime": int(os.path.getmtime(src)),
        })

    def vkey(v):
        return [int(x) if x.isdigit() else 0 for x in v.split(".")]
    packages.sort(key=lambda p: vkey(p["version"]), reverse=True)

    docs = []
    for d in DOCS:
        src = os.path.join(ROOT, d)
        if not os.path.exists(src):
            continue
        base = os.path.basename(d)
        shutil.copy2(src, os.path.join(PKG, base))
        docs.append({
            "name": base,
            "file": "pkg/" + base,
            "size": os.path.getsize(src),
            "title": base[:-3].replace("_", " "),
        })

    meta = {"packages": packages, "docs": docs,
            "gamemode": "darkrp", "gamemode_title": "DarkRP"}
    with open(os.path.join(PKG, "packages.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    return meta


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=SITE, **kw)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        self.send_header("Accept-Ranges", "bytes")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("[site] %s\n" % (fmt % args))


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    meta = collect()
    print("собрано: %d архив(ов), %d документ(ов)" % (len(meta["packages"]), len(meta["docs"])))
    for p in meta["packages"]:
        print("  - v%-8s %.2f МБ  %s" % (p["version"], p["size"] / 1048576, p["file"]))
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("0.0.0.0", port), Handler) as httpd:
        print("витрина: http://0.0.0.0:%d" % port)
        httpd.serve_forever()


if __name__ == "__main__":
    main()
