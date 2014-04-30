//========================================
// Start.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 25 February 2014

#include "include/Json.lsl"
#include "include/GlobalDefines.lsl"
#define sendMsg(id,msg) lmSendToAgent(msg, id);

#define RUNNING 1
#define NOT_RUNNING 0
#define YES 1
#define NO 0
#define NOT_FOUND -1
#define UNSET -1
#define cdRunScript(a) llSetScriptState(a, RUNNING);
#define cdStopScript(a) llSetScriptState(a, NOT_RUNNING);

#define PREFS_READ 1
#define PREFS_NOT_READ 0

// This isn't great - but at least it's up here where it can be maintained
// Note, too, that Start is missing - because that's THIS script...
//
// LinkListen *could* be added for developers, but that is an optional script -
// still - so not necessarily good to add here.
list scriptList = [ "Aux", "Avatar", "ChatHandler", "Dress", "Main", "MenuHandler",
                    "ServiceRequester", "ServiceReceiver", "StatusRLV", "Transform" ];

//#define HYPNO_START   // Enable hypno messages on startup
//
// This is the initial hypnotic suggestion and RolePlay
// called from Main.lsl.  The text is sent to the Key
// owner over the space of about three minutes when the
// Key is first used.
//
// As of 30 October 2013, this script is unused.

//=======================================
// VARIABLES
//=======================================
float delayTime = 15.0; // in seconds
//float nextIntro;
#ifdef DEVELOPER_MODE
float initTimer;
#endif
float nextLagCheck;

key dollID = NULL_KEY;
key MistressID = NULL_KEY;

string dollName;
string dollyName;
string appearanceData;

#define APPEARANCE_NC "DataAppearance"
#define NC_ATTACHLIST "DataAttachments"
key ncPrefsKey;
list ncPrefsLoadedUUID;
key ncIntroKey;
key ncResetAttach;
key ncRequestAppearance;

float timeLeftOnKey;
float keyLimit;
integer ncLine;
integer demoMode;

#ifdef DEVELOPER_MODE
float ncStart;
#endif
integer lastAttachPoint;
key lastAttachAvatar;

list controllers;
list blacklist;
list recentDilation;
//list windTimes;

integer quiet = NO;
integer newAttach = YES;
integer autoTP = NO;
integer canFly = YES;
integer canSit = YES;
integer canStand = YES;
integer canDress = YES;
integer detachable = YES;
integer busyIsAway = NO;
integer offlineMode = YES;
integer visible = YES;
integer primGlow = YES;
integer primLight = YES;
integer dbConfigCount;

vector gemColour;

string barefeet;
string dollType;
string attachName;
string saveAttachment = "{\"chest\":[\"<0.000000, 0.184040, -0.279770>\",\"<1.000000, 0.000000, 0.000000, 0.000000>\"],\"spine\":[\"<0.000000, -0.200000, 0.000000>\",\"<0.000000, 0.000000, 0.000000, 1.000000>\"]}";
string userAfkRLVcmd;
string userBaseRLVcmd;
string userCollapseRLVcmd;
string userPoseRLVcmd;
string dollGender = "Female";
string pronounHerDoll = "Her";
string pronounSheDoll = "She";
//string nameOverride;
//integer startup;
//integer initState = 104;
integer introLine;
integer introLines;
integer reset;
integer rlvWait;
integer RLVok = UNSET;
integer databaseFinished;
integer databaseOnline;

float keyLimit;

integer afk;
#ifdef SIM_FRIENDLY
integer lowScriptMode;
#endif

