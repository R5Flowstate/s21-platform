
global function MpWeaponDirtyBomb_Init

global function OnWeaponTossReleaseAnimEvent_weapon_dirty_bomb
global function OnWeaponTossPrep_weapon_dirty_bomb


#if SERVER
global function RemoveCausticDirtyBomb
global function DirtyBomb_Destruction
#endif

global const string DIRTY_BOMB_TARGETNAME = "caustic_trap"
global const string CAUSTIC_DIRTY_BOMB_WEAPON_CLASS_NAME = "mp_weapon_dirty_bomb"
global const string DIRTY_BOMB_CLOUD_HOST_TARGETNAME = "caustic_trap_cloud_host"

const asset DIRTY_BOMB_CANISTER_MODEL = $"mdl/props/caustic_gas_tank/caustic_gas_tank.rmdl"

const asset DIRTY_BOMB_CANISTER_EXP_FX = $"P_meteor_trap_EXP"
const asset DIRTY_BOMB_CANISTER_FX_ALL = $"P_gastrap_start"

global int DIRTY_BOMB_MAX_GAS_CANISTERS = 6
const float DIRTY_BOMB_SPAWN_MIN = 1 			 //Min Spawn Delay
const float DIRTY_BOMB_SPAWN_MAX = 2 			 //Max Spawn Delay
const float DIRTY_BOMB_SPAWN_FORCE_MIN = 0.2 	 //Min Spawning Vel Force
const float DIRTY_BOMB_SPAWN_FORCE_MAX = 1 	 //Max Spawning Vel Force

const string DIRTY_BOMB_WARNING_SOUND 	= "weapon_vortex_gun_explosivewarningbeep"

const int DIRTY_BOMB_HEALTH = 150
global const float DIRTY_BOMB_CLOUD_LINGER_TIME = 2.0
const float DIRTY_BOMB_GAS_RADIUS = 256.0
const float DIRTY_BOMB_GAS_DURATION = 11.0
const float DIRTY_BOMB_DETECTION_RADIUS = 140.0

const float DIRTY_BOMB_THROW_POWER = 1.0
const float DIRTY_BOMB_GAS_FX_HEIGHT = 45.0
const float DIRTY_BOMB_GAS_CLOUD_HEIGHT = 48.0

//TRAP PLACEMENT VARS
const float DIRTY_BOMB_ACTIVATE_DELAY = 0.2
const float DIRTY_BOMB_PLACEMENT_RANGE_MAX = 64
const float DIRTY_BOMB_PLACEMENT_RANGE_MIN = 32
const vector DIRTY_BOMB_BOUND_MINS = <-8,-8,-8>
const vector DIRTY_BOMB_BOUND_MAXS = <8,8,8>
const vector DIRTY_BOMB_PLACEMENT_TRACE_OFFSET = <0,0,128>
const float DIRTY_BOMB_ANGLE_LIMIT = 0.55
const float DIRTY_BOMB_PLACEMENT_MAX_HEIGHT_DELTA = 20.0

const bool CAUSTIC_DEBUG_DRAW_PLACEMENT = false

struct DirtyBombPlacementInfo
{
	vector origin
	vector angles
	entity parentTo
	bool success = false
	bool doDeployAnim = true
}

struct
{
	#if SERVER
	table< entity, int > triggerTargets
	#endif
} file

void function MpWeaponDirtyBomb_Init()
{
	DirtyBombPrecache()
	// DIRTY_BOMB_MAX_GAS_CANISTERS: CafeMod mitosis OnEnable (or legacy playlist default)
}

void function DirtyBombPrecache()
{
	RegisterSignal( "DirtyBomb_Detonated" )
	RegisterSignal( "DirtyBomb_PickedUp" )
	RegisterSignal( "DirtyBomb_Disarmed" )
	RegisterSignal( "DirtyBomb_Active" )

	PrecacheParticleSystem( DIRTY_BOMB_CANISTER_EXP_FX )
	PrecacheParticleSystem( DIRTY_BOMB_CANISTER_FX_ALL )
	#if SERVER || CLIENT
	PrecacheModel( DIRTY_BOMB_CANISTER_MODEL )
	#endif // SERVER || CLIENT

	#if CLIENT
		AddCreateCallback( "prop_script", DirtyBomb_OnPropScriptCreated )
		AddCallback_MinimapEntShouldCreateCheck_Targetname( DIRTY_BOMB_TARGETNAME, Minimap_DontCreateRuisForEnemies )
	#endif
}

#if SERVER

