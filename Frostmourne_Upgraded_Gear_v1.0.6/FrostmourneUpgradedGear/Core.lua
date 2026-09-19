local ADDON = ...
FUL = FUL or {}
FUL.version = "1.0.6"
FUL.productName = "Frostmourne Upgraded Gear"
FUL.SOURCE_QUEST = 1
FUL.SOURCE_DROP = 2
FUL.SOURCE_CRAFT = 3
FUL.SOURCE_NAMES = { [1] = "Quest", [2] = "Drop", [3] = "Craft" }

-- Official Frostmourne/Rebuffed quest rates published by Whitemane (Sep 2026).
-- Uncommon quest reward: 19% Rare, 1% Epic. Rare quest reward: 20% Epic.
FUL.OFFICIAL = {
  questGreenRare = 0.19,
  questGreenEpic = 0.01,
  questBlueEpic = 0.20,
}

local function DefaultDB()
  return {
    version = 1,
    language = "enUS",
    trackingEnabled = true,
    strictMode = true,
    showTooltip = true,
    showVariantPreviews = true,
    previewStyle = "INLINE",
    previewMode = "ALWAYS",
    showLowerVariants = true,
    showOwnedItemProjections = true,
    upgradeAlerts = true,
    upgradeSounds = true,
    notifyRare = true,
    notifyEpic = true,
    failedUpgradeAlerts = true,
    showMinimapButton = true,
    debug = false,
    minimapAngle = 220,
    sessionSeq = 0,
    events = {},
    dict = { name = {}, zone = {}, subzone = {}, quest = {}, mob = {}, recipe = {}, char = {} },
    ignored = { uncertain = 0, ineligible = 0 },
    dropScan = { allGear = 0, eligible = 0, eligibleNormal = 0, rare = 0, epic = 0 },
  }
end

function FUL:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff7adbf2FUL|r " .. tostring(msg))
end

function FUL:InitDB()
  if type(FrostmourneUpgradedLookDB) ~= "table" or FrostmourneUpgradedLookDB.version ~= 1 then
    FrostmourneUpgradedLookDB = DefaultDB()
  end
  local db = FrostmourneUpgradedLookDB
  if db.language ~= "frFR" and db.language ~= "enUS" then db.language = "enUS" end
  db.trackingEnabled = true
  db.events = db.events or {}
  db.dict = db.dict or { name = {}, zone = {}, subzone = {}, quest = {}, mob = {}, recipe = {}, char = {} }
  for _, k in ipairs({"name","zone","subzone","quest","mob","recipe","char"}) do db.dict[k] = db.dict[k] or {} end
  db.ignored = db.ignored or { uncertain = 0, ineligible = 0 }
  if db.strictMode == nil then db.strictMode = true end
  if db.showTooltip == nil then db.showTooltip = true end
  if db.showVariantPreviews == nil then db.showVariantPreviews = true end
  if db.previewStyle ~= "CARDS" and db.previewStyle ~= "INLINE" then db.previewStyle = "INLINE" end
  if db.previewMode ~= "ALT" and db.previewMode ~= "ALWAYS" and db.previewMode ~= "OFF" then db.previewMode = "ALWAYS" end
  if db.showLowerVariants == nil then db.showLowerVariants = true end
  if db.showOwnedItemProjections == nil then db.showOwnedItemProjections = true end
  if db.upgradeAlerts == nil then db.upgradeAlerts = true end
  if db.upgradeSounds == nil then db.upgradeSounds = true end
  if db.notifyRare == nil then db.notifyRare = true end
  if db.notifyEpic == nil then db.notifyEpic = true end
  if db.failedUpgradeAlerts == nil then db.failedUpgradeAlerts = true end
  if db.showMinimapButton == nil then db.showMinimapButton = true end
  db.dropScan = db.dropScan or { allGear = 0, eligible = 0, eligibleNormal = 0, rare = 0, epic = 0 }
  for _, k in ipairs({"allGear","eligible","eligibleNormal","rare","epic"}) do db.dropScan[k] = db.dropScan[k] or 0 end
  if db.minimapAngle == nil then db.minimapAngle = 220 end
  db.sessionSeq = (db.sessionSeq or 0) + 1
  self.sessionID = db.sessionSeq
  self.db = db
  self.SOURCE_NAMES = { [1] = self:T("source_quest"), [2] = self:T("source_drop"), [3] = self:T("source_craft") }
  self:BuildDictReverse()
end

function FUL:ResetStatistics()
  if not self.db then return end
  self.db.events = {}
  self.db.dict = { name = {}, zone = {}, subzone = {}, quest = {}, mob = {}, recipe = {}, char = {} }
  self.db.ignored = { uncertain = 0, ineligible = 0 }
  self.db.dropScan = { allGear = 0, eligible = 0, eligibleNormal = 0, rare = 0, epic = 0 }
  self.db.trackingEnabled = true
  self:BuildDictReverse()
  if self.RebuildStats then self:RebuildStats() end
end

function FUL:BuildDictReverse()
  self.dictRev = {}
  for kind, values in pairs(self.db.dict) do
    local rev = {}
    for id, value in ipairs(values) do rev[value] = id end
    self.dictRev[kind] = rev
  end
