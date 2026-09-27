// Client half of the agent API: what the local player sees, and localized
// names for the place tokens the server reports.
global function AgentCl_State
global function AgentCl_Localize

void function AgentCl_Reply( table data )
{
	data.ok <- true
	AgentLink_Reply( Agent_Json( data ) )
}

void function AgentCl_State()
{
	entity player = GetLocalClientPlayer()
	entity viewPlayer = GetLocalViewPlayer()
	table data = { map = GetMapName(), connected = IsValid( player ) }
	if ( IsValid( player ) )
	{
		entity weapon = player.GetActiveWeapon( eActiveInventorySlot.mainHand )
		data.name <- player.GetPlayerName()
		data.alive <- IsAlive( player )
		data.origin <- player.GetOrigin()
		data.eyeAngles <- player.EyeAngles()
		data.eyePosition <- player.EyePosition()
		data.health <- player.GetHealth()
		data.shield <- player.GetShieldHealth()
		data.activeWeapon <- IsValid( weapon ) ? weapon.GetWeaponClassName() : ""
		data.spectating <- IsValid( viewPlayer ) && viewPlayer != player ? viewPlayer.GetPlayerName() : ""
	}
	AgentCl_Reply( data )
}

void function AgentCl_Localize( array<string> tokens )
{
	table names = {}
	foreach ( string token in tokens )
		names[ token ] <- Localize( token )
	AgentCl_Reply( { names = names } )
}
