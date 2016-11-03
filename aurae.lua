local _G, _M, _F = getfenv(0), {}, CreateFrame'Frame'
setfenv(1, setmetatable(_M, {__index=_G}))

_F:SetScript('OnUpdate', function() _M.UPDATE() end)

_F:SetScript('OnEvent', function()
	_M[event](this)
end)
_F:RegisterEvent'ADDON_LOADED'

CreateFrame('GameTooltip', 'aurae_Tooltip', nil, 'GameTooltipTemplate')

function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage('<aurae> ' .. msg)
end

function QuickLocalize(str)
	-- just remove $1 & $2 args because we *know that the order is not changed*.
	-- not fail proof if ever it occurs (should be a more clever function, and return found arguments order)
	str = string.gsub(str, '.%$', '')
	str = string.gsub(str, '%%s', '(.+)')
	return str
end

WIDTH = 170
HEIGHT = 16
MAXBARS = 10

_G.ETYPE_CC = 1
_G.ETYPE_DEBUFF = 2
_G.ETYPE_BUFF = 4

--_G.aurae_ARCANIST_ON = "Arcanist' Set activated (+15 sec to ".."Polymorph".." spell)"
--_G.aurae_ARCANIST_OFF = "Arcanist' Set off"

_G.aurae_settings = {}

_G.aurae = {}
aurae.EFFECTS = {}
aurae.COMBO = 0

-- effect groups for each bar
aurae.GROUPSCC = {}
aurae.GROUPSDEBUFF = {}
aurae.GROUPSBUFF = {}

_G.aurae_SCHOOL = {
	NONE = {1, 1, 1},
	PHYSICAL = {1, 1, 0},
	HOLY = {1, .9, .5},
	FIRE = {1, .5, 0},
	NATURE = {.3, 1, .3},
	FROST = {.5, 1, 1},
	SHADOW = {.5, .5, 1},
	ARCANE = {1, .5, 1},
}

DR_CLASS = {
	["Bash"] = 1,
	["Hammer of Justice"] = 1,
	["Cheap Shot"] = 1,
	["Charge Stun"] = 1,
	["Intercept Stun"] = 1,
	["Concussion Blow"] = 1,

	["Fear"] = 2,
	["Howl of Terror"] = 2,
	["Seduction"] = 2,
	["Intimidating Shout"] = 2,
	["Psychic Scream"] = 2,

	["Polymorph"] = 3,
	["Sap"] = 3,
	["Gouge"] = 3,

	["Entangling Roots"] = 4,
	["Frost Nova"] = 4,

	["Freezing Trap"] = 5,
	["Wyvern String"] = 5,

	["Blind"] = 6,

	["Hibernate"] = 7,

	["Mind Control"] = 8,

	["Kidney Shot"] = 9,

	["Death Coil"] = 10,

	["Frost Shock"] = 11,
}

do
	local dr = {}

	local factor = {1, 1/2, 1/4, 0}

	local function diminish(key, seconds)
		return factor[dr[key].level] * seconds
	end

	function DiminishedDuration(unit, effect, full_duration)
		local class = DR_CLASS[effect]
		if class then
			StartDR(effect, unit)
			return full_duration * factor[timers[class .. '@' .. unit].DR]
		else
			return full_duration
		end
	end
end

function UnitDebuffs(unit)
	local debuffs = {}
	local i = 1
	while UnitDebuff(unit, i) do
		aurae_Tooltip:SetOwner(UIParent, 'ANCHOR_NONE')
		aurae_Tooltip:SetUnitDebuff(unit, i)
		debuffs[aurae_TooltipTextLeft1:GetText()] = true
		i = i + 1
	end
	return debuffs
end

