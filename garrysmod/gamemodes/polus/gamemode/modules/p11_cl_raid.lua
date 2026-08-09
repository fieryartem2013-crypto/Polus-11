-- ============================================================
--  ПОЛЮС-11 — РЕЙДЫ (клиент) v4.24.0 «РУБЕЖ»
--  Полоса наверху (заявка «меню наверху рейда — какие точки
--  чьи»): кто объявил рейд и на кого, сколько осталось, и ряд
--  фишек точек прорыва — буква окрашена цветом ВЛАДЕЛЬЦА
--  вживую (золото РККА / синь Орла / серый — никто).
--  Садится под полосой операций (у той y=92) — не перекрывает.
-- ============================================================

surface.CreateFont("P11.Raid.Mid",   { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11.Raid.Small", { font = "Roboto", size = 14, weight = 500, extended = true })

local FACT_COL = {
    rkka  = Color(205, 190, 100),
    eagle = Color(115, 155, 225),
}
local FACT_SHORT = { rkka = "РККА", eagle = "ОРЁЛ" }

local function RaidState()
    local raw = GetGlobalString("P11_Raid", "")
    if raw == "" then return nil end
    local t = string.Explode("|", raw)
    return {
        left = tonumber(t[2]) or 0,
        att  = t[3] or "",
        def  = t[4] or "",
    }
end

local function FmtTime(sec)
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

hook.Add("HUDPaint", "P11.RaidHUD", function()
    local st = RaidState()
    if not st then return end
    local w = ScrW()

    -- полоса рейда: «⚔ РЕЙД: РККА ▶ ОРЁЛ · до конца 8:32»
    draw.RoundedBox(8, w / 2 - 380, 138, 760, 40, Color(30, 14, 12, 225))
    draw.SimpleText("⚔ РЕЙД: " .. (FACT_SHORT[st.att] or "?") ..
        " ▶ " .. (FACT_SHORT[st.def] or "?"),
        "P11.Raid.Mid", w / 2 - 362, 148,
        Color(255, 160, 130), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("до конца " .. FmtTime(st.left), "P11.Raid.Mid",
        w / 2 + 362, 148, Color(235, 238, 242), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    -- фишки «какие точки чьи» (вживую с энтити-флагов рейда)
    local chips = {}
    for _, e in ipairs(ents.FindByClass("polus11_cappoint")) do
        if IsValid(e) and e:GetNWBool("P11_RaidPoint", false) then
            chips[#chips + 1] = {
                nm = e.GetPointName and e:GetPointName() or "?",
                ow = e.GetOwnerFact and e:GetOwnerFact() or "",
            }
        end
    end
    table.sort(chips, function(a, b) return a.nm < b.nm end)
    if #chips == 0 then return end

    local x = w / 2 - (#chips * 64) / 2
    for _, c in ipairs(chips) do
        local col = FACT_COL[c.ow] or Color(125, 131, 141)
        draw.RoundedBox(6, x, 184, 56, 26, Color(14, 18, 26, 235))
        draw.SimpleText(c.nm, "P11.Raid.Mid", x + 28, 197, col,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        x = x + 64
    end
end)

print("[POLUS-11] РЕЙДЫ (client) v4.24.0 «РУБЕЖ»: полоса наверху — ход рейда и чьи точки")
