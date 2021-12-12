if game.local_player.champ_name ~= "Chogath" then 
	return 
end

local color_table = {"FF0000", "FF2900", "FF5300", "FF7C00", "FFA500", "FFCF00", "FFF800", "DDFF00", "B3FF00", "8AFF00", "60FF00", "37FF00", "0EFF00", "00FF1C", "00FF45", "00FF6E", "00FF98", "00FFC1", "00FFEA", "00EAFF", "00C1FF", "0098FF", "006EFF", "0045FF", "001CFF", "0E00FF", "3700FF", "6000FF", "8A00FF", "B300FF", "DD00FF", "FF00F8", "FF00CF", "FF00A5", "FF007C", "FF0053", "FF0029"}

local function ColorWrapText(string, colors)
    local base_string = "<font color='#"
    local concat_string = ""
    local counter = 1
    for i = 1, #string do
        if counter > #colors then
            counter = 1
        end
        local char = string:sub(i, i)
        concat_string = concat_string .. base_string .. tostring(colors[counter]) .. "'>" .. char .. "</font>"
        counter = counter + 1
    end
    game:print_chat(concat_string)
end

------- Chogath To Do ----
--Flash Ult
-- Auto Q on dash/gap_close
-- Use fast pred to cast q after w
-- E W Q ONLY

local file_name = "VectorMath.lua"
if not file_manager:file_exists(file_name) then
   local url = "https://raw.githubusercontent.com/stoneb2/Bruhwalker/main/VectorMath/VectorMath.lua"
   http:download_file(url, file_name)
   console:log("VectorMath Library Downloaded")
   console:log("Please Reload with F5")
end

local ml = require "VectorMath"

if not file_manager:file_exists("PKDamageLib.lua") then
	local file_name = "PKDamageLib.lua"
	local url = "http://raw.githubusercontent.com/Astraanator/test/main/Champions/PKDamageLib.lua"   	
	http:download_file(url, file_name)
end

require "PKDamageLib" 

if not file_manager:file_exists("VectorMath.lua") then
	local file_name = "VectorMath.lua"
	local url = "http://raw.githubusercontent.com/Astraanator/test/main/Champions/PKDamageLib.lua"   	
	http:download_file(url, file_name)
end

if not file_manager:directory_exists("Banthors Common") then
    file_manager:create_directory("Banthors Common")
end

local file_name = "Prediction.lib"
if not file_manager:file_exists(file_name) then
   local url = "https://raw.githubusercontent.com/Ark223/Bruhwalker/main/Prediction.lib"
   http:download_file(url, file_name)
   console:log("Ark223 Prediction Library Downloaded")
   console:log("Please Reload with F5")
end


pred:use_prediction()
arkpred = _G.Prediction

local myHero = game.local_player
lastTime = 0
Runonce = 0
local ExtraRange = 0
MinionFeast = 0
EpicFeast = 0
EnemyFeast = 0

---------------- Spell Variables --------------- 
-- Radius Q = 115 Delay .5 Range = 950
-- Cast delay .30 speed 2000 radius 50
-- Possibly Good Range = 750, Radius = 87.5, CastDelay = 1.20, Speed = math.huge
local Q = { Range = 750, Radius = 87.5, CastDelay = 0.5, Speed = 2000 }
local W = { Range = 620, Angle = 60, CastDelay = 0.5, Speed = math.huge }
local E = { Range = 500, Width = 340, CastDelay = 0 }
local R = { Range = 250, CastDelay = 0.25 }

local Q_input = {
    source = myHero,
	hitbox = false,
	speed = Q.Speed, 
	range = Q.Range,
	delay = Q.CastDelay, 
	radius = Q.Radius,
	collision = { },
    type = "circular"
}

local W_input = {
    source = myHero,
	hitbox = false,
	speed = W.Speed, 
	range = W.Range,
	delay = W.CastDelay, 
	angle = W.Angle,
	collision = { },
    type = "conic"
}

local function RRange()
	local FeastBuff = myHero:get_buff("Feast")
	local FeastStacks = FeastBuff.stacks2
	local level = spellbook:get_spell_slot(SLOT_R).level
	if level >= 1 and ExtraRange <= 75 then
		ExtraRange = ({4.62, 6.15, 7.69})[level] * FeastStacks
	end
	return ExtraRange + R.Range
