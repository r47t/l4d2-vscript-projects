// Squirrel
// Gas Station Explosion

class CScriptPluginGasStationExplosion extends IScriptPlugin
{
	function Load()
	{
		::g_ConVar_AllowGasStationExp <- CreateConVar("gs_allow", 1, "integer", 0, 1);
		::g_ConVar_GasStationExpChance <- CreateConVar("gs_chance", 90, "integer", 0, 100);
		::g_ConVar_GasStationExpClearTime <- CreateConVar("gs_time", 0.0, "float", 0.0);
		::g_ConVar_GasStationExpDamage <- CreateConVar("gs_damage", 1, "integer", 0, 1);
		::g_ConVar_GasStationExpLimit <- CreateConVar("gs_limit", 10, "integer", 1);
		::g_ConVar_GasStationExpHordeTime <- CreateConVar("gs_horde", 2.0, "float", 0.0);

		RegisterOnTickFunction("g_tGasStationExplosion.GSE_Think");
		RegisterOnTickFunction("g_tGasStationExplosion.InvalidEntitiesListener_Think");

		g_ConVar_GasStationExpLimit.AddChangeHook(g_tGasStationExplosion.OnConVarChange);

		printl("[Gas Station Explosion]\nAuthor: Sw1ft\nVersion: 1.0.2");
	}

	function Unload()
	{

	}

	function OnRoundStartPost()
	{
		local hEntity, chance;
		if ((chance = GetConVarInt(g_ConVar_GasStationExpChance)) > 0)
		{
			foreach (map, tbl in g_tGasStationExpParams)
			{
				if (g_sMapName == map)
				{
					if (RandomInt(1, 100) <= chance)
					{
						g_tGasStationExplosion.SpawnGasStation(g_tGasStationExpParams[g_sMapName]["origin"], g_tGasStationExpParams[g_sMapName]["angles"]);
						printl("> [Gas Station Explosion] Gas station has been spawned for the current map at " + kvstr(g_tGasStationExpParams[g_sMapName]["origin"]));
					}
				}
			}
		}
	}

	function OnRoundEnd()
	{

	}

	function AdditionalClassMethodsInjected()
	{
		RegisterChatCommand("!gs_mode", g_tGasStationExplosion.SwitchMode, true);
		RegisterChatCommand("!gs_clear", g_tGasStationExplosion.Clear, true);
		RegisterChatCommand("!gas", g_tGasStationExplosion.Forward, true);
		RegisterChatCommand("!bgas", g_tGasStationExplosion.Behind, true);
		RegisterChatCommand("!lgas", g_tGasStationExplosion.Left, true);
		RegisterChatCommand("!rgas", g_tGasStationExplosion.Right, true);
	}

	function GetClassName() { return m_sClassName; }

	function GetScriptPluginName() { return m_sScriptPluginName; }

	function GetInterfaceVersion() { return m_InterfaceVersion; }

	function _set(key, val) { throw null; }

	static m_InterfaceVersion = 1;
	static m_sClassName = "CScriptPluginGasStationExplosion";
	static m_sScriptPluginName = "Gas Station Explosion";
}

enum eExplosionType
{
	Forward,
	Behind,
	Left,
	Right
}

g_GasStationExplosion <- CScriptPluginGasStationExplosion();

g_bMode <- true;
g_flLastSurvivorsReaction <- 0.0;

g_aGasStations <- [];
g_aInvalidEntitiesListener <- [];

g_sGasStationExpModel <-
[
	"models/hybridphysx/gasstationpart_1.mdl"
	"models/hybridphysx/gasstationpart_2.mdl"
	"models/hybridphysx/gasstationpart_3.mdl"
	"models/hybridphysx/gasstationpart_4.mdl"
	"models/hybridphysx/gasstationpart_5.mdl"
	"models/hybridphysx/gasstationpart_6.mdl"
	"models/hybridphysx/gasstationpart_7.mdl"
	"models/hybridphysx/gasstationpart_8.mdl"
	"models/hybridphysx/gasstationpart_9.mdl"
	"models/hybridphysx/gasstation_endstate_2.mdl"
	"models/hybridphysx/gaspumpdestruction.mdl"
	"models/hybridphysx/gasstationpit.mdl"
	"models/props_equipment/gas_pump_nodebris.mdl"
	"models/props_interiors/airportdeparturerampcontrol01.mdl"
];

