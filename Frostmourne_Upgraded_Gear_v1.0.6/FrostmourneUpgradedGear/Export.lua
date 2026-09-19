local function Escape(s)
  s = tostring(s or "")
  return (s:gsub("([^%w %-%._:/'])", function(c) return string.format("%%%02X", string.byte(c)) end))
end
local function Unescape(s)
  return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h,16)) end))
end

function FUL:BuildExport()
  local out = { "FUL1" }
  local codes = { name="N", zone="Z", subzone="S", quest="Q", mob="M", recipe="R", char="C" }
  for _, kind in ipairs({"name","zone","subzone","quest","mob","recipe","char"}) do
    for id, value in ipairs(self.db.dict[kind]) do
      out[#out+1] = "D\t" .. codes[kind] .. "\t" .. id .. "\t" .. Escape(value)
    end
  end
  for _, e in ipairs(self.db.events) do
    local v = {}
    for i=1,13 do v[i] = tostring(e[i] or 0) end
    out[#out+1] = "E\t" .. table.concat(v, ",")
  end
  local d=self.db.dropScan or {}
  out[#out+1] = string.format("S\t%d,%d,%d,%d,%d", d.allGear or 0,d.eligible or 0,d.eligibleNormal or 0,d.rare or 0,d.epic or 0)
  return table.concat(out, "\n")
end

function FUL:ImportExport(text)
  if not text or text:match("^%s*$") then return false, self:T("no_import_data") end
  local header = text:match("^%s*([^\r\n]+)")
  if header then header = header:gsub("%s+$", "") end
  if header ~= "FUL1" and header ~= "FUL2" and header ~= "WUI1" and header ~= "WUI2" then
    return false, self:T("invalid_format")
  end
  local newdb = {
    version=1, trackingEnabled=true, strictMode=true, showTooltip=true, debug=false,
    language=(self.db and self.db.language or "frFR"),
    minimapAngle=(self.db and self.db.minimapAngle or 220),
    showMinimapButton=(not self.db or self.db.showMinimapButton ~= false),
    showVariantPreviews=(not self.db or self.db.showVariantPreviews ~= false),
    previewStyle=(self.db and self.db.previewStyle or "CARDS"),
    previewMode=(self.db and self.db.previewMode or "ALT"),
    upgradeAlerts=(not self.db or self.db.upgradeAlerts ~= false),
    upgradeSounds=(not self.db or self.db.upgradeSounds ~= false),
    notifyRare=(not self.db or self.db.notifyRare ~= false),
    notifyEpic=(not self.db or self.db.notifyEpic ~= false),
    failedUpgradeAlerts=(not self.db or self.db.failedUpgradeAlerts ~= false),
    dropScan={allGear=0,eligible=0,eligibleNormal=0,rare=0,epic=0},
    sessionSeq=(self.db and self.db.sessionSeq or 0), events={},
    dict={name={},zone={},subzone={},quest={},mob={},recipe={},char={}}, ignored={uncertain=0,ineligible=0},
  }
  local kinds = { N="name", Z="zone", S="subzone", Q="quest", M="mob", R="recipe", C="char" }
  for line in text:gmatch("[^\r\n]+") do
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if line:match("^D%s+") then
      local code,id,val = line:match("^D%s+([^%s]+)%s+(%d+)%s+(.*)$")
      local kind = kinds[code]
      if kind then newdb.dict[kind][tonumber(id)] = Unescape(val) end
    elseif line:match("^S%s+") then
      local payload=line:match("^S%s+(.+)$") or ""
      local a,b,c,d,e=payload:match("^(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)$")
      if a then newdb.dropScan={allGear=tonumber(a),eligible=tonumber(b),eligibleNormal=tonumber(c),rare=tonumber(d),epic=tonumber(e)} end
    elseif line:match("^E%s+") then
      local csv = line:match("^E%s+(.+)$") or ""; local e = {}
      for n in csv:gmatch("[^,%s]+") do e[#e+1] = tonumber(n) or 0 end
      if #e >= 13 then newdb.events[#newdb.events+1] = e end
    end
  end
  if #newdb.events == 0 then return false, self:T("no_import_events") end
  FrostmourneUpgradedLookDB = newdb
  self.db = newdb
  self:BuildDictReverse(); self:RebuildStats()
  return true, #newdb.events, header
end