void function DeployCausticTrap( entity owner, DirtyBombPlacementInfo placementInfo )
{
	if ( !IsValid( owner ) )
		return

	vector origin = placementInfo.origin
	vector angles = placementInfo.angles

	owner.EndSignal( "OnDestroy", "CleanUpPlayerAbilities" )

	int team = owner.GetTeam()
	entity canisterProxy = CreatePropScript( DIRTY_BOMB_CANISTER_MODEL, origin, angles, SOLID_CYLINDER )
	//canisterProxy.kv.collisionGroup = TRACE_COLLISION_GROUP_BLOCK_WEAPONS
	canisterProxy.DisableHibernation()
	canisterProxy.SetMaxHealth( DIRTY_BOMB_HEALTH )
	canisterProxy.SetHealth( DIRTY_BOMB_HEALTH )
	canisterProxy.SetDamageNotifications( false )
	canisterProxy.SetDeathNotifications( false )
	canisterProxy.SetArmorType( ARMOR_TYPE_HEAVY )
	canisterProxy.SetScriptName( DIRTY_BOMB_TARGETNAME )
	canisterProxy.SetBlocksRadiusDamage( false )
	SetTargetName( canisterProxy, DIRTY_BOMB_TARGETNAME )
	canisterProxy.EndSignal( "OnDestroy" )
	canisterProxy.SetBossPlayer( owner )
	canisterProxy.e.isGasSource = true
	canisterProxy.e.noOwnerFriendlyFire = false
	canisterProxy.e.isBusy = false
	canisterProxy.RemoveFromAllRealms()
	canisterProxy.AddToOtherEntitysRealms( owner )
	// SetTeam( canisterProxy, team )
	entity minimapObj = canisterProxy//CreatePropScript( $"mdl/dev/empty_model.rmdl", canisterProxy.GetOrigin() )
	// minimapObj.SetParent( canisterProxy )
	minimapObj.Minimap_SetCustomState( eMinimapObject_prop_script.DIRTY_BOMB )
	minimapObj.Minimap_AlwaysShow( team, null )
	minimapObj.Minimap_SetAlignUpright( true )
	minimapObj.Minimap_SetZOrder( MINIMAP_Z_OBJECT-1 )
	canisterProxy.SetTakeDamageType( DAMAGE_NO )
	canisterProxy.NotSolid()
	canisterProxy.SetPhysics( MOVETYPE_FLY ) // doesn't actually make it move, but allows pushers to interact with it
	Highlight_SetOwnedHighlight( canisterProxy, "sp_friendly_hero" )
	Highlight_SetFriendlyHighlight( canisterProxy, "sp_friendly_hero" )

	MakeEntityAsGasEmitter( canisterProxy )

	//EmitSoundOnEntityOnlyToPlayer( canisterProxy, owner, "GasTrap_Throw_1p" )
	//EmitSoundOnEntityExceptToPlayer( canisterProxy, owner, "GasTrap_Throw_3p" )

	string noSpawnIdx = CreateNoSpawnArea( TEAM_INVALID, team, origin, -1.0, DIRTY_BOMB_GAS_RADIUS )
	SetObjectCanBeMeleed( canisterProxy, true )
	SetVisibleEntitiesInConeQueriableEnabled( canisterProxy, false )

	//make npc's fire at their own traps to cut off lanes
	if ( owner.IsNPC() )
	{
		owner.SetSecondaryEnemy( canisterProxy )
		canisterProxy.EnableAttackableByAI( AI_PRIORITY_NO_THREAT, 0, AI_AP_FLAG_NONE )		// don't let other AI target this
	}

	//Register Canister so that it is detected by sonar.
	canisterProxy.Highlight_Enable()
	AddSonarDetectionForPropScript( canisterProxy )

	//Create a threat zone for the passive voices and store the ID so we can clean it up later.
	int threatZoneID = ThreatDetection_CreateThreatZoneForTrap( canisterProxy, owner, canisterProxy.GetOrigin(), team)

	// Landing sound handled in impact table: exp_dirty_bomb.txt
	// EmitSoundOnEntity( canisterProxy, "GasTrap_Land_Default" )

	entity mover

	if ( IsValid( placementInfo.parentTo ) )
	{
		mover = CreateScriptMover( "", origin, angles )
		mover.SetParent( placementInfo.parentTo )
		canisterProxy.SetParent( mover )
	}
	else
	{
		mover = canisterProxy
	}

	OnThreadEnd(
	function() : ( owner, canisterProxy, mover, noSpawnIdx, threatZoneID )
		{
			DeleteNoSpawnArea( noSpawnIdx )

			//Remove the threat zone for this trap.
			ThreatDetection_DestroyThreatZone( threatZoneID )

			if ( IsValid( owner ) )
			{
				for ( int i=owner.e.activeTraps.len()-1; i>=0 ; i-- )
				{
					if ( owner.e.activeTraps[i] == canisterProxy )
					{
						owner.e.activeTraps.remove( i )
					}
				}
			}

			thread RemoveCanister( canisterProxy, mover )
		}
	)

	canisterProxy.EndSignal( "OnDestroy" )
	canisterProxy.EndSignal( "DirtyBomb_Detonated" )
	canisterProxy.EndSignal( "DirtyBomb_PickedUp" )
	canisterProxy.EndSignal( "DirtyBomb_Disarmed" )

	canisterProxy.SetTakeDamageType( DAMAGE_EVENTS_ONLY )
	AddEntityCallback_OnDamaged( canisterProxy, OnDirtyBombCanisterDamaged_PreArmed )

	if ( placementInfo.doDeployAnim )
		waitthread PlayAnim( canisterProxy, "prop_caustic_gastank_predeploy", mover )
	thread PlayAnim( canisterProxy, "prop_caustic_gastank_predeploy_idle", mover )

	canisterProxy.Solid()

	waitthread PlayAnim( canisterProxy, "prop_caustic_gastank_deploy", mover )

	thread WaitForCanisterPickup( canisterProxy )
	thread CreateDirtyBombTriggerArea( canisterProxy, team )

	RemoveEntityCallback_OnDamaged( canisterProxy, OnDirtyBombCanisterDamaged_PreArmed )
	AddEntityCallback_OnDamaged( canisterProxy, OnDirtyBombCanisterDamaged )

	owner.e.activeTraps.insert( 0, canisterProxy )

	while ( owner.e.activeTraps.len() > DIRTY_BOMB_MAX_GAS_CANISTERS )
	{
		entity entToDelete = owner.e.activeTraps.pop()
		if ( IsValid( entToDelete ) )
		{
			entToDelete.Destroy()
		}
	}

	// CafeMod mitosis: every armed trap throws child canisters (recursive).
	// Cap via DIRTY_BOMB_MAX_GAS_CANISTERS (300 when mod ON). Oldest traps destroy.
	// Plant path = FireWeaponGrenade + proj.deployFunc (S21 sticky). Never WaitSignal("Planted").
	while ( CafeMod_IsEnabled( "mitosis" ) )
	{
		wait RandomFloatRange( DIRTY_BOMB_SPAWN_MIN, DIRTY_BOMB_SPAWN_MAX )

		if ( !CafeMod_IsEnabled( "mitosis" ) )
			break

		if ( !IsValid( owner ) || !IsValid( canisterProxy ) )
			break

		// Still throw when at cap -- DeployCausticTrap pops oldest. Skip only if no weapon.
		vector attackPos = placementInfo.origin + <0, 0, 80>
		float angle = RandomFloatRange( 0, 360 )
		vector dir = Normalize( <deg_sin( angle ), deg_cos( angle ), 1> )
		entity weapon = Mitosis_GetDirtyBombWeapon( owner )
		if ( !IsValid( weapon ) )
			continue

		thread Mitosis_ThrowChild( attackPos, dir, weapon, owner )
	}

	WaitForever()
}

