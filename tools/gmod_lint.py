#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gmod_lint.py — проверка сборки ПОЛЮС-11 НАСТОЯЩИМ движковым интерпретатором.

Уровень 1 (syntax):  каждый .lua компилируется в LuaJIT 2.1 / Lua 5.1 —
                     это ровно тот VM, что стоит в Garry's Mod.
Уровень 2 (load):    серверные+общие модули ВЫПОЛНЯЮТСЯ по порядку init.lua
                     на заглушках GMod-API — падают настоящие ошибки загрузки
                     («attempt to index nil», опечатка в глобале, неверный
                     порядок модулей), которых luac -p не видит.
Уровень 3 (hooks):   дёргаются hook.InitPostEntity / Initialize /
                     PostGamemodeLoaded / PostCleanupMap — там живёт сид
                     проф, спавн НПС и чтение сейвов.

Запуск:  /tmp/luaenv/bin/python tools/gmod_lint.py [--only-load]
(нужен:  pip install lupa)
"""
import os, re, sys, json
try:
    from lupa.luajit21 import LuaRuntime
    VM = "LuaJIT 2.1 (= VM Garry's Mod)"
except Exception:
    try:
        from lupa.lua51 import LuaRuntime
        VM = "Lua 5.1"
    except Exception:
        print("нужен lupa:  pip install lupa"); sys.exit(2)

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "garrysmod")
def _find_gm():
    base = os.path.join(ROOT, "gamemodes")
    for name in ("darkrp", "polus"):
        cand = os.path.join(base, name, "gamemode")
        if os.path.isdir(cand): return cand
    for d in sorted(os.listdir(base)):
        cand = os.path.join(base, d, "gamemode")
        if os.path.isdir(cand): return cand
    raise SystemExit("не найдена папка гейммода")
GM = _find_gm()

def luafiles():
    out = []
    for dp, dn, fn in os.walk(ROOT):
        for f in fn:
            if f.endswith(".lua"): out.append(os.path.join(dp, f))
    return sorted(out)

def rel(p): return os.path.relpath(p, ROOT).replace("\\", "/")

HELPER = r"""
function P11_Compile(src, name)
  local chunk, err = loadstring(src, name)
  if not chunk then return { ok = false, err = tostring(err) } end
  return { ok = true, err = "" }
end
function P11_RunChunk(src, name)
  local chunk, err = loadstring(src, name)
  if not chunk then return { ok = false, err = tostring(err), stage = "compile" } end
  local ok, err2 = pcall(chunk)
  if not ok then return { ok = false, err = tostring(err2), stage = "run" } end
  return { ok = true, err = "" }
