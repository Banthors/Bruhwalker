-- Always cache current skin on load
-- Localize data
-- Want to prettify the menu sprites
-- Data structure in common folder -- Skinchanger Sprites And Cached file

local json = { _version = "0.1.2" }

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
  [ "\\" ] = "\\",
  [ "\"" ] = "\"",
  [ "\b" ] = "b",
  [ "\f" ] = "f",
  [ "\n" ] = "n",
  [ "\r" ] = "r",
  [ "\t" ] = "t",
}

local escape_char_map_inv = { [ "/" ] = "/" }
for k, v in pairs(escape_char_map) do
  escape_char_map_inv[v] = k
end

local function escape_char(c)
  return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end

local function encode_nil(val)
  return "null"
end

local function encode_table(val, stack)
  local res = {}
  stack = stack or {}

  -- Circular reference?
  if stack[val] then error("circular reference") end

  stack[val] = true

  if rawget(val, 1) ~= nil or next(val) == nil then
    -- Treat as array -- check keys are valid and it is not sparse
    local n = 0
    for k in pairs(val) do
      if type(k) ~= "number" then
        error("invalid table: mixed or invalid key types")
      end
      n = n + 1
    end
    if n ~= #val then
      error("invalid table: sparse array")
    end
    -- Encode
    for i, v in ipairs(val) do
      table.insert(res, encode(v, stack))
    end
    stack[val] = nil
    return "[" .. table.concat(res, ",") .. "]"

  else
    -- Treat as an object
    for k, v in pairs(val) do
      if type(k) ~= "string" then
        error("invalid table: mixed or invalid key types")
      end
      table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
    end
    stack[val] = nil
    return "{" .. table.concat(res, ",") .. "}"
  end
end

local function encode_string(val)
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end

local function encode_number(val)
  -- Check for NaN, -inf and inf
  if val ~= val or val <= -math.huge or val >= math.huge then
    error("unexpected number value '" .. tostring(val) .. "'")
  end
  return string.format("%.14g", val)
end

local type_func_map = {
  [ "nil"     ] = encode_nil,
  [ "table"   ] = encode_table,
  [ "string"  ] = encode_string,
  [ "number"  ] = encode_number,
  [ "boolean" ] = tostring,
}

encode = function(val, stack)
  local t = type(val)
  local f = type_func_map[t]
  if f then
    return f(val, stack)
  end
  error("unexpected type '" .. t .. "'")
end

function json.encode(val)
  return ( encode(val) )
end

-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do
    res[ select(i, ...) ] = true
  end
  return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
  [ "true"  ] = true,
  [ "false" ] = false,
  [ "null"  ] = nil,
}

local function next_char(str, idx, set, negate)
  for i = idx, #str do
    if set[str:sub(i, i)] ~= negate then
      return i
    end
  end
  return #str + 1
end

local function decode_error(str, idx, msg)
  local line_count = 1
  local col_count = 1
  for i = 1, idx - 1 do
    col_count = col_count + 1
    if str:sub(i, i) == "\n" then
      line_count = line_count + 1
      col_count = 1
    end
  end
  error( string.format("%s at line %d col %d", msg, line_count, col_count) )
end

local function codepoint_to_utf8(n)
  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
  local f = math.floor
  if n <= 0x7f then
    return string.char(n)
  elseif n <= 0x7ff then
    return string.char(f(n / 64) + 192, n % 64 + 128)
  elseif n <= 0xffff then
    return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
  elseif n <= 0x10ffff then
    return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                       f(n % 4096 / 64) + 128, n % 64 + 128)
  end
  error( string.format("invalid unicode codepoint '%x'", n) )
end

local function parse_unicode_escape(s)
  local n1 = tonumber( s:sub(1, 4),  16 )
  local n2 = tonumber( s:sub(7, 10), 16 )
   -- Surrogate pair?
  if n2 then
    return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
  else
    return codepoint_to_utf8(n1)
  end
end

