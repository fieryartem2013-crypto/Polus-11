-- ============================================================
--  ПОЛЮС-11 — БРАУЗЕР ВНЕШНОСТИ (client) v4.4.0 — НАПИСАН С НУЛЯ
--  Полная замена старого «Меню моделей» из C-меню.
--
--  ЧТО УМЕЕТ:
--   • МОЯ ДОЛЖНОСТЬ — варианты формы своей профы, клик = надеть
--     (официальный канал P11_ModelWear → сервер сам разрулит);
--   • ВСЕ ДОЛЖНОСТИ СТАНЦИИ — каталог моделей всех проф (кастом
--     РККА/НКВД/наука тоже виден — их-то раньше и «не было в меню»);
--   • СТАНДАРТНЫЕ МОДЕЛИ ИГРЫ — полный движковый список;
--   • ★ ИЗБРАННОЕ — свои закладки (data/polus11/favmodels.json);
--   • ЖИВОЕ ПРЕВЬЮ выбранной модели + поиск по пути;
--   • красным — модели, которых НЕТ на твоём ПК (воркшоп-пак);
--   • АДМИНАМ: «НАДЕТЬ СЕБЕ» любую и «ВЫДАТЬ ИГРОКУ» по списку.
--  Открыть: C-меню → «Меню моделей», консоль p11_models.
-- ============================================================

P11 = P11 or {}

