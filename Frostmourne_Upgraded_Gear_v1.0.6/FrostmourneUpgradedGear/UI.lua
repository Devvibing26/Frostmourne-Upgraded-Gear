local PANEL_W, PANEL_H = 920, 620
local NAV_W = 176

local C = {
  bg = {0.055, 0.062, 0.075, 0.98},
  panel = {0.085, 0.095, 0.115, 0.98},
  panel2 = {0.11, 0.12, 0.145, 0.98},
  border = {0.20, 0.22, 0.26, 1},
  text = {0.93, 0.95, 0.98, 1},
  muted = {0.60, 0.64, 0.70, 1},
  accent = {0.30, 0.82, 0.95, 1},
  good = {0.35, 0.88, 0.55, 1},
  warn = {1.00, 0.68, 0.25, 1},
  bad = {0.95, 0.35, 0.35, 1},
}

local function T(key, ...) return FUL:T(key, ...) end

local function SetColor(fs, c) fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end

local function Atan2(y, x)
  if math.atan2 then return math.atan2(y, x) end
  if x > 0 then return math.atan(y / x) end
  if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
  if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
  if x == 0 and y > 0 then return math.pi / 2 end
  if x == 0 and y < 0 then return -math.pi / 2 end
  return 0
end


local function Solid(parent, layer, c)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND")
  t:SetTexture(c[1], c[2], c[3], c[4] or 1)
  return t
end

local function Label(parent, text, size, color, font)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(font or "Fonts\\FRIZQT__.TTF", size or 12, "")
  fs:SetText(text or "")
  SetColor(fs, color or C.text)
  fs:SetJustifyH("LEFT")
  return fs
end

local function FrameBg(frame, color, border)
  frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  frame:SetBackdropColor(color[1], color[2], color[3], color[4] or 1)
  local b = border or C.border
  frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4] or 1)
end

local function Button(parent, text, width, height, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(width or 120); b:SetHeight(height or 32)
  FrameBg(b, C.panel2, C.border)
  local l = Label(b, text, 12, C.text)
  l:SetPoint("CENTER", 0, 0)
  b.label = l

  function b:SetBaseStyle(bg, border, textColor)
    self._baseBg = bg or C.panel2
    self._baseBorder = border or C.border
    self._baseText = textColor or C.text
    self:SetBackdropColor(self._baseBg[1], self._baseBg[2], self._baseBg[3], self._baseBg[4] or 1)
    self:SetBackdropBorderColor(self._baseBorder[1], self._baseBorder[2], self._baseBorder[3], self._baseBorder[4] or 1)
    SetColor(self.label, self._baseText)
  end
  function b:RestoreBaseStyle()
    self:SetBaseStyle(self._baseBg or C.panel2, self._baseBorder or C.border, self._baseText or C.text)
  end
  function b:SetButtonText(v) self.label:SetText(v or "") end
  b:SetBaseStyle(C.panel2, C.border, C.text)

  b:SetScript("OnEnter", function(self)
    local bg = self._baseBg or C.panel2
    self:SetBackdropColor(math.min(1,(bg[1] or 0)+.055), math.min(1,(bg[2] or 0)+.055), math.min(1,(bg[3] or 0)+.055), bg[4] or 1)
    local br = self._baseBorder or C.border
    self:SetBackdropBorderColor(br[1], br[2], br[3], 1)
  end)
  b:SetScript("OnLeave", function(self) self:RestoreBaseStyle() end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

local function PctWithCount(n, d)
  if not d or d == 0 then return "-" end
  return string.format("%.2f%% (%d)", 100 * (n or 0) / d, n or 0)
end

local function BaseQualityLabel(baseQuality)
  return baseQuality == 3 and T("base_rare") or T("base_uncommon")
end

local function StatRowNote(source, baseQuality)
  if source == FUL.SOURCE_QUEST then
    if baseQuality == 2 then return T("quest_rates_green") else return T("quest_rates_blue") end
  elseif source == FUL.SOURCE_DROP then
    return T("drop_rates")
  end
  return T("no_official_rate")
end

local function SetToggleVisual(b, enabled, onText, offText)
  if not b then return end
  if enabled then
    b:SetButtonText(onText or "ON")
    b:SetBaseStyle({0.075,0.20,0.125,1}, C.good, C.good)
  else
    b:SetButtonText(offText or "OFF")
    b:SetBaseStyle({0.20,0.075,0.075,1}, C.bad, {1.0,0.68,0.68,1})
  end
end

local function SetSelectedVisual(b, selected)
  if not b then return end
  if selected then b:SetBaseStyle({0.13,0.18,0.22,1}, C.accent, C.accent)
  else b:SetBaseStyle(C.panel2, C.border, C.text) end
end

local activeDropdown = nil

local function CustomDropdown(parent, width, height, getChoices, getValue, onSelect)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(width or 180); b:SetHeight(height or 30)
  FrameBg(b, C.panel2, C.border)

  local valueText = Label(b, "", 11, C.text)
  valueText:SetPoint("LEFT", 12, 0); valueText:SetPoint("RIGHT", -30, 0)
  valueText:SetJustifyH("LEFT")
  local arrow = Label(b, "v", 12, C.muted, "Fonts\\ARIALN.TTF")
  arrow:SetPoint("RIGHT", -10, 0)
  b.valueText = valueText; b.arrow = arrow

  local menu = CreateFrame("Frame", nil, UIParent)
  menu:SetFrameStrata("DIALOG"); menu:SetClampedToScreen(true)
  FrameBg(menu, {0.055,0.062,0.075,1}, C.border)
  menu:Hide(); b.menu = menu; b.items = {}

  local function CurrentChoiceText()
    local value = getValue and getValue() or nil
    for _, choice in ipairs((getChoices and getChoices()) or {}) do
      if choice.value == value then return choice.text end
    end
    return ""
  end

  function b:Refresh()
    self.valueText:SetText(CurrentChoiceText())
    if self.menu:IsShown() then self:RebuildMenu() end
  end

  function b:RebuildMenu()
    local choices = (getChoices and getChoices()) or {}
    self.menu:SetWidth(self:GetWidth())
    self.menu:SetHeight(math.max(4, #choices * 30 + 4))
    local current = getValue and getValue() or nil
    for i, choice in ipairs(choices) do
      local item = self.items[i]
      if not item then
        item = Button(self.menu, "", self:GetWidth()-4, 28, function(btn)
          local value = btn._value
          self.menu:Hide()
          if activeDropdown == self then activeDropdown = nil end
          if onSelect then onSelect(value) end
          self:Refresh()
        end)
        item.label:ClearAllPoints(); item.label:SetPoint("LEFT", 10, 0); item.label:SetJustifyH("LEFT")
        self.items[i] = item
      end
      item._value = choice.value
      item:SetButtonText(choice.text)
      item:ClearAllPoints(); item:SetPoint("TOPLEFT", 2, -2 - (i-1)*30)
      item:SetWidth(self:GetWidth()-4); item:Show()
      if choice.value == current then
        item:SetBaseStyle({0.13,0.18,0.22,1}, C.accent, C.accent)
      else
        item:SetBaseStyle(C.panel2, C.border, C.text)
      end
    end
    for i=#choices+1,#self.items do self.items[i]:Hide() end
  end

  b:SetScript("OnClick", function(self)
    if self.menu:IsShown() then
      self.menu:Hide(); if activeDropdown == self then activeDropdown = nil end
      return
    end
    if activeDropdown and activeDropdown ~= self and activeDropdown.menu then activeDropdown.menu:Hide() end
    activeDropdown = self
    self:RebuildMenu()
    self.menu:ClearAllPoints(); self.menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -4)
    self.menu:Show()
  end)
  b:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.14,0.15,0.18,1); self:SetBackdropBorderColor(C.accent[1],C.accent[2],C.accent[3],0.85)
  end)
  b:SetScript("OnLeave", function(self)
    self:SetBackdropColor(C.panel2[1],C.panel2[2],C.panel2[3],C.panel2[4]); self:SetBackdropBorderColor(C.border[1],C.border[2],C.border[3],1)
  end)
  b:HookScript("OnHide", function(self)
    if self.menu then self.menu:Hide() end
    if activeDropdown == self then activeDropdown = nil end
  end)
  b:Refresh()
  return b
end

local function HelpIcon(parent, titleKey, lines)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(20); b:SetHeight(20)
  FrameBg(b, {0.075,0.083,0.10,1}, C.border)
  local q = Label(b, "?", 12, C.muted, "Fonts\\ARIALN.TTF"); q:SetPoint("CENTER",0,0)
  b:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.12,0.15,0.18,1); self:SetBackdropBorderColor(C.accent[1],C.accent[2],C.accent[3],1)
    SetColor(q, C.accent)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(T(titleKey), C.accent[1], C.accent[2], C.accent[3])
    for _, spec in ipairs(lines or {}) do
      if spec.spacer then
        GameTooltip:AddLine(" ")
      else
        local color = spec.color or C.text
        GameTooltip:AddLine(T(spec.key), color[1], color[2], color[3], true)
      end
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.075,0.083,0.10,1); self:SetBackdropBorderColor(C.border[1],C.border[2],C.border[3],1)
    SetColor(q, C.muted); GameTooltip:Hide()
  end)
  return b
