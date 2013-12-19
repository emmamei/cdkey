// 1 "Start.lslp"
// 1 "<built-in>"
// 1 "<command-line>"
// 1 "Start.lslp"
// Start.lsl
//
// DATE: 18 December 2012
//
// 1 "include/GlobalDefines.lsl" 1
// include/GlobalDefines.lsl
//
// Global preprocessor and variable definitions for the key
//
// 32 "include/GlobalDefines.lsl"
// Link messages
// 41 "include/GlobalDefines.lsl"
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
// 48 "include/GlobalDefines.lsl" 2
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

        llMessageLinked(LINK_SET, 300, "windRate" + "|" + (string)windRate,NULL_KEY);
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
        llMessageLinked(LINK_SET, 300, "globalFlags" + "|" + "0x" + bits2nybbles(globalFlags),NULL_KEY);
        return 1;
    }
    else return 0;
}
// 49 "include/GlobalDefines.lsl" 2
// 6 "Start.lslp" 2

//#define HYPNO_START   // Enable hypno messages on startup
//
// This is the initial hypnotic suggestion and RolePlay
// called from Main.lsl.  The text is sent to the Key
// owner over the space of about three minutes when the
// Key is first used.
//
// As of 30 October 2013, this script is unused.

float delayTime = 15.0; // in seconds

key dollID = NULL_KEY;
key MistressID = NULL_KEY;

string dollName;

key ncPrefsKey;
key ncPrefsLoadedUUID = NULL_KEY;
string ncName = "Preferences";
integer ncLine;
integer replyHandle;

float ncStart;
integer lastAttachPoint;
key lastAttachAvatar;

list knownScripts;
list readyScripts;
integer quiet;
integer startup = 1;
integer reset;
integer rlvWait;
integer RLVok;
// 48 "Start.lslp"
//---------------------------------------
// Configuration Functions
//---------------------------------------
// This code assumes a human-generated config file
processConfiguration(string name, list values) {
    //----------------------------------------
    // Assign values to program variables

    string value = llList2String(values,0);

    list validConfig = [ "initial time", "wind time", "max time", "doll type", "helpless dolly", "controller",
                         "auto tp", "can fly", "outfitable", "pleasure doll", "detachable", "barefeet path",
                         "user startup rlv", "user collapse rlv", "quiet key" ];

    if (llListFindList(validConfig, [ name ]) != -1) {
        if (name == "initial time") {
            llMessageLinked(LINK_SET, 300, "timeLeftOnKey" + "|" + (string)((float)value * 60.0),NULL_KEY);
        }
        else if (name == "wind time") {
            llMessageLinked(LINK_SET, 300, "wind time" + "|" + (string)((float)value * 60.0),NULL_KEY);
        }
        else if (name == "max time") {
            llMessageLinked(LINK_SET, 300, "max time" + "|" + (string)((float)value * 60.0),NULL_KEY);
        }
        else if (name == "barefeet path") {
            llMessageLinked(LINK_SET, 300, "barefeet" + "|" + value,NULL_KEY);
        }
        else if (name == "user startup rlv") {
            llMessageLinked(LINK_SET, 300, "userBaseRLVcmd" + "|" + value,NULL_KEY);
        }
        else if (name == "user collapse rlv") {
            llMessageLinked(LINK_SET, 300, "userCollapseRLVcmd" + "|" + value,NULL_KEY);
        }
        else if (name == "helpless dolly") {
            llMessageLinked(LINK_SET, 300, "helpless" + "|" + value,NULL_KEY);
        }
        else if (name == "auto tp") {
            llMessageLinked(LINK_SET, 300, "autoTP" + "|" + value,NULL_KEY);
        }
        else if (name == "pleasure doll") {
            llMessageLinked(LINK_SET, 300, "pleasureDoll" + "|" + value,NULL_KEY);
        }
        else if (name == "detachable") {
            llMessageLinked(LINK_SET, 300, "detachable" + "|" + value,NULL_KEY);
        }
        else if (name == "outfitable") {
            llMessageLinked(LINK_SET, 300, "canDress" + "|" + value,NULL_KEY);
        }
        else if (name == "can fly") {
            llMessageLinked(LINK_SET, 300, "canFly" + "|" + value,NULL_KEY);
        }
        else if (name == "can sit") {
            llMessageLinked(LINK_SET, 300, "canSit" + "|" + value,NULL_KEY);
        }
        else if (name == "can stand") {
            llMessageLinked(LINK_SET, 300, "canStand" + "|" + value,NULL_KEY);
        }
        else if (name == "quiet key") {
            quiet = (integer)value;
            llMessageLinked(LINK_SET, 300, "quiet" + "|" + value,NULL_KEY);
        }
    }
    //--------------------------------------------------------------------------
    // Disabled for future use, allows for extention scripts to add support for
    // their own peferences by using names starting with the prefix 'ext'. These
    // are sent with a different link code to prevent clashes with built in names
    //--------------------------------------------------------------------------
    //else if (llGetSubString(name, 0, 2) == "ext") {
    //    string param = "|" + llDumpList2String(values, "|");
    //    llMessageLinked(LINK_SET, 101, name + param, NULL_KEY);
    //}
    else {
        llOwnerSay("Unknown configuration value: " + name + " on line " + (string)(ncLine + 1));
    }
}

