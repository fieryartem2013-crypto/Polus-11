-- ============================================================
--  ПОЛЮС-11 — МАСТЕР-ФИКСЫ v5.6.5 (КЛИЕНТ, энтити fixboot)
--  1) БЕЛЫЙ текст во всех меню/UI (чёрный → белый)
--  2) Плавное появление C-меню и TAB
--  3) Новая вкладка/окно «ВЫДАЧА ОПЫТА» (опыт/XP батлпасс/стаж)
--  4) Замена всех квадратиков (эмодзи) на рабочие Юникод-знаки
--  5) Стаж/время выдаётся (сервер: p11_sv_adminxp_v565)
--  6) Убрана ванильная штука (HP + Steam-ник над/под игроком)
--  7) Описание игрока — ВНИЗУ (у ног), а не над головой
--
--  Доставка: cl_init энтити раздаётся клиентам ВСЕГДА (не зависит
--  от sv_allowcslua). Энтити спавнится сервером (fixboot_spawn).
--  Применение ПОСЛЕ гейммода. Старые файлы не трогаем.
-- ============================================================

local function Safe(fn, name)
    local ok, err = pcall(fn)
    if not ok then print("[POLUS-11][v5.6.5] " .. (name or "?") .. ": " .. tostring(err)) end
end

-- ================= 1) БЕЛЫЙ ТЕКСТ ВО ВСЕХ МЕНЮ/UI =================
local function ApplyWhiteText()
    -- v5.7.0: ГЛОБАЛЬНЫЙ ПЕРЕКРАС ОТКАЧЕН — он ломал чёрный/белый текст
    -- (где надо чёрный — стал белым и слился, и наоборот).
    -- Возвращаем ШТАТНЫЙ рендер текста. Ничего не патчим глобально.
    -- Точечные правки цвета текста — отдельными модулями при необходимости.
    if P11F565_White then return end P11F565_White = true
    print("[POLUS-11] v5.7.0: глобальный перекрас текста ОТКАЧЕН (штатный рендер)")
end

-- ================= 2) ПЛАВНОЕ ПОЯВЛЕНИЕ C-МЕНЮ И TAB =================
local function ApplySmooth()
    if P11F565_Smooth then return end P11F565_Smooth = true
    -- C-меню: улучшенная анимация (плавный выезд + прозрачность)
    if P11 then
        P11.AnimateIn = function(s, dur)
            dur = dur or 0.28
            local x, y = s:GetPos()
            s.P11A_T0 = SysTime()
            s.P11A_X, s.P11A_Y = x, y
            local basePaint = s.Paint
            s.Paint = function(self, w, h)
                local t = math.Clamp((SysTime() - (self.P11A_T0 or 0)) / dur, 0, 1)
                local e = 1 - (1 - t) * (1 - t)
                self:SetAlpha(math.floor(255 * e))
                self:SetPos(self.P11A_X, self.P11A_Y + (1 - e) * 16)
                if basePaint then basePaint(self, w, h) end
            end
        end
    end
    -- TAB: плавное затемнение при открытии
    local tabFade = 0
    hook.Add("ScoreboardShow", "P11.TabFade", function()
        tabFade = CurTime() + 0.25
    end)
    hook.Add("HUDPaint", "P11.TabFadeOverlay", function()
        if CurTime() > tabFade then return end
        local t = (tabFade - CurTime()) / 0.25
        surface.SetDrawColor(0, 0, 0, math.floor(110 * (1 - t)))
        surface.DrawRect(0, 0, ScrW(), ScrH())
    end)
    print("[POLUS-11] v5.6.5: плавное появление C-меню и TAB")
end

-- ================= 6) УБРАТЬ ВАНИЛЬНУЮ ШТУКУ (HP + Steam-ник) =================
local function ApplyHideVanilla()
    if P11F565_Van then return end P11F565_Van = true
    -- ники/ХП под прицелом (ванильный target ID)
    hook.Add("HUDDrawTargetID", "P11.HideVanillaTarget", function() return false end)
    -- ванильные HUD-элементы
    hook.Add("HUDShouldDraw", "P11.HideVanillaHud", function(name)
        if name == "CHudName" or name == "CHudHealth" or name == "CHudBattery" then
            return false
        end
    end)
    print("[POLUS-11] v5.6.5: ванильные HP/Steam-ник убраны")
end

-- ================= 4) ЗАМЕНА КВАДРАТИКОВ (эмодзи → Юникод) =================

