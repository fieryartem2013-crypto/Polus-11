-- ============================================================
--  ПОЛЮС-11 — T-POSE НПС: СЕРВЕРНЫЙ НАДЗОР v5.8.28
--  (НОВЫЙ ФАЙЛ). Старые init НПС не трогаем.
--  Корень T-pose: player-модели на base_anim часто встают в
--  seq=0 (reference), idle_subtle нет, Think раз в 0.5с не
--  крутит кадр. Ставим idle_all_01 / ACT_IDLE и
--  AutomaticFrameAdvance на таблицу класса.
-- ============================================================

local NPCS = {
    "polus_fw_jobnpc",
    "polus_p11_shopnpc",
    "polus_p11_dutynpc",
    "polus_p11_contractnpc",
    "polus_p11_jailnpc",
    "polus_p11_stashnpc",
    "polus11_avtosalon",
    "polus_p11_usasalon",
}

local IDLE_NAMES = {
    "idle_all_01", "idle_all_02", "menu_combine",
    "pose_standing_02", "idle_subtle", "idle",
    "cidle_all", "idle_subtle_01",
}

local function PickIdle(ent)
    if not IsValid(ent) then return nil end
    if ent.SelectWeightedSequence then
        local ok, seq = pcall(ent.SelectWeightedSequence, ent, ACT_IDLE)
        if ok and isnumber(seq) and seq > 0 then return seq end
        ok, seq = pcall(ent.SelectWeightedSequence, ent, ACT_IDLE_ANGRY)
        if ok and isnumber(seq) and seq > 0 then return seq end
    end
    if ent.LookupSequence then
        for _, name in ipairs(IDLE_NAMES) do
            local ok, seq = pcall(ent.LookupSequence, ent, name)
            if ok and isnumber(seq) and seq >= 0 then return seq end
        end
    end
    return nil
end

local function PoseOne(ent)
    if not IsValid(ent) then return end
    ent.AutomaticFrameAdvance = true
    local seq = ent.P11_IdleFixSeq
    if not seq or seq <= 0 then
        seq = PickIdle(ent)
        ent.P11_IdleFixSeq = seq
    end
    if not seq or seq <= 0 then return end
    local cur = -1
    if ent.GetSequence then
        local ok, c = pcall(ent.GetSequence, ent)
        if ok then cur = c end
    end
    -- 0 = T-pose / reference у player-моделей
    if cur ~= seq or cur == 0 then
        ent:ResetSequence(seq)
        ent:SetCycle(0)
        if ent.SetPlaybackRate then ent:SetPlaybackRate(1) end
    elseif ent.SetPlaybackRate then
        ent:SetPlaybackRate(1)
    end
    if ent.NextThink then ent:NextThink(CurTime()) end
end

local function PoseAll()
    for _, cls in ipairs(NPCS) do
        for _, e in ipairs(ents.FindByClass(cls)) do
            PoseOne(e)
        end
    end
end

local function PatchClassTables()
    if not scripted_ents or not scripted_ents.GetStored then return end
    for _, cls in ipairs(NPCS) do
        local st = scripted_ents.GetStored(cls)
        if st and st.t then
            st.t.AutomaticFrameAdvance = true
            if not st.t.P11_PosePatched then
                st.t.P11_PosePatched = true
                local old = st.t.Think
                st.t.Think = function(self)
                    self.AutomaticFrameAdvance = true
                    if self.FrameAdvance then pcall(self.FrameAdvance, self) end
                    PoseOne(self)
                    if old then
                        local ok = pcall(old, self)
                        if not ok then end
                    end
                    if self.NextThink then self:NextThink(CurTime()) end
                    return true
                end
            end
        end
    end
end

hook.Add("InitPostEntity", "P11.NpcPose.v5828", function()
    timer.Simple(1, PatchClassTables)
    timer.Simple(1.2, PoseAll)
end)
hook.Add("OnEntityCreated", "P11.NpcPose.New.v5828", function(ent)
    if not IsValid(ent) then return end
    local cls = ent:GetClass()
    local want = false
    for _, c in ipairs(NPCS) do if c == cls then want = true break end end
    if not want then return end
    timer.Simple(0.15, function() PoseOne(ent) end)
    timer.Simple(0.80, function() PoseOne(ent) end)
end)
hook.Add("PostCleanupMap", "P11.NpcPose.Clean.v5828", function()
    timer.Simple(2, PoseAll)
end)

timer.Create("P11.NpcPose.Tick.v5828", 1.5, 0, PoseAll)

print("[POLUS-11] v5.8.28: надзор стоек НПС (T-pose) — сервер")
