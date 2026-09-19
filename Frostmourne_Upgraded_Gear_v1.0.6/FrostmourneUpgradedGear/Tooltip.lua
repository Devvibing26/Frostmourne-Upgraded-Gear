local refreshing = false
local lastLink = nil
local lastName = nil
local lastFamily = nil
local inlineAppliedLink = nil

local PREVIEW_MAX_STATS = 8

local STAT_ORDER = {
  "ITEM_MOD_AGILITY_SHORT",
  "ITEM_MOD_STRENGTH_SHORT",
  "ITEM_MOD_STAMINA_SHORT",
  "ITEM_MOD_INTELLECT_SHORT",
  "ITEM_MOD_SPIRIT_SHORT",
  "ITEM_MOD_ATTACK_POWER_SHORT",
  "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
  "ITEM_MOD_HIT_RATING_SHORT",
  "ITEM_MOD_CRIT_RATING_SHORT",
  "ITEM_MOD_HASTE_RATING_SHORT",
  "ITEM_MOD_EXPERTISE_RATING_SHORT",
  "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
  "ITEM_MOD_SPELL_POWER_SHORT",
  "ITEM_MOD_MANA_REGENERATION_SHORT",
  "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
  "ITEM_MOD_DODGE_RATING_SHORT",
  "ITEM_MOD_PARRY_RATING_SHORT",
  "ITEM_MOD_BLOCK_RATING_SHORT",
  "ITEM_MOD_BLOCK_VALUE_SHORT",
  "ITEM_MOD_RESILIENCE_RATING_SHORT",
}

local FALLBACK_LABELS = {
  ITEM_MOD_AGILITY_SHORT = "stat_agility", ITEM_MOD_STRENGTH_SHORT = "stat_strength",
  ITEM_MOD_STAMINA_SHORT = "stat_stamina", ITEM_MOD_INTELLECT_SHORT = "stat_intellect",
  ITEM_MOD_SPIRIT_SHORT = "stat_spirit", ITEM_MOD_ATTACK_POWER_SHORT = "stat_attack_power",
  ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "stat_ranged_attack_power", ITEM_MOD_HIT_RATING_SHORT = "stat_hit",
  ITEM_MOD_CRIT_RATING_SHORT = "stat_crit", ITEM_MOD_HASTE_RATING_SHORT = "stat_haste",
  ITEM_MOD_EXPERTISE_RATING_SHORT = "stat_expertise", ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "stat_armor_pen",
  ITEM_MOD_SPELL_POWER_SHORT = "stat_spell_power", ITEM_MOD_MANA_REGENERATION_SHORT = "stat_mana_regen",
  ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "stat_defense", ITEM_MOD_DODGE_RATING_SHORT = "stat_dodge",
  ITEM_MOD_PARRY_RATING_SHORT = "stat_parry", ITEM_MOD_BLOCK_RATING_SHORT = "stat_block",
  ITEM_MOD_BLOCK_VALUE_SHORT = "stat_block_value", ITEM_MOD_RESILIENCE_RATING_SHORT = "stat_resilience",
}

local function StatLabel(key)
  local v = _G[key]
  if type(v) == "string" and v ~= "" then return v end
  return FALLBACK_LABELS[key] and FUL:T(FALLBACK_LABELS[key]) or key
end

local function Pct(n, d)
  if not d or d == 0 then return nil end
  return 100 * n / d
end

local function Signed(v)
  if not v or math.abs(v) < 0.0001 then return nil end
  if math.abs(v - math.floor(v + 0.5)) < 0.001 then
    return string.format("%+d", math.floor(v + 0.5))
  end
  return string.format("%+.1f", v)
end

local function Value(v)
  if not v then return "-" end
  if math.abs(v - math.floor(v + 0.5)) < 0.001 then return tostring(math.floor(v + 0.5)) end
  return string.format("%.1f", v)
end

local scanTip = CreateFrame("GameTooltip", "FULHiddenScanTooltip", UIParent, "GameTooltipTemplate")
scanTip:SetOwner(UIParent, "ANCHOR_NONE")