end

local function Ready(spell)
    return spellbook:can_cast(spell) 
end


local function GetEnemyHeroes()
	local _EnemyHeroes = {}
	players = game.players	
	for i, unit in ipairs(players) do
		if unit and unit.is_enemy then
			table.insert(_EnemyHeroes, unit)
		end
	end	
	return _EnemyHeroes
end	

local function GetAllyHeroes()
	local _AllyHeroes = {}
	players = game.players	
	for i, unit in ipairs(players) do
		if unit and not unit.is_enemy and unit.object_id ~= myHero.object_id then
			table.insert(_AllyHeroes, unit)
		end
	end
	return _AllyHeroes
end

local function IsValid(unit)
    if (unit and unit.is_targetable and unit.is_alive and unit.is_visible and unit.object_id and unit.health > 0) then
        return true
    end
    return false
end

local function IsImmobileTarget(unit)
	if unit:has_buff_type(5) or unit:has_buff_type(11) or unit:has_buff_type(29) or unit:has_buff_type(24) or unit:has_buff_type(10) then
		return true
	end
	return false	
end

local function GetDistanceSqr(unit, p2)
	p2 = p2.origin or myHero.origin	
	p2x, p2y, p2z = p2.x, p2.y, p2.z
	p1 = unit.origin
	p1x, p1y, p1z = p1.x, p1.y, p1.z	
	local dx = p1x - p2x
	local dz = (p1z or p1y) - (p2z or p2y)
	return dx*dx + dz*dz
end

local function GetDistanceSqr2(p1, p2)    
    p2x, p2y, p2z = p2.x, p2.y, p2.z
    p1x, p1y, p1z = p1.x, p1.y, p1.z    
    local dx = p1x - p2x
    local dz = (p1z or p1y) - (p2z or p2y)
    return dx*dx + dz*dz
end

local function VectorPointProjectionOnLineSegment(v1, v2, v)
    local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
    local pointLine = { x = ax + rL * (bx - ax), y = ay + rL * (by - ay) }
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or { x = ax + rS * (bx - ax), y = ay + rS * (by - ay) }
    return pointSegment, pointLine, isOnSegment
end

local function GetLineTargetCount(source, aimPos, range, width)
    local Count = 0
	local QCount = 0
	players = game.players
	for _, target in ipairs(players) do
        local Range = range * range
        if target.object_id ~= 0 and IsValid(target) and target.is_enemy and GetDistanceSqr(myHero, target) < Range then     
    
            local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(source.origin, aimPos, target.origin)
            if pointSegment and isOnSegment and (GetDistanceSqr2(target.origin, pointSegment) <= (target.bounding_radius + width) * (target.bounding_radius + width)) then
                Count = Count + 1    
            end
        end
		if target.object_id ~= 0 and IsValid(target) and target.is_enemy and GetDistanceSqr(myHero, target) < Range and IsImmobileTarget(target) then     
    
            local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(source.origin, aimPos, target.origin)
            if pointSegment and isOnSegment and (GetDistanceSqr2(target.origin, pointSegment) <= (target.bounding_radius + width) * (target.bounding_radius + width)) then
                QCount = QCount + 1    
            end
        end
    end        
    return Count, QCount
end

local function GetEnemyCount(range, unit)
	count = 0
	for i, hero in ipairs(GetEnemyHeroes()) do
	Range = range * range
		if unit.object_id ~= hero.object_id and GetDistanceSqr(unit, hero) < Range and IsValid(hero) then
		count = count + 1
		end
	end
	return count
end

local function GetEnemyCountCicular(range, p1)
	count = 0
	players = game.players
	for _, unit in ipairs(players) do
	Range = range * range
		if unit.is_enemy and GetDistanceSqr2(p1, unit.origin) < Range and IsValid(unit) then
		count = count + 1
		end
	end
	return count
end

local function GetEnemyCountCicularMinions(range, p1)
	count = 0
	for _, unit in ipairs(game.minions) do
	Range = range * range
		if unit.is_enemy and GetDistanceSqr2(p1, unit.origin) < Range and IsValid(unit) then
		count = count + 1
		end
	end
	return count
end