entity function Mitosis_GetDirtyBombWeapon( entity owner )
{
	if ( !IsValid( owner ) || !owner.IsPlayer() )
		return null

	entity left = owner.GetOffhandWeapon( OFFHAND_LEFT )
	if ( IsValid( left ) && left.GetWeaponClassName() == CAUSTIC_DIRTY_BOMB_WEAPON_CLASS_NAME )
		return left

	array<entity> offhands = owner.GetOffhandWeapons()
	foreach ( entity w in offhands )
	{
		if ( IsValid( w ) && w.GetWeaponClassName() == CAUSTIC_DIRTY_BOMB_WEAPON_CLASS_NAME )
			return w
	}

	return null
}

// CafeMod throw: FireWeaponGrenade from the trap. S21 plant = deployFunc on sticky collide.
void function Mitosis_ThrowChild( vector attackPos, vector dir, entity weapon, entity owner )
{
	if ( !IsValid( weapon ) || !IsValid( owner ) )
		return

	if ( !CafeMod_IsEnabled( "mitosis" ) )
		return

	if ( !CafeMod_CanSpawnEntities( 16 ) )
		return

	// Empty clip can fail/no-op FireWeaponGrenade; refill so script throws always work.
	int clipMax = weapon.GetWeaponPrimaryClipCountMax()
	if ( clipMax > 0 && weapon.GetWeaponPrimaryClipCount() < 1 )
		weapon.SetWeaponPrimaryClipCount( clipMax )

	WeaponFireGrenadeParams fireGrenadeParams
	fireGrenadeParams.pos = attackPos
	fireGrenadeParams.vel = dir * RandomFloatRange( DIRTY_BOMB_SPAWN_FORCE_MIN, DIRTY_BOMB_SPAWN_FORCE_MAX )
	fireGrenadeParams.angVel = <600, RandomFloatRange( -300, 300 ), 0>
	fireGrenadeParams.fuseTime = 0
	fireGrenadeParams.scriptTouchDamageType = damageTypes.explosive
	fireGrenadeParams.scriptExplosionDamageType = damageTypes.explosive
	fireGrenadeParams.clientPredicted = false
	fireGrenadeParams.lagCompensated = true
	fireGrenadeParams.useScriptOnDamage = true

	entity deployable = weapon.FireWeaponGrenade( fireGrenadeParams )
	if ( !IsValid( deployable ) )
		return

	deployable.RemoveFromAllRealms()
	deployable.AddToOtherEntitysRealms( owner )

	vector angles = VectorToAngles( dir )
	deployable.proj.savedOrigin = deployable.GetOrigin()
	deployable.proj.savedAngles = <0, angles.y, 0>
	deployable.proj.savedVel = deployable.GetVelocity()
	Grenade_Init( deployable, weapon )
	// Sticky collision (OnProjectileCollision_weapon_deployable_LDOV) calls this.
	deployable.proj.deployFunc = OnDirtyBombPlanted
}