local function create_bar()

	local texture = [[Interface\Addons\aurae\bar]]
	local font, _, style = GameFontHighlight:GetFont()
	local fontsize = 11

	local f = CreateFrame('Button', nil, UIParent)

	f.fadetime = .5

	f:SetHeight(HEIGHT)

	f.icon = f:CreateTexture()
	f.icon:SetWidth(HEIGHT)
	f.icon:SetPoint('TOPLEFT', 0, 0)
	f.icon:SetPoint('BOTTOMLEFT', 0, 0)
	f.icon:SetTexture[[Interface\Icons\INV_Misc_QuestionMark]]
	f.icon:SetTexCoord(.08, .92, .08, .92)

	f.statusbar = CreateFrame('StatusBar', nil, f)
	f.statusbar:SetPoint('TOPLEFT', f.icon, 'TOPRIGHT', 0, 0)
	f.statusbar:SetPoint('BOTTOMRIGHT', 0, 0)
	f.statusbar:SetStatusBarTexture(texture)
	f.statusbar:SetStatusBarColor(.5, .5, .5, 1)
	f.statusbar:SetMinMaxValues(0, 1)
	f.statusbar:SetValue(1)
	f.statusbar:SetBackdrop{bgFile=texture}
	f.statusbar:SetBackdropColor(.5, .5, .5, .3)

	f.spark = f.statusbar:CreateTexture(nil, 'OVERLAY')
	f.spark:SetTexture[[Interface\CastingBar\UI-CastingBar-Spark]]
	f.spark:SetWidth(16)
	f.spark:SetHeight(HEIGHT + 25)
	f.spark:SetBlendMode'ADD'

	f.text = f.statusbar:CreateFontString(nil, 'OVERLAY')
--	f.text:SetFontObject(GameFontHighlightSmallOutline)
	f.text:SetFontObject(GameFontHighlight)
	f.text:SetFont(font, fontsize, style)
	f.text:SetPoint('TOPLEFT', 2, 0)
	f.text:SetPoint('BOTTOMRIGHT', -2, 0)
	f.text:SetJustifyH'LEFT'
	f.text:SetText''

	f.timertext = f.statusbar:CreateFontString(nil, 'OVERLAY')
--	f.text:SetFontObject(GameFontHighlightSmallOutline)
	f.timertext:SetFontObject(GameFontHighlight)
	f.timertext:SetFont(font, fontsize, style)
	f.timertext:SetPoint('TOPLEFT', 2, 0)
	f.timertext:SetPoint('BOTTOMRIGHT', -2, 0)
	f.timertext:SetJustifyH'RIGHT'
	f.timertext:SetText''

	f:EnableMouse(false)
	f:RegisterForClicks()

--	f:SetScript('OnUpdate', function()
--		f:EnableMouse(IsControlKeyDown())
--	end)
--	f:SetScript('OnClick', function()
--		TargetByName(this.TIMER.UNIT, true)
--	end)

	return f
end

local function fade_bar(bar)
	if bar.fadeelapsed > bar.fadetime then
		bar:SetAlpha(0)
	else
		local t = bar.fadetime - bar.fadeelapsed
		local a = t / bar.fadetime
		bar:SetAlpha(a)
	end
end

local function format_time(t)
	local h = floor(t / 3600)
	local m = floor((t - h * 3600) / 60)
	local s = t - (h * 3600 + m * 60)
	if h > 0 then
		return format('%d:%02d:02d', h, m, s)
	elseif m > 0 then
		return format('%d:%02d', m, s)
	elseif s < 10 then
		return format('%.1f', s)
	else
		return format('%.0f', s)
	end
end

function UnlockBars()
	aurae.LOCKED = false
	for _, type in {'CC', 'Buff', 'Debuff'} do
		_G['aurae' .. type]:EnableMouse(1)
		for i = 1, MAXBARS do
			local f = getglobal('auraeBar' .. type .. i)
			f:SetAlpha(1)
			f.statusbar:SetStatusBarColor(1, 1, 1)
			f.statusbar:SetValue(1)
			f.icon:SetTexture[[Interface\Icons\INV_Misc_QuestionMark]]
			f.text:SetText('aurae ' .. type .. ' Bar ' .. i)
			f.timertext:SetText''
			f.spark:Hide()
			-- getglobal(barname.."StatusBarSpark"):SetPoint("CENTER", barname.."StatusBar", "LEFT", 0, 0)
		end
	end
end

function LockBars()
	aurae.LOCKED = true
	auraeCC:EnableMouse(0)
	auraeDebuff:EnableMouse(0)
	auraeBuff:EnableMouse(0)

	for i = 1, MAXBARS do
		getglobal('auraeBarCC' .. i):SetAlpha(0)
		getglobal('auraeBarDebuff' .. i):SetAlpha(0)
		getglobal('auraeBarBuff' .. i):SetAlpha(0)
	end
end

