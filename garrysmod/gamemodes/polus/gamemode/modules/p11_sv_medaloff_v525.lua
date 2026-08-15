-- ============================================================
--  ПОЛЮС-11 — МЕДАЛИ ОТКЛЮЧЕНЫ (server) v5.2.5 (НОВЫЙ ФАЙЛ)
--  Владелец: «медали вырезай полностью, они не работают».
--  Медальные модули (p11_sv_medals / p11_sv_medals_v2) ОТКЛЮЧЕНЫ
--  от загрузки. Эта заглушка подменяет весь медальный API на
--  no-op, чтобы батл-пасс и другие системы не падали:
--  батл-пасс пишет медаль в таблицу — но она никому не шлётся
--  и нигде не рисуется.
-- ============================================================

POLUS11.MedalDefs    = {}
POLUS11.Medals       = {}
POLUS11.AutoStats    = {}
POLUS11.AutoMedals   = {}

-- весь API медалей — заглушки (ничего не делает, ничего не падает)
POLUS11.MedalPush        = function() end
POLUS11.MedalAward       = function(ply) POLUS11.Notify(ply, "Медали отключены (v5.2.5).") return false end
POLUS11.MedalRevoke      = function() return false end
POLUS11.MedalScope       = function() return nil end
POLUS11.MedalAutoGrant   = function() return false end
POLUS11.MedalStatEvent   = function() end

print("[POLUS-11] МЕДАЛИ ВЫРЕЗАНЫ v5.2.5: реестр/выдача/отображение отключены (заглушка активна)")