sendMsg(key target, string msg) {
    if (llGetSubString(msg, 0, 0) == "%" && llGetSubString(msg, -1, -1) == "%") {
        msg = findString(msg);
    }

    if (target == dollID) llOwnerSay(msg);
    else if (llGetAgentSize(target)) llRegionSayTo(target, 0, msg);
    else llInstantMessage(target, msg);
}

string findString(string msg) {
    if (msg == "%TEXT_HELP%") return "Commands:\n\n
    detach ......... detach key if possible\n
    stat ........... concise current status\n
    stats .......... selected statistics and settings\n
    xstats ......... extended statistics and settings\n
    poses .......... list all poses\n
    help ........... this list of commands\n
    wind ........... trigger emergency autowind\n
    demo ........... toggle demo mode\n
    channel ........ change channel\n\n";
    else return "";
}

initConfiguration() {
    sendMsg(dollID, "Loading preferences notecard");
    ncStart = llGetTime();

    // Check to see if the file exists and is a notecard
    if (llGetInventoryType(ncName) == INVENTORY_NOTECARD) {

        // Start reading from first line (which is 0)
        ncLine = 0;
        ncPrefsKey = llGetNotecardLine(ncName, ncLine);

    } else {

        // File missing - report for debugging only
        sendMsg(dollID, "No configuration found (" + ncName + ")");
    }
}

doneConfiguration() {
    if (startup) {
        ncPrefsLoadedUUID = llGetInventoryKey(ncName);
        //sendMsg(dollID, (string)ncPrefsLoadedUUID);
        llMessageLinked(LINK_SET, 102, "", NULL_KEY);
        startup = 0;

        sendMsg(dollID, "Preferences read in " + formatFloat(llGetTime() - ncStart, 2) + "s");

    }

    llSleep(1);

    string msg = "Initialization completed";

    msg += " in " + formatFloat(llGetTime(), 2) + "s";

    msg += " key ready";
    sendMsg(dollID, msg);
    if (!quiet && llGetAttached() == ATTACH_BACK)
        llSay(0, llGetDisplayName(llGetOwner()) + " is now a dolly - anyone may play with their Key.");


    llMessageLinked(LINK_SET, 135, llGetScriptName(), NULL_KEY);

}

list notReady() {
    list waiting; integer loop;
    for (loop = 0; loop < llGetListLength(knownScripts); loop++) {
        string script = llList2String(knownScripts, loop);
        if (llListFindList(readyScripts, [ script ]) == -1 && llGetScriptState(script)) waiting += script;
    }
    return waiting;
}