g_tGasStationExpParams <-
{
	c1m2_streets =
	{
		origin = Vector(-6438.181, -3003.592, 390.657)
		angles = QAngle(0, -90, 0)
	}

	c6m3_port =
	{
		origin = Vector(638.044, 1093.173, 158.031)
		angles = QAngle(0, 90, 0)
	}

	c7m1_docks =
	{
		origin = Vector(10494.208, 2892.211, 128.031)
		angles = QAngle(0, 180, 0)
	}

	c7m3_port =
	{
		origin = Vector(638.044, 1093.173, 158.031)
		angles = QAngle(0, 90, 0)
	}
};

class CGasStationExplosion
{
	constructor(vecOrigin, eAngles, bDamage)
	{
		eAngles.x = 0.0;
		eAngles.z = 0.0;
		eAngles.y += 90.0;
		vecOrigin.z += 0.95;

		local sAngles = kvstr(eAngles);
		local vecForward = eAngles.Forward();
		local vecLeft = eAngles.Left() * -1;
		local vecGasPumpLeft = vecOrigin + Vector(0, 0, 8) + vecForward * 178 + vecLeft * -9;
		local vecGasPumpRight = vecOrigin + Vector(0, 0, 8) + vecForward * -215 + vecLeft * -9;

		m_aSoundEntities = [];
		m_aGasStation = [];
		m_aTimers = [];

		if (bDamage)
		{
			m_aTrianglePoints =
			[
				vecOrigin + vecLeft * 115 + vecForward * -155
				vecOrigin + vecLeft * -115 + vecForward * -155
				vecOrigin + vecLeft * 115 + vecForward * 330
			];

			m_hGasPumpLeftExplosion = SpawnEntityFromTable("env_explosion", {
				origin = vecGasPumpLeft + Vector(0, 0, 64)
				iMagnitude = 1000
				iRadiusOverride = 400
				spawnflags = 1852
				rendermode = 5
				ignoredClass = 4
				targetname = "__gas_station_exp__"
				fireballsprite = "sprites/zerogxplode.vmt"
			});

			m_hGasPumpRightExplosion = SpawnEntityFromTable("env_explosion", {
				origin = vecGasPumpRight + Vector(0, 0, 64)
				iMagnitude = 1000
				iRadiusOverride = 400
				spawnflags = 1852
				rendermode = 5
				ignoredClass = 4
				targetname = "__gas_station_exp__"
				fireballsprite = "sprites/zerogxplode.vmt"
			});

			getroottable()[m_sHurtFunction = "_gas_station_hurt" + UniqueString()] <- function(aTrianglePoints)
			{
				local hEntity, vecPos;
				local function HurtEntity(hEntity, vecPos)
				{
					if (VectorBetween(vecOrigin - Vector(500, 500, 500), vecOrigin + Vector(500, 500, 500), vecPos))
					{
						if (vecPos.z + 200 > vecOrigin.z && vecPos.z - 200 < vecOrigin.z)
						{
							if ((aTrianglePoints[1] - aTrianglePoints[0]).Dot(vecPos - aTrianglePoints[0]) > 0 && (aTrianglePoints[0] - aTrianglePoints[1]).Dot(vecPos - aTrianglePoints[1]) > 0)
							{
								if ((aTrianglePoints[2] - aTrianglePoints[0]).Dot(vecPos - aTrianglePoints[0]) > 0 && (aTrianglePoints[0] - aTrianglePoints[2]).Dot(vecPos - aTrianglePoints[2]) > 0)
								{
									hEntity.TakeDamage(10.0, DMG_BURN, null);
								}
							}
						}
					}
				}

				while (hEntity = Entities.FindByClassname(hEntity, "player"))
				{
					if (hEntity.IsAlive() && NetProps.GetPropInt(hEntity, "m_iObserverMode") == 0 && !NetProps.GetPropInt(hEntity, "m_isGhost"))
					{
						HurtEntity(hEntity, hEntity.GetBodyPosition())
					}
				}

				hEntity = null;
				while (hEntity = Entities.FindByClassname(hEntity, "infected"))
				{
					if (hEntity.GetHealth() > 0 && NetProps.GetPropInt(hEntity, "movetype") != MOVETYPE_NONE)
					{
						HurtEntity(hEntity, hEntity.GetOrigin())
					}
				}

				hEntity = null;
				while (hEntity = Entities.FindByClassname(hEntity, "witch"))
				{
					if (hEntity.GetHealth() > 0)
					{
						HurtEntity(hEntity, hEntity.GetOrigin())
					}
				}
				
				foreach (model in ["models/props_junk/gascan001a.mdl", "models/props_equipment/oxygentank01.mdl", "models/props_junk/propanecanister001a.mdl", "models/props_industrial/barrel_fuel.mdl"])
				{
					hEntity = null;
					while (hEntity = Entities.FindByModel(hEntity, model))
					{
						HurtEntity(hEntity, hEntity.GetOrigin())
					}
				}
			}
		}

		getroottable()[m_sPushFunction = "_gas_station_push" + UniqueString()] <- function()
		{
			local hPlayer, vecDirection;
			while (hPlayer = Entities.FindByClassname(hPlayer, "player"))
			{
				if (hPlayer.IsAlive() && NetProps.GetPropInt(hPlayer, "m_iObserverMode") == 0 && !NetProps.GetPropInt(hPlayer, "m_isGhost"))
				{
					if ((hPlayer.GetOrigin() - vecOrigin).LengthSqr() <= 25e4)
					{
						if (NetProps.GetPropInt(hPlayer, "m_fFlags") & FL_ONGROUND)
						{
							vecDirection = hPlayer.GetOrigin() - vecOrigin; vecDirection.z = 0.0;
							NetProps.SetPropVector(hPlayer, "m_vecBaseVelocity", vecDirection.Normalize() * 500);
						}
					}
				}
			}
		}

		for (local i = 0; i < 9; i++)
		{
			m_aGasStation.push(SpawnEntityFromTable("prop_dynamic", {
				origin = vecOrigin
				angles = sAngles
				disableshadows = 1
				targetname = "__gas_station_exp__"
				model = g_sGasStationExpModel[i]
			}));
		}

		m_hGasPumpExplosionShake = SpawnEntityFromTable("env_shake", {
			origin = vecOrigin
			amplitude = 16
			radius = 4096
			duration = 0.7
			frequency = 20
			targetname = "__gas_station_exp__"
		});

		m_hGasStationExplosionShake = SpawnEntityFromTable("env_shake", {
			origin = vecOrigin
			amplitude = 12
			radius = 4096
			duration = 3
			frequency = 9
			targetname = "__gas_station_exp__"
		});

		m_aSoundEntities.push(m_hBurningPipeLeft = SpawnEntityFromTable("ambient_generic", {
			origin = vecGasPumpLeft + Vector(0, 0, 32)
			disableshadows = 1
			health = 10
			radius = 2048
			spawnflags = 16
			targetname = "__gas_station_exp__"
			message = "fire_large"
		}));

		m_aSoundEntities.push(m_hBurningPipeRight = SpawnEntityFromTable("ambient_generic", {
			origin = vecGasPumpRight + Vector(0, 0, 32)
			disableshadows = 1
			health = 10
			radius = 2048
			spawnflags = 16
			targetname = "__gas_station_exp__"
			message = "fire_large"
		}));

		m_aSoundEntities.push(m_hGasExplosionSound = SpawnEntityFromTable("ambient_generic", {
			origin = vecOrigin + Vector(0, 0, 92)
			disableshadows = 1
			health = 10
			radius = 2642
			spawnflags = 1 | 16 | 32
			targetname = "__gas_station_exp__"
			message = "Objects.gas_station_explosion"
		}));

		m_aSoundEntities.push(m_hGasExplosionImpactSound = SpawnEntityFromTable("ambient_generic", {
			origin = vecOrigin + Vector(0, 0, 92)
			disableshadows = 1
			health = 10
			radius = 2642
			spawnflags = 1 | 16 | 32
			targetname = "__gas_station_exp__"
			message = "SmashCave.WoodRockCollapse"
		}));

		m_aSoundEntities.push(m_hGasPumpExplosionSound = SpawnEntityFromTable("ambient_generic", {
			origin = vecOrigin + Vector(0, 0, 92)
			disableshadows = 1
			health = 10
			radius = 2642
			spawnflags = 1 | 16 | 32
			targetname = "__gas_station_exp__"
			message = "explode_3"
		}));

		AcceptEntityInput(m_hGasStationBrush = SpawnEntityFromTable("prop_dynamic", {
			origin = vecOrigin - Vector(0, 0, 144.031)
			angles = sAngles
			solid = 6
			effects = 16
			spawnflags = 256
			disableshadows = 1
			StartDisabled = 1
			targetname = "__gas_station_exp__"
			model = g_sGasStationExpModel[9]
		}), "DisableCollision");

		AttachEntity(m_hDebrisDoor = SpawnEntityFromTable("func_door", {
			origin = vecOrigin - Vector(0, 0, 216.031)
			angles = kvstr(eAngles - QAngle(0, 90, 0))
			disableshadows = 1
			speed = 200
			lip = -128
			wait = -1
			spawnpos = 1
			movedir = "90 0 0"
			targetname = "__gas_station_exp__"
		}), m_hGasStationBrush);

		m_hGasStationPit = SpawnEntityFromTable("prop_dynamic", {
			origin = vecOrigin
			angles = sAngles
			disableshadows = 1
			StartDisabled = 1
			targetname = "__gas_station_exp__"
			model = g_sGasStationExpModel[11]
		});

		m_hGasPumpLeft = SpawnEntityFromTable("prop_dynamic", {
			origin = vecOrigin
			angles = sAngles
			disableshadows = 1
			StartDisabled = 1
			targetname = "__gas_station_exp__"
			model = g_sGasStationExpModel[10]
		});

		m_hGasPumpRight = SpawnEntityFromTable("prop_dynamic", {
			origin = vecOrigin + vecForward * -393
			angles = sAngles
			disableshadows = 1
			StartDisabled = 1
			targetname = "__gas_station_exp__"
			model = g_sGasStationExpModel[10]
		});

		m_hGasPumpLeftParticle = SpawnEntityFromTable("info_particle_system", {
			origin = vecGasPumpLeft
			angles = sAngles
			targetname = "__gas_station_exp__"
			effect_name = "gas_explosion_pump"
		});

		m_hGasPumpRightParticle = SpawnEntityFromTable("info_particle_system", {
			origin = vecGasPumpRight
			angles = sAngles
			targetname = "__gas_station_exp__"
			effect_name = "gas_explosion_pump"
		});

		m_hGasStationExplosionParticle = SpawnEntityFromTable("info_particle_system", {
			origin = vecGasPumpLeft - Vector(0, 0, 36.03125)
			angles = sAngles
			targetname = "__gas_station_exp__"
			effect_name = "gas_explosion_main"
		});

		m_hGasPumpLeftBreakable = SpawnEntityFromTable("prop_physics", {
			origin = vecGasPumpLeft
			angles = kvstr(eAngles - QAngle(0, 90, 0))
			spawnflags = 8 | 8192
			disableshadows = 1
			pressuredelay = 4
			physdamagescale = 1
			ExplodeDamage = 90
			PerformanceMode = 1
			Damagetype = DMG_CLUB
			targetname = "__gas_station_exp__"
			model = g_sGasStationExpModel[12]
		});

		m_hGasPumpRightBreakable = SpawnEntityFromTable("prop_physics", {
			origin = vecGasPumpRight
			angles = kvstr(eAngles - QAngle(0, 90, 0))
			spawnflags = 8 | 8192
			disableshadows = 1
			pressuredelay = 4
			physdamagescale = 1
			ExplodeDamage = 90
			PerformanceMode = 1
			Damagetype = DMG_CLUB
			targetname = "__gas_station_exp__"
			model = g_sGasStationExpModel[12]
		});

		g_aInvalidEntitiesListener.push({
			ent = m_hGasPumpLeftBreakable
			func = g_tGasStationExplosion.OnGasPumpKill
			params = {
				pump = "left"
				__instance = this
			}
		});

		g_aInvalidEntitiesListener.push({
			ent = m_hGasPumpRightBreakable
			func = g_tGasStationExplosion.OnGasPumpKill
			params = {
				pump = "right"
				__instance = this
			}
		});

		m_aEntities =
		[
			m_hGasStationBrush
			m_hDebrisDoor
			m_hGasStationPit
			m_hGasPumpLeft
			m_hGasPumpRight
			m_hGasPumpLeftParticle
			m_hGasPumpRightParticle
			m_hGasPumpExplosionShake
			m_hGasPumpExplosionSound
			m_hGasStationExplosionParticle
			m_hGasStationExplosionShake
			m_hGasExplosionImpactSound
		];
		m_aEntities.extend(m_aGasStation);
		m_aEntities.extend(m_aSoundEntities);
	}