void function CausticTrap_OnDamaged_Activated(entity ent, var damageInfo)
{
	if( !IsValid( ent ) )
		return

	entity attacker = DamageInfo_GetAttacker(damageInfo)
	entity inflictor = DamageInfo_GetInflictor( damageInfo )

	if( IsValid( inflictor ) && inflictor.GetScriptName() == "caustic_trap_gas" )
		return

	float damage = DamageInfo_GetDamage( damageInfo )

	if( attacker.IsPlayer() )
	{
		attacker.NotifyDidDamage
		(
			ent,
			DamageInfo_GetHitBox( damageInfo ),
			DamageInfo_GetDamagePosition( damageInfo ),
			DamageInfo_GetCustomDamageType( damageInfo ),
			DamageInfo_GetDamage( damageInfo ),
			DamageInfo_GetDamageFlags( damageInfo ),
			DamageInfo_GetHitGroup( damageInfo ),
			DamageInfo_GetWeapon( damageInfo ),
			DamageInfo_GetDistFromAttackOrigin( damageInfo )
		)
	}

	// Handle damage, props get destroyed on death, we don't want that.
	// printt( "DEBUG CANNISTER DAMAGE - Damage: " + DamageInfo_GetDamage( damageInfo ) + " Health: " + ent.GetHealth() )

	// Handle damage, props get destroyed on death, we don't want that.
	float nextHealth = ent.GetHealth() - DamageInfo_GetDamage( damageInfo )
	if( nextHealth > 0 )
	{
		ent.SetHealth(nextHealth)
		return
	}

	// "Died"
	// Don't take damage anymore

	ent.SetTakeDamageType( DAMAGE_NO )
	ent.kv.solid = 0
	DamageInfo_SetDamage( damageInfo, 0 )

	thread RemoveCanister( ent, null )
}

void function RemoveCanister( entity canisterProxy, entity mover )
{
	OnThreadEnd(
		function () : (mover, canisterProxy)
		{
			// mover is being destroyed in sh_gas.gnut now. Colombia

			// if ( IsValid( mover ) )
			// {
				// mover.Destroy()
			// }
			if ( IsValid( canisterProxy ) )
			{
				canisterProxy.Destroy()
			}
		}
	)

	if ( IsValid( canisterProxy ) )
	{
		canisterProxy.EndSignal( "OnDestroy" )
		//canisterProxy.SetTakeDamageType( DAMAGE_NO )
		canisterProxy.NotSolid()

		float duration = canisterProxy.GetSequenceDuration( "prop_caustic_gastank_destroy" )
		Highlight_ClearOwnedHighlight( canisterProxy )
		Highlight_ClearFriendlyHighlight( canisterProxy )
		thread PlayAnim( canisterProxy, "prop_caustic_gastank_destroy", mover )
		//canisterProxy.Dissolve( ENTITY_DISSOLVE_CORE, <0,0,0>, 500 )
		waitthread PROTO_FadeModelAlphaOverTime( canisterProxy, duration )
	}
}

// Global interface
void function RemoveCausticDirtyBomb( entity canisterProxy, entity mover = null )
{
	thread RemoveCanister( canisterProxy, mover )
}

void function CreateDirtyBombTriggerArea( entity canisterProxy, int team )
{
	Assert ( IsNewThread(), "Must be threaded off" )
	canisterProxy.EndSignal( "OnDestroy" )
	canisterProxy.EndSignal( "DirtyBomb_Active" )
	canisterProxy.EndSignal( "DirtyBomb_PickedUp" )
	canisterProxy.EndSignal( "DirtyBomb_Disarmed" )

	vector origin = canisterProxy.GetOrigin()

	entity trigger = CreateEntity( "trigger_cylinder" )
	trigger.SetOwner( canisterProxy )
	trigger.SetRadius( DIRTY_BOMB_DETECTION_RADIUS )
	trigger.SetAboveHeight( 128 )
	trigger.SetBelowHeight( 128 )
	trigger.SetOrigin( origin )
	SetTeam( trigger, team )
	trigger.kv.triggerFilterNonCharacter = "0"
	trigger.RemoveFromAllRealms()
	trigger.AddToOtherEntitysRealms( canisterProxy )
	DispatchSpawn( trigger )

	file.triggerTargets[ trigger ] <- 0
	trigger.SetEnterCallback( OnDirtyBombAreaEnter )
	trigger.SetOrigin( origin )

	trigger.SetParent( IsValid( canisterProxy.GetParent() ) ? canisterProxy.GetParent() : canisterProxy, "", true, 0.0 )

	OnThreadEnd(
	function() : ( trigger )
	{
		delete file.triggerTargets[ trigger ]
		trigger.Destroy()
	} )

	WaitForever()
}

