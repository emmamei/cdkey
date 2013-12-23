// LinkListen.lsl
//
// vim:sw=4 et nowrap:
//
// DATE: 20 December 2013
//
// Debug script to monitor link message activity
// between the scripts while being compatible with the new
// startup and initialization system.
//
// This script should not be released with the key, but
// should be removed before releasing.

default
{
    link_message(integer sender, integer num, string msg, key id) {
        list params = llParseString2List(msg, [ "​" ], []);
        if (id == NULL_KEY) {
            llOwnerSay((string)num + ", " + msg);
        } else {
            llOwnerSay((string)num + ", " + msg + ", " + (string)id);
        }
        
        if (num == 104 || num == 105) llMessageLinked(LINK_SET, 103, llGetScriptName(), NULL_KEY);
    }
}
