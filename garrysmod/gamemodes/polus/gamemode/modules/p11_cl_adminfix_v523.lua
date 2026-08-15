-- ============================================================
--  ПОЛЮС-11 — ФИКС АДМИН-ПАНЕЛИ (client) v5.2.3 (НОВЫЙ ФАЙЛ)
--  Баг: fw_cl_admin.lua зовёт DLabel:SetAutoWrapVertical(true) —
--  такого метода в GMod НЕТ → «attempt to call a nil value»
--  при каждом открытии админки.
--  Решение БЕЗ правки старого файла: доопределяем недостающий
--  метод на классе DLabel в рантайме (клиент). Он просто вызывает
--  штатные SetWrap + SetAutoStretchVertical — визуально идентично.
--  Если метод появится в движке — наш не перезапишет его.
-- ============================================================

if CLIENT and DLabel then
    DLabel.SetAutoWrapVertical = DLabel.SetAutoWrapVertical or function(self, b)
        if self.SetWrap then self:SetWrap(b) end
        if self.SetAutoStretchVertical then self:SetAutoStretchVertical(b) end
    end
    print("[POLUS-11] фикс админки v5.2.3: DLabel:SetAutoWrapVertical доопределён (метод-обёртка)")
end