local function GetMinionCount(range, unit)
	count = 0
	minions = game.minions
	for i, minion in ipairs(minions) do
	Range = range * range
		if minion.is_enemy and IsValid(minion) and unit.object_id ~= minion.object_id and GetDistanceSqr(unit, minion) < Range then
			count = count + 1
		end
	end
	return count
end

local function Is_Me(unit)
	if unit.champ_name == myHero.champ_name and myHero.object_id == unit.object_id then
		return true
	end
	return false
end

local function GetMousePos()
    x, y, z = game.mouse_pos.x, game.mouse_pos.y, game.mouse_pos.z
    local output = vec3.new(x, y, z)
    return output
end

-- Menu --

if file_manager:file_exists("Banthors Common//Chogath.png") then
	BChogath_category = menu:add_category_sprite("Banthors Chogath", "Banthors Common//Chogath.png")
else
	http:download_file("https://raw.githubusercontent.com/Banthors/Bruhwalker/main/Banthors%20Chogath/Chogath.png", "Banthors Common//Chogath.png")
	BChogath_category = menu:add_category("Banthors Chogath")
end
BChogath_enabled = menu:add_checkbox("Enabled", BChogath_category, 1)
BChogath_combokey = menu:add_keybinder("Combo Key", BChogath_category, 32)

--[[if file_manager:file_exists("Banthors Common//wheelchair.png") then
	UsePrediction = menu:add_subcategory_sprite("Prediction Features", BChogath_category, "Banthors Common//wheelchair.png")
else
	http:download_file("https://raw.githubusercontent.com/Banthors/Bruhwalker/main/Banthors%20Common/wheelchair.png", "Banthors Common//wheelchair.png")
	UsePrediction = menu:add_subcategory("Prediction Features", BChogath_category )
end
UsePrediction_table = {}
UsePrediction_table[1] = "Internal Prediction"
UsePrediction_table[2] = "Arks Prediction"
UsePredictionCombo = menu:add_combobox("Which Prediction To Use", UsePrediction, UsePrediction_table, 1)

if file_manager:file_exists("Banthors Common//Ark.png") then
	ArkPrediction = menu:add_subcategory_sprite("Ark Prediction Features", BChogath_category, "Banthors Common//Ark.png")
else
	http:download_file("https://raw.githubusercontent.com/Banthors/Bruhwalker/main/Banthors%20Common/Ark.png", "Banthors Common//Ark.png")
	ArkPrediction = menu:add_subcategory("Ark Prediction Features", BChogath_category )
end
ChogathQHitchance = menu:add_slider("[Q] Hit Chance [%]", ArkPrediction, 1, 99, 50)
ChogathWHitchance = menu:add_slider("[W] Hit Chance [%]", ArkPrediction, 1, 99, 50)
ChogathEHitchance = menu:add_slider("[E] Hit Chance [%]", ArkPrediction, 1, 99, 50)
ChogathRHitchance = menu:add_slider("[R] Hit Chance [%]", ArkPrediction, 1, 99, 50)]]

if file_manager:file_exists("Banthors Common//Combo.png") then
	Bcombo = menu:add_subcategory_sprite("Combo Features", BChogath_category, "Banthors Common//Combo.png")
else
	http:download_file("https://raw.githubusercontent.com/Banthors/Bruhwalker/main/Banthors%20Common/Combo.png", "Banthors Common//Combo.png")
	Bcombo = menu:add_subcategory("Combo Features", BChogath_category)
end

if file_manager:file_exists("Banthors Common//ChogathQ.png") then
	BcomboQ = menu:add_subcategory_sprite("[Q] Options", Bcombo, "Banthors Common//ChogathQ.png")
else
	http:download_file("https://raw.githubusercontent.com/Banthors/Bruhwalker/main/Banthors%20Chogath/ChogathQ.png", "Banthors Common//ChogathQ.png")
	BcomboQ = menu:add_subcategory("[Q] Options", Bcombo)
end
ComboQ = menu:add_checkbox("Use [Q]", BcomboQ, 1)
ComboQ_GapClose = menu:add_checkbox("Use [Q] On Gap Close", BcomboQ, 1)

if file_manager:file_exists("Banthors Common//ChogathW.png") then
	BcomboW = menu:add_subcategory_sprite("[W] Options", Bcombo, "Banthors Common//ChogathW.png")