void function OnDirtyBombAreaEnter( entity trigger, entity ent )
{
	array<entity> touchingEnts = trigger.GetTouchingEntities()
	array<entity> filteredEnts

	int team = trigger.GetTeam()
	foreach ( entity touchingEnt in touchingEnts )
	{
		if ( touchingEnt.GetTeam() != team )
			filteredEnts.append( touchingEnt )
	}

	//if we have any hostile targets, start update
	if ( filteredEnts.len() && file.triggerTargets[ trigger ] == 0 )
		thread DirtyBombProximityActivationUpdate( trigger )
}

void function DirtyBombProximityActivationUpdate( entity trigger )
{
	Assert ( IsNewThread(), "Must be threaded off." )
	trigger.EndSignal( "OnDestroy" )

	vector offsetOrigin = trigger.GetOrigin() + <0,0,DIRTY_BOMB_GAS_CLOUD_HEIGHT>

	float maxDist		= DIRTY_BOMB_DETECTION_RADIUS
	int traceMask 		= TRACE_MASK_PLAYERSOLID
	int visConeFlags	= VIS_CONE_ENTS_TEST_HITBOXES | VIS_CONE_RETURN_HIT_VORTEX
	entity antilagPlayer = null

	int team = trigger.GetTeam()

	//printt( "STARTING UPDATE FOR TRIGGER" )

	array<entity> touchingEnts = trigger.GetTouchingEntities()
	while( touchingEnts.len() )
	{
		touchingEnts = trigger.GetTouchingEntities()
		array<entity> targetEnts
		array<entity> ignoreEnts = []

		foreach ( entity touchingEnt in touchingEnts )
		{
			if ( touchingEnt.GetTeam() != team )
				targetEnts.append( touchingEnt )
			else
				ignoreEnts.append( touchingEnt )
		}

		//printt( "TARGETS IN TRIGGER: " + targetEnts.len() )
		//if we are not touching any targets end update.
		file.triggerTargets[ trigger ] = targetEnts.len()
		if ( file.triggerTargets[ trigger ] == 0 )
			return

		array<entity> gasSources = GetEntArrayByScriptName( "dirty_bomb" )
		ignoreEnts.extend( gasSources )

		//printt( ignoreEnts.len() )

		foreach ( entity ent in targetEnts )
		{
			if ( !ent.DoesShareRealms( trigger ) )
				continue

			//Don't trigger on phase shifted targets.
			if ( ent.IsPhaseShifted() )
				continue

			//Don't trigger on cloaked targets.
			if ( IsCloaked( ent ) )
				continue

			//Don't trigger on titans
			// if ( ent.IsTitan() )
				// continue

			//printt( "CASTING CONE FOR " + ent )
			vector dir = Normalize( ent.GetOrigin() - offsetOrigin )
			array<VisibleEntityInCone> results = FindVisibleEntitiesInCone( offsetOrigin, dir, maxDist, 45, ignoreEnts, traceMask, visConeFlags, antilagPlayer )
			foreach ( result in results )
			{
				//printt( result.ent )
				if ( !targetEnts.contains( result.ent ) )
					continue

				//printt( "TARGET FOUND" )

				//A target has set off the dirty bomb
				entity canisterProxy = trigger.GetOwner()
				EmitSoundOnEntity( canisterProxy, DIRTY_BOMB_WARNING_SOUND )
				thread DetonateDirtyBombCanister( canisterProxy )
				return
			}
		}

		WaitFrame()
	}
}

