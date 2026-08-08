-- ============================================================
--  ПОЛЮС-11 — МАЯКИ СТАНЦИИ «КУДА ИДТИ» (client)
--  v4.10.0 «ГАРАЖ». Заявка владельца: «непонятно куда идти
--  и что делать, карта большая и пустая».
--  Подписи-маяки над ключевыми точками станции (ларёк, кадровик,
--  ГАРАЖ, генератор, сейф, кухня, лаборатория…) с расстоянием
--  в метрах — видно сквозь метель и стены (ближайшие 8 по дуге).
--  Включено по умолчанию: консоль p11_poi (0/1) или p11_poi без
--  аргумента — переключить. Настройка запоминается.
-- ============================================================

surface.CreateFont("P11POI.Text", { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("P11POI.Small", { font = "Roboto", size = 12, weight = 500, extended = true })

local cv = CreateClientConVar("p11_poi_show", "1", true, false)

concommand.Add("p11_poi", function(_, _, args)
    local a = tostring(args and args[1] or "")
    local want
    if a == "" then
        want = not cv:GetBool()
    else
        want = (a == "1" or a == "true" or a == "on" or a == "вкл" or a == "да")
    end
    RunConsoleCommand("p11_poi_show", want and "1" or "0") -- конвар отдельный — рекурсии нет
    chat.AddText(Color(255, 210, 110), "[МАЯКИ] ", Color(235, 240, 250),
        "Подписи точек станции: " .. (want and "ВКЛ (ларёк/кадровик/гараж/генератор…)" or "ВЫКЛ."))
end, nil, "Маяки станции «куда идти»: без аргумента — переключить, 1 — вкл, 0 — выкл")

-- класс → { подпись, цвет }
local POI = {
    polus_p11_shopnpc  = { lbl = "🏪 ЛАРЁК",        col = Color(255, 200, 90)  },
    polus_fw_jobnpc    = { lbl = "🧑 КАДРОВИК",     col = Color(255, 210, 110) },
    polus11_avtosalon  = { lbl = "🚗 ГАРАЖ",        col = Color(255, 175, 90)  },
    polus11_generator  = { lbl = "⚡ ГЕНЕРАТОР",    col = Color(255, 230, 120) },
    polus11_terminal   = { lbl = "🖥 ТЕРМИНАЛ",     col = Color(150, 220, 255) },
    polus11_bloodlab   = { lbl = "🩸 АНАЛИЗ КРОВИ", col = Color(255, 140, 140) },
    polus11_labtable   = { lbl = "🧪 ЛАБОРАТОРИЯ",  col = Color(170, 200, 255) },
    polus_p11_storage  = { lbl = "🗄 СЕЙФ",         col = Color(190, 190, 210) },
    polus_p11_kitchen  = { lbl = "🍲 КУХНЯ",        col = Color(255, 180, 120) },
    polus_p11_supply   = { lbl = "📦 СНАБЖЕНИЕ",    col = Color(200, 220, 170) },
    polus_p11_patrol   = { lbl = "🚩 ПОСТ ПАТРУЛЯ", col = Color(160, 200, 160) },
    -- v4.11.0 «КУЗНЯ»: верстак всегда маячит; лутницы — только ПОЛНЫЕ (ready=true)
    polus11_crafttable = { lbl = "🛠 ВЕРСТАК",      col = Color(185, 220, 255) },
    polus11_lootcrate  = { lbl = "📦 ЯЩИК ЛОМА",    col = Color(215, 195, 140), ready = true },
    polus11_lootbarrel = { lbl = "🛢 ТОПЛИВНАЯ БОЧКА", col = Color(205, 175, 95), ready = true },
    polus11_lootcache  = { lbl = "💼 ТАЙНИК",       col = Color(255, 150, 150), ready = true },
}

-- кэш найденных точек (пересчёт раз в ~0.7 сек — карта большая)
local cache = {}
local nextScan = 0

local function ScanPOI()
    cache = {}
    local me = LocalPlayer()
    if not IsValid(me) then return end
    for cls, def in pairs(POI) do
        for _, e in ipairs(ents.FindByClass(cls)) do
            if IsValid(e) then
                -- v4.11.0 «КУЗНЯ»: пустая лутница маяком НЕ светит (вернётся при пополнении)
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
    -- сортировка по близости, оставляем 8 ближайших (шум не глушит картинку)
    table.sort(cache, function(a, b)
        local da = IsValid(a.ent) and a.ent:GetPos():DistToSqr(me:GetPos()) or math.huge
        local db = IsValid(b.ent) and b.ent:GetPos():DistToSqr(me:GetPos()) or math.huge
        return da < db
    end)
    while #cache > 8 do table.remove(cache) end
end

hook.Add("HUDPaint", "P11.POIBeacons", function()
    if not cv:GetBool() then return end
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    -- маяки прячем во время любого открытого окна станции — не мешают
    if vgui.CursorVisible() then return end

    local now = CurTime()
    if now >= nextScan then
        nextScan = now + 0.7
        ScanPOI()
    end

    local myPos = me:GetPos()
    local sw, sh = ScrW(), ScrH()
    local pulse = 0.7 + math.sin(now * 3.2) * 0.3

    for _, it in ipairs(cache) do
        local e = it.ent
        if IsValid(e) then
            local pos = e:GetPos() + Vector(0, 0, 46)
            local dist = myPos:Distance(e:GetPos())
            local scr = pos:ToScreen()
            local col = it.def.col
            local meters = math.max(1, math.Round(dist / 52))

            if scr.visible then
                local a = dist < 1300 and 255 or math.max(90, 255 - (dist - 1300) / 8)
                draw.SimpleTextOutlined(it.def.lbl, "P11POI.Text", scr.x, scr.y,
                    Color(col.r, col.g, col.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, a * 0.8))
                draw.SimpleTextOutlined(meters .. " м", "P11POI.Small", scr.x, scr.y + 18,
                    Color(235, 240, 250, a * 0.9), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, a * 0.7))
            else
                -- за спиной/краем — чип-указатель у борта экрана
                local x = math.Clamp(scr.x, 90, sw - 90)
                local y = math.Clamp(scr.y, 70, sh - 90)
                local a = 150 + 80 * pulse
                draw.SimpleTextOutlined("» " .. it.def.lbl .. " · " .. meters .. " м", "P11POI.Small", x, y,
                    Color(col.r, col.g, col.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, a * 0.7))
            end
        end
    end
end)

print("[P11POI] v4.11.0 «КУЗНЯ» OK — маяки «куда идти» + верстак и ПОЛНЫЕ лутницы (выкл: p11_poi 0)")