else
	http:download_file("https://raw.githubusercontent.com/Banthors/Bruhwalker/main/Banthors%20Chogath/ChogathW.png", "Banthors Common//ChogathW.png")
	BcomboW = menu:add_subcategory("[W] Options", Bcombo)
end
ComboW = menu:add_checkbox("Use [W]", BcomboW, 1)
ComboWInterrupt = menu:add_checkbox("Use [W] On Interruptible Spells", BcomboW, 1)

if file_manager:file_exists("Banthors Common//ChogathE.png") then
	BcomboE = menu:add_subcategory_sprite("[E] Options", Bcombo, "Banthors Common//ChogathE.png")
else
	http:download_file("https://raw.githubusercontent.com/Banthors/Bruhwalker/main/Banthors%20Chogath/ChogathE.png", "Banthors Common//ChogathE.png")
	BcomboE = menu:add_subcategory("[E] Options", Bcombo)
end
ComboE = menu:add_checkbox("Use [E]", BcomboE, 1)


if file_manager:file_exists("Banthors Common//ChogathR.png") then
	BcomboR = menu:add_subcategory_sprite("[R] Options", Bcombo, "Banthors Common//ChogathR.png")
else
	http:download_file("https://raw.githubusercontent.com/Banthors/Bruhwalker/main/Banthors%20Chogath/ChogathR.png", "Banthors Common//ChogathR.png")
	BcomboR = menu:add_subcategory("[R] Options", Bcombo)
end
ComboR = menu:add_checkbox("Use R", BcomboR, 1)


if file_manager:file_exists("Banthors Common//Harass.png") then
	Bharass = menu:add_subcategory_sprite("Harass Features", BChogath_category, "Banthors Common//Harass.png")
else
	http:download_file("https://raw.githubusercontent.com/Banthors/Bruhwalker/main/Banthors%20Common/Harass.png", "Banthors Common//Harass.png")
	Bharass = menu:add_subcategory("Harass Features", BChogath_category)
end
HarassQ = menu:add_checkbox("Use [Q] Harass", Bharass, 1)





if file_manager:file_exists("Banthors Common//LaneClear.png") then
	Blane = menu:add_subcategory_sprite("LaneClear Features", BChogath_category, "Banthors Common//LaneClear.png")
else
	http:download_file("https://raw.githubusercontent.com/Banthors/Bruhwalker/main/Banthors%20Common/LaneClear.png", "Banthors Common//LaneClear.png")
	Blane = menu:add_subcategory("LaneClear Features", BChogath_category)
end
LaneQ = menu:add_checkbox("Use [Q]", Blane, 1)
LaneQX = menu:add_slider("Min Minions to [Q]", Blane, 1, 6, 3)
LaneW = menu:add_checkbox("Use [W]", Blane, 1)
LaneWX = menu:add_slider("Min Minions to [W]", Blane, 1, 6, 3)
LaneE = menu:add_checkbox("Use [E]", Blane, 1)
LaneR = menu:add_checkbox("Use [R]", Blane, 1)
LaneMana = menu:add_slider("Min Mana To LaneClear", Blane, 1, 100, 20)





if file_manager:file_exists("Banthors Common//JungleClear.png") then
	Bjungle = menu:add_subcategory_sprite("JungleClear Features", BChogath_category, "Banthors Common//JungleClear.png")
else
	http:download_file("https://raw.githubusercontent.com/Banthors/Bruhwalker/main/Banthors%20Common/JungleClear.png", "Banthors Common//JungleClear.png")
	Bjungle = menu:add_subcategory("JungleClear Features", BChogath_category)
end
JungleQ = menu:add_checkbox("Use [Q]", Bjungle, 1)
JungleQX = menu:add_slider("Min Minions to [Q]", Bjungle, 1, 6, 2)
JungleW = menu:add_checkbox("Use [W]", Bjungle, 1)
JungleWX = menu:add_slider("Min Minions to [W]", Bjungle, 1, 6, 2)
JungleE = menu:add_checkbox("Use [E]", Bjungle, 1)
JungleR = menu:add_checkbox("Use [R]", Bjungle, 1)
JungleMana = menu:add_slider("Min Mana To JungleClear", Bjungle, 1, 100, 20)




if file_manager:file_exists("Banthors Common//LastHit.png") then
	Blast = menu:add_subcategory_sprite("LastHit Features", BChogath_category, "Banthors Common//LastHit.png")
