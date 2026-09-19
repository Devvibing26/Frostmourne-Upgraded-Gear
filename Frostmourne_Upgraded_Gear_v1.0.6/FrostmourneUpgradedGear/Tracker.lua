FUL.track = FUL.track or {}

local function ItemNameFromLink(link)
  if not link then return nil end
  local name = GetItemInfo(link)
  if name then return name end
  return link:match("%[(.-)%]")
end

local function FindQuestIDByTitle(title)
  if GetQuestID then
    local id = GetQuestID()
    if id and id > 0 then return id end
  end
  if not title or title == "" or not GetNumQuestLogEntries or not GetQuestLogTitle then return 0 end
  local n = GetNumQuestLogEntries() or 0
  for i=1,n do
    local t, a2, a3, a4, a5, a6, a7, a8, a9 = GetQuestLogTitle(i)
    if t == title then
      -- Wrath 3.3.5 exposes questID as the 9th return. Some derivative clients expose it as 8th.
      local id9 = tonumber(a9)
      local id8 = tonumber(a8)
      if id9 and id9 > 0 then return id9 end
      if id8 and id8 > 3 then return id8 end
    end
  end
  return 0
end

local function CaptureQuest()
  local title = (GetTitleText and GetTitleText()) or ""
  local q = {
    id = FindQuestIDByTitle(title),
    title = title,
    zone = GetRealZoneText(), subzone = GetSubZoneText(),
    guaranteed = {}, choices = {}, createdAt = GetTime(),
  }
  local nr = (GetNumQuestRewards and GetNumQuestRewards()) or 0
  for i=1,nr do
    local link = GetQuestItemLink and GetQuestItemLink("reward", i)
    if link then
      local itemName = ItemNameFromLink(link)
      local _,_,quality = GetItemInfo(link)
      local familyKey = FUL:GetFamilyKey(link, itemName)
      q.guaranteed[#q.guaranteed+1] = { link=link, name=itemName, quality=quality, familyKey=familyKey }
    end
  end
  local nc = (GetNumQuestChoices and GetNumQuestChoices()) or 0
  for i=1,nc do
    local link = GetQuestItemLink and GetQuestItemLink("choice", i)
    if link then
      local itemName = ItemNameFromLink(link)
      local _,_,quality = GetItemInfo(link)
      local familyKey = FUL:GetFamilyKey(link, itemName)
      q.choices[i] = { link=link, name=itemName, quality=quality, familyKey=familyKey }
    end
  end
  FUL.track.quest = q
end

local function ArmQuest(choice)
  local q = FUL.track.quest
  if not q then CaptureQuest(); q = FUL.track.quest end
  if not q then return end
  q.expected = {}
  local function AddExpected(x)
    if not x then return end
    if x.familyKey then q.expected[x.familyKey] = x.quality or true end
    -- Keep a locale-local fallback only for legacy/unmapped items.
    if x.name then q.expected["local:" .. x.name] = x.quality or true end
  end
  for _, x in ipairs(q.guaranteed or {}) do AddExpected(x) end
  local c = q.choices and q.choices[choice or 0]
  AddExpected(c)
  q.expires = GetTime() + 8
  q.armed = true
end

local function ParseFirstItemLink(msg)
  if not msg then return nil end
  return msg:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)") or msg:match("(|Hitem:.-|h%[.-%]|h)")
end

local function IsEquippableItem(link)
  if not link then return false end
  local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
  return equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_TABARD" and equipLoc ~= "INVTYPE_BODY"
end

local function RecordDropScan(link, name)
  if not FUL.db or not FUL.db.trackingEnabled or not IsEquippableItem(link) then return end
  local d = FUL.db.dropScan
  d.allGear = (d.allGear or 0) + 1
  local family = FUL:ResolveFamily(link, name)
  if not family then return end
  d.eligible = (d.eligible or 0) + 1
  local _, _, resultQuality = GetItemInfo(link)
  local baseQuality = FUL:InferBaseQuality(link, family)
  local outcome = FUL:Outcome(baseQuality, resultQuality)
  if outcome == "rare" then d.rare = (d.rare or 0) + 1
  elseif outcome == "epic" then d.epic = (d.epic or 0) + 1
  else d.eligibleNormal = (d.eligibleNormal or 0) + 1 end
end

local function CurrentDeadTarget()
  if UnitExists("target") and UnitIsDead("target") and not UnitIsPlayer("target") then
    return UnitGUID("target"), UnitName("target")
  end
end