local function parse_string(str, i)
  local res = ""
  local j = i + 1
  local k = j

  while j <= #str do
    local x = str:byte(j)

    if x < 32 then
      decode_error(str, j, "control character in string")

    elseif x == 92 then -- `\`: Escape
      res = res .. str:sub(k, j - 1)
      j = j + 1
      local c = str:sub(j, j)
      if c == "u" then
        local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                 or str:match("^%x%x%x%x", j + 1)
                 or decode_error(str, j - 1, "invalid unicode escape in string")
        res = res .. parse_unicode_escape(hex)
        j = j + #hex
      else
        if not escape_chars[c] then
          decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
        end
        res = res .. escape_char_map_inv[c]
      end
      k = j + 1

    elseif x == 34 then -- `"`: End of string
      res = res .. str:sub(k, j - 1)
      return res, j + 1
    end

    j = j + 1
  end

  decode_error(str, i, "expected closing quote for string")
end

local function parse_number(str, i)
  local x = next_char(str, i, delim_chars)
  local s = str:sub(i, x - 1)
  local n = tonumber(s)
  if not n then
    decode_error(str, i, "invalid number '" .. s .. "'")
  end
  return n, x
end

local function parse_literal(str, i)
  local x = next_char(str, i, delim_chars)
  local word = str:sub(i, x - 1)
  if not literals[word] then
    decode_error(str, i, "invalid literal '" .. word .. "'")
  end
  return literal_map[word], x
end

local function parse_array(str, i)
  local res = {}
  local n = 1
  i = i + 1
  while 1 do
    local x
    i = next_char(str, i, space_chars, true)
    -- Empty / end of array?
    if str:sub(i, i) == "]" then
      i = i + 1
      break
    end
    -- Read token
    x, i = parse(str, i)
    res[n] = x
    n = n + 1
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "]" then break end
    if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
  end
  return res, i
end

local function parse_object(str, i)
  local res = {}
  i = i + 1
  while 1 do
    local key, val
    i = next_char(str, i, space_chars, true)
    -- Empty / end of object?
    if str:sub(i, i) == "}" then
      i = i + 1
      break
    end
    -- Read key
    if str:sub(i, i) ~= '"' then
      decode_error(str, i, "expected string for key")
    end
    key, i = parse(str, i)
    -- Read ':' delimiter
    i = next_char(str, i, space_chars, true)
    if str:sub(i, i) ~= ":" then
      decode_error(str, i, "expected ':' after key")
    end
    i = next_char(str, i + 1, space_chars, true)
    -- Read value
    val, i = parse(str, i)
    -- Set
    res[key] = val
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "}" then break end
    if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
  end
  return res, i
end

local char_func_map = {
  [ '"' ] = parse_string,
  [ "0" ] = parse_number,
  [ "1" ] = parse_number,
  [ "2" ] = parse_number,
  [ "3" ] = parse_number,
  [ "4" ] = parse_number,
  [ "5" ] = parse_number,
  [ "6" ] = parse_number,
  [ "7" ] = parse_number,
  [ "8" ] = parse_number,
  [ "9" ] = parse_number,
  [ "-" ] = parse_number,
  [ "t" ] = parse_literal,
  [ "f" ] = parse_literal,
  [ "n" ] = parse_literal,
  [ "[" ] = parse_array,
  [ "{" ] = parse_object,
}

parse = function(str, idx)
  local chr = str:sub(idx, idx)
  local f = char_func_map[chr]
  if f then
    return f(str, idx)
  end
  decode_error(str, idx, "unexpected character '" .. chr .. "'")
end

function json.decode(str)
  if type(str) ~= "string" then
    error("expected argument of type string, got " .. type(str))
  end
  local res, idx = parse(str, next_char(str, 1, space_chars, true))
  idx = next_char(str, idx, space_chars, true)
  if idx <= #str then
    decode_error(str, idx, "trailing garbage")
  end
  return res
end

players = game.players

local function GetAllyHeroes()
    local output = {}
    for i, champ in ipairs(players) do
        if not champ.is_enemy then
            table.insert(output, champ)
        end
    end
    return output
end

local function GetEnemyHeroes()
    local output = {}
    for i, champ in ipairs(players) do
        if champ.is_enemy then
            table.insert(output, champ)
        end
    end
    return output
end

local allies = GetAllyHeroes()
local enemies = GetEnemyHeroes()

myHero = game.local_player

local function StringSplit(inputstr, sep, sep2)
    sep = sep or "%s"
    sep2 = sep2 or nil

    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
       table.insert(t, str)
    end

    if sep2 then
        for str in string.gmatch(t[1], "([^" .. sep2 .. "]+)") do
            return str
        end
    end

    return t
 end

local function GetData()
    local Base = "https://cdn.merakianalytics.com/riot/lol/resources/latest/en-US/champions.json"
    return http:get(Base)
 end

