// LinkListen.lsl
//
// vim:sw=4 et nowrap:
//
// DATE: 8 December 2013
//
// Optional debug script to monitor link message activity
// between the scripts while being compatible with the new
// startup and initialization system.

default
{
    link_message(integer sender, integer num, string msg, key id) {
        list params = llParseString2List(msg, [ "​" ], []);
        llOwnerSay((string)num + ", " + msg + ", " + (string)id);
        
        if (num == 104 || num == 105) llMessageLinked(LINK_SET, 103, llGetScriptName(), NULL_KEY);
    }
}