local function ScanDPS(link)
  if not link then return nil end
  scanTip:ClearLines()
  local ok = pcall(scanTip.SetHyperlink, scanTip, link)
  if not ok then return nil end
  for i = 1, scanTip:NumLines() do
    local fs = _G["FULHiddenScanTooltipTextLeft" .. i]
    local txt = fs and fs:GetText()
    if txt then
      local low = string.lower(txt)
      if string.find(low, "par seconde", 1, true) or string.find(low, "damage per second", 1, true) or string.find(low, "dps", 1, true) then
        local raw = string.match(txt, "([%d]+[%,%.]?[%d]*)")
        if raw then return tonumber((string.gsub(raw, ",", "."))) end
      end
    end
  end
  return nil
end

local function SafeItemStats(link)
  if not link or type(GetItemStats) ~= "function" then return {} end
  local ok, stats = pcall(GetItemStats, link)
  if ok and type(stats) == "table" then return stats end
  return {}
end

local function ItemLinkFromID(id)
  if not id then return nil end
  local _, link = GetItemInfo(id)
  return link or ("item:" .. tostring(id))
end

local function QualityColor(q)
  if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then
    local c = ITEM_QUALITY_COLORS[q]
    return c.r or 1, c.g or 1, c.b or 1
  end
  if q == 3 then return 0.0, 0.44, 0.87 end
  if q == 4 then return 0.64, 0.21, 0.93 end
  return 1, 1, 1
end

local function UpgradeLevel(baseQuality, quality)
  if baseQuality == 2 then
    if quality == 2 then return 1, 3 end
    if quality == 3 then return 2, 3 end
    if quality == 4 then return 3, 3 end
  elseif baseQuality == 3 then
    if quality == 3 then return 1, 2 end
    if quality == 4 then return 2, 2 end
  end
  return nil, nil
end

local function UpgradeLevelHex(level, maximum)
  -- Use the same visual language as WoW item qualities.
  -- 3-tier family: normal green -> Rare blue -> Epic purple.
  -- 2-tier family: Rare blue -> Epic purple.
  if maximum == 3 then
    if level == 1 then return "ff1eff00" end
    if level == 2 then return "ff0070dd" end
    if level == 3 then return "ffa335ee" end
  elseif maximum == 2 then
    if level == 1 then return "ff0070dd" end
    if level == 2 then return "ffa335ee" end
  end
  return "ffffffff"
end

local function ColoredUpgradeLevelText(key, level, maximum)
  local text = FUL:T(key, level, maximum)
  local value = tostring(level) .. "/" .. tostring(maximum)
  local colored = "|c" .. UpgradeLevelHex(level, maximum) .. value .. "|r"
  local escaped = string.gsub(value, "([^%w])", "%%%1")
  return (string.gsub(text, escaped, colored, 1))
end

local function AddUpgradeLevel(tip, baseQuality, quality, current)
  local level, maximum = UpgradeLevel(baseQuality, quality)
  if not level then return end
  local key = current and "current_upgrade_level" or "upgrade_level"
  tip:AddLine(ColoredUpgradeLevelText(key, level, maximum), 1.00, 0.82, 0.00)
end

local function TransitionText(beforeValue, afterValue, delta)
  local color = delta < 0 and "ffff4040" or "ff33ff4d"
  return Value(beforeValue) .. "  →  |c" .. color .. Value(afterValue) .. "  (" .. (Signed(delta) or "+0") .. ")|r"
end

-- GameTooltip has no public InsertLine API in 3.3.5. Extending the title's
-- font string with a second colored row keeps Blizzard's money frames and
-- right-side columns aligned. Non-standard tooltips use the safe fallback.
local function InsertCurrentUpgradeLevel(tip, baseQuality, currentQuality)
  local level, maximum = UpgradeLevel(baseQuality, currentQuality)
  if not level then return false end
  local tipName = tip and tip.GetName and tip:GetName()
  local oldCount = tip and tip.NumLines and tip:NumLines() or 0
  if not tipName or oldCount < 1 then return false end

  for i=1, math.min(oldCount, 5) do
    local fs = _G[tipName .. "TextLeft" .. i]
    local text = fs and fs:GetText()
    local low = text and string.lower(text) or ""
    if string.find(low, "niveau d'amélioration", 1, true) or string.find(low, "upgrade level", 1, true) then
      return true
    end
  end

  local title = _G[tipName .. "TextLeft1"]
  local titleText = title and title:GetText()
  if not title or not titleText or titleText == "" then return false end
  title:SetText(titleText .. "\n|cffffd100" .. ColoredUpgradeLevelText("upgrade_level", level, maximum) .. "|r")
  tip:Show()
  return true
