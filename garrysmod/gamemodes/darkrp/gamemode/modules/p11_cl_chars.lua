-- ============================================================
--  ПОЛЮС-11 — АНКЕТА БОЙЦА (client) v4.3.0
--  Окно создания персонажа: ПОЗЫВНОЙ + ОПИСАНИЕ внешности.
--  Открывается по запросу сервера (первый заход) или по
--  /персонаж, /char, кнопке «🪪 Мой персонаж» в C-меню.
-- ============================================================

surface.CreateFont("P11.Char.Big",   { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("P11.Char.Med",   { font = "Roboto", size = 16, weight = 600, extended = true })
surface.CreateFont("P11.Char.Small", { font = "Roboto", size = 13, weight = 500, extended = true })

function P11.OpenCharUI()
    if IsValid(P11.CharFrame) then P11.CharFrame:Remove() end

    local me = LocalPlayer()

    -- окно: фирменный P11UI, с запасным путём
    local f
    local okF = pcall(function()
        f = P11UI.Frame("ЛИЧНОЕ ДЕЛО БОЙЦА", "позывной и внешность — видят все, кто смотрит на тебя", 480, 330, Color(120, 185, 255))
    end)
    if not okF or not IsValid(f) then
        f = vgui.Create("DFrame")
        f:SetSize(480, 330)
        f:Center()
        f:SetTitle("ЛИЧНОЕ ДЕЛО БОЙЦА")
    end
    P11.CharFrame = f
    f:MakePopup()
    f:SetDeleteOnClose(true)

    local oldName = me:GetNWString("P11_CharName", "")
    local oldDesc = me:GetNWString("P11_CharDesc", "")

    -- ---- позывной ----
    local l1 = vgui.Create("DLabel", f)
    l1:SetPos(18, 64) l1:SetSize(444, 18)
    l1:SetFont("P11.Char.Small") l1:SetTextColor(Color(150, 190, 230))
    l1:SetText("ПОЗЫВНОЙ (3–32 знака) — так тебя видят на станции:")

    local e1 = vgui.Create("DTextEntry", f)
    e1:SetPos(18, 86) e1:SetSize(444, 30)
    e1:SetFont("P11.Char.Med")
    e1:SetText(oldName)
    e1:SetPlaceholderText("напр.: ст. сержант КРАСНОВ")
    e1:SetUpdateOnType(true)

    local cnt1 = vgui.Create("DLabel", f)
    cnt1:SetPos(18, 118) cnt1:SetSize(444, 14)
    cnt1:SetFont("P11.Char.Small") cnt1:SetTextColor(Color(120, 130, 145))

    -- ---- описание ----
    local l2 = vgui.Create("DLabel", f)
    l2:SetPos(18, 142) l2:SetSize(444, 18)
    l2:SetFont("P11.Char.Small") l2:SetTextColor(Color(150, 190, 230))
    l2:SetText("ОПИСАНИЕ ВНЕШНОСТИ (до 140 знаков) — всплывает у смотрящего:")

    local e2 = vgui.Create("DTextEntry", f)
    e2:SetPos(18, 164) e2:SetSize(444, 74)
    e2:SetMultiline(true)
    e2:SetFont("P11.Char.Small")
    e2:SetText(oldDesc)
    e2:SetPlaceholderText("напр.: высокий, шрам через бровь, потёртый торговый полушубок, за пазухой — блокнот")
    e2:SetUpdateOnType(true)

    local cnt2 = vgui.Create("DLabel", f)
    cnt2:SetPos(18, 240) cnt2:SetSize(444, 14)
    cnt2:SetFont("P11.Char.Small") cnt2:SetTextColor(Color(120, 130, 145))

    -- ---- кнопки ----
    local bSave = vgui.Create("DButton", f)
    bSave:SetPos(18, 266) bSave:SetSize(300, 40)
    bSave:SetText("")

    local bLater = vgui.Create("DButton", f)
    bLater:SetPos(330, 266) bLater:SetSize(132, 40)
    bLater:SetText("")
    bLater.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, s:IsHovered() and Color(42, 50, 62, 255) or Color(26, 32, 42, 255))
        surface.SetDrawColor(110, 125, 145, 110)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("позже", "P11.Char.Med", w / 2, h / 2, Color(160, 170, 185),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    bLater.DoClick = function() f:Remove() end

    local function Validate()
        local name = string.Trim(e1:GetText() or "")
        local desc = string.Trim(e2:GetText() or "")
        cnt1:SetText(#name .. "/32 знака" .. (#name > 32 and " — лишнее отрежется" or ""))
        cnt2:SetText(#desc .. "/140 знаков" .. (#desc > 140 and " — лишнее отрежется" or ""))
        return #name >= 3
    end

    bSave.Paint = function(s, w, h)
        local can = Validate()
        local hov = s:IsHovered() and can
        draw.RoundedBox(8, 0, 0, w, h,
            can and (hov and Color(50, 80, 105, 255) or Color(34, 58, 78, 255))
                  or Color(30, 34, 42, 255))
        surface.SetDrawColor(120, 185, 255, can and 200 or 60)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("ЗАПИСАТЬ В ДЕЛО", "P11.Char.Med", w / 2, h / 2,
            can and Color(200, 230, 255) or Color(110, 118, 130),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    bSave.DoClick = function()
        local name = string.Trim(e1:GetText() or "")
        if #name < 3 then
            surface.PlaySound("buttons/button10.wav")
            return
        end
        surface.PlaySound("buttons/button15.wav")
        net.Start("P11_CharSave")
            net.WriteString(name)
            net.WriteString(string.Trim(e2:GetText() or ""))
        net.SendToServer()
        f:Remove()
    end

    Validate()
end

-- сервер попросил анкету (первый заход / правка)
-- v4.6.4: во время интро НИЧЕГО не открываем — ждём его конца,
-- чтобы меню не мешало заставке (по заявке владельца).
net.Receive("P11_CharAsk", function()
    timer.Create("P11.CharAskWaitIntro", 0.5, 0, function()
        if P11.IntroOpen then return end -- интро ещё идёт — ждём
        timer.Remove("P11.CharAskWaitIntro")
        P11.OpenCharUI()
    end)
end)

print("[POLUS-11] анкета бойца загружена")
