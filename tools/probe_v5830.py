#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
probe_v5830.py — приёмочные проверки по ТЗ (Задача 1 и Задача 2).

Загружает сборку в движковом VM (LuaJIT 2.1 через lupa) на заглушках GMod-API
и ДЁРГАЕТ реальные обработчики: P11FW.SetRank / CanManageRank для Задачи 1,
хуки Think / OnPauseMenuShow для Задачи 2.

Запуск:  /tmp/luaenv/bin/python tools/probe_v5830.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gmod_lint as G  # noqa: E402

FAIL = []


def check(label, ok, detail=""):
    print("%s  %-52s %s" % ("PASS" if ok else "FAIL", label, detail))
    if not ok:
        FAIL.append(label)


def server_runtime():
    sv = G.order_of(os.path.join(G.GM, "init.lua"), "sv")
    sh = G.order_of(os.path.join(G.GM, "shared.lua"), "sh")
    ar = sorted(G.rel(q) for q in G.luafiles()
                if G.rel(q).startswith("lua/autorun/shared/")
                or G.rel(q).startswith("lua/autorun/server/"))
    order = ["shared.lua"] + sh + sv + [os.path.join(G.ROOT, x) for x in ar]
    L, loaded, errors, _ = G.level_load(order, "server")
    L.execute("P11_SpawnPlayers(4)")
    L.execute("P11_HOOK_ERR = {}")
    L.execute('hook.Run("InitPostEntity")')
    L.execute("P11_FireTimers(600)")
    return L, loaded, errors, len(order)


def client_runtime():
    sh = G.order_of(os.path.join(G.GM, "shared.lua"), "sh")
    cl = G.order_of(os.path.join(G.GM, "cl_init.lua"), "cl", base="cl_init.lua")
    ar = sorted(G.rel(q) for q in G.luafiles()
                if G.rel(q).startswith("lua/autorun/shared/")) + \
         sorted(G.rel(q) for q in G.luafiles()
                if G.rel(q).startswith("lua/autorun/client/"))
    order = ["cl_init.lua"] + sh + cl + [os.path.join(G.ROOT, x) for x in ar]
    L, loaded, errors, _ = G.level_load(order, "client")
    L.execute("P11_LOCAL = P11_FAKE_PLY(1)")
    L.execute("P11_HOOK_ERR = {}")
    L.execute('hook.Run("PostGamemodeLoaded")')
    L.execute('hook.Run("InitPostEntity")')
    L.execute("P11_FireTimers(600)")
    return L, loaded, errors, len(order)