end

local function Card(parent, x, y, w, h)
  local f = CreateFrame("Frame", nil, parent)
  f:SetPoint("TOPLEFT", x, y); f:SetWidth(w); f:SetHeight(h)
  FrameBg(f, C.panel, C.border)
  return f
end

local function Pct(n, d)
  if not d or d == 0 then return "–" end
  return string.format("%.2f%%", 100 * n / d)
end

local function BucketText(b)
  if not b or not b.total or b.total == 0 then return T("no_data") end
  return string.format("n=%d   %s %s   %s %s", b.total, T("rare"), Pct(b.rare or 0, b.total), T("epic"), Pct(b.epic or 0, b.total))
end

FUL.UI = FUL.UI or {}
local UI = FUL.UI

function UI:SetStatus(text, color)
  if not self.statusText then return end
  self.statusText:SetText(text or "")
  SetColor(self.statusText, color or C.muted)
end

function UI:RefreshTracking()
  if not self.trackButton or not FUL.db then return end
  FUL.db.trackingEnabled = true
  self.trackButton:SetButtonText(T("automatic_tracking"))
  self.trackButton:SetBaseStyle({0.075,0.20,0.125,1}, C.good, C.good)
  if self.dashboardTrackState then
    self.dashboardTrackState:SetText(T("automatic_tracking"))
    SetColor(self.dashboardTrackState, C.good)
  end
end

function UI:HideAllPages()
  if not self.pages then return end
  for _, page in pairs(self.pages) do page:Hide() end
end

function UI:SelectPage(key)
  self:HideAllPages()
  local page = self.pages and self.pages[key]
  if page then page:Show() end
  self.activePage = key
  if self.navButtons then
    for k, b in pairs(self.navButtons) do
      if k == key then
        b:SetBackdropColor(0.13, 0.18, 0.22, 1)
        b:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.85)
        SetColor(b.label, C.accent)
      else
        b:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], C.panel[4])
        b:SetBackdropBorderColor(C.panel[1], C.panel[2], C.panel[3], 1)
        SetColor(b.label, C.text)
      end
    end
  end
  if key == "overview" then self:RefreshOverview() end
  if key == "stats" then self:RefreshStats() end
  if key == "data" then self:RefreshData() end
  if key == "settings" then self:RefreshSettings() end
end

