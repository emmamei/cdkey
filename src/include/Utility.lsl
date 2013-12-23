#ifndef UTILITY_LSL
#define UTILITY_LSL
//----------------------------------------
// Utility Functions
//----------------------------------------
string wwGetSLUrl() {
    string region = llGetRegionName();
    vector pos = llGetPos();
    string posx = (string)llRound(pos.x);
    string posy = (string)llRound(pos.y);
    string posz = (string)llRound(pos.z);

    return ("secondlife://" + llEscapeURL(region) +"/" + posx + "/" + posy + "/" + posz);
}

string bits2nybbles(integer bits)
{
    string nybbles = "";
    do
    {
        integer lsn = bits & 0xF; // least significant nybble
        nybbles = llGetSubString("0123456789ABCDEF", lsn, lsn) + nybbles;
    } while (bits = (0xfffFFFF & (bits >> 4)));
    return nybbles;
}

string formatFloat(float val, integer dp)
{
    string out = "ERROR";
    if (dp == 0) {
        out = (string)llRound(val);
    } else if (dp > 0 && dp <= 6) {
        val = llRound(val * llPow(10.0, dp)) / llPow(10.0, dp);
        out = llGetSubString((string)val, 0, -7 + dp);
    }
    return out;
}

#ifdef DEVELOPER_MODE
memReport() {
    float memory_limit = (float)llGetMemoryLimit();
    float free_memory = (float)llGetFreeMemory();
    float used_memory = (float)llGetUsedMemory();
    if (used_memory == memory_limit && free_memory > 0 && memory_limit == 16384) { // LSL2 compiled script
       used_memory = memory_limit - free_memory;
    }
    
    llSleep(1.0);
    llOwnerSay(SCRIPT_NAME + ": Memory " + formatFloat(used_memory/1024.0, 2) + "/" + (string)llRound((memory_limit)/1024.0) + "kB, " + formatFloat(free_memory/1024.0, 2) + " kB free");
}
#else
#define memReport(dummy)
#endif // DEVELOPER_MODE

#endif // UTILITY_LSL