void function OnDirtyBombCanisterDamaged( entity canisterProxy, var damageInfo )
{
	// printt( "canisterProxy damaged " + canisterProxy )

	if(canisterProxy.e.isBusy)
		return

	//HACK - Should use damage flags, but we might be capped?
	int damageSourceID = DamageInfo_GetDamageSourceIdentifier( damageInfo )
	switch ( damageSourceID )
	{
		case eDamageSourceId.damagedef_grenade_gas:
		case eDamageSourceId.damagedef_gas_exposure:
			return
	}

	int damageFlags = DamageInfo_GetCustomDamageType( damageInfo )

	bool isMelee                   = (damageFlags & DF_MELEE) ? true : false
	bool isExplosion               = (damageFlags & DF_EXPLOSION) ? true : false

	if ( isExplosion || isMelee )
	{
		thread DetonateDirtyBombCanister( canisterProxy )
		return
	}

	//Check hitBoxes
	int hitBox = DamageInfo_GetHitBox( damageInfo )
	entity attacker = DamageInfo_GetAttacker( damageInfo )

	if( !IsValid( attacker ) )
		return

	canisterProxy.e.isBusy = true

	if ( hitBox > 0 ) //Normal Hit
	{
		thread DetonateDirtyBombCanister( canisterProxy )
	}
	else
	{
		canisterProxy.Signal( "DirtyBomb_Disarmed" )
	}
}

void function OnDirtyBombCanisterDamaged_PreArmed( entity canisterProxy, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker(damageInfo)

	if( !IsValid( attacker ) || !attacker.IsPlayer() || attacker == canisterProxy.GetBossPlayer() )
		return

	entity inflictor = DamageInfo_GetInflictor( damageInfo )

	if( IsValid( inflictor ) && inflictor.GetScriptName() == "caustic_trap_gas" )
		return

	//printt( "Bomb disarmed: " + canisterProxy )
	canisterProxy.Signal( "DirtyBomb_Disarmed" )
}

void function DetonateDirtyBombCanister( entity canisterProxy )
{
	if ( !IsValid( canisterProxy ) )
		return

	canisterProxy.e.isBusy = true

	Assert( IsNewThread(), "Must be threaded off." )
	canisterProxy.EndSignal( "OnDestroy" )
	canisterProxy.Signal( "DirtyBomb_Active" )

	entity owner = canisterProxy.GetBossPlayer()

	if ( IsValid( owner ) )
		owner.EndSignal( "CleanUpPlayerAbilities" )

	//If the owner is alive we should use the owner, otherwise world is attacker
	entity attacker = IsValid( owner ) ? owner : svGlobal.worldspawn

	canisterProxy.SetOwner( attacker )

	if ( !IsValid( attacker ) )
		return

	if ( IsValid( owner ) )
		StatsHook_DirtyBomb_OnDetonate( owner, attacker, canisterProxy )

	EmitSoundOnEntity( canisterProxy, "GasTrap_Activate" )
	EmitSoundOnEntity( canisterProxy, "GasTrap_TrapLoop" ) // Sweetener for gas trap -- cloud has its own sound in sh_gas.gnut
	entity fx = PlayLoopFXOnEntity( DIRTY_BOMB_CANISTER_FX_ALL, canisterProxy, "fx_top" )

	Highlight_SetOwnedHighlight( canisterProxy, "caustic_gas_canister" )
	Highlight_SetFriendlyHighlight( canisterProxy, "caustic_gas_canister" )

	wait DIRTY_BOMB_ACTIVATE_DELAY

	attacker = IsValid( attacker ) ? attacker : svGlobal.worldspawn

	canisterProxy.SetHealth( DIRTY_BOMB_HEALTH )
	// canisterProxy.SetTakeDamageType( DAMAGE_YES )
	canisterProxy.SetDamageNotifications( true )

	RemoveEntityCallback_OnDamaged( canisterProxy, OnDirtyBombCanisterDamaged )
	AddEntityCallback_OnDamaged( canisterProxy, CausticTrap_OnDamaged_Activated )

	TrackingVision_CreatePOI( eTrackingVisionNetworkedPOITypes.PLAYER_ABILITIES_GAS, canisterProxy, canisterProxy.GetOrigin(), attacker.GetTeam(), attacker )
	CreateGasCloudMediumAtOrigin( canisterProxy, attacker, canisterProxy.GetOrigin() + <0,0,DIRTY_BOMB_GAS_CLOUD_HEIGHT>, DIRTY_BOMB_GAS_DURATION )

	wait DIRTY_BOMB_GAS_DURATION - 5.0

	if( IsValid( canisterProxy ) )
		thread BeepSound( canisterProxy )

	wait 5.0

	if ( IsValid( fx ) )
		fx.Destroy()

	if( IsValid( canisterProxy ) )
	{
		StopSoundOnEntity( canisterProxy, "GasTrap_TrapLoop" )
		canisterProxy.Signal( "DirtyBomb_Detonated" )
	}
}

void function BeepSound( entity canister )
{
	canister.EndSignal( "OnDestroy" )
	canister.EndSignal( "DirtyBomb_Detonated" )

	while ( 1 )
	{
		EmitSoundOnEntity( canister, "Wpn_ArcTrap_Beep" )
		wait 1.0
	}
}