function UI:RefreshOverview()
  if not FUL.db or not self.overviewEvents then return end
  if not FUL.runtimeStats then FUL:RebuildStats() end
  self.overviewEvents:SetText(tostring(#FUL.db.events))
  self.overviewIgnored:SetText(tostring((FUL.db.ignored and FUL.db.ignored.uncertain or 0) + (FUL.db.ignored and FUL.db.ignored.ineligible or 0)))
  self.overviewSession:SetText(tostring(FUL.sessionID or 0))
  if self.dropAll then
    local d=FUL.db.dropScan or {}
    self.dropAll:SetText(tostring(d.allGear or 0))
    self.dropEligible:SetText(tostring(d.eligible or 0))
    self.dropRare:SetText(tostring(d.rare or 0))
    self.dropEpic:SetText(tostring(d.epic or 0))
  end
  self:RefreshTracking()
  local q = FUL.runtimeStats and FUL.runtimeStats.global[FUL.SOURCE_QUEST]
  local d = FUL.runtimeStats and FUL.runtimeStats.global[FUL.SOURCE_DROP]
  local c = FUL.runtimeStats and FUL.runtimeStats.global[FUL.SOURCE_CRAFT]
  self.overviewQuest:SetText(BucketText(q))
  self.overviewDrop:SetText(BucketText(d))
  self.overviewCraft:SetText(BucketText(c))
end

function UI:RefreshStats()
  if not FUL.db then return end
  FUL:RebuildStats()

  local groups = {
    { source = FUL.SOURCE_QUEST, rows = {2, 3} },
    { source = FUL.SOURCE_DROP, rows = {2, 3} },
    { source = FUL.SOURCE_CRAFT, rows = {2, 3} },
  }

  for groupIndex, group in ipairs(groups) do
    local card = self.statGroups and self.statGroups[groupIndex]
    if card then
      card.title:SetText(FUL.SOURCE_NAMES[group.source] or "")
      for rowIndex, baseQuality in ipairs(group.rows) do
        local row = card.rows[rowIndex]
        local b = FUL:GetBaseBucket(group.source, baseQuality) or { total = 0, normal = 0, rare = 0, epic = 0 }
        row.baseLabel:SetText(BaseQualityLabel(baseQuality))
        row.sample:SetText(tostring(b.total or 0))

        -- Keep semantic quality columns. A blue-base item that does not upgrade
        -- belongs in Rare, never in the green/Uncommon column.
        if baseQuality == 2 then
          row.uncommon:SetText(PctWithCount(b.normal or 0, b.total or 0))
          row.rare:SetText(PctWithCount(b.rare or 0, b.total or 0))
        else
          row.uncommon:SetText("-")
          row.rare:SetText(PctWithCount(b.normal or 0, b.total or 0))
        end
        row.epic:SetText(PctWithCount(b.epic or 0, b.total or 0))
        row.note:SetText(StatRowNote(group.source, baseQuality))
      end
    end
  end
end

function UI:RefreshData()
  if not FUL.db or not self.dataCount then return end
  self.dataCount:SetText(tostring(#FUL.db.events))
  self.dataIgnored:SetText(tostring((FUL.db.ignored.uncertain or 0) + (FUL.db.ignored.ineligible or 0)))
end

function UI:RefreshSettings()
  if not FUL.db then return end
  local mode = FUL.db.previewMode or "ALT"
  if self.previewModeButtons then
    for key, b in pairs(self.previewModeButtons) do SetSelectedVisual(b, key == mode) end
  end
  local on, off = T("on"), T("off")
  if self.debugToggle then SetToggleVisual(self.debugToggle, FUL.db.debug, T("debug").."  "..on, T("debug").."  "..off) end
  if self.alertOverlayToggle then SetToggleVisual(self.alertOverlayToggle, FUL.db.upgradeAlerts ~= false, T("overlay").."  "..on, T("overlay").."  "..off) end
  if self.alertSoundToggle then SetToggleVisual(self.alertSoundToggle, FUL.db.upgradeSounds ~= false, T("sound").."  "..on, T("sound").."  "..off) end
  if self.alertRareToggle then SetToggleVisual(self.alertRareToggle, FUL.db.notifyRare ~= false, "RARE  "..on, "RARE  "..off) end
  if self.alertEpicToggle then SetToggleVisual(self.alertEpicToggle, FUL.db.notifyEpic ~= false, string.upper(T("epic")).."  "..on, string.upper(T("epic")).."  "..off) end
  if self.alertMissToggle then SetToggleVisual(self.alertMissToggle, FUL.db.failedUpgradeAlerts ~= false, T("miss").."  "..on, T("miss").."  "..off) end
  if self.minimapToggle then SetToggleVisual(self.minimapToggle, FUL.db.showMinimapButton ~= false, T("icon").."  "..on, T("icon").."  "..off) end
  if self.lowerVariantsToggle then SetToggleVisual(self.lowerVariantsToggle, FUL.db.showLowerVariants == true, T("lower_variants").."  "..on, T("lower_variants").."  "..off) end
  if self.ownedProjectionsToggle then SetToggleVisual(self.ownedProjectionsToggle, FUL.db.showOwnedItemProjections == true, T("owned_projections").."  "..on, T("owned_projections").."  "..off) end
  if self.previewStyleDropdown and self.previewStyleDropdown.Refresh then self.previewStyleDropdown:Refresh() end
  if self.languageDropdown and self.languageDropdown.Refresh then self.languageDropdown:Refresh() end
end

local function StatCard(parent, x, title)
  local f = Card(parent, x, -92, 220, 122)
  local t = Label(f, title, 11, C.muted); t:SetPoint("TOPLEFT", 16, -14)
  local v = Label(f, "0", 30, C.text, "Fonts\\ARIALN.TTF"); v:SetPoint("TOPLEFT", 16, -42)
  return f, v
end

function UI:BuildOverview(page)
  local scroll=CreateFrame("ScrollFrame","FULOverviewScrollFrame",page,"UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT",0,0); scroll:SetPoint("BOTTOMRIGHT",-24,0)
  local body=CreateFrame("Frame",nil,scroll); body:SetWidth(716); body:SetHeight(610); scroll:SetScrollChild(body)
  local title = Label(body, T("overview"), 24, C.text, "Fonts\\ARIALN.TTF"); title:SetPoint("TOPLEFT", 28, -28)
  local sub = Label(body, T("overview_sub"), 12, C.muted); sub:SetPoint("TOPLEFT", 30, -58)

  local _, e = StatCard(body, 28, string.upper(T("observations"))); self.overviewEvents = e
  local _, i = StatCard(body, 262, string.upper(T("ignored"))); self.overviewIgnored = i
  local _, s = StatCard(body, 496, string.upper(T("session"))); self.overviewSession = s

  local funnel = Card(body, 28, -228, 688, 88)
  local ft=Label(funnel,T("gear_drops"),11,C.muted); ft:SetPoint("TOPLEFT",16,-12)
  local labels={{T("all"),16,"dropAll"},{T("eligible"),180,"dropEligible"},{T("rare"),360,"dropRare"},{T("epic"),510,"dropEpic"}}
  for _,v in ipairs(labels) do
    local l=Label(funnel,v[1],10,C.muted); l:SetPoint("TOPLEFT",v[2],-35)
    local n=Label(funnel,"0",20,C.text,"Fonts\\ARIALN.TTF"); n:SetPoint("TOPLEFT",v[2],-52); self[v[3]]=n
  end

  local state = Card(body, 28, -330, 688, 62)
  self.dashboardTrackState = Label(state, T("automatic_tracking"), 15, C.good, "Fonts\\ARIALN.TTF"); self.dashboardTrackState:SetPoint("TOPLEFT", 16, -14)
  local hint = Label(state, T("automatic_tracking_hint"), 11, C.muted); hint:SetPoint("TOPLEFT",16,-38)

  local y = -404
  local heads = {T("quests"), T("drops"), T("crafts")}
  local refs = {"overviewQuest", "overviewDrop", "overviewCraft"}
  for idx=1,3 do
    local r = Card(body, 28, y - (idx-1)*58, 688, 48)
    local n = Label(r, heads[idx], 13, C.text); n:SetPoint("LEFT", 16, 8)
    local v = Label(r, T("no_data"), 12, C.muted); v:SetPoint("LEFT", 16, -11)
    self[refs[idx]] = v
  end
end

function UI:BuildStats(page)
  local title = Label(page, T("statistics"), 24, C.text, "Fonts\\ARIALN.TTF"); title:SetPoint("TOPLEFT", 28, -28)
  local sub = Label(page, T("stats_sub"), 12, C.muted); sub:SetPoint("TOPLEFT", 30, -58)

  -- Fixed white column headers. Data below scrolls independently.
  local header = CreateFrame("Frame", nil, page)
  header:SetPoint("TOPLEFT", 28, -94); header:SetWidth(688); header:SetHeight(28)
  local cols = {
    {T("source"), 18}, {"n", 226}, {T("uncommon"), 306}, {T("rare"), 436}, {T("epic"), 566}
  }
  for _, c in ipairs(cols) do
    local fs = Label(header, c[1], 11, C.text)
    fs:SetPoint("LEFT", c[2], 0)
  end

  local scroll = CreateFrame("ScrollFrame", "FULStatsScrollFrame", page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 28, -122)
  scroll:SetPoint("BOTTOMRIGHT", -34, 12)

  local body = CreateFrame("Frame", nil, scroll)
  body:SetWidth(662)
  body:SetHeight(520)
  scroll:SetScrollChild(body)
  self.statsScroll = scroll
  self.statGroups = {}

  local sourceOrder = { FUL.SOURCE_QUEST, FUL.SOURCE_DROP, FUL.SOURCE_CRAFT }
  local y = 0
  for groupIndex, source in ipairs(sourceOrder) do
    local card = Card(body, 0, -y, 654, 142)
    local group = { rows = {} }
    group.title = Label(card, FUL.SOURCE_NAMES[source] or "", 14, C.text, "Fonts\\ARIALN.TTF")
    group.title:SetPoint("TOPLEFT", 16, -12)

    -- subtle divider under the source title
    local divider = Solid(card, "ARTWORK", {0.20,0.22,0.26,0.75})
    divider:SetHeight(1); divider:SetPoint("TOPLEFT", 14, -35); divider:SetPoint("TOPRIGHT", -14, -35)

    for rowIndex, baseQuality in ipairs({2,3}) do
      local rowY = -45 - (rowIndex - 1) * 48
      local row = {}
      row.baseLabel = Label(card, BaseQualityLabel(baseQuality), 11, C.text)
      row.baseLabel:SetPoint("TOPLEFT", 18, rowY)
      row.baseLabel:SetWidth(190)

      row.sample = Label(card, "0", 11, C.text)
      row.sample:SetPoint("TOPLEFT", 226, rowY)
      row.sample:SetWidth(58); row.sample:SetJustifyH("LEFT")

      row.uncommon = Label(card, "-", 11, C.good)
      row.uncommon:SetPoint("TOPLEFT", 306, rowY)
      row.uncommon:SetWidth(112); row.uncommon:SetJustifyH("LEFT")

      row.rare = Label(card, "-", 11, {0.45,0.72,1,1})
      row.rare:SetPoint("TOPLEFT", 436, rowY)
      row.rare:SetWidth(112); row.rare:SetJustifyH("LEFT")

      row.epic = Label(card, "-", 11, {0.78,0.46,1,1})
      row.epic:SetPoint("TOPLEFT", 566, rowY)
      row.epic:SetWidth(78); row.epic:SetJustifyH("LEFT")

      row.note = Label(card, "", 9, C.muted)
      row.note:SetPoint("TOPLEFT", 18, rowY - 19)
      row.note:SetWidth(620); row.note:SetJustifyH("LEFT")
      group.rows[rowIndex] = row
    end

    self.statGroups[groupIndex] = group
    y = y + 154
  end

  local note = Label(body, T("future_analysis"), 10, C.muted)
  note:SetPoint("TOPLEFT", 6, -y - 2)
  body:SetHeight(y + 38)
end

function UI:BuildData(page)
  local title = Label(page, T("data"), 24, C.text, "Fonts\\ARIALN.TTF"); title:SetPoint("TOPLEFT", 28, -28)
  local sub = Label(page, T("data_sub"), 12, C.muted); sub:SetPoint("TOPLEFT", 30, -58)

  local info = Card(page, 28, -92, 688, 68)
  local a=Label(info,T("observations"),11,C.muted); a:SetPoint("TOPLEFT",16,-13)
  self.dataCount=Label(info,"0",20,C.text,"Fonts\\ARIALN.TTF"); self.dataCount:SetPoint("TOPLEFT",16,-32)
  local b=Label(info,T("ignored"),11,C.muted); b:SetPoint("TOPLEFT",170,-13)
  self.dataIgnored=Label(info,"0",20,C.text,"Fonts\\ARIALN.TTF"); self.dataIgnored:SetPoint("TOPLEFT",170,-32)

  local help = Card(page, 28, -174, 688, 70)
  local ht=Label(help,T("save"),11,C.accent); ht:SetPoint("TOPLEFT",16,-12)
  local hd=Label(help,T("data_help"),11,C.muted)
  hd:SetPoint("TOPLEFT",16,-32); hd:SetWidth(650); hd:SetJustifyH("LEFT")

  local mode = Label(page, T("export"), 11, C.accent); mode:SetPoint("TOPLEFT", 30, -262); self.dataModeLabel=mode
  local sf = CreateFrame("ScrollFrame", "FULDataScrollFrame", page, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 28, -286); sf:SetWidth(660); sf:SetHeight(190)
  self.dataScrollFrame=sf
  local box = CreateFrame("EditBox", "FULDataEditBox", sf)
  box:SetMultiLine(true); box:SetAutoFocus(false); box:SetFont("Fonts\\ARIALN.TTF", 11, "")
  box:SetTextColor(C.text[1],C.text[2],C.text[3],1); box:SetWidth(638); box:SetHeight(186); box:SetTextInsets(10,10,10,10)
  FrameBg(box, {0.035,0.04,0.05,1}, C.border); sf:SetScrollChild(box); self.dataEdit=box

  local exportBtn = Button(page, T("export_data"), 165, 32, function()
    self.dataMode = "export"; self.dataModeLabel:SetText(T("export_copy")); SetColor(self.dataModeLabel, C.accent)
    self.dataEdit:SetText(FUL:BuildExport()); self.dataEdit:HighlightText(); self.dataEdit:SetFocus()
    self:SetStatus(T("export_ready"), C.good)
  end)
  exportBtn:SetPoint("TOPLEFT", 28, -480)

  local importModeBtn = Button(page, T("restore_backup"), 190, 32, function()
    self.dataMode = "import"; self.dataModeLabel:SetText(T("restore")); SetColor(self.dataModeLabel, C.warn)
    self.dataEdit:SetText(""); self.dataEdit:SetFocus()
    self:SetStatus(T("paste_backup"), C.warn)
  end)
  importModeBtn:SetPoint("LEFT", exportBtn, "RIGHT", 10, 0)

  StaticPopupDialogs.FUL_CONFIRM_RESTORE = {
    text=T("restore_confirm_title").."\n\n"..T("restore_confirm_text"), button1=T("yes_replace"), button2=T("cancel"), timeout=0, whileDead=1, hideOnEscape=1,
    OnAccept=function()
      local ok, n, sourceFormat = FUL:ImportExport(UI.pendingImportText or "")
      UI.pendingImportText=nil
      if ok then
        UI.dataMode=nil
        UI.dataModeLabel:SetText(T("export")); SetColor(UI.dataModeLabel,C.accent)
        UI.dataEdit:SetText(""); UI.dataEdit:ClearFocus()
        if UI.dataScrollFrame then UI.dataScrollFrame:SetVerticalScroll(0) end
        UI:RefreshData(); UI:RefreshStats(); UI:RefreshTracking(); UI:RefreshSettings(); UI:RefreshMinimapButton(); UI:RefreshOverview()
        UI:SetStatus(T("restore_success", tostring(sourceFormat), tonumber(n) or 0), C.good)
      else UI:SetStatus(T("restore_failed", tostring(n)), C.bad) end
    end,
    OnCancel=function() UI.pendingImportText=nil end,
  }
  local applyBtn = Button(page, T("confirm"), 120, 32, function()
    if self.dataMode ~= "import" then self:SetStatus(T("restore_first"), C.warn); return end
    self.pendingImportText=self.dataEdit:GetText()
    StaticPopup_Show("FUL_CONFIRM_RESTORE", T("restore_confirm_title"))
  end)
  applyBtn:SetPoint("LEFT", importModeBtn, "RIGHT", 10, 0)
end



function UI:BuildSettings(page)
  local title = Label(page, T("settings"), 24, C.text, "Fonts\\ARIALN.TTF"); title:SetPoint("TOPLEFT", 28, -28)
  local sub = Label(page, T("settings_sub"), 12, C.muted); sub:SetPoint("TOPLEFT", 30, -58)

  -- PREVIEWS -----------------------------------------------------------------
  local r1 = Card(page, 28, -86, 688, 154)
  local t1=Label(r1,T("preview_title"),13,C.text); t1:SetPoint("TOPLEFT",16,-13)
  local d1=Label(r1,T("preview_desc"),10,C.muted); d1:SetPoint("TOPLEFT",16,-34); d1:SetWidth(650); d1:SetJustifyH("LEFT")

  local styleLabel=Label(r1,T("presentation"),10,C.muted); styleLabel:SetPoint("TOPLEFT",16,-59)
  local styleHelp=HelpIcon(r1,"help_presentation_title",{
    {key="help_presentation_desc",color=C.text},{spacer=true},
    {key="help_presentation_cards",color=C.muted},{key="help_presentation_inline",color=C.muted},
  }); styleHelp:SetPoint("LEFT",styleLabel,"RIGHT",7,0)

  self.previewStyleDropdown=CustomDropdown(r1,210,30,
    function() return {{text=T("separate_cards"),value="CARDS"},{text=T("inline_tooltip"),value="INLINE"}} end,
    function() return FUL.db.previewStyle or "CARDS" end,
    function(value)
      FUL.db.previewStyle=value
      UI:RefreshSettings()
      if FUL.RefreshVariantPreviews then FUL.RefreshVariantPreviews() end
      UI:SetStatus(value=="INLINE" and T("preview_inline_status") or T("preview_cards_status"),C.good)
    end)
  self.previewStyleDropdown:SetPoint("TOPLEFT",16,-76)

  local triggerLabel=Label(r1,T("display"),10,C.muted); triggerLabel:SetPoint("TOPLEFT",250,-59)
  local triggerHelp=HelpIcon(r1,"help_display_title",{
    {key="help_display_desc",color=C.text},{spacer=true},
    {key="help_display_alt",color=C.muted},{key="help_display_always",color=C.muted},{key="help_display_off",color=C.muted},
  }); triggerHelp:SetPoint("LEFT",triggerLabel,"RIGHT",7,0)

  self.previewModeButtons = {}
  local modes = {{"ALT",T("alt_hover")},{"ALWAYS",T("always")},{"OFF",T("disabled")}}
  for i, spec in ipairs(modes) do
    local key, txt = spec[1], spec[2]
    local b = Button(r1, txt, 130, 30, function()
      FUL.db.previewMode = key
      self:RefreshSettings()
      if FUL.RefreshVariantPreviews then FUL.RefreshVariantPreviews() end
      local status = key == "ALT" and T("preview_alt_status") or (key == "ALWAYS" and T("preview_always_status") or T("preview_off_status"))
      self:SetStatus(status, C.good)
    end)
    b:SetPoint("TOPLEFT",250 + (i-1)*138,-76)
    self.previewModeButtons[key] = b
  end

  self.lowerVariantsToggle=Button(r1,T("lower_variants"),270,28,function()
    FUL.db.showLowerVariants=not FUL.db.showLowerVariants
    self:RefreshSettings()
    if FUL.RefreshVariantPreviews then FUL.RefreshVariantPreviews() end
    self:SetStatus(T("lower_variants_status",FUL.db.showLowerVariants and T("enabled") or T("disabled_plural")),FUL.db.showLowerVariants and C.good or C.muted)
  end)
  self.lowerVariantsToggle:SetPoint("TOPLEFT",16,-116)
  local lowerHelp=HelpIcon(r1,"help_lower_title",{
    {key="help_lower_desc",color=C.text},{spacer=true},{key="help_lower_on",color=C.good},{key="help_lower_off",color=C.muted},
  }); lowerHelp:SetPoint("LEFT",self.lowerVariantsToggle,"RIGHT",7,0)

  self.ownedProjectionsToggle=Button(r1,T("owned_projections"),270,28,function()
    FUL.db.showOwnedItemProjections=not FUL.db.showOwnedItemProjections
    self:RefreshSettings()
    if FUL.RefreshVariantPreviews then FUL.RefreshVariantPreviews() end
    self:SetStatus(T("owned_projections_status",FUL.db.showOwnedItemProjections and T("enabled") or T("disabled_plural")),FUL.db.showOwnedItemProjections and C.good or C.muted)
  end)
  self.ownedProjectionsToggle:SetPoint("TOPLEFT",336,-116)
  local ownedHelp=HelpIcon(r1,"help_owned_title",{
    {key="help_owned_desc",color=C.text},{spacer=true},{key="help_owned_on",color=C.good},{key="help_owned_off",color=C.muted},
  }); ownedHelp:SetPoint("LEFT",self.ownedProjectionsToggle,"RIGHT",7,0)

  -- NOTIFICATIONS -------------------------------------------------------------
  local alerts=Card(page,28,-250,688,112)
  local at=Label(alerts,T("notifications"),13,C.text); at:SetPoint("TOPLEFT",16,-13)
  local notificationHelp=HelpIcon(alerts,"help_notifications_title",{
    {key="help_notifications_desc",color=C.text},{spacer=true},
    {key="help_notifications_results",color=C.muted},{key="help_notifications_overlay",color=C.muted},{key="help_notifications_sound",color=C.muted},
  }); notificationHelp:SetPoint("LEFT",at,"RIGHT",7,0)
  local ad=Label(alerts,T("notifications_desc"),10,C.muted); ad:SetPoint("TOPLEFT",16,-35)

  local notifW, notifGap, notifX, notifY = 120, 9, 16, -62
  self.alertRareToggle=Button(alerts,string.upper(T("rare")),notifW,30,function()
    FUL.db.notifyRare=not FUL.db.notifyRare; self:RefreshSettings()
    self:SetStatus(T("rare_notif_status",FUL.db.notifyRare and T("enabled") or T("disabled_plural")),FUL.db.notifyRare and C.good or C.muted)
  end); self.alertRareToggle:SetPoint("TOPLEFT",notifX,notifY)
  self.alertEpicToggle=Button(alerts,T("epic"),notifW,30,function()
    FUL.db.notifyEpic=not FUL.db.notifyEpic; self:RefreshSettings()
    self:SetStatus(T("epic_notif_status",FUL.db.notifyEpic and T("enabled") or T("disabled_plural")),FUL.db.notifyEpic and C.good or C.muted)
  end); self.alertEpicToggle:SetPoint("TOPLEFT",notifX+(notifW+notifGap),notifY)
  self.alertMissToggle=Button(alerts,T("miss"),notifW,30,function()
    FUL.db.failedUpgradeAlerts=not FUL.db.failedUpgradeAlerts; self:RefreshSettings()
    self:SetStatus(T("miss_notif_status",FUL.db.failedUpgradeAlerts and T("enabled") or T("disabled_plural")),FUL.db.failedUpgradeAlerts and C.good or C.muted)
  end); self.alertMissToggle:SetPoint("TOPLEFT",notifX+2*(notifW+notifGap),notifY)
  self.alertOverlayToggle=Button(alerts,T("overlay"),notifW,30,function()
    FUL.db.upgradeAlerts=not FUL.db.upgradeAlerts; self:RefreshSettings()
    self:SetStatus(T("overlay_status",FUL.db.upgradeAlerts and T("enabled") or T("disabled_plural")),FUL.db.upgradeAlerts and C.good or C.muted)
  end); self.alertOverlayToggle:SetPoint("TOPLEFT",notifX+3*(notifW+notifGap),notifY)
  self.alertSoundToggle=Button(alerts,T("sound"),notifW,30,function()
    FUL.db.upgradeSounds=not FUL.db.upgradeSounds; self:RefreshSettings()
    self:SetStatus(T("sound_status",FUL.db.upgradeSounds and T("enabled") or T("disabled_plural")),FUL.db.upgradeSounds and C.good or C.muted)
  end); self.alertSoundToggle:SetPoint("TOPLEFT",notifX+4*(notifW+notifGap),notifY)

  -- ACCESS --------------------------------------------------------------------
  local access=Card(page,28,-372,688,72)
  local ait=Label(access,T("access_title"),13,C.text); ait:SetPoint("TOPLEFT",16,-12)
  local aid=Label(access,T("access_desc"),10,C.muted); aid:SetPoint("TOPLEFT",16,-34); aid:SetWidth(320); aid:SetJustifyH("LEFT")

  self.minimapToggle=Button(access,T("icon"),132,30,function()
    FUL.db.showMinimapButton=not FUL.db.showMinimapButton; self:RefreshMinimapButton(); self:RefreshSettings()
    self:SetStatus(FUL.db.showMinimapButton and T("icon_shown") or T("icon_hidden"),C.muted)
  end); self.minimapToggle:SetPoint("TOPLEFT",352,-30)
  local minimapHelp=HelpIcon(access,"help_minimap_title",{{key="help_minimap_desc",color=C.text}})
  minimapHelp:SetPoint("LEFT",self.minimapToggle,"RIGHT",7,0)

  local languageLabel=Label(access,T("language"),10,C.muted); languageLabel:SetPoint("TOPLEFT",520,-12)
  local languageHelp=HelpIcon(access,"help_language_title",{{key="help_language_desc",color=C.text}})
  languageHelp:SetPoint("LEFT",languageLabel,"RIGHT",7,0)
  self.languageDropdown=CustomDropdown(access,150,30,
    function() return {{text=FUL_LOCALES.frFR.french,value="frFR"},{text=FUL_LOCALES.enUS.english,value="enUS"}} end,
    function() return FUL.db.language or "frFR" end,
    function(value) FUL.db.language=value; if UI.languageDropdown then UI.languageDropdown:Refresh() end; ReloadUI() end)
  self.languageDropdown:SetPoint("TOPLEFT",520,-30)

  -- DATA ----------------------------------------------------------------------
  local management=Card(page,28,-454,688,58)
  local mt=Label(management,T("data_management"),13,C.text); mt:SetPoint("TOPLEFT",16,-10)
  local md=Label(management,T("data_management_desc"),10,C.muted); md:SetPoint("TOPLEFT",16,-31); md:SetWidth(480)
  StaticPopupDialogs.FUL_CONFIRM_DELETE = {
    text=T("delete_confirm_title").."\n\n"..T("delete_confirm_text"), button1=T("delete"), button2=T("cancel"), timeout=0, whileDead=1, hideOnEscape=1,
    OnAccept=function() FUL:ResetStatistics(); UI:RefreshOverview(); UI:RefreshStats(); UI:RefreshData(); UI:SetStatus(T("data_deleted"),C.good) end,
  }
  self.deleteDataButton=Button(management,T("delete_all"),144,30,function() StaticPopup_Show("FUL_CONFIRM_DELETE") end)
  self.deleteDataButton:SetPoint("RIGHT",-16,0); self.deleteDataButton:SetBaseStyle({0.20,0.075,0.075,1},C.bad,{1,.68,.68,1})
end

function UI:BuildMainFrame()
  if self.frame then return end
  local f = CreateFrame("Frame", "FrostmourneUpgradedGearFrame", UIParent)
  f:SetWidth(PANEL_W); f:SetHeight(PANEL_H); f:SetPoint("CENTER", 0, 8)
  f:SetFrameStrata("HIGH"); f:SetToplevel(true); f:EnableMouse(true); f:SetMovable(true); f:SetClampedToScreen(true)
  FrameBg(f, C.bg, {0.17,0.19,0.23,1})
  f:Hide(); self.frame = f

  local top = CreateFrame("Frame", nil, f); top:SetPoint("TOPLEFT",0,0); top:SetPoint("TOPRIGHT",0,0); top:SetHeight(64)
  local topBg = Solid(top,"BACKGROUND",{0.07,0.078,0.094,1}); topBg:SetAllPoints(top)
  top:EnableMouse(true); top:RegisterForDrag("LeftButton")
  top:SetScript("OnDragStart", function() f:StartMoving() end); top:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

  local title = Label(top,"FROSTMOURNE UPGRADED GEAR",18,C.text,"Fonts\\ARIALN.TTF"); title:SetPoint("LEFT",20,7)
  local ver = Label(top,"v"..tostring(FUL.version or ""),10,C.muted); ver:SetPoint("LEFT",title,"RIGHT",10,6)
  local sub = Label(top,T("subtitle"),10,C.muted); sub:SetPoint("LEFT",20,-14)

  local close = Button(top,"×",36,34,function() f:Hide() end); close:SetPoint("RIGHT",-14,0); close.label:SetFont("Fonts\\ARIALN.TTF",22,"")
  self.trackButton = Button(top,T("automatic_tracking"),190,34,nil); self.trackButton:SetPoint("RIGHT",close,"LEFT",-10,0); self.trackButton:EnableMouse(false)

  local nav = CreateFrame("Frame",nil,f); nav:SetPoint("TOPLEFT",0,-64); nav:SetPoint("BOTTOMLEFT",0,34); nav:SetWidth(NAV_W)
  FrameBg(nav,{0.067,0.074,0.09,1},{0.067,0.074,0.09,1})
  self.navButtons = {}
  local navItems={{"overview",T("overview")},{"stats",T("statistics")},{"data",T("data")},{"settings",T("settings")}}
  for idx,it in ipairs(navItems) do
    local key, labelText = it[1], it[2]
    local b=Button(nav,labelText,NAV_W-20,42,function() self:SelectPage(key) end)
    b:SetPoint("TOPLEFT",10,-14-(idx-1)*50); b.label:ClearAllPoints(); b.label:SetPoint("LEFT",14,0); b.label:SetJustifyH("LEFT")
    b:SetBackdropBorderColor(C.panel[1],C.panel[2],C.panel[3],1)
    self.navButtons[it[1]]=b
  end

  local content = CreateFrame("Frame",nil,f); content:SetPoint("TOPLEFT",NAV_W,-64); content:SetPoint("BOTTOMRIGHT",0,34)
  self.pages = {}
  for _, key in ipairs({"overview","stats","data","settings"}) do
    local p=CreateFrame("Frame",nil,content); p:SetAllPoints(content); p:Hide(); self.pages[key]=p
  end
  self:BuildOverview(self.pages.overview); self:BuildStats(self.pages.stats); self:BuildData(self.pages.data); self:BuildSettings(self.pages.settings)

  local bottom = CreateFrame("Frame",nil,f); bottom:SetPoint("BOTTOMLEFT",0,0); bottom:SetPoint("BOTTOMRIGHT",0,0); bottom:SetHeight(34)
  local bottomBg=Solid(bottom,"BACKGROUND",{0.045,0.05,0.06,1}); bottomBg:SetAllPoints(bottom)
  self.statusText=Label(bottom,T("ready"),10,C.muted); self.statusText:SetPoint("LEFT",14,0)

  f:SetScript("OnShow",function()
    f:Raise(); self:SelectPage(self.activePage or "overview"); self:RefreshTracking(); self:SetStatus(T("ready"), C.muted)
  end)
  f:SetScript("OnHide",function()
    if activeDropdown and activeDropdown.menu then activeDropdown.menu:Hide() end
    activeDropdown = nil
  end)

  if UISpecialFrames then table.insert(UISpecialFrames,"FrostmourneUpgradedGearFrame") end
end

local function MinimapAngleToXY(angle)
  local r = 82
  local rad = math.rad(angle or 220)
  return math.cos(rad)*r, math.sin(rad)*r
end

function UI:BuildMinimapButton()
  if self.minimapButton then return end
  local b = CreateFrame("Button","FULMinimapButton",Minimap)
  b:SetWidth(31); b:SetHeight(31); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8); b:RegisterForClicks("LeftButtonUp","RightButtonUp")

  -- Use the same geometry as standard WoW/LibDBIcon minimap buttons.
  -- The TrackingBorder texture contains built-in transparent padding and must
  -- be anchored to TOPLEFT with NO manual offset. Offsetting it is what made
  -- the ring appear above-left of the actual icon in previous builds.
  local background=b:CreateTexture(nil,"BACKGROUND")
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetWidth(20); background:SetHeight(20); background:SetPoint("TOPLEFT",7,-5)

  local icon=b:CreateTexture(nil,"ARTWORK")
  icon:SetTexture("Interface\\AddOns\\FrostmourneUpgradedGear\\Media\\FUL_MinimapIcon")
  icon:SetWidth(20); icon:SetHeight(20); icon:SetPoint("TOPLEFT",7,-5)
  icon:SetTexCoord(.08,.92,.08,.92)

  local border=b:CreateTexture(nil,"OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetWidth(53); border:SetHeight(53); border:SetPoint("TOPLEFT",0,0)

  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  self.minimapButton=b

  local angle=(FUL.db and FUL.db.minimapAngle) or 220
  local x,y=MinimapAngleToXY(angle); b:SetPoint("CENTER",Minimap,"CENTER",x,y)

  b:SetScript("OnClick",function(_,button)
    if button=="LeftButton" then self:Toggle() end
  end)
  b:SetScript("OnEnter",function()
    GameTooltip:SetOwner(b,"ANCHOR_LEFT"); GameTooltip:AddLine("Frostmourne Upgraded Gear",1,1,1)
    GameTooltip:AddLine(T("minimap_click"),0.70,0.75,0.80)
    GameTooltip:AddLine(T("minimap_drag"),0.55,0.60,0.68); GameTooltip:Show()
  end)
  b:SetScript("OnLeave",function() GameTooltip:Hide() end)

  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart",function() b.dragging=true end)
  b:SetScript("OnDragStop",function() b.dragging=false end)
  b:SetScript("OnUpdate",function()
    if not b.dragging then return end
    local mx,my=Minimap:GetCenter(); local cx,cy=GetCursorPosition(); local scale=UIParent:GetEffectiveScale(); cx=cx/scale; cy=cy/scale
    local ang=math.deg(Atan2(cy-my,cx-mx)); FUL.db.minimapAngle=ang
    local px,py=MinimapAngleToXY(ang); b:ClearAllPoints(); b:SetPoint("CENTER",Minimap,"CENTER",px,py)
  end)
  self:RefreshMinimapButton()
end

function UI:RefreshMinimapButton()
  if not self.minimapButton or not FUL.db then return end
  if FUL.db.showMinimapButton == false then self.minimapButton:Hide() else self.minimapButton:Show() end
end

function UI:BuildInterfaceOptions()
  if self.optionsPanel or type(InterfaceOptions_AddCategory) ~= "function" then return end
  local p=CreateFrame("Frame","FULInterfaceOptionsPanel",InterfaceOptionsFramePanelContainer)
  p.name="Frostmourne Upgraded Gear"
  self.optionsPanel=p

  local title=p:CreateFontString(nil,"ARTWORK","GameFontNormalLarge"); title:SetPoint("TOPLEFT",16,-16); title:SetText("Frostmourne Upgraded Gear")
  local desc=p:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); desc:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-10); desc:SetWidth(560); desc:SetJustifyH("LEFT")
  desc:SetText(T("interface_desc"))

  local cb=CreateFrame("CheckButton","FULInterfaceOptionsMinimap",p,"InterfaceOptionsCheckButtonTemplate")
  cb:SetPoint("TOPLEFT",desc,"BOTTOMLEFT",0,-18)
  _G[cb:GetName().."Text"]:SetText(T("show_minimap"))
  cb:SetScript("OnClick",function(self)
    FUL.db.showMinimapButton=self:GetChecked() and true or false
    UI:RefreshMinimapButton(); UI:RefreshSettings()
  end)

  local hint=p:CreateFontString(nil,"ARTWORK","GameFontDisableSmall"); hint:SetPoint("TOPLEFT",cb,"BOTTOMLEFT",26,-4)
  hint:SetText(T("minimap_hint"))

  local open=CreateFrame("Button",nil,p,"UIPanelButtonTemplate"); open:SetWidth(190); open:SetHeight(24); open:SetPoint("TOPLEFT",hint,"BOTTOMLEFT",-26,-20)
  open:SetText(T("open_full_settings"))
  open:SetScript("OnClick",function()
    if InterfaceOptionsFrame then InterfaceOptionsFrame:Hide() end
    UI:BuildMainFrame(); UI.frame:Show(); UI:SelectPage("settings")
  end)
  p:SetScript("OnShow",function() cb:SetChecked(FUL.db and FUL.db.showMinimapButton ~= false) end)
  InterfaceOptions_AddCategory(p)
end

function UI:Toggle()
  self:BuildMainFrame()
  if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end

function UI:Init()
  self:BuildMainFrame(); self:BuildMinimapButton(); self:BuildInterfaceOptions(); self:RefreshTracking(); self:SelectPage("overview")
end