end
function P11_HookErrors() return P11_HOOK_ERR end
"""

# ---------------- УРОВЕНЬ 1: СИНТАКСИС ----------------
def level_syntax(files):
    L = LuaRuntime(unpack_returned_tuples=True)
    L.execute(HELPER)
    bad = []
    for p in files:
        src = open(p, encoding="utf-8", errors="replace").read()
        try:
            r = L.eval("P11_Compile")(src, "@" + rel(p))
            if not r["ok"]:
                bad.append((rel(p), r["err"]))
        except Exception as e:
            bad.append((rel(p), str(e)))
    return bad

# ---------------- ЗАГЛУШКИ GMod API ----------------
STUBS = r'''
P11LOG = {}
local function log(...) local t={} for i=1,select('#',...) do t[#t+1]=tostring(select(i,...)) end P11LOG[#P11LOG+1]=table.concat(t," ") end
function P11_Logs() return P11LOG end

-- автозаглушка: любой неизвестный метод возвращает «безопасный» объект
local function autostub(name)
  local t = {}
  local mt = {}
  mt.__index = function(s, k)
     if k == "__isstub" then return true end
     local child = autostub(name .. "." .. tostring(k))
     rawset(s, k, child)
     return child
  end
  mt.__call = function(s, ...) return autostub(name .. "()") end
  mt.__tostring = function() return "<stub " .. name .. ">" end
  mt.__len = function() return 0 end
  mt.__add = function(a,b) return 0 end mt.__sub = function(a,b) return 0 end
  mt.__mul = function(a,b) return 0 end mt.__div = function(a,b) return 0 end
  mt.__lt = function(a,b) return false end mt.__le = function(a,b) return false end
  mt.__concat = function(a,b) return tostring(a)..tostring(b) end
  setmetatable(t, mt)
  return t
end

-- базовые типы GMod
local VMT = {}
VMT.__add = function(a,b) return Vector(a.x+b.x, a.y+b.y, a.z+b.z) end
VMT.__sub = function(a,b) return Vector(a.x-b.x, a.y-b.y, a.z-b.z) end
VMT.__mul = function(a,b) if type(a)=="number" then return Vector(b.x*a,b.y*a,b.z*a) end
  if type(b)=="number" then return Vector(a.x*b,a.y*b,a.z*b) end return 0 end
VMT.__div = function(a,b) local n = type(b)=="number" and b or 1 return Vector(a.x/n,a.y/n,a.z/n) end
VMT.__unm = function(a) return Vector(-a.x,-a.y,-a.z) end
VMT.__eq = function(a,b) return a.x==b.x and a.y==b.y and a.z==b.z end
VMT.__tostring = function(a) return a.x.." "..a.y.." "..a.z end
function Vector(x,y,z) local v=setmetatable({x=x or 0,y=y or 0,z=z or 0}, VMT)
  function v:Length() return math.sqrt(self.x^2+self.y^2+self.z^2) end
  function v:Length2D() return math.sqrt(self.x^2+self.y^2) end
  function v:Distance(o) return 0 end function v:DistToSqr(o) return 0 end
  function v:GetNormalized() return v end function v:Normalize() return v end
  function v:Dot(o) return 0 end function v:Cross(o) return v end
  function v:Add(o) end function v:Sub(o) end function v:Mul(n) end
  function v:Set(x,y,z) self.x,self.y,self.z=x,y,z end
  function v:ToTable() return {self.x,self.y,self.z} end
  v.Dot = function(a,b) return 0 end v.Cross = function(a,b) return a end
  function v:Angle() return Angle(0,0,0) end
  return v end
function Angle(p,y,r) local a=setmetatable({p=p or 0,y=y or 0,r=r or 0}, {__tostring=function(x) return x.p.." "..x.y.." "..x.r end})
  function a:Forward() return Vector(1,0,0) end function a:Right() return Vector(0,1,0) end
  function a:Up() return Vector(0,0,1) end function a:Set(p,y,r) self.p,self.y,self.r=p,y,r end
  function a:ToTable() return {self.p,self.y,self.r} end
  return a end
function Color(r,g,b,a) return {r=r or 255,g=g or 255,b=b or 255,a=a or 255,
  SetUnpacked=function() end, ToTable=function() return {} end} end
function Matrix() return autostub("Matrix") end
function Entity(i) return _G.P11_FAKE_ENT(i) end
function Player(i) return _G.P11_FAKE_PLY(i) end
function IsValid(e) return e ~= nil and type(e)=="table" and e.__valid ~= false end
function istable(v) return type(v)=="table" end
function isstring(v) return type(v)=="string" end
function isnumber(v) return type(v)=="number" end
function isbool(v) return type(v)=="boolean" end
function isfunction(v) return type(v)=="function" end
function isentity(v) return type(v)=="table" end
function isvector(v) return type(v)=="table" end
function isangle(v) return type(v)=="table" end
function IsColor(v) return type(v)=="table" end
function ispanel(v) return false end
function tonumber2(v) return tonumber(v) end
function PrintMessage(t, m) log("[print]", m) end
function Msg(...) log(...) end function MsgN(...) log(...) end function MsgC(...) end
function ErrorNoHalt(...) log("[ERR] ",...) end function Error(...) log("[ERR] ",...) end
function print(...) log(...) end
function Include(f) return nil end
function DeriveGamemode(s) GM.BaseClass = autostub("base") ; GM.Folder="gamemodes/polus" end
function AddCSLuaFile(f) end
function include(f) return nil end
function CurTime() return _G.P11_NOW end
function SysTime() return _G.P11_NOW end
function RealTime() return _G.P11_NOW end
function FrameTime() return 0.015 end
if not table.unpack and _G.unpack then table.unpack = _G.unpack end

-- хуки
hook = { _t = {} }
P11_PERF = {}
function hook.Add(n, id, fn)
  hook._t[n] = hook._t[n] or {}
  if n == "HUDPaint" or n == "Think" then
    local real = fn
    fn = function(...)
      P11_INFRAME = n
      local ok, err = pcall(real, ...)
      P11_INFRAME = nil
      if not ok then P11_HOOK_ERR[#P11_HOOK_ERR+1] = n .. " " .. tostring(id) .. " :: " .. tostring(err) end
    end
  end
  hook._t[n][tostring(id)] = fn
end
local function PerfHit(what)
  if P11_INFRAME then P11_PERF[#P11_PERF+1] = P11_INFRAME .. " -> " .. what end
end
function hook.Remove(n, id) if hook._t[n] then hook._t[n][tostring(id)] = nil end end
function hook.GetTable() return hook._t end
function hook.Call(n, ...) local fns = hook._t[n]; if not fns then return end
  for _, f in pairs(fns) do local ok, err = pcall(f, ...) if not ok then P11_HOOK_ERR[#P11_HOOK_ERR+1] = n .. " :: " .. tostring(err) end end end
function hook.Run(n, ...) return hook.Call(n, ...) end
P11_HOOK_ERR = {}

-- сеть
net = {}
net._strings = {} net._recv = {} net._buf = {} net._sent = {}
function util_AddNetworkString_stub() end
function net.Receive(name, fn) net._recv[name] = fn end
function net.Start(name) net._cur = name; net._sent[name] = (net._sent[name] or 0) + 1 end
function net.Send(p) end function net.Broadcast() end function net.WriteUInt() end
function net.WriteInt() end function net.WriteString() end function net.WriteBool() end
function net.WriteFloat() end function net.WriteEntity() end function net.WriteTable() end
function net.WriteAngle() end function net.WriteVector() end function net.WriteDouble() end
function net.WriteNormal() end function net.WriteData() end function net.WriteColor() end
function net.ReadUInt() return 0 end function net.ReadInt() return 0 end
function net.ReadString() return "" end function net.ReadBool() return false end
function net.ReadFloat() return 0 end function net.ReadEntity() return nil end
function net.ReadTable() return {} end function net.ReadAngle() return Angle() end
function net.ReadVector() return Vector() end function net.ReadDouble() return 0 end
function net.ReadData() return "" end function net.ReadColor() return Color() end
function net.BytesWritten() return 0 end function net.BytesLeft() return 0 end

util = {}
function util.AddNetworkString(s) net._strings[s] = (net._strings[s] or 0) + 1 end
function util.TableToJSON(t, pretty) local ok, r = pcall(json_encode or function() return "{}" end, t) return ok and r or "{}" end
function util.JSONToTable(s) return nil end
function util.PrecacheModel(m) end function util.PrecacheSound(s) end
function util.GetSurfaceData() return {} end function util.StringToType(s,t) return 0 end
function util.TypeToString(t) return "number" end function util.Base64Encode(s) return "" end
function util.CRC(s) return "0" end function util.MD5(s) return "0" end
function util.Effect(n, d) end function util.ScreenShake() end
function util.TraceLine(t) PerfHit("util.TraceLine()") return {Hit=false, HitPos=Vector(), Fraction=1, Entity=nil, HitWorld=true, StartPos=Vector(), Normal=Vector()} end
function util.TraceHull(t) return {Hit=false, HitPos=Vector(), Fraction=1, Entity=nil} end
function util.TraceEntity() return {Hit=false} end function util.IsInWorld(v) return true end
function util.RelativePathToFull(p) return p end function util.NetworkStringToID(s) return 1 end
function util.RandomSeed(n) end function util.Compress(s) return s end function util.Decompress(s) return s end
function util.DateStamp() return 0,0 end function util.tobool(v) return v and true or false end
function util.GetPixelVisibleHandle() return 1 end function util.PixelVisible() return false end
function util.LocalToWorld(o, a, l, ang) return Vector(), Angle() end
function util.GetModelInfo(m) return {} end function util.IsValidModel(m) return true end
function util.QuickTrace(a,b,c) return {Hit=false} end function util.SharedRandom() return 0.5 end

-- файлы (виртуальная ФС в памяти)
file = { _fs = {} }
function file.Exists(p, d) return file._fs[p] ~= nil end
function file.Read(p, d) return file._fs[p] end
function file.Write(p, c) file._fs[p] = c end
function file.Append(p, c) file._fs[p] = (file._fs[p] or "") .. c end
function file.CreateDir(p) end function file.Delete(p) file._fs[p] = nil end
function file.IsDir(p, d) return false end
function file.Find(pat, d) PerfHit("file.Find("..tostring(pat)..")") return {}, {} end
function file.Size(p, d) return #(file._fs[p] or "") end
function file.Time(p, d) return 0 end
function file.Rename(a,b) file._fs[b]=file._fs[a]; file._fs[a]=nil end
function file.Open(p, m, d) return autostub("filehandle") end

timer = { _t = {}, _id = 0 }
function timer.Create(name, delay, reps, fn) timer._t[name] = {delay=delay, fn=fn, reps=reps} end
function timer.Simple(d, fn) timer._id = timer._id + 1; timer._t["simple"..timer._id] = {delay=d, fn=fn} end
function timer.Destroy(n) timer._t[n]=nil end function timer.Remove(n) timer._t[n]=nil end
function timer.Exists(n) return timer._t[n] ~= nil end
function timer.Adjust(n, d, r, f) timer._t[n] = {delay=d, fn=f, reps=r} end
function timer.Check(n) return false end function timer.Pause(n) end function timer.UnPause(n) end
function timer.TimeLeft(n) return 0 end function timer.RepsLeft(n) return 0 end
function timer.Toggle(n) end
-- Таймеры стреляют ПО ВРЕМЕНИ: берём ближайший по delay, а не «как легло в pairs».
-- Повторяющиеся таймеры (reps = 0 — бесконечно, reps = N) переставляются снова,
-- но не больше P11_MAX_REPS раз, чтобы симуляция завершалась.
P11_MAX_REPS = 6
function P11_FireTimers(maxn)
  local n = 0
  while true do
    if n >= (maxn or 1e9) then break end
    local bestName, bestT, bestDelay
    for name, t in pairs(timer._t) do
      local d = tonumber(t.delay) or 0
      if not bestT or d < bestDelay or (d == bestDelay and name < bestName) then
        bestName, bestT, bestDelay = name, t, d
      end
    end
    if not bestT then break end
    timer._t[bestName] = nil
    local ok, err = pcall(bestT.fn)
    if not ok then P11_HOOK_ERR[#P11_HOOK_ERR+1] = "timer " .. bestName .. " :: " .. tostring(err) end
    n = n + 1
    -- повтор: 0 = бесконечно (ограничиваем), >1 = ещё (reps-1) раз
    local reps = bestT.reps
    bestT.fired = (bestT.fired or 0) + 1
    local again = false
    if reps == 0 and bestT.fired < P11_MAX_REPS then again = true
    elseif isnumber(reps) and reps > 1 then bestT.reps = reps - 1; again = true end
    if again then timer._t[bestName] = bestT end
  end
  return n
end

concommand = { _t = {} }
function concommand.Add(n, fn, ...) concommand._t[n] = fn end
function concommand.Remove(n) concommand._t[n] = nil end
function concommand.Run(p, c, a, s) end
function concommand.GetTable() return concommand._t end

P11_CVARS = P11_CVARS or {}
CreateConVar = function(n, v, f, h)
  if P11_CVARS[n] then return P11_CVARS[n] end
  local c = autostub("convar")
  local val = v
  c.GetName = function() return n end c.GetString = function() return tostring(val) end
  c.GetInt = function() return tonumber(val) or 0 end c.GetFloat = function() return tonumber(val) or 0 end
  c.GetBool = function() return val == "1" or val == true end c.SetBool = function(_, x) val = x and "1" or "0" end
  c.SetString = function(_, x) val = x end c.SetInt = function(_, x) val = x end c.SetFloat = function(_, x) val = x end
  c.AddCallback = function() end c.SetHelpText = function() end c.GetDefault = function() return v end
  c.GetConVar = function() return c end
  P11_CVARS[n] = c
  return c end
GetConVar = function(n) return P11_CVARS[n] or CreateConVar(n, "0") end
CreateClientConVar = function(n, v, a, r, h) return CreateConVar(n, v) end
CreateSound = function(e, n) return autostub("csound") end
Derma_Hook = function(p, a, b, c) end
Derma_Anim = function(n, p, f) local a = autostub("anim") return a end
Derma_String = function(n, p, f) return "x" end
Derma_DrawBackgroundBlur = function(p, t) end
Derma_Message = function(...) return autostub("msg") end
Derma_Query = function(...) return autostub("qry") end
Derma_DrawText = function(...) end
notification = {}
notification.AddLegacy = function(...) end notification.AddProgress = function(...) end
notification.Kill = function(...) end
input = {}
input.IsKeyDown = function(k) return false end input.IsMouseDown = function(k) return false end
input.LookupKeyBinding = function(k) return "" end input.SelectWeapon = function() end
input.GetCursorPos = function() return 0, 0 end input.SetCursorPos = function() end
input.IsControlDown = function() return false end input.IsShiftDown = function() return false end
language = {}
language.Add = function(k, v) end language.GetPhrase = function(k) return k end
DrawMotionBlur = function(a,b,c) end DrawMaterialOverlay = function(m, s) end
DrawSharpen = function(a, b) end DrawColorModify = function(t) end DrawBloom = function() end
DrawToyTown = function(a, b) end DrawTexturize = function(a, b) end DrawSobel = function(a) end
DrawMaterialOverlay2 = function() end
GetRenderTargetEx2 = function() return autostub("rt") end
GetGlobalVar4 = function() return nil end
GetHUDPanel = function() return autostub("hud") end
GetViewEntity2 = function() return nil end
ScrW2 = ScrW
SetClipboardText = function(t) end
GetClipboardText = function() return "" end
GetGlobalVarTable = function() return {} end
system = {}
system.IsWindows = function() return true end system.IsLinux = function() return false end
system.IsOSX = function() return false end system.UpTime = function() return 0 end
system.SteamTime = function() return 0 end system.Date = function() return os.date() end
system.GetCountry = function() return "RU" end system.HasSSE = function() return true end
system.HasSSE2 = function() return true end system.ShouldSleep = function() return false end
system.AppTime = function() return 0 end system.FocusChanged = function() return false end
system.Time = function() return 0 end system.benchTimeEx = function() return 0 end
system.GetTime = function() return 0 end
FrameNumber2 = FrameNumber
GetHostName = function() return "POLUS-11" end
GetConVar2 = GetConVar
P11_NOW = P11_NOW or 1000
GetConVarNumber = function(n) return 0 end
GetConVarString = function(n) return "" end
cvars = { AddChangeCallback=function() end, OnConVarChanged=function() end, GetConVarCallbacks=function() return {} end }

-- игроки/энтити
local PLY_MT = {}
local function newply(i)
  local p = { __index = i, __valid = true, _nw = {}, _vars = {}, _ammo = {}, _inv = {} }
  setmetatable(p, PLY_MT)
  return p
end
PLY_MT.__index = function(p, k)
  local pm = rawget(_G, "P11_PMETA")
  if pm and rawget(pm, k) ~= nil then return rawget(pm, k) end
  if k == "SteamID" then return function() return "STEAM_0:0:" .. tostring(p.__index) end end
  if k == "SteamID64" then return function() return tostring(76561190000000000 + (p.__index or 1)) end end
  if k == "Nick" or k == "GetName" or k == "Name" then return function() return "TestPlayer" .. tostring(p.__index) end end
  if k == "GetPos" then return function() return Vector(0,0,0) end end
  if k == "EyePos" then return function() return Vector(0,0,64) end end
  if k == "EyeAngles" then return function() return Angle() end end
  if k == "GetAngles" then return function() return Angle() end end
  if k == "GetVelocity" then return function() return Vector() end end
  if k == "SetVelocity" then return function() end end
  if k == "Alive" then return function() return true end end
  if k == "Health" then return function() return 100 end end
  if k == "Armor" then return function() return 0 end end
  if k == "SetHealth" or k == "SetArmor" or k == "AddHealth" then return function() end end
  if k == "Team" then return function() return 1001 end end
  if k == "SetTeam" then return function() end end
  if k == "GetNWString" then return function(_, n, d) return p._nw[n] or d or "" end end
  if k == "GetNWInt" then return function(_, n, d) return p._nw[n] or d or 0 end end
  if k == "GetNWBool" then return function(_, n, d) return p._nw[n] or d or false end end
  if k == "GetNWFloat" then return function(_, n, d) return p._nw[n] or d or 0 end end
  if k == "GetNWEntity" then return function() return nil end end
  if k == "SetNWString" or k == "SetNWInt" or k == "SetNWBool" or k == "SetNWFloat" or k == "SetNWEntity"
     or k == "SetNWAngle" or k == "SetNWVector" then return function(_, n, v) p._nw[n] = v end end
  if k == "GetPData" then return function(_, n, d) return p._vars[n] or d end end
  if k == "SetPData" then return function(_, n, v) p._vars[n] = v end end
  if k == "IsAdmin" then return function() return false end end
  if k == "IsSuperAdmin" then return function() return false end end
  if k == "IsUserGroup" then return function() return false end end
  if k == "SetUserGroup" then return function() end end
  if k == "GetUserGroup" then return function() return "user" end end
  if k == "IsListenServerHost" then return function() return false end end
  if k == "ConCommand" then return function(_, cmd)
      P11_UI.concommands[#P11_UI.concommands + 1] = tostring(cmd) end end
  if k == "IsPlayer" then return function() return true end end
  if k == "IsNPC" or k == "IsRagdoll" or k == "IsWeapon" or k == "IsVehicle" then return function() return false end end
  if k == "ChatPrint" or k == "PrintMessage" or k == "SendLua" then return function() end end
  if k == "EmitSound" or k == "StopSound" then return function() end end
  if k == "Give" or k == "StripWeapon" or k == "StripWeapons" or k == "RemoveAllAmmo" then return function() return autostub("wep") end end
  if k == "GetWeapon" then return function() return nil end end
  if k == "GetActiveWeapon" then return function() return autostub("wep") end end
  if k == "HasWeapon" then return function() return false end end
  if k == "GetWeapons" then return function() return {} end end
  if k == "GetAmmoCount" then return function() return 0 end end
  if k == "GiveAmmo" or k == "SetAmmo" or k == "TakeAmmo" then return function() end end
  if k == "AddCount" or k == "GetCount" or k == "LimitHit" then return function() return 0 end end
  if k == "SetModel" or k == "GetModel" then return function() return "models/player.mdl" end end
  if k == "SetWalkSpeed" or k == "SetRunSpeed" or k == "SetJumpPower" or k == "SetMaxSpeed" then return function() end end
  if k == "GetWalkSpeed" then return function() return 200 end end
  if k == "GetRunSpeed" then return function() return 400 end end
  if k == "Kill" or k == "KillSilent" or k == "Spawn" or k == "Freeze" or k == "GodEnable" or k == "GodDisable" then return function() end end
  if k == "SetPos" or k == "SetAngles" or k == "SetEyeAngles" then return function() end end
  if k == "GetEyeTrace" then return function() return {Hit=false, Entity=nil, HitPos=Vector()} end end
  if k == "GetTraceHull" then return function() return {Hit=false} end end
  if k == "SetNoClip" or k == "GetNoClip" then return function() return false end end
  if k == "ScreenFade" or k == "SendHint" or k == "SuppressHint" then return function() end end
  if k == "AddCleanup" or k == "AddFrozenPhysicsObject" then return function() end end
  if k == "GetViewEntity" then return function() return p end end
  if k == "UnSpectate" or k == "Spectate" or k == "SpectateEntity" then return function() end end
  if k == "InVehicle" then return function() return false end end
  if k == "GetVehicle" then return function() return nil end end
  if k == "Ping" then return function() return 30 end end
  if k == "KeyDown" then return function() return false end end
  if k == "SteamName" then return function() return "TestPlayer" end end
  if k == "EntIndex" then return function() return p.__index or 1 end end
  if k == "SetCustomCollisionCheck" or k == "SetCollisionGroup" or k == "SetSolid" then return function() end end
  if k == "LookupAttachment" or k == "GetAttachment" then return function() return nil end end
  if k == "GetBonePosition" then return function() return Vector(), Angle() end end
  if k == "SelectWeapon" then return function() end end
  if k == "IsBot" then return function() return false end end
  if k == "GetRagdollEntity" then return function() return nil end end
  if k == "Frags" or k == "Deaths" then return function() return 0 end end
  if k == "SetFrags" or k == "SetDeaths" then return function() end end
  if k == "TimeConnected" then return function() return 0 end end
  if k == "IsFullyAuthenticated" then return function() return true end end
  if k == "GetUniqueID" then return function() return tostring(p.__index) end end
  if k == "SetRenderMode" or k == "SetColor" or k == "GetColor" then return function() return Color() end end
  if k == "DrawShadow" or k == "SetNoDraw" or k == "SetNotSolid" then return function() end end
  if k == "GetPos" then return function() return Vector() end end
  if k == "WorldToLocal" or k == "LocalToWorld" then return function() return Vector() end end
  if k == "IsOnGround" then return function() return true end end
  if k == "GetMoveType" or k == "SetMoveType" then return function() return 2 end end
  if k == "Crouching" or k == "OnGround" then return function() return false end end
  if k == "GetAimVector" then return function() return Vector(1,0,0) end end
  if k == "GetHull" or k == "GetHullDuck" then return function() return Vector(), Vector() end end
  if k == "SetFOV" or k == "GetFOV" then return function() return 90 end end
  if k == "SetBodygroup" or k == "GetBodygroup" then return function() return 0 end end
  if k == "SetSkin" or k == "GetSkin" then return function() return 0 end end
  if k == "PrintMessage" then return function() end end
  -- методы GMod — CamelCase (Get/Set/Is/Has/Add/Take/Emit/...); всё остальное — данные (nil)
  if type(k) == "string" and string.match(k, "^(Get|Set|Is|Has|Add|Take|Remove|Lookup|Select|World|Local|Alive|Health|Armor|Team|Nick|Name|SteamID|ChatPrint|PrintMessage|SendLua|ConCommand|EmitSound|StopSound|Give|Strip|Kill|Spawn|Freeze|God|ScreenFade|InVehicle|KeyDown|Ping|Frags|Deaths|TimeConnected|Crouching|OnGround|EntIndex|DrawShadow|SuppressHint|SendHint|LimitHit|AddCleanup|AddFrozenPhysicsObject|UnSpectate|Spectate|WaterLevel|GetViewModel|TranslateWeaponActivity|AnimRestartGesture|AnimResetGestureSlot|DoAnimationEvent|GetModelPhysBoneCount|EyePos|EyeAngles|GetAimVector|GetViewEntity|GetMoveType|SetMoveType|GetHull|GetHullDuck|SetFOV|GetFOV|SetBodygroup|GetBodygroup|SetSkin|GetSkin|IsBot|GetRagdollEntity|IsFullyAuthenticated|GetUniqueID|SetRenderMode|SetColor|GetColor|SetNoDraw|SetNotSolid|WorldToLocal|LocalToWorld|SetCustomCollisionCheck|SetCollisionGroup|SetSolid|InVehicle|GetVehicle|SteamName|GetWeapons|GetActiveWeapon|GetWeapon|HasWeapon|GetAmmoCount|GiveAmmo|SetAmmo|TakeAmmo|RemoveAllAmmo|SetModel|GetModel|SetWalkSpeed|SetRunSpeed|SetJumpPower|SetMaxSpeed|GetWalkSpeed|GetRunSpeed|SetPos|GetPos|SetAngles|GetAngles|SetEyeAngles|GetEyeTrace|SetNoClip|GetNoClip|SetVelocity|GetVelocity|SetHealth|SetArmor|AddHealth|SetTeam|GetViewPunchAngles|ViewPunch|SetViewPunchAngles|IsOnGround|GetGroundEntity|GetParent|GetOwner|SetParent|GetChildren|GetEffects|AddEffects|RemoveEffects|EmitSound|StopSound|GetSoundLevel|SetSoundLevel|GetRenderGroup|SetRenderGroup|GetShouldPlayPickupSound|SetShouldPlayPickupSound|GetSequence|LookupSequence|ResetSequence|SetSequence|SelectWeightedSequence|IsPlayer|IsNPC|IsRagdoll|IsWeapon|IsVehicle|GetClass|GetModel|SetModel|Spawn|Remove|IsValid|EntIndex|GetCreationID|GetCreator|OBBMins|OBBMaxs|WorldSpaceAABB|GetPhysicsObject|PhysicsInit|SetMoveType|SetSolid|SetUseType|Fire|SetKeyValue|FollowBone|SetMaterial|SetSubMaterial|AddEFlags|SetTrigger|SetModelScale|GetModelScale|DrawShadow|SetColor|GetColor|SetNWVarProxy|GetNWVarProxy)") then
    return autostub("ply:" .. tostring(k))
  end
  return nil
end
function P11_FAKE_PLY(i) return newply(i) end

local ENT_MT = {}
ENT_MT.__index = function(e, k)
  if k == "IsValid" then return function() return true end end
  if k == "GetClass" then return function() return e.__class or "prop_physics" end end
  if k == "GetPos" then return function() return Vector(0,0,0) end end
  if k == "SetPos" or k == "SetAngles" or k == "SetModel" or k == "Spawn" or k == "Activate"
     or k == "PhysicsInit" or k == "SetMoveType" or k == "SetSolid" or k == "SetUseType"
     or k == "SetCollisionGroup" or k == "SetNWString" or k == "SetNWInt" or k == "SetNWBool"
     or k == "SetNWFloat" or k == "SetNWEntity" or k == "SetHealth" or k == "SetMaxHealth"
     or k == "Remove" or k == "EmitSound" or k == "StopSound" or k == "SetModelScale"
     or k == "DrawShadow" or k == "SetNotSolid" or k == "SetTrigger" or k == "SetRenderMode"
     or k == "SetColor" or k == "Fire" or k == "SetKeyValue" or k == "SetParent" or k == "FollowBone"
     or k == "SetMaterial" or k == "SetSubMaterial" or k == "SetSkin" or k == "SetBodygroup"
     or k == "AddEFlags" or k == "RemoveEffects" or k == "SetNoDraw" or k == "SetCustomCollisionCheck"
     or k == "EnableCustomCollisions" or k == "SetSequence" or k == "ResetSequence" then
     return function() end end
  if k == "GetModel" then return function() return e.__model or "models/props.mdl" end end
  if k == "GetNWString" or k == "GetNWInt" or k == "GetNWBool" or k == "GetNWFloat" then return function(_, n, d) return d end end
  if k == "Health" or k == "GetMaxHealth" then return function() return 100 end end
  if k == "GetPhysicsObject" then return function() return autostub("phys") end end
  if k == "GetOwner" or k == "GetParent" then return function() return nil end end
  if k == "WorldSpaceAABB" then return function() return Vector(), Vector() end end
  if k == "OBBMins" or k == "OBBMaxs" then return function() return Vector() end end
  if k == "EntIndex" then return function() return e.__i or 1 end end
  if k == "GetAngles" then return function() return Angle() end end
  if k == "LookupSequence" or k == "SelectWeightedSequence" then return function() return 1 end end
  if k == "GetSequence" then return function() return 0 end end
  if k == "IsPlayer" then return function() return false end end
  if k == "IsNPC" then return function() return false end end
  if k == "GetCreator" then return function() return nil end end
  if k == "GetCreationID" then return function() return 1 end end
  if k == "GetSolidFlags" or k == "GetMoveType" then return function() return 0 end end
  if k == "WorldToLocal" or k == "LocalToWorld" or k == "LocalToWorldAngles" then return function() return Vector() end end
  if k == "SetLocalPos" or k == "GetLocalPos" then return function() return Vector() end end
  if k == "SetNetworkOrigin" or k == "SetAbsOrigin" then return function() end end
  return autostub("ent:" .. tostring(k))
end
function P11_FAKE_ENT(i) local e = {__i = i or 1, __valid = true}; setmetatable(e, ENT_MT); return e end

player = { _all = {} }
function player.GetAll() return player._all end
function player.GetCount() return #player._all end
function player.GetByID(i) return player._all[i] end
function player.GetBySteamID(s) return nil end
function player.GetByUniqueID(s) return nil end
function player.CreateNextBot(n) return newply(99) end
function player.GetBots() return {} end
function player.GetHumans() return player._all end
function P11_SpawnPlayers(n)
  player._all = {}
  for i = 1, n do player._all[i] = newply(i) end
  return player._all
end

ents = { _made = {} }
function ents.Create(c) local e = P11_FAKE_ENT(#ents._made + 1); e.__class = c; ents._made[#ents._made+1] = e; return e end
function ents.CreateClientProp(c) return ents.Create(c) end
function ents.FindByClass(c) PerfHit("ents.FindByClass("..tostring(c)..")") return {} end
function ents.FindByClassAndParent(c, p) return {} end
function ents.FindInSphere(v, r) PerfHit("ents.FindInSphere()") return {} end
function ents.FindInBox(a, b) return {} end
function ents.FindAlongRay(a, b) return {} end
function ents.FindInPVS(v) return {} end
function ents.GetAll() return ents._made end
function ents.GetByIndex(i) return P11_FAKE_ENT(i) end
function ents.GetCount() return #ents._made end

engine = {}
function engine.ActiveGamemode() return "darkrp" end
function engine.GetGamemodes() return {} end
function engine.IsMounted() return true end
function engine.GetMountableID() return 0 end
function engine.SetMounted() end
function engine.GetGames() return {} end
function engine.CloseServer() end
function engine.ServerFrameTime() return 0.015 end
function engine.LightStyle() end
function engine.GetUserContent() return {} end
engine._t = {}

game = {}
function game.GetMap() return "gm_flatgrass" end
function game.MaxPlayers() return 24 end
function game.SinglePlayer() return false end
function game.GetTimeScale() return 1 end
function game.SetTimeScale(t) end
function game.AddParticles(p) end
function game.AddDecal(a,b,c) end
function game.GetAmmoName(i) return "Pistol" end
function game.GetAmmoID(n) return 1 end
function game.GetDamageType() return 0 end
function game.CleanUpMap(b, e) end
function game.SetGlobalState(a,b) end function game.GetGlobalState(a) return 0 end
function game.MountGMA() end function game.GetGlobalCounter() return 0 end
function game.SetGlobalCounter(a,b) end function game.GetWorld() return P11_FAKE_ENT(0) end
function game.GetWorld() return P11_FAKE_ENT(0) end
function game.GetIP() return "0.0.0.0" end function game.GetPorts() return 0,0 end
function game.GetMapVersion() return 1 end function game.GetAmmoForce(n) return 1 end
function game.GetAmmoMax(n) return 999 end function game.GetTimeScale2() return 1 end
function game.RemoveRagdolls() end function game.KickID() end function game.AddAmmoType(t) end

team = { _t = {} }
function team.SetUp(i, n, c) team._t[i] = {name=n, color=c} end
function team.GetName(i) return (team._t[i] and team._t[i].name) or "TEAM" end
function team.GetColor(i) return Color() end
function team.GetAllTeams() return team._t end
function team.NumPlayers(i) return 0 end
function team.TotalDeaths(i) return 0 end function team.TotalFrags(i) return 0 end
function team.Valid(i) return team._t[i] ~= nil end
function team.AddScore(i, n) end function team.SetScore(i, n) end
function team.GetScore(i) return 0 end
function team.BestAutoJoinTeam() return 1001 end
function team.GetPlayers(i) return {} end
function team.GetSpawnPoint(i) return nil end function team.SetSpawnPoint(i, p) end

resource = {}
function resource.AddFile(f) end function resource.AddWorkshop(id) end
function resource.AddSingleFile(f) end

sound = {}
function sound.Play(n, p, l, pi, v) end
function sound.Add(t) end function sound.EmitHint() end
function sound.GetProperties() return {} end function sound.PlayFile(p, f, cb) if cb then cb(nil) end end

surface = {}
surface._fonts = {}
function surface.CreateFont(n, t) PerfHit("surface.CreateFont("..tostring(n)..")"); surface._fonts[n] = t end
function surface.SetFont(n) end function surface.SetTextColor(r,g,b,a) end
function surface.SetDrawColor(r,g,b,a) end function surface.DrawRect(x,y,w,h) end
function surface.DrawOutlinedRect() end function surface.DrawText(t) end
function surface.GetTextSize(t) return 10, 10 end function surface.PlaySound(s) end
function surface.SetMaterial(m) end function surface.DrawTexturedRect() end
function surface.DrawTexturedRectRotated() end function surface.DrawPoly(t) end
function surface.DrawLine(x1,y1,x2,y2) end function surface.DrawCircle() end
function surface.CreateMaterial(n, s, t) PerfHit("surface.CreateMaterial("..tostring(n)..")") return autostub("mat") end
function surface.GetTextureID(n) return 1 end function surface.SetTexture(i) end
function surface.ScreenWidth() return 1920 end function surface.ScreenHeight() return 1080 end
function surface.GetHUDTexture() return nil end function surface.DisableClipping(b) end
function surface.DrawRoundedBox() end function surface.SetAlphaMultiplied(b) end

draw = {}
function draw.SimpleText(t, f, x, y, c, ax, ay) return 10, 10 end
function draw.SimpleTextOutlined(...) return 10, 10 end
function draw.Text(t) return 10, 10 end function draw.TextShadow(...) return 10,10 end
function draw.RoundedBox(r, x, y, w, h, c) end function draw.RoundedBoxEx(...) end
function draw.NoTexture() end function draw.GetFontHeight(f) return 12 end
function draw.WordBox(...) return 10,10 end function draw.DrawText(...) return 10,10 end
function draw.SetFont(f) end function draw.SetTextColor(c) end
function draw.DrawLine(x1,y1,x2,y2,c) end

vgui = { _made = {} }
function vgui.Create(c, p) PerfHit("vgui.Create("..tostring(c)..")") local pn = autostub("panel:" .. tostring(c))
  pn.ClassName = c; pn.Remove = function() end; pn:SetVisible(true); vgui._made[#vgui._made+1] = pn; return pn end
function vgui.CreateFromTable(t, p) return vgui.Create("Table") end
function vgui.GetControlTable(c) return autostub("control:" .. tostring(c)) end
function vgui.Register(t, n, b) _G[n] = t; return t end
function vgui.CursorVisible() return P11_UI.cursor end
function vgui.GetWorldPanel()
  local w = P11_UI.world
  if not w then
    w = { ClassName = "WorldPanel", __valid = true }
    w.GetChildren = function() return P11_UI.kids end
    w.IsVisible = function() return true end
    w.IsMouseInputEnabled = function() return false end
    w.GetSize = function() return ScrW(), ScrH() end
    w.Remove = function(self) P11_UI.kids = {} end
    P11_UI.world = w
  end
  return w
end
function vgui.GetKeyboardFocus() return P11_UI.focus end
function vgui.RegisterFile(f) end
function vgui.ResetCursor() end function vgui.GetHoveredPanel() return nil end
function vgui.SpawnCursor() end

gui = {}
P11_UI = { kids = {}, cursor = false, gameui = false, console = false,
           clicker = 0, clicker_last = nil, hideui = 0, concommands = {} }
function gui.MousePos() return 0, 0 end
function gui.IsGameUIVisible() return P11_UI.gameui end
function gui.ActivateGameUI() P11_UI.gameui = true end
function gui.HideGameUI() P11_UI.hideui = P11_UI.hideui + 1; P11_UI.gameui = false end
function gui.EnableScreenClicker(b) P11_UI.clicker = P11_UI.clicker + 1; P11_UI.clicker_last = b and true or false end function gui.SetMousePos(x,y) end
function gui.InternalCursorMoved(x,y) end function gui.OpenURL(u) end
function gui.ScreenToVector(v) return Vector() end function gui.MouseX() return 0 end
function gui.MouseY() return 0 end function gui.IsConsoleVisible() return P11_UI.console end
function gui.InternalKeyCodeTyped(c) end function gui.InternalKeyCodePressed(c) end
function gui.InternalKeyCodeReleased(c) end function gui.InternalMousePressed(m) end
function gui.InternalMouseReleased(m) end function gui.InternalWheelDelta(d) end
function gui.InternalKeyTyped(c) end function gui.InternalCursorMoved2() end
function gui.InternalKeyCodeChar(c) end

chat = {}
function chat.AddText(...) end function chat.Close() end function chat.Open(n) end
function chat.GetChatBoxPos() return 0,0 end function chat.GetChatBoxSize() return 0,0 end
function chat.PlaySound() end

render = {}
function render.SetColorMaterial() end function render.SetMaterial(m) end
function render.DrawQuadEasy(...) end function render.DrawSprite(...) end
function render.SetLightingMode() end function render.ComputeLighting(v, n) return Vector() end
function render.GetLightColor(v) return Vector() end function render.SuppressEngineLighting(b) end
function render.SetAmbientLight(r,g,b) end function render.SetLightMapTexture() end
function render.SetFogZ() end function render.FogStart() end function render.FogEnd() end
function render.SetBlend(b) end function render.SetScissorRect() end
function render.DrawSphere() end function render.Clear(r,g,b,a) end
function render.DrawLine(a,b,c,d) end function render.GetAmbientLightColor() return Vector() end
function render.OverrideDepthEnable() end function render.SetViewPort() end
function render.Capture(t) return "" end function render.UpdateScreenEffectTexture() end
function render.SetToneMappingScale(v) end function render.GetSuperFPTex() return 1 end
function render.GetSmallTex0() return 1 end function render.SetModelLighting() end
function render.SetWriteDepthToDestAlpha() end

cam = {}
function cam.Start3D(p, a, f, x, y, w, h) end function cam.End3D() end
function cam.Start2D() end function cam.End2D() end
function cam.Start3D2D(p, a, s) end function cam.End3D2D() end
function cam.ApplyShake() end function cam.IgnoreZ(b) end
function cam.GetView() return {} end function cam.PushModelMatrix() end
function cam.PopModelMatrix() end function cam.StartOrthoView() end
function cam.EndOrthoView() end

effects = {}
function effects.Create(n) return autostub("effect") end
function effects.Register(t, n) end

materials = {}
function Material(n, f) PerfHit("Material("..tostring(n)..")") return autostub("mat") end
function CreateMaterial(n, s, t) return autostub("mat") end

particles = {}
function ParticleEmitter(p) return autostub("pe") end
function ParticleEffect(n, p, a, e) end
function ParticleEffectAttach(...) end
function CreateParticleSystem(...) end

constraint = {}
function constraint.GetAllConstrainedEntities(e) return {} end
function constraint.FindConstraints(e, t) return {} end
function constraint.RemoveConstraints(e, t) end
function constraint.NoCollide() return nil end function constraint.Weld() return nil end
function constraint.Keepupright() return nil end
function constraint.Find(a,b,c,d) return nil end
function constraint.AdvBallsocket() return nil end

physenv = {}
function physenv.SetAirDensity(v) end function physenv.GetAirDensity() return 2 end
function physenv.SetGravity(v) end function physenv.GetGravity() return Vector(0,0,-600) end
function physenv.GetPerformanceSettings() return {} end
function physenv.SetPerformanceSettings(t) end function physenv.AddSurfaceData(s) end

cleanup = {}
function cleanup.Add(p, t, e) end function cleanup.ReplaceEntity(a, b) return false end
function cleanup.CC_AdminCleanup(p, c, a) end function cleanup.GetList() return {} end
function cleanup.Register(t) end function cleanup.UpdateUI() end
function cleanup.GetTable() return {} end

duplicator = {}
function duplicator.RegisterEntityClass(c, f, ...) end
function duplicator.RegisterEntityModifier(n, f) end
function duplicator.CopyEntTable(e) return {} end
function duplicator.Paste(p, e, c) return {}, {} end
function duplicator.DoGeneric(e, t) end function duplicator.DoGenericPhysics(e, p, t) end
function duplicator.StoreEntityModifier(e, n, t) end
function duplicator.FindEntityClass(t) return nil end

undo = {}
function undo.Create(n) end function undo.AddEntity(e) end
function undo.SetPlayer(p) end function undo.Finish() end
function undo.AddFunction(f, ...) end function undo.ReplaceEntity(a, b) end
function undo.DoUndoPlayer(p) end

gamemode = {}
function gamemode.Call(n, ...) return hook.Call(n, ...) end
function gamemode.Register(t, n) end

sql = {}
function sql.Query(s) return {} end function sql.QueryValue(s) return nil end
function sql.SQLStr(s) return "'" .. tostring(s) .. "'" end
function sql.TableExists(t) return false end function sql.LastError() return "" end
function sql.Begin() end function sql.Commit() end function sql.mquery(s) return {} end

http = {}
function HTTP(t) if t.failed then t.failed("no-net") end end
function http.Fetch(u, ok, bad) if bad then bad("no-net") end end
function http.Post(u, p, ok, bad) if bad then bad("no-net") end end

list = {}
function list.Get(t) return {} end function list.Set(t, k, v) end
function list.Add(t, v) end function list.HasEntry(t, k) return false end

properties = {}
function properties.Add(n, t) end function properties.CanBeTargeted(e, p) return false end
function properties.OnScreenClick(e, p) end function properties.OpenEntityMenu(e, p) end

menubar = {}
function menubar.Add() return autostub("mb") end function menubar.Init() end
function menubar.IsParent(p) return false end function menubar.ParentTo() end

search = {}
function search.AddProvider(f, t) end

spawnmenu = {}
function spawnmenu.AddCreationTab(n, f, i, o, t) end
function spawnmenu.AddToolTab(n, l, i) end function spawnmenu.AddToolCategory(t, r, n) end
function spawnmenu.AddToolMenuOption(t, c, i, n, cmd, cfg, tb, op) end
function spawnmenu.ActivateTool(t) end function spawnmenu.GetTools() return {} end
function spawnmenu.GetCreationTabs() return {} end function spawnmenu.SwitchToolTab(t) end
function spawnmenu.PopulateToolMenu() end function spawnmenu.ActiveControlPanel() return nil end
function spawnmenu.GetActiveControlPanel() return nil end
function spawnmenu.SetActiveControlPanel(p) end function spawnmenu.GetToolMenu() return {} end
function spawnmenu.DoSaveToClipboard() end function spawnmenu.AddContentType(t, f) end
function spawnmenu.CreateContentIcon(t, p, d) return autostub("ci") end
function spawnmenu.SwitchToolTab2() end function spawnmenu.SetActiveTool() end
function spawnmenu.GetTools2() return {} end function spawnmenu.PopulateContent() end
function spawnmenu.CreateContentIcons() end function spawnmenu.ActivateTool2() end
function spawnmenu.ActivateToolPanel() end function spawnmenu.SetSpawnIcon() end
function spawnmenu.GetSpawnIcon() return nil end function spawnmenu.SaveToClipboard() end
function spawnmenu.PopulatePropMenu() end function spawnmenu.PopulateVehicles() end
function spawnmenu.PopulateNPCs() end function spawnmenu.PopulateWeapons() end
function spawnmenu.PopulateEntities() end function spawnmenu.PopulatePostProcess() end
function spawnmenu.PopulateSaves() end function spawnmenu.PopulateDemos() end
function spawnmenu.PopulateDupes() end function spawnmenu.PopulateSettings() end
function spawnmenu.PopulateUtility() end function spawnmenu.PopulateHooks() end

presets = {}
function presets.Add(t, n, v) end function presets.GetValues(t) return {} end
function presets.Exists(t, n) return false end function presets.Remove(t, n) end
function presets.BadNameAlert() end function presets.Rename(t, o, n) return false end
function presets.Stock() return {} end

achievements = {}
function achievements.BalloonFallback() end function achievements.EatBall() end
function achievements.SpawnedProp() end function achievements.SpawnedRagdoll() end
function achievements.SpawnedNPC() end function achievements.SpawnedVehicle() end
function achievements.SpawnedSENT() end function achievements.SpawnedEffect() end
function achievements.Remover() end function achievements.IncBaddies() end
function achievements.IncGoodies() end function achievements.IncBystander() end
function achievements.IncFriend() end function achievements.IsFriend(e) return false end
function achievements.IsEnemy(e) return false end function achievements.GetTable() return {} end

halo = {}
function halo.Add(t) end function halo.Rendered() end

widgets = {}
function widgets.PlayerTick() end function widgets.RenderMe() end

numpad = {}
function numpad.OnDown(p, k, n, ...) return 1 end
function numpad.OnUp(p, k, n, ...) return 1 end
function numpad.Activate(p, k, i) end function numpad.Deactivate(p, k, i) end
function numpad.Toggle(p, k, i) end function numpad.Remove(i) end
function numpad.FromButton() return false end function numpad.GetTable() return {} end

usermessage = {}
function usermessage.Hook(n, f) end function usermessage.Begin(n) return autostub("um") end
function usermessage.Register() end

DeriveGamemode2 = nil
GM = GM or {}
if not GM then GM = {} end
SWEP = {} ENT = {} TOOL = {}
weapons = { _t = {} }
function weapons.Get(c) return weapons._t[c] end
function weapons.Register(t, n) weapons._t[n] = t; return t end
function weapons.GetList() return {} end
function weapons.GetStored(c) return weapons._t[c] end
function weapons.IsBasedOn(a, b) return false end
KEY_ESCAPE=88 KEY_ENTER=64 KEY_SPACE=57 KEY_TAB=65 KEY_F1=112 KEY_F2=113 KEY_F3=114
KEY_F4=115 KEY_F5=116 KEY_F6=117 KEY_LALT=119 KEY_RALT=120 KEY_LSHIFT=108 KEY_LCONTROL=107
KEY_A=2 KEY_D=4 KEY_E=5 KEY_R=21 KEY_W=26 KEY_Q=19 KEY_F=8 KEY_G=9 KEY_T=23
TEXT_ALIGN_LEFT=0 TEXT_ALIGN_CENTER=1 TEXT_ALIGN_RIGHT=2 TEXT_ALIGN_TOP=0 TEXT_ALIGN_BOTTOM=4
HUD_PRINTTALK=3
MOVETYPE_NONE=0 MOVETYPE_WALK=2 MOVETYPE_NOCLIP=8 MOVETYPE_OBSERVER=10
SOLID_NONE=0 SOLID_BSP=1 SOLID_BBOX=2 SOLID_VPHYSICS=6 SOLID_CUSTOM=11
COLLISION_GROUP_NONE=0 COLLISION_GROUP_PLAYER=10 COLLISION_GROUP_WEAPON=17
HUD_PRINTNOTIFY=1 HUD_PRINTCONSOLE=2 HUD_PRINTTALK=3 HUD_PRINTCENTER=4
IN_ATTACK=1 IN_JUMP=2 IN_DUCK=4 IN_FORWARD=8 IN_BACK=16 IN_USE=32 IN_RELOAD=8192 IN_WALK=262144
DMG_GENERIC=0 DMG_CRUSH=1 DMG_BULLET=2 DMG_SLASH=4 DMG_BURN=8 DMG_CLUB=128
FCVAR_NONE=0 FCVAR_ARCHIVE=128 FCVAR_NOTIFY=256 FCVAR_REPLICATED=8192 FCVAR_PROTECTED=32 FCVAR_SERVER_CAN_EXECUTE=16777216 FCVAR_NEVER_AS_STRING=4096
ACT_IDLE=1 ACT_WALK=6 ACT_RUN=10 ACT_JUMP=38 ACT_GESTURE_RANGE_ATTACK1=41
MAT_ANTLION=81 MAT_BLOODYFLESH=68 MAT_FLESH=70 MAT_METAL=77 MAT_DIRT=85 MAT_WOOD=87 MAT_GLASS=89
MASK_ALL=-1 MASK_SOLID=33570827 MASK_SHOT=1174421507 MASK_PLAYERSOLID=33636363
D_LIGHT=0 D_FR=1 D_HT=2 D_NU=3 D_LI=4 D_ER=5 D_SD=6
PLAYERANIMEVENT_ATTACK_PRIMARY=0 PLAYERANIMEVENT_JUMP=5
P11_NOW = 1000.0
CLIENT = false
SERVER = true
GAMEMODE = GM

-- ============ расширения stdlib, которые GMod навешивает на string/table/math ============
math.Rand = function(a, b) return a + math.random() * ((b or 1) - a) end
math.Approach = function(c, t, d) if c > t then return math.max(c - d, t) else return math.min(c + d, t) end end
math.Clamp = function(v, a, b) if v < a then return a end if v > b then return b end return v end
math.Distance = function(x1,y1,x2,y2) return math.sqrt((x2-x1)^2 + (y2-y1)^2) end
math.NormalizeAngle = function(a) a = a % 360 if a > 180 then a = a - 360 end return a end
math.Round = function(v, d) local m = 10^(d or 0) return math.floor(v * m + 0.5) / m end
math.TimeFraction = function(a, b, c) return math.Clamp((c - a) / (b - a), 0, 1) end
math.easeInOut = function(p, eo, ei) return p end
math.BSpline = function(t, pts) return pts[1] or Vector() end
math.Truncate = function(v, d) return v end
math.remap = function(v, ia, ib, oa, ob) return oa + (v - ia) * (ob - oa) / (ib - ia) end
math.RandInt = math.RandInt or function(a,b) return math.random(a,b) end

string.Explode = function(sep, str, ws) local out, i, pos = {}, 1, 1
  if str == nil then return {} end
  for s, e in function() return string.find(str, sep, pos, true) end do
    out[i] = string.sub(str, pos, s - 1); i = i + 1; pos = e + 1
  end
  out[i] = string.sub(str, pos); return out end
string.Split = string.Explode
string.ToTable = string.Explode
string.Trim = function(s, ch) ch = ch or " " s = tostring(s or "")
  local a, b = 1, #s
  while a <= b and string.sub(s, a, a) == ch do a = a + 1 end
  while b >= a and string.sub(s, b, b) == ch do b = b - 1 end
  return string.sub(s, a, b) end
string.TrimLeft = function(s, ch) return string.Trim(s, ch) end
string.TrimRight = function(s, ch) return string.Trim(s, ch) end
string.StartWith = function(s, st) return string.sub(tostring(s or ""), 1, #st) == st end
string.EndsWith = function(s, en) s = tostring(s or "") return string.sub(s, -#en) == en end
string.Left = function(s, n) return string.sub(tostring(s or ""), 1, n) end
string.Right = function(s, n) return string.sub(tostring(s or ""), -n) end
string.Replace = function(s, f, r) local out = tostring(s or "")
  out = string.gsub(out, f, r) return out end
string.NiceTime = function(sec) return tostring(math.floor((sec or 0) / 60)) .. " мин" end
string.ToMinutesSeconds = function(s) s = s or 0 return string.format("%02d:%02d", math.floor(s/60), math.floor(s%60)) end
string.ToMinutesSecondsMilliseconds = function(s) return string.ToMinutesSeconds(s) end
string.FormattedTime = function(f, fmt) f = f or 0 return {hours=math.floor(f/3600), minutes=math.floor(f%3600/60), seconds=math.floor(f%60), milliseconds=0} end
string.GetExtensionFromFilename = function(p) return string.match(tostring(p or ""), "%.([^%.]+)$") end
string.StripExtension = function(p) return string.gsub(tostring(p or ""), "%.[^%.]+$", "") end
string.GetFileFromFilename = function(p) return string.match(tostring(p or ""), "[^/\\]+$") or "" end
string.GetPathFromFilename = function(p) return string.match(tostring(p or ""), "^(.*)[/\\]") or "" end
string.FromColor = function(c) return "" end
string.ToColor = function(s) return Color() end
string.PatternSafe = function(s) return string.gsub(tostring(s or ""), "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1") end
string.JavascriptSafe = function(s) return tostring(s or "") end
string.Comma = function(n) n = tostring(math.floor(tonumber(n) or 0))
  local f = "" while #n > 3 do f = " " .. string.sub(n, -3) .. f; n = string.sub(n, 1, -4) end return n .. f end
string.Implode = function(sep, t) return table.concat(t or {}, sep) end
string.SetChar = function(s, i, c) return string.sub(s,1,i-1)..c..string.sub(s,i+1) end
string.GetChar = function(s, i) return string.sub(s, i, i) end
string.NiceSize = function(n) return tostring(n) .. " Б" end
string.ToTable2 = string.Explode

table.Count = function(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
table.IsEmpty = function(t) return next(t or {}) == nil end
table.HasValue = function(t, v) for _, x in pairs(t or {}) do if x == v then return true end end return false end
table.Contains = table.HasValue
table.KeyFromValue = function(t, v) for k, x in pairs(t or {}) do if x == v then return k end end end
table.KeysFromValue = function(t, v) local o = {} for k, x in pairs(t or {}) do if x == v then o[#o+1] = k end end return o end
table.Random = function(t) local n = table.Count(t) if n == 0 then return nil end
  local i = math.random(1, n) local c = 0 for k, v in pairs(t) do c = c + 1 if c == i then return v end end end
table.Copy = function(t, lt) if type(t) ~= "table" then return t end local o = {}
  for k, v in pairs(t) do o[k] = type(v) == "table" and table.Copy(v, lt) or v end return o end
table.Merge = function(a, b) for k, v in pairs(b or {}) do a[k] = v end return a end
table.Empty = function(t) for k in pairs(t or {}) do t[k] = nil end return t end
table.Add = function(a, b) for _, v in ipairs(b or {}) do a[#a+1] = v end return a end
table.RemoveByValue = function(t, v) local f = false for i = #t, 1, -1 do if t[i] == v then table.remove(t, i) f = true end end return f end
table.FirstValue = function(t) for _, v in pairs(t or {}) do return v end end
table.FirstKey = function(t) for k in pairs(t or {}) do return k end end
table.LastValue = function(t) local v for _, x in pairs(t or {}) do v = x end return v end
table.LastKey = function(t) local k for x in pairs(t or {}) do k = x end return k end
table.Sanitise = function(t) return t end table.DeSanitise = function(t) return t end
table.LowerKeyNames = function(t) local o = {} for k, v in pairs(t or {}) do o[string.lower(tostring(k))] = v end return o end
table.ForceInsert = function(t, v) t[#t+1] = v return t end
table.SortByMember = function(t, m, d) table.sort(t, function(a, b) return (a[m] or 0) > (b[m] or 0) end) end
table.Reverse = function(t) local o = {} for i = #t, 1, -1 do o[#o+1] = t[i] end return o end
table.Shuffle = function(t) for i = #t, 2, -1 do local j = math.random(i) t[i], t[j] = t[j], t[i] end return t end
table.InsertIf = function(t, c, v) if c then t[#t+1] = v end return c and true or false end
table.Lookupify = function(t) local o = {} for _, v in ipairs(t or {}) do o[v] = true end return o end
table.GetFirstKey = table.FirstKey table.GetFirstValue = table.FirstValue
table.GetLastKey = table.LastKey table.GetLastValue = table.LastValue
table.GetWinningKey = function(t) local k, m for a, b in pairs(t or {}) do if not m or b > m then m, k = b, a end end return k end
table.FuzzyScore = function(a, b) return 0 end table.CopyFromTo = function(a, b) for k,v in pairs(a or {}) do b[k]=v end end

function SortedPairs(t, desc) local ks = {} for k in pairs(t or {}) do ks[#ks+1] = k end
  table.sort(ks, function(a, b) if desc then return tostring(a) > tostring(b) end return tostring(a) < tostring(b) end)
  local i = 0 return function() i = i + 1 local k = ks[i] if k == nil then return nil end return k, t[k] end end
function SortedPairsByValue(t, desc) local ks = {} for k in pairs(t or {}) do ks[#ks+1] = k end
  table.sort(ks, function(a, b) if desc then return t[a] > t[b] end return t[a] < t[b] end)
  local i = 0 return function() i = i + 1 local k = ks[i] if k == nil then return nil end return k, t[k] end end
function SortedPairsByMemberValue(t, m, desc) local ks = {} for k in pairs(t or {}) do ks[#ks+1] = k end
  table.sort(ks, function(a, b) if desc then return (t[a][m] or 0) > (t[b][m] or 0) end return (t[a][m] or 0) < (t[b][m] or 0) end)
  local i = 0 return function() i = i + 1 local k = ks[i] if k == nil then return nil end return k, t[k] end end
function RandomPairs(t, desc) return pairs(t or {}) end
P11_METAS = {}
P11_PMETA = {
  SetNWString = function(self, k, v) self._nw = self._nw or {}; self._nw[k] = v end,
}
P11_METAS["Player"] = P11_PMETA
function FindMetaTable(n)
  if not P11_METAS[n] then P11_METAS[n] = autostub("meta:" .. tostring(n)) end
  return P11_METAS[n]
end
function DeriveClass(n) local c = {}; c.BaseClass = autostub("base") return c end
function AccessorFunc(t, member, name, flags)
  t["Get" .. name] = function(s) return s[member] end
  t["Set" .. name] = function(s, v) s[member] = v return s end
end
function AccessorFuncNW() end
function Lerp(d, a, b) return a + (b - a) * d end
function LerpVector(d, a, b) return a or Vector() end
function LerpAngle(d, a, b) return a or Angle() end
function ScrW() return 1920 end function ScrH() return 1080 end
function LocalPlayer() return _G.P11_LOCAL end
function RealFrameTime() return 0.015 end
function GetRenderTarget(n, w, h) return autostub("rt") end
function GetRenderTargetEx() return autostub("rt") end
function WorldToLocal(v, a, o, an) return Vector(), Angle() end
function OrderVectors(a, b) return a, b end
function FrameNumber() return 1 end
function EngineTime() return 0 end
function SetGlobalVar(n, v) _G["G_"..n] = v end
function GetGlobalVar(n, d) return _G["G_"..n] or d end
function GetGlobalBool(n, d) return GetGlobalVar(n, d) end
function GetGlobalInt(n, d) return GetGlobalVar(n, d) end
function GetGlobalFloat(n, d) return GetGlobalVar(n, d) end
function GetGlobalString(n, d) return GetGlobalVar(n, d) end
function GetGlobalEntity(n, d) return nil end
function GetGlobalAngle(n, d) return Angle() end
function GetGlobalVector(n, d) return Vector() end
function GetGlobalVar2() return nil end
function GetGlobalVarInt() return 0 end
function SetGlobalAngle() end function SetGlobalVector() end function SetGlobalEntity() end
function SetGlobalBool() end function SetGlobalInt() end function SetGlobalFloat() end function SetGlobalString() end
function GetViewEntity() return nil end
function GetGlobalVar3() return nil end
P11_LOCAL = _G.P11_FAKE_PLY and P11_FAKE_PLY(1) or nil

'''

# ---------------- УРОВЕНЬ 2: ЗАГРУЗКА ----------------
def level_load(files_order, label):
    L = LuaRuntime(unpack_returned_tuples=True)
    L.execute(STUBS)
    L.execute(HELPER)
    g = L.globals()
    g.P11_NOW = 1000.0
    g.GM = L.table_from({})
    errors, loaded = [], 0
    for path in files_order:
        full = os.path.join(GM, path) if not os.path.isabs(path) else path
        if not os.path.exists(full):
            errors.append((path, "ФАЙЛ НЕ НАЙДЕН")); continue
        src = open(full, encoding="utf-8", errors="replace").read()
        try:
            r = L.eval("P11_RunChunk")(src, "@" + rel(full))
            if r["ok"]:
                loaded += 1
            else:
                errors.append((path, "%s: %s" % (r["stage"], str(r["err"]).strip())))
        except Exception as e:
            errors.append((path, "HARNESS: " + str(e).strip()))
    hookerrs = L.eval("table.concat(P11_HOOK_ERR, '\\n')").split("\n")
    return L, loaded, errors, hookerrs

def order_of(path, var, base=None):
    src = open(path, encoding="utf-8").read()
    i = src.find("local %s = {" % var)
    j = src.find("{", i); k = src.find("\n}", j)
    body = src[j:k]
    # режем строковые комментарии, чтобы закомментированные модули не считались живыми
    body = re.sub(r"--[^\n]*", "", body)
    return re.findall(r'"([^"]+\.lua)"', body)

if __name__ == "__main__":
    files = luafiles()
    print("VM: %s" % VM)
    print("=" * 78)
    print("УРОВЕНЬ 1 — СИНТАКСИС (все %d .lua файлов)" % len(files))
    print("=" * 78)
    bad = level_syntax(files)
    if not bad:
        print("  ✅ синтаксических ошибок нет")
    for f, e in bad:
        print("  ❌ %s\n      %s" % (f, str(e).strip().replace("\n", " ")[:300]))

    if "--only-syntax" in sys.argv:
        sys.exit(1 if bad else 0)

    sv = order_of(os.path.join(GM, "init.lua"), "sv")
    sh = order_of(os.path.join(GM, "shared.lua"), "sh")
    autorun_sv = sorted(rel(q) for q in luafiles()
                        if rel(q).startswith("lua/autorun/shared/") or rel(q).startswith("lua/autorun/server/"))
    # wiki.facepunch.com/gmod/Lua_Loading_Order: includes -> ГЕЙММОД -> autorun/ -> autorun/server/
    order = ["shared.lua"] + sh + sv + [os.path.join(ROOT, x) for x in autorun_sv]
    print()
    print("=" * 78)
    print("УРОВЕНЬ 2 — ЗАГРУЗКА СЕРВЕРА (гейммод: shared + %d sh + %d sv, потом autorun %d)" % (len(sh), len(sv), len(autorun_sv)))
    print("=" * 78)
    L, loaded, errors, hookerrs = level_load(order, "server")
    print("  загружено без ошибок: %d/%d" % (loaded, len(order)))
    for f, e in errors:
        print("  ❌ %-46s %s" % (f, str(e).replace("\n", " ")[:240]))

    # ---------- УРОВЕНЬ 2c: КЛИЕНТ ----------
    cll = order_of(os.path.join(GM, "cl_init.lua"), "cl", base="cl_init.lua")
    cl_files = ["cl_init.lua"] + sh + cll
    ar_cl = sorted(rel(p) for p in luafiles()
                   if rel(p).startswith("lua/autorun/shared/")) + \
            sorted(rel(p) for p in luafiles()
                   if rel(p).startswith("lua/autorun/client/"))
    cl_files += [os.path.join(ROOT, x) for x in ar_cl]
    print()
    print("=" * 78)
    print("УРОВЕНЬ 2c — ЗАГРУЗКА КЛИЕНТА (cl_init: shared %d + cl %d, потом autorun %d = %d файлов)" % (len(sh), len(cll), len(ar_cl), len(cl_files)))
    print("=" * 78)
    L2, loaded2, errors2, hookerrs2 = level_load(cl_files, "client")
    print("  загружено без ошибок: %d/%d" % (loaded2, len(cl_files)))
    for f, e in errors2:
        print("  ❌ %-46s %s" % (f, str(e).replace("\n", " ")[:240]))

    # уровень 3: хуки загрузки
    # ---------- УРОВЕНЬ 4: клиентский кадр ----------
    print()
    print("=" * 78)
    print("УРОВЕНЬ 4 — КЛИЕНТСКИЙ КАДР (HUDPaint x2 + Think x2 на заглушках)")
    print("=" * 78)
    before4 = L2.eval("#P11_HOOK_ERR") or 0
    perf0 = L2.eval("#P11_PERF") or 0
    L2.execute('P11_SpawnPlayers(2)')
    for _ in range(2):
        L2.execute('hook.Call("HUDPaint")')
        L2.execute('hook.Call("Think")')
    newerr4 = [x for x in L2.eval("table.concat(P11_HOOK_ERR, '\\n')").split("\n") if x]
    perf = [str(x) for x in L2.eval("table.concat(P11_PERF, '\\n')").split("\n") if x]
    from collections import Counter
    cnt = Counter(perf)
    print("  ошибок в HUDPaint/Think: %d" % len(newerr4))
    for e in newerr4[:25]: print("     -", e.replace("\n", " ")[:200])
    print("  тяжёлых вызовов ВНУТРИ кадра (за 2 кадра): %d уникальных %d" % (len(cnt), len(perf)))
    for k, v in cnt.most_common(25):
        print("     - x%-3d %s" % (v // 2, k))
    print()
    print("=" * 78)
    print("УРОВЕНЬ 3 — ХУКИ ЗАГРУЗКИ (Initialize / InitPostEntity / PostGamemodeLoaded)")
    print("=" * 78)
    L.execute("P11_SpawnPlayers(3)")
    before = len(hookerrs)
    try:
        L.execute('hook.Run("Initialize")')
        L.execute('hook.Run("InitPostEntity")')
        L.execute('hook.Run("PostGamemodeLoaded")')
        L.execute('P11_FireTimers(200)')
        L.execute('hook.Run("PostCleanupMap")')
    except Exception as e:
        print("  ❌ хук упал:", str(e)[:200])
    newerr = [x for x in L.eval("table.concat(P11_HOOK_ERR, '\\n')").split("\n") if x]
    print("  ошибок внутри хуков/таймеров: %d" % len(newerr))
    for e in newerr[:60]:
        print("     -", str(e).replace("\n", " ")[:220])
    sys.exit(1 if (bad or errors or newerr) else 0)