void function WaitForCanisterPickup( entity canisterProxy )
{
	Assert( IsNewThread(), "Must be threaded off." )
	canisterProxy.EndSignal( "OnDestroy" )
	canisterProxy.EndSignal( "DirtyBomb_PickedUp" )
	canisterProxy.EndSignal( "DirtyBomb_Disarmed" )
	canisterProxy.EndSignal( "DirtyBomb_Active" )

	canisterProxy.SetUsable()
	//canister.SetUsableByGroup( "owner pilot" )
	canisterProxy.AddUsableValue( USABLE_CUSTOM_HINTS | USABLE_BY_OWNER | USABLE_CUSTOM_HINTS ) //Update hint text every server frame so that we can keep unique client texts up to date.
 	canisterProxy.SetUsePrompts( "#WPN_DIRTY_BOMB_DYNAMIC", "#WPN_DIRTY_BOMB_DYNAMIC" )

	OnThreadEnd(
	function() : ( canisterProxy )
		{
			if ( IsValid( canisterProxy ) )
			{
				canisterProxy.UnsetUsable()
			}
		}
	)

 	while( true )
 	{
 		entity player = expect entity( canisterProxy.WaitSignal( "OnPlayerUse" ).player )

 		//Titans cannot interact with dirty bomb.
 		// if ( player.IsTitan() )
 			// continue

		entity owner = canisterProxy.GetBossPlayer()

 		if ( player == owner )
 		{
 			if ( PickUpCanister( player ) )
	 		{
	 			canisterProxy.Signal( "DirtyBomb_PickedUp" )
	 		}
 		}
 	}
}

bool function PickUpCanister( entity player )
{
	entity weapon = player.GetOffhandWeapon( OFFHAND_TACTICAL )

	//string className = weapon.GetWeaponClassName()
	if ( weapon.GetWeaponClassName() != "mp_weapon_dirty_bomb" )
		return false

	if ( Bleedout_IsBleedingOut( player ) )
		return false

	int ammoPerShot = weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
	int maxAmmo = weapon.GetWeaponPrimaryClipCountMax()
	int curAmmo = weapon.GetWeaponPrimaryClipCount(  )
	int newAmmo = minint( curAmmo + ammoPerShot, maxAmmo )

	weapon.SetWeaponPrimaryClipCount( newAmmo )

	return true
}
#endif // SERVER

#if CLIENT
	void function DirtyBomb_OnPropScriptCreated( entity ent )
	{
		switch ( ent.GetScriptName() )
		{
			case DIRTY_BOMB_TARGETNAME:
				AddEntityCallback_GetUseEntOverrideText( ent, DirtyBomb_UseTextOverride )
				//thread DirtyBomb_CreateBombHUDMarker( ent )
			break
		}
	}

	string function DirtyBomb_UseTextOverride( entity ent )
	{
		entity player = GetLocalViewPlayer()

		if ( player.IsTitan() )
			return "#WPN_DIRTY_BOMB_NO_INTERACTION"

		if ( player == ent.GetBossPlayer() )
		{
			return ""
		}

		//if ( player.GetTeam() != ent.GetTeam() )
		//{
		//	return "#WPN_DIRTY_BOMB_DISARM_DYNAMIC"
		//}

		return "#WPN_DIRTY_BOMB_NO_INTERACTION"
	}

	void function DirtyBomb_CreateBombHUDMarker( entity bomb )
	{
		entity localClientPlayer = GetLocalClientPlayer()

		bomb.EndSignal( "OnDestroy" )

		if ( !ShouldShowBombIcon( localClientPlayer, bomb ) )
			return

		vector pos = bomb.GetOrigin() + <0,0,DIRTY_BOMB_GAS_CLOUD_HEIGHT>
		var rui = CreateCockpitRui( $"ui/dirty_bomb_marker_icons.rpak", RuiCalculateDistanceSortKey( localClientPlayer.EyePosition(), pos ) )
		RuiSetGameTime( rui, "startTime", Time() )
		RuiTrackFloat( rui, "healthFrac", bomb, RUI_TRACK_HEALTH )
		RuiTrackFloat3( rui, "pos", bomb, RUI_TRACK_POINT_FOLLOW, bomb.LookupAttachment( "fx_top" ) )
		RuiKeepSortKeyUpdated( rui, true, "pos" )

		RuiSetImage( rui, "bombImage", $"rui/hud/gametype_icons/raid/bomb_icon_friendly" )
		RuiSetImage( rui, "triggeredImage", $"rui/pilot_loadout/ordnance/electric_smoke" )

		OnThreadEnd(
		function() : ( rui )
		{
			RuiDestroy( rui )
		}
		)

		WaitForever()
	}

bool function ShouldShowBombIcon( entity localPlayer, entity bomb )
{
	if ( !GamePlayingOrSuddenDeath() )
		return false

	//if ( IsWatchingReplay() )
	//	return false
	entity owner = bomb.GetBossPlayer()
	if ( !IsValid( owner ) )
		return false

	if ( localPlayer.GetTeam() != owner.GetTeam() )
		return false

	return true
}

