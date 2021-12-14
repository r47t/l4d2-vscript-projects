// Dynamic Light

class CDynamicLight extends IScriptPlugin
{
	function Load()
	{
		if (!("g_DynamicLightSettings" in getroottable()))
		{
			::g_DynamicLightSettings <-
			{
				dl_allow = 1
				dl_mode = DL_HELD_ITEM | DL_PROJECTILE | DL_INFLUENCE_EFFECT | DL_INFECTED_GLOW | DL_MUZZLE_FLASH
				dl_limit = 32
				dl_blink_interval = 0.25
				dl_flame_radius = 200.0
				dl_pipe_radius = 160.0
				dl_spit_radius = 200.0
				dl_fireworks_color = "255 100 0"
				dl_molotov_color = "255 50 0"
				dl_spit_color = "0 192 0"
			}

			::g_DynamicLightSettingsSrc <- clone g_DynamicLightSettings;
			
			local tData;
			if (tData = FileToString("dynamic_light/cvars.nut"))
			{
				try
				{
					tData = compilestring("return " + tData)();

					if (typeof tData != "table")
						throw "[Dynamic Light - Error] Expected table, not " + (typeof tData);
					
					foreach (key, val in g_DynamicLightSettings)
					{
						if (!tData.rawin(key))
						{
							tData.rawset(key, val);
							printl("[Dynamic Light - Warning] Couldn't find the table key, the value was reset to default");
						}
					}

					g_DynamicLightSettings = tData;
				}
				catch (error)
				{
					printl(error);
					printl("[Dynamic Light] Couldn't parse the file with settings, resetting..");
					g_DynamicLight.ResetSettings();
				}
			}
		}

		::g_ConVar_DynamicLightAllow <- CreateConVar("dl_allow", g_DynamicLightSettings["dl_allow"], "integer", 0, 1);
		::g_ConVar_DynamicLightMode <- CreateConVar("dl_mode", g_DynamicLightSettings["dl_mode"], "integer", 0, 31);
		::g_ConVar_DynamicLightLimit <- CreateConVar("dl_limit", g_DynamicLightSettings["dl_limit"], "integer", 0);
		::g_ConVar_DynamicLightBlinkInterval <- CreateConVar("dl_blink_interval", g_DynamicLightSettings["dl_blink_interval"], "float", 0.01);
		::g_ConVar_DynamicLightFlameRadius <- CreateConVar("dl_flame_radius", g_DynamicLightSettings["dl_flame_radius"], "float", 0.0, 1000.0);
		::g_ConVar_DynamicLightPipeBombRadius <- CreateConVar("dl_pipe_radius", g_DynamicLightSettings["dl_pipe_radius"], "float", 0.0, 1000.0);
		::g_ConVar_DynamicLightSpitRadius <- CreateConVar("dl_spit_radius", g_DynamicLightSettings["dl_spit_radius"], "float", 0.0, 1000.0);
		::g_ConVar_DynamicLightFireworksColor <- CreateConVar("dl_fireworks_color", g_DynamicLightSettings["dl_fireworks_color"]);
		::g_ConVar_DynamicLightMolotovColor <- CreateConVar("dl_molotov_color", g_DynamicLightSettings["dl_molotov_color"]);
		::g_ConVar_DynamicLightSpitColor <- CreateConVar("dl_spit_color", g_DynamicLightSettings["dl_spit_color"]);

		HookEvent("molotov_thrown", g_DynamicLight.OnMolotovThrown, g_DynamicLight);
		HookEvent("weapon_fire", g_DynamicLight.OnWeaponFire, g_DynamicLight);
		HookEvent("ability_use", g_DynamicLight.OnAbilityUse, g_DynamicLight);
		HookEvent("break_prop", g_DynamicLight.OnBreakProp, g_DynamicLight);

		printl("[Dynamic Light]\nAuthor: Sw1ft\nVersion: 2.0.5");
	}

