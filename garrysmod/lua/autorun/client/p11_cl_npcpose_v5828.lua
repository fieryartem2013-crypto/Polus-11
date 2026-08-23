-- ============================================================
--  ПОЛЮС-11 — T-POSE НПС: КЛИЕНТСКИЙ КАДР v5.8.28
--  (НОВЫЙ ФАЙЛ). Крутим FrameAdvance каждый кадр у всех
--  станционных человечков — иначе player-модель замирает
--  в T-pose даже при правильной секвенции на сервере.
-- ============================================================

local NPCS = {
    ["polus_fw_jobnpc"] = true,
    ["polus_p11_shopnpc"] = true,
    ["polus_p11_dutynpc"] = true,
    ["polus_p11_contractnpc"] = true,
    ["polus_p11_jailnpc"] = true,
    ["polus_p11_stashnpc"] = true,
    ["polus11_avtosalon"] = true,
    ["polus_p11_usasalon"] = true,
}

local IDLE = { "idle_all_01", "idle_all_02", "menu_combine", "idle_subtle", "idle" }

local function PoseCl(ent)
    if not IsValid(ent) then return end
    ent.AutomaticFrameAdvance = true
    if ent.SetPlaybackRate then
        if ent:GetPlaybackRate() == 0 then ent:SetPlaybackRate(1) end
    end
    local cur = ent.GetSequence and ent:GetSequence() or 0
    if (not cur or cur <= 0) and ent.LookupSequence then
        for _, n in ipairs(IDLE) do
            local s = ent:LookupSequence(n)
            if isnumber(s) and s >= 0 then
                ent:ResetSequence(s)
                ent:SetCycle(0)
                break
            end
        end
    end
    if ent.FrameAdvance then pcall(ent.FrameAdvance, ent) end
    if ent.SetNextClientThink then ent:SetNextClientThink(CurTime()) end
end

hook.Add("Think", "P11.NpcPose.Cl.v5828", function()
    -- не каждый кадр по всей карте: раз в 0 — FrameAdvance нужен часто,
    -- но FindByClass дёшев при малом числе НПС (обычно < 15)
    for cls in pairs(NPCS) do
        for _, e in ipairs(ents.FindByClass(cls)) do
            PoseCl(e)
        end
    end
end)

print("[POLUS-11] v5.8.28: надзор стоек НПС (T-pose) — клиент")
