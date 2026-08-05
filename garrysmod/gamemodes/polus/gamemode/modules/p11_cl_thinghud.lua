-- ============================================================
--  ПОЛЮС-11 — HUD НЕЧТО (client) v2.6
--  Видит только заражённый: форма, состояние маскировки,
--  кулдауны (крик / смена формы / разрыв), доза спор,
--  подсказки клавиш. При явленной форме — красная виньетка
--  по краям экрана («глаза зверя»).
-- ============================================================

surface.CreateFont("P11.TH.Title", { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("P11.TH.Text",  { font = "Roboto", size = 16, weight = 500, extended = true })
surface.CreateFont("P11.TH.Small", { font = "Roboto", size = 13, weight = 400, extended = true })

local TC = {
    red    = Color(215, 70, 60),
    reddim = Color(215, 70, 60, 130),
    blood  = Color(150, 32, 30, 235),
    panel  = Color(14, 10, 12, 215),
    edge   = Color(90, 20, 22),
    text   = Color(240, 225, 225),
    dim    = Color(190, 150, 150),
    ok     = Color(140, 220, 140),
    cyan   = Color(120, 205, 230),
}

local FORM_NAMES = {
    imitator = "ИМИТАТОР",
    brute    = "ПОГЛОТИТЕЛЬ",
    spore    = "СПОРОВИК",
    split    = "РАЗДЕЛЁННЫЙ",
}

local function CdBar(x, y, w, nextTime, name, readyCol)
    local now = CurTime()
    local left = math.max(0, (nextTime or 0) - now)
    local ready = left <= 0

    draw.SimpleText(name, "P11.TH.Small", x, y, ready and readyCol or TC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.RoundedBox(3, x, y + 9, w, 5, Color(255, 255, 255, 16))
    if ready then
        draw.RoundedBox(3, x, y + 9, w, 5, readyCol)
    else
        draw.RoundedBox(3, x, y + 9, 4, 5, TC.dim)
        draw.SimpleText(math.ceil(left) .. "с", "P11.TH.Small", x + w + 6, y + 1, TC.dim)
    end
end

hook.Add("HUDPaint", "P11.ThingHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if not ply:GetNWBool("P11_Infected", false) then return end

    local sw, sh = ScrW(), ScrH()
    local revealed = ply:GetNWBool("P11_Revealed", false)
    local active = ply:GetNWBool("P11_InfActive", false)

    -- ===== виньетка «глаз зверя» при явленной форме =====
    if revealed then
        local pulse = 60 + math.sin(CurTime() * 3.2) * 25
        surface.SetDrawColor(TC.blood.r, TC.blood.g, TC.blood.b, pulse)
        surface.DrawRect(0, 0, sw, 3)
        surface.DrawRect(0, sh - 3, sw, 3)
        surface.DrawRect(0, 0, 3, sh)
        surface.DrawRect(sw - 3, 0, 3, sh)
        -- мягко затянутые углы
        draw.RoundedBox(0, 0, 0, sw, 26, Color(TC.blood.r, TC.blood.g, TC.blood.b, pulse * 0.35))
        draw.RoundedBox(0, 0, sh - 26, sw, 26, Color(TC.blood.r, TC.blood.g, TC.blood.b, pulse * 0.35))
    end

    -- ===== панель Нечто (левый нижний угол) =====
    local w, h = 372, active and 128 or 86
    local x, y = 14, sh - h - 14

    draw.RoundedBox(8, x, y, w, h, TC.panel)
    surface.SetDrawColor(revealed and TC.red or TC.edge)
    surface.DrawOutlinedRect(x, y, w, h, 2)

    local form = FORM_NAMES[ply:GetNWString("P11_ThingForm", "")] or "НЕЧТО"
    local status
    if not active then
        status = "ИНКУБАЦИЯ — держись в тени"
    elseif revealed then
        status = "ФОРМА ЯВЛЕНА — тебя видно!"
    else
        status = "МАСКИРОВКА — ты «человек»"
    end

    draw.SimpleText(form, "P11.TH.Title", x + 12, y + 18, TC.red)
    draw.SimpleText(status, "P11.TH.Text", x + w - 12, y + 19,
        not active and TC.cyan or (revealed and TC.red or TC.ok),
        TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    draw.SimpleText("☣ ТЫ — НЕЧТО. Поглощай. Копируй. Не светись перед огнём и тестом крови.",
        "P11.TH.Small", x + 12, y + 40, TC.dim)

    if not active then return end

    -- кулдауны
    local cy = y + 58
    CdBar(x + 12,  cy, 150, ply:GetNWFloat("P11_ScreamCd", 0), "КРИК (!крик)", TC.red)
    CdBar(x + 200, cy, 150, ply:GetNWFloat("P11_FormCd", 0), "ФОРМА (!форма)", TC.cyan)

    -- доза спор (у споровика/если капал на людей — это шкала цели, у себя тоже видно)
    local expo = ply:GetNWFloat("P11_Exposure", 0)
    if expo > 0.5 then
        draw.SimpleText("СПОРЫ В ТЕЛЕ", "P11.TH.Small", x + 12, cy + 26, TC.dim)
        draw.RoundedBox(3, x + 12, cy + 35, w - 24, 5, Color(255, 255, 255, 16))
        draw.RoundedBox(3, x + 12, cy + 35, (w - 24) * math.Clamp(expo / 100, 0, 1), 5, TC.cyan)
    else
        draw.SimpleText("ЛКМ — когти • R — маскировка • !разрыв (споровик) • огонь = смерть",
            "P11.TH.Small", x + 12, cy + 30, TC.dim)
    end

    draw.SimpleText("v2.6", "P11.TH.Small", x + w - 10, y + h - 12, TC.edge, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end)