//=======================================
// FUNCTIONS
//=======================================
doVisibility() {
    vector colour = gemColour;

    if (llGetInventoryType(APPEARANCE_NC) == INVENTORY_NOTECARD) {

        if (!visible || !primGlow || collapsed) {
            llSetLinkPrimitiveParamsFast(LINK_SET, [ PRIM_GLOW, ALL_SIDES, 0.0 ]);
        }
        else {

            integer i;
            integer j;
            integer type;
            integer typeval;
            list params;
            list types = [ "Light", 23, "Glow", 25 ];
            string name;
            string typeName;
            integer typeLen = llGetListLength(types)/2;

            for (; type < typeLen; ++type) {
                typeName = llList2String(types, type * 2);

                for (i = 1; i < llGetNumberOfPrims(); i++) {

                    name = llGetLinkName(i);
                    params += [ PRIM_LINK_TARGET, i ];

                    if (cdGetElementType(appearanceData,([name,typeName])) != JSON_INVALID) {

                        typeval = llList2Integer(types, llListFindList(types, [typeName]) + 1);

                        if (typeName == "Light") {
                            //if (colour == ZERO_VECTOR) colour = (vector)llList2String(llGetLinkPrimitiveParams(i,[PRIM_DESC]),0);
                            if (colour == ZERO_VECTOR) colour = (vector)llList2String(params,1);
                            params += [ typeval, (primLight & !collapsed), colour, 0.5, 2.5, 2.0 ];
                        }

                        while(cdGetElementType(appearanceData,([name,typeName,j])) != JSON_INVALID) {
                            if (typeName == "Glow")
                                params += [ 25 ] + llJson2List(cdGetValue(appearanceData,([name,typeName,j++])));
                        }
                    }
                }
            }
            llSetLinkPrimitiveParamsFast(0, params);
        }
    }
}

//---------------------------------------
// Configuration Functions
//---------------------------------------