# ============================================================ ЗАДАЧА 1
def task1():
    print("=" * 78)
    print("ЗАДАЧА 1. Staff Leader не выдаёт «Administrator»")
    print("=" * 78)
    L, loaded, errors, total = server_runtime()
    check("сервер загрузился", not errors, "%d/%d файлов" % (loaded, total))
    for f, e in errors:
        print("      ", f, "->", str(e)[:150])

    def ev(x):
        return L.eval(x)

    errs = ev("table.concat(P11_HOOK_ERR, '\\n')") or ""
    check("нет ошибок в хуках/таймерах", errs == "", "%d шт." % len([x for x in errs.split("\n") if x]))

    # конфиг прав
    L.execute("""
    P11T = {}
    P11T.allow = P11FW.RankGate.allow.staff_leader
    P11T.deny_admin = P11FW.RankGate.deny.staff_leader["admin"] == true
    P11T.minlvl = P11FW.RankGate.min_level["admin"]
    P11T.cfg_file = file.Exists("polus_framework/rank_grant.json", "DATA")
    """)
    n_allow = ev("#P11T.allow")
    check("список разрешённых рангов — из конфига, не из кода",
          bool(ev("P11T.cfg_file")) and n_allow >= 6,
          "файл: %s, рангов: %d" % (ev("tostring(P11T.cfg_file)"), n_allow))
    check("«Administrator» в жёстком deny", bool(ev("P11T.deny_admin")))
    check("min_level для admin = 13 (верхний эшелон)", ev("P11T.minlvl") == 13,
          "факт: %s" % ev("tostring(P11T.minlvl)"))

    # игроки: staff_leader (14), цель, главный админ (5)
    L.execute("""
    local sl = P11_FAKE_PLY(51)
    sl.P11FW_RankId = "staff_leader"
    local target = P11_FAKE_PLY(52)
    local head = P11_FAKE_PLY(53)
    head.P11FW_RankId = "head_admin"
    P11T.sl, P11T.target, P11T.head = sl, target, head
    P11T.sl_level = P11FW.GetRankLevel(sl)
    """)
    check("ранг Staff Leader = 14", ev("P11T.sl_level") == 14, "факт: %s" % ev("P11T.sl_level"))

    # --- попытка выдать Administrator ---
    L.execute("""
    file.Write("polus_framework/rank_grant.log", "")
    local ok, err = P11FW.SetRank(P11T.target, "admin", P11T.sl)
    P11T.grant_ok, P11T.grant_err = ok, err
    P11T.applied = P11FW.RankData[P11T.target:SteamID()]
    P11T.log = file.Read("polus_framework/rank_grant.log", "DATA") or ""
    """)
    check("выдача «Administrator» ЗАБЛОКИРОВАНА", ev("P11T.grant_ok") is False,
          "вернул: %s" % ev("tostring(P11T.grant_ok)"))
    check("сообщение «У вас нет прав для выдачи этого ранга»",
          "нет прав" in str(ev("tostring(P11T.grant_err)")), str(ev("tostring(P11T.grant_err)")))
    check("ранг НЕ применился", ev("tostring(P11T.applied)") != "admin",
          "в базе: %s" % ev("tostring(P11T.applied)"))
    log = str(ev("P11T.log"))
    check("запись в логе: DENY", "DENY" in log)
    check("в логе есть SteamID нарушителя", "STEAM_" in log)
    check("в логе есть запрашиваемый ранг", "'admin'" in log)
    check("в логе есть дата и время", len(log.split("]")[0]) >= 12 and "-" in log.split("]")[0],
          log.split("\n")[0][:60] if log else "")

    # --- обход через правку конфига ---
    L.execute("""
    P11FW.RankGate.allow.staff_leader = { "user", "admin" }   -- «кто-то дописал»
    local ok2 = P11FW.SetRank(P11T.target, "admin", P11T.sl)
    P11T.bypass = ok2
    """)
    check("обход правкой allow НЕ работает", ev("P11T.bypass") is False)
    L.execute("concommand._t['p11_rankgate_reload'](nil, 'p11_rankgate_reload', {})")

    # --- ранг вне списка ---
    L.execute("P11T.dev = select(1, P11FW.SetRank(P11T.target, 'developer', P11T.sl))")
    check("ранг вне белого списка отклонён", ev("P11T.dev") is False)

    # --- старшие ранги ---
    L.execute("""
    local cur = P11_FAKE_PLY(54); cur.P11FW_RankId = "curator"          -- 12
    local chief = P11_FAKE_PLY(55); chief.P11FW_RankId = "chief_curator" -- 13
    P11T.sl_manage4 = P11FW.CanManageRank(P11T.sl, 4)
    P11T.sl_manage3 = P11FW.CanManageRank(P11T.sl, 3)
    P11T.curator_admin = P11FW.SetRank(P11T.target, "admin", cur)
    P11T.chief_admin = P11FW.SetRank(P11T.target, "admin", chief)
    """)
    check("Staff Leader не менеджит уровень Administrator (4)", ev("P11T.sl_manage4") is False)
    check("Staff Leader менеджит уровень 3", bool(ev("P11T.sl_manage3")))
    check("Куратор (12) выдать «admin» НЕ может", ev("P11T.curator_admin") is False)
    check("Chief Curator (13) выдать «admin» может", bool(ev("P11T.chief_admin")))

    # --- системная выдача (донат) не ломается ---
    L.execute("P11T.sys = P11FW.SetRank(P11T.target, 'vip', nil)")
    check("системная выдача (by = nil, донат/промо) работает", bool(ev("P11T.sys")))