else
	http:download_file("https://raw.githubusercontent.com/Banthors/Bruhwalker/main/Banthors%20Common/LastHit.png", "Banthors Common//LastHit.png")
	Blast = menu:add_subcategory("LastHit Features", BChogath_category)
end




if file_manager:file_exists("Banthors Common//KillSteal.png") then
	Bkill = menu:add_subcategory_sprite("KillSteal Features", BChogath_category, "Banthors Common//KillSteal.png")
else
	http:download_file("https://raw.githubusercontent.com/Banthors/Bruhwalker/main/Banthors%20Common/KillSteal.png", "Banthors Common//KillSteal.png")
	Bkill = menu:add_subcategory("KillSteal Features", BChogath_category)
end
KillstealQ = menu:add_checkbox("Killsteal [Q]", Bkill, 1)
KillstealW = menu:add_checkbox("Killsteal [W]", Bkill, 1)
KillstealR = menu:add_checkbox("Killsteal [R]", Bkill, 1)

if file_manager:file_exists("Banthors Common//Drawing.png") then
	BSpell_range = menu:add_subcategory_sprite("Drawing Features", BChogath_category, "Banthors Common//Drawing.png")
else
	http:download_file("https://raw.githubusercontent.com/Banthors/Bruhwalker/main/Banthors%20Common/Drawing.png", "Banthors Common//Drawing.png")
	BSpell_range = menu:add_subcategory("Drawing Features", BChogath_category)
end
Bdrawq = menu:add_checkbox("Draw Q", BSpell_range, 1)
Bdraww = menu:add_checkbox("Draw W", BSpell_range, 1)
Bdrawe = menu:add_checkbox("Draw E", BSpell_range, 1)
Bdrawr = menu:add_checkbox("Draw R", BSpell_range, 1)
BColorR = menu:add_slider("Red", BSpell_range, 1, 255, 220)
BColorG = menu:add_slider("Green", BSpell_range, 1, 255, 55)
BColorB = menu:add_slider("Blue", BSpell_range, 1, 255, 14)
BColorA = menu:add_slider("Alpha", BSpell_range, 1, 255, 255)

-- Cast Q Function --

local function CastQInternal(unit)
	p = unit.origin
	spellbook:cast_spell(SLOT_Q, 0.5, p.x, p.y, p.z)
end

-- Cast W Function --

local function CastWInternal(unit)
	--console:log("Casting W")
	p = unit.origin
	spellbook:cast_spell(SLOT_W, 0.5, p.x, p.y, p.z)
end

--Cast E Function --

local function CastEInternal()
	spellbook:cast_spell(SLOT_E)
end

-- Cast R Function --

local function CastRInternal(unit)
	--console:log("Casting R")
	spellbook:cast_spell(SLOT_R)
end

local function CastQArk(unit)
	t = arkpred:get_prediction(Q_input, unit).cast_pos
	x = unit.move_speed
	y = x * 850 / 1000
	pos = unit.origin
	if (unit:distance_to(t) <= y) then
		pos = t
	end
	if (unit:distance_to(t) > y) then
		pos = ml.Extend(unit.origin, t, y)
	end
	if (myHero:distance_to(pos) <=949 and unit:distance_to(pos) >= 100) then
		spellbook:cast_spell(SLOT_Q, Q.CastDelay, pos.x, pos.y, pos.z)
	end
	if (myHero:distance_to(unit.origin) <= myHero.bounding_radius + myHero.attack_range + unit.bounding_radius) then
		spellbook:cast_spell(SLOT_Q, Q.CastDelay, pos.x, pos.y, pos.z)
	end
end

local function CastWArk(unit)
	local output = arkpred:get_aoe_prediction(W_input, unit)
	if output.hit_chance >= menu:get_value(ChogathWHitchance) / 100 then
		local p = output.cast_pos
		spellbook:cast_spell(SLOT_W, W.CastDelay, p.x, p.y, p.z)
	end
end

local function CastEArk()
	spellbook:cast_spell(SLOT_E)
end

local function CastRArk(unit)
	spellbook:cast_spell_targetted(SLOT_R, target, R.CastDelay)
end


-- Combo Logic --