processConfiguration(string name, string value) {

    //----------------------------------------
    // Assign values to program variables

         if (value == "yes" || value == "on")  value = "1";
    else if (value == "no"  || value == "off") value = "0";

    integer i;
    //list firstWord = [ "barefeet path", "helpless dolly", "quiet key" ];
    //list capSubsiquent = [ "busy is away", "can afk", "can fly", "can pose", "can sit", "can stand", "can wear", "detachable", "doll type", "pleasure doll", "pose silence" ];
    //list rlv = [ "afk rlv", "base rlv", "collapse rlv", "pose rlv" ];

    list configs = [ "barefeet path", "helpless dolly", "quiet key",
                     "busy is away", "can afk", "can fly", "can pose", "can sit", "can stand", "can wear", "detachable", "doll type", "pleasure doll", "pose silence", "auto tp", "outfitable", "initial time", "max time",
                     "afk rlv", "base rlv", "collapse rlv", "pose rlv" ];
    list sendName = [ "barefeet", "helpless", "quiet",
                     "busyIsAway", "canAfk", "canFly", "canPose", "canSit", "canStand", "canWear", "detachable", "dollType", "pleasureDoll", "poseSilence", "autoTP", "canDress", "timeLeftOnKey", "keyLimit",
                     "userAfkRLVcmd", "userBaseRLVcmd", "userCollapseRLVcmd", "userPoseRLVcmd" ];

    list internals = [ "wind time", "blacklist name", "controller name" ];
    list cmdName = [ "setWindtimes", "getBlacklistName", "getMistressName" ];

    // This processes a single line from the preferences notecard...
    // processing done a single time during the read of the nc belong elsewhere

    name = llToLower(name);
    if ((i = cdListElementP(configs,name)) != NOT_FOUND) {
        if (name == "initial time") {
            if (!databaseOnline || offlineMode)
                value = (string)((float)value * SEC_TO_MIN);
        } if (name == "max time") {
            value = (string)((float)value * SEC_TO_MIN);
        }

        lmSendConfig(cdListElement(sendName,i), value);
    }
    else if ((i = cdListElementP(internals,name)) != NOT_FOUND) {
        lmInternalCommand(cdListElement(cmdName,i), value, NULL_KEY);
    }
    else if (name == "doll gender") {
        setGender(value);
    }
    else if (name == "blacklist") {
        if (llListFindList(blacklist, [ value ]) == NOT_FOUND)
            lmSendConfig("blacklist", llDumpList2String((blacklist = llListSort(blacklist + [ value, llRequestAgentData((key)value, DATA_NAME) ], 2, 1)), "|"));
    }
    else if (name == "controller") {
        if (llListFindList(controllers, [ value ]) == NOT_FOUND)
            lmSendConfig("controllers", llDumpList2String((controllers = llListSort(controllers + [ value, llRequestAgentData((key)value, DATA_NAME) ], 2, 1)), "|"));
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
#ifdef DEVELOPER_MODE
    else {
        llOwnerSay("Unknown configuration value in preferences: " + name + " on line " + (string)(ncLine + 1));
    }
#endif
}

// Only place gender is currently set is in the preferences
setGender(string gender) {

    if (gender == "male") {
        dollGender     = "Male";
        pronounHerDoll = "His";
        pronounSheDoll = "He";
    }
    else {
        if (gender == "sissy") dollGender = "Sissy";
        else dollGender = "Female";

        pronounHerDoll = "Her";
        pronounSheDoll = "She";
    }

    lmSendConfig("dollGender",     dollGender);
    lmSendConfig("pronounHerDoll", pronounHerDoll);
    lmSendConfig("pronounSheDoll", pronounSheDoll);
}

// PURPOSE: initConfiguration reads the Preferences notecard, if any -
//          and runs doneConfiguration if no notecard is found

initConfiguration() {
#ifdef DEVELOPER_MODE
    ncStart = llGetTime();
#endif

    // Check to see if the file exists and is a notecard
    if (llGetInventoryType(NOTECARD_PREFERENCES) == INVENTORY_NOTECARD) {
        llOwnerSay("Loading Key Preferences Notecard");

        // Start reading from first line (which is 0)
        ncLine = 0;
        ncPrefsKey = llGetNotecardLine(NOTECARD_PREFERENCES, ncLine);
    } else {
        // File missing - report for debugging only
        debugSay(1, "DEBUG", "No configuration found (" + NOTECARD_PREFERENCES + ")");

        doneConfiguration(PREFS_NOT_READ);
    }
}

// PURPOSE: doneConfiguration is called from various places,
//          and its real purpose is as yet unknown.

doneConfiguration(integer read) {

    //if (startup == 1 && read) {
    if (read) {
#ifdef DEVELOPER_MODE
        sendMsg(dollID, "Preferences read in " + formatFloat(llGetTime() - ncStart, 2) + "s");
#else
        ;
#endif
    }

    if (reset) {
        llSleep(7.5);
        llResetScript();
    }

    reset = 0;

    lmInitState(102);
    lmInitState(105);

    //startup = 2;

    initializationCompleted();
}

initializationCompleted() {
    if (newAttach && !quiet && cdAttached())
        llSay(0, llGetDisplayName(llGetOwner()) + " is now a dolly - anyone may play with their Key.");

#ifdef DEVELOPER_MODE
    initTimer = llGetTime() * 1000;
#endif

    if (dollyName == "") {
        string name = dollName;
        integer space = llSubStringIndex(name, " ");

        if (space != NOT_FOUND) name = llGetSubString(name, 0, space - 1);

        lmSendConfig("dollyName", (dollyName = "Dolly " + name));
    }

    if (cdAttached()) llSetObjectName(dollyName + "'s Key");

    string msg = "Initialization completed" +
#ifdef DEVELOPER_MODE
                 " in " + formatFloat(initTimer, 2) + "ms" +
#endif
                 "; key ready";

    sendMsg(dollID, msg);

    //startup = 0;

    lmInitState(110);

    if (llGetInventoryType(APPEARANCE_NC) == INVENTORY_NOTECARD) {
        ncLine = 0;
        appearanceData = "";
        ncRequestAppearance = llGetNotecardLine(APPEARANCE_NC, ncLine++);
    }

    llSetTimerEvent(10.0);
}

#ifdef SIM_FRIENDLY
#ifdef WAKESCRIPT
wakeMenu() {
#ifdef DEVELOPER_MODE
    llOwnerSay("Waking menu scripts");
#endif
    //cdRunScript("MenuHandler");
    //cdRunScript("Transform");
    //cdRunScript("Dress");
}

sleepMenu() {
#ifdef DEVELOPER_MODE
    llOwnerSay("Sleeping menu scripts");
#endif
    //cdStopScript("MenuHandler");
    //cdStopScript("Transform");
    //cdStopScript("Dress");
}
#endif
#endif

doRestart() {
    integer loop; string me = cdMyScriptName();
    string script;
    reset = 0;

    llOwnerSay("Resetting scripts");

    // Set all other scripts to run state and reset them
    for (; loop < llGetInventoryNumber(INVENTORY_SCRIPT); loop++) {

        script = llGetInventoryName(INVENTORY_SCRIPT, loop);
        if (script != me) {
            cdRunScript(script);
            llResetOtherScript(script);
        }
    }

    reset = 0;

    ncResetAttach = llGetNotecardLine(NC_ATTACHLIST, cdAttached() - 1);
}

//========================================
// STATES
//========================================
default {

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer source, integer i, string data, key id) {

        // Parse link message header information
        list split        =     cdSplitArgs(data);
        string script     =     cdListElement(split, 0);
        integer remoteSeq =     (i & 0xFFFF0000) >> 16;
        integer optHeader =     (i & 0x00000C00) >> 10;
        integer code      =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        scaleMem();

        if (code == 102) {
            if (script != "ServiceReceiver") return;

            databaseFinished = 1;
            if (!databaseOnline) {
                llOwnerSay("Database not online...");
                initConfiguration();
            }
            if (llListFindList(ncPrefsLoadedUUID,[(string)llGetInventoryKey(NOTECARD_PREFERENCES)]) == NOT_FOUND) {
                llOwnerSay("Didn't find original prefs");
                initConfiguration();
            }
            else {
                debugSay(2, "DEBUG", "Skipping preferences notecard as it is unchanged and settings were found in database.");
                doneConfiguration(PREFS_NOT_READ); // this calls "code = 102"
            }
        }
        else if (code == 135) {
            if (script == cdMyScriptName()) return;

            float delay = llList2Float(split, 0);
            memReport(cdMyScriptName(),delay);
        }
        else

        cdConfigReport();

        else if (code == 300) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);

            if (value == RECORD_DELETE) {
                value = "";
                split = [];
            }

            if (script == "ServiceReceiver") dbConfigCount++;

                 if (name == "ncPrefsLoadedUUID")    ncPrefsLoadedUUID = llDeleteSubList(split,0,0);
            else if (name == "offlineMode")                offlineMode = (integer)value;
            else if (name == "databaseOnline")          databaseOnline = (integer)value;
#ifdef SIM_FRIENDLY
            else if (name == "lowScriptMode")            lowScriptMode = (integer)value;
#endif
            else if (name == "dialogChannel")            dialogChannel = (integer)value;
            else if (name == "demoMode")                      demoMode = (integer)value;
            else if (name == "quiet")                            quiet = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                  debugLevel = (integer)value;
#endif
            else if (name == "keyLimit")                      keyLimit = (float)value;
            else if (name == "userBaseRLVcmd")          userBaseRLVcmd = value;
            else if (name == "userCollapseRLVcmd")  userCollapseRLVcmd = value;
            else if (name == "userPoseRLVcmd")          userPoseRLVcmd = value;
            else if (name == "userAfkRLVcmd")            userAfkRLVcmd = value;

            else if ((name == "gemColour") ||
                     (name == "primGlow")  ||
                     (name == "primLight") ||
                     (name == "isVisible") ||
                     (name == "collapsed")) {

                     if (name == "gemColour")       gemColour = (vector)value;
                else if (name == "primGlow")         primGlow = (integer)value;
                else if (name == "primLight")       primLight = (integer)value;
                else if (name == "isVisible")         visible = (integer)value;
                else if (name == "collapsed")       collapsed = (integer)value;
                
                doVisibility();
            }

            else if ((name == "dollyName") && (script != cdMyScriptName())) {
                dollyName = value;

                if (dollyName == "") {
                    string name = dollName;
                    integer space = llSubStringIndex(name, " ");

                    if (space != NOT_FOUND) name = llGetSubString(name, 0, space -1);
                    //llOwnerSay("INIT:300: dollyName = " + dollyName + " (send to 300)");

                    lmSendConfig("dollyName", (dollyName = "Dolly " + name));
                }
                //llOwnerSay("INIT:300: dollyName = " + dollyName + " (setting)");
                if (cdAttached()) llSetObjectName(dollyName + "'s Key");
            }

            // Run user RLV settings in appropriate situations
            if ((name == "collapsed") && (userCollapseRLVcmd != "")) {
                if (collapsed) lmRunRLVas("UserCollapse", userCollapseRLVcmd);
                else lmRunRLVas("UserCollapse", "clear");
            }
            else if ((name == "afk") && (userAfkRLVcmd != "")) {
                if (afk) lmRunRLVas("UserAfk", userAfkRLVcmd);
                else lmRunRLVas("UserAfk", "clear");
            }
            else if ((name == "keyAnimation") && (userPoseRLVcmd != "")) {
                if (!cdNoAnim() && !cdCollapsedAnim()) lmRunRLVas("UserPose", userPoseRLVcmd);
                else lmRunRLVas("UserPose", "clear");
            }
        }

        else if (code == 350) {
            RLVok = (llList2Integer(split, 0) == 1);
            rlvWait = 0;

            if (!newAttach && cdAttached()) {
                string msg = dollName + " has logged in with";

                if (!RLVok) msg += "out";
                msg += " RLV at " + wwGetSLUrl();

                lmSendToController(msg);
            }

            if (collapsed) lmRunRLVas("UserCollapse", userCollapseRLVcmd);
            else lmRunRLVas("UserCollapse", "clear");

            if (afk) lmRunRLVas("UserAfk", userAfkRLVcmd);
            else lmRunRLVas("UserAfk", "clear");

            if (!cdNoAnim() && !cdCollapsedAnim()) lmRunRLVas("UserPose", userPoseRLVcmd);
            else lmRunRLVas("UserPose", "clear");

            newAttach = 0;
        }
        else if (code == 500) {
            string selection = llList2String(split, 0);
            string name = llList2String(split, 1);

            if (selection == "Reset Scripts") {
                if (cdIsController(id)) llResetScript();
//              else if (id == dollID) {
//                  if (RLVok == YES)
//                      llOwnerSay("Unable to reset scripts while running with RLV enabled, please relog without RLV disabled or " +
//                                  "you can use login a Linden Lab viewer to perform a script reset.");
//                  else if (RLVok == UNSET && (llGetTime() < 300.0))
//                      llOwnerSay("Key is currently still checking your RLV status please wait until the check completes and then try again.");
//                  else llResetScript();
//              }
            }

            nextLagCheck = llGetTime() + SEC_TO_MIN;
        }
    }


    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);

        rlvWait = 1;
        cdInitializeSeq();
        reset = 2;

        if (cdAttached()) llRequestPermissions(dollID, PERMISSION_MASK);
        else {
            llOwnerSay("Key not attached");
            llSetObjectName(PACKAGE_NAME + " " + __DATE__);
        }

        doRestart();
    }

    //----------------------------------------
    // TOUCH START
    //----------------------------------------
    touch_start(integer num) {
        if (cdAttached()) llRequestPermissions(dollID, PERMISSION_MASK);

#ifdef SIM_FRIENDLY
#ifdef WAKESCRIPT
        if (!llGetScriptState("MenuHandler")) wakeMenu();
#endif
        nextLagCheck = llGetTime() + SEC_TO_MIN;
#endif
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);

        if (cdAttached()) llRequestPermissions(dollID, PERMISSION_MASK);
        else llSetObjectName(PACKAGE_NAME + " " + __DATE__);

        RLVok = UNSET;
        //startup = 2;

        databaseOnline = 0;
        databaseFinished = 0;

