-- ============================================================
--  ПОЛЮС-11 — HUD ТОЧКИ ЗАХВАТА «ФЛАГ» (v4.16.0 «ЗАХВАТ»)
--  Полоса внизу экрана, пока боец в кругу точки: владелец,
--  шкала захвата, «БОЙ ЗА ТОЧКУ» при встречных боках.
-- ============================================================

if not POLUS11 then return end

local FACT = {
    rkka  = { name = "РККА",                col = Color(205, 190, 100) },
    eagle = { name = "ОТРЯД «КРАСНЫЙ ОРЁЛ»", col = Color(115, 155, 225) },
}
local RADIUS = 360

local made = 0
local function Fonts()
    if made == 1 then return end
    made = 1
    surface.CreateFont("P11.Cap.Big",   { font = "Arial", size = 20, weight = 800, extended = true })
    surface.CreateFont("P11.Cap.Small", { font = "Arial", size = 15, weight = 600, extended = true })
end

-- фракция игрока для захвата (та же логика, что на сервере)
local function FactOf(ply)
    if not (P11FW and P11FW.GetJob) then return nil end
    local job = P11FW.GetJob(ply)
    local id = istable(job) and (job.faction or job.category) or nil
    if id == "rkka" or id == "eagle" then return id end
    return nil
end

hook.Add("HUDPaint", "P11.CapPointHUD", function()
    local me = LocalPlayer()
    if not (IsValid(me) and me:Alive()) then return end

    local best
    for _, e in ipairs(ents.FindByClass("polus11_cappoint")) do
        if IsValid(e) and me:GetPos():DistToSqr(e:GetPos()) <= (RADIUS + 20) * (RADIUS + 20) then
            best = e break
        end
    end
    if not best then return end

    Fonts()

    -- бой за точку: обе стороны в кругу?
    local r2 = RADIUS * RADIUS
    local rkka, eagle = 0, 0
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:Alive() and p:GetPos():DistToSqr(best:GetPos()) <= r2 then
            local f = FactOf(p)
            if f == "rkka" then rkka = rkka + 1
            elseif f == "eagle" then eagle = eagle + 1 end
        end
    end

    local w, h = 340, 92
    local x = ScrW() / 2 - w / 2
    local y = ScrH() - h - 230 -- выше виталов и худов
    draw.RoundedBox(8, x, y, w, h, Color(14, 18, 24, 218))
    surface.SetDrawColor(255, 170, 90, 230)
    surface.DrawOutlinedRect(x, y, w, h, 1)

    local nm = best.GetPointName and best:GetPointName() or ""
    if nm == "" then nm = "?" end
    draw.SimpleTextOutlined("ТОЧКА ЗАХВАТА «" .. nm .. "»", "P11.Cap.Big", x + w / 2, y + 8,
        Color(255, 200, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 200))

    local owner = best.GetOwnerFact and best:GetOwnerFact() or ""
    local ow = FACT[owner]
    draw.SimpleTextOutlined("ВЛАДЕЕТ: " .. (ow and ow.name or "— НИКТО —"), "P11.Cap.Small",
        x + w / 2, y + 34, ow and ow.col or Color(170, 175, 185),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 200))

    if rkka > 0 and eagle > 0 then
        draw.SimpleTextOutlined("БОЙ ЗА ТОЧКУ — шкала заморожена!", "P11.Cap.Small",
            x + w / 2, y + 56, Color(255, 120, 110),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 230))
        return
    end

    local cap = best.GetCapFact and best:GetCapFact() or ""
    local frac = tonumber(best.GetCapFrac and best:GetCapFrac()) or 0
    if cap ~= "" and FACT[cap] then
        local bx, by, bw, bh = x + 12, y + 60, w - 24, 14
        draw.RoundedBox(4, bx, by, bw, bh, Color(30, 34, 42, 235))
        draw.RoundedBox(4, bx, by, math.floor(bw * math.Clamp(frac, 0, 1)), bh, FACT[cap].col)
        draw.SimpleTextOutlined("ЗАХВАТ: " .. FACT[cap].name .. " " .. math.floor(frac * 100) .. "%",
            "P11.Cap.Small", x + w / 2, by + 1, Color(255, 255, 255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
    else
        local hint = "встань в круг — фракция жмёт точку (60 сек)"
        if owner ~= "" then hint = "круг спокоен · удержание идёт (+35₽)" end
        draw.SimpleTextOutlined(hint, "P11.Cap.Small", x + w / 2, y + 58, Color(190, 195, 205),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 200))
    end
end)

print("[POLUS-11] ЗАХВАТ: HUD v4.16.0 — полоса точки в круге (владелец/шкала/бой)")