end

local OWNED_TOOLTIP_HINTS = {
  "ContainerFrame", "BankFrame", "Character", "PaperDoll", "Inspect",
  "EquipmentManager", "Bagnon", "AdiBags", "ArkInventory", "Combuctor",
  "OneBag", "BagItem", "ActionButton", "MultiBar", "BT4Button", "DominosActionButton",
}

local function IsOwnedItemTooltip(tip)
  local owner = tip and tip.GetOwner and tip:GetOwner()
  local depth = 0
  while owner and depth < 10 do
    local name = owner.GetName and owner:GetName()
    if name then
      for _, hint in ipairs(OWNED_TOOLTIP_HINTS) do
        if string.find(name, hint, 1, true) then return true end
      end
    end
    owner = owner.GetParent and owner:GetParent() or nil
    depth = depth + 1
  end
  return false
end

local function ObservedText(source, familyName, quality)
  local b = FUL:GetNameBucket(source, familyName)
  if not b or not b.total or b.total == 0 then return "- (n=0)" end
  local count = quality == 3 and (b.rare or 0) or (b.epic or 0)
  local p = Pct(count, b.total)
  return string.format("%.1f%% (n=%d)", p or 0, b.total)
end

local function OfficialQuestRate(baseQuality, targetQuality)
  if baseQuality == 2 and targetQuality == 3 then return FUL.OFFICIAL.questGreenRare end
  if baseQuality == 2 and targetQuality == 4 then return FUL.OFFICIAL.questGreenEpic end
  if baseQuality == 3 and targetQuality == 4 then return FUL.OFFICIAL.questBlueEpic end
  return nil
end

local rareTip = CreateFrame("GameTooltip", "FULRarePreviewTooltip", UIParent, "GameTooltipTemplate")
local epicTip = CreateFrame("GameTooltip", "FULEpicPreviewTooltip", UIParent, "GameTooltipTemplate")
rareTip:SetFrameStrata("TOOLTIP")
epicTip:SetFrameStrata("TOOLTIP")

local function AddRateLines(tip, familyName, baseQuality, targetQuality)
  tip:AddLine(" ")
  local official = OfficialQuestRate(baseQuality, targetQuality)
  local observedQuest = ObservedText(FUL.SOURCE_QUEST, familyName, targetQuality)
  if official then
    tip:AddDoubleLine(FUL:T("quest"), FUL:T("official").." "..string.format("%.0f%%", official * 100).."   "..FUL:T("observed").." "..observedQuest, 0.72,0.76,0.82, 0.72,0.92,1)
  else
    tip:AddDoubleLine(FUL:T("quest"), FUL:T("observed").." " .. observedQuest, 0.72,0.76,0.82, 0.72,0.92,1)
  end
  tip:AddDoubleLine(FUL:T("source_drop"), FUL:T("observed").." " .. ObservedText(FUL.SOURCE_DROP, familyName, targetQuality), 0.72,0.76,0.82, 0.72,0.92,1)
  tip:AddDoubleLine(FUL:T("source_craft"), FUL:T("observed").." " .. ObservedText(FUL.SOURCE_CRAFT, familyName, targetQuality), 0.72,0.76,0.82, 0.72,0.92,1)
end