surface.CreateFont("P11.MD.Title", { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("P11.MD.Text",  { font = "Roboto", size = 15, weight = 600, extended = true })
surface.CreateFont("P11.MD.Small", { font = "Roboto", size = 13, weight = 400, extended = true })
surface.CreateFont("P11.MD.Btn",   { font = "Roboto", size = 15, weight = 700, extended = true })

local MC = {
    bg    = Color(10, 14, 20, 245),
    panel = Color(20, 26, 36, 255),
    panel2= Color(27, 34, 47, 255),
    cyan  = Color(120, 185, 255),
    gold  = Color(255, 205, 110),
    text  = Color(228, 236, 245),
    dim   = Color(150, 165, 180),
    ok    = Color(115, 215, 135),
    bad   = Color(235, 100, 90),
    star  = Color(255, 190, 80),
}

-- ============ мягкое появление (самодостаточно, без внешних зависимостей) ============
local TW_LEN = 0.2
local function TweenK(s)
    local k = math.Clamp((SysTime() - (s.AnimT or 0)) / TW_LEN, 0, 1)
    return 1 - (1 - k) ^ 3
end
local function AnimateIn(s)
    s.AnimT = SysTime()
    local tx, ty = s:GetPos()
    s:SetPos(tx, ty + 22)
    s.Think = function() s:SetPos(tx, ty + 22 * (1 - TweenK(s))) end
end

-- ============ ИЗБРАННОЕ (клиентский файл) ============
local FAV_FILE = "polus11/favmodels.json"

local function LoadFavs()
    local raw = file.Read(FAV_FILE, "DATA")
    if not raw then return {} end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if not (ok and istable(tbl)) then return {} end
    local out = {}
    for _, m in ipairs(tbl) do
        if isstring(m) then out[#out + 1] = string.lower(m) end
    end
    return out
end

local function SaveFavs(favs)
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(FAV_FILE, util.TableToJSON(favs))
end

local function IsFav(favs, mdl)
    for _, m in ipairs(favs) do if m == mdl then return true end end
    return false
end

-- ============ МОДЕЛЬ ИЗ МОЕЙ ДОЛЖНОСТИ? ============
local function InMyJobModels(me, mdl)
    local job = P11FW.GetJob and P11FW.GetJob(me)
    if not (job and istable(job.models)) then return false end
    for _, m in ipairs(job.models) do
        if string.lower(tostring(m)) == mdl then return true end
    end
    return false
end

-- ============================================================
--  ГЛАВНОЕ ОКНО
-- ============================================================

function P11.OpenModelMenu()
    if IsValid(P11.ModelFrame) then P11.ModelFrame:Remove() end

    local me = LocalPlayer()
    local isAdmin = P11FW.Config and P11FW.Config.Admin(me)

    local W, H = 940, 600
    local f = vgui.Create("DFrame")
    P11.ModelFrame = f
    f.T0 = SysTime()
    f:SetSize(W, H)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)
    AnimateIn(f)

    -- ранние объявления: замыкания выше по коду ссылаются на эти панели
    local search, wearB, favB, giveB

    f.Favs = LoadFavs()
    f.Selected = nil       -- выбранный путь модели

    function f:Paint(w, h)
        local x, y = self:GetPos()
        surface.SetDrawColor(5, 9, 13, 165 * TweenK(self))
        surface.DrawRect(-x, -y, ScrW(), ScrH())
        surface.SetAlphaMultiplier(0.25 + 0.75 * TweenK(self))
        Derma_DrawBackgroundBlur(self, self.T0 or 0)
        draw.RoundedBox(10, 0, 0, w, h, MC.bg)
        draw.RoundedBoxEx(10, 0, 0, w, 56, MC.panel2, true, true, false, false)
        surface.SetDrawColor(MC.gold)
        surface.DrawRect(0, 56, w, 2)
        draw.SimpleText("БРАУЗЕР ВНЕШНОСТИ", "P11.MD.Title", 16, 28, MC.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("клик — превью • двойной клик — надеть • v4.4.0", "P11.MD.Small", w - 46, 28, MC.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        surface.SetAlphaMultiplier(1)
    end
    function f:OnKeyCodePressed(key) if key == KEY_ESCAPE then f:Remove() end end

    local xB = vgui.Create("DButton", f)
    xB:SetPos(W - 40, 14) xB:SetSize(26, 26)
    xB:SetText("✕") xB:SetFont("P11.MD.Title") xB:SetTextColor(MC.dim)
    xB.Paint = function() end
    xB.DoClick = function() f:Remove() end

    -- ============ ЛЕВАЯ КОЛОНКА: РАЗДЕЛЫ ============
    local side = vgui.Create("DPanel", f)
    side:SetPos(10, 66) side:SetSize(230, 524)
    side.Paint = function(s, w, h) draw.RoundedBox(8, 0, 0, w, h, MC.panel) end

    f.Section = "myjob"
    f.SideButtons = {}

    local function SideBtn(y, id, name, desc, col)
        local b = vgui.Create("DButton", side)
        b:SetPos(10, y) b:SetSize(210, 56)
        b:SetText("")
        b.SId = id
        b.Paint = function(s, w, h)
            local on = f.Section == s.SId
            draw.RoundedBox(6, 0, 0, w, h, on and Color(col.r, col.g, col.b, 38) or (s:IsHovered() and Color(255,255,255,10) or Color(255,255,255,4)))
            draw.RoundedBoxEx(6, 0, 0, 4, h, on and col or Color(col.r, col.g, col.b, 110), true, false, true, false)
            if on then
                surface.SetDrawColor(col)
                surface.DrawRect(4, h - 2, w - 8, 2)
            end
            draw.SimpleText(name, "P11.MD.Text", 14, h / 2 - 9, on and col or MC.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(desc, "P11.MD.Small", 14, h / 2 + 11, MC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            f.Section = id
            surface.PlaySound("buttons/button15.wav")
            f:FillGrid(search:GetValue())
        end
        f.SideButtons[id] = b
        return b
    end

    SideBtn(10,  "myjob",   "🪖 МОЯ ДОЛЖНОСТЬ", "варианты формы своей профы — надеть может каждый", MC.ok)
    SideBtn(72,  "favs",    "★ ИЗБРАННОЕ", "твои закладки (хранятся на этом ПК)", MC.star)
    SideBtn(134, "alljobs", "🏢 ВСЕ ДОЛЖНОСТИ", "каталог форм станции: РККА, НКВД, наука, обслуга", MC.cyan)
    SideBtn(196, "stock",   "📦 СТАНДАРТНЫЕ", "полный список моделей движка", MC.text)

    local sideNote = vgui.Create("DLabel", side)
    sideNote:SetPos(10, 266) sideNote:SetSize(210, 248)
    sideNote:SetFont("P11.MD.Small") sideNote:SetTextColor(MC.dim)
    sideNote:SetWrap(true) sideNote:SetAutoStretchVertical(true)
    sideNote:SetText("ПРАВИЛА СТАНЦИИ:\n\n• Свою форму надевай свободно.\n• Чужая/любая модель — только через администрацию.\n• Красная ячейка = модели нет на твоём ПК (нужен воркшоп-пак сервера), на сервере она всё равно наденется.")

    -- ============ ПРАВАЯ ПАНЕЛЬ: ПРЕВЬЮ ============
    local prev = vgui.Create("DPanel", f)
    prev:SetPos(700, 66) prev:SetSize(230, 524)
    prev.Paint = function(s, w, h) draw.RoundedBox(8, 0, 0, w, h, MC.panel) end

    local mp = vgui.Create("DModelPanel", prev)
    mp:SetPos(10, 10) mp:SetSize(210, 250)
    mp:SetLookAt(Vector(0, 0, 62))
    mp:SetCamPos(Vector(46, -12, 62))
    mp:SetAnimated(true)
    mp.LayoutEntity = function(s, ent)
        ent:SetAngles(Angle(0, math.sin(CurTime() * 0.4) * 14 - 12, 0))
    end

    local pathL = vgui.Create("DLabel", prev)
    pathL:SetPos(10, 264) pathL:SetSize(210, 48)
    pathL:SetFont("P11.MD.Small") pathL:SetTextColor(MC.cyan)
    pathL:SetWrap(true) pathL:SetAutoStretchVertical(true)
    pathL:SetText("— выбери модель из списка —")

    local statusL = vgui.Create("DLabel", prev)
    statusL:SetPos(10, 312) statusL:SetSize(210, 16)
    statusL:SetFont("P11.MD.Small") statusL:SetTextColor(MC.dim)
    statusL:SetText("")

    local function MPanel_SetModel(mdl)
        f.Selected = mdl
        pathL:SetText(mdl)
        if file.Exists(mdl, "GAME") then
            statusL:SetText("✔ файл есть на твоём ПК")
            statusL:SetTextColor(MC.ok)
            mp:SetModel(mdl)
        else
            statusL:SetText("⚠ нет на твоём ПК (воркшоп-пак?)")
            statusL:SetTextColor(MC.bad)
            mp:SetModel("models/player/Group01/male_01.mdl")
        end
        -- обновить подписи кнопок
        local mine = InMyJobModels(me, mdl)
        local can = mine or isAdmin
        wearB.PText = can and "НАДЕТЬ СЕБЕ" or "НАДЕТЬ СЕБЕ 🔒"
        wearB.PColor = can and MC.ok or MC.dim
        wearB.Mine = mine
        wearB.Can = can
        favB.PText = IsFav(f.Favs, mdl) and "★ УБРАТЬ ИЗ ЗАКЛАДОК" or "☆ В ИЗБРАННОЕ"
        if IsValid(giveB) then
            giveB.PText = "ВЫДАТЬ ИГРОКУ"
            giveB.PColor = MC.gold
        end
    end

    -- надевает выбранную модель (канал v4.4: P11_ModelWear)
    local function WearSelected(silent)
        local mdl = f.Selected
        if not mdl then surface.PlaySound("buttons/button10.wav") return end
        net.Start("P11_ModelWear")
            net.WriteString(mdl)
        net.SendToServer()
        if not silent then
            surface.PlaySound("buttons/button9.wav")
            chat.AddText(MC.cyan, "[ПОЛЮС-11] Запрос внешности отправлен: ", MC.dim, mdl)
        end
    end
    f.WearSelected = WearSelected

    wearB = vgui.Create("DButton", prev)
    wearB:SetPos(10, 336) wearB:SetSize(210, 40)
    wearB:SetText("")
    wearB.PText, wearB.PColor = "НАДЕТЬ СЕБЕ", MC.dim
    wearB.Paint = function(s, w, h)
        local can = s.Can
        draw.RoundedBox(8, 0, 0, w, h,
            can and (s:IsHovered() and Color(46, 100, 62) or Color(34, 78, 48))
                or  (s:IsHovered() and Color(60, 64, 72) or Color(46, 50, 58)))
        draw.SimpleText(s.PText, "P11.MD.Btn", w / 2, h / 2, s.PColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    wearB.DoClick = function()
        if not f.Selected then surface.PlaySound("buttons/button10.wav") return end
        if not wearB.Can then
            surface.PlaySound("buttons/button10.wav")
            chat.AddText(MC.bad, "[ПОЛЮС-11] Эта модель не из твоей должности — попроси администрацию (или возьми профу в F4).")
            return
        end
        WearSelected(true)
        surface.PlaySound("buttons/button15.wav")
        timer.Simple(0.3, function() if IsValid(f) then f:Remove() end end)
    end

    favB = vgui.Create("DButton", prev)
    favB:SetPos(10, 384) favB:SetSize(210, 32)
    favB:SetText("")
    favB.PText = "☆ В ИЗБРАННОЕ"
    favB.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(255, 190, 80, 26) or Color(255, 255, 255, 8))
        draw.SimpleText(s.PText, "P11.MD.Text", w / 2, h / 2, MC.star, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    favB.DoClick = function()
        if not f.Selected then surface.PlaySound("buttons/button10.wav") return end
        for i, m in ipairs(f.Favs) do
            if m == f.Selected then
                table.remove(f.Favs, i)
                SaveFavs(f.Favs)
                MPanel_SetModel(f.Selected)
                if f.Section == "favs" then f:FillGrid(search:GetValue()) end
                surface.PlaySound("buttons/button10.wav")
                return
            end
        end
        f.Favs[#f.Favs + 1] = f.Selected
        SaveFavs(f.Favs)
        MPanel_SetModel(f.Selected)
        surface.PlaySound("buttons/button15.wav")
    end

    -- ===== АДМИН: ВЫДАТЬ ДРУГОМУ =====
    if isAdmin then
        local giveLbl = vgui.Create("DLabel", prev)
        giveLbl:SetPos(10, 424) giveLbl:SetSize(210, 16)
        giveLbl:SetFont("P11.MD.Small") giveLbl:SetTextColor(MC.gold)
        giveLbl:SetText("АДМИН: выдать модель игроку")

        local tgt = vgui.Create("DComboBox", prev)
        tgt:SetPos(10, 442) tgt:SetSize(210, 26)
        tgt:SetValue("— выбери игрока —")
        tgt:SetFont("P11.MD.Small")
        tgt:SetTextColor(MC.text)
        for _, pl in ipairs(player.GetAll()) do
            tgt:AddChoice(pl:Nick(), pl:EntIndex(), false, "")
        end

        giveB = vgui.Create("DButton", prev)
        giveB:SetPos(10, 476) giveB:SetSize(210, 36)
        giveB:SetText("")
        giveB.PText, giveB.PColor = "ВЫДАТЬ ИГРОКУ", MC.gold
        giveB.Paint = function(s, w, h)
            draw.RoundedBox(8, 0, 0, w, h, s:IsHovered() and Color(110, 82, 32) or Color(84, 62, 26))
            draw.SimpleText(s.PText, "P11.MD.Btn", w / 2, h / 2, s.PColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        giveB.DoClick = function()
            local _, idx = tgt:GetSelected()
            if not f.Selected or not idx then surface.PlaySound("buttons/button10.wav") return end
            net.Start("P11_ModelGive")
                net.WriteUInt(idx, 8)
                net.WriteString(f.Selected)
            net.SendToServer()
            surface.PlaySound("buttons/button9.wav")
        end
    end

    -- ============ ЦЕНТР: ПОИСК + СЕТКА ============
    search = vgui.Create("DTextEntry", f)
    search:SetPos(250, 66) search:SetSize(440, 26)
    search:SetPlaceholderText("поиск по пути (напр. rkka, scientist, male_01...)")

    local stats = vgui.Create("DLabel", f)
    stats:SetPos(250, 572) stats:SetSize(440, 16)
    stats:SetFont("P11.MD.Small") stats:SetTextColor(MC.dim)
    stats:SetText("")

    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(250, 98) sc:SetSize(440, 470)
    local sb = sc:GetVBar()
    sb:SetWide(5)
    sb.Paint = function(s, w, h) draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 18)) end
    sb.btnGrip.Paint = function(s, w, h) draw.RoundedBox(2, 0, 0, w, h, MC.cyan) end

    local grid = vgui.Create("DIconLayout", sc)
    grid:Dock(FILL)
    grid:SetSpaceX(6) grid:SetSpaceY(6)

    -- ---------- наполнение ----------
    function f:FillGrid(filter)
        grid:Clear()
        filter = string.lower(string.Trim(filter or ""))
        local shown, missing = 0, 0

        local function AddTile(mdl, idx)
            mdl = string.lower(tostring(mdl))
            if shown + missing >= 600 then return end
            if filter ~= "" and not string.find(mdl, filter, 1, true) then return end
            if file.Exists(mdl, "GAME") then
                shown = shown + 1
                local ic = vgui.Create("SpawnIcon", grid)
                ic:SetSize(66, 66)
                ic:SetModel(mdl)
                ic:SetTooltip(mdl)
                ic.DoClick = function()
                    surface.PlaySound("buttons/button9.wav")
                    MPanel_SetModel(mdl)
                end
                ic.DoDoubleClick = function()
                    MPanel_SetModel(mdl)
                    WearSelected(false)
                end
                ic.PaintOver = function(s, w, h)
                    if f.Selected == mdl then
                        surface.SetDrawColor(MC.gold)
                        surface.DrawOutlinedRect(1, 1, w - 2, h - 2, 2)
                    end
                    if IsFav(f.Favs, mdl) then
                        draw.SimpleText("★", "P11.MD.Small", w - 12, 12, MC.star, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end
            else
                missing = missing + 1
                local bad = vgui.Create("DButton", grid)
                bad:SetSize(66, 66)
                bad:SetText("")
                bad:SetTooltip(mdl .. "\n\n⚠ модели нет на этом ПК (воркшоп-пак не смонтирован).\nНа сервере наденется — у кого пак есть, увидят правильно.")
                bad.Paint = function(bs, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, bs:IsHovered() and Color(60, 26, 26) or Color(36, 20, 22))
                    surface.SetDrawColor(MC.bad)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    draw.SimpleText("ВОРК-", "P11.MD.Small", w / 2, h / 2 - 10, MC.bad, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("ШОП?", "P11.MD.Small", w / 2, h / 2 + 2, MC.bad, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("нет на ПК", "P11.MD.Small", w / 2, h / 2 + 14, MC.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                bad.DoClick = function()
                    surface.PlaySound("buttons/button10.wav")
                    MPanel_SetModel(mdl) -- превью-подстановка + честный статус
                end
            end
        end

        local section = self.Section

        if section == "myjob" then
            local job = P11FW.GetJob and P11FW.GetJob(me)
            if job and istable(job.models) and #job.models > 0 then
                for i, m in ipairs(job.models) do AddTile(m, i) end
            else
                local l = grid:Add("DLabel")
                l:SetFont("P11.MD.Small") l:SetTextColor(MC.dim)
                l:SetText("  У твоей должности нет своих моделей.")
                l:SizeToContents()
            end

        elseif section == "favs" then
            for _, m in ipairs(self.Favs) do AddTile(m) end

        elseif section == "alljobs" then
            local seen = {}
            for _, jobId in ipairs(P11FW.JobIds or {}) do
                local jb = P11FW.Jobs[jobId]
                if jb and istable(jb.models) then
                    for _, m in ipairs(jb.models) do
                        local key = string.lower(tostring(m))
                        if not seen[key] then
                            seen[key] = true
                            AddTile(m)
                        end
                    end
                end
            end

        elseif section == "stock" then
            local opts = list.Get("PlayerOptionsModel") or {}
            local names = {}
            for name in pairs(opts) do names[#names + 1] = name end
            table.sort(names)
            for _, name in ipairs(names) do AddTile(opts[name]) end
        end

        if shown + missing == 0 and section ~= "myjob" then
            local l = grid:Add("DLabel")
            l:SetFont("P11.MD.Small") l:SetTextColor(MC.dim)
            l:SetText("  ничего не найдено" .. (filter ~= "" and (" по «" .. filter .. "»") or ""))
            l:SizeToContents()
        end

        stats:SetText("раздел: " .. (self.SideButtons[section] and "" or "") ..
            "моделей: " .. shown .. (missing > 0 and ("  (+ " .. missing .. " только с паком)") or ""))
    end

    f:FillGrid("")
    search.OnChange = function(s) f:FillGrid(s:GetValue()) end

    -- если уже на модели из превью — сразу показать текущую
    local cur = string.lower(me:GetModel() or "")
    if cur ~= "" and string.find(cur, "models/player/", 1, true) then
        MPanel_SetModel(cur)
    end
end

-- консоль: p11_models
concommand.Add("p11_models", function()
    P11.OpenModelMenu()
end)

print("[POLUS-11] Браузер внешности v4.4.0 загружен (p11_models)")