	function StartPreExplosion()
	{
		if (!m_bExplosionStarted)
		{
			AcceptEntityInput(m_hGasExplosionSound, "PlaySound");
			m_aTimers.push(CreateTimer(2.0, function(__instance){
				if (!__instance.StartExplosion())
					__instance.ClearExplosion();
			}, this));
			m_bExplosionStarted = true;
		}
	}

	function StartExplosion()
	{
		if (IsAllEntitiesValid())
		{
			AcceptEntityInput(m_hGasExplosionSound, "PlaySound");
			AcceptEntityInput(m_hBurningPipeLeft, "PlaySound", "", 1.0);
			AcceptEntityInput(m_hBurningPipeRight, "PlaySound", "", 1.0);
			AcceptEntityInput(m_hGasExplosionImpactSound, "PlaySound", "", 3.1);

			AcceptEntityInput(m_hGasStationExplosionShake, "StartShake");
			AcceptEntityInput(m_hGasStationExplosionParticle, "Start", "", 0.5);

			AcceptEntityInput(m_hDebrisDoor, "Close", "", 1.0);
			AcceptEntityInput(m_hGasStationBrush, "Enable", "", 1.0);
			AcceptEntityInput(m_hGasStationBrush, "EnableCollision", "", 1.0);
			AcceptEntityInput(m_hGasStationPit, "Enable", "", 1.0);

			AcceptEntityInput(m_hGasPumpLeftParticle, "Kill", "", 1.0);
			AcceptEntityInput(m_hGasPumpRightParticle, "Kill", "", 1.0);

			AcceptEntityInput(m_hGasPumpLeft, "Kill", "", 1.0);
			AcceptEntityInput(m_hGasPumpRight, "Kill", "", 1.0);

			AcceptEntityInput(m_hGasPumpLeftBreakable, "Break");
			AcceptEntityInput(m_hGasPumpRightBreakable, "Break");

			AcceptEntityInput(m_hGasExplosionSound, "Kill", "", 12.0);
			AcceptEntityInput(m_hGasExplosionImpactSound, "Kill", "", 12.0);
			AcceptEntityInput(m_hGasStationExplosionShake, "Kill", "", 12.0);
			AcceptEntityInput(m_hGasPumpExplosionShake, "Kill", "", 6.0);
			AcceptEntityInput(m_hGasPumpExplosionSound, "Kill", "", 6.0);

			if (!m_bGasPumpLeftExploded)
			{
				if (m_hGasPumpLeftExplosion) AcceptEntityInput(m_hGasPumpLeftExplosion, "Explode");
				AcceptEntityInput(m_hGasPumpLeftParticle, "Start");
				AcceptEntityInput(m_hGasPumpExplosionSound, "PlaySound");
			}
			else if (!m_bGasPumpRightExploded)
			{
				if (m_hGasPumpRightExplosion) AcceptEntityInput(m_hGasPumpRightExplosion, "Explode");
				AcceptEntityInput(m_hGasPumpRightParticle, "Start");
				AcceptEntityInput(m_hGasPumpExplosionSound, "PlaySound");
			}

			foreach (ent in m_aGasStation)
			{
				AcceptEntityInput(ent, "SetAnimation", "boom");
			}

			if (GetConVarFloat(g_ConVar_GasStationExpHordeTime) > 0)
			{
				if (!Entities.FindByName(null, "director"))
				{
					SpawnEntityFromTable("info_director", {targetname = "director"});
				}

				m_aTimers.push(CreateTimer(GetConVarFloat(g_ConVar_GasStationExpHordeTime), function(){
					EntFire("director", "ForcePanicEvent", "1");
					EntFire("@director", "ForcePanicEvent", "1");
				}));
			}

			if (m_sHurtFunction)
			{
				m_aTimers.push(CreateTimer(0.4, RegisterLoopFunction, m_sHurtFunction, 0.5, m_aTrianglePoints));
				m_aTimers.push(CreateTimer(64.6, function(sHurtFunction, aTrianglePoints){
					if (IsLoopFunctionRegistered(sHurtFunction, aTrianglePoints))
						RemoveLoopFunction(sHurtFunction, aTrianglePoints);
				}, m_sHurtFunction, m_aTrianglePoints));
			}

			m_aTimers.push(CreateTimer(0.4, RegisterOnTickFunction, m_sPushFunction));
			m_aTimers.push(CreateTimer(0.9, function(sPushFunction){
				if (IsOnTickFunctionRegistered(sPushFunction))
					RemoveOnTickFunction(sPushFunction);
			}, m_sPushFunction));

			m_aTimers.push(CreateTimer(6.0, function(){
				if (g_flLastSurvivorsReaction + 10.0 < Time())
				{
					local hPlayer;
					local aL4D1Survivors = [];
					local aL4D2Survivors = [];
					local aL4D1SurvivorsNames = ["louis", "zoey", "bill", "francis"];
					local aL4D2SurvivorsNames = ["coach", "nick", "ellis", "rochelle"];

					for (local i = 0; i < aL4D1SurvivorsNames.len(); i++)
					{
						hPlayer = Entities.FindByName(null, "!" + aL4D1SurvivorsNames[i]);
						if (hPlayer)
						{
							if (hPlayer.IsSurvivor() && hPlayer.IsAlive() && !hPlayer.IsIncapacitated())
							{
								aL4D1Survivors.push(hPlayer);
							}
						}
					}

					for (local j = 0; j < aL4D2SurvivorsNames.len(); j++)
					{
						hPlayer = Entities.FindByName(null, "!" + aL4D2SurvivorsNames[j]);
						if (hPlayer)
						{
							if (hPlayer.IsSurvivor() && hPlayer.IsAlive() && !hPlayer.IsIncapacitated())
							{
								if (GetCharacterDisplayName(hPlayer).tolower() == aL4D2SurvivorsNames[j])
								{
									aL4D2Survivors.push(hPlayer);
								}
							}
						}
					}

					if (aL4D1Survivors.len() > 0)
					{
						local hEntity = SpawnEntityFromTable("func_orator", {
							disableshadows = 1
							spawnflags = 1
							model = g_sGasStationExpModel[13]
						});
						NetProps.SetPropInt(hEntity, "m_fEffects", (1 << 5));
						AcceptEntityInput(hEntity, "SpeakResponseConcept", "PlaneCrash");
						AcceptEntityInput(hEntity, "Kill", "", 0.01);
					}

					if (aL4D2Survivors.len() > 0)
					{
						local idx;
						local arr = [];
						local flTime = 1.0;

						while (aL4D2Survivors.len() > 0)
						{
							idx = RandomInt(0, aL4D2Survivors.len() - 1);
							arr.push(aL4D2Survivors[idx]);
							aL4D2Survivors.remove(idx);
						}
						
						for (local k = 0; k < arr.len(); k++)
						{
							AcceptEntityInput(arr[k], "SpeakResponseConcept", "C2M1Falling", flTime);
							flTime += 0.25;
						}
					}

					g_flLastSurvivorsReaction = Time();
				}
			}));

			m_bGasPumpLeftExploded = true;
			m_bGasPumpRightExploded = true;
			m_flExplosionTime = Time() + 9.0;

			return true;
		}
		return false;
	}

