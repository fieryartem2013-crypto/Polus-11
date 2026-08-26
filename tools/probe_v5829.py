#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
probe_v5829.py — функциональный smoke-тест пакета v5.8.29.

Не «проверил синтаксис», а реально ЗАГРУЖАЕТ сборку в движковом VM
(LuaJIT 2.1 через lupa — тот же интерпретатор, что в Garry's Mod) на заглушках
API и ДЁРГАЕТ обработчики: конвары, хуки, таймеры, чат-команды, начисления.

Запуск:  /tmp/luaenv/bin/python tools/probe_v5829.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gmod_lint as G  # noqa: E402

FAIL = []


def check(label, ok, detail=""):
    print("%s  %-50s %s" % ("PASS" if ok else "FAIL", label, detail))
    if not ok:
        FAIL.append(label)


def main():
    sv = G.order_of(os.path.join(G.GM, "init.lua"), "sv")
    sh = G.order_of(os.path.join(G.GM, "shared.lua"), "sh")
    ar = sorted(G.rel(q) for q in G.luafiles()
                if G.rel(q).startswith("lua/autorun/shared/")
                or G.rel(q).startswith("lua/autorun/server/"))
    order = ["shared.lua"] + sh + sv + [os.path.join(G.ROOT, x) for x in ar]

    L, loaded, errors, _ = G.level_load(order, "server")
    check("загрузка сервера", not errors, "%d/%d файлов" % (loaded, len(order)))
    for f, e in errors:
        print("      ", f, "->", str(e)[:160])

    # запоминаем тела нужных таймеров ДО их прогона (P11_FireTimers их снимает)
    L.execute("""
    P11T = {}
    P11T.tick = timer._t["P11.DutyAFK.Tick"] and timer._t["P11.DutyAFK.Tick"].fn
    P11T.wage = timer._t["P11.DutyWage"] and timer._t["P11.DutyWage"].fn
    """)

    # мир: игроки, хуки загрузки, все таймеры
    L.execute("P11_SpawnPlayers(3)")
    L.execute("P11_HOOK_ERR = {}")
    L.execute('hook.Run("InitPostEntity")')
    # подменяем начисление денег ДО того, как обёртки встанут поверх
    L.execute("""
    P11T.money = 0
    POLUS11.__origAdd = POLUS11.AddMoney
    POLUS11.AddMoney = function(ply, amt, reason)
        P11T.money = P11T.money + 1
        P11T.last_reason = reason
        return true
    end
    """)
    L.execute("P11_FireTimers(600)")

    errs = L.eval("table.concat(P11_HOOK_ERR, '\\n')") or ""
    errlist = [x for x in errs.split("\n") if x]
    funerrs = [x for x in errlist if "a function value" in x]
    check("нет ошибок в хуках/таймерах", not errlist, "%d шт." % len(errlist))
    for e in errlist[:8]:
        print("      ", e[:170])
    check("обёртки встают (нет «index a function value»)", not funerrs, "%d шт." % len(funerrs))

    def ev(x):
        return L.eval(x)

    # ---------- 1. ЭКСТРЕННЫЙ СБОР ----------
    check("p11_sbor зарегистрирован", bool(ev("concommand._t['p11_sbor'] ~= nil")))
    check("PlayerSay P11.SborChat зарегистрирован",
          bool(ev("hook._t.PlayerSay['P11.SborChat'] ~= nil")))
    L.execute("""
    local p1, p2, p3 = P11_FAKE_PLY(11), P11_FAKE_PLY(12), P11_FAKE_PLY(13)
    P11T.sbor_con = select(2, pcall(POLUS11.SborDeclare, p1, "тренировка"))
    P11T.n1 = #(POLUS11.Sbor.list or {})
    hook._t.PlayerSay["P11.SborChat"](p2, "!сбор тревога на станции")
    P11T.n2 = #(POLUS11.Sbor.list or {})
    P11T.reason2 = POLUS11.Sbor.list[2] and POLUS11.Sbor.list[2].reason
    hook._t.PlayerSay["P11.SborChat"](p3, "!сборка")
    P11T.n3 = #(POLUS11.Sbor.list or {})
    """)
    check("сбор объявляется из консоли", bool(ev("P11T.sbor_con")) and ev("P11T.n1") == 1,
          "в списке: %s" % ev("P11T.n1"))
    check("сбор объявляется из чата (!сбор)", ev("P11T.n2") == 2,
          "причина: «%s»" % ev("tostring(P11T.reason2)"))
    check("!сборка (крафт) НЕ уходит в сбор", ev("P11T.n3") == 2, "в списке: %s" % ev("P11T.n3"))

    # ---------- 2. КЛЮЧ ОСНОВАТЕЛЯ ----------
    check("FounderKey — строка", ev("type(P11FW.Config.FounderKey)") == "string")
    check("FounderKey — 32 символа", ev("#tostring(P11FW.Config.FounderKey)") == 32,
          "длина: %s" % ev("#tostring(P11FW.Config.FounderKey)"))
    check("ключ из публичного репо не принимается",
          bool(ev("P11FW.Config.FounderKey ~= 'АрчиславКрутойПарень2013'")))

    # ---------- 3. !ПРОФА ----------
    check("конвар p11_profa_minlevel = 2",
          ev("GetConVar('p11_profa_minlevel'):GetInt()") == 2,
          "факт: %s" % ev("GetConVar('p11_profa_minlevel'):GetInt()"))
    L.execute("""
    local chat = hook._t.PlayerSay["P11.ChatCore"]
    P11T.chat_alive = chat ~= nil
    -- обычный игрок (ранг 0)
    local p = P11_FAKE_PLY(21)
    pcall(function() chat(p, "!ПРОФА Начальник НКВД") end)
    P11T.job_user = p._nw and p._nw["P11_JobName"] or ""
    -- хелпер (ранг 2)
    local h = P11_FAKE_PLY(22)
    h.P11FW_RankId = "helper"
    pcall(function() chat(h, "!ПРОФА Дежурный по КПП") end)
    P11T.job_helper = h._nw and h._nw["P11_JobName"] or ""
    P11T.rank_helper = P11FW.GetRankLevel and P11FW.GetRankLevel(h) or -1
    """)
    check("роутер чата жив", bool(ev("P11T.chat_alive")))
    check("ранг хелпера = 2", ev("P11T.rank_helper") == 2, "факт: %s" % ev("P11T.rank_helper"))
    check("!профа от бойца (ранг 0) НЕ меняет должность",
          ev("tostring(P11T.job_user)") == "", "P11_JobName = «%s»" % ev("tostring(P11T.job_user)"))
    check("!профа от хелпера работает",
          ev("tostring(P11T.job_helper)") != "", "P11_JobName = «%s»" % ev("tostring(P11T.job_helper)"))

    # ---------- 4. ДЕЖУРСТВО / АФК ----------
    check("конвар p11_duty_afk = 240", ev("GetConVar('p11_duty_afk'):GetInt()") == 240,
          "факт: %s" % ev("GetConVar('p11_duty_afk'):GetInt()"))
    check("таймер дежурного оклада найден", bool(ev("P11T.wage ~= nil")))
    check("таймер анти-АФК найден", bool(ev("P11T.tick ~= nil")))
    L.execute("""
    -- боец на посту, не двигается: 250 тиков = 250 секунд
    local p = P11_FAKE_PLY(31)
    p._nw["P11_DutyLoc"] = "gate"
    player._all[#player._all + 1] = p
    P11T.money = 0
    P11T.wage()                       -- до АФК — оклад должен пройти
    P11T.money_before = P11T.money
    for i = 1, 250 do P11T.tick() end
    P11T.money = 0
    P11T.wage()                       -- после 250 с простоя — оклад НЕ должен пройти
    P11T.money_after = P11T.money
    """)
    check("оклад капает, пока боец не в АФК", ev("P11T.money_before") == 1,
          "начислений: %s" % ev("P11T.money_before"))
    check("оклад НЕ капает после 240 с простоя", ev("P11T.money_after") == 0,
          "начислений: %s" % ev("P11T.money_after"))

    # ---------- 5. ВЕРСИЯ / ГЕЙММОД ----------
    ver = str(ev("tostring(POLUS_BUILD)"))
    vt = tuple(int(x) for x in ver.split(".") if x.isdigit())
    check("POLUS_BUILD не ниже 5.8.29", vt >= (5, 8, 29), "факт: %s" % ver)
    check("гейммод — darkrp", "darkrp" in G.GM.replace("\\", "/"), G.GM.split("/")[-2])

    print()
    if FAIL:
        print("❌ провалено: %d — %s" % (len(FAIL), ", ".join(FAIL)))
        return 1
    print("✅ все проверки пройдены")
    return 0


if __name__ == "__main__":
    sys.exit(main())
