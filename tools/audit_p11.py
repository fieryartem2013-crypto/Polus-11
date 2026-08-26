#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
audit_p11.py — статический аудит сборки ПОЛЮС-11.
Ничего не меняет: только читает lua и печатает метрики.
Запуск:  python3 tools/audit_p11.py
"""
import os, re, sys, json
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "garrysmod")

def rel(p): return os.path.relpath(p, ROOT).replace("\\", "/")

LUA = []
for dp, dn, fn in os.walk(ROOT):
    for f in fn:
        if f.endswith(".lua"):
            LUA.append(os.path.join(dp, f))
LUA.sort()

SRC = {}
for p in LUA:
    SRC[p] = open(p, encoding="utf-8", errors="replace").read()

# ---------- 1. ЛОАДЕР ----------
def _find_gm():
    base = os.path.join(ROOT, "gamemodes")
    for name in ("darkrp", "polus"):
        cand = os.path.join(base, name, "gamemode")
        if os.path.isdir(cand): return cand
    raise SystemExit("не найдена папка гейммода")
GM = _find_gm()
def table_of(path, var):
    src = SRC.get(path, "")
    i = src.find("local %s = {" % var)
    if i < 0: return []
    j = src.find("{", i); k = src.find("\n}", j)
    body = src[j:k]
    # режем строковые комментарии, чтобы закомментированные модули не считались живыми
    body = re.sub(r"--[^\n]*", "", body)
    return re.findall(r'"([^"]+\.lua)"', body)

send = table_of(os.path.join(GM, "init.lua"), "send")
sv   = table_of(os.path.join(GM, "init.lua"), "sv")
sh   = table_of(os.path.join(GM, "shared.lua"), "sh")
cl   = table_of(os.path.join(GM, "cl_init.lua"), "cl")

print("=" * 72)
print("1. ЛОАДЕР ГЕЙММОДА")
print("=" * 72)
print("  send(клиенту)=%d  sv(сервер)=%d  sh(общие)=%d  cl(клиент include)=%d" % (len(send), len(sv), len(sh), len(cl)))
dl_dead = [f for f in send if f not in cl]
print("\n  Скачивается клиенту, но клиентом НЕ грузится (%d):" % len(dl_dead))
for f in dl_dead: print("     -", f)
disk = set(os.listdir(os.path.join(GM, "modules")))
orph_sv = sorted(f for f in disk if (f.startswith("p11_sv_") or f.startswith("fw_sv_")) and "modules/"+f not in sv)
orph_cl = sorted(f for f in disk if (f.startswith("p11_cl_") or f.startswith("fw_cl_")) and "modules/"+f not in cl)
orph_sh = sorted(f for f in disk if (f.startswith("p11_sh_") or f.startswith("fw_sh_")) and "modules/"+f not in sh)
print("\n  Серверные модули на диске ВНЕ sv-листа (%d):" % len(orph_sv))
for f in orph_sv: print("     -", f)
print("\n  Клиентские модули на диске ВНЕ cl-листа (%d):" % len(orph_cl))
for f in orph_cl: print("     -", f)
print("\n  Общие модули на диске ВНЕ sh-листа (%d):" % len(orph_sh))
for f in orph_sh: print("     -", f)

# ---------- 2. ХУКИ ----------
def hook_hits(name, files):
    out = []
    for p in files:
        for m in re.finditer(r'hook\.Add\(\s*"%s"' % name, SRC[p]):
            out.append((rel(p), m.start()))
    return out

live_cl = [os.path.join(GM, f) for f in cl if os.path.exists(os.path.join(GM, f))]
live_cl += [p for p in LUA if "/lua/autorun/client/" in rel(p)]
ent_cl  = [p for p in LUA if "/entities/entities/" in rel(p) and rel(p).endswith("cl_init.lua")]
dead_cl = [os.path.join(GM, "modules", f) for f in orph_cl]

live_sv = [os.path.join(GM, f) for f in sv if os.path.exists(os.path.join(GM, f))]
live_sv += [os.path.join(GM, "shared.lua"), os.path.join(GM, "init.lua")]
for f in sh:
    q = os.path.join(GM, f)
    if q in SRC: live_sv.append(q)
live_sv += [p for p in LUA if "/lua/autorun/server/" in rel(p)]
live_sv += [p for p in LUA if "/lua/autorun/shared/" in rel(p)]
ent_sv  = [p for p in LUA if "/entities/entities/" in rel(p) and rel(p).endswith("init.lua")]

print()
print("=" * 72)
print("2. ХУКИ (сколько реально живых обработчиков)")
print("=" * 72)
for h in ("HUDPaint", "Think", "PlayerSay", "InitPostEntity", "PostCleanupMap", "PlayerInitialSpawn", "HUDShouldDraw"):
    a = len(hook_hits(h, live_cl)); b = len(hook_hits(h, ent_cl)); c = len(hook_hits(h, dead_cl))
    d = len(hook_hits(h, live_sv)); e = len(hook_hits(h, ent_sv))
    print("  %-18s клиент(живые)=%-3d +энтити=%-3d | мёртвые файлы=%-3d | сервер=%-3d +энтити=%-3d" % (h, a, b, c, d, e))

# ---------- 3. NET ----------
print()
print("=" * 72)
print("3. СЕТЬ: net.Receive без проверки прав/валидности (серверная сторона)")
print("=" * 72)
svfiles = [p for p in live_sv + ent_sv if p in SRC]
pat = re.compile(r'net\.Receive\(\s*"([^"]+)"\s*,\s*function\s*\(([^)]*)\)', re.S)
bad, tot = [], 0
for p in svfiles:
    src = SRC[p]
    for m in pat.finditer(src):
        tot += 1
        name, args = m.group(1), m.group(2)
        if "ply" not in args and "pl" not in args:
            continue  # сервер-сервер (клиентский приёмник)
        body = src[m.end():m.end() + 1400]
        ok = bool(re.search(r'IsValid\(\s*(ply|pl|player)\b', body)) and bool(re.search(
            r'Admin|Rank|IsSuperAdmin|UserGroup|Config\.(Admin|CanManage)|POLUS11\.IsStaff|P11FW\.CanManage|Level', body))
        if not ok:
            bad.append((rel(p), name, "IsValid" if re.search(r'IsValid', body) else "НИЧЕГО"))
print("  всего net.Receive в серверном коде: %d ; без гейта прав: %d" % (tot, len(bad)))
for f, n, why in bad:
    print("     - %-58s %-24s (в теле: %s)" % (f, n, why))

# дубли AddNetworkString / net.Receive
addn = {}
for p in LUA:
    for m in re.finditer(r'util\.AddNetworkString\(\s*"([^"]+)"', SRC[p]):
        addn.setdefault(m.group(1), []).append(rel(p))
print("\n  net-строки, объявленные повторно (>1 AddNetworkString):")
for k, v in sorted(addn.items(), key=lambda x: -len(x[1])):
    if len(v) > 1: print("     - %-22s x%d  %s" % (k, len(v), ", ".join(sorted(set(v)))))

recv = {}
for p in LUA:
    for m in re.finditer(r'net\.Receive\(\s*"([^"]+)"', SRC[p]):
        recv.setdefault(m.group(1), []).append(rel(p))
print("\n  net.Receive на одну строку в разных файлах (последний побеждает):")
for k, v in sorted(recv.items(), key=lambda x: -len(x[1])):
    if len(v) > 1: print("     - %-22s x%d  %s" % (k, len(v), ", ".join(sorted(set(v)))))

# ---------- 4. КОНКОМАНДЫ ----------
print()
print("=" * 72)
print("4. concommand.Add БЕЗ проверки (вызывается любым игроком из консоли)")
print("=" * 72)
cnt = 0; guard = 0; open_cmds = []
for p in LUA:
    src = SRC[p]
    for m in re.finditer(r'concommand\.Add\(\s*"([^"]+)"\s*,\s*function\s*\(([^)]*)\)', src):
        cmd, args = m.group(1), m.group(2)
        cnt += 1
        body = src[m.end():m.end() + 900]
        if "ply" not in args and "pl" not in args:
            continue
        if re.search(r'IsValid\(\s*ply\s*\)|IsValid\(pl\)|Admin|Rank|SuperAdmin|UserGroup', body):
            guard += 1
        else:
            open_cmds.append((rel(p), cmd))
print("  всего concommand.Add: %d ; с проверкой прав: %d ; БЕЗ проверки: %d" % (cnt, guard, len(open_cmds)))
for f, c in open_cmds: print("     - %-58s %s" % (f, c))

# ---------- 5. ПРОИЗВОДИТЕЛЬНОСТЬ ----------
print()
print("=" * 72)
print("5. ПРОИЗВОДИТЕЛЬНОСТЬ")
print("=" * 72)
# ВАЖНО: «создание шрифта внутри HUDPaint» статически не определяется —
# грубый поиск по соседним строкам давал ЛОЖНОЕ срабатывание
# (p11_cl_mutations.lua: шрифты объявлены на уровне файла, строки 6-8 и 97-99).
# Настоящая проверка — запуском кадра: tools/gmod_lint.py, УРОВЕНЬ 4.
print("  шрифты/материалы внутри кадра: см. tools/gmod_lint.py (УРОВЕНЬ 4 — реальный прогон HUDPaint)")
short_timers = []
for p in LUA:
    for m in re.finditer(r'timer\.Create\(\s*"[^"]+"\s*,\s*([0-9.]+)', SRC[p]):
        v = float(m.group(1))
        if v and v < 1: short_timers.append((rel(p), v))
print("\n  timer.Create с интервалом < 1 c: %d" % len(short_timers))
for f, v in sorted(set(short_timers))[:20]: print("     - %-58s %.2f c" % (f, v))

# ---------- 6. ФАЙЛЫ/СЕЙВЫ ----------
print()
print("=" * 72)
print("6. СЕЙВЫ (file.Write) — частота и риск потери данных")
print("=" * 72)
fw = {}
for p in LUA:
    n = len(re.findall(r'file\.Write\(', SRC[p]))
    if n: fw[rel(p)] = n
print("  файлов с file.Write: %d ; всего вызовов: %d" % (len(fw), sum(fw.values())))
for f, n in sorted(fw.items(), key=lambda x: -x[1])[:12]: print("     - %-58s %d" % (f, n))
print("  бэкапов (file.Write в *_bak / копирование): %d" % sum(1 for p in LUA if re.search(r'_bak|backup', SRC[p], re.I)))

# ---------- 7. СЕКРЕТЫ ----------
print()
print("=" * 72)
print("7. СЕКРЕТЫ В SHARED (уходит клиентам через AddCSLuaFile)")
print("=" * 72)
for p in LUA:
    code = "\n".join(l for l in SRC[p].split("\n") if not l.strip().startswith("--"))
    for m in re.finditer(r'(FounderKey|SecretKey|Password|API[_ ]?KEY|Token)\s*=\s*"([^"]+)"', code):
        where = "SHARED (видят клиенты)" if (rel(p).startswith("gamemodes") and "/modules/" in rel(p) and ("sh_" in os.path.basename(p) or p in [os.path.join(GM, x) for x in send])) else rel(p)
        print("     - %s :: %s = %s" % (rel(p), m.group(1), m.group(2)))

# ---------- 8. РАЗМЕРЫ ----------
print()
print("=" * 72)
print("8. РАЗМЕРЫ И ГИГИЕНА")
print("=" * 72)
tot_lines = sum(SRC[p].count("\n") + 1 for p in LUA)
print("  lua-файлов: %d ; строк: %d ; КБ: %.0f" % (len(LUA), tot_lines, sum(len(SRC[p].encode()) for p in LUA) / 1024))
longest = sorted(LUA, key=lambda p: -max((len(l) for l in SRC[p].split("\n")), default=0))[:5]
for p in longest:
    mx = max((len(l) for l in SRC[p].split("\n")), default=0)
    ln = max(range(1, SRC[p].count("\n") + 2), key=lambda i: len(SRC[p].split("\n")[i-1]))
    print("     - самая длинная строка: %6d символов  %s:%d" % (mx, rel(p), ln))
top = sorted(LUA, key=lambda p: -len(SRC[p]))[:10]
print("  топ-10 по размеру:")
for p in top: print("     - %7.1f КБ  %s" % (len(SRC[p].encode()) / 1024, rel(p)))
