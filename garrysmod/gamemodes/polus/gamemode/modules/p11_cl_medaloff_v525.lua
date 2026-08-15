-- ============================================================
--  ПОЛЮС-11 — МЕДАЛИ ОТКЛЮЧЕНЫ (client) v5.2.5 (НОВЫЙ ФАЙЛ)
--  Владелец: «медали вырезай полностью». Медальный модуль
--  (p11_cl_medals_v2) ОТКЛЮЧЁН от загрузки. Заглушка подменяет
--  весь клиентский медальный API на no-op: намики, TAB и админка
--  просто ничего не рисуют (у них guard'ы P11.MedalCells и т.п.),
--  вкладка «МЕДАЛИ» в админке показывает «медали отключены».
-- ============================================================

P11 = P11 or {}

-- помощники отрисовки — пустые
P11.MedalIds       = function() return {} end
P11.MedalGlyphs    = function() return "", 0 end
P11.MedalColorOf   = function() return Color(150, 158, 172) end
P11.MedalCells     = function() return {}, 0 end
P11.MedalTop       = function() return {} end
P11.MedalScopeLocal= function() return nil end

-- окно вручения — сообщение «отключено»
P11.MedalAwardMenu = function()
    chat.AddText(Color(255, 205, 100), "[ПОЧЁТ] ", Color(232, 238, 245), "Медали отключены (v5.2.5).")
end

-- вкладка МЕДАЛИ в админке — заглушка с текстом
P11FW.MedalsTabBuild = function(p)
    local l = vgui.Create("DLabel", p)
    l:SetPos(20, 30) l:SetSize(700, 60)
    l:SetFont("P11FW.Text")
    l:SetTextColor(Color(150, 158, 172))
    l:SetText("Медали отключены владельцем (v5.2.5).\nСистема наград убрана из сборки.")
end

print("[POLUS-11] МЕДАЛИ ВЫРЕЗАНЫ v5.2.5 (client): заглушка активна — намики/TAB/админка чисты")