	function ExplodeGasPumpLeft()
	{
		if (!m_bGasPumpLeftExploded)
		{
			if (m_hGasPumpLeftExplosion) AcceptEntityInput(m_hGasPumpLeftExplosion, "Explode", "", 1.10);
			AcceptEntityInput(m_hGasPumpLeft, "Enable", "", 1.0);
			AcceptEntityInput(m_hGasPumpLeft, "SetAnimation", "leftDetonator", 1.10);
			AcceptEntityInput(m_hGasPumpExplosionShake, "StartShake", "", 1.0);
			AcceptEntityInput(m_hGasPumpLeftParticle, "Start", "", 1.10);
			AcceptEntityInput(m_hGasPumpExplosionSound, "PlaySound", "", 1.10);
			m_bGasPumpLeftExploded = true;
			StartPreExplosion();
		}
	}

	function ExplodeGasPumpRight()
	{
		if (!m_bGasPumpRightExploded)
		{
			if (m_hGasPumpRightExplosion) AcceptEntityInput(m_hGasPumpRightExplosion, "Explode", "", 1.10);
			AcceptEntityInput(m_hGasPumpRight, "Enable", "", 1.0);
			AcceptEntityInput(m_hGasPumpRight, "SetAnimation", "rightDetonator", 1.10);
			AcceptEntityInput(m_hGasPumpExplosionShake, "StartShake", "", 1.0);
			AcceptEntityInput(m_hGasPumpRightParticle, "Start", "", 1.10);
			AcceptEntityInput(m_hGasPumpExplosionSound, "PlaySound", "", 1.10);
			m_bGasPumpRightExploded = true;
			StartPreExplosion();
		}
	}