	function Unload()
	{
		RemoveConVar(g_ConVar_DynamicLightAllow);
		RemoveConVar(g_ConVar_DynamicLightMode);
		RemoveConVar(g_ConVar_DynamicLightLimit);
		RemoveConVar(g_ConVar_DynamicLightBlinkInterval);
		RemoveConVar(g_ConVar_DynamicLightFlameRadius);
		RemoveConVar(g_ConVar_DynamicLightPipeBombRadius);
		RemoveConVar(g_ConVar_DynamicLightSpitRadius);
		RemoveConVar(g_ConVar_DynamicLightFireworksColor);
		RemoveConVar(g_ConVar_DynamicLightMolotovColor);
		RemoveConVar(g_ConVar_DynamicLightSpitColor);

		if ("g_iMaxParticles" in getroottable())
		{
			RemoveConVar(g_iMaxParticles);
			RemoveConVar(g_sFireworksColor);
			RemoveConVar(g_sMolotovColor);
			RemoveConVar(g_sSpitColor);
		}

		UnhookEvent("molotov_thrown", g_DynamicLight.OnMolotovThrown, g_DynamicLight);
		UnhookEvent("weapon_fire", g_DynamicLight.OnWeaponFire, g_DynamicLight);
		UnhookEvent("ability_use", g_DynamicLight.OnAbilityUse, g_DynamicLight);
		UnhookEvent("break_prop", g_DynamicLight.OnBreakProp, g_DynamicLight);

		RemoveLoopFunction("DynamicLight_Think", 0.0334);
		RemoveOnTickFunction("g_DynamicLight.DynamicLight_Think2");

		RemoveChatCommand("!dl_reset");
	}

	function OnRoundStartPost()
	{	
	}

	function OnRoundEnd()
	{
	}

	function OnExtendClassMethods()
	{
		::g_iMaxParticles <- GetConVarInt(g_ConVar_DynamicLightLimit);
		::g_sFireworksColor <- GetConVarString(g_ConVar_DynamicLightFireworksColor);
		::g_sMolotovColor <- GetConVarString(g_ConVar_DynamicLightMolotovColor);
		::g_sSpitColor <- GetConVarString(g_ConVar_DynamicLightSpitColor);

		g_ConVar_DynamicLightAllow.AddChangeHook(g_DynamicLight.OnConVarChange);
		g_ConVar_DynamicLightMode.AddChangeHook(g_DynamicLight.OnConVarChange);
		g_ConVar_DynamicLightLimit.AddChangeHook(g_DynamicLight.OnConVarChange);

		g_ConVar_DynamicLightBlinkInterval.AddChangeHook(g_DynamicLight.OnConVarChange);
		g_ConVar_DynamicLightFlameRadius.AddChangeHook(g_DynamicLight.OnConVarChange);
		g_ConVar_DynamicLightPipeBombRadius.AddChangeHook(g_DynamicLight.OnConVarChange);
		g_ConVar_DynamicLightSpitRadius.AddChangeHook(g_DynamicLight.OnConVarChange);

		g_ConVar_DynamicLightFireworksColor.AddChangeHook(g_DynamicLight.OnConVarChange);
		g_ConVar_DynamicLightMolotovColor.AddChangeHook(g_DynamicLight.OnConVarChange);
		g_ConVar_DynamicLightSpitColor.AddChangeHook(g_DynamicLight.OnConVarChange);

		RegisterLoopFunction("DynamicLight_Think", 0.0334);
		RegisterOnTickFunction("g_DynamicLight.DynamicLight_Think2");

		RegisterChatCommand("!dl_reset", g_DynamicLight.ResetSettings_Cmd, true);
	}

	function GetClassName() { return m_sClassName; }

	function GetScriptPluginName() { return m_sScriptPluginName; }

	function GetInterfaceVersion() { return m_InterfaceVersion; }

	static m_InterfaceVersion = 1;
	static m_sClassName = "CDynamicLight";
	static m_sScriptPluginName = "Dynamic Light";
}

g_PluginDynamicLight <- CDynamicLight();

