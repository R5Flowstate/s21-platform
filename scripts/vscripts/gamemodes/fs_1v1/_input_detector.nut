// IBMM input detect (CafeFPS) -- S21 port of Flowstate mp/_input_detector.nut
// p.input: 0 = MnK, 1 = controller

global function InputDetector_Init
global function StartInputDetectorForPlayer
global function FS_1v1_PublishInputState

struct
{
	bool signalRegistered = false
	table<entity, bool> running
} file

void function InputDetector_Init()
{
	AddCallback_OnClientConnected( InputDetector_OnClientConnected )
}

void function InputDetector_OnClientConnected( entity player )
{
	player.p.input = player.IsBot() ? 1 : 0
	FS_1v1_PublishInputState( player )

	if ( !player.IsBot() )
		StartInputDetectorForPlayer( player )
}

void function InputDetector_EnsureSignal()
{
	if ( file.signalRegistered )
		return
	file.signalRegistered = true
	RegisterSignal( "InputChanged" )
}

// p.input is what the matchmaker reads and FS_PlayerIsMnk is what every HUD
// reads. Publish one from the other so they can never disagree.
void function FS_1v1_PublishInputState( entity player )
{
	if ( !IsValid( player ) )
		return

	player.SetPlayerNetBool( "FS_PlayerIsMnk", player.p.input == 0 )
}

void function StartInputDetectorForPlayer( entity player )
{
	if ( !IsValid( player ) || player in file.running )
		return

	file.running[ player ] <- true
	InputDetector_EnsureSignal()
	thread Thread_CheckInput( player )

	AddButtonPressedPlayerInputCallback( player, IN_MOVELEFT, SetInput_IN_MOVELEFT )
	AddButtonPressedPlayerInputCallback( player, IN_MOVERIGHT, SetInput_IN_MOVERIGHT )
	AddButtonPressedPlayerInputCallback( player, IN_BACK, SetInput_IN_BACK )
	AddButtonPressedPlayerInputCallback( player, IN_FORWARD, SetInput_IN_FORWARD )
}

void function Thread_CheckInput( entity player )
{
	int timesCheckedForNewInput = 0
	int previousInput = -1
	bool isCheckerRunning = false
	bool previousMnkState = false
	bool mnkStateInitialized = false

	OnThreadEnd(
		function() : ( player )
		{
			if ( player in file.running )
				delete file.running[ player ]
		}
	)

	for ( ; ; )
	{
		wait 0.1

		if ( !IsValid( player ) )
			break

		int typeOfInput = GetInput( player )

		if ( !isCheckerRunning && typeOfInput == 1 )
			player.p.movevalue = 0

		if ( typeOfInput == 9 )
			continue

		bool currentMnkState = ( player.p.input == 0 )

		if ( !mnkStateInitialized || currentMnkState != previousMnkState )
		{
			FS_1v1_PublishInputState( player )
			previousMnkState = currentMnkState
			mnkStateInitialized = true
		}

		if ( isCheckerRunning )
		{
			if ( typeOfInput == previousInput )
			{
				if ( timesCheckedForNewInput >= 4 )
				{
					isCheckerRunning = false
					timesCheckedForNewInput = 0

					if ( InvalidInput( typeOfInput, player.p.movevalue ) )
					{
						player.p.input = 0
					}
					else
					{
						player.p.input = typeOfInput
						player.p.lastInputChangeTime = Time()
						player.Signal( "InputChanged" )
					}
					// Publish now: the leaderboard reads p.input directly and must never disagree with the HUD flag.
					FS_1v1_PublishInputState( player )
					previousMnkState = ( player.p.input == 0 )
					mnkStateInitialized = true
					continue
				}
				timesCheckedForNewInput++
			}
			else
			{
				timesCheckedForNewInput = 0
				isCheckerRunning = false
			}

			previousInput = typeOfInput
			continue
		}

		if ( player.p.input != typeOfInput && !isCheckerRunning )
		{
			isCheckerRunning = true
			previousInput = typeOfInput
			continue
		}
	}
}

bool function InvalidInput( int input_type, int movevalue )
{
	if ( movevalue == 0 && input_type == 0 )
		return true
	return false
}

// 0 = MnK (short axis string), 1 = controller, 9 = idle/noise
int function GetInput( entity player )
{
	float value = player.GetInputAxisRight() == 0 ? player.GetInputAxisForward() : player.GetInputAxisRight()

	if ( value == 0 || value == 0.5 )
		return 9

	return value.tostring().len() < 5 ? 0 : 1
}

void function SetInput_IN_MOVELEFT( entity player )
{
	player.p.movevalue = 3
}

void function SetInput_IN_MOVERIGHT( entity player )
{
	player.p.movevalue = 4
}

void function SetInput_IN_BACK( entity player )
{
	player.p.movevalue = 5
}

void function SetInput_IN_FORWARD( entity player )
{
	player.p.movevalue = 6
}