end

function FUL:DictID(kind, value)
  if not value or value == "" then return 0 end
  local rev = self.dictRev[kind]
  local id = rev[value]
  if id then return id end
  local values = self.db.dict[kind]
  id = #values + 1
  values[id] = value
  rev[value] = id
  return id
end

function FUL:DictValue(kind, id)
  if not id or id == 0 then return nil end
  return self.db.dict[kind] and self.db.dict[kind][id]
end

function FUL:GetItemID(link)
  if not link then return nil end
  return tonumber(string.match(link, "item:(%d+)"))
end

function FUL:IsCustomVariantID(id)
  return id and id >= 1200000 and id <= 1209999
end

function FUL:GetCurrentCharacterKey()
  return (GetRealmName() or "?") .. ":" .. (UnitName("player") or "?")
end

-- Exact base IDs from the MASTER catalog are preferred when available.
function FUL:GetBaseRecord(itemLink)
  local id = self:GetItemID(itemLink)
  if not id or not FUL_BASE_ITEMS then return nil end
  return FUL_BASE_ITEMS[id]
end

-- Build stable, locale-independent indexes once. All item matching should use IDs
-- whenever the item is present in the embedded MASTER-derived tables.
function FUL:EnsureVariantIndexes()
  if self.variantIndexesReady then return end
  self.variantBaseIndex = {}
  self.variantRecordIndex = {}
  self.variantFamilyNameIndex = {}

  for familyName, rows in pairs(FUL_VARIANTS or {}) do
    for _, row in ipairs(rows) do
      local variantID = row and row[1]
      if variantID and variantID ~= 0 then
        if not self.variantRecordIndex[variantID] then self.variantRecordIndex[variantID] = row end
        if not self.variantFamilyNameIndex[variantID] then self.variantFamilyNameIndex[variantID] = familyName end
      end
    end
  end

  for baseID, pair in pairs(FUL_BASE_VARIANTS or {}) do
    for _, variantID in ipairs(pair) do
      if variantID and variantID ~= 0 and not self.variantBaseIndex[variantID] then
        self.variantBaseIndex[variantID] = baseID
      end
    end
  end

  self.variantIndexesReady = true
end

-- Resolve the original item behind a custom Rare/Epic variant. This lets the
-- tooltip reproduce Frostmourne's 1/2 or 1/3 upgrade-level convention.
function FUL:GetOriginalBase(itemID)
  if not itemID then return nil, nil end
  if FUL_BASE_ITEMS and FUL_BASE_ITEMS[itemID] then
    return itemID, FUL_BASE_ITEMS[itemID]
  end
  self:EnsureVariantIndexes()
  local baseID = self.variantBaseIndex[itemID]
  return baseID, baseID and FUL_BASE_ITEMS and FUL_BASE_ITEMS[baseID] or nil
end

