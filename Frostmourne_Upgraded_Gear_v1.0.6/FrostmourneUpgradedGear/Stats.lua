FUL.runtimeStats = nil

local function NewBucket()
  return { total = 0, normal = 0, rare = 0, epic = 0 }
end

function FUL:Outcome(baseQuality, resultQuality)
  if baseQuality == 2 then
    if resultQuality == 4 then return "epic" end
    if resultQuality == 3 then return "rare" end
    return "normal"
  elseif baseQuality == 3 then
    if resultQuality == 4 then return "epic" end
    return "normal"
  end
  return "normal"
end

local function AddTo(map, key, outcome)
  if not key or key == 0 then return end
  local b = map[key]
  if not b then b = NewBucket(); map[key] = b end
  b.total = b.total + 1
  b[outcome] = (b[outcome] or 0) + 1
end

function FUL:RebuildStats()
  local s = { global = {}, byName = {}, byZone = {}, byQuest = {}, byRecipe = {}, byBase = {} }
  for source = 1, 3 do
    s.global[source] = NewBucket(); s.byName[source] = {}; s.byZone[source] = {}; s.byQuest[source] = {}; s.byRecipe[source] = {}
    s.byBase[source] = { [2] = NewBucket(), [3] = NewBucket() }
  end
  self.runtimeStats = s
  for _, e in ipairs(self.db.events) do self:AddEventToStats(e) end
end

-- Event schema:
-- 1 time, 2 source, 3 nameKey, 4 resultItemID, 5 resultQuality, 6 baseQuality,
-- 7 zoneKey, 8 subzoneKey, 9 questKey, 10 mobKey, 11 recipeKey, 12 charKey, 13 sessionID.
function FUL:AddEventToStats(e)
  local s = self.runtimeStats
  if not s then return end
  local source, baseQuality, outcome = e[2], e[6], self:Outcome(e[6], e[5])
  local g = s.global[source]
  g.total = g.total + 1; g[outcome] = (g[outcome] or 0) + 1
  local gb = s.byBase[source] and s.byBase[source][baseQuality]
  if gb then gb.total = gb.total + 1; gb[outcome] = (gb[outcome] or 0) + 1 end
  AddTo(s.byName[source], e[3], outcome)
  AddTo(s.byZone[source], e[7], outcome)
  AddTo(s.byQuest[source], e[9], outcome)
  AddTo(s.byRecipe[source], e[11], outcome)
end

function FUL:RecordObservation(obs)
  if not self.db.trackingEnabled then return false end
  if not obs or not obs.itemLink or not obs.source then return false end
  local itemName, _, resultQuality = GetItemInfo(obs.itemLink)
  itemName = obs.itemName or itemName
  if not itemName then return false end
  local family = self:ResolveFamily(obs.itemLink, itemName)
  if not family then
    self.db.ignored.ineligible = (self.db.ignored.ineligible or 0) + 1
    return false
  end
  local baseQuality = obs.baseQuality or self:InferBaseQuality(obs.itemLink, family)
  if baseQuality ~= 2 and baseQuality ~= 3 then return false end
  if not resultQuality then return false end

  local questValue = nil
  if obs.questID or obs.questTitle then questValue = tostring(obs.questID or 0) .. "\t" .. tostring(obs.questTitle or "") end
  local recipeValue = nil
  if obs.recipeID or obs.recipeName then recipeValue = tostring(obs.recipeID or 0) .. "\t" .. tostring(obs.profession or "") .. "\t" .. tostring(obs.recipeName or "") end
  local mobValue = nil
  if obs.mobGUID or obs.mobName then mobValue = tostring(obs.mobGUID or "") .. "\t" .. tostring(obs.mobName or "") end

  local e = {
    time(), obs.source, self:DictID("name", itemName), self:GetItemID(obs.itemLink) or 0,
    resultQuality, baseQuality, self:DictID("zone", obs.zone or GetRealZoneText()),
    self:DictID("subzone", obs.subzone or GetSubZoneText()), self:DictID("quest", questValue),
    self:DictID("mob", mobValue), self:DictID("recipe", recipeValue),
    self:DictID("char", self:GetCurrentCharacterKey()), self.sessionID or 0,
  }
  self.db.events[#self.db.events+1] = e
  self:AddEventToStats(e)
  local outcome = self:Outcome(baseQuality, resultQuality)
  if (outcome == "rare" or outcome == "epic") and self.ShowUpgradeAlert then
    self:ShowUpgradeAlert(obs.itemLink, itemName, outcome, obs.source)
  elseif outcome == "normal" and (obs.source == self.SOURCE_QUEST or obs.source == self.SOURCE_DROP)
      and self.ShowUpgradeMissAlert then
    -- The family was resolved above, so this is a confirmed eligible item that stayed at base quality.
    self:ShowUpgradeMissAlert(obs.itemLink, itemName, obs.source, baseQuality)
  end
  if self.db.debug then
    self:Print("LOG " .. self.SOURCE_NAMES[obs.source] .. " " .. itemName .. " q" .. resultQuality .. " base q" .. tostring(baseQuality))
  end
  return true
end

local function Pct(n, d)
  if not d or d == 0 then return "-" end
  return string.format("%.2f%%", 100*n/d)
end

function FUL:GetNameBucket(source, itemName)
  if not self.runtimeStats then return nil end
  local id = self.dictRev.name[itemName]
  return id and self.runtimeStats.byName[source][id] or nil
end

function FUL:GetBaseBucket(source, baseQuality)
  if not self.runtimeStats or not self.runtimeStats.byBase[source] then return nil end
  return self.runtimeStats.byBase[source][baseQuality]
end

function FUL:PrintStats()
  if not self.runtimeStats then self:RebuildStats() end
  for source = 1, 3 do
    local b = self.runtimeStats.global[source]
    self:Print(string.format("%s n=%d | normal %s | rare %s | epic %s", self.SOURCE_NAMES[source], b.total,
      Pct(b.normal,b.total), Pct(b.rare,b.total), Pct(b.epic,b.total)))
  end
  self:Print("Ignorés: inéligibles=" .. tostring(self.db.ignored.ineligible or 0) .. ", incertains=" .. tostring(self.db.ignored.uncertain or 0))
end
