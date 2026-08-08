-- ============================================================
--  ПОЛЮС-11 — МАЯКИ СТАНЦИИ «GPS-ПРИБОР» (client)
--  v4.12.2 «ЭФИР». Заявка владельца: «вижу отметки сейфа/
--  терминала/кадровика — убери это в GPS в C-меню».
--
--  КАК ТЕПЕРЬ:
--   • по умолчанию мир ЧИСТЫЙ — никаких постоянных отметок;
--   • навигация живёт в 📱 C-МЕНЮ → «🧭 GPS-КУРС» (или консоль
--     p11_gps): список точек станции → клик «КУРС» — ведёт ОДИН
--     маяк к выбранной точке (маячит до прибытия на 14 м);
--   • кому нужны ВСЕ маяки как раньше — консоль p11_poi (тумблер)
--     или p11_poi 1. Выбор «все маяки» НЕ запоминается (чистота).
-- ============================================================

surface.CreateFont("P11POI.Text", { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("P11POI.Small", { font = "Roboto", size = 12, weight = 500, extended = true })

-- «все маяки» — только по требованию и только до конца сессии (не архив!)
local cvAll = CreateClientConVar("p11_poi_all", "0", false, false)

concommand.Add("p11_poi", function(_, _, args)
    local a = tostring(args and args[1] or "")
    local want
    if a == "" then
        want = not cvAll:GetBool()
    else
        want = (a == "1" or a == "true" or a == "on" or a == "вкл" or a == "да")
    end
    RunConsoleCommand("p11_poi_all", want and "1" or "0") -- конвар отдельный — рекурсии нет
    chat.AddText(Color(255, 210, 110), "[GPS] ", Color(235, 240, 250),
        "Все маяки точек станции: " .. (want and "ВКЛ (до перезахода; наводка удобнее — C → 🧭 GPS-КУРС)" or "ВЫКЛ."))
end, nil, "Все маяки станции: без аргумента — переключить, 1 — вкл, 0 — выкл (по умолчанию выкл, v4.12.2)")

-- класс → { подпись, цвет, [ready] } (ready=true → маячит только ПОЛНАЯ лутница)
local POI = {
    polus_p11_shopnpc  = { lbl = "🏪 ЛАРЁК",        col = Color(255, 200, 90)  },
    polus_fw_jobnpc    = { lbl = "🧑 КАДРОВИК",     col = Color(255, 210, 110) },
    polus11_avtosalon  = { lbl = "🚗 ГАРАЖ",        col = Color(255, 175, 90)  },
    polus11_terminal   = { lbl = "🖥 ТЕРМИНАЛ",     col = Color(150, 220, 255) },
    polus11_bloodlab   = { lbl = "🩸 АНАЛИЗ КРОВИ", col = Color(255, 140, 140) },
    polus11_labtable   = { lbl = "🧪 ЛАБОРАТОРИЯ",  col = Color(170, 200, 255) },
    polus_p11_storage  = { lbl = "🗄 СЕЙФ",         col = Color(190, 190, 210) },
    polus_p11_kitchen  = { lbl = "🍲 КУХНЯ",        col = Color(255, 180, 120) },
    polus_p11_supply   = { lbl = "📦 СНАБЖЕНИЕ",    col = Color(200, 220, 170) },
    polus_p11_patrol   = { lbl = "🚩 ПОСТ ПАТРУЛЯ", col = Color(160, 200, 160) },
    -- v4.11.0+ «КУЗНЯ»/«ОТБОЙ»: верстак всегда; лутницы — только ПОЛНЫЕ
    polus11_crafttable = { lbl = "🛠 ВЕРСТАК",      col = Color(185, 220, 255) },
    polus11_lootcrate  = { lbl = "📦 ЯЩИК ЛОМА",    col = Color(215, 195, 140), ready = true },
    polus11_lootbarrel = { lbl = "🛢 ТОПЛ. БОЧКА",  col = Color(205, 175, 95),  ready = true },
    polus11_lootcache  = { lbl = "💼 ТАЙНИК",       col = Color(255, 150, 150), ready = true },
    polus11_lootmed    = { lbl = "💊 МЕДШКАФ",      col = Color(170, 235, 210), ready = true },
    polus11_lootmil    = { lbl = "🔫 БОЕВОЙ ЯЩИК",  col = Color(215, 170, 110), ready = true },
    polus11_loottech   = { lbl = "⚙ ГРУДА ЛОМА",    col = Color(200, 200, 205), ready = true },
    -- v4.15.0 «УГЛИ»
    polus11_lootfood   = { lbl = "🥫 ПРОД. ЯЩИК",    col = Color(235, 215, 140), ready = true },
    polus11_lootarm    = { lbl = "🪖 АРМ. КОНТЕЙНЕР", col = Color(190, 225, 170), ready = true },
    polus11_hearth     = { lbl = "🔥 УГЛИ",           col = Color(255, 170, 90) },
    polus11_cappoint   = { lbl = "🚩 ТОЧКА ЗАХВАТА",   col = Color(235, 140, 90) },
}

-- gps-состояние (общее с меню): цель наводки
P11POI = P11POI or {}
P11POI.GpsEnt = nil

-- найти ВСЕ точки станции (для режима «все маяки» и для списка GPS-меню)
local cache = {}
local nextScan = 0

local function ScanPOI(noLimit)
    cache = {}
    local me = LocalPlayer()
    if not IsValid(me) then return end
    for cls, def in pairs(POI) do
        local found = ents.FindByClass(cls)
        for _, e in ipairs(found) do
            if IsValid(e) then
                local full = true
                if def.ready and e.GetLootReadyAt then
                    full = (e:GetLootReadyAt() or 0) <= CurTime()
                end
                if full then
                    cache[#cache + 1] = { ent = e, def = def }
                end
            end
        end
    end
    table.sort(cache, function(a, b)
        local da = IsValid(a.ent) and a.ent:GetPos():DistToSqr(me:GetPos()) or math.huge
        local db = IsValid(b.ent) and b.ent:GetPos():DistToSqr(me:GetPos()) or math.huge
        return da < db
    end)
    if not noLimit then
        while #cache > 8 do table.remove(cache) end
    end
end

-- ============ НАВОДКА (API для C-меню/GPS-окна) ============

function P11POI.GpsClear(quiet)
    P11POI.GpsEnt = nil
    if not quiet then
        chat.AddText(Color(255, 210, 110), "[GPS] ", Color(235, 240, 250), "Наводка снята.")
    end
end

function P11POI.GpsTo(e, lbl)
    if not (IsValid(e) and e.GetPos) then return end
    P11POI.GpsEnt = e
    surface.PlaySound("buttons/button15.wav")
    chat.AddText(Color(255, 210, 110), "[GPS] ", Color(235, 240, 250),
        "Курс: " .. tostring(lbl or "точка") .. " — следуй за маяком. Прибудешь на 14 м — снимется сам. Снять: C → 🧭 GPS-КУРС → СТОП.")
end

-- ============ HUD: маяки ============

local function DrawBeacon(e, lbl, col, big)
    local me = LocalPlayer()
    if not IsValid(me) or not IsValid(e) then return end
    local pos = e:GetPos() + Vector(0, 0, 46)
    local dist = me:GetPos():Distance(e:GetPos())
    local scr = pos:ToScreen()
    local meters = math.max(1, math.Round(dist / 52))

    if scr.visible then
        local a = dist < 1300 and 255 or math.max(90, 255 - (dist - 1300) / 8)
        draw.SimpleTextOutlined(lbl, "P11POI.Text", scr.x, scr.y,
            Color(col.r, col.g, col.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, a * 0.8))
        draw.SimpleTextOutlined(meters .. " м", "P11POI.Small", scr.x, scr.y + 18,
            Color(235, 240, 250, a * 0.9), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, a * 0.7))
    elseif big then
        -- курс за спиной/сбоку: чип у края экрана со стрелкой направления
        local sw, sh = ScrW(), ScrH()
        local dir = (e:GetPos() - me:EyePos()):Angle()
        local rel = math.NormalizeAngle((dir - me:EyeAngles()).y)
        local side = (rel > 0) and sw - 110 or 110
        draw.RoundedBox(8, side - 90, sh * 0.5 - 14, 180, 28, Color(10, 12, 16, 200))
        draw.SimpleTextOutlined((rel > 0 and "» " or "« ") .. lbl .. " · " .. meters .. " м",
            "P11POI.Small", side, sh * 0.5, Color(col.r, col.g, col.b, 240),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 180))
    end
end

hook.Add("HUDPaint", "P11.POIBeacons", function()
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    if vgui.CursorVisible() then return end -- не путаемся под окнами
    local now = CurTime()

    -- 1) GPS-наводка (работает даже при выключенных общих маяках)
    local tgt = P11POI.GpsEnt
    if IsValid(tgt) then
        -- цель лутница опустела → курс бессмыслен
        local cls = tgt:GetClass()
        local def = POI[cls]
        local lbl = (def and def.lbl) or "ТОЧКА"
        local col = (def and def.col) or Color(255, 210, 110)
        if def and def.ready and tgt.GetLootReadyAt and (tgt:GetLootReadyAt() or 0) > now then
            P11POI.GpsClear(true)
            chat.AddText(Color(255, 210, 110), "[GPS] ", Color(235, 240, 250),
                "Цель пуста — наводка снята. Ищи другую через C → 🧭 GPS-КУРС.")
            tgt = nil
        else
            local dist = me:GetPos():Distance(tgt:GetPos())
            if dist < 14 * 52 then
                P11POI.GpsClear(true)
                surface.PlaySound("buttons/button24.wav")
                chat.AddText(Color(255, 210, 110), "[GPS] ", Color(140, 235, 150),
                    "ПРИБЫЛ: " .. lbl .. ". Курс снят.")
                tgt = nil
            else
                DrawBeacon(tgt, "🧭 " .. lbl, col, true)
            end
        end
    end

    -- 2) все маяки — только если игрок включил (p11_poi)
    if not cvAll:GetBool() then return end
    if now >= nextScan then
        nextScan = now + 0.7
        ScanPOI(false)
    end
    for _, it in ipairs(cache) do
        if IsValid(it.ent) then
            DrawBeacon(it.ent, it.def.lbl, it.def.col, false)
        end
    end