local REPL = {
    ["\226\128\139"] = "", -- FE0F
    ["\240\159\142\146"] = "◆", ["\240\159\143\141"] = "●", ["\240\159\148\146"] = "●",
    ["\240\159\146\160"] = "◆", ["\240\159\146\142"] = "◆", ["\240\159\155\161"] = "◆",
    ["\240\159\140\159"] = "★", ["\226\154\161"] = "◆", ["\240\159\147\166"] = "◆",
    ["\240\159\169\184"] = "●", ["\240\159\155\160"] = "◆", ["\240\159\154\151"] = "◆",
    ["\240\159\148\165"] = "▲", ["\240\159\167\173"] = "●", ["\240\159\164\157"] = "↔",
    ["\240\159\143\170"] = "◆", ["\226\154\148"] = "✚", ["\240\159\167\170"] = "●",
    ["\240\159\166\133"] = "◆", ["\240\159\142\173"] = "●", ["\240\159\154\169"] = "▲",
    ["\240\159\151\132"] = "◆", ["\240\159\146\188"] = "◆", ["\240\159\148\171"] = "◆",
    ["\240\159\147\156"] = "◆", ["\226\157\132"] = "◆", ["\240\159\148\145"] = "●",
    ["\240\159\146\176"] = "●", ["\240\159\147\161"] = "●", ["\240\159\170\150"] = "◆",
    ["\226\152\163"] = "⚠", ["\240\159\169\185"] = "✚", ["\240\159\150\165"] = "●",
    ["\240\159\165\171"] = "●", ["\226\153\153"] = "◆", ["\226\152\190"] = "●",
    ["\240\159\142\150"] = "★", ["\240\159\148\135"] = "✖", ["\240\159\145\164"] = "●",
    ["\240\159\148\138"] = "●", ["\226\136\179"] = "◆", ["\240\159\148\180"] = "●",
    ["\240\159\151\139"] = "●", ["\240\159\145\132"] = "○", ["\240\159\134\149"] = "★",
    ["\240\159\143\134"] = "★", ["\240\159\146\161"] = "●", ["\240\159\148\166"] = "●",
    ["\226\132\155"] = "●", ["\226\132\158"] = "●", ["\240\159\146\190"] = "◆",
    ["\240\159\147\159"] = "◆", ["\226\152\162"] = "⚠", ["\226\152\160"] = "♠",
    ["\240\159\142\175"] = "◎", ["\240\159\154\170"] = "▲", ["\226\153\163"] = "▲",
    ["\240\159\155\176"] = "●", ["\240\159\151\175"] = "●", ["\240\159\167\145"] = "●",
    ["\226\157\165"] = "♥", ["\226\153\160"] = "◆", ["\226\153\179"] = "◆",
    ["\226\153\168"] = "♪", ["\240\159\148\157"] = "●", ["\240\159\148\155"] = "●",
    ["\226\152\181"] = "✚", ["\226\153\187"] = "⟳", ["\226\132\162"] = "◆",
    ["\240\159\147\157"] = "◆", ["\240\159\147\141"] = "◆", ["\240\159\147\138"] = "◆",
    ["\240\159\145\145"] = "●", ["\240\159\145\146"] = "●", ["\240\159\145\168"] = "●",
    ["\240\159\145\177"] = "●", ["\240\159\145\189"] = "●", ["\240\159\145\190"] = "●",
    ["\226\157\160"] = "♥", ["\226\157\161"] = "♥", ["\226\157\164"] = "♥",
    ["\240\159\146\152"] = "●", ["\240\159\146\153"] = "●", ["\240\159\146\154"] = "●",
    ["\240\159\146\155"] = "●", ["\240\159\146\156"] = "●", ["\240\159\146\157"] = "●",
    ["\240\159\146\158"] = "●", ["\240\159\146\159"] = "●", ["\240\159\148\132"] = "●",
    ["\226\152\163"] = "", -- v5.7.3: знак опасности ☣ УДАЛЁН (не палить Нечто)
}

local function Sanitize(str)
    if not isstring(str) then return str end
    if not str:find("[\226-\240]") then return str end
    for from, to in pairs(REPL) do
        str = string.gsub(str, from, to)
    end
    return str
end

local function ApplyEmojiFix()
    if P11F565_Emoji then return end P11F565_Emoji = true
    local origST = draw.SimpleText
    draw.SimpleText = function(text, font, x, y, col, xa, ya, nb, sh)
        if isstring(text) then text = Sanitize(text) end
        return origST(text, font, x, y, col, xa, ya, nb, sh)
    end
    local origSTO = draw.SimpleTextOutlined
    draw.SimpleTextOutlined = function(text, ...)
        if isstring(text) then text = Sanitize(text) end
        return origSTO(text, ...)
    end
    local origSet = DLabel.SetText
    DLabel.SetText = function(self, t)
        if isstring(t) then t = Sanitize(t) end
        return origSet(self, t)
    end
    print("[POLUS-11] v5.6.5: квадратики заменены на Юникод-знаки")
