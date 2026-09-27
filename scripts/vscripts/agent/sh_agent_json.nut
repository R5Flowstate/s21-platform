// JSON encoding shared by the agent API on every VM.
global function Agent_Json

// Player names can hold any byte; every control character must be escaped
// or the reply is not valid JSON.
string function Agent_JsonString( string s )
{
	string out = ""
	int start = 0
	int n = s.len()
	for ( int i = 0; i < n; i++ )
	{
		int c = expect int( s[i] ) & 0xFF
		if ( c >= 0x20 && c != 0x22 && c != 0x5C )
			continue
		out += s.slice( start, i )
		if ( c == 0x22 )
			out += "\\\""
		else if ( c == 0x5C )
			out += "\\\\"
		else if ( c == 0x0A )
			out += "\\n"
		else if ( c == 0x0D )
			out += "\\r"
		else if ( c == 0x09 )
			out += "\\t"
		else
			out += format( "\\u%04x", c )
		start = i + 1
	}
	return "\"" + out + s.slice( start ) + "\""
}

string function Agent_JsonNumber( float f )
{
	// NaN and infinities have no JSON form.
	if ( f != f || f > 1.0e30 || f < -1.0e30 )
		return "null"
	return format( "%.3f", f )
}

string function Agent_Json( var v )
{
	string t = typeof( v )
	if ( t == "null" )
		return "null"
	if ( t == "bool" )
		return expect bool( v ) ? "true" : "false"
	if ( t == "int" )
		return string( v )
	if ( t == "float" )
		return Agent_JsonNumber( expect float( v ) )
	if ( t == "string" )
		return Agent_JsonString( expect string( v ) )
	if ( t == "vector" )
	{
		vector vec = expect vector( v )
		return "[" + Agent_JsonNumber( vec.x ) + "," + Agent_JsonNumber( vec.y ) + "," + Agent_JsonNumber( vec.z ) + "]"
	}
	if ( t == "array" )
	{
		string arrOut = "["
		bool arrFirst = true
		foreach ( e in expect array( v ) )
		{
			if ( !arrFirst )
				arrOut += ","
			arrFirst = false
			arrOut += Agent_Json( e )
		}
		return arrOut + "]"
	}
	if ( t == "table" )
	{
		string tblOut = "{"
		bool tblFirst = true
		foreach ( k, val in expect table( v ) )
		{
			if ( !tblFirst )
				tblOut += ","
			tblFirst = false
			tblOut += Agent_JsonString( string( k ) ) + ":" + Agent_Json( val )
		}
		return tblOut + "}"
	}
	return Agent_JsonString( string( v ) )
}