do
	local function tokenize(str)
		local tokens = {}
		for token in string.gfind(str, '%S+') do tinsert(tokens, token) end
		return tokens
	end

	function SlashCommandHandler(msg)
		if msg then
			local args = tokenize(msg)
			local command = strlower(msg)
			if command == "unlock" then
				UnlockBars()
				Print('Bars unlocked.')
			elseif command == "lock" then
				LockBars()
				Print('Bars locked.')
			elseif command == "invert" then
				aurae_settings.invert = not aurae_settings.invert
				aurae_settings.invert = aurae_settings.invert
				if aurae_settings.invert then
					Print('Bar inversion on.')
				else
					Print('Bar inversion off.')
				end
			elseif args[1] == 'color' and (args[2] == 'school' or args[2] == 'progress' or args[2] == 'custom') then
				aurae_settings.color = args[2]
				Print('Color: ' .. args[2])
			elseif args[1] == "customcolor" and tonumber(args[2]) and tonumber(args[3]) and tonumber(args[4]) and args[5] and aurae.EFFECTS[args[5]] then
				local effect = gsub(msg, '%s*%S+%s*', '', 4)
				aurae_settings.colors[effect] = {tonumber(args[2])/255, tonumber(args[3])/255, tonumber(args[4])/255 }
				print('Custom color: ' .. color_code(unpack(aurae_settings.colors[effect])) .. effect .. '|r')
			elseif command == 'clear' then
				aurae_settings = nil
				LoadVariables()
			elseif strsub(command, 1, 5) == "scale" then
				local scale = tonumber(strsub(command, 7))
				if scale then
					scale = max(.25, min(3, scale))
					aurae_settings.scale = scale
					auraeCC:SetScale(scale)
					auraeDebuff:SetScale(scale)
					auraeBuff:SetScale(scale)
					Print('Scale: ' .. scale)
				else
					Usage()
				end
			elseif strsub(command, 1, 5) == "alpha" then
				local alpha = tonumber(strsub(command, 7))
				if alpha then
					alpha = max(0, min(1, alpha))
					aurae_settings.alpha = alpha
					auraeCC:SetAlpha(alpha)
					auraeDebuff:SetAlpha(alpha)
					auraeBuff:SetAlpha(alpha)
					Print('Alpha: ' .. alpha)
				else
					Usage()
				end
			else
				Usage()
			end
		end
	end
end

function Usage()
	Print("Usage:")
	Print("  lock | unlock")
	Print("  invert")
	Print("  alpha [0,1]")
	Print("  color (school | progress | custom)")
	Print("  customcolor [1,255] [1,255] [1,255] <effect>")
end

do
	local gender = {[2]='M', [3]='F'}

	function TargetID()
		local name = UnitName'target'
		if name then
			return UnitIsPlayer'target' and name or '[' .. UnitLevel'target' .. (gender[UnitSex'target'] or '') .. '] ' .. name
		end
	end
end

function SetActionRank(name, rank)
	local _, _, rank = strfind(rank or '', 'Rank (%d+)')
	if rank and _G.aurae_RANKS[name] then
		_G.aurae.EFFECTS[_G.aurae_RANKS[name].EFFECT or name].DURATION = _G.aurae_RANKS[name].DURATION[tonumber(rank)]
	end
end