default {
    link_message(integer source, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);
// 228 "Start.lslp"
        if (code == 11) {


            sendMsg(id, llList2String(split,0));
        }
        else if (code == 103) {
            if (llListFindList(readyScripts, [ llList2String(split,0) ]) == -1) {
                readyScripts += llList2String(split,0);
            }
            if (llList2String(split,0) == "RLV") {
                if (startup) initConfiguration();
                else doneConfiguration();
            }
        }

        else if (code == 135) memReport();

        else if (code == 300) {
            string name = llList2String(split, 0);
            integer value = llList2Integer(split, 1);

/*                 if (name == "afk")                 afk = (integer)value;
            else if (name == "autoTP")              autoTP = (integer)value;
            else if (name == "canAFK")              canAFK = (integer)value;
            else if (name == "canCarry")            canCarry = (integer)value;
            else if (name == "canDress")            canDress = (integer)value;
            else if (name == "canFly")              canFly = (integer)value;
            else if (name == "canSit")              canSit = (integer)value;
            else if (name == "canStand")            canStand = (integer)value;
            else if (name == "isCollapsed")         collapsed = (integer)value;
            else if (name == "isConfigured")        configured = (integer)value;
            else if (name == "isDetachable")        detachable = (integer)value;
            else if (name == "isHelpless")          helpless = (integer)value;
            else if (name == "isPleasureDoll")      pleasureDoll = (integer)value;
            else if (name == "isTransformingKey")   transformingKey = (integer)value;
            else if (name == "isVisible")           visible = (integer)value;
            else if (name == "quiet")               quiet = (integer)value;
            else if (name == "RLVok")               RLVok = (integer)value;
            else if (name == "signOn")              signOn = (integer)value;
            else if (name == "takeoverAllowed")     takeoverAllowed = (integer)value;*/
        }
        else if (code == 350) {
            RLVok = llList2Integer(split, 0);
            rlvWait = 0;
        }
        else if (code == 500) {
            string selection = llList2String(split, 0);

            if (selection == "Reset Scripts" && id == dollID) {
                if (RLVok)
                    llOwnerSay("Unable to reset scripts while running with RLV enabled, please relog without RLV disabled or " +
                                "you can use login a Linden Lab viewer to perform a script reset.");
                else if (rlvWait && (llGetTime() < 180.0))
                    llOwnerSay("Key is currently still checking your RLV status please wait until the check completes and then try again.");
                else {
                    if ((MistressID != NULL_KEY)) {
                        sendMsg(MistressID, dollName + " is resetting the script in her key, if you are not in her preferences notecard " +
                                            "you will no longer be her controller when the process completes.");
                    }
                    llResetScript();
                }
            }
        }
        else if (code == 999) {
            if (reset) llResetScript();
        }
    }

    state_entry() {
        rlvWait = 1;
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);

        llTargetOmega(<0,0,0>,0,0);

        llSetObjectName(llList2String(llGetLinkPrimitiveParams(24, [ PRIM_DESC ]), 0) + " " + "18/Dec/13");

        string me = llGetScriptName();
        integer loop; string script;

        llOwnerSay("Resetting scripts");

        for (loop = 0; loop < llGetInventoryNumber(INVENTORY_SCRIPT); loop++) {
            script = llGetInventoryName(INVENTORY_SCRIPT, loop);
            if (script != me) {
                knownScripts += script;
                llResetOtherScript(script);
            }
        }

        llSetTimerEvent(2);
    }

    on_rez(integer start) {
        rlvWait = 1;
        if (startup) llResetScript();

        llTargetOmega(<0,0,0>,0,0);

        llResetTime();
        string me = llGetScriptName();
        integer loop; string script;

        sendMsg(dollID, "Starting initialization");
        knownScripts = [];
        readyScripts = [];

        for (loop = 0; loop < llGetInventoryNumber(INVENTORY_SCRIPT); loop++) {
            script = llGetInventoryName(INVENTORY_SCRIPT, loop);
            if (script != me) knownScripts += script;
        }

        llSetTimerEvent(120);

        llMessageLinked(LINK_SET, 105, llGetScriptName(), NULL_KEY);
    }

    attach(key id) {
        if (id == NULL_KEY) {
            llMessageLinked(LINK_SET, 106, "detached|" + (string)lastAttachPoint, lastAttachAvatar);
            if (lastAttachPoint == ATTACH_BACK) {
                llOwnerSay("The key is wrenched from your back, and you double over at the " +
                           "unexpected pain as the tendrils are ripped out. You feel an emptiness, " +
                           "as if some beautiful presence has been removed.");
            }
        } else {
            llMessageLinked(LINK_SET, 106, "attached|" + (string)llGetAttached(), id);

            if (llGetAttached() != ATTACH_BACK) {
                llMessageLinked(LINK_SET, 311, "windDown|0", id);

                llOwnerSay("Your key stubbornly refuses to attach itself, and you " +
                           "belatedly realize that it must be attached to your spine.");
                llOwnerSay("@clear,detachme=force");

                llSleep(3);
                llDetachFromAvatar();
            }

            lastAttachPoint = llGetAttached();
            lastAttachAvatar = id;
        }
    }

    dataserver(key query_id, string data) {
        if (query_id == ncPrefsKey) {
            if (data == EOF) {
                doneConfiguration();
            } else {
                if (data != "" && llGetSubString(data, 0, 0) != "#") {
                    integer index = llSubStringIndex(data, "=");
                    string name = llGetSubString(data, 0, index - 1);
                    string value = llGetSubString(data, index + 1, -1);
                    name = llStringTrim(llToLower(name), STRING_TRIM);
                    value = llStringTrim(value, STRING_TRIM);
                    list split = llParseString2List(value, [ "|" ], []);
                    processConfiguration(name, split);
                }
                ncPrefsKey = llGetNotecardLine(ncName, ++ncLine);
            }
        }
    }

    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            if (ncPrefsLoadedUUID != NULL_KEY && llGetInventoryKey(ncName) != ncPrefsLoadedUUID) {
                // Get a unique number
                integer ncd = -1 * (integer)("0x" + llGetSubString((string)llGetKey(),-7,-1));
                integer channel = ncd - 5467;
                replyHandle = llListen(channel, "", "", "");

                llSetTimerEvent(60);
                llDialog(llGetOwner(), "Detected a change in your Preferences notecard, would you like to load the new settings?\n\n" +
                  "WARNING: All current data will be lost!", [ "Reload Config", "Keep Settings" ], channel);
            }
        }
        if (change & CHANGED_OWNER) {
            llOwnerSay("Deleting old preferences notecard on owner change.");
            llOwnerSay("Look at PreferencesExample to see how to make yours.");
            llRemoveInventory(ncName);
            llSleep(5);
            llResetScript();
        }
    }

    listen(integer channel, string name, key id, string message)
    {
        if (message == "Reload Config") {
            llResetScript();
        }
    }

    timer() {
        llListenRemove(replyHandle);
        llSetTimerEvent(0);

        if (!reset) {
            llOwnerSay("Starting initialization");
            reset = 1;
            llSetTimerEvent(120);

            llMessageLinked(LINK_SET, 104, llGetScriptName() + "|1", NULL_KEY);



        }
        else if (startup) {
            sendMsg(dollID, "Startup failure detected one or more scripts may have crashed, resetting");


            sendMsg(dollID, "The following scripts did not report: " + llList2CSV(notReady()));

        }
    }
}