	function ClearExplosion()
	{
		m_bGasPumpLeftExploded = true;
		m_bGasPumpRightExploded = true;

		if (m_sPushFunction)
		{
			if (IsOnTickFunctionRegistered(m_sPushFunction)) RemoveOnTickFunction(m_sPushFunction);
			delete getroottable()[m_sPushFunction];
		}

		if (m_sHurtFunction)
		{
			if (IsLoopFunctionRegistered(m_sHurtFunction, m_aTrianglePoints)) RemoveLoopFunction(m_sHurtFunction, m_aTrianglePoints);
			delete getroottable()[m_sHurtFunction];
		}

		if (m_hGasPumpLeftBreakable && m_hGasPumpLeftBreakable.IsValid()) m_hGasPumpLeftBreakable.Kill();
		if (m_hGasPumpRightBreakable && m_hGasPumpRightBreakable.IsValid()) m_hGasPumpRightBreakable.Kill();

		foreach (ent in m_aSoundEntities)
		{
			if (ent && ent.IsValid())
			{
				AcceptEntityInput(ent, "Volume", "0");
				AcceptEntityInput(ent, "Kill", "", 0.01);
			}
		}

		foreach (ent in m_aEntities)
		{
			if (ent && ent.IsValid())
			{
				ent.Kill();
			}
		}

		for (local i = 0; i < m_aTimers.len(); i++)
		{
			foreach (idx, timer in g_aTimers)
			{
				if (m_aTimers[i].GetIdentifier() == timer.GetIdentifier())
				{
					g_aTimers.remove(idx);
					break;
				}
			}
		}
	}

