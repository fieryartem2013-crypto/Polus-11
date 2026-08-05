-- ============================================================
--  ПОЛЮС-11 — ДОКУМЕНТЫ (shared) v3.0
--  Удостоверение станции «ПОЛЮС-11» с УНИКАЛЬНЫМ КОДОМ.
--  v3.8: код привязан к игроку НА ВСЮ СМЕНУ — от захода и до
--  выхода с сервера (респавн код больше НЕ меняет — проверка
--  по коду через караульный терминал наконец осмысленна).
--  Перезашёл — удостоверение перевыпустят. R / ПКМ — предъявить
--  ближайшему человеку: у него откроется окно «ДОКУМЕНТ»
--  с именем, должностью, кодом и печатью времени.
--  Замаскированное Нечто показывает УКРАДЕННОЕ имя — как и положено.
-- ============================================================

SWEP.PrintName   = "Документы"
SWEP.Author      = "POLUS-11"
SWEP.Category    = "ПОЛЮС-11"
SWEP.Spawnable   = false
SWEP.AdminOnly   = false
SWEP.Weight      = 2

SWEP.HoldType        = "slam"
SWEP.ViewModel       = ""
SWEP.WorldModel      = "" -- без мировой модели: чистые руки с c_hands
SWEP.UseHands        = true
SWEP.DrawAmmo        = false
SWEP.DrawCrosshair   = false

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

if SERVER then
    util.AddNetworkString("P11_DocShow")
    util.AddNetworkString("P11_DocWho")
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    -- ЛКМ тоже предъявляет (удобно)
    self:SecondaryAttack()
end

-- ============ УНИКАЛЬНЫЙ КОД ============