local function Combo()
	target = selector:find_target(1100, mode_health)
	if target.is_enemy and myHero:distance_to(target.origin) <= RRange() and IsValid(target) and Ready(SLOT_R) and menu:get_value(ComboR) == 1 then
		local RDmg = getdmg("R", target, game.local_player, 1)
		if RDmg - 20 > target.health then
			spellbook:cast_spell_targetted(SLOT_R, target, R.CastDelay)
		end
	end
	-- Use Q --
	if target.is_enemy and myHero:distance_to(target.origin) <= Q.Range and IsValid(target) and Ready(SLOT_Q) and menu:get_value(ComboQ) == 1 then
		CastQArk(target)
	end
	-- Use W --
	if target.is_enemy and myHero:distance_to(target.origin) <= W.Range and IsValid(target) and Ready(SLOT_W) and menu:get_value(ComboW) == 1 then
		CastWArk(target)
	end
	-- Use E --
	if target.is_enemy and myHero:distance_to(target.origin) <= E.Range and IsValid(target) and Ready(SLOT_E) and menu:get_value(ComboE) == 1 then
		CastEArk(target)
	end
end

local function LaneClear()
	for _, v in ipairs(game.minions) do
		local mana_ok = myHero.mana/myHero.max_mana >= menu:get_value(LaneMana) / 100
		if myHero:distance_to(v.origin) <= RRange() and v.object_id ~= 0 and IsValid(v) and menu:get_value(JungleR) == 1 and Ready(SLOT_R) then
			local RDmg = getdmg("R", v, game.local_player, 1)
			if RDmg > v.health then
				spellbook:cast_spell_targetted(SLOT_R, v, R.CastDelay)
			end
		end
		if v.is_enemy and myHero:distance_to(v.origin) <= 950 and IsValid(v) and menu:get_value(LaneQ) == 1 and mana_ok and Ready(SLOT_Q) then
			BestPos, MostHit = ml.GetBestCircularFarmPos(v, 950, 230)
			if MostHit >= menu:get_value(LaneQX) then
				spellbook:cast_spell(SLOT_Q, 0.5, BestPos.x, BestPos.y, BestPos.z)
			end
		end
		if v.is_enemy and myHero:distance_to(v.origin) <= W.Range and IsValid(v) and menu:get_value(LaneW) == 1 and mana_ok and Ready(SLOT_W) then
			BestPos, MostHit = ml.GetBestCircularFarmPos(v, W.Range, 150)
			if MostHit >= menu:get_value(LaneWX) then
				spellbook:cast_spell(SLOT_W, W.CastDelay, BestPos.x, BestPos.y, BestPos.z)
			end
		end
		if v.is_enemy and myHero:distance_to(v.origin) <= E.Range and IsValid(v) and menu:get_value(LaneE) == 1 and mana_ok and Ready(SLOT_E) then
			CastEInternal(v)
		end
	end
end

local function JungleClear()
	for _, v in ipairs(game.jungle_minions) do
		local mana_ok = myHero.mana/myHero.max_mana >= menu:get_value(JungleMana) / 100
		if v.is_enemy and myHero:distance_to(v.origin) <= Q.Range and IsValid(v) and menu:get_value(JungleQ) == 1 and mana_ok and Ready(SLOT_Q) then
			if ml.JungleMonstersAround(myHero.origin, Q.Range) == 1 then
				CastQInternal(v)
			elseif ml.JungleMonstersAround(myHero.origin, Q.Range) > 1 then
				BestPos, MostHit = ml.GetBestCircularJungPos(v, Q.Range, 230)
				if MostHit >= menu:get_value(JungleQX) then
					spellbook:cast_spell(SLOT_Q, Q.CastDelay, BestPos.x, BestPos.y, BestPos.z)
				end
			end
		end
		if v.is_enemy and myHero:distance_to(v.origin) <= W.Range and IsValid(v) and menu:get_value(JungleW) == 1 and mana_ok and Ready(SLOT_W) then
			if ml.JungleMonstersAround(myHero.origin, W.Range) == 1 then
				CastWInternal(v)
			elseif ml.JungleMonstersAround(myHero.origin, W.Range) > 1 then
				BestPos, MostHit = ml.GetBestCircularJungPos(v, W.Range, 150)
				if MostHit >= menu:get_value(JungleWX) then
					spellbook:cast_spell(SLOT_W, W.CastDelay, BestPos.x, BestPos.y, BestPos.z)
				end
			end
		end
		if v.is_enemy and myHero:distance_to(v.origin) <= E.Range and IsValid(v) and menu:get_value(JungleE) == 1 and mana_ok and Ready(SLOT_E) then
			CastEInternal()
		end
		if myHero:distance_to(v.origin) <= RRange() and v.object_id ~= 0 and IsValid(v) and menu:get_value(JungleR) == 1 and Ready(SLOT_R) then
			local RDmg = getdmg("R", v, game.local_player, 1)
			if RDmg > v.health then
				spellbook:cast_spell_targetted(SLOT_R, v, R.CastDelay)
			end
		end
	end