	function IsAllEntitiesValid()
	{
		foreach (ent in m_aEntities)
		{
			if (!ent || !ent.IsValid())
				return false;
		}
		return true;
	}

	function _set(key, val) { throw null; }

	m_flExplosionTime = null;
	m_sPushFunction = null;
	m_sHurtFunction = null;
	m_bExplosionStarted = null;
	m_hGasStationExplosionParticle = null;
	m_hGasStationExplosionShake = null;
	m_hGasPumpExplosionShake = null;
	m_bGasPumpLeftExploded = null;
	m_bGasPumpRightExploded = null;
	m_hGasPumpLeftBreakable = null;
	m_hGasPumpRightBreakable = null;
	m_hGasPumpLeftParticle = null;
	m_hGasPumpRightParticle = null;
	m_hGasPumpLeftExplosion = null;
	m_hGasPumpRightExplosion = null;
	m_hGasPumpLeft = null;
	m_hGasPumpRight = null;
	m_hBurningPipeLeft = null;
	m_hBurningPipeRight = null;
	m_hGasPumpExplosionSound = null;
	m_hGasExplosionImpactSound = null;
	m_hGasExplosionSound = null;
	m_hGasStationBrush = null;
	m_hGasStationPit = null;
	m_aTrianglePoints = null;
	m_aGasStation = null;
	m_hDebrisDoor = null;
	m_aTimers = null;
	m_aEntities = null;
	m_aSoundEntities = null;
}

