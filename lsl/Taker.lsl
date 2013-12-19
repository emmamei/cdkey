// 1 "Taker.lslp"
// 1 "<built-in>"
// 1 "<command-line>"
// 1 "Taker.lslp"
// Taker.lsl
//
// DATE: 18 December 2012
//
// 8/19 sits in key, helps change key.  Taker 4 doesn't have allowing inventory drop for getpin
// 1 "include/GlobalDefines.lsl" 1
// include/GlobalDefines.lsl
//
// Global preprocessor and variable definitions for the key
//
// 35 "include/GlobalDefines.lsl"
// Link messages
// 44 "include/GlobalDefines.lsl"
// Keys of important people in life of the Key:





// 1 "include/Utility.lsl" 1
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

memReport() {
    float free_memory = (float)llGetFreeMemory();
    float used_memory = (float)llGetUsedMemory();

    llOwnerSay(llGetScriptName() + ": Memory " + formatFloat(used_memory/1024.0, 2) + "/" + (string)llRound((used_memory + free_memory)/1024.0) + "kB, " + formatFloat(free_memory/1024.0, 2) + " kB free");
}
// 51 "include/GlobalDefines.lsl" 2
// 1 "include/KeySharedFuncs.lsl" 1
//-----------------------------------
// Internal Shared Functions
//-----------------------------------

float lastTimerEvent;

float setWindRate() {
    float newWindRate;
    vector agentPos = llList2Vector(llGetObjectDetails(dollID, [ OBJECT_POS ]), 0);
    integer agentInfo = llGetAgentInfo(dollID);
    integer windDown = (llGetAttached() == ATTACH_BACK) && !collapsed && dollType != "Builder" && dollType != "Key";

    newWindRate = 1.0;
    if (afk) newWindRate *= 0.5;

    if (windRate != newWindRate * windDown) {
        windRate = newWindRate * windDown;

        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "windRate" + "|" + (string)windRate,NULL_KEY);
    }

    // llTargetOmega: With normalized vector spinrate is equal to radians per second
    // 2𝜋 radians per rotation.  This sets a normal rotation rate of 4 rpm about the
    // Z axis multiplied by the wind rate this way the key will visually run faster as
    // the dolly begins using their time faster.
    llTargetOmega(llVecNorm(<0.0, 0.0, 1.0>), windRate * (TWO_PI / 15.0), 1);

    return newWindRate;
}

integer setFlags(integer clear, integer set) {
    integer oldFlags = globalFlags;
    globalFlags = (globalFlags & ~clear) | set;
    if (globalFlags != oldFlags) {
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "globalFlags" + "|" + "0x" + bits2nybbles(globalFlags),NULL_KEY);
        return 1;
    }
    else return 0;
}
// 52 "include/GlobalDefines.lsl" 2
// 7 "Taker.lslp" 2

integer cd6011;
integer cd6200;
integer listen_cd6011;
integer wait;

integer getOwnerSubStr(key id) {
    return (-1 * (integer) ("0x" + llGetSubString((string) id,-5,-1)));
}

setup() {
    integer ncd = getOwnerSubStr(llGetOwner()) - 6011;

    if (cd6011 != ncd) {
        // reset listen_cd6011 (?)
        llListenRemove(listen_cd6011);
        cd6011 = ncd;
        listen_cd6011 = llListen(cd6011, "", "", "");
        cd6200 = cd6011 - 122;
    }
}

default {
    state_entry() { llMessageLinked(LINK_THIS, 999, llGetScriptName(), NULL_KEY); }

    timer() {
        // countdown...
        wait -= 1;
        if (wait == 0) {
            llSetTimerEvent(0.0);
            llAllowInventoryDrop(FALSE);
        }
    }

    link_message(integer sender, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);

        if (code == 104 || code == 105) {
            if (llList2String(split, 0) != "Start") return;
            setup();
            llMessageLinked(LINK_THIS, code, llGetScriptName(), NULL_KEY);
        }
    }

    listen(integer channel, string name, key id, string choice) {
        if (channel == cd6011) {
            if (llGetSubString(choice,0,2) == "-~-") {
                string todelete = llGetSubString(choice,3,-1);

                llOwnerSay(todelete + " is being removed.");
                llRemoveInventory(todelete);
            }
            else if ( choice == "~getpin") {
                integer newpin = (integer) llFrand(-500000.0) - 19;
                llSetRemoteScriptAccessPin(newpin);
                integer ncd = getOwnerSubStr(id) - 6013; //not needed?
                llSay(cd6200,(string)newpin);
            }
            else {
                if (llGetInventoryType(choice) != -1) {
                    llRemoveInventory(choice);
                }
                llAllowInventoryDrop(TRUE);

                integer ncd = getOwnerSubStr(llGetOwner()) - 6013;
                llSay(ncd + 7, choice);

                // Timer set...
                wait = 15;
                llSetTimerEvent(10.0);
                //presumably no need to listen?
            }
        }
    }
}