do
	local casting = {}
	local last_cast
	local pending = {}

	do
		local orig = UseAction
		function _G.UseAction(slot, clicked, onself)
			if HasAction(slot) and not GetActionText(slot) then
				aurae_Tooltip:SetOwner(UIParent, 'ANCHOR_NONE')
				aurae_TooltipTextRight1:SetText()
				aurae_Tooltip:SetAction(slot)
				local name = aurae_TooltipTextLeft1:GetText()
				casting[name] = TargetID()
				SetActionRank(name, aurae_TooltipTextRight1:GetText())
			end
			return orig(slot, clicked, onself)
		end
	end

	do
		local orig = CastSpell
		function _G.CastSpell(index, booktype)
			local name, rank = GetSpellName(index, booktype)
			casting[name] = TargetID()
			SetActionRank(name, rank)
			return orig(index, booktype)
		end
	end

	do
		local orig = CastSpellByName
		function _G.CastSpellByName(text, onself)
			if not onself then
				casting[text] = TargetID()
			end
			return orig(text, onself)
		end
	end

	function CHAT_MSG_SPELL_FAILED_LOCALPLAYER()
		for effect in string.gfind(arg1, 'You fail to %a+ (.*):.*') do
			casting[effect] = nil
		end
	end

	function SPELLCAST_STOP()
		for effect, target in casting do
			if (EffectActive(effect, target) or not IsPlayer(target) and aurae.EFFECTS[effect]) and aurae.EFFECTS[effect].ETYPE ~= ETYPE_BUFF then
				if pending[effect] then
					last_cast = nil
				else
					pending[effect] = {target=target, time=GetTime() + (_G.aurae_RANKS[effect] and _G.aurae_DELAYS[effect] or 0)}
					last_cast = effect
				end
			end
		end
		casting = {}
	end

	CreateFrame'Frame':SetScript('OnUpdate', function()
		for effect, info in pending do
			if GetTime() >= info.time + .5 and (IsPlayer(info.target) or TargetID() ~= info.target or UnitDebuffs'target'[effect]) then
				StartTimer(effect, info.target, info.time)
				pending[effect] = nil
			end
		end
	end)

	function AbortCast(effect, unit)
		for k, v in pending do
			if k == effect and v.target == unit then
				pending[k] = nil
			end
		end
	end

	function AbortUnitCasts(unit)
		for k, v in pending do
			if v.target == unit or not unit and not IsPlayer(v.target) then
				pending[k] = nil
			end
		end
	end

	function SPELLCAST_INTERRUPTED()
		if last_cast then
			pending[last_cast] = nil
		end
	end

	do
		local patterns = {
			'is immune to your (.*)%.',
			'Your (.*) missed',
			'Your (.*) was resisted',
			'Your (.*) was evaded',
			'Your (.*) was dodged',
			'Your (.*) was deflected',
			'Your (.*) is reflected',
			'Your (.*) is parried'
		}
		function CHAT_MSG_SPELL_SELF_DAMAGE()
			for _, pattern in patterns do
				local _, _, effect = strfind(arg1, pattern)
				if effect then
					pending[effect] = nil
					return
				end
			end
		end
	end
end

function CHAT_MSG_SPELL_AURA_GONE_OTHER()
	for effect, unit in string.gfind(arg1, QuickLocalize(AURAREMOVEDOTHER)) do
		AuraGone(unit, effect)
	end
end

function CHAT_MSG_SPELL_BREAK_AURA()
	for unit, effect in string.gfind(arg1, QuickLocalize(AURADISPELOTHER)) do
		AuraGone(unit, effect)
	end
end

function ActivateDRTimer(effect, unit)
	for k, v in DR_CLASS do
		if v == DR_CLASS[effect] and EffectActive(k, unit) then
			return
		end
	end
	local timer = timers[DR_CLASS[effect] .. '@' .. unit]
	if timer then
		timer.START = GetTime()
		timer.END = timer.START + 15
	end
end

function AuraGone(unit, effect)
	if aurae.EFFECTS[effect] then
		if IsPlayer(unit) then
			AbortCast(effect, unit)
			StopTimer(effect .. '@' .. unit)
			if DR_CLASS[effect] then
				ActivateDRTimer(effect, unit)
			end
		elseif unit == UnitName'target' then
			-- TODO pet target (in other places too)
			local unit = TargetID()
			local debuffs = UnitDebuffs'target'
			for k, timer in timers do
				if timer.UNIT == unit and not debuffs[timer.EFFECT] then
					StopTimer(timer.EFFECT .. '@' .. timer.UNIT)
				end
			end
		end
	end
end

function CHAT_MSG_COMBAT_HOSTILE_DEATH()
	for unit in string.gfind(arg1, '(.+) dies') do -- TODO does not work when xp is gained
		if IsPlayer(unit) then
			UnitDied(unit)
		elseif unit == UnitName'target' and UnitIsDead'target' then
			UnitDied(TargetID())
		end
	end
end

function CHAT_MSG_COMBAT_HONOR_GAIN()
	for unit in string.gfind(arg1, '(.+) dies') do
		UnitDied(unit)
	end
end

function UNIT_COMBAT()
	if GetComboPoints() > 0 then
		aurae.COMBO = GetComboPoints()
	end
end

function color_code(r, g, b)
	return format('|cFF%02X%02X%02X', r*255, g*255, b*255)
end

timers = {}

local function place_timers()
	for _, timer in timers do
		if timer.shown and not timer.visible then
			local group
			if aurae.EFFECTS[timer.EFFECT].ETYPE == ETYPE_BUFF then
				group = aurae.GROUPSBUFF
			elseif aurae.EFFECTS[timer.EFFECT].ETYPE == ETYPE_DEBUFF then
				group = aurae.GROUPSDEBUFF
			else
				group = aurae.GROUPSCC
			end
			for i = 1, MAXBARS do
				if group[i].TIMER.stopped then
					group[i].TIMER = timer
					timer.visible = true
					break
				end
			end
		end
	end