local function GetSkins(champ)
  local data = json.decode(GetData)[champ.champ_name]["skins"]
    for i, Skin in ipairs(data) do
      console:log(Skin)
    end
end

 local function GetVersion()
    local version_url = "https://ddragon.leagueoflegends.com/api/versions.json"
    local version = StringSplit(http:get(version_url), '["', '"')
    return version
 end

local function GetData(champ)
    local champ_name = champ.champ_name
    local version = GetVersion()
    local base = "http://ddragon.leagueoflegends.com/cdn/" .. version .. "/data/en_US/champion/" .. champ_name .. ".json"
    return http:get(base)
end

local function GetSkins(champ)
    local skin_table = {}
    local skin_values = {}
    local has_chromas = {}

    local data = json.decode(GetData(champ))["data"][champ.champ_name]["skins"]
    for i, skin in ipairs(data) do
        table.insert(skin_table, skin["name"])
        skin_values[skin["name"]] = skin["num"]
        --[[
        if skin["chromas"] == true then
            console:log(skin["name"] .. " has chromas")
        end
        ]]
    end

    return skin_table, skin_values
end

local function class()
    return setmetatable({}, {
        __call = function(self, ...)
            local result = setmetatable({}, {__index = self})
            result:__init(...)
            return result
        end
    })
end

local SkinChanger = class()

function SkinChanger:__init()
    self.skins = {}
    for i, champ in ipairs(players) do
        local skin_table, skin_values = GetSkins(champ)
        self.skins[champ.object_id] = skin_table
        for k, skin in ipairs(skin_table) do
            self.skins[skin] = skin_values[skin]
        end
    end

    self:Menu()

    client:set_event_callback("on_tick", function() self:OnTick() end)
end

function SkinChanger:Menu()
    self.menu = menu:add_category("Skin Changer")
    
    self.skins_menu = {}
    self.ChampSkinCat = {}

    self.label1 = menu:add_label("Ally Skins", self.menu)
    for i, champ in ipairs(allies) do
      local Logo = os.getenv('APPDATA'):gsub("Roaming","Local\\leaguesense\\sprites\\"..champ.champ_name..".png")
      self.ChampSkinSub = menu:add_subcategory_sprite(tostring(champ.champ_name), self.menu, Logo)
      self.skins_menu[champ.object_id] = menu:add_combobox(tostring(champ.champ_name.."s Skin"), self.ChampSkinSub, self.skins[champ.object_id], champ.current_skin)
    end

    self.label2 = menu:add_label("Enemy Skins", self.menu)
    for i, champ in ipairs(enemies) do
      local Logo = os.getenv('APPDATA'):gsub("Roaming","Local\\leaguesense\\sprites\\"..champ.champ_name..".png")
      self.ChampSkinSub = menu:add_subcategory_sprite(tostring(champ.champ_name), self.menu, Logo)
      self.skins_menu[champ.object_id] = menu:add_combobox(tostring(champ.champ_name.."s Skin"), self.ChampSkinSub, self.skins[champ.object_id], champ.current_skin)
    end
end

function SkinChanger:MenuToSkinID(champ)
    local object_id = champ.object_id
    local index = menu:get_value(self.skins_menu[object_id])
    local skin_name = self.skins[object_id][index + 1]
    local skin_id = self.skins[skin_name]
    return skin_id
end

function SkinChanger:OnTick()
    for i, champ in ipairs(players) do
      local current_skin = champ.current_skin
      local skin_id = self:MenuToSkinID(champ)
      local skin_matches = current_skin == skin_id
      if not skin_matches then
          champ:set_skin(skin_id)
      end
    end
    wards = game.wards
    for _, v in ipairs(wards) do
      --console:log(v.current_skin)
      --if v.current_skin ~= 10 then
        --v:set_skin(10)
      --end
    end
    jungle_camps = game.jungle_camps

    for _, camp in ipairs(jungle_camps) do
      --console:log(camp.current_skin)
      --if camp.current_skin ~= 1 then
        --camp:set_skin(2)
      --end
    end
    --[[minions = game.minions

    for _, x in ipairs(minions) do
      if myHero:distance_to(x.origin) < 1000 then
        --console:log(x.current_skin)
        --if x.current_skin ~= 10 then
          --x:set_skin(10)
        --end
      end
    end]]
end

SkinChanger:__init()