end)

-- ============ GPS-МЕНЮ (список точек → КУРС) ============

P11POI.GpsFrame = P11POI.GpsFrame or nil

local function GpsClose()
    if IsValid(P11POI.GpsFrame) then P11POI.GpsFrame:Remove() P11POI.GpsFrame = nil end
end

function P11POI.GpsOpen()
    GpsClose()
    ScanPOI(true) -- полный список, без отсева по 8

    local f = vgui.Create("DFrame")
    P11POI.GpsFrame = f
    f:SetSize(420, 520)
    f:Center()
    f:SetTitle("")
    f:SetDraggable(true)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false)
    f.btnMaxim:SetVisible(false)
    f.btnMinim:SetVisible(false)
    f.OnRemove = function() if P11POI.GpsFrame == f then P11POI.GpsFrame = nil end end
    f.OnKeyCodePressed = function(_, key) if key == KEY_ESCAPE then f:Remove() end end

    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, SysTime())
        draw.RoundedBox(10, 0, 0, w, h, Color(12, 12, 16, 246))
        draw.RoundedBoxEx(10, 0, 0, w, 56, Color(22, 24, 30, 255), true, true, false, false)
        surface.SetDrawColor(Color(100, 110, 130, 140)) surface.DrawRect(0, 56, w, 1)
        draw.SimpleText("🧭 GPS-КУРС СТАНЦИИ", "P11POI.Text", 14, 20, Color(255, 200, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("клик по точке — курс до неё; мир без маяков остаётся чистым", "P11POI.Small", 14, 40, Color(152, 160, 176), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local xb = vgui.Create("DButton", f)
    xb:SetPos(420 - 34, 12) xb:SetSize(24, 22) xb:SetText("")
    xb.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(120, 44, 40) or Color(50, 34, 32))
        draw.SimpleText("✕", "P11POI.Small", w / 2, h / 2 - 1, Color(240, 210, 205), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    xb.DoClick = function() f:Remove() end

    -- верхний ряд действий: стоп-наводка / обновить список
    local stop = vgui.Create("DButton", f)
    stop:SetPos(12, 64) stop:SetSize(190, 28) stop:SetText("")
    stop.Paint = function(s, w, h)
        local on = IsValid(P11POI.GpsEnt)
        draw.RoundedBox(6, 0, 0, w, h, on and (s:IsHovered() and Color(120, 50, 44) or Color(70, 38, 34)) or Color(34, 36, 44, 180))
        draw.SimpleText(on and "■ СТОП НАВОДКА" or "наводка не ведётся", "P11POI.Small", w / 2, h / 2,
            on and Color(255, 160, 150) or Color(120, 126, 140), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    stop.DoClick = function() P11POI.GpsClear() end

    local ref = vgui.Create("DButton", f)
    ref:SetPos(210, 64) ref:SetSize(198, 28) ref:SetText("")
    ref.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(44, 52, 64) or Color(30, 34, 42))
        draw.SimpleText("⟳ ОБНОВИТЬ СПИСОК", "P11POI.Small", w / 2, h / 2, Color(150, 220, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    ref.DoClick = function() P11POI.GpsOpen() end

    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(12, 100) sc:SetSize(396, 408)
    sc:GetVBar():SetWide(5)

    local me = LocalPlayer()
    local myPos = IsValid(me) and me:GetPos() or vector_origin
    if #cache == 0 then
        local l = sc:Add("DLabel")
        l:SetFont("P11POI.Small") l:SetTextColor(Color(152, 160, 176))
        l:SetText("  Точек пока нет: админ ставит их из C → 📍 «Поставить» (ларёк, сейф, верстак, ящики…).")
        l:SizeToContents()
    end

    for _, it in ipairs(cache) do
        if IsValid(it.ent) then
            local dist = myPos:Distance(it.ent:GetPos())
            local meters = math.max(1, math.Round(dist / 52))
            local card = sc:Add("DButton")
            card:Dock(TOP) card:DockMargin(0, 0, 0, 5) card:SetTall(40)
            card:SetText("")
            local col = it.def.col
            local lbl = it.def.lbl
            card.Paint = function(s, w, h)
                local hov = s:IsHovered()
                local cur = (P11POI.GpsEnt == it.ent)
                draw.RoundedBox(7, 0, 0, w, h, cur and Color(40, 44, 54) or (hov and Color(32, 35, 44) or Color(24, 26, 33, 220)))
                surface.SetDrawColor(col.r, col.g, col.b, cur and 220 or (hov and 170 or 90))
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText(lbl, "P11POI.Text", 12, h / 2, Color(col.r, col.g, col.b, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(meters .. " м", "P11POI.Small", w - 12, h / 2, Color(200, 208, 220), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
            card.DoClick = function()
                P11POI.GpsTo(it.ent, lbl)
                GpsClose()
            end
        end
    end

    surface.PlaySound("ui/buttonclick.wav")
end

-- консольная дверь GPS
concommand.Add("p11_gps", function()
    P11POI.GpsOpen()
end, nil, "GPS-КУРС станции: список точек и наводка (v4.12.2)")

print("[P11POI] v4.12.2 «ЭФИР» OK — мир чист по умолчанию; курс: C-меню → 🧭 GPS-КУРС (или p11_gps); все маяки: p11_poi 1")