#ifdef SIM_FRIENDLY
#ifdef WAKESCRIPT
        wakeMenu();
#endif
#endif
        llResetTime();
        sendMsg(dollID, "Reattached, Initializing");
    }

    //----------------------------------------
    // ATTACH
    //----------------------------------------
    attach(key id) {
        if (id == NULL_KEY) {
            if(!cdAttached()) llSetObjectName(PACKAGE_NAME + " " + __DATE__);
            llMessageLinked(LINK_SET, 106,  cdMyScriptName() + "|" + "detached" + "|" + (string)lastAttachPoint, lastAttachAvatar);
            llOwnerSay("The key is wrenched from your back, and you double over at the unexpected pain as the tendrils are ripped out. You feel an emptiness, as if some beautiful presence has been removed.");
        } else {
            llMessageLinked(LINK_SET, 106, cdMyScriptName() + "|" + "attached" + "|" + (string)llGetAttached(), id);

            if (llGetPermissionsKey() == dollID && (llGetPermissions() & PERMISSION_TAKE_CONTROLS) != 0) llTakeControls(CONTROL_MOVE, 1, 1);
            else llRequestPermissions(dollID, PERMISSION_MASK);

            ncResetAttach = llGetNotecardLine(NC_ATTACHLIST, cdAttached() - 1);

            if (lastAttachAvatar == NULL_KEY) newAttach = 1;
        }

        lastAttachPoint = cdAttached();
        lastAttachAvatar = id;
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key query_id, string data) {
        if (query_id == ncResetAttach) {
            data = llStringTrim(data,STRING_TRIM);

            if (cdAttached())
                llSetPrimitiveParams([PRIM_POS_LOCAL,
                    (vector)cdGetValue(saveAttachment,([data,0])),
                    PRIM_ROT_LOCAL,
                    (rotation)cdGetValue(saveAttachment,([data,1]))]);

            attachName = data;

            llSetTimerEvent(10.0);
        }
        else if (query_id == ncRequestAppearance) {
            if (data == EOF) {
                doVisibility();
                configured = 1;
                ncRequestAppearance = NULL_KEY;
            }
            else {
                data = llStringTrim(data,STRING_TRIM);

                // Search for "ALL" (with quotes) in data and replace
                // with "-1" (without quotes) - is this necessary?
                string find = "\"ALL\""; integer index;
                while ((index = llSubStringIndex(data, find)) != NOT_FOUND) {
                    data = llInsertString(llDeleteSubString(data, index, index + llStringLength(find) - 1), index, "-1");
                }

                appearanceData += data;
                ncRequestAppearance = llGetNotecardLine(APPEARANCE_NC, ncLine++);
            }
        }
        else if (query_id == ncPrefsKey) {
            if (data == EOF) {
                lmSendConfig("ncPrefsLoadedUUID", llDumpList2String(llList2List((string)llGetInventoryKey(NOTECARD_PREFERENCES) + ncPrefsLoadedUUID, 0, 9),"|"));
                lmInternalCommand("getTimeUpdates","",NULL_KEY);

                doneConfiguration(PREFS_READ);
            }
            else {
                integer index = llSubStringIndex(data, "#");

                if (index != NOT_FOUND) data = llDeleteSubString(data, index, -1);

                if (data != "") {
                    index = llSubStringIndex(data, "=");

                    // name is "lval" and value is "rval" split by equals
                    string name = llToLower(llStringTrim(llGetSubString(data,  0, index - 1),STRING_TRIM));
                    string value =          llStringTrim(llGetSubString(data, index + 1, -1),STRING_TRIM) ;

                    // this is the heart of preferences processing
                    processConfiguration(name, value);
                }

                // get next Notecard Line
                ncPrefsKey = llGetNotecardLine(NOTECARD_PREFERENCES, ++ncLine);
            }
        }
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if(!cdAttached()) llSetObjectName(PACKAGE_NAME + " " + __DATE__);

        if (change & CHANGED_OWNER) {

            if (llGetInventoryType(NOTECARD_PREFERENCES) != INVENTORY_NONE) {
                llOwnerSay("Deleting old preferences notecard on owner change.\n" +
                    "Look at PreferencesExample to see how to make yours.");
                llRemoveInventory(NOTECARD_PREFERENCES);
            }

            llSleep(5.0);
            llResetScript();
        }

        if (change & CHANGED_INVENTORY) {
            if (llGetInventoryType(NOTECARD_PREFERENCES) == INVENTORY_NOTECARD) {
                string ncKey = (string)llGetInventoryKey(NOTECARD_PREFERENCES);

                // Did Notecard change? (that is, did its UUID change?)
                if (llListFindList(ncPrefsLoadedUUID,[ncKey]) == NOT_FOUND) {
                    reset = 1;

                    sendMsg(dollID, "Reloading preferences card");
#ifdef DEVELOPER_MODE
                    ncStart = llGetTime();
#endif

                    // Start reading from first line (which is 0)
                    ncLine = 0;
                    ncPrefsKey = llGetNotecardLine(NOTECARD_PREFERENCES, ncLine);

                    return;
                }
            }

            llOwnerSay("Inventory modified restarting in 60 seconds.");
            cdLinkMessage(LINK_THIS, 0, 301, "", llGetKey());
            llSleep(60.0);

            llResetScript();
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
        float t = llGetTime();

        // If the script has been running longer than 5 minutes, then
        // scale back to 60s cycles, otherwise, use 15s cycles
        if (t >= 300.0) llSetTimerEvent(60.0);
        else llSetTimerEvent(15.0);

        // Check to see if database startup timed out
        if (!databaseOnline ||
            (!databaseFinished && (
            (t > 60.0) || (
            (t > 10.0) &&
            (t > dbConfigCount))))) {
                databaseFinished = 1;
                databaseOnline = 0;
                initConfiguration();
        }

#ifdef NO_STARTUP
        if (startup != 0) {
            // Check each script to see that they are running...
            // Is this appropriate?

            integer i; integer n = llGetListLength(scriptList);

            for (i = 0; i < n; i++) {
                string script = cdListElement(scriptList,i);

                if (!llGetScriptState(script)) {
                    // Core key script appears to have suffered a fatal error try restarting

#ifdef DEVELOPER_MODE
                    float delay = 90.0;  // Increase delay for automatic restarts;
                                         // this prevents rapidly looping in the event of a developer
                                         // accidently saving a script that fails to compile.
#else
                    float delay = 30.0;
#endif
                    llOwnerSay("Script " + script + " has failed; key subsystems restarting in " + (string)delay + " seconds.");
                    llSleep(delay);

                    cdRunScript(script);
                    llResetScript();
                }
            }
        }
#endif
        else {
            if (!cdAttached() || (attachName == "")) return;

            saveAttachment = cdSetValue(saveAttachment,([attachName,0]),(string)llGetLocalPos());
            saveAttachment = cdSetValue(saveAttachment,([attachName,1]),(string)llGetLocalRot());
        }
    }

    //----------------------------------------
    // RUN TIME PERMISSIONS
    //----------------------------------------
    run_time_permissions(integer perm) {
        if (perm & PERMISSION_TAKE_CONTROLS) {
            llTakeControls(CONTROL_MOVE, 1, 1);

            // Is this the cause of a reset loop? reset never gets away from (2)
            //if (reset == 2) {
            //    llOwnerSay("Permissions resetting");
            //    doRestart();
            //}
        }
    }
}