-- Resolve an upgrade family ID-first. Localized names are only a final fallback
-- for legacy/unmapped records. This keeps matching stable on EN/FR and future locales.
function FUL:ResolveFamily(itemLink, explicitName)
  local liveName, link, quality, ilvl, req, class, subclass, _, equipLoc = GetItemInfo(itemLink or explicitName)
  local itemID = self:GetItemID(itemLink)
  self:EnsureVariantIndexes()

  local baseID, original = self:GetOriginalBase(itemID)
  local baseRecord = itemID and FUL_BASE_ITEMS and FUL_BASE_ITEMS[itemID]
  local variantRecord = itemID and self.variantRecordIndex[itemID]

  -- Canonical internal family name comes from our embedded DB, never the client locale,
  -- whenever we know the ID.
  local canonicalName
  if original then
    canonicalName = original[1]
  elseif variantRecord then
    canonicalName = self.variantFamilyNameIndex[itemID]
  elseif baseRecord then
    canonicalName = baseRecord[1]
  else
    canonicalName = explicitName or liveName
  end
  if not canonicalName then return nil end

  local all = FUL_VARIANTS and FUL_VARIANTS[canonicalName]
  -- Last-resort compatibility fallback for records that are not present in the ID maps.
  if not all then
    local fallbackName = explicitName or liveName
    all = fallbackName and FUL_VARIANTS and FUL_VARIANTS[fallbackName] or nil
    if all then canonicalName = fallbackName end
  end
  if not all then return nil end

  -- For current-item metadata, prefer the embedded record so class/subclass strings
  -- cannot change behavior with the client locale.
  local currentRecord = variantRecord or baseRecord
  if currentRecord then
    quality, ilvl, req, class, subclass, equipLoc = currentRecord[2], currentRecord[3], currentRecord[4], currentRecord[5], currentRecord[6], currentRecord[7]
  end

  -- Exact base -> Rare/Epic IDs from the MASTER-derived map. This path is completely
  -- independent from item names and is used for both base items and their custom variants.
  if baseID and FUL_BASE_VARIANTS and FUL_BASE_VARIANTS[baseID] then
    local pair = FUL_BASE_VARIANTS[baseID]
    local rare, epic = {}, {}
    local rareRec = pair[1] and pair[1] ~= 0 and self.variantRecordIndex[pair[1]] or nil
    local epicRec = pair[2] and pair[2] ~= 0 and self.variantRecordIndex[pair[2]] or nil
    if rareRec then rare[#rare+1] = rareRec end
    if epicRec then epic[#epic+1] = epicRec end

    return {
      name = canonicalName,
      displayName = liveName or explicitName or canonicalName,
      currentQuality = quality,
      currentIlvl = ilvl,
      currentClass = class,
      currentSubclass = subclass,
      currentSlot = equipLoc,
      rare = rare,
      epic = epic,
      candidates = all,
      ambiguous = false,
      exactBaseID = baseID,
      matchedByID = true,
    }
  end

  -- Legacy fallback for the small set of families without an exact base-ID pair.
  -- The canonical family itself is still found by ID when possible; metadata is only
  -- used to disambiguate duplicate historical names.
  local candidates = {}
  for _, r in ipairs(all) do candidates[#candidates+1] = r end
  local function filter(index, value)
    if not value or value == "" then return end
    local tmp = {}
    for _, r in ipairs(candidates) do if r[index] == value then tmp[#tmp+1] = r end end
    if #tmp > 0 then candidates = tmp end
  end
  filter(5, class)
  filter(6, subclass)
  filter(7, equipLoc)
  if ilvl then
    local tmp = {}
    for _, r in ipairs(candidates) do if r[3] == ilvl then tmp[#tmp+1] = r end end
    if #tmp > 0 then candidates = tmp end
  end

  local rare, epic = {}, {}
  for _, r in ipairs(candidates) do
    if r[2] == 3 then rare[#rare+1] = r end
    if r[2] == 4 then epic[#epic+1] = r end
  end
  return {
    name = canonicalName,
    displayName = liveName or explicitName or canonicalName,
    currentQuality = quality,
    currentIlvl = ilvl,
    currentClass = class,
    currentSubclass = subclass,
    currentSlot = equipLoc,
    rare = rare,
    epic = epic,
    candidates = candidates,
    ambiguous = (#rare > 1 or #epic > 1),
    matchedByID = (baseRecord ~= nil or variantRecord ~= nil),
  }
end

-- Stable family key used by quest/craft tracking. Exact families use the vanilla
-- base item ID; legacy families use the canonical embedded family name.
function FUL:GetFamilyKey(itemLink, explicitName)
  local family = self:ResolveFamily(itemLink, explicitName)
  if not family then return nil, nil end
  if family.exactBaseID then return "id:" .. tostring(family.exactBaseID), family end
  return "family:" .. tostring(family.name or ""), family
end

function FUL:InferBaseQuality(itemLink, family)
  local _, _, quality = GetItemInfo(itemLink)
  local id = self:GetItemID(itemLink)
  if not family then return quality end
  local _, original = self:GetOriginalBase(id)
  if original and (original[2] == 2 or original[2] == 3) then return original[2] end
  if quality == 2 or quality == 3 then return quality end
  if #family.rare > 0 then return 2 end
  return 3
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    FUL:InitDB()
  elseif event == "PLAYER_LOGIN" then
    if not FUL.db then FUL:InitDB() end
    if FUL.RebuildStats then FUL:RebuildStats() end
    if FUL.UI and FUL.UI.Init then FUL.UI:Init() end
    FUL:Print(FUL:T("addon_loaded", FUL.productName or "FUL", FUL.version))
  end
end)

SLASH_FUL1 = "/ful"
SLASH_FUL2 = "/frostlook"
SlashCmdList.FUL = function(msg)
  msg = string.lower((msg or ""):match("^%s*(.-)%s*$"))
  if msg == "status" or msg == "" then
    FUL:Print(FUL:T("status_auto", #FUL.db.events, tostring(FUL.sessionID)))
  elseif msg == "stats" then
    if FUL.PrintStats then FUL:PrintStats() end
  elseif msg == "export" or msg == "import" then
    if FUL.UI then FUL.UI:BuildMainFrame(); FUL.UI.frame:Show(); FUL.UI:SelectPage("data") end
  elseif msg == "debug on" then
    FUL.db.debug = true; FUL:Print(FUL:T("debug_on"))
  elseif msg == "debug off" then
    FUL.db.debug = false; FUL:Print(FUL:T("debug_off"))
  elseif msg == "minimap on" then
    FUL.db.showMinimapButton = true
    if FUL.UI and FUL.UI.RefreshMinimapButton then FUL.UI:RefreshMinimapButton() end
    FUL:Print(FUL:T("minimap_on_msg"))
  elseif msg == "minimap off" then
    FUL.db.showMinimapButton = false
    if FUL.UI and FUL.UI.RefreshMinimapButton then FUL.UI:RefreshMinimapButton() end
    FUL:Print(FUL:T("minimap_off_msg"))
  else
    FUL:Print(FUL:T("slash_help"))
    if FUL.UI then FUL.UI:BuildMainFrame(); FUL.UI.frame:Show() end
  end
end