local function BuildDeltaLines(tip, baseLink, variantLink)
  local baseStats = SafeItemStats(baseLink)
  local varStats = SafeItemStats(variantLink)
  local shown = 0

  local baseDps = ScanDPS(baseLink)
  local varDps = ScanDPS(variantLink)
  if baseDps and varDps and math.abs(varDps - baseDps) > 0.001 then
    local delta = varDps - baseDps
    tip:AddDoubleLine("DPS", TransitionText(baseDps, varDps, delta), 0.95,0.95,0.95, 1,1,1)
    shown = shown + 1
  end

  for _, key in ipairs(STAT_ORDER) do
    if shown >= PREVIEW_MAX_STATS then break end
    local b = tonumber(baseStats[key] or 0) or 0
    local v = tonumber(varStats[key] or 0) or 0
    local d = v - b
    if math.abs(d) > 0.001 then
      tip:AddDoubleLine(StatLabel(key), TransitionText(b, v, d), 0.95,0.95,0.95, 1,1,1)
      shown = shown + 1
    end
  end

  if shown == 0 then
    local _, _, _, ilvlBase = GetItemInfo(baseLink)
    local _, _, _, ilvlVar = GetItemInfo(variantLink)
    if ilvlVar and ilvlBase and ilvlVar ~= ilvlBase then
      tip:AddDoubleLine(FUL:T("item_level"), tostring(ilvlVar) .. "  (" .. (Signed(ilvlVar - ilvlBase) or "+0") .. ")", 0.82,0.84,0.88, 0.35,1,0.45)
      shown = shown + 1
    end
  end

  if shown == 0 then
    tip:AddLine(FUL:T("stats_loading"), 0.60,0.64,0.70)
  end
end

local function BuildPreview(tip, record, label, baseLink, familyName, baseQuality)
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  local id, quality, ilvl = record[1], record[2], record[3]
  local variantLink = ItemLinkFromID(id)
  local itemName = GetItemInfo(id) or familyName
  local r,g,b = QualityColor(quality)
  tip:AddLine(label, r,g,b)
  tip:AddLine(itemName or familyName, r,g,b)
  if ilvl then tip:AddLine(FUL:T("ilevel_short") .. " " .. tostring(ilvl), 0.58,0.62,0.68) end
  AddUpgradeLevel(tip, baseQuality, quality, false)
  tip:AddLine(" ")
  BuildDeltaLines(tip, baseLink, variantLink)
  AddRateLines(tip, familyName, baseQuality, quality)
  tip:Show()
end

local function PickRecord(records)
  if not records or #records == 0 then return nil end
  return records[1]
end

local INLINE_MAX_STATS = 4

local function AddInlineVariant(tip, record, label, baseLink, familyName, baseQuality)
  local id, quality = record[1], record[2]
  local variantLink = ItemLinkFromID(id)
  local r,g,b = QualityColor(quality)
  tip:AddLine(label, r,g,b)
  AddUpgradeLevel(tip, baseQuality, quality, false)

  local baseDps, varDps = ScanDPS(baseLink), ScanDPS(variantLink)
  if baseDps and varDps and math.abs(varDps - baseDps) > 0.001 then
    local delta = varDps - baseDps
    tip:AddDoubleLine("  DPS", TransitionText(baseDps, varDps, delta), 0.95,0.95,0.95, 1,1,1)
  end

  local baseStats, varStats = SafeItemStats(baseLink), SafeItemStats(variantLink)
  local shown = 0
  for _, key in ipairs(STAT_ORDER) do
    if shown >= INLINE_MAX_STATS then break end
    local bv = tonumber(baseStats[key] or 0) or 0
    local vv = tonumber(varStats[key] or 0) or 0
    local delta = vv - bv
    if math.abs(delta) > 0.001 then
      tip:AddDoubleLine("  " .. StatLabel(key), TransitionText(bv, vv, delta), 0.95,0.95,0.95, 1,1,1)
      shown = shown + 1
    end
  end
end