end

-- ================= 7) ОПИСАНИЕ ИГРОКА — ВНИЗУ (у ног), НЕ НАД ГОЛОВОЙ =================
local function InstallNametags()
    if P11F565_Name then return end P11F565_Name = true
    -- удаляем оригинальный хук намиков (чтобы не рисовался дважды)
    local t = hook.GetTable()
    local h = t and t["HUDPaint"]
    if h then h["P11_Nametags"] = nil end
end
-- ============================================================
--  ПОЛЮС-11 — таблички с именами (client) v4.4.0 «ОРДЕН» (v4.27.0)
--  Вместо «ванильного ника и ХП»:
--   • всегда — СЕРВЕРНЫЙ позывной бойца (анкета) поверх головы;
--   • кто смотрит В УПОР — под именем ПЛАВНО проявляется
--     ОПИСАНИЕ внешности (анкета «дело бойца»);
--   • приоритет имени: личина Нечто → позывной → стим-ник;
--     приоритет описания: украденное жертвой → своё;
--   • розыск мигание, должность+фракция, ранг с FX, динамик.
-- ============================================================

surface.CreateFont("P11.Tag.Desc", { font = "Roboto", size = 14, weight = 500, extended = true })

-- отображаемое имя: личина > позывной > ник
local function TagName(ply)
    local f = ply:GetNWString("P11_FakeNick", "")
    if f ~= "" then return f end
    local c = ply:GetNWString("P11_CharName", "")
    if c ~= "" then return c end
    return ply:Nick()
end

-- отображаемое описание: украденное жертвой > своё
local function TagDesc(ply)
    local f = ply:GetNWString("P11_FakeDesc", "")
    if f ~= "" then return f end
    return ply:GetNWString("P11_CharDesc", "")
end