g_DynamicLight <-
{
	hMuzzleFlashParticle = null

	aParticlesList = []
	flMuzzleFlashTime = array(MAXCLIENTS + 1, 0.0)

	UpdateSettings = function()
	{
		local sData = "{";
		foreach (key, val in g_DynamicLightSettings)
		{
			switch (typeof val)
			{
			case "string":
				sData = format("%s\n\t%s = \"%s\"", sData, key, val);
				break;
			
			case "float":
				sData = format("%s\n\t%s = %f", sData, key, val);
				break;
			
			case "integer":
			case "bool":
				sData = sData + "\n\t" + key + " = " + val;
				break;
			}
		}
		sData = sData + "\n}";
		StringToFile("dynamic_light/cvars.nut", sData);
	}

	ResetSettings = function()
	{
		g_DynamicLightSettings = clone g_DynamicLightSettingsSrc;
		SendToServerConsole("setinfo dl_allow " + g_DynamicLightSettings["dl_allow"]);
		SendToServerConsole("setinfo dl_mode " + g_DynamicLightSettings["dl_mode"]);
		SendToServerConsole("setinfo dl_limit " + g_DynamicLightSettings["dl_limit"]);
		SendToServerConsole("setinfo dl_blink_interval " + g_DynamicLightSettings["dl_blink_interval"]);
		SendToServerConsole("setinfo dl_flame_radius " + g_DynamicLightSettings["dl_flame_radius"]);
		SendToServerConsole("setinfo dl_pipe_radius " + g_DynamicLightSettings["dl_pipe_radius"]);
		SendToServerConsole("setinfo dl_spit_radius " + g_DynamicLightSettings["dl_spit_radius"]);
		SendToServerConsole(format("setinfo dl_fireworks_color \"%s\"", g_DynamicLightSettings["dl_fireworks_color"]));
		SendToServerConsole(format("setinfo dl_molotov_color \"%s\"", g_DynamicLightSettings["dl_molotov_color"]));
		SendToServerConsole(format("setinfo dl_spit_color \"%s\"", g_DynamicLightSettings["dl_spit_color"]));

		g_DynamicLight.UpdateSettings();
	}

	RemoveParticles = function(tParams)
	{
		if (tParams["particle"] && tParams["particle"].IsValid())
			tParams["particle"].Kill();

		if (tParams["particle2"] && tParams["particle2"].IsValid())
			tParams["particle2"].Kill();
	}

	GetParticleAttachment = function(sModel)
	{
		if (sModel.len() > 29)
		{
			switch (sModel[29])
			{
			case 98: // nick
			case 104: // ellis
			case 100: // rochelle
			case 118: // bill
				return "weapon_bone";

			case 99: // coach
			case 101: // francis
			case 97: // louis
			case 110: // zoey
				return "survivor_light";
			}
		}
	}

	Blink = function(hLight, flRadius, flDelay, bMode)
	{
		if (hLight && hLight.IsValid())
		{
			CreateTimer(flDelay, function(hLight, flRadius, flDelay, bMode){
				NetProps.SetPropFloat(hLight, "m_Radius", bMode ? 0.0 : flRadius);
				::g_DynamicLight.Blink(hLight, flRadius, flDelay, !bMode);
			}, hLight, flRadius, flDelay, bMode);
		}
	}

	PutOutMuzzleFlash = function(hLight, idx)
	{
		if (g_DynamicLight.flMuzzleFlashTime[idx] <= Time())
		{
			NetProps.SetPropFloat(hLight, "m_Radius", 0.0);
			AcceptEntityInput(hLight, "TurnOff");
		}
	}

	OnProjectileSpawn = function(hProjectile, iType)
	{
		this = ::g_DynamicLight;

		if (GetConVarInt(g_ConVar_DynamicLightAllow) && GetConVarInt(g_ConVar_DynamicLightMode) & DL_PROJECTILE)
		{
			if (iType == 0) // pipe bomb
			{
				if (aParticlesList.len() + 1 < g_iMaxParticles)
				{
					local flRadius = GetConVarFloat(g_ConVar_DynamicLightPipeBombRadius) * 1.25;
					
					local hLight = SpawnEntityFromTable("light_dynamic", {
						_light = "200 0 0"
						spotlight_radius = 128
						distance = flRadius
						brightness = 0
					});

					local hLight2 = SpawnEntityFromTable("light_dynamic", {
						_light = "255 55 0"
						spotlight_radius = 8
						distance = 16
						brightness = 1
						style = 6
					});

					Blink(hLight, flRadius, GetConVarFloat(g_ConVar_DynamicLightBlinkInterval), true);

					AttachEntity(hProjectile, hLight, "pipebomb_light");
					AttachEntity(hProjectile, hLight2, "fuse");

					aParticlesList.push(hLight);
					aParticlesList.push(hLight2);
				}
				return;
			}

			if (aParticlesList.len() < g_iMaxParticles)
			{
				if (iType == 1) // molotov
				{
					local hLight = SpawnEntityFromTable("light_dynamic", {
						_light = g_sMolotovColor
						spotlight_radius = 128
						distance = GetConVarFloat(g_ConVar_DynamicLightFlameRadius)
						brightness = 1
						style = 6
					});

					AttachEntity(hProjectile, hLight, "wick");
					aParticlesList.push(hLight);

					return;
				}

				// spit
				local hLight = SpawnEntityFromTable("light_dynamic", {
					origin = hProjectile.GetOrigin()
					_light = g_sSpitColor
					spotlight_radius = 128
					distance = GetConVarFloat(g_ConVar_DynamicLightFlameRadius) * 0.75
					brightness = 1
					style = 6
				});

				AttachEntity(hProjectile, hLight);
				aParticlesList.push(hLight);
			}
		}
	}

	OnInfluenceEffectSpawn = function(hEntity, iType)
	{
		this = ::g_DynamicLight;

		if (GetConVarInt(g_ConVar_DynamicLightAllow) && GetConVarInt(g_ConVar_DynamicLightMode) & DL_INFLUENCE_EFFECT && aParticlesList.len() < g_iMaxParticles)
		{
			local flInfluenceEffectLifeTime, flRadius, sColor;

			switch (iType)
			{
			// inferno or fireworks
			case 0:
			case 1:
				flRadius = GetConVarFloat(g_ConVar_DynamicLightFlameRadius) * 1.25;
				flInfluenceEffectLifeTime = cvar("inferno_flame_lifetime", null, false);
				if (iType == 0)
				{
					sColor = g_sMolotovColor;
				}
				else
				{
					flInfluenceEffectLifeTime -= 1.5;
					sColor = g_sFireworksColor;
				}
				break;
			
			// spit
			default:
				flRadius = GetConVarFloat(g_ConVar_DynamicLightSpitRadius) * 1.25;
				flInfluenceEffectLifeTime = 7.25;
				sColor = g_sSpitColor;
				break;
			}

			if (flInfluenceEffectLifeTime > 3.4 || iType == 2)
			{
				local iTicks = 50;
				local flTime = 0.0;
				local flRadiusDelta = flRadius / iTicks;

				local hLight = SpawnEntityFromTable("light_dynamic", {
					origin = hEntity.GetOrigin() + Vector(0, 0, 4)
					_light = sColor
					spotlight_radius = 256
					brightness = (iType == 2 ? 2 : 3)
					distance = 0
					style = 6
				});

				if (flRadius > 10)
				{
					flRadius = 0.0;
					for (local i = 0; i < iTicks; i++)
					{
						flTime += 0.0333333;
						flRadius += flRadiusDelta;
						CreateTimer(flTime, function(hLight, flRadius){
							if (hLight.IsValid()) NetProps.SetPropFloat(hLight, "m_Radius", flRadius);
						}, hLight, flRadius);
					}
					for (local j = 0; j < iTicks; j++)
					{
						flTime -= 0.0333333;
						flRadius -= flRadiusDelta;
						CreateTimer(flInfluenceEffectLifeTime - flTime, function(hLight, flRadius){
							if (hLight.IsValid()) NetProps.SetPropFloat(hLight, "m_Radius", flRadius);
						}, hLight, flRadius);
					}
				}

				AttachEntity(hEntity, hLight);
				aParticlesList.push(hLight);
			}
		}
	}

	OnConVarChange = function(ConVar, LastValue, NewValue)
	{
		this = ::g_DynamicLight;

		local sCvar = ConVar.GetName();
		if (sCvar == "dl_allow")
		{
			if (NewValue == 0)
			{
				foreach (particle in aParticlesList)
				{
					if (particle && particle.IsValid())
						particle.Kill();
				}
				aParticlesList.clear();
			}
		}
		else if (sCvar == "dl_limit")
		{
			g_iMaxParticles = NewValue;
		}
		else if (sCvar.find("_color") != null)
		{
			local aColors = split(NewValue, " ");
			if (aColors.len() > 2)
			{
				local r = aColors[0];
				local g = aColors[1];
				local b = aColors[2];
				
				try
				{
					r = r.tointeger();
					g = g.tointeger();
					b = b.tointeger();

					if (r >= 0 && r < 256 && g >= 0 && g < 256 && b >= 0 && b < 256)
					{
						local sColor = r + " " + g + " " + b;
						switch (sCvar)
						{
						case "dl_fireworks_color":
							g_sFireworksColor = sColor;
							break;

						case "dl_molotov_color":
							g_sMolotovColor = sColor;
							break;

						case "dl_spit_color":
							g_sSpitColor = sColor;
							break;
						}
					}
				}
				catch (error)
				{
					return;
				}
			}
		}

		g_DynamicLightSettings[sCvar] = NewValue;
		UpdateSettings();
	}

	DynamicLight_ThinkThread = function()
	{
		local hEntity;
		while (hEntity = Entities.FindByClassname(hEntity, "inferno"))
		{
			if (!KeyInScriptScope(hEntity, "spawned"))
			{
				g_DynamicLight.OnInfluenceEffectSpawn(hEntity, 0);
				SetScriptScopeVar(hEntity, "spawned", true);
			}
		}

		hEntity = null;
		while (hEntity = Entities.FindByClassname(hEntity, "pipe_bomb_projectile"))
		{
			if (!KeyInScriptScope(hEntity, "spawned"))
			{
				g_DynamicLight.OnProjectileSpawn(hEntity, 0);
				SetScriptScopeVar(hEntity, "spawned", true);
			}
		}

		hEntity = null;
		while (hEntity = Entities.FindByClassname(hEntity, "insect_swarm"))
		{
			if (!KeyInScriptScope(hEntity, "spawned"))
			{
				g_DynamicLight.OnInfluenceEffectSpawn(hEntity, 2);
				SetScriptScopeVar(hEntity, "spawned", true);
			}
		}
	}

	DynamicLight_Think2 = function()
	{
		this = ::g_DynamicLight;

		local idx = 0;
		local length = aParticlesList.len();

		while (idx < length)
		{
			if (!aParticlesList[idx].IsValid())
			{
				aParticlesList.remove(idx);
				--length;
				continue;
			}

			++idx;
		}

		if (hMuzzleFlashParticle && hMuzzleFlashParticle.IsValid())
		{
			local hPlayer = GetScriptScopeVar(hMuzzleFlashParticle, "owner");

			if (hPlayer.IsValid())
			{
				local vecDirection = hPlayer.EyeAngles().Forward();
				local vecEyePosition = hPlayer.EyePosition();
				local vecPos = hPlayer.DoTraceLine(eTrace.Type_Pos, 30.0);
				hMuzzleFlashParticle.SetOrigin(((vecEyePosition - vecPos).LengthSqr() <= 625.0) ? (vecPos - vecDirection) : (vecEyePosition + vecDirection * 25.0));
			}
		}
	}

	FindFireCrackerBlast = function()
	{
		local hEntity;
		while (hEntity = Entities.FindByClassname(hEntity, "fire_cracker_blast"))
		{
			if (!KeyInScriptScope(hEntity, "spawned"))
			{
				g_DynamicLight.OnInfluenceEffectSpawn(hEntity, 1);
				SetScriptScopeVar(hEntity, "spawned", true);
			}
		}
	}

	FindSpitterProjectile = function()
	{
		local hEntity;
		while (hEntity = Entities.FindByClassname(hEntity, "spitter_projectile"))
		{
			if (!KeyInScriptScope(hEntity, "spawned"))
			{
				g_DynamicLight.OnProjectileSpawn(hEntity, 2);
				SetScriptScopeVar(hEntity, "spawned", true);
			}
		}
	}

	OnMolotovThrown = function(tParams)
	{
		local hEntity;
		while (hEntity = Entities.FindByClassname(hEntity, "molotov_projectile"))
		{
			if (!KeyInScriptScope(hEntity, "spawned"))
			{
				g_DynamicLight.OnProjectileSpawn(hEntity, 1);
				SetScriptScopeVar(hEntity, "spawned", true);
			}
		}
	}

	OnWeaponFire = function(tParams)
	{
		if (g_DynamicLightSettings["dl_allow"] && g_DynamicLightSettings["dl_mode"] & DL_MUZZLE_FLASH)
		{
			local bAutomaticWeapon = true;

			switch (tParams["weaponid"])
			{
			case 1: // pistol
			case 3: // pumpshotgun
			case 4: // autoshotgun
			case 6: // hunting_rifle
			case 8: // shotgun_chrome
			case 10: // sniper_military
			case 11: // shotgun_spas
			case 32: // pistol_magnum
			case 35: // sniper_awp
			case 36: // sniper_scout
				bAutomaticWeapon = false;

			case 2: // smg
			case 5: // rifle
			case 7: // smg_silenced
			case 9: // rifle_desert
			case 26: // rifle_ak47
			case 33: // smg_mp5
			case 34: // rifle_sg552
			case 37: // rifle_m60
			case 54: // prop_minigun, prop_minigun_l4d1
				local hPlayer = tParams["_player"];
				local hLight = GetScriptScopeVar(hPlayer, "dynamic_light")["muzzle_flash"];

				if (hLight && hLight.IsValid() && hPlayer.IsAlive() && NetProps.GetPropInt(hPlayer, "m_nWaterLevel") < 3)
				{
					AcceptEntityInput(hLight, "TurnOn");
					NetProps.SetPropFloat(hLight, "m_Radius", bAutomaticWeapon ? (RandomInt(0, 1) ? 65.0 : RandomFloat(155.0, 255.0)) : RandomFloat(100.0, 255.0));
					
					g_DynamicLight.flMuzzleFlashTime[hPlayer.GetEntityIndex()] = Time() + 0.0334;
					CreateTimer(0.0334, g_DynamicLight.PutOutMuzzleFlash, hLight, hPlayer.GetEntityIndex());
				}
				
				break;
			}
		}
	}

	OnAbilityUse = function(tParams)
	{
		if (tParams["ability"] == "ability_spit")
			CreateTimer(0.24, g_DynamicLight.FindSpitterProjectile);
	}

	OnBreakProp = function(tParams)
	{
		CreateTimer(0.01, g_DynamicLight.FindFireCrackerBlast);
	}

	ResetSettings_Cmd = function(hPlayer)
	{
		if (hPlayer.IsHost())
		{
			g_DynamicLight.ResetSettings();
			EmitSoundOnClient("EDIT_TOGGLE_PLACE_MODE", hPlayer);
		}
	}
};