local function AddInlinePreviews(tip, rare, epic, baseLink, familyName, baseQuality, currentQuality, currentInserted)
  if not currentInserted then
    tip:AddLine(" ")
    AddUpgradeLevel(tip, baseQuality, currentQuality, true)
  end
  if not rare and not epic then tip:Show(); return end
  tip:AddLine(" ")
  tip:AddLine(FUL:T("upgrade_tiers"), 0.55,0.86,0.95)
  if rare then AddInlineVariant(tip, rare, string.upper(FUL:T("rare")), baseLink, familyName, baseQuality) end
  if rare and epic then tip:AddLine(" ") end
  if epic then AddInlineVariant(tip, epic, string.upper(FUL:T("epic")), baseLink, familyName, baseQuality) end
  tip:Show()
end

-- Keep Frostmourne Upgraded Gear previews away from WoW's native equipment-comparison tooltips.
-- Important: the cards are built/shown BEFORE this function runs so their final
-- width/height is known. Positioning them before SetHyperlink/AddLine caused the
-- Rare/Epic cards themselves to overlap when one card grew after anchoring.
local TOOLTIP_GAP = 8
local TOOLTIP_MARGIN = 10

local function Clamp(v, lo, hi)
  if hi < lo then return lo end
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function FrameRect(frame)
  if not frame or not frame.IsShown or not frame:IsShown() then return nil end
  local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
  if not left or not right or not top or not bottom then return nil end
  return { left = left, right = right, top = top, bottom = bottom }
end

local function ExpandBounds(bounds, rect)
  if not rect then return bounds end
  if not bounds then
    return { left = rect.left, right = rect.right, top = rect.top, bottom = rect.bottom }
  end
  bounds.left = math.min(bounds.left, rect.left)
  bounds.right = math.max(bounds.right, rect.right)
  bounds.top = math.max(bounds.top, rect.top)
  bounds.bottom = math.min(bounds.bottom, rect.bottom)
  return bounds
end

local function PlaceAbsolute(tip, x, top)
  tip:ClearAllPoints()
  tip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top)
end