local function NewDocCode()
    local chars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    local p1 = ""
    for i = 1, 4 do
        local r = math.random(#chars)
        p1 = p1 .. string.sub(chars, r, r)
    end
    return "П11-" .. p1 .. "-" .. math.random(100, 999)
end

function DocCodeOf(ply)
    if ply.P11_DocCode == nil then
        ply.P11_DocCode = NewDocCode()
        ply:SetNWString("P11_DocCode", ply.P11_DocCode)
    end
    return ply.P11_DocCode
end

-- v3.8: код выдаётся ОДИН РАЗ за заход и живёт, пока игрок на сервере
-- (поле ply.P11_DocCode умирает вместе с игроком при disconnect —
-- перевыпуск автоматический). Респавн/смерть код НЕ переигрывает.
if SERVER then
    hook.Add("PlayerSpawn", "P11.DocCode", function(ply)
        if ply.P11_DocCode == nil then
            ply.P11_DocCode = NewDocCode()
            ply:SetNWString("P11_DocCode", ply.P11_DocCode)
        end
    end)
end

-- ============ ПРЕДЪЯВИТЬ ============

function SWEP:SecondaryAttack()
    local ply = self.Owner
    if not IsValid(ply) then return end
    if self:GetNextSecondaryFire() > CurTime() then return end
    self:SetNextSecondaryFire(CurTime() + 1.5)
    ply:SetAnimation(PLAYER_ATTACK1)

    if CLIENT then return end

    -- найти ближайшего на виду
    local best, bestDist = nil, 290
    for _, t in ipairs(player.GetAll()) do
        if t ~= ply and IsValid(t) and t:Alive() then
            local d = t:GetPos():DistToSqr(ply:GetPos())
            if d < bestDist * bestDist then
                local tr = util.TraceLine({
                    start  = ply:EyePos(),
                    endpos = t:EyePos(),
                    filter = { ply, t },
                })
                if not tr.Hit or tr.Entity == t then
                    best, bestDist = t, math.sqrt(d)
                end
            end
        end
    end

    if not IsValid(best) then
        ply:ChatPrint("[ПОЛЮС-11] Некому предъявить документы — рядом никого.")
        return
    end

    -- личность = украденная, если под маской (как везде на станции)
    local name = ply:GetNWString("P11_FakeNick", "")
    if name == "" then name = ply:Nick() end
    local jobName = P11FW.GetJobName and P11FW.GetJobName(ply) or "без назначения"

    -- v3.7: ФРАКЦИЯ + читаемый формат кода (как в DRP-документах)
    local facName = "ПЕРСОНАЛ СТАНЦИИ"
    if P11FW.GetJob and P11FW.CategoryList then
        local job = P11FW.GetJob(ply)
        local cid = job and (job.faction or job.category) or nil
        for _, c in ipairs(P11FW.CategoryList) do
            if c.id == cid then facName = c.name break end
        end
    end

    net.Start("P11_DocShow")
        net.WriteString(name)
        net.WriteString(jobName)
        net.WriteString(DocCodeOf(ply))
        net.WriteString(os.date("%d.%m.%Y %H:%M"))
        net.WriteString(facName)
    net.Send(best)

    ply:ChatPrint("[ПОЛЮС-11] Документы предъявлены: " .. best:Nick())
    best:ChatPrint("[ПОЛЮС-11] " .. ply:Nick() .. " показывает тебе документы.")
end

function SWEP:Reload()
    if CLIENT then return true end
    self:SecondaryAttack()
    return true
end

-- ============ HUD ПОДСКАЗКИ ============

function SWEP:DrawHUD()
    local ply = self.Owner
    if not IsValid(ply) or not ply:Alive() then return end

    local code = ply:GetNWString("P11_DocCode", "...")
    draw.SimpleText("Документы: " .. code,
        "P11.HUD.Text", ScrW() / 2, ScrH() * 0.72, Color(230, 215, 170, 215),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("ЛКМ / R — предъявить ближайшему",
        "P11.HUD.Text", ScrW() / 2, ScrH() * 0.72 + 24, Color(160, 170, 185, 170),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- ============ ОКНО ДОКУМЕНТА (у того, кому предъявили) ============

if CLIENT then
    -- "П11-АГЛ-922" — как выглядит код в диктовке вслух (уже с дефисами;
    -- если когда-то появится код БЕЗ дефисов — аккуратно разобьём)
    local function FormatDocCode(code)
        if string.find(code, "-", 1, true) then return code end
        local letters = string.match(code, "^(%D+)") or code
        local digits  = string.match(code, "(%d+)$") or ""
        return letters .. (digits ~= "" and ("-" .. digits) or "")
    end

    surface.CreateFont("P11.Doc.Big",   { font = "Roboto", size = 26, weight = 800, extended = true })
    surface.CreateFont("P11.Doc.Mid",   { font = "Roboto", size = 18, weight = 600, extended = true })
    surface.CreateFont("P11.Doc.Small", { font = "Roboto", size = 14, weight = 400, extended = true })

    net.Receive("P11_DocShow", function()
        local name = net.ReadString()
        local jobName = net.ReadString()
        local code = net.ReadString()
        local stamp = net.ReadString()
        local facName = net.ReadString() -- v3.7

        if IsValid(POLUS11.DocFrame) then POLUS11.DocFrame:Remove() end

        local f = vgui.Create("DFrame")
        POLUS11.DocFrame = f
        f.T0 = SysTime()
        f:SetSize(400, 240)
        f:Center()
        f:SetTitle("")
        f:MakePopup()
        f:SetDeleteOnClose(true)
        f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)

        f.Paint = function(s, w, h)
            Derma_DrawBackgroundBlur(f, f.T0 or 0)
            -- «картон» удостоверения
            draw.RoundedBox(8, 0, 0, w, h, Color(226, 214, 180, 255))
            draw.RoundedBox(8, 4, 4, w - 8, h - 8, Color(240, 230, 198, 255))
            -- шапка станции
            draw.RoundedBoxEx(6, 4, 4, w - 8, 44, Color(24, 30, 40, 255), true, true, false, false)
            draw.SimpleText("СТАНЦИЯ «ПОЛЮС-11»", "P11.Doc.Big", w / 2, 26,
                Color(220, 195, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("УДОСТОВЕРЕНИЕ ЛИЧНОСТИ", "P11.Doc.Small", w / 2, 56,
                Color(70, 60, 44), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            draw.SimpleText("Имя: " .. name, "P11.Doc.Mid", 22, 84, Color(40, 36, 26),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            -- ФРАКЦИЯ крупно (как в DRP)
            draw.SimpleText(string.upper(facName), "P11.Doc.Mid", 22, 110, Color(90, 62, 30),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Должность: " .. jobName, "P11.Doc.Small", 22, 130, Color(40, 36, 26),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- код — главное (группами, читаемо при устном диктовании)
            draw.RoundedBox(4, 22, 146, w - 44, 38, Color(24, 30, 40, 255))
            draw.SimpleText("КОД: " .. FormatDocCode(code), "P11.Doc.Big", w / 2, 165,
                Color(230, 220, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            draw.SimpleText("выдано/проверено: " .. stamp, "P11.Doc.Small", 22, 200,
                Color(90, 80, 60), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("любая проверка кода — через КАРАУЛЬНЫЙ ТЕРМИНАЛ", "P11.Doc.Small", w - 22, 200,
                Color(90, 80, 60), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

            -- печать
            surface.SetDrawColor(70, 60, 40, 200)
            surface.DrawOutlinedRect(w - 84, 190, 62, 34, 3)
            draw.SimpleText("П-11", "P11.Doc.Mid", w - 53, 207, Color(70, 60, 40, 220),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        function f:OnKeyCodePressed(key) if key == KEY_ESCAPE then f:Remove() end end

        local xB = vgui.Create("DButton", f)
        xB:SetPos(400 - 34, 10) xB:SetSize(22, 22)
        xB:SetText("✕") xB:SetFont("P11.Doc.Small") xB:SetTextColor(Color(200, 180, 140))
        xB.Paint = function() end
        xB.DoClick = function() f:Remove() end

        timer.Simple(14, function() if IsValid(f) then f:Remove() end end)
    end)
end