-- перенос описания на строки по ширине
local function WrapDesc(txt, font, maxW)
    surface.SetFont(font)
    local lines, cur = {}, ""
    for word in string.gmatch(txt, "%S+") do
        local probe = (cur == "") and word or (cur .. " " .. word)
        if (surface.GetTextSize(probe) or 0) > maxW and cur ~= "" then
            lines[#lines + 1] = cur
            cur = word
            if #lines >= 3 then break end
        else
            cur = probe
        end
    end
    if cur ~= "" and #lines < 3 then lines[#lines + 1] = cur end
    -- если что-то не влезло — многоточие
    local joined = table.concat(lines, " ")
    if #joined < #txt and #lines > 0 then
        lines[#lines] = lines[#lines] .. "…"
    end
    return lines
end

-- состояние фокуса «смотрю на человека»
P11.FocusTag = P11.FocusTag or { ent = nil, a = 0 }

hook.Add("HUDPaint", "P11_Nametags565", function()
    if not POLUS11.Config.Nametags then return end

    local me = LocalPlayer()
    if not IsValid(me) or not me:EyePos() then return end

    -- ---- кто в фокусе прицела ----
    local focus = nil
    local tr = me:GetEyeTrace()
    local te = tr.Entity
    if IsValid(te) and te:IsPlayer() and te:Alive() and te ~= me
    and me:GetPos():DistToSqr(te:GetPos()) < 700 * 700 then
        focus = te
    end

    local F = P11.FocusTag
    if F.ent ~= focus then F.ent = focus F.a = 0 end
    F.a = Lerp(math.min(FrameTime() * 5, 1), F.a or 0, focus and 1 or 0)

    for _, ply in ipairs(player.GetAll()) do
        if ply ~= me and IsValid(ply) and ply:Alive() then
            local dist = me:GetPos():DistToSqr(ply:GetPos())
            if dist < 450 * 450 then
                -- видим ли мы его
                local tr2 = util.TraceLine({
                    start  = me:EyePos(),
                    endpos = ply:EyePos(),
                    filter = {me, ply},
                })

                if not tr2.Hit or tr2.Entity == ply then
                    local pos = (ply:EyePos() + Vector(0, 0, 14)):ToScreen()
                    if pos.visible then
                        local frac = 1 - (math.sqrt(dist) / 450)
                        local a = math.Clamp(frac * 255, 40, 255)
                        local name = TagName(ply)
                        local col = Color(235, 238, 245, a)

                        -- РОЗЫСК мигает красным над головой
                        local wanted = ply:GetNWString("P11_Wanted", "")
                        if wanted ~= "" then
                            local blink = 0.5 + math.sin(CurTime() * 6) * 0.5
                            draw.SimpleTextOutlined("⚠ РОЗЫСК", "P11.HUD.Text", pos.x, pos.y - 44,
                                Color(255, 70, 60, a * (0.45 + blink * 0.55)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
                                2, Color(0, 0, 0, a * 0.8))
                        end

                        draw.SimpleTextOutlined(name, "P11.HUD.Mid", pos.x, pos.y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a * 0.8))

                        -- должность (+ фракция) под именем
                        local bottomY = 6
                        if P11FW and P11FW.GetJobName then
                            -- v4.2.1: нечто в чужой шкуре носит ДОЛЖНОСТЬ ЖЕРТВЫ
                            local job = nil
                            do
                                local fj = ply:GetNWInt("P11_FakeJob", 0)
                                if fj > 0 and P11FW.TeamJobs then
                                    local jid = P11FW.TeamJobs[fj]
                                    if jid then job = P11FW.Jobs[jid] end
                                end
                                if not job then job = P11FW.GetJob(ply) end
                            end
                            local jn = (job and job.name) or ""
                            if jn ~= "" then
                                bottomY = 30
                                local jc = (job and job.color) or Color(150, 190, 235)
                                local facName = nil
                                if job and P11FW.CategoryList then
                                    local cid = job.faction or job.category
                                    for _, c in ipairs(P11FW.CategoryList) do
                                        if c.id == cid then facName = c.name break end
                                    end
                                end
                                local line = facName and (facName .. " · " .. jn) or jn
                                draw.SimpleTextOutlined(line, "P11.HUD.Text", pos.x, pos.y + 30, Color(jc.r, jc.g, jc.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a * 0.8))
                            end
                        end

                        -- ранг администрации под должностью (Хелпер+), старшие — переливаются
                        if P11FW and P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 2 then
                            bottomY = 56
                            local rc = P11FW.RankFxColor and P11FW.RankFxColor(ply) or P11FW.GetRankColor(ply)
                            if P11FW.RankHasFx and P11FW.RankHasFx(ply) then
                                local pulse = 0.35 + math.sin(CurTime() * 2.6) * 0.15
                                draw.SimpleTextOutlined("◆ " .. P11FW.GetRankName(ply), "P11.HUD.Text",
                                    pos.x, pos.y + 56, Color(rc.r, rc.g, rc.b, a * pulse),
                                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, Color(rc.r, rc.g, rc.b, a * 0.55))
                            end
                            draw.SimpleTextOutlined("◆ " .. P11FW.GetRankName(ply), "P11.HUD.Text",
                                pos.x, pos.y + 56, Color(rc.r, rc.g, rc.b, a),
                                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a * 0.8))
                        end

                        -- v4.27.0 «ОРДЕН»: НАГРАДНАЯ ПЛАНКА НАД ником —
                        -- фишки цвета знака на тёмной подложке, пульс-шиммер
                        if P11 and P11.MedalCells then
                            local okM, cells, total = pcall(P11.MedalCells, ply, 4)
                            if okM and cells and #cells > 0 then
                                local nch = #cells + ((total > #cells) and 1 or 0)
                                local wAll = nch * 22 - 2
                                local cy2 = pos.y - (wanted ~= "" and 56 or 34)
                                local lx = pos.x - wAll / 2
                                draw.RoundedBox(6, lx - 5, cy2 - 2, wAll + 10, 24,
                                    Color(8, 12, 18, a * 0.55))
                                for i, c in ipairs(cells) do
                                    local bx = lx + (i - 1) * 22
                                    draw.RoundedBox(4, bx, cy2, 20, 20,
                                        Color(c.col.r, c.col.g, c.col.b, a * 0.16))
                                    draw.RoundedBoxEx(4, bx, cy2, 20, 3,
                                        Color(c.col.r, c.col.g, c.col.b, a * 0.85), true, true, false, false)
                                    surface.SetDrawColor(c.col.r, c.col.g, c.col.b,
                                        a * (0.40 + 0.18 * math.sin(CurTime() * 2.4 + i * 1.2)))
                                    surface.DrawOutlinedRect(bx, cy2, 20, 20, 1)
                                    draw.SimpleText(c.g, "P11.HUD.Text", bx + 10, cy2 + 11,
                                        Color(c.col.r, c.col.g, c.col.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                                end
                                if total > #cells then
                                    local bx = lx + #cells * 22
                                    draw.RoundedBox(4, bx, cy2, 20, 20, Color(255, 205, 100, a * 0.14))
                                    draw.SimpleText("+" .. (total - #cells), "P11.Tag.Desc", bx + 10, cy2 + 11,
                                        Color(255, 205, 100, a * 0.95), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                                end
                            end
                        end

                        -- динамик говорящего — ПОД табличкой
                        if ply.IsSpeaking and ply:IsSpeaking() then
                            local pulse = 0.55 + math.sin(CurTime() * 10) * 0.45
                            draw.SimpleTextOutlined("🔊", "P11.HUD.Text", pos.x, pos.y + bottomY + 24,
                                Color(130, 220, 250, a * pulse), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
                                2, Color(0, 0, 0, a * 0.7))
                        end
                    end
                end
            end
        end
    end

    -- ---- v4.3.0: ФОКУС-КАРТОЧКА — позывной + описание, плавное проявление ----
    if IsValid(F.ent) and F.ent:IsPlayer() and F.ent:Alive() and (F.a or 0) > 0.03 then
        local ply = F.ent
        local pos = (ply:GetPos() + Vector(0, 0, 2)):ToScreen() -- v5.6.5: карточка у ног игрока
        if pos.visible then
            local a = math.Clamp((F.a or 0) * 255, 0, 255)
            local name = TagName(ply)
            local desc = TagDesc(ply)

            surface.SetFont("P11.HUD.Mid")
            local wName = surface.GetTextSize(name) or 80
            local lines = desc ~= "" and WrapDesc(desc, "P11.Tag.Desc", 300) or {}
            local wDesc = 0
            for _, ln in ipairs(lines) do
                surface.SetFont("P11.Tag.Desc")
                local wl = surface.GetTextSize(ln) or 0
                if wl > wDesc then wDesc = wl end
            end
            -- v4.27.0 «ОРДЕН»: фишки медалей в фокус-карте
            local fCells, fTotal = {}, 0
            if P11 and P11.MedalCells then
                local okM, cc, tt = pcall(P11.MedalCells, ply, 8)
                if okM and cc then fCells, fTotal = cc, tt end
            end
            local medH = (#fCells > 0) and 28 or 0
            local wBox = math.max(wName, wDesc, #fCells * 22 + 8) + 28
            local hBox = 26 + medH + (#lines > 0 and (#lines * 17 + 8) or 0)
            pos.y = pos.y - hBox + 10 -- v5.6.5: карточка стоит НАД ногами (низ игрока)

            -- карточка-затемнение за текстом
            draw.RoundedBox(8, pos.x - wBox / 2, pos.y - 10, wBox, hBox, Color(8, 12, 18, a * 0.62))
            surface.SetDrawColor(120, 185, 255, a * 0.35)
            surface.DrawOutlinedRect(pos.x - wBox / 2, pos.y - 10, wBox, hBox, 1)

            draw.SimpleTextOutlined("«" .. name .. "»", "P11.HUD.Mid", pos.x, pos.y + 3,
                Color(240, 246, 252, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a * 0.7))

            local yy = pos.y + 20
            -- v4.27.0: фишки медалей под позывным
            if #fCells > 0 then
                local nch = #fCells + ((fTotal > #fCells) and 1 or 0)
                local lx = pos.x - (nch * 22 - 2) / 2
                for i, c in ipairs(fCells) do
                    local bx = lx + (i - 1) * 22
                    draw.RoundedBox(4, bx, yy - 2, 20, 20,
                        Color(c.col.r, c.col.g, c.col.b, a * 0.18))
                    draw.RoundedBoxEx(4, bx, yy - 2, 20, 3,
                        Color(c.col.r, c.col.g, c.col.b, a * 0.9), true, true, false, false)
                    draw.SimpleText(c.g, "P11.HUD.Text", bx + 10, yy + 9,
                        Color(c.col.r, c.col.g, c.col.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                if fTotal > #fCells then
                    local bx = lx + #fCells * 22
                    draw.RoundedBox(4, bx, yy - 2, 20, 20, Color(255, 205, 100, a * 0.15))
                    draw.SimpleText("+" .. (fTotal - #fCells), "P11.Tag.Desc", bx + 10, yy + 9,
                        Color(255, 205, 100, a * 0.95), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                yy = yy + 28
            end
            for _, ln in ipairs(lines) do
                draw.SimpleTextOutlined(ln, "P11.Tag.Desc", pos.x, yy,
                    Color(205, 215, 228, a * 0.95), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, a * 0.6))
                yy = yy + 17
            end
        end
    end
end)


-- ================= 3) ОКНО «ВЫДАЧА ОПЫТА» (клиент) =================
local function XPWindow()
    P11 = P11 or {}
    if IsValid(P11.XPFrame) then P11.XPFrame:Remove() end

    local me = LocalPlayer()
    if not IsValid(me) then return end

    local W, H = 560, 520
    local f = vgui.Create("DFrame")
    P11.XPFrame = f
    f:SetSize(W, H)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)
    f.T0 = SysTime()
    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, s.T0)
        draw.RoundedBox(8, 0, 0, w, h, Color(10, 14, 20, 248))
        draw.RoundedBoxEx(8, 0, 0, w, 56, Color(30, 36, 46, 255), true, true, false, false)
        surface.SetDrawColor(210, 60, 50)
        surface.DrawRect(0, 56, w, 3)
        surface.SetDrawColor(238, 202, 108)
        surface.DrawRect(0, 59, w, 1)
        draw.SimpleText("ВЫДАЧА ОПЫТА", "DermaDefaultBold", 16, 18, Color(255, 205, 100))
        draw.SimpleText("выбери бойца, введи кол-во и нажми кнопку", "DermaDefault", 16, 38, Color(150, 158, 172))
    end
    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then s:Remove() end
    end

    local xb = vgui.Create("DButton", f)
    xb:SetPos(W - 38, 12) xb:SetSize(26, 26) xb:SetText("X")
    xb.Paint = function() end
    xb.DoClick = function() f:Remove() end

    -- список бойцов
    local lv = vgui.Create("DListView", f)
    lv:SetPos(10, 66) lv:SetSize(W - 20, 280)
    lv:AddColumn("Боец"):SetFixedWidth(180)
    lv:AddColumn("Профессия"):SetFixedWidth(120)
    lv:AddColumn("Стаж, мин"):SetFixedWidth(70)
    lv:AddColumn("Опыт службы"):SetFixedWidth(90)
    lv:SetMultiSelect(false)
    for _, pl in ipairs(player.GetAll()) do
        local nick = pl:GetNWString("P11_CharName", "")
        if nick == "" then nick = pl:Nick() end
        local job = (P11FW and P11FW.GetJobName and P11FW.GetJobName(pl)) or ""
        local st = (POLUS11 and POLUS11.GetPlayMin and POLUS11.GetPlayMin(pl)) or 0
        local xp = pl:GetNWInt("P11_SkillXP", 0)
        local line = lv:AddLine(nick, job, st, xp)
        line.sid = pl:SteamID()
        line.nick = pl:Nick()
    end

    -- кол-во
    local amt = vgui.Create("DTextEntry", f)
    amt:SetPos(10, 356) amt:SetSize(120, 30)
    amt:SetText("100")

    local lbl = vgui.Create("DLabel", f)
    lbl:SetPos(140, 358) lbl:SetSize(300, 24)
    lbl:SetText("Кол-во (опыт/XP/минут)")

    -- кнопки
    local function DoGive(mode, label)
        local line = lv:GetSelectedLine() and lv:GetLine(lv:GetSelectedLine())
        if not line then
            chat.AddText(Color(255, 120, 110), "[ОПЫТ] ", Color(232, 238, 245), "Сначала выбери бойца.")
            return
        end
        local n = tonumber(amt:GetValue() or "")
        if not n or n <= 0 then
            chat.AddText(Color(255, 120, 110), "[ОПЫТ] ", Color(232, 238, 245), "Введи положительное число.")
            return
        end
        net.Start("P11_XPAct")
            net.WriteUInt(mode, 2)
            net.WriteString(line.nick)
            net.WriteUInt(math.min(math.floor(n), 999999), 20)
        net.SendToServer()
        chat.AddText(Color(110, 215, 140), "[ОПЫТ] ", Color(232, 238, 245),
            label .. " → " .. line.nick .. " (+" .. math.floor(n) .. ")")
        surface.PlaySound("buttons/button15.wav")
        f:Remove()
    end

    local b1 = vgui.Create("DButton", f)
    b1:SetPos(10, 396) b1:SetSize(W - 20, 34) b1:SetText("ОПЫТ СЛУЖБЫ (древо)")
    b1.DoClick = function() DoGive(1, "Опыт службы") end

    local b2 = vgui.Create("DButton", f)
    b2:SetPos(10, 436) b2:SetSize(W - 20, 34) b2:SetText("XP БАТЛ-ПАССА")
    b2.DoClick = function() DoGive(2, "XP батл-пасса") end

    local b3 = vgui.Create("DButton", f)
    b3:SetPos(10, 476) b3:SetSize(W - 20, 34) b3:SetText("СТАЖ / ВРЕМЯ (минуты)")
    b3.DoClick = function() DoGive(3, "Стаж") end
end

net.Receive("P11_XPOpen", function()
    Safe(XPWindow, "окно опыта")
end)

-- ================= ПРИМЕНЕНИЕ ПОСЛЕ ГЕЙММОДА =================
local function ApplyAll()
    Safe(ApplyWhiteText, "белый текст")
    Safe(ApplySmooth, "плавное появление")
    Safe(ApplyHideVanilla, "ванильные ники/ХП")
    Safe(ApplyEmojiFix, "квадратики")
    Safe(InstallNametags, "намики вниз")
    Safe(InstallNullPanelGuard, "NULL Panel guard")
    Safe(CutMedals, "медали насмерть")
    Safe(FixAdmin, "фикс админки")
    Safe(ApplyJobName, "!Профа")
    Safe(UnmarkThing, "не палить Нечто")
    Safe(ComplexHud, "HUD комплекса")
    Safe(FixVoiceNames, "голос-маскировка")
    Safe(function()
        -- копия намиков (с описанием внизу) добавляется самим чанком выше
    end, "намики")
end

hook.Add("PostGamemodeLoaded", "P11.565", function()
    timer.Simple(0, ApplyAll)
    timer.Simple(1, ApplyAll)
    timer.Simple(2, ApplyAll)
    timer.Simple(5, ApplyAll)
end)
hook.Add("InitPostEntity", "P11.565b", function()
    timer.Simple(1, ApplyAll)
    timer.Simple(3, ApplyAll)
end)
timer.Simple(0, ApplyAll)
timer.Simple(1, ApplyAll)
timer.Simple(2, ApplyAll)



-- ================= 9) МЕДАЛИ — ВЫРЕЗАНЫ НАСМЕРТЬ (v5.7.0) =================
-- Владелец: «медали насмерть вырежи — TAB, вкладку, остальное».
-- Заглушки: P11.MedalCells/MedalTop/MedalScopeLocal/MedalAwardMenu —
-- все возвращают пусто/нил → TAB не рисует ни ленту, ни доску почёта,
-- ни карточку, ни кнопку «Вручить медаль». Вкладка «МЕДАЛИ» в админке
-- уже показывает «медали отключены» (заглушка MedalTabBuild).
local function CutMedals()
    P11 = P11 or {}
    P11.MedalIds        = function() return {} end
    P11.MedalGlyphs     = function() return "", 0 end
    P11.MedalColorOf    = function() return Color(150, 158, 172) end
    P11.MedalCells      = function() return {}, 0 end
    P11.MedalTop        = function() return {} end
    P11.MedalScopeLocal = function() return nil end
    P11.MedalAwardMenu  = function() end
    print("[POLUS-11] v5.7.0: медали вырезаны насмерть (TAB/вкладка/кнопки)")
end

-- ================= 7b) ФИКС АДМИНКИ: SetAutoWrapVertical (v5.7.1) =================
-- fw_cl_admin.lua:2230 зовёт DLabel:SetAutoWrapVertical — метода НЕТ
-- в GMod → админка падает при открытии. Доопределяем метод (обёртка
-- на штатные SetWrap + SetAutoStretchVertical). Было в v5.2.3, потерялось
-- при откате UI — возвращаем сюда (доставка через энтити гарантирована).
local function FixAdmin()
    if DLabel and not DLabel.SetAutoWrapVertical then
        DLabel.SetAutoWrapVertical = function(self, b)
            if self.SetWrap then self:SetWrap(b) end
            if self.SetAutoStretchVertical then self:SetAutoStretchVertical(b) end
        end
    end
    print("[POLUS-11] v5.7.1: фикс админки SetAutoWrapVertical восстановлен")
end





-- ================= 13) ГОЛОС: МАСКИРОВАННОЕ ИМЯ ВМЕСТО ВАНИЛЬНОГО (v5.7.5) =================
-- Владелец: «когда ты за Нечто и маскировался — в голосе ты
-- отображаешься как старый человек». Ванильный GMod voice-индикатор
-- (CHudVoiceStatus / CHudVoiceSelfStatus) показывает Steam-ник.
-- Решение: скрываем ванильные voice-элементы и рисуем СВОЙ
-- индикатор: если у игрока маскировка (P11_FakeNick) — показываем
-- её, иначе обычный ник. Только для своего голоса (SelfStatus).
local function FixVoiceNames()
    hook.Add("HUDShouldDraw", "P11.HideVoice", function(name)
        if name == "CHudVoiceStatus" or name == "CHudVoiceSelfStatus" then
            return false
        end
    end)

    -- свой voice-индикатор (слева внизу, как ванильный)
    hook.Add("HUDPaint", "P11.MyVoiceName", function()
        local me = LocalPlayer()
        if not IsValid(me) or not me:Alive() then return end
        local spk = me.IsSpeaking and me:IsSpeaking() or false
        if not spk then return end

        local name = me:GetNWString("P11_FakeNick", "")
        if name == "" then name = me:GetNWString("P11_CharName", "") end
        if name == "" then name = me:Nick() end

        local x, y = 20, ScrH() - 64
        draw.RoundedBox(6, x, y, 220, 30, Color(10, 14, 20, 210))
        surface.SetDrawColor(110, 215, 140, 160)
        surface.DrawOutlinedRect(x, y, 220, 30, 1)
        draw.SimpleText("ГОВОРИТ: " .. name, "DermaDefaultBold", x + 10, y + 15,
            Color(235, 240, 248), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)
    print("[POLUS-11] v5.7.5: голос показывает маскированное имя (ванильный ник скрыт)")
end

-- ================= 12) СОСТОЯНИЕ КОМПЛЕКСА — HUD (v5.7.4) =================
-- Показывает текущее состояние комплекса (глобальная P11_ComplexState):
-- Всё нормально / Атака / Выход НКВД / Собрание / Конец комплекса.
-- Рисуется под фазой (справа вверху). Цвет зависит от статуса.
local function ComplexHud()
    hook.Add("HUDPaint", "P11.ComplexHud", function()
        local w = ScrW()
        local state = GetGlobalString("P11_ComplexState", "")
        if state == "" then return end
        local col = Color(110, 215, 140) -- нормально
        if state == "Атака" then col = Color(240, 80, 70)
        elseif state == "Выход НКВД" then col = Color(200, 165, 90)
        elseif state == "Собрание" then col = Color(150, 200, 255)
        elseif state == "Конец комплекса" then col = Color(220, 120, 220) end

        surface.SetFont("P11.HUD.Text")
        local tw = surface.GetTextSize("Комплекс: " .. state)
        local y = 38 -- под фазой
        draw.RoundedBox(4, w - 18 - tw - 14, y, tw + 14, 24, Color(10, 13, 18, 170))
        surface.SetDrawColor(col.r, col.g, col.b, 80)
        surface.DrawOutlinedRect(w - 18 - tw - 14, y, tw + 14, 24, 1)
        draw.SimpleText("Комплекс: " .. state, "P11.HUD.Text", w - 18, y + 2,
            Color(col.r, col.g, col.b, 235), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end)
    print("[POLUS-11] v5.7.4: HUD «Состояние комплекса» активен")
end

-- ================= 11) НЕ ПАЛИТЬ НЕЧТО (v5.7.3) =================
-- Владелец: «убери знак опасности для заражённого — сразу понятно,
-- кто Нечто, атмосфера портится».
-- 1) Hive-метки «НЕЧТО» над заражёнными (p11_cl_hud P11_Hive) — УБРАНЫ;
-- 2) ☣ в TAB у заражённых — убран через REPL выше.
local function UnmarkThing()
    hook.Remove("HUDPaint", "P11_Hive")
    print("[POLUS-11] v5.7.3: метки «НЕЧТО» над заражёнными убраны (Hive) + ☣ удалён")
end

-- ================= 10) !ПРОФА: ПЕРСОНАЛЬНОЕ НАЗВАНИЕ ПРОФЫ (v5.7.1) =================
local function ApplyJobName()
    if P11F571_JobName then return end P11F571_JobName = true
    if P11FW and P11FW.GetJobName then
        local orig = P11FW.GetJobName
        P11FW.GetJobName = function(ply)
            if IsValid(ply) then
                local custom = ply:GetNWString("P11_JobName", "")
                if custom ~= "" then return custom end
            end
            return orig(ply)
        end
        print("[POLUS-11] v5.7.1: !Профа — персональное название профы работает (намики/TAB)")
    end
end

-- ================= 8) ЗАЩИТА ОТ "NULL Panel" (spawnmenu и др.) v5.6.9 =================
-- Ошибка: spawnmenu.lua:44 Tried to use a NULL Panel при клике по кнопке
-- (панель уже удалена). Лечим глобально: перехват Panel:SetVisible и
-- DLabel:DSetText — если панель мертва, тихо пропускаем (без краша).
local function InstallNullPanelGuard()
    -- Panel:SetVisible — если панель мертва, не падаем
    local PanelMeta = FindMetaTable("Panel")
    if PanelMeta and PanelMeta.SetVisible then
        local origSV = PanelMeta.SetVisible
        PanelMeta.SetVisible = function(self, ...)
            if not IsValid(self) then return end
            return origSV(self, ...)
        end
    end
    -- DLabel:SetText — если панель мертва, не падаем
    if PanelMeta and PanelMeta.SetText then
        local origSTxt = PanelMeta.SetText
        PanelMeta.SetText = function(self, ...)
            if not IsValid(self) then return end
            return origSTxt(self, ...)
        end
    end
    -- защита DoClick спавнменю: оборачиваем DImageButton.DoClick
    local ib = vgui.GetControlTable and vgui.GetControlTable("DImageButton")
    if ib and ib.DoClick then
        local origClick = ib.DoClick
        ib.DoClick = function(self, ...)
            if not IsValid(self) then return end
            return origClick(self, ...)
        end
    end
    print("[POLUS-11] v5.6.9: защита от NULL Panel (spawnmenu) установлена")
end

print("[POLUS-11] МАСТЕР-ФИКСЫ v5.6.5 активны: белый текст, плавные меню, выдача опыта, знаки, ники, описание внизу")