# ============================================================ ЗАДАЧА 2
def task2():
    print()
    print("=" * 78)
    print("ЗАДАЧА 2. Esc в E-меню возвращает управление")
    print("=" * 78)
    L, loaded, errors, total = client_runtime()
    check("клиент загрузился", not errors, "%d/%d файлов" % (loaded, total))
    for f, e in errors:
        print("      ", f, "->", str(e)[:150])

    def ev(x):
        return L.eval(x)

    check("сторож v5.8.30 зарегистрирован",
          bool(ev("hook._t.Think['P11.EscFix2.Watchdog.v5830'] ~= nil")))
    check("хук меню паузы v5.8.30 зарегистрирован",
          bool(ev("hook._t.OnPauseMenuShow['P11.EscFix2.Pause.v5830'] ~= nil")))
    check("блокиратор меню паузы от v5.8.28 снят",
          bool(ev("hook.GetTable().OnPauseMenuShow['P11.EscFix.v5828'] == nil")))

    # --- сценарий: E-меню открыто ---
    L.execute("P11T = {}")
    L.execute("""
    P11_UI.kids = {}
    P11_UI.cursor = true
    P11_UI.gameui = false
    P11_UI.console = false
    P11_UI.clicker = 0
    local p = { ClassName = "DPanel", __valid = true }
    p.IsVisible = function() return true end
    p.IsMouseInputEnabled = function() return true end
    p.GetSize = function() return ScrW(), ScrH() end
    p.Remove = function(self) self.__valid = false end
    P11T_overlay = p
    P11_UI.kids[1] = p
    hook._t.Think["P11.EscFix2.Watchdog.v5830"]()
    P11T.guarded = rawget(p, "P11_EscGuard") == true
    P11T.clicker_open = P11_UI.clicker
    """)
    check("подложка E-меню распознана, Esc-страховка навешена", bool(ev("P11T.guarded")))

    # --- Esc: меню закрылось (панель удалена), курсор остался ---
    L.execute("""
    P11_UI.clicker = 0
    P11T_overlay:Remove()
    P11_UI.kids = {}
    hook._t.Think["P11.EscFix2.Watchdog.v5830"]()
    P11T.clicker_after_close = P11_UI.clicker
    P11T.clicker_value = P11_UI.clicker_last
    P11T.keys = table.concat(P11_UI.concommands, ",")
    """)
    check("после закрытия меню курсор отпущен",
          ev("P11T.clicker_after_close") >= 1 and ev("P11T.clicker_value") is False,
          "вызовов EnableScreenClicker: %s (значение %s)"
          % (ev("P11T.clicker_after_close"), ev("tostring(P11T.clicker_value)")))
    check("залипшие кнопки отпущены (-attack/-use)",
          "-attack" in str(ev("P11T.keys")), str(ev("P11T.keys"))[:60])

    # --- Esc напрямую по панели ---
    L.execute("""
    local p2 = { ClassName = "DPanel", __valid = true }
    p2.IsVisible = function() return true end
    p2.IsMouseInputEnabled = function() return true end
    p2.GetSize = function() return ScrW(), ScrH() end
    p2.Remove = function(self) self.__valid = false end
    local closed = false
    p2.OnKeyCodePressed = function(s, key) if key == KEY_ESCAPE then closed = true end end
    P11_UI.kids = { p2 }
    P11_UI.cursor = true
    P11_UI.clicker = 0
    hook._t.Think["P11.EscFix2.Watchdog.v5830"]()   -- сторож навесит свой обработчик
    p2:OnKeyCodePressed(KEY_ESCAPE)
    P11T.esc_closed = closed
    P11T.esc_unlock = P11_UI.clicker
    """)
    check("штатный обработчик Esc не сломан", bool(ev("P11T.esc_closed")))
    check("Esc сразу возвращает ввод", ev("P11T.esc_unlock") >= 1,
          "вызовов: %s" % ev("P11T.esc_unlock"))

    # --- залипший курсор без панелей ---
    L.execute("""
    P11_UI.kids = {}
    P11_UI.cursor = true
    P11_UI.gameui = false
    P11_UI.console = false
    P11_UI.clicker = 0
    hook._t.Think["P11.EscFix2.Watchdog.v5830"]()
    P11T.stuck = P11_UI.clicker
    """)
    check("залипший курсор без панелей отпускается", ev("P11T.stuck") >= 1)

    # --- меню паузы не блокируется ---
    L.execute("""
    P11T.pause_ret = hook.Call("OnPauseMenuShow")
    """)
    check("меню паузы НЕ блокируется (Alt+F4 не единственный выход)",
          ev("P11T.pause_ret") is None, "вернул: %s" % ev("tostring(P11T.pause_ret)"))

    # --- живой DFrame (админка/F4) не сносится ---
    L.execute("""
    local fr = { ClassName = "DFrame", __valid = true }
    fr.IsVisible = function() return true end
    fr.IsMouseInputEnabled = function() return true end
    fr.GetSize = function() return ScrW(), ScrH() end
    fr.SetTitle = function() end
    P11_UI.kids = { fr }
    P11_UI.cursor = true
    P11_UI.clicker = 0
    hook._t.Think["P11.EscFix2.Watchdog.v5830"]()
    P11T.frame_alive = fr.__valid
    P11T.frame_clicker = P11_UI.clicker
    """)
    check("полноэкранный DFrame (админка/F4) не трогается",
          ev("P11T.frame_alive") is True and ev("P11T.frame_clicker") == 0)


if __name__ == "__main__":
    task1()
    task2()
    print()
    if FAIL:
        print("❌ провалено: %d — %s" % (len(FAIL), ", ".join(FAIL)))
        sys.exit(1)
    print("✅ все проверки по ТЗ пройдены")
    sys.exit(0)