g_tGasStationExplosion <-
{
	OnConVarChange = function(ConVar, LastValue, NewValue)
	{
		while (g_aGasStations.len() > NewValue)
		{
			g_aGasStations[0].ClearExplosion();
			g_aGasStations.remove(0);
		}
	}

	OnGasPumpKill = function(tParams)
	{
		if (tParams["pump"] == "left")
			tParams["__instance"].ExplodeGasPumpLeft();
		else
			tParams["__instance"].ExplodeGasPumpRight();
	}

	Initialize = function(hPlayer, iExplosionType)
	{
		if (hPlayer.IsHost() && GetConVarBool(g_ConVar_AllowGasStationExp))
		{
			local vecOrigin;
			local eAngles = hPlayer.EyeAngles();
			if (g_bMode) vecOrigin = hPlayer.GetOrigin();
			else vecOrigin = hPlayer.DoTraceLine(eTrace.Type_Pos, eTrace.Distance, eTrace.Mask_Shot);
			if (iExplosionType == eExplosionType.Behind) eAngles += QAngle(0, 180, 0);
			else if (iExplosionType == eExplosionType.Left) eAngles += QAngle(0, 90, 0);
			else if (iExplosionType == eExplosionType.Right) eAngles -= QAngle(0, 90, 0);
			g_tGasStationExplosion.SpawnGasStation(vecOrigin, eAngles);
		}
	}

	GSE_Think = function()
	{
		if (g_aGasStations.len() > 0 && GetConVarFloat(g_ConVar_GasStationExpClearTime) > 0)
		{
			for (local i = 0; i < g_aGasStations.len(); i++)
			{
				if (g_aGasStations[i].m_flExplosionTime != null)
				{
					if (g_aGasStations[i].m_flExplosionTime + GetConVarFloat(g_ConVar_GasStationExpClearTime) < Time())
					{
						g_aGasStations[i].ClearExplosion();
						g_aGasStations.remove(i);
						i--;
					}
				}
			}
		}
	}

	InvalidEntitiesListener_Think = function()
	{
		local tbl;
		for (local i = 0; i < g_aInvalidEntitiesListener.len(); i++)
		{
			tbl = g_aInvalidEntitiesListener[i];
			if (!tbl.ent.IsValid())
			{
				tbl.func(tbl.params);
				g_aInvalidEntitiesListener.remove(i);
				i--;
			}
		}
	}

	SpawnGasStation = function(vecOrigin, eAngles)
	{
		if (g_aGasStations.len() > 0 && g_aGasStations.len() + 1 > GetConVarInt(g_ConVar_GasStationExpLimit))
		{
			g_aGasStations[0].ClearExplosion();
			g_aGasStations.remove(0);
		}
		g_aGasStations.push(CGasStationExplosion(vecOrigin, eAngles, GetConVarBool(g_ConVar_GasStationExpDamage)));
	}

	Clear = function(hPlayer)
	{
		if (hPlayer.IsHost())
		{
			for (local i = 0; i < g_aGasStations.len(); i++)
			{
				g_aGasStations[i].ClearExplosion();
				g_aGasStations.remove(i);
				i--;
			}
		}
	}

	SwitchMode = function(hPlayer)
	{
		if (hPlayer.IsHost())
		{
			SayMsg("[Gas Station Explosion] Explosion mode: " + (g_bMode ? "camera direction" : "near the player"));
			g_bMode = !g_bMode;
		}
	}

	Forward = function(hPlayer) { g_tGasStationExplosion.Initialize(hPlayer, eExplosionType.Forward); }

	Behind = function(hPlayer) { g_tGasStationExplosion.Initialize(hPlayer, eExplosionType.Behind); }

	Left = function(hPlayer) { g_tGasStationExplosion.Initialize(hPlayer, eExplosionType.Left); }

	Right = function(hPlayer) { g_tGasStationExplosion.Initialize(hPlayer, eExplosionType.Right); }
};

PrecacheEntityFromTable({classname = "ambient_generic", message = "Objects.gas_station_explosion"});
PrecacheEntityFromTable({classname = "ambient_generic", message = "SmashCave.WoodRockCollapse"});
PrecacheEntityFromTable({classname = "ambient_generic", message = "explode_3"});
PrecacheEntityFromTable({classname = "ambient_generic", message = "fire_large"});
PrecacheEntityFromTable({classname = "env_explosion", fireballsprite = "sprites/zerogxplode.spr"});

for (local i = 0; i < g_sGasStationExpModel.len(); i++)
{
	PrecacheEntityFromTable({classname = "prop_dynamic", model = g_sGasStationExpModel[i]});
}

g_ScriptPluginsHelper.AddScriptPlugin(g_GasStationExplosion);