function DynamicLight_Think()
{
	local hPlayer;

	while (hPlayer = Entities.FindByClassname(hPlayer, "player"))
	{
		if (!KeyInScriptScope(hPlayer, "dynamic_light"))
		{
			SetScriptScopeVar(hPlayer, "dynamic_light", {
				name = null
				burning = false
				particle = null
				particle2 = null
				muzzle_flash = null
			});
		}

		local sActiveWeapon;
		local tParams = GetScriptScopeVar(hPlayer, "dynamic_light");

		if (GetConVarInt(g_ConVar_DynamicLightAllow))
		{
			if (hPlayer.IsAlive())
			{
				local length = g_DynamicLight.aParticlesList.len();
				local mode = GetConVarInt(g_ConVar_DynamicLightMode);
				
				if (hPlayer.IsSurvivor() && NetProps.GetPropInt(hPlayer, "m_nWaterLevel") < 3)
				{
					if (tParams["muzzle_flash"])
					{
						if (!tParams["muzzle_flash"].IsValid())
							tParams["muzzle_flash"] = null;
					}
					else if (mode & DL_MUZZLE_FLASH)
					{
						local hLight = tParams["muzzle_flash"] = SpawnEntityFromTable("light_dynamic", {
							_light = "250 150 30"
							spotlight_radius = 32
							brightness = 1
							distance = 0
						});

						if (hPlayer.IsHost())
						{
							g_DynamicLight.hMuzzleFlashParticle = hLight;
							SetScriptScopeVar(hLight, "owner", hPlayer);
						}
						else
						{
							AttachEntity(hPlayer, hLight, "survivor_light");
						}

						AcceptEntityInput(hLight, "TurnOff");
					}

					if (mode & DL_HELD_ITEM && !hPlayer.IsIncapacitated() && NetProps.GetPropInt(hPlayer, "m_MoveType") != MOVETYPE_LADDER)
					{
						local hWeapon;
						local tInv = {};
						GetInvTable(hPlayer, tInv);

						if ((hWeapon = hPlayer.GetActiveWeapon()) && !NetProps.GetPropInt(hWeapon, "m_bRedraw"))
							sActiveWeapon = hWeapon.GetClassname();

						if ("slot2" in tInv)
						{
							local sClass = tInv["slot2"].GetClassname();
							if (sClass != tParams["name"] && sClass == sActiveWeapon)
							{
								if (sClass == "weapon_molotov" && length < g_iMaxParticles)
								{
									local hLight = SpawnEntityFromTable("light_dynamic", {
										_light = g_sMolotovColor
										spotlight_radius = 128
										distance = GetConVarFloat(g_ConVar_DynamicLightFlameRadius)
										brightness = 1
										style = 6
									});

									AttachEntity(hPlayer, hLight, g_DynamicLight.GetParticleAttachment(NetProps.GetPropString(hPlayer, "m_ModelName")));

									g_DynamicLight.aParticlesList.push(hLight);

									g_DynamicLight.RemoveParticles(tParams);
									tParams["particle"] = hLight;
									tParams["name"] = sClass;

									continue;
								}
								else if (sClass == "weapon_pipe_bomb" && length + 1 < g_iMaxParticles)
								{
									local flRadius = GetConVarFloat(g_ConVar_DynamicLightPipeBombRadius);

									local hLight = SpawnEntityFromTable("light_dynamic", {
										_light = "255 0 0"
										spotlight_radius = 128
										distance = flRadius
										brightness = 1
									});

									local hLight2 = SpawnEntityFromTable("light_dynamic", {
										origin = hPlayer.EyePosition() + hPlayer.EyeAngles().Left() * 8
										_light = "128 28 0"
										spotlight_radius = 32
										distance = 32
										brightness = 2
										style = 6
									});

									g_DynamicLight.Blink(hLight, flRadius, GetConVarFloat(g_ConVar_DynamicLightBlinkInterval), true);

									AttachEntity(hPlayer, hLight, g_DynamicLight.GetParticleAttachment(NetProps.GetPropString(hPlayer, "m_ModelName")));
									AttachEntity(hPlayer, hLight2, "armR_T");

									g_DynamicLight.aParticlesList.push(hLight);
									g_DynamicLight.aParticlesList.push(hLight2);

									g_DynamicLight.RemoveParticles(tParams);

									tParams["particle"] = hLight;
									tParams["particle2"] = hLight2;
									tParams["name"] = sClass;

									continue;
								}
							}
						}
					}
				}
				else if (mode & DL_INFECTED_GLOW)
				{
					if (hPlayer.IsOnFire() && NetProps.GetPropInt(hPlayer, "m_nWaterLevel") < 1)
					{
						if (!tParams["burning"] && length < g_iMaxParticles)
						{
							local hLight = SpawnEntityFromTable("light_dynamic", {
								origin = hPlayer.GetBodyPosition(0.35)
								_light = g_sMolotovColor
								spotlight_radius = 128
								distance = GetConVarFloat(g_ConVar_DynamicLightFlameRadius) * 0.75
								brightness = 2
								style = 6
							});

							AttachEntity(hPlayer, hLight);

							g_DynamicLight.aParticlesList.push(hLight);
							g_DynamicLight.RemoveParticles(tParams);

							tParams["particle"] = hLight;
						}
						tParams["burning"] = true;
					}
					else
					{
						if (tParams["burning"]) g_DynamicLight.RemoveParticles(tParams);
						tParams["burning"] = false;
					}
				}
			}
		}

		if (tParams["name"] != sActiveWeapon)
		{
			g_DynamicLight.RemoveParticles(tParams);

			tParams["name"] = null;
			tParams["particle"] = null;
			tParams["particle2"] = null;
		}
	}

	local hEntity;
	while (hEntity = Entities.FindByClassname(hEntity, "inferno"))
	{
		if (!KeyInScriptScope(hEntity, "spawned"))
		{
			g_DynamicLight.OnInfluenceEffectSpawn(hEntity, 0);
			SetScriptScopeVar(hEntity, "spawned", true);
		}
	}

	hEntity = null;
	while (hEntity = Entities.FindByClassname(hEntity, "pipe_bomb_projectile"))
	{
		if (!KeyInScriptScope(hEntity, "spawned"))
		{
			g_DynamicLight.OnProjectileSpawn(hEntity, 0);
			SetScriptScopeVar(hEntity, "spawned", true);
		}
	}

	hEntity = null;
	while (hEntity = Entities.FindByClassname(hEntity, "insect_swarm"))
	{
		if (!KeyInScriptScope(hEntity, "spawned"))
		{
			g_DynamicLight.OnInfluenceEffectSpawn(hEntity, 2);
			SetScriptScopeVar(hEntity, "spawned", true);
		}
	}

	// newthread(g_DynamicLight.DynamicLight_ThinkThread).call();
}

g_ScriptPluginsHelper.AddScriptPlugin(g_PluginDynamicLight);