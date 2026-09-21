global function OnWeaponActivate_weapon_semipistol
global function OnWeaponDeactivate_weapon_semipistol
global function OnWeaponReload_weapon_semipistol
global function OnProjectileCollision_weapon_semipistol
global function OnWeaponAkimboStateChanged_weapon_semipistol

void function OnWeaponActivate_weapon_semipistol( entity weapon )
{
                   
                                       
       

               
            
                                                                  
                                                         
                                                                   
                                                          
                                                                   
                                                          
        
       
}

void function OnWeaponDeactivate_weapon_semipistol( entity weapon )
{
                   
                                         
       
}

void function OnWeaponAkimboStateChanged_weapon_semipistol( entity weapon, entity player, int currentAkimboState )
{
	#if CLIENT
		if ( player != GetLocalViewPlayer() || weapon.IsAkimboAlthand() )
			return

		PrimaryWeapon_UpdateFireSelectHUD( weapon )
		OnPrimaryWeaponStatusUpdate_Akimbo( weapon, GetWeaponRui() )
	#endif
}

void function OnWeaponReload_weapon_semipistol ( entity weapon, int milestoneIndex )
{
                   
                                                    
       
}


#if SERVER
void function OnProjectileCollision_weapon_semipistol( entity projectile, vector pos, vector normal, entity hitEnt, int hitBox, bool isCritical )
#else
void function OnProjectileCollision_weapon_semipistol( entity projectile, vector pos, vector normal, entity hitEnt, int hitBox, bool isCritical, bool isPassthrough )
#endif
{
                   
                                                                                                        
       
}


//this was a temp airburst prototype, wasn't really usable since we could only do the airburst stuff from server. Will wait on code to do it as a real feature if we want this. (dbocek 3/19/21)

/*
global function OnWeaponActivate_weapon_semipistol
global function OnWeaponPrimaryAttack_weapon_semipistol
global function GetProjectileVelocity_weapon_semipistol

const string SHATTER_CAPS_MOD = "altfire_shatter_rounds"
const string AIRBURST_SETTING = "airburst_distance"
const string AIRBURST_PELLET_COUNT_SETTING = "airburst_pellet_count"
const string AIRBURST_PELLET_DMG_SETTING = "airburst_pellet_damage"
const string AIRBURST_PATTERN_SCALE = "airburst_pattern_scale"

//const array< array<float> > AIRBURST_PATTERN_OFFSETS = [ [0.0, 0.0], [1.0, 1.0], [1.0, -1.0], [2.5, 0.0], [-1.0, 1.0], [-1.0, -1.0], [-2.5, 0.0] ]
const array< array<float> > AIRBURST_PATTERN_OFFSETS = [ [0.0, 0.0], [1.0, 0.2], [-1.0, 0.2] ]

struct
{
	bool isInitialized = false

	float airburstDistance
	int airburstPelletCount
	//int airburstPelletDamage
	float airburstPatternScale
	int damageFlags
} file


void function OnWeaponActivate_weapon_semipistol( entity weapon )
{
	if ( !file.isInitialized )
	{
		file.isInitialized        = true
		file.airburstDistance     = GetWeaponInfoFileKeyField_GlobalFloat( "mp_weapon_semipistol", AIRBURST_SETTING )
		file.airburstPelletCount  = GetWeaponInfoFileKeyField_GlobalInt( "mp_weapon_semipistol", AIRBURST_PELLET_COUNT_SETTING )
		//file.airburstPelletDamage  = GetWeaponInfoFileKeyField_GlobalInt( "mp_weapon_semipistol", AIRBURST_PELLET_DMG_SETTING )
		file.airburstPatternScale = GetWeaponInfoFileKeyField_GlobalFloat( "mp_weapon_semipistol", AIRBURST_PATTERN_SCALE )
		file.damageFlags = weapon.GetWeaponDamageFlags()
	}
}

var function OnWeaponPrimaryAttack_weapon_semipistol( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	#if CLIENT
	if ( !weapon.ShouldPredictProjectiles() )
		return
	#endif

	if ( weapon.HasMod( SHATTER_CAPS_MOD ) )
	{
		WeaponFireBoltParams params
		params.pos = attackParams.pos
		params.dir = attackParams.dir
		params.speed = 1.0
		params.scriptTouchDamageType = file.damageFlags
		params.scriptExplosionDamageType = file.damageFlags
		params.clientPredicted = false
		params.dontApplySpread = false

		entity projectile = weapon.FireWeaponBoltAndReturnEntity( params )

		if ( projectile != null )
		{
			projectile.proj.savedOrigin = attackParams.pos
			projectile.proj.detonateDist = file.airburstDistance
		}
	}
	else
	{
		weapon.FireWeapon_Default( attackParams.pos, attackParams.dir, 1.0, 1.0, false )
	}

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

vector function GetProjectileVelocity_weapon_semipistol( entity projectile, float timeElapsed, float timeStep )
{
	if ( !IsValid( projectile ) )
		return <0, 0, 0>

	vector vel             = projectile.GetVelocity()
	float gravityVelChange = projectile.GetCurrentProjectileGravity() * timeStep
	vel -= <0, 0, gravityVelChange>

	entity weapon = projectile.GetWeaponSource()
	if ( !IsValid( weapon ) )
	{
		#if SERVER
			projectile.Destroy()
		#endif
		return vel
	}

	#if SERVER
	if ( projectile.proj.detonateDist > 0 )
	{
		float travelledDist = Distance( projectile.GetOrigin(), projectile.proj.savedOrigin )
		//todo: we should figure out where along this move step the distance was reached and actually explode at that point. needs the code feature but good enough for proto

		if ( travelledDist >= projectile.proj.detonateDist )
		{

			//temp hacky blast pattern stuff until we get code support
			printt( "detonated after " + travelledDist + " units" )
			for ( int i = 0; i < AIRBURST_PATTERN_OFFSETS.len(); i++ )
			{
				vector patternOrigin = projectile.GetOrigin() + projectile.GetForwardVector() * 512;
				float offsetX = AIRBURST_PATTERN_OFFSETS[i][0] * file.airburstPatternScale
				float offsetY = AIRBURST_PATTERN_OFFSETS[i][1] * file.airburstPatternScale

				vector dir = (patternOrigin + projectile.GetRightVector() * offsetX + projectile.GetUpVector() * offsetY) - projectile.GetOrigin()
				dir = Normalize( dir )

				WeaponFireBoltParams params
				params.pos = projectile.GetOrigin()
				params.dir = dir
				params.speed = 1.0
				params.scriptTouchDamageType = file.damageFlags
				params.scriptExplosionDamageType = file.damageFlags
				params.clientPredicted = false
				params.dontApplySpread = true

				entity newProj = weapon.FireWeaponBoltAndReturnEntity( params )
				newProj.proj.detonateDist = -1.0
				newProj.proj.savedOrigin = newProj.GetOrigin()
			}

			#if SERVER
				projectile.Destroy()
			#endif
		}
	}
	#endif

	return vel
}
*/