local f = CreateFrame("Frame")
for _, ev in ipairs({"QUEST_COMPLETE","QUEST_FINISHED","LOOT_OPENED","LOOT_CLOSED","CHAT_MSG_LOOT","PLAYER_ENTERING_WORLD"}) do f:RegisterEvent(ev) end
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "QUEST_COMPLETE" then
    CaptureQuest()
  elseif event == "QUEST_FINISHED" then
    -- Do not clear immediately; reward chat can arrive after the frame closes.
    local q = FUL.track.quest
    if q and q.armed then q.expires = math.max(q.expires or 0, GetTime()+3) end
  elseif event == "LOOT_OPENED" then
    local guid, name = CurrentDeadTarget()
    FUL.track.loot = { expires = GetTime()+10, zone=GetRealZoneText(), subzone=GetSubZoneText(), mobGUID=guid, mobName=name }
  elseif event == "LOOT_CLOSED" then
    if FUL.track.loot then FUL.track.loot.expires = GetTime()+2 end
  elseif event == "PLAYER_ENTERING_WORLD" then
    FUL.track.quest = nil; FUL.track.loot = nil; FUL.track.craft = nil
  elseif event == "CHAT_MSG_LOOT" then
    if not FUL.db or not FUL.db.trackingEnabled then return end
    local link = ParseFirstItemLink(arg1)
    if not link then return end
    local name = ItemNameFromLink(link)
    if not name then return end
    local familyKey = FUL:GetFamilyKey(link, name)
    local now = GetTime()

    -- Highest priority: explicit quest-turn-in context.
    local q = FUL.track.quest
    local questExpectedKey = familyKey or ("local:" .. name)
    local questExpected = q and q.expected and (q.expected[questExpectedKey] or q.expected["local:" .. name])
    if q and q.armed and (q.expires or 0) >= now and questExpected then
      local bq = questExpected
      if type(bq) ~= "number" then bq = nil end
      FUL:RecordObservation({ source=FUL.SOURCE_QUEST, itemLink=link, itemName=name, baseQuality=bq,
        questID=q.id, questTitle=q.title, zone=q.zone, subzone=q.subzone })
      q.expected[questExpectedKey] = nil
      q.expected["local:" .. name] = nil
      return
    end

    -- Second priority: craft explicitly armed by DoTradeSkill.
    local c = FUL.track.craft
    local craftMatch = c and ((c.familyKey and familyKey and c.familyKey == familyKey) or c.name == name)
    if c and (c.expires or 0) >= now and craftMatch and (c.remaining or 0) > 0 then
      FUL:RecordObservation({ source=FUL.SOURCE_CRAFT, itemLink=link, itemName=name, baseQuality=c.baseQuality,
        recipeID=c.recipeID, recipeName=c.recipeName, profession=c.profession, zone=c.zone, subzone=c.subzone })
      c.remaining = c.remaining - 1
      if c.remaining <= 0 then c.expires = now + 0.5 end
      return
    end

    -- Drop is accepted only inside an actual loot session. This deliberately rejects .additem,
    -- vendor/AH purchases, mail, trade and unexplained bag additions.
    local l = FUL.track.loot
    if l and (l.expires or 0) >= now then
      RecordDropScan(link, name)
      if FUL:ResolveFamily(link, name) then
        FUL:RecordObservation({ source=FUL.SOURCE_DROP, itemLink=link, itemName=name,
          zone=l.zone, subzone=l.subzone, mobGUID=l.mobGUID, mobName=l.mobName })
      end
      if FUL.UI and FUL.UI.RefreshOverview then FUL.UI:RefreshOverview() end
      return
    end

    FUL.db.ignored.uncertain = (FUL.db.ignored.uncertain or 0) + 1
    if FUL.db.debug then FUL:Print("IGNORÉ (source incertaine): " .. name) end
  end
end)

if hooksecurefunc then
  if GetQuestReward then hooksecurefunc("GetQuestReward", function(choice) ArmQuest(choice) end) end
  if DoTradeSkill then hooksecurefunc("DoTradeSkill", function(index, count)
    if not FUL.db or not FUL.db.trackingEnabled then return end
    local link = GetTradeSkillItemLink and GetTradeSkillItemLink(index)
    if not link then return end
    local name = ItemNameFromLink(link)
    if not name then return end
    local familyKey, family = FUL:GetFamilyKey(link, name)
    if not familyKey or not family then return end
    local _,_,quality = GetItemInfo(link)
    local recipeLink = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(index)
    local recipeID = recipeLink and tonumber(recipeLink:match("enchant:(%d+)")) or 0
    local recipeName = GetTradeSkillInfo and select(1, GetTradeSkillInfo(index)) or name
    local available = GetTradeSkillInfo and select(3, GetTradeSkillInfo(index)) or 1
    local profession = GetTradeSkillLine and select(1, GetTradeSkillLine()) or ""
    local requested = tonumber(count) or 1
    if requested <= 0 then requested = tonumber(available) or 1 end
    requested = math.max(1, requested)
    FUL.track.craft = {
      name=name, familyKey=familyKey, baseQuality=FUL:InferBaseQuality(link, family) or quality,
      recipeID=recipeID, recipeName=recipeName, profession=profession,
      remaining=requested, expires=GetTime()+math.max(15, requested*8),
      zone=GetRealZoneText(), subzone=GetSubZoneText(),
    }
  end) end
end