end

function UpdateTimers()
	local t = GetTime()
	for k, timer in timers do
		if timer.END and t > timer.END then
			StopTimer(k)
			if DR_CLASS[timer.EFFECT] and not timer.DR then
				ActivateDRTimer(timer.EFFECT, timer.UNIT)
			end
		end
	end
end

function EffectActive(effect, unit)
	return timers[effect .. '@' .. unit] and true or false
end

function StartTimer(effect, unit, start)
	local key = effect .. '@' .. unit
	local timer = timers[key] or {}
	timers[key] = timer

	timer.EFFECT = effect
	timer.UNIT = unit
	timer.START = start
	timer.shown = IsShown(unit)
	timer.END = timer.START

	local duration = aurae.EFFECTS[effect].DURATION + (bonuses[effect] and bonuses[effect](aurae.EFFECTS[effect].DURATION) or 0)

	if IsPlayer(unit) then
		timer.END = timer.END + DiminishedDuration(unit, effect, aurae.EFFECTS[effect].PVP_DURATION or duration)
	else
		timer.END = timer.END + duration
	end

	if aurae.EFFECTS[effect].COMBO then
		timer.END = timer.END + aurae.EFFECTS[effect].A * aurae.COMBO
	end

	timer.stopped = nil
	place_timers()
end

function StartDR(effect, unit)

	local key = DR_CLASS[effect] .. '@' .. unit
	local timer = timers[key] or {}

	if not timer.DR or timer.DR < 3 then
		timers[key] = timer

		timer.EFFECT = effect
		timer.UNIT = unit
		timer.START = nil
		timer.END = nil
		timer.shown = timer.shown or IsShown(unit)
		timer.DR = min(3, (timer.DR or 0) + 1)

		place_timers()
	end
end

function PLAYER_REGEN_ENABLED()
	AbortUnitCasts()
	for k, timer in timers do
		if not IsPlayer(timer.UNIT) then
			StopTimer(k)
		end
	end
end

function StopTimer(key)
	if timers[key] then
		timers[key].stopped = GetTime()
		timers[key] = nil
		place_timers()
	end
end

function UnitDied(unit)
	AbortUnitCasts(unit)
	for k, timer in timers do
		if timer.UNIT == unit then
			StopTimer(k)
		end
	end
	place_timers()
end

do
	local f = CreateFrame'Frame'
	local player, current, recent = {}, {}, {}

	local function hostile_player(msg)
		local _, _, name = strfind(arg1, "^([^%s']*)")
		return name
	end

	local function add_recent(unit)
		local t = GetTime()

		recent[unit] = t

		for k, v in recent do
			if t - v > 30 then
				recent[k] = nil
			end
		end

		for _, timer in timers do
			if timer.UNIT == unit then
				timer.shown = true
			end
		end
		place_timers()
	end

	local function unit_changed(unitID)
		local unit = UnitName(unitID)
		if unit then
			player[unit] = UnitIsPlayer(unitID) and true or false

			if player[unit] then
				add_recent(unit)
			end
			if player[current[unitID]] and current[unitID] then
				add_recent(current[unitID])
			end
			current[unitID] = unit
		end
	end

	for _, event in {
		'CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS',
		'CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES',
		'CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE',
		'CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE',
		'CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF',
		'CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS',
	} do f:RegisterEvent(event) end

	f:SetScript('OnEvent', function()
		if strfind(arg1, '. You ') or strfind(arg1, ' you') then
			add_recent(hostile_player(arg1)) -- TODO make sure this happens before the other handlers
		end
	end)

	f:SetScript('OnUpdate', function()
		RequestBattlefieldScoreData()
	end)

	function CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS()
		if player[hostile_player(arg1)] == nil then player[hostile_player(arg1)] = true end -- wrong for pets
		for unit, effect in string.gfind(arg1, QuickLocalize(AURAADDEDOTHERHELPFUL)) do
			if IsPlayer(unit) and aurae.EFFECTS[effect] then
				StartTimer(effect, unit, GetTime())
			end
		end
	end

	function CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE()
		if player[hostile_player(arg1)] == nil then player[hostile_player(arg1)] = true end -- wrong for pets
		for unit, effect in string.gfind(arg1, QuickLocalize(AURAADDEDOTHERHARMFUL)) do
			if IsPlayer(unit) and aurae.EFFECTS[effect] then
				StartTimer(effect, unit, GetTime())
			end
		end
	end

	function PLAYER_TARGET_CHANGED()
		unit_changed'target'
	end

	function UPDATE_MOUSEOVER_UNIT()
		unit_changed'mouseover'
	end

	function UPDATE_BATTLEFIELD_SCORE()
		for i = 1, GetNumBattlefieldScores() do
			player[GetBattlefieldScore(i)] = true
		end
	end

	function IsShown(unit)
		return not player[unit]
				or UnitName'target' == unit
				or UnitName'mouseover' == unit
				or recent[unit] and GetTime() - recent[unit] <= 30
	end

	function IsPlayer(unit)
		return player[unit]
	end
end

function UPDATE()
	UpdateTimers()
	if not aurae.LOCKED then
		return
	end
	UpdateBars()
end

function UpdateBars()
	for _, group in {aurae.GROUPSBUFF, aurae.GROUPSDEBUFF, aurae.GROUPSCC} do
		for _, bar in group do
			UpdateBar(bar)
		end
	end
end

do
	local dr_prefix = {
		color_code(1, 1, 0) .. 'DR: ½|r - ',
		color_code(1, .5, 0) .. 'DR: ¼|r - ',
		color_code(1, 0, 0) .. 'DR: 0|r - ',
	}
	function UpdateBar(bar)
		if not aurae.LOCKED then
			return
		end

		local timer = bar.TIMER

		if timer.stopped then
			if bar:GetAlpha() > 0 then
				bar.spark:Hide()
				bar.fadeelapsed = GetTime() - timer.stopped
				fade_bar(bar)
			end
		else
			bar:SetAlpha(1)
			bar.icon:SetTexture([[Interface\Icons\]] .. (aurae.EFFECTS[timer.EFFECT].ICON or 'INV_Misc_QuestionMark'))
			bar.text:SetText((timer.DR and dr_prefix[timer.DR] or '') .. timer.UNIT)

			if timer.START then
				local duration = timer.END - timer.START
				local remaining = timer.END - GetTime()
				local fraction = remaining / duration

				bar.statusbar:SetValue(aurae_settings.invert and 1 - fraction or fraction)

				local sparkPosition = WIDTH * fraction
				bar.spark:Show()
				bar.spark:SetPoint('CENTER', bar.statusbar, aurae_settings.invert and 'RIGHT' or 'LEFT', aurae_settings.invert and -sparkPosition or sparkPosition, 0)

				bar.timertext:SetText(format_time(remaining))

				local r, g, b
				if aurae_settings.color == 'school' then
					r, g, b = unpack(aurae.EFFECTS[timer.EFFECT].SCHOOL or {1, 0, 1})
				elseif aurae_settings.color == 'progress' then
					r, g, b = 1 - fraction, fraction, 0
				elseif aurae_settings.color == 'custom' then
					if aurae_settings.colors[timer.EFFECT] then
						r, g, b = unpack(aurae_settings.colors[timer.EFFECT])
					else
						r, g, b = 1, 1, 1
					end
				end
				bar.statusbar:SetStatusBarColor(r, g, b)
				bar.statusbar:SetBackdropColor(r, g, b, .3)
			else
				bar.statusbar:SetValue(1)
				bar.spark:Hide()
				bar.timertext:SetText('')

				local r, g, b
				if aurae_settings.color == 'school' then
					r, g, b = unpack(aurae.EFFECTS[timer.EFFECT].SCHOOL or {1, 0, 1})
				elseif aurae_settings.color == 'progress' then
					r, g, b = 0, 1, 0
				elseif aurae_settings.color == 'custom' then
					if aurae_settings.colors[timer.EFFECT] then
						r, g, b = unpack(aurae_settings.colors[timer.EFFECT])
					else
						r, g, b = 1, 1, 1
					end
				end
				bar.statusbar:SetStatusBarColor(r, g, b)
				bar.statusbar:SetBackdropColor(r, g, b, .3)
			end
		end
	end
end