end

local function KillSteal()
	for i, target in ipairs(GetEnemyHeroes()) do     	
		if myHero:distance_to(target.origin) <= RRange() and target.object_id ~= 0 and IsValid(target) and menu:get_value(KillstealR) == 1 and Ready(SLOT_R) then
			local RDmg = getdmg("R", target, game.local_player, 1)
			if RDmg > target.health then
				spellbook:cast_spell_targetted(SLOT_R, target, R.CastDelay)
			end
		end
		if myHero:distance_to(target.origin) <= Q.Range and target.object_id ~= 0 and IsValid(target) and menu:get_value(KillstealQ) == 1 and Ready(SLOT_Q) then
			local QDmg = getdmg("Q", target, game.local_player, 1)
			if QDmg > target.health then
				CastQInternal(target)
			end
		end
		if myHero:distance_to(target.origin) <= W.Range and target.object_id ~= 0 and IsValid(target) and menu:get_value(KillstealW) == 1 and Ready(SLOT_W) then
			local WDmg = getdmg("W", target, game.local_player, 1)
			if WDmg > target.health then
				CastWInternal(target)
			end
		end
	end
end

local function Harass()
	target = selector:find_target(1100, mode_health)
	-- Use Q --
	if target.is_enemy and myHero:distance_to(target.origin) <= Q.Range and IsValid(target) and Ready(SLOT_Q) and menu:get_value(ComboQ) == 1 then
		CastQArk(target)
	end
	-- Use W --
	if target.is_enemy and myHero:distance_to(target.origin) <= W.Range and IsValid(target) and Ready(SLOT_W) and menu:get_value(ComboW) == 1 then
		CastWArk(target)
	end
	-- Use E --
	if target.is_enemy and myHero:distance_to(target.origin) <= E.Range and IsValid(target) and Ready(SLOT_E) and menu:get_value(ComboE) == 1 then
		CastEArk(target)
	end
end

local function RTracker()
	console:log(MinionFeast)
	console:log(EpicFeast)
	console:log(EnemyFeast)
end


-- Drawings --

local function on_draw()
	local_player = game.local_player

	if local_player.object_id ~= 0 then
		origin = local_player.origin
		x, y, z = origin.x, origin.y, origin.z

		if menu:get_value(Bdrawq) == 1 then
			if Ready(SLOT_Q) then
				renderer:draw_circle(x, y, z, Q.Range, menu:get_value(BColorR), menu:get_value(BColorG), menu:get_value(BColorB), menu:get_value(BColorA))
			end
		end

		if menu:get_value(Bdraww) == 1 then
			if Ready(SLOT_W) then
				renderer:draw_circle(x, y, z, W.Range, menu:get_value(BColorR), menu:get_value(BColorG), menu:get_value(BColorB), menu:get_value(BColorA))
			end
		end

		if menu:get_value(Bdrawe) == 1 then
			if Ready(SLOT_E) then
				renderer:draw_circle(x, y, z, E.Range, menu:get_value(BColorR), menu:get_value(BColorG), menu:get_value(BColorB), menu:get_value(BColorA))
			end
		end

		if menu:get_value(Bdrawr) == 1 then
			if Ready(SLOT_R) then
				renderer:draw_circle(x, y, z, RRange(), menu:get_value(BColorR), menu:get_value(BColorG), menu:get_value(BColorB), menu:get_value(BColorA))
			end
		end
	end
end

local function on_possible_interrupt(obj, spell_name)
	if IsValid(obj) and obj.is_enemy and myHero:distance_to(obj.origin) <= W.Range and menu:get_value(ComboWInterrupt) == 1 then
		CastWArk(obj)
	end
end

local function on_dash(obj, dash_info)

end

local function on_process_spell(obj, args)
	if Is_Me(obj) then
		--console:log(tostring(args.spell_name))
		if args.spell_name == "ChogathBasicAttack" or args.spell_name == "ChogathBasicAttack2" then
			Runonce = 0
		end
		--[[if args.spell_name == "Feast" then
			if args.target.is_enemy then
				EnemyFeast = EnemyFeast + 1
			end
			if args.target.is_minion then
				MinionFeast = MinionFeast + 1
			end
			if args.target.is_jungle_minion then
				if args.target.champ_name == ("SRU_Dragon_Air") 
				or args.target.champ_name == ("SRU_Dragon_Fire") 
				or args.target.champ_name == ("SRU_Dragon_Water") 
				or args.target.champ_name == ("SRU_Dragon_Earth") 
				or args.target.champ_name == ("SRU_Dragon_Elder")
				or args.target.champ_name == ("SRU_Dragon_Chemtech")
				or args.target.champ_name == ("SRU_Dragon_Hextech") 
				or args.target.champ_name == ("SRU_Baron") then
					EpicFeast = EpicFeast + 1
				end
			end
		end]]
	end
end

local function on_gap_close(obj, data)
	if menu:get_value(ComboQ_GapClose) == 1 and myHero:distance_to(obj.origin) <= Q.Range and obj.is_enemy and IsValid(obj) then
		pos = data.end_pos
		spellbook:cast_spell(SLOT_Q, Q.CastDelay, pos.x, pos.y, pos.z)
	end
end

local function on_buff_active(obj, buff_name)
	if Is_Me(obj) then
		if buff_name == "recall" then
			Recalling = true
		end
	end
end

local function on_buff_end(obj, buff_name)
	if Is_Me(obj) then
		if buff_name == "recall" then
			Recalling = false
		end
	end
end

local function ParticleCheck()
	----- On Process Backup -----
	particles = game.particles
	if ((client:get_tick_count() - lastTime) < 175) then
		return
	end 
	lastTime = client:get_tick_count()
	for _, v in ipairs(particles) do
		if v.object_name == "Chogath_Base_E_Cas" then
			if Runonce == 0 then
				orbwalker:reset_aa()
				target = selector:find_target(425, mode_health)
				if target.object_id ~= 0 then
					orbwalker:attack_target(target)
				end
			end
			Runonce = 1
		end
	end
end


-- Every Game Tick --

local function on_tick()
	local Mode = combo:get_mode()
	if game:is_key_down(menu:get_value(BChogath_combokey)) then
		Combo()
	elseif Mode == MODE_HARASS then
		Harass()
	elseif Mode == MODE_LANECLEAR then
		LaneClear()
		JungleClear()
	end
	RRange()
	KillSteal()
	ParticleCheck()
	--RTracker()
end

client:set_event_callback("on_tick", on_tick) 
client:set_event_callback("on_draw", on_draw)
client:set_event_callback("on_dash", on_dash)
client:set_event_callback("on_gap_close", on_gap_close)
client:set_event_callback("on_buff_active", on_buff_active)
client:set_event_callback("on_buff_end", on_buff_end)
client:set_event_callback("on_process_spell", on_process_spell)
client:set_event_callback("on_possible_interrupt", on_possible_interrupt)


console:clear()

-- Auto Updater --
do
	local function AutoUpdate()
		local Version = 1.2
		local file_name = "BanthorsChogath.lua"
		local url = "https://raw.githubusercontent.com/Banthors/Bruhwalker/main/Banthors%20Chogath/BanthorsChogath.lua"
		local web_version = http:get("https://raw.githubusercontent.com/Banthors/Bruhwalker/main/Banthors%20Chogath/BanthorsChogath.version.txt")
		--console:log("BanthorsChogath.Lua Vers: "..Version)
		--console:log("BanthorsChogath.Web Vers: "..tonumber(web_version))
		if tonumber(web_version) == Version then
			ColorWrapText("Banthors Chogath V1.2 Successfully Loaded.....", color_table)
			else
			http:download_file(url, file_name)
			ColorWrapText("New Chogath Update available.....", color_table)
			ColorWrapText("Please reload via F5.....", color_table)
			end
		end
  
 AutoUpdate()

end