#endif //CLIENT

////////////////////////////////////////////////////////////////////////
//			TOSS
////////////////////////////////////////////////////////////////////////

var function OnWeaponTossReleaseAnimEvent_weapon_dirty_bomb( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	int ammoReq = weapon.GetAmmoPerShot()
	weapon.EmitWeaponSound_1p3p( GetGrenadeThrowSound_1p( weapon ), GetGrenadeThrowSound_3p( weapon ) )

	entity deployable = ThrowDeployable( weapon, attackParams, DIRTY_BOMB_THROW_POWER, OnDirtyBombPlanted )
	if ( deployable )
	{
		entity player = weapon.GetWeaponOwner()
		PlayerUsedOffhand( player, weapon )

		#if SERVER
			string projectileSound = GetGrenadeProjectileSound( weapon )
			if ( projectileSound != "" )
				EmitSoundOnEntity( deployable, projectileSound )

			weapon.w.lastProjectileFired = deployable
		#endif

		#if SERVER
			TryPlayWeaponBattleChatterLine( player, weapon )
		#endif

	}

	return ammoReq
}


void function OnWeaponTossPrep_weapon_dirty_bomb( entity weapon, WeaponTossPrepParams prepParams )
{
	weapon.EmitWeaponSound_1p3p( GetGrenadeDeploySound_1p( weapon ), GetGrenadeDeploySound_3p( weapon ) )
}

void function OnDirtyBombPlanted( entity projectile, DeployableCollisionParams collisionParams )
{
	#if SERVER
		if ( !IsValid( projectile ) )
			return

		entity trapOwner = projectile.GetOwner()
		if ( !IsValid( trapOwner ) || !trapOwner.IsPlayer() )
		{
			// Mitosis / script grenades: fall back to weapon owner.
			entity weap = projectile.GetWeaponSource()
			if ( IsValid( weap ) )
				trapOwner = weap.GetWeaponOwner()
		}
		if ( !IsValid( trapOwner ) || !trapOwner.IsPlayer() )
		{
			projectile.Destroy()
			return
		}

		DirtyBombPlacementInfo placementInfo
		placementInfo.origin = projectile.GetOrigin()
		placementInfo.angles = projectile.GetAngles()
		placementInfo.success = true
		placementInfo.doDeployAnim = false
		placementInfo.parentTo = projectile.GetParent()

		thread DeployCausticTrap( trapOwner, placementInfo )
		projectile.Destroy()
	#endif
}

#if CLIENT
void function MinimapPackage_DirtyBomb( entity ent, var rui )
{
#if MINIMAP_DEBUG
		printt( "Adding 'rui/hud/tactical_icons/tactical_caustic' icon to minimap" )
#endif
	RuiSetImage( rui, "defaultIcon", $"rui/hud/tactical_icons/tactical_caustic" )
	RuiSetImage( rui, "clampedDefaultIcon", $"rui/hud/tactical_icons/tactical_caustic" )
	RuiSetBool( rui, "useTeamColor", false )
	RuiSetFloat( rui, "iconBlend", 0.0 )
}
#endif //CLIENT

void function RestoreDirtyBombAmmo( entity owner )
{
	if ( IsAlive( owner ) )
	{
		entity weapon = owner.GetOffhandWeapon( OFFHAND_SPECIAL )
		if ( IsValid( weapon ) && weapon.GetWeaponClassName() == CAUSTIC_DIRTY_BOMB_WEAPON_CLASS_NAME )
		{
			Weapon_AddSingleCharge( weapon )
		}
	}
}

const string DIRTY_BOMB_CANISTER_EXPLODE_SOUND = "GasTrap_Destroyed_Explo"

const asset DIRTY_BOMB_CANISTER_MODEL_BIG = $"mdl/props/caustic_gas_tank/caustic_gas_tank_big.rmdl"

const float DIRTY_BOMB_TRACE_HEIGHT_END_OFFSET = 36

const asset DIRTY_BOMB_CANISTER_EXPLODE_FX = $"P_gastrap_destroyed"

#if SERVER
void function DirtyBomb_Destruction( entity canisterProxy )
{
	int effectID
	string destroySFX

	if( IsValid( canisterProxy ) )
	{
		effectID = PrecacheParticleSystem( DIRTY_BOMB_CANISTER_EXPLODE_FX )
		destroySFX 	= DIRTY_BOMB_CANISTER_EXPLODE_SOUND

		StartParticleEffectInWorldForRealms( effectID, canisterProxy.GetOrigin(), canisterProxy.GetAngles(), canisterProxy )
		EmitSoundAtPosition( TEAM_UNASSIGNED, canisterProxy.GetOrigin(), destroySFX, canisterProxy )
	}
}
#endif