do
	local default_settings = {
		colors = {},
		invert = false,
		color = 'school',
		scale = 1,
		alpha = 1,
		arcanist = false,
	}

	function ADDON_LOADED()
		if arg1 ~= 'aurae' then return end

		local dummy_timer = {stopped=0}
		for i, etype in {'Debuff', 'CC', 'Buff'} do
			local height = HEIGHT * MAXBARS + 4 * (MAXBARS - 1)
			local f = CreateFrame('Frame', 'aurae' .. etype, UIParent)
			f:SetWidth(WIDTH + HEIGHT)
			f:SetHeight(height)
			f:SetMovable(true)
			f:SetUserPlaced(true)
			f:SetClampedToScreen(true)
			f:RegisterForDrag('LeftButton')
			f:SetScript('OnDragStart', function()
				this:StartMoving()
			end)
			f:SetScript('OnDragStop', function()
				this:StopMovingOrSizing()
			end)
			f:SetPoint('CENTER', -210 + (i - 1) * 210, 150)
			for i = 1, MAXBARS do
				local bar = create_bar()
				bar:SetParent(getglobal('aurae' .. etype))
				local offset = 20 * (i - 1)
				bar:SetPoint('BOTTOMLEFT', 0, offset)
				bar:SetPoint('BOTTOMRIGHT', 0, offset)
				_G['auraeBar' .. etype .. i] = bar
				bar.TIMER = dummy_timer
				tinsert(aurae['GROUPS' .. strupper(etype)], bar)
			end
		end

		for _, event in {
			'UNIT_COMBAT',
			'CHAT_MSG_COMBAT_HONOR_GAIN', 'CHAT_MSG_COMBAT_HOSTILE_DEATH', 'PLAYER_REGEN_ENABLED',
			'CHAT_MSG_SPELL_AURA_GONE_OTHER', 'CHAT_MSG_SPELL_BREAK_AURA',
			'CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE', 'CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS',
			'SPELLCAST_STOP', 'SPELLCAST_INTERRUPTED', 'CHAT_MSG_SPELL_SELF_DAMAGE', 'CHAT_MSG_SPELL_FAILED_LOCALPLAYER',
			'PLAYER_TARGET_CHANGED', 'UPDATE_MOUSEOVER_UNIT', 'UPDATE_BATTLEFIELD_SCORE',
		} do _F:RegisterEvent(event) end

		for k, v in default_settings do
			if aurae_settings[k] == nil then
				aurae_settings[k] = v
			end
		end

		auraeCC:SetScale(aurae_settings.scale)
		auraeDebuff:SetScale(aurae_settings.scale)
		auraeBuff:SetScale(aurae_settings.scale)

		auraeCC:SetAlpha(aurae_settings.alpha)
		auraeDebuff:SetAlpha(aurae_settings.alpha)
		auraeBuff:SetAlpha(aurae_settings.alpha)

		_G.SLASH_AURAE1 = '/aurae'
		SlashCmdList.AURAE = SlashCommandHandler

		LockBars()
	end

	Print('aurae loaded - /aurae')
end

do
	local function rank(i, j)
		local _, _, _, _, rank = GetTalentInfo(i, j)
		return rank
	end

	local _, class = UnitClass'player'
	if class == 'ROGUE' then
		bonuses = {
			["Gouge"] = function()
				return rank(2, 1) * .5
			end,
			["Garrote"] = function()
				return rank(3, 8) * 3
			end,
		}
	elseif class == "WARLOCK" then
		bonuses = {
			["Shadow Word: Pain"] = function()
				return rank(2, 7) * 1.5
			end,
		}
	elseif class == 'HUNTER' then
		bonuses = {
			["Freezing Trap Effect"] = function(t)
				return t * rank(3, 7) * .15
			end,
		}
	elseif class == 'PRIEST' then
		bonuses = {
			["Shadow Word: Pain"] = function()
				return rank(3, 4) * 3
			end,
		}
	elseif class == 'MAGE' then
		bonuses = {
			["Cone of Cold"] = function()
				return min(1, rank(3, 2)) * .5 + rank(3, 2) * .5
			end,
			["Frostbolt"] = function()
				return min(1, rank(3, 2)) * .5 + rank(3, 2) * .5
			end,
			["Polymorph"] = function()
				if aurae_settings.arcanist then
					return 15
				end
			end,
		}
	elseif class == 'DRUID' then
		bonuses = {
			["Pounce"] = function()
				return rank(2, 4) * .5
			end,
			["Bash"] = function()
				return rank(2, 4) * .5
			end,
		}
	else
		bonuses = {}
	end
end