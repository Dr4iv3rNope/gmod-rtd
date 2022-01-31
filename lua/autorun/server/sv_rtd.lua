rtd = {}
rtd.effects = {}

rtd.current_ply = nil
rtd.currect_effect = nil
rtd.next_effects = {}

-- @id is table key name. Must be unique
-- @data - is information about hook. Here is data structure:
--[[
{
	duration: number or table - can be nil if you want to call it ONCE
		if table then it will have structure:
			{
				min: number - min effect duration
				max: number - max effect duration
			}

	format: string - message that will be printed when player is roll the dice
		formats:
			%rtd - player nickname who rtd
			%time - effect duration. NEVER WILL BE FORMATED IF ^duration IS NOT A TABLE

	on_first: function(ply, duration) - called when it's first effect run time. can be nil.
		if ^duration is nil, it will be NEVER CALLED
		@ply - who rtd
		@duration - it's ^duration

	on_end: function(ply, duration, start_time) - called when it's last effect run time. can be nil.
		if ^duration is nil, it will be NEVER CALLED
		@ply - who rtd
		@duration - it's ^duration
		@start_time - CurTime() when effect has been rolled

	callback: function(ply, duration, start_time) - called every tick. can be nil.
		if ^duration is nil, it will be CALLED ONCE
		return true if you want to stop effect
		@ply - who rtd
		@duration - it's ^duration.
			if ^duration is nil, then this WILL BE NIL
		@start_time - CurTime() when effect has been rolled.
			if ^duration is nil, then this WILL BE NIL

	hooks: table - hooks that can be used for effect. can be nil
		structure:
			["PlayerSpawn"] = function(...) ... end
}
]]
rtd.registerEffectEx = function(id, data)
	rtd.assert(istable(data), "@data must be a table")
	rtd.assert(isstring(id), "@id must be a string")

	rtd.assert(isfunction(data.callback) or isfunction(data.on_first) or isfunction(data.on_end) or (istable(data.hooks) and next(data.hooks) ~= nil), "no callbacks are set! dummy effect!")

	rtd.assert(isstring(data.format), "^data.format must be a string")

	rtd.assert(data.duration == nil or isnumber(data.duration) or istable(data.duration), "^data.duration must be a nil or number or table")
	rtd.assert(not istable(data.duration) or (isnumber(data.duration.min) and isnumber(data.duration.max)), "^data.duration has wrong table")

	if data.callback == nil then data.callback = function() end end
	rtd.assert(isfunction(data.callback), "@callback must be a function")

	if data.on_first == nil then data.on_first = function() end end
	rtd.assert(isfunction(data.on_first), "@onfirst must be a function")

	if data.on_end == nil then data.on_end = function() end end
	rtd.assert(isfunction(data.on_end), "@onend must be a function")

	if data.hooks == nil then data.hooks = {} end
	for k, v in pairs(data.hooks) do
		rtd.assert(isstring(k), "keys in @hooks must be a string")
		rtd.assert(isfunction(v), "expected function in @hooks table (key "..k..")")
		rtd.assert(rtd.isHookRegistered(k), "you forgot to register hook "..k)
	end

	rtd.assert(rtd.effects[id] == nil, "effect with id "..id.." is already registered")

	rtd.info("Registering effect "..id)

	data.id = id
	rtd.effects[id] = data
end

-- see rtd.registerEffectEx
--
-- @name is friendly in-chat effect description
rtd.registerEffect = function(id, name, data)
	data.format = "%rtd "..name

	if istable(data.duration) then
		data.format = data.format.." в течении %time секунд."
	end

	rtd.registerEffectEx(id, data)
end

-- set user user data for current effect
-- function will error if no current rtd is in action
rtd.setUserData = function(data_name, any)
	rtd.assert(isstring(data_name), "@data_name must be a string")
	rtd.assert(any ~= nil, "@any can't be a nil")

	rtd.getCurrentEffect().user_data[data_name] = any
end

-- get custom user data for current effect
--
-- function will error if no current rtd is in action or
-- no data has been set (nil)
rtd.getUserData = function(data_name)
	rtd.assert(isstring(data_name), "@data_name must be a string")
	rtd.assert(istable(rtd.getCurrentEffect().user_data), "to devs: you CANT use userdata for functions that called ONCE")

	rtd.assert(rtd.getCurrentEffect().user_data[data_name] ~= nil, "user data ("..data_name..") of the effect is not set!")

	return rtd.getCurrentEffect().user_data[data_name]
end

-- return current rtd player
-- function will error if no current rtd is in action
rtd.getCurrentPlayer = function()
	rtd.assert(rtd.current_ply ~= nil, "no current rtd is in action")

	return rtd.current_ply
end

-- return current rtd effect
-- function will error if no current rtd is in action
rtd.getCurrentEffect = function()
	rtd.assert(rtd.current_effect ~= nil, "no current rtd is in action")

	return rtd.current_effect
end

rtd.printAll = function(msg)
	PrintMessage(HUD_PRINTTALK, "[RTD] "..msg)
end

rtd.debug = function(...)
	MsgC(Color(255, 255, 0), "[RTD] ", ...)
	MsgN("")
end

rtd.info = function(...)
	rtd.debug(Color(155, 155, 155), "[Info] ", color_white, ...)
end

rtd.warning = function(...)
	rtd.debug(Color(255, 155, 20), "[Warning] ", Color(255, 180, 100), ...)
end

rtd.critical = function(...)
	rtd.debug(Color(255, 55, 55), "[Critical Error] ", Color(255, 120, 120), ...)

	rtd.current_ply = nil
	rtd.currect_effect = nil

	Error(...)
end

rtd.assert = function(any, ...)
	if not any then
		rtd.critical("Assertation Fault: ", Color(255, 0, 0), ...)
	end
end

local USER_HOOK_NAME = "[user] roll the dice"

-- return true if @event already hooked
rtd.isHookRegistered = function(event)
	local callbacks = hook.GetTable()[event]

	return callbacks ~= nil and callbacks[USER_HOOK_NAME] ~= nil
end

-- registers new hook
-- if hook already registered, it will print warning message
rtd.registerHook = function(event, verify_fn)
	rtd.assert(isstring(event), "@event must be a string")
	if verify_fn == nil then verify_fn = function() return true end end
	rtd.assert(isfunction(verify_fn), "@verify_fn must be a function")

	if rtd.isHookRegistered(event) then
		rtd.warning("Hook ", event, " already exist. Hook will be overrided!")
	end

	rtd.info("Created hook ", event, " with name \"" .. USER_HOOK_NAME .. "\"")

	hook.Add(event, USER_HOOK_NAME, function(...)
		for i,v in ipairs(rtd.next_effects) do
			if IsValid(v.ply) then
				if v.ply:Alive() then
					if v.end_time >= CurTime() then
						rtd.current_effect = v
						rtd.current_ply = v.ply

						local verified

						local success, err = pcall(function(...)
							verified = verify_fn(v.ply, ...)
						end, ...)

						if not success then
							rtd.critical("error while verifying " .. event .. ": " .. err)
						end

						verified = verified or false

						if verified and isfunction(v.effect.hooks[event]) then
							local success, err = pcall(function(...)
								v.effect.hooks[event](...)
							end, ...)

							if not success then
								rtd.critical("error while executing " .. event .. ": " .. err)
							end
						end

						rtd.current_effect = nil
						rtd.current_ply = nil
					end
				end
			end
		end
	end)
end

--
-- rtd process
--

rtd.rollEffect = function(ply, effect)
	rtd.assert(isentity(ply) and ply:IsPlayer(), "@ply must be a player")
	rtd.assert(istable(effect), "@effect must be a table")

	if ply.isInRTD then
		rtd.warning(ply, " is already in RTD")
		return false
	end

	local effect_time = nil

	if istable(effect.duration) then
		effect_time = math.random(effect.duration.min, effect.duration.max)
	elseif isnumber(effect.duration) then
		effect_time = effect.duration
	end

	rtd.info(ply, " rolled effect ", effect.id, " with time ", effect_time)

	local formated_msg = effect.format
	formated_msg = string.Replace(formated_msg, "%rtd", ply:Nick())

	if effect_time ~= nil then
		local sv_effect =
		{
			effect = effect,
			ply = ply,
			start_time = CurTime(),
			end_time = CurTime() + effect_time,
			forse_stop = false,
			user_data = {}
		}

		table.insert(rtd.next_effects, sv_effect)

		rtd.current_ply = ply
		rtd.current_effect = sv_effect

		formated_msg = string.Replace(formated_msg, "%time", effect_time)

		ply.isInRTD = true

		local success, err = pcall(effect.on_first, ply)

		if not success then
			rtd.critical("error while executing on_first: " .. err)
		end
	else
		-- setting up dummy sv_effect

		local dummy_effect =
		{
			effect = effect,
			ply = ply
		}

		rtd.current_effect = dummy_effect
		rtd.current_ply = ply

		local success, err = pcall(effect.callback, ply)

		if not success then
			rtd.critical("error while executing callback: " .. err)
		end
	end

	rtd.current_effect = nil
	rtd.current_ply = nil

	rtd.printAll(formated_msg)
	return true
end

rtd.rollRandomEffect = function(ply)
	rtd.rollEffect(ply, table.Random(rtd.effects))
end

hook.Add("Tick", "roll the dice", function()
	local removed = 0

	local function removeEffect(i)
		table.remove(rtd.next_effects, i - removed)
		removed = removed + 1
	end

	for i,v in ipairs(rtd.next_effects) do
		if not IsValid(v.ply) then return removeEffect(i) end

		rtd.current_effect = v
		rtd.current_ply = v.ply

		::retry_process_effect::

		if v.force_stop or not v.ply:Alive() or CurTime() > v.end_time then
			local success, err = pcall(v.effect.on_end, v.ply, v.start_time)

			if not success then
				rtd.critical("error while executing on_end: " .. err)
			end

			removeEffect(i)

			if not v.ply:Alive() then
				rtd.printAll(v.ply:Nick().." умер во время эффекта!")
			else
				rtd.printAll(v.ply:Nick().." эффект закончен.")
			end

			rtd.info(v.ply, " effect ", v.effect.id, " is end")
			v.ply.isInRTD = false
		else
			local success, result = xpcall(v.effect.callback, function(err)
				rtd.critical("error while callback effect: " .. err)
			end, v.ply, v.end_time - v.start_time, v.start_time)

			if
				not success or
				result == true
			then
				v.force_stop = true
				goto retry_process_effect
			end
		end

		rtd.current_effect = nil
		rtd.current_ply = nil
	end
end)

--
-- helpers
--
local function createExplosion(pos, owner, dmg, rad)
	rtd.assert(isvector(pos), "@pos must be a vector")
	rtd.assert(owner == nil or isentity(owner), "@owner must be a entity")
	rtd.assert(isnumber(dmg), "@dmg must be a number")
	rtd.assert(isnumber(rad), "@rad must be a number")

	local explosion = ents.Create"env_explosion"
	explosion:SetPos(pos)
	explosion:SetOwner(owner)
	explosion:Spawn()
	explosion:SetKeyValue("iMagnitude", dmg)
	explosion:SetKeyValue("iRadiusOverride", rad)
	explosion:Fire"Explode"
end

local function createGrenade(pos, owner, timeout)
	local gr = ents.Create"npc_grenade_frag"
	gr:SetPos(pos)
	gr:SetOwner(owner)
	gr:Spawn()
	gr:Activate()

	gr:Fire("SetTimer", timeout)

	return gr
end

local function getClosestPlayer(ent)
	local best_tar = nil
	local best_dis = math.huge - 1

	for k,v in ipairs(player.GetAll()) do
		if v ~= ent then
			if v:Alive() then
				local dis = ent:GetPos():Distance(v:GetPos())

				if dis < best_dis then
					best_tar = v
					best_dis = dis
				end
			end
		end
	end

	return best_tar
end

--
-- registering effects
--

rtd.registerEffect("kill", "выпилился",
{
	callback = function(ply)
		ply:Kill()
	end
})

rtd.registerEffect("explode", "взорвался",
{
	callback = function(ply)
		createExplosion(ply:GetPos(), ply, math.random(100, 200), 200)

		ply:Kill()
	end
})

rtd.registerEffect("no_gravity", "стал космонавтом",
{
	duration = { min = 5, max = 20 },

	callback = function(ply)
		ply:SetVelocity(Vector(0, 0, 100))
	end
})

rtd.registerEffect("drunk", "опьянел",
{
	duration = { min = 5, max = 30 },

	callback = function(ply)
		local randang = Angle(math.Rand(-10, 10), math.Rand(-10, 10), math.Rand(-10, 10))

		ply:ViewPunch(randang)
		ply:ScreenFade(SCREENFADE.PURGE, Color(math.random(0, 255), math.random(0, 255), math.random(0, 255), 100), 0.1, 0.1)
	end
})

rtd.registerEffect("rocket", "стал ракетой",
{
	duration = 0.2,

	callback = function(ply)
		ply:SetVelocity(Vector(0, 0, 10000))
	end,

	on_end = function(ply)
		createExplosion(ply:GetPos(), ply, math.random(100, 2000), 200)
	end
})

rtd.registerHook("EntityTakeDamage")
rtd.registerEffect("insta_kill", "теперь убивает всех с одного выстрела",
{
	duration = { min = 15, max = 30 },

	hooks =
	{
		["EntityTakeDamage"] = function(ent, dmg)
			if dmg:GetAttacker() == rtd.getCurrentPlayer() then
				dmg:ScaleDamage(9999)
			end
		end
	}
})

rtd.registerHook("EntityFireBullets", function(rtd, ply, bullet)
	return rtd == ply
end)

rtd.registerEffect("explosive_bullets", "получил взрывчатые пули",
{
	duration = { min = 10, max = 30 },

	on_first = function()
		rtd.setUserData("ignore_next_bullet", false)
	end,

	hooks =
	{
		["EntityFireBullets"] = function(ply, bullet)
			if rtd.getUserData"ignore_next_bullet" then
				rtd.setUserData("ignore_next_bullet", false)

				return
			end

			rtd.setUserData("ignore_next_bullet", true)

			local oldcallback = bullet.Callback
			bullet.Callback = function(attacker, tr, dmg)
				createExplosion(tr.HitPos, attacker, math.random(10, 100), 200)

				if oldcallback ~= nil then
					oldcallback(attacker, tr, dmg)
				end
			end

			ply:FireBullets(bullet)

			return false
		end
	}
})

rtd.registerEffect("overheal", "получил сверх лечение",
{
	duration = 15,

	callback = function(ply)
		if ply:Health() - 5 <= ply:GetMaxHealth() then
			ply:SetHealth(ply:GetMaxHealth())
			return true
		end

		ply:SetHealth(ply:Health() - 5)
	end,

	on_first = function(ply)
		ply:SetHealth(10000)
	end
})

rtd.registerEffect("godmode", "получает режим бога",
{
	duration = { min = 10, max = 30 },

	hooks =
	{
		["EntityTakeDamage"] = function(ent, dmg)
			if ent == rtd.getCurrentPlayer() then
				dmg:SetDamage(0)
			end
		end
	}
})

-- TODO: toxic effect

rtd.registerEffect("fast_speed", "получает супер скорость",
{
	duration = { min = 10, max = 30 },

	on_first = function(ply)
		rtd.setUserData("slow_walk_speed", ply:GetSlowWalkSpeed())
		rtd.setUserData("walk_speed", ply:GetWalkSpeed())
		rtd.setUserData("run_speed", ply:GetRunSpeed())

		ply:SetSlowWalkSpeed(10000)
		ply:SetWalkSpeed(10000)
		ply:SetRunSpeed(10000)
	end,

	on_end = function(ply)
		ply:SetSlowWalkSpeed(rtd.getUserData("slow_walk_speed"))
		ply:SetWalkSpeed(rtd.getUserData("walk_speed"))
		ply:SetRunSpeed(rtd.getUserData("run_speed"))
	end
})

rtd.registerEffect("noclip", "получает noclip",
{
	duration = { min = 10, max = 30 },

	on_first = function(ply)
		rtd.setUserData("old_move_type", ply:GetMoveType())

		ply:SetMoveType(MOVETYPE_NOCLIP)
	end,

	on_end = function(ply)
		ply:SetMoveType(rtd.getUserData"old_move_type")
	end
})

rtd.registerEffect("invisibility", "становится невидимым",
{
	duration = { min = 10, max = 30 },

	on_first = function(ply)
		rtd.setUserData("old_rt", ply:GetRenderMode())
		rtd.setUserData("old_color", ply:GetColor())

		ply:SetRenderMode(RENDERMODE_TRANSCOLOR)
		ply:SetColor(Color(0, 0, 0, 0))
	end,

	on_end = function(ply)
		ply:SetRenderMode(rtd.getUserData"old_rt")
		ply:SetColor(rtd.getUserData"old_color")
	end
})

rtd.registerEffect("snail", "стал улиткой",
{
	duration = { min = 10, max = 30 },

	on_first = function(ply)
		rtd.setUserData("slow_walk_speed", ply:GetSlowWalkSpeed())
		rtd.setUserData("walk_speed", ply:GetWalkSpeed())
		rtd.setUserData("run_speed", ply:GetRunSpeed())

		ply:SetSlowWalkSpeed(50)
		ply:SetWalkSpeed(50)
		ply:SetRunSpeed(50)
	end,

	on_end = function(ply)
		ply:SetSlowWalkSpeed(rtd.getUserData("slow_walk_speed"))
		ply:SetWalkSpeed(rtd.getUserData("walk_speed"))
		ply:SetRunSpeed(rtd.getUserData("run_speed"))
	end
})

rtd.registerEffect("freeze", "заморожен",
{
	duration = { min = 10, max = 30 },

	on_first = function(ply)
		ply:Freeze(true)
	end,

	on_end = function(ply)
		ply:Freeze(false)
	end
})

rtd.registerEffect("swep_strip", "потерял оружия",
{
	callback = function(ply)
		ply:StripWeapons()
	end
})

rtd.registerEffect("funny_feeling", "ощущает себя странно",
{
	duration = { min = 5, max = 30 },

	callback = function(ply)
		ply:SetFOV(179)
	end,

	on_first = function(ply)
		rtd.setUserData("fov", ply:GetFOV())
	end,

	on_end = function(ply)
		ply:SetFOV(rtd.getUserData"fov")
	end
})

rtd.registerEffect("earthquake", "попал в зону землетрясения",
{
	duration = { min = 5, max = 20 },

	callback = function(ply)
		util.ScreenShake(ply:GetPos(), 10000, 10000, 1, 500)
	end
})

rtd.registerHook("StartCommand", function(rtd, ply)
	return rtd == ply
end)

rtd.registerEffect("aimbot", "включил аимбот",
{
	duration = { min = 10, max = 20 },

	hooks =
	{
		["StartCommand"] = function(ply, cmd)
			local best_tar = getClosestPlayer(ply)

			if best_tar then
				local head = best_tar:GetBonePosition(best_tar:LookupBone"ValveBiped.Bip01_Head1")
				local angle = (head - ply:GetShootPos()):Angle()

				ply:SetEyeAngles(angle)
				cmd:SetViewAngles(angle)
			end
		end
	}
})

rtd.registerEffect("no_friction", "на льду",
{
	duration = { min = 10, max = 30 },

	callback = function(ply)
		local vel = ply:GetVelocity()
		vel.z = -100

		ply:SetVelocity(vel)
	end
})

rtd.registerEffect("upside_down", "перевернулся",
{
	duration = { min = 5, max = 20 },

	on_end = function(ply)
		local angles = ply:EyeAngles()
		angles.r = 0

		ply:SetEyeAngles(angles)
	end,

	hooks =
	{
		["StartCommand"] = function(ply, cmd)
			local angles = cmd:GetViewAngles()
			angles.r = 180

			cmd:SetViewAngles(angles)
			ply:SetEyeAngles(angles)
		end
	}
})

rtd.registerEffect("im_scary", "стал страшным",
{
	duration = { min = 10, max = 20 },

	callback = function(ply)
		for k, v in ipairs(player.GetAll()) do
			if v ~= ply then
				if v:GetEyeTrace().Entity == ply then
					v:ConCommand("say \"страшно...\"")

					v:SetEyeAngles(v:EyeAngles() + Angle(math.Rand(-10, 10), math.Rand(-10, 10), 0))
					v:EmitSound("vo/npc/female01/pain0"..math.random(1, 9)..".wav")
					v:ScreenFade(SCREENFADE.MODULATE, color_black, 0.5, 2)
				end
			end
		end
	end
})

rtd.registerEffect("car_crush", "сбила машина",
{
	duration = 5,

	callback = function(ply)
		local car = rtd.getUserData"car"
		if not isentity(car) then return true end

		local phys = car:GetPhysicsObject()
		if not phys then return true end

		phys:SetVelocity((ply:GetPos() - car:GetPos()) * 10)
	end,

	on_first = function(ply)
		local normal = ply:GetEyeTrace().Normal
		normal.z = 0

		local car = ents.Create"prop_physics"
		car:SetModel"models/props_vehicles/car005a_physics.mdl"
		car:SetPos(ply:GetPos() + Vector(0, 0, 100) + normal * 2000)
		car:SetAngles(ply:EyeAngles() - Angle(0, 180, 0))
		car:Spawn()

		car:EmitSound"vehicles/v8/skid_highfriction.wav"
		ply:EmitSound"vo/npc/male01/no02.wav"

		rtd.setUserData("car", car)
	end,

	on_end = function()
		local car = rtd.getUserData"car"

		if not IsValid(car) then return end

		local wheels =
		{
			"models/props_vehicles/carparts_wheel01a.mdl",
			"models/props_vehicles/carparts_tire01a.mdl"
		}

		local dest_cars =
		{
			"models/props_vehicles/car001b_hatchback.mdl",
			"models/props_vehicles/car004b_physics.mdl",
			"models/props_vehicles/car005b_physics.mdl"
		}

		for i = 1, math.random(2, 4) do
			local wheel = ents.Create"prop_physics"
			wheel:SetModel(table.Random(wheels))
			wheel:SetPos(car:GetPos())
			wheel:SetAngles(car:GetAngles() + Angle(0, math.Rand(-45, 45), 0))
			wheel:Spawn()
			wheel:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			wheel:Ignite(12, 100)

			local phys = car:GetPhysicsObject()
			if phys then
				phys:SetVelocity(car:GetVelocity())
			end

			timer.Simple(12, function()
				if IsValid(wheel) then
					wheel:Remove()
				end
			end)
		end

		car:SetModel(table.Random(dest_cars))
		car:SetMaterial"models/props_foliage/tree_deciduous_01a_trunk"
		car:Ignite(10, 200)
		createExplosion(car:GetPos(), car, 1000, 300)

		timer.Simple(10, function()
			if IsValid(car) then
				createExplosion(car:GetPos(), car, 2000, 500)
				car:Remove()
			end
		end)
	end
})

rtd.registerEffect("on_fire", "загорелся",
{
	duration = { min = 1, max = 10 },

	callback = function(ply)
		ply:Ignite(1, 100)
	end
})

rtd.registerEffect("time_bomb", "стал бомбой",
{
	duration = { min = 5, max = 10 },

	callback = function(ply, dur, start)
		local max_freq = math.Round(dur)
		local freq = (1 + max_freq - math.Round(CurTime() - start)) * 4

		if (engine.TickCount() % freq) == 0 then
			ply:EmitSound"buttons/button17.wav"
		end
	end,

	on_end = function(ply)
		createExplosion(ply:GetPos(), ply, 1000, 300)
	end
})

rtd.registerEffect("cursed", "забыл как ходить",
{
	duration = { min = 5, max = 25 },

	hooks =
	{
		["StartCommand"] = function(ply, cmd)
			cmd:SetForwardMove(-cmd:GetForwardMove())
			cmd:SetSideMove(-cmd:GetSideMove())
			cmd:SetUpMove(-cmd:GetUpMove())

			cmd:SetMouseX(-cmd:GetMouseX())
			cmd:SetMouseY(-cmd:GetMouseY())

			cmd:SetMouseWheel(-cmd:GetMouseWheel())
		end
	}
})

rtd.registerEffect("rand_swep", "получил случайное оружие",
{
	callback = function(ply)
		ply:Give(table.Random(weapons.GetList()).ClassName)
	end
})

rtd.registerEffect("vampire", "стал вампиром",
{
	duration = { min = 10, max = 30 },

	hooks =
	{
		["EntityTakeDamage"] = function(ent, dmg)
			if dmg:GetAttacker() == rtd.getCurrentPlayer() then
				dmg:GetAttacker():SetHealth(dmg:GetAttacker():Health() + dmg:GetDamage())
			end
		end
	}
})

rtd.registerEffect("mirror_dmg", "стал бесполезным в бою",
{
	duration = { min = 5, max = 20 },

	hooks =
	{
		["EntityTakeDamage"] = function(ent, dmg)
			if dmg:GetAttacker() == rtd.getCurrentPlayer() then
				dmg:GetAttacker():TakeDamage(dmg:GetDamage(), ent, dmg:GetInflictor())
				dmg:ScaleDamage(0)
			end
		end
	}
})

rtd.registerEffect("inf_ammo", "имеет беск. запас патрон",
{
	duration = { min = 10, max = 30 },

	callback = function(ply)
		local weapon = ply:GetActiveWeapon()

		if not weapon then return end

		weapon:SetClip1(weapon:GetMaxClip1())
		weapon:SetClip2(weapon:GetMaxClip2())
	end
})

rtd.registerEffect("fast_hands", "получил быстрые руки",
{
	duration = { min = 10, max = 30 },

	callback = function(ply)
		local weapon = ply:GetActiveWeapon()

		if not weapon then return end

		weapon:SetNextPrimaryFire(CurTime() + 0.05)
		weapon:SetNextSecondaryFire(CurTime() + 0.05)
	end
})

rtd.registerEffect("super_jump", "стал лягушкой",
{
	duration = { min = 5, max = 15 },

	on_first = function(ply)
		rtd.setUserData("power", ply:GetJumpPower())

		ply:SetJumpPower(600)
	end,

	on_end = function(ply)
		ply:SetJumpPower(rtd.getUserData"power")
	end
})

rtd.registerEffect("drug_bullets", "пули сломались",
{
	duration = { min = 10, max = 20 },

	hooks =
	{
		["EntityFireBullets"] = function(ply, bullet)
			bullet.Spread = Vector(math.Rand(-10, 10), math.Rand(-10, 10), 0)

			return true
		end
	}
})

rtd.registerEffect("strong_recoil", "разучился стрелять",
{
	duration = { min = 10, max = 30 },

	hooks =
	{
		["EntityFireBullets"] = function(ply, bullet)
			local angle = Angle(math.Rand(-45, 45), math.Rand(-10, 10), math.Rand(-10, 10))

			ply:ViewPunch(angle)
			angle.r = 0
			ply:SetEyeAngles(ply:EyeAngles() + (angle / 10))

			ply:SetVelocity(-bullet.Dir * (bullet.Force + bullet.Damage) * bullet.Damage * bullet.Num)

			bullet.Spread = bullet.Spread * Vector(math.Rand(1, 5), math.Rand(1, 5), 0)

			return true
		end
	}
})

rtd.registerEffect("grenade_rain", "попал под дождь из гранат",
{
	callback = function(ply)
		local pos = ply:GetShootPos() + Vector(0, 0, 100)
		local MAX_GRENADES = 5

		for x = 0, MAX_GRENADES do
			for y = 0, MAX_GRENADES do
				createGrenade(pos - Vector((MAX_GRENADES - x) * 20, (MAX_GRENADES - y) * 20, 0), ply, 1)
			end
		end
	end
})

rtd.registerEffect("trapped_in_prop", "застрял в пропе",
{
	duration = { min = 10, max = 30 },

	callback = function(ply)
		local prop = rtd.getUserData"prop"

		if not IsValid(prop) then return true end

		ply:SetMoveType(MOVETYPE_NONE)
		ply:SetPos(prop:GetPos())
	end,

	on_first = function(ply)
		local MODEL_LIST =
		{
			"models/props_c17/chair02a.mdl",
			"models/props_c17/oildrum001.mdl",
			"models/props_c17/oildrum001_explosive.mdl",
			"models/props_junk/TrashBin01a.mdl",
			"models/props_junk/wood_crate001a.mdl",
			"models/props_junk/wood_crate002a.mdl",
			"models/props_junk/TrafficCone001a.mdl",
			"models/props_interiors/VendingMachineSoda01a.mdl",
			"models/props_borealis/bluebarrel001.mdl",
			"models/props_wasteland/laundry_dryer002.mdl"
		}

		local ent = ents.Create"prop_physics"
		ent:SetModel(table.Random(MODEL_LIST))
		ent:SetPos(ply:GetPos())
		ply:SetParent(ent)
		ent:Spawn()

		rtd.setUserData("prop", ent)
		rtd.setUserData("movetype", ply:GetMoveType())
	end,

	on_end = function(ply)
		ply:SetParent(nil)
		ply:SetEyeAngles(Angle())
		ply:SetMoveType(rtd.getUserData"movetype")

		local ent = rtd.getUserData"prop"

		if not IsValid(ent) then return end

		ent:Remove()
	end
})


rtd.registerEffect("rand_tp", "телепортировался куда-то",
{
	callback = function(ply)
		local top = util.TraceLine({
			start = ply:GetPos(),
			endpos = ply:GetPos() + Vector(0, 0, 50000),
			filter = ply
		})

		local max_x = util.TraceLine({
			start = top.HitPos,
			endpos = top.HitPos + Vector(50000, 0, 0)
		})

		local max_y = util.TraceLine({
			start = top.HitPos,
			endpos = top.HitPos + Vector(0, 50000, 0)
		})

		local min_x = util.TraceLine({
			start = top.HitPos,
			endpos = top.HitPos + Vector(-50000, 0, 0)
		})

		local min_y = util.TraceLine({
			start = top.HitPos,
			endpos = top.HitPos + Vector(0, -50000, 0)
		})

		local tp_pos = Vector(
			math.Rand(min_x.HitPos.x, max_x.HitPos.x),
			math.Rand(min_y.HitPos.y, max_y.HitPos.y),
			math.Rand(ply:GetPos().z, top.HitPos.z)
		)

		ply:EmitSound("ambient/energy/zap"..math.random(1, 9)..".wav")
		ply:SetPos(tp_pos)
	end
})

rtd.registerEffect("big_ply", "стал большим",
{
	duration = { min = 5, max = 20 },

	on_first = function(ply)
		rtd.setUserData("scale", ply:GetModelScale())

		ply:SetModelScale(50, 1)
	end,

	on_end = function(ply)
		ply:SetModelScale(rtd.getUserData"scale", 0.5)
	end
})

rtd.registerEffect("small_ply", "стал маленьким",
{
	duration = { min = 5, max = 20 },

	on_first = function(ply)
		rtd.setUserData("scale", ply:GetModelScale())

		ply:SetModelScale(0.1, 1)
	end,

	on_end = function(ply)
		ply:SetModelScale(rtd.getUserData"scale", 0.5)
	end
})

local PROJ_TYPE_ANGLE = 1
local PROJ_TYPE_VELOCITY = 2

local projectiles =
{
	["npc_grenade_frag"] = PROJ_TYPE_VELOCITY,
	--["rpg_missile"] = PROJ_TYPE_VELOCITY,
	["prop_combine_ball"] = PROJ_TYPE_VELOCITY,
	--["crossbow_bolt"] = PROJ_TYPE_ANGLE,
	["npc_satchel"] = PROJ_TYPE_VELOCITY
}

rtd.registerEffect("homing_projectiles", "получил самонаводящиеся снаряды",
{
	duration = { min = 10, max = 30 },

	callback = function(ply)
		local tar = getClosestPlayer(ply)

		if not tar then return end

		local proj_table = {}

		for class, t in pairs(projectiles) do
			table.Merge(proj_table, ents.FindByClass(class))
		end

		for k, ent in pairs(proj_table) do
			local proj_type = projectiles[ent:GetClass()]

			if proj_type == nil then return end

			if
				ent:GetInternalVariable"m_hThrower" == ply or
				ent:GetInternalVariable"m_hOwner" == ply or
				ent:GetOwner() == ply
			then
				if proj_type == PROJ_TYPE_ANGLE then
					ent:SetAngles((ent:GetPos() - tar:GetPos()):Angle())
				elseif proj_type == PROJ_TYPE_VELOCITY then
					local phys = ent:GetPhysicsObject()

					if phys then phys:SetVelocity((tar:GetPos() - ent:GetPos()) * 10 * phys:GetMass()) end
				elseif isfunction(proj_type) then
					proj_type(ent, tar)
				end
			end
		end
	end
})

rtd.registerEffect("zombie", "стал зомби",
{
	duration = { min = 10, max = 30 },

	on_first = function(ply)
		ply:Give("weapon_crowbar")

		rtd.setUserData("crowbar", ply:GetWeapon("weapon_crowbar"))
	end,

	hooks =
	{
		["StartCommand"] = function(ply, cmd)
			cmd:SelectWeapon(rtd.getUserData"crowbar")
			cmd:SetForwardMove(10000)
			cmd:SetSideMove(0)
			cmd:SetUpMove(0)

			local angles = cmd:GetViewAngles()
			angles.r = 0

			local best_tar = getClosestPlayer(ply)
			if best_tar ~= nil then
				local dis = best_tar:GetPos():Distance(ply:GetPos())

				if best_tar and dis < 2000 then
					local aimang = (best_tar:GetPos() - ply:GetShootPos()):Angle()

					angles.p = aimang.p - 25
					angles.y = aimang.y
				else
					angles.p = 0
				end

				if ply:GetVelocity():Length() < (ply:GetRunSpeed() / 3) and dis > 300 then
					angles.y = angles.y + 90

					if (engine.TickCount() % 16) == 0 then
						ply:EmitSound("npc/zombie/zo_attack"..math.random(1, 2)..".wav")
					end
				end
			end

			if (engine.TickCount() % 72) == 0 then
				ply:EmitSound("npc/zombie/zombie_voice_idle"..math.random(1, 14)..".wav")
			end

			if (engine.TickCount() % 150) == 0 then
				cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_JUMP))
				cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_DUCK))

				ply:EmitSound("player/drown"..math.random(1, 3)..".wav")
			else
				cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(IN_JUMP)))
				cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(IN_DUCK)))
			end

			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_SPEED))
			cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(IN_ATTACK2)))

			cmd:SetViewAngles(angles)
			ply:SetEyeAngles(angles)
		end
	}
})

rtd.registerEffect("meteorite", "получает подарок из космоса",
{
	duration = 10,

	on_first = function(ply)
		local top = util.TraceLine({
			start = ply:GetPos(),
			endpos = ply:GetPos() + Vector(0, 0, 50000),
			mask = MASK_SOLID_BRUSHONLY
		})

		local met = ents.Create("prop_physics")
		met:SetPos(top.HitPos - Vector(0, 0, 50))
		met:SetModel("models/props_wasteland/rockgranite04a.mdl")
		met:SetMaterial("models/props_foliage/tree_deciduous_01a_trunk")
		met:Spawn()

		met:Ignite(10, 100)

		met:GetPhysicsObject():SetMass(50000)

		local trail = util.SpriteTrail(met, 0, Color(255, 255, 255), true, 100, 1, 5, 1, "trails/smoke")

		rtd.setUserData("trail", trail)
		rtd.setUserData("met", met)
	end,

	callback = function(ply)
		local met = rtd.getUserData"met"
		if not isentity(met) then return true end

		local phys = met:GetPhysicsObject()
		if not phys then return true end

		phys:ApplyForceOffset(Vector(0, 0, -10000), met:GetPos() + (met:OBBMaxs() * 10))
		phys:SetVelocity((ply:GetPos() - met:GetPos()) * 100)
	end,

	on_end = function(ply)
		local met = rtd.getUserData"met"
		if not IsValid(met) then return end

		local CHUNKS_MDL =
		{
			"models/props_wasteland/rockgranite02c.mdl",
			"models/props_wasteland/rockgranite02b.mdl",
			"models/props_wasteland/rockgranite02a.mdl",
			"models/props_wasteland/rockgranite03c.mdl",
			"models/props_wasteland/rockcliff01k.mdl",
			"models/props_wasteland/rockcliff01j.mdl",
			"models/props_wasteland/rockcliff01g.mdl"
		}

		for i = 1, math.random(8, 20) do
			local chunk = ents.Create("prop_physics")
			chunk:SetPos(met:GetPos())
			chunk:SetModel(table.Random(CHUNKS_MDL))
			chunk:SetMaterial("models/props_foliage/tree_deciduous_01a_trunk")
			chunk:Spawn()

			chunk:Ignite(5, 100)

			chunk:GetPhysicsObject():SetVelocity(VectorRand() * 1000)

			timer.Simple(5, function()
				if IsValid(chunk) then
					chunk:Remove()
				end
			end)
		end

		createExplosion(met:GetPos(), met, 1000, 300)
		met:Remove()
	end
})

--
-- You can replace these functions
--

hook.Add("PlayerSay", "roll the dice", function(ply, text)
	if ply:Alive() and string.StartWith(string.lower(text), "!rtd") then
		rtd.rollRandomEffect(ply)
	end
end)

concommand.Add("rtd_set_effect", function(ply, _, args)
	if not ply:IsAdmin() then return end

	if args[1] ~= nil then
		local effect = rtd.effects[args[1]]

		if not istable(effect) then
			ply:PrintMessage(HUD_PRINTCONSOLE, "Effect is not valid")
			return
		end

		if not rtd.rollEffect(ply, effect) then
			ply:PrintMessage(HUD_PRINTCONSOLE, "Something is gone wrong")
		else
			ply:PrintMessage(HUD_PRINTCONSOLE, "OK")
		end
	else
		ply:PrintMessage(HUD_PRINTCONSOLE, "Syntax: rtd_set_effect <effect_id>")
	end
end)

concommand.Add("rtd_print_all_effects", function(ply)
	if not ply:IsAdmin() then return end

	ply:PrintMessage(HUD_PRINTCONSOLE, "\t\tEffect count: "..#rtd.effects)

	for i, v in ipairs(rtd.effects) do
		ply:PrintMessage(
			HUD_PRINTCONSOLE,
			string.format("==> ID: %s <==\n{\n\tFormat: %s", v.id, v.format)
		)

		if istable(v.duration) then
			ply:PrintMessage(
				HUD_PRINTCONSOLE,
				string.format("\n\tDuration: %i-%i", v.duration.min, v.duration.max)
			)
		elseif isnumber(v.duration) then
			ply:PrintMessage(
				HUD_PRINTCONSOLE,
				string.format("\n\tDuration: %i", v.duration)
			)
		end

		ply:PrintMessage(HUD_PRINTCONSOLE, "\n}\n")
	end
end)