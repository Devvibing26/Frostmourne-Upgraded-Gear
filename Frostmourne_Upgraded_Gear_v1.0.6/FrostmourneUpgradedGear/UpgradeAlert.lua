local alert = CreateFrame("Frame", "FULUpgradeAlert", UIParent)
alert:SetWidth(420); alert:SetHeight(92); alert:SetPoint("TOP", UIParent, "TOP", 0, -165)
alert:SetFrameStrata("DIALOG"); alert:Hide()
alert:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
alert:SetBackdropColor(0.035,0.04,0.05,0.96); alert:SetBackdropBorderColor(0.3,0.82,0.95,0.9)
local icon=alert:CreateTexture(nil,"ARTWORK"); icon:SetWidth(58); icon:SetHeight(58); icon:SetPoint("LEFT",16,0)
local title=alert:CreateFontString(nil,"OVERLAY"); title:SetFont("Fonts\\ARIALN.TTF",22,"OUTLINE"); title:SetPoint("TOPLEFT",88,-17); title:SetText("UPGRADE")
local item=alert:CreateFontString(nil,"OVERLAY"); item:SetFont("Fonts\\FRIZQT__.TTF",13,""); item:SetPoint("TOPLEFT",88,-49); item:SetWidth(310); item:SetJustifyH("LEFT")
local source=alert:CreateFontString(nil,"OVERLAY"); source:SetFont("Fonts\\ARIALN.TTF",10,""); source:SetPoint("TOPLEFT",88,-69); source:SetTextColor(.6,.64,.7,1)
local seq=0

local function PlayAlertSound(kind)
  if not FUL.db or FUL.db.upgradeSounds == false then return end
  if kind == "epic" then
    pcall(PlaySoundFile, "Sound\\Interface\\RaidWarning.wav")
  elseif kind == "rare" then
    pcall(PlaySoundFile, "Sound\\Interface\\iQuestComplete.wav")
  else
    -- Deliberately small/negative cue: the item was eligible, but the roll stayed normal.
    local ok, played = pcall(PlaySoundFile, "Sound\\Interface\\iQuestFailed.wav")
    if (not ok or played == false) and type(PlaySound) == "function" then pcall(PlaySound, "igQuestFailed") end
  end
end

local function ShowVisual(link, name, kind, sourceText)
  if not FUL.db or FUL.db.upgradeAlerts == false then return end
  seq=seq+1; local mine=seq
  local _,_,_,_,_,_,_,_,_,texture=GetItemInfo(link)
  icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
  if kind == "epic" then
    title:SetText(FUL:T("upgrade_epic")); title:SetTextColor(.78,.46,1,1); alert:SetBackdropBorderColor(.78,.46,1,1)
  elseif kind == "rare" then
    title:SetText(FUL:T("upgrade_rare")); title:SetTextColor(.35,.68,1,1); alert:SetBackdropBorderColor(.35,.68,1,1)
  else
    title:SetText(FUL:T("no_upgrade")); title:SetTextColor(.78,.80,.84,1); alert:SetBackdropBorderColor(.52,.56,.62,.95)
  end
  item:SetText(name or FUL:T("item"))
  source:SetText(sourceText or "")
  alert:SetAlpha(1); alert:Show()
  local elapsed=0
  alert:SetScript("OnUpdate",function(self,dt)
    if mine~=seq then return end
    elapsed=elapsed+dt
    if elapsed>2.8 then self:SetAlpha(math.max(0,1-(elapsed-2.8)/.55)) end
    if elapsed>3.35 then self:Hide(); self:SetScript("OnUpdate",nil) end
  end)
end

function FUL:ShowUpgradeAlert(link, name, outcome, sourceID)
  if not self.db then return end
  if outcome == "rare" and self.db.notifyRare == false then return end
  if outcome == "epic" and self.db.notifyEpic == false then return end
  local src = (self.SOURCE_NAMES and self.SOURCE_NAMES[sourceID]) or ""
  ShowVisual(link, name, outcome, src)
  PlayAlertSound(outcome)
end

function FUL:ShowUpgradeMissAlert(link, name, sourceID, baseQuality)
  if not self.db or self.db.failedUpgradeAlerts == false then return end
  local src = (self.SOURCE_NAMES and self.SOURCE_NAMES[sourceID]) or ""
  local eligible = baseQuality == 3 and self:T("eligible_epic_miss") or self:T("eligible_both_miss")
  ShowVisual(link, name, "miss", src .. (src ~= "" and " • " or "") .. eligible)
  PlayAlertSound("miss")
end