local function PositionPreviews()
  if not GameTooltip:IsShown() then return end

  local cards = {}
  if rareTip:IsShown() then cards[#cards + 1] = rareTip end
  if epicTip:IsShown() then cards[#cards + 1] = epicTip end
  if #cards == 0 then return end

  -- Occupied area = hovered item tooltip + Blizzard comparison cards.
  -- ShoppingTooltip1/2 are the normal equipped-item comparison bubbles in 3.3.5.
  local bounds = ExpandBounds(nil, FrameRect(GameTooltip))
  for i = 1, 3 do
    bounds = ExpandBounds(bounds, FrameRect(_G["ShoppingTooltip" .. i]))
  end
  if not bounds then return end

  local uiW, uiH = UIParent:GetWidth(), UIParent:GetHeight()
  if not uiW or not uiH or uiW <= 0 or uiH <= 0 then return end

  local colW, stackH, rowW, rowH = 0, 0, 0, 0
  for i, tip in ipairs(cards) do
    local w = math.max(1, tip:GetWidth() or 1)
    local h = math.max(1, tip:GetHeight() or 1)
    colW = math.max(colW, w)
    stackH = stackH + h
    rowW = rowW + w
    rowH = math.max(rowH, h)
    if i > 1 then
      stackH = stackH + TOOLTIP_GAP
      rowW = rowW + TOOLTIP_GAP
    end
  end

  local leftSpace = bounds.left - TOOLTIP_MARGIN
  local rightSpace = uiW - bounds.right - TOOLTIP_MARGIN
  local needSide = colW + TOOLTIP_GAP

  -- Preferred layout: one compact vertical column beside all native tooltips.
  -- This uses far less horizontal space than Rare + Epic side-by-side.
  local side = nil
  if leftSpace >= needSide and rightSpace >= needSide then
    side = rightSpace >= leftSpace and "RIGHT" or "LEFT"
  elseif rightSpace >= needSide then
    side = "RIGHT"
  elseif leftSpace >= needSide then
    side = "LEFT"
  end

  if side then
    local x
    if side == "RIGHT" then x = bounds.right + TOOLTIP_GAP else x = bounds.left - TOOLTIP_GAP - colW end
    x = Clamp(x, TOOLTIP_MARGIN, uiW - TOOLTIP_MARGIN - colW)
    local top = Clamp(bounds.top, TOOLTIP_MARGIN + stackH, uiH - TOOLTIP_MARGIN)
    local y = top
    for _, tip in ipairs(cards) do
      PlaceAbsolute(tip, x, y)
      y = y - (tip:GetHeight() or 1) - TOOLTIP_GAP
    end
    return
  end

  -- If neither side is wide enough, try a horizontal row below/above the native block.
  local belowSpace = bounds.bottom - TOOLTIP_MARGIN
  local aboveSpace = uiH - bounds.top - TOOLTIP_MARGIN
  local rowFits = rowW <= (uiW - 2 * TOOLTIP_MARGIN)
  if rowFits and belowSpace >= rowH + TOOLTIP_GAP then
    local x = Clamp(((bounds.left + bounds.right) - rowW) / 2, TOOLTIP_MARGIN, uiW - TOOLTIP_MARGIN - rowW)
    local top = bounds.bottom - TOOLTIP_GAP
    for _, tip in ipairs(cards) do
      PlaceAbsolute(tip, x, top)
      x = x + (tip:GetWidth() or 1) + TOOLTIP_GAP
    end
    return
  elseif rowFits and aboveSpace >= rowH + TOOLTIP_GAP then
    local x = Clamp(((bounds.left + bounds.right) - rowW) / 2, TOOLTIP_MARGIN, uiW - TOOLTIP_MARGIN - rowW)
    local top = bounds.top + TOOLTIP_GAP + rowH
    for _, tip in ipairs(cards) do
      PlaceAbsolute(tip, x, top)
      x = x + (tip:GetWidth() or 1) + TOOLTIP_GAP
    end
    return
  end

  -- Last-resort screen-safe placement. It still keeps Rare/Epic apart even on a
  -- very crowded/low-resolution UI. Prefer the side with the most remaining room.
  local useRight = rightSpace >= leftSpace
  local fallbackX = useRight and (uiW - TOOLTIP_MARGIN - colW) or TOOLTIP_MARGIN
  local fallbackTop = Clamp(bounds.top, TOOLTIP_MARGIN + stackH, uiH - TOOLTIP_MARGIN)
  local y = fallbackTop
  for _, tip in ipairs(cards) do
    PlaceAbsolute(tip, fallbackX, y)
    y = y - (tip:GetHeight() or 1) - TOOLTIP_GAP
  end
end

local layoutDriver = CreateFrame("Frame")
local layoutElapsed = 0
local layoutPending = false

local function SchedulePreviewPosition()
  if not rareTip:IsShown() and not epicTip:IsShown() then return end
  layoutElapsed = 0
  if layoutPending then return end
  layoutPending = true
  layoutDriver:SetScript("OnUpdate", function(self, elapsed)
    layoutElapsed = layoutElapsed + (elapsed or 0)
    -- Give Blizzard/other addons one or two frames to finish creating comparison tips.
    if layoutElapsed < 0.04 then return end
    self:SetScript("OnUpdate", nil)
    layoutPending = false
    if GameTooltip:IsShown() then PositionPreviews() end
  end)
end

local function HidePreviews()
  rareTip:Hide()
  epicTip:Hide()
end

local function CurrentMode()
  if not FUL.db then return "OFF" end
  local m = FUL.db.previewMode
  if m ~= "ALT" and m ~= "ALWAYS" and m ~= "OFF" then m = "ALT" end
  return m
end

local function CurrentStyle()
  if not FUL.db then return "CARDS" end
  return FUL.db.previewStyle == "INLINE" and "INLINE" or "CARDS"
end

local function ShouldShowPreviews()
  local mode = CurrentMode()
  if mode == "OFF" then return false end
  if mode == "ALWAYS" then return true end
  return IsAltKeyDown and IsAltKeyDown()
end

local function UpdatePreviewVisibility()
  if refreshing or not FUL.db or not GameTooltip:IsShown() then HidePreviews(); return end
  if not ShouldShowPreviews() then HidePreviews(); return end

  local name, link = GameTooltip:GetItem()
  if not name or not link then HidePreviews(); return end

  lastLink = link
  lastName = name
  local fam = FUL:ResolveFamily(link, name)
  lastFamily = fam
  if not fam then HidePreviews(); return end

  local rare = PickRecord(fam.rare)
  local epic = PickRecord(fam.epic)
  local baseQuality = FUL:InferBaseQuality(link, fam)
  local currentQuality = fam.currentQuality or select(3, GetItemInfo(link))
  local currentID = FUL:GetItemID(link)

  if CurrentStyle() == "INLINE" and inlineAppliedLink == link then return end

  -- Never duplicate the exact item currently hovered.
  if rare and rare[1] == currentID then rare = nil end
  if epic and epic[1] == currentID then epic = nil end

  -- Lower tiers are useful for research, but noisy during normal play.
  if FUL.db.showLowerVariants ~= true and currentQuality then
    if rare and rare[2] < currentQuality then rare = nil end
    if epic and epic[2] < currentQuality then epic = nil end
  end

  if FUL.db.showOwnedItemProjections ~= true and IsOwnedItemTooltip(GameTooltip) then
    rare, epic = nil, nil
  end

  HidePreviews()
  if not rare and not epic and CurrentStyle() ~= "INLINE" then return end
  if CurrentStyle() == "INLINE" then
    local currentInserted = InsertCurrentUpgradeLevel(GameTooltip, baseQuality, currentQuality)
    AddInlinePreviews(GameTooltip, rare, epic, link, name, baseQuality, currentQuality, currentInserted)
    inlineAppliedLink = link
  else
    -- Build first so final dimensions are known; then lay out around native compare tips.
    if rare then BuildPreview(rareTip, rare, string.upper(FUL:T("rare")), link, name, baseQuality) end
    if epic then BuildPreview(epicTip, epic, string.upper(FUL:T("epic")), link, name, baseQuality) end
    PositionPreviews()
    SchedulePreviewPosition()
  end
end

-- The normal WoW tooltip is deliberately left untouched. Variant cards are an overlay.
GameTooltip:HookScript("OnTooltipSetItem", UpdatePreviewVisibility)
GameTooltip:HookScript("OnHide", function() HidePreviews(); inlineAppliedLink = nil end)

local mf = CreateFrame("Frame")
mf:RegisterEvent("GET_ITEM_INFO_RECEIVED")
mf:RegisterEvent("MODIFIER_STATE_CHANGED")
mf:SetScript("OnEvent", function(_, event, arg1)
  if event == "MODIFIER_STATE_CHANGED" then
    if arg1 == "LALT" or arg1 == "RALT" or arg1 == "ALT" then
      if CurrentStyle() == "INLINE" and GameTooltip:IsShown() then
        local _, link = GameTooltip:GetItem()
        if link then
          HidePreviews()
          inlineAppliedLink = nil
          GameTooltip:ClearLines()
          GameTooltip:SetHyperlink(link)
        end
      else
        UpdatePreviewVisibility()
      end
    elseif rareTip:IsShown() or epicTip:IsShown() then
      -- Shift/Ctrl may show/hide Blizzard comparison cards. Reflow without touching them.
      SchedulePreviewPosition()
    end
    return
  end
  if GameTooltip:IsShown() and lastLink and not refreshing then
    UpdatePreviewVisibility()
  end
end)

-- Native comparison bubbles can be created after OnTooltipSetItem. Reflow whenever
-- they appear/disappear; never hide, move or replace them.
for i = 1, 3 do
  local native = _G["ShoppingTooltip" .. i]
  if native and native.HookScript then
    native:HookScript("OnShow", SchedulePreviewPosition)
    native:HookScript("OnHide", SchedulePreviewPosition)
  end
end

-- Exposed so the Settings page can apply a new mode immediately.
FUL.RefreshVariantPreviews = function()
  HidePreviews()
  if GameTooltip:IsShown() then
    local _, link = GameTooltip:GetItem()
    if link then inlineAppliedLink = nil; GameTooltip:ClearLines(); GameTooltip:SetHyperlink(link); return end
  end
  UpdatePreviewVisibility()
end
