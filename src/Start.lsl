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
#define cdMyScriptName() llGetScriptName()
#define cdRunScript(a) llSetScriptState(a, RUNNING);
#define cdStopScript(a) llSetScriptState(a, NOT_RUNNING);

//#define HYPNO_START   // Enable hypno messages on startup
//
// This is the initial hypnotic suggestion and RolePlay
// called from Main.lsl.  The text is sent to the Key
// owner over the space of about three minutes when the
// Key is first used.
//
// As of 30 October 2013, this script is unused.

float delayTime = 15.0; // in seconds
float nextIntro;
float initTimer;
float nextLagCheck;

key dollID = NULL_KEY;
key MistressID = NULL_KEY;

string dollName;
string dollyName;

#define NC_ATTACHLIST "DataAttachments"
key ncPrefsKey;
key ncPrefsLoadedUUID = NULL_KEY;
key ncIntroKey;
key ncResetAttach;
float timeLeftOnKey = UNSET;
integer ncLine;

float ncStart;
integer lastAttachPoint;
key lastAttachAvatar;

list MistressList;
list blacklist;
list recentDilation;
list windTimes;

integer quiet = NO;
integer newAttach = YES;
integer autoTP = NO;
integer canFly = YES;
integer canSit = YES;
integer canStand = YES;
integer canDress = YES;
integer detachable = YES;
integer busyIsAway = NO;
integer offlineMode = NO;

string barefeet;
string dollType;
string attachName;
string saveAttachment = "{\"chest\":[\"<0.000000, 0.184040, -0.279770>\",\"<1.000000, 0.000000, 0.000000, 0.000000>\"],\"spine\":[\"<0.000000, -0.200000, 0.000000>\",\"<0.000000, 0.000000, 0.000000, 1.000000>\"]}";
string userBaseRLVcmd;
string userCollapseRLVcmd;
string dollGender = "Female";
string pronounHerDoll = "Her";
string pronounSheDoll = "She";
//string nameOverride;
integer startup;
integer initState = 104;
integer introLine;
integer introLines;
integer reset;
integer rlvWait;
integer RLVok = UNSET;
integer databaseFinished;
integer databaseOnline;

float keyLimit;

#ifdef SIM_FRIENDLY
integer afk;
integer lowScriptMode;
#endif

//---------------------------------------
// Configuration Functions
//---------------------------------------
// This code assumes a human-generated config file
processConfiguration(string name, list values) {
    //----------------------------------------
    // Assign values to program variables

    string value = llList2String(values,0);

         if (value == "yes" || value == "on")  value = "1";
    else if (value == "no"  || value == "off") value = "0";

    if (name == "initial time") {
        lmSendConfig("timeLeftOnKey", (string)((float)value * SEC_TO_MIN));
    }
    else if (name == "wind time") {
        lmSendConfig("windTimes", llDumpList2String(values, "|"));
    }
    else if (name == "max time") {
        lmSendConfig("keyLimit", (string)((float)value * SEC_TO_MIN));
    }
    else if (name == "barefeet path") {
        lmSendConfig("barefeet", value);
    }
    else if (name == "doll type") {
        lmSendConfig("dollType", value);
    }
    else if (name == "doll gender") {
        setGender(value);
    }

    else if (name == "user startup rlv")  { lmSendConfig("userBaseRLVcmd",     value); }
    else if (name == "user collapse rlv") { lmSendConfig("userCollapseRLVcmd", value); }
    else if (name == "helpless dolly")    { lmSendConfig("helpless",           value); }
    else if (name == "auto tp")           { lmSendConfig("autoTP",             value); }
    else if (name == "pleasure doll")     { lmSendConfig("pleasureDoll",       value); }
    else if (name == "detachable")        { lmSendConfig("detachable",         value); }
    else if (name == "outfitable")        { lmSendConfig("canDress",           value); }
    else if (name == "can fly")           { lmSendConfig("canFly",             value); }
    else if (name == "can sit")           { lmSendConfig("canSit",             value); }
    else if (name == "can stand")         { lmSendConfig("canStand",           value); }

    else if (name == "busy is away") {
        if (busyIsAway != (integer)value) lmSendConfig("busyIsAway", value);
    }
    else if (name == "quiet key") {
        quiet = (integer)value;
        if (quiet != (integer)value) lmSendConfig("quiet", value);
    }
    else if (name == "blacklist") {
        if (llListFindList(blacklist, [ value ]) == NOT_FOUND)
            lmSendConfig("blacklist", llDumpList2String((blacklist = llListSort(blacklist + [ value, llRequestAgentData((key)value, DATA_NAME) ], 2, 1)), "|"));
    }
    else if (name == "controller") {
        if (llListFindList(MistressList, [ value ]) == NOT_FOUND)
            lmSendConfig("MistressList", llDumpList2String((MistressList = llListSort(MistressList + [ value, llRequestAgentData((key)value, DATA_NAME) ], 2, 1)), "|"));
    }
    else if (name == "blacklist name") {
        lmInternalCommand("getBlacklistName", value, NULL_KEY);
    }
    else if (name == "controller name") {
        lmInternalCommand("getMistressName", value, NULL_KEY);
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

setGender(string gender) {
    if (gender == "male") {
        lmSendConfig("dollGender",     (dollGender     = "Male"));
        lmSendConfig("pronounHerDoll", (pronounHerDoll = "His"));
        lmSendConfig("pronounSheDoll", (pronounSheDoll = "He"));
        return;
    } else {
        if (gender == "sissy") {
            lmSendConfig("dollGender", (dollGender = "Sissy"));
        } else {
            lmSendConfig("dollGender", (dollGender = "Female"));
        }

        lmSendConfig("pronounHerDoll", (pronounHerDoll = "Her"));
        lmSendConfig("pronounSheDoll", (pronounSheDoll = "She"));
    }
}

initConfiguration() {
    // Check to see if the file exists and is a notecard
    if (llGetInventoryType(NOTECARD_PREFERENCES) == INVENTORY_NOTECARD) {
        if (databaseOnline && (offlineMode || (ncPrefsLoadedUUID == NULL_KEY) || (ncPrefsLoadedUUID != llGetInventoryKey(NOTECARD_PREFERENCES)))) {
            sendMsg(dollID, "Loading preferences notecard");
            ncStart = llGetTime();

            // Start reading from first line (which is 0)
            ncLine = 0;
            ncPrefsKey = llGetNotecardLine(NOTECARD_PREFERENCES, ncLine);
        }
        else {
            debugSay(7, "DEBUG", "Skipping preferences notecard as it is unchanged");
            doneConfiguration(0);
        }
    } else {
        // File missing - report for debugging only
        debugSay(1, "DEBUG", "No configuration found (" + NOTECARD_PREFERENCES + ")");
        doneConfiguration(0);
    }
}

doneConfiguration(integer read) {
    if (startup == 1 && read) {
        ncPrefsLoadedUUID = llGetInventoryKey(NOTECARD_PREFERENCES);
        lmSendConfig("ncPrefsLoadedUUID", (string)ncPrefsLoadedUUID);
#ifdef DEVELOPER_MODE
        sendMsg(dollID, "Preferences read in " + formatFloat(llGetTime() - ncStart, 2) + "s");
#endif
    }
    if (reset) {
        llSleep(7.5);
        llResetScript();
    }
    reset = 0;
    lmInitState(102);
    lmInitState(105);
    startup = 2;
    
    initializationCompleted();
}

initializationCompleted() {
    if (newAttach && !quiet && cdAttached())
        llSay(0, llGetDisplayName(llGetOwner()) + " is now a dolly - anyone may play with their Key.");

    initTimer = llGetTime() * 1000;
    

    if (dollyName == "") {
        string name = dollName;
        integer space = llSubStringIndex(name, " ");

        if (space != NOT_FOUND) name = llGetSubString(name, 0, space -1);

        //llOwnerSay("INIT1: dollyName = " + dollyName + " (send to 300)");
        lmSendConfig("dollyName", (dollyName = "Dolly " + name));
    }
    //llOwnerSay("INIT1: dollyName = " + dollyName + " (setting)");
    if (cdAttached()) llSetObjectName(dollyName + "'s Key");
    string msg = "Initialization completed";
#ifdef DEVELOPER_MODE
    msg += " in " + formatFloat(initTimer, 2) + "ms";
#endif
    msg += " key ready";

    sendMsg(dollID, msg);

    startup = 0;
    
    lmInitState(110);
    llSetTimerEvent(1.0);
}

#ifdef SIM_FRIENDLY
wakeMenu() {
#ifdef DEVELOPER_MODE
    llOwnerSay("Waking menu scripts");
#endif
    cdRunScript("MenuHandler");
    cdRunScript("Transform");
    cdRunScript("Dress");
}

sleepMenu() {
#ifdef DEVELOPER_MODE
    llOwnerSay("Sleeping menu scripts");
#endif
    cdStopScript("MenuHandler");
    cdStopScript("Transform");
    cdStopScript("Dress");
}
#endif

do_Restart() {
    integer loop; string me = cdMyScriptName();
    reset = 0;

    llOwnerSay("Resetting scripts");

    for (loop = 0; loop < llGetInventoryNumber(INVENTORY_SCRIPT); loop++) {
        string script = llGetInventoryName(INVENTORY_SCRIPT, loop);
        if (script != me) {
            cdRunScript(script);
            llResetOtherScript(script);
        }
    }

    reset = 0;

    llSetTimerEvent(0.1);
}

default {
    link_message(integer source, integer code, string data, key id) {
        list split = llParseStringKeepNulls(data, [ "|" ], []);
        string script = llList2String(split, 0);

        scaleMem();

        if (code == 102) {
            if (script != "ServiceReceiver") return;
            databaseFinished = 1;
            initConfiguration();
        }
        else if ((code == 104) || (code == 105)) {

        }
        else if (code == 135) {
            if (llList2String(split, 0) == cdMyScriptName()) return;
            float delay = llList2Float(split, 1);
            memReport(delay);
        }
        else if (code == 300) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);

            //debugXay(5, "From " + script + ": " + name + "=" + value);

                 if (name == "timeLeftOnKey")            timeLeftOnKey = (float)value;
            else if (name == "ncPrefsLoadedUUID")    ncPrefsLoadedUUID = (key)value;
            else if (name == "offlineMode")                offlineMode = (integer)value;
            else if (name == "databaseOnline")          databaseOnline = (integer)value;
            else if (name == "autoTP")                          autoTP = (integer)value;
            else if (name == "barefeet")                      barefeet = value;
            else if (name == "busyIsAway")                  busyIsAway = (integer)value;
            else if (name == "canAFK")                          canAFK = (integer)value;
            else if (name == "canDress")                      canDress = (integer)value;
            else if (name == "canFly")                          canFly = (integer)value;
            else if (name == "canSit")                          canSit = (integer)value;
            else if (name == "canStand")                      canStand = (integer)value;
            else if (name == "detachable")                  detachable = (integer)value;
            else if (name == "keyLimit")                      keyLimit = (float)value;
            else if (name == "helpless")                      helpless = (integer)value;
            else if (name == "pleasureDoll")              pleasureDoll = (integer)value;
            else if (name == "quiet")                            quiet = (integer)value;
            else if (name == "lowScriptMode")            lowScriptMode = (integer)value;
            else if (name == "dialogChannel")            dialogChannel = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                  debugLevel = (integer)value;
#endif
            else if (name == "userBaseRLVcmd")          userBaseRLVcmd = value;
            else if (name == "userCollapseRLVcmd")  userCollapseRLVcmd = value;
            else if (name == "windTimes")                    windTimes = llDeleteSubList(split, 0, 1);
            else if (name == "dollType")                      dollType = value;
            else if (name == "MistressList")              MistressList = llListSort(llDeleteSubList(split, 0, 1), 2, 1);
            else if (name == "blacklist")                    blacklist = llListSort(llDeleteSubList(split, 0, 1), 2, 1);

            else if (name == "dollyName") {

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
        }

        else if (code == 305) {
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);

            split = llDeleteSubList(split, 0, 1);

            if (cmd == "addRemBlacklist") {
                string uuid = llList2String(split, 0);
                string name = llList2String(split, 1);

                integer index = llListFindList(blacklist, [ uuid ]);

                if (index == -1) {
                    lmSendToAgentPlusDoll("Adding " + name + " to blacklist", id);
                    if ((llGetListLength(blacklist) % 2) == 1) blacklist = llDeleteSubList(blacklist, 0, 0);
                    blacklist = llListSort(blacklist + [ uuid, name ], 2, 1);
                }
                else {
                    lmSendToAgentPlusDoll("Removing " + name + " from blacklist.", id);
                    if ((llGetListLength(blacklist) % 2) == 1) blacklist = llDeleteSubList(blacklist, 0, 0);
                    blacklist = llDeleteSubList(blacklist, index, ++index);
                    
                }
                
                lmSendConfig("blacklist", llDumpList2String(blacklist,"|") );
            }
            else if ((cmd == "addMistress") || (cmd == "remMistress")) {
                string uuid = llList2String(split, 0);
                string name = llList2String(split, 1);

                integer index = llListFindList(MistressList, [ uuid ]);

                if  ((cmd == "addMistress") && (index == -1)) {
                    lmSendToAgentPlusDoll("Adding " + name + " to controller list.", id);
                    if ((llGetListLength(MistressList) % 2) == 1) MistressList = llDeleteSubList(MistressList, 0, 0);
                    MistressList = llListSort(MistressList + [ uuid, name ], 2, 1);
                }
                else if ((cmd == "remMistress") && cdIsBuiltinController(id)) {
                    lmSendToAgentPlusDoll("Removing " + name + " from controller list.", id);
                    if ((llGetListLength(MistressList) % 2) == 1) MistressList = llDeleteSubList(MistressList, 0, 0);
                    MistressList = llDeleteSubList(MistressList, index, ++index);
                    
                    list exceptions = ["tplure","recvchat","recvemote","recvim","sendim","startim"]; integer i;
                    for (i = 0; i < 6; i++) lmRunRLVas("Base",llList2String(exceptions, i) + ":" + uuid + "=rem");
                }
                
                lmSendConfig("MistressList", llDumpList2String(MistressList,"|") );
            }
#ifdef SIM_FRIENDLY
            else if (cmd == "setAFK") afk = llList2Integer(split, 2);
#endif
        }

        else if (code == 350) {
            string script = llList2String(split, 0);
            RLVok = llList2Integer(split, 1);
            rlvWait = 0;

            if (!newAttach && cdAttached()) {
                string msg = dollName + " has logged in with";
                if (!RLVok) msg += "out";
                msg += " RLV at " + wwGetSLUrl();
                lmSendToController(msg);
            }

            newAttach = 0;
        }
        else if (code == 500) {
            string script = llList2String(split, 0);
            string selection = llList2String(split, 1);
            string name = llList2String(split, 2);

            if (selection == "Reset Scripts") {
                if (cdIsController(id)) llResetScript();
                else if (id == dollID) {
                    if (RLVok == YES)
                        llOwnerSay("Unable to reset scripts while running with RLV enabled, please relog without RLV disabled or " +
                                    "you can use login a Linden Lab viewer to perform a script reset.");
                    else if (RLVok == UNSET && (llGetTime() < 300.0))
                        llOwnerSay("Key is currently still checking your RLV status please wait until the check completes and then try again.");
                    else llResetScript();
                }
            }

            nextLagCheck = llGetTime() + SEC_TO_MIN;
        }
//      else if (code == 999 && reset == 1) {
//          llResetScript();
//      }
    }

    state_entry() {
        rlvWait = 1;
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);

        //llTargetOmega(<0,0,0>,0,0);
        llSetObjectName(PACKAGE_STRING);

        ncResetAttach = llGetNotecardLine(NC_ATTACHLIST, cdAttached() - 1);

        reset = 2;
        if (cdAttached()) llRequestPermissions(dollID, PERMISSION_MASK);
        else do_Restart();
    }

    //----------------------------------------
    // TOUCHED
    //----------------------------------------
    touch_start(integer num) {
        if (cdAttached()) llRequestPermissions(dollID, PERMISSION_MASK);
        integer i;
#ifdef SIM_FRIENDLY
        if (!llGetScriptState("MenuHandler")) wakeMenu();
        nextLagCheck = llGetTime() + SEC_TO_MIN;
#endif
    }

    on_rez(integer start) {
        dollID = llGetOwner();
        databaseOnline = 0;
        if (cdAttached()) llRequestPermissions(dollID, PERMISSION_MASK);
        RLVok = UNSET;
        startup = 2;
#ifdef SIM_FRIENDLY
        wakeMenu();
#endif

        //llTargetOmega(<0,0,0>,0,0);

        llResetTime();
        string me = cdMyScriptName();
        integer loop; string script;

        sendMsg(dollID, "Reattached, Initializing");

        llSleep(0.5);
        lmInitState(initState = 105);
    }

    attach(key id) {
        if (id == NULL_KEY) {
            llMessageLinked(LINK_SET, 106,  SCRIPT_NAME + "|" + "detached" + "|" + (string)lastAttachPoint, lastAttachAvatar);
            llOwnerSay("The key is wrenched from your back, and you double over at the unexpected pain as the tendrils are ripped out. You feel an emptiness, as if some beautiful presence has been removed.");
            
            saveAttachment = cdSetValue(saveAttachment, [attachName], llList2Json(JSON_ARRAY,[llGetLocalPos(),llGetLocalRot()]));
            llOwnerSay(saveAttachment);
        } else {
            llMessageLinked(LINK_SET, 106, SCRIPT_NAME + "|" + "attached" + "|" + (string)llGetAttached(), id);

            if (llGetPermissionsKey() == llGetOwner() && (llGetPermissions() & PERMISSION_TAKE_CONTROLS) != 0) llTakeControls(CONTROL_MOVE, 1, 1);
            else llRequestPermissions(dollID, PERMISSION_MASK);
            
            ncResetAttach = llGetNotecardLine(NC_ATTACHLIST, cdAttached() - 1);

            if (lastAttachAvatar == NULL_KEY) newAttach = 1;
        }

        lastAttachPoint = cdAttached();
        lastAttachAvatar = id;
    }

    dataserver(key query_id, string data) {
        if (query_id == ncResetAttach) {
            data = llStringTrim(data,STRING_TRIM);
            llSetPrimitiveParams([PRIM_POS_LOCAL, (vector)cdGetValue(saveAttachment,([data,0])), PRIM_ROT_LOCAL, (rotation)cdGetValue(saveAttachment,([data,1]))]);
            attachName = data;
        }
        else if (query_id == ncPrefsKey) {
            if (data == EOF) {
                doneConfiguration(1);
            }
            else {
                integer index = llSubStringIndex(data, "#");
                if (index != -1) data = llDeleteSubString(data, index, -1);
                if (data != "") {
                    index = llSubStringIndex(data, "=");
                    string name = llGetSubString(data, 0, index - 1);
                    string value = llGetSubString(data, index + 1, -1);
                    name = llStringTrim(llToLower(name), STRING_TRIM);
                    value = llStringTrim(value, STRING_TRIM);
                    list split = llParseStringKeepNulls(value, [ "|" ], []);
                    if (name == "windTimes") split = llParseString2List(value, ["|",","," "], []); // Accept pipe (|), space ( ) or comma (,) as seperators

                    processConfiguration(name, split);
                }
                ncPrefsKey = llGetNotecardLine(NOTECARD_PREFERENCES, ++ncLine);
            }
        }
    }

    changed(integer change) {
        if (change & CHANGED_OWNER) {
            if (llGetInventoryType(NOTECARD_PREFERENCES) != INVENTORY_NONE) {
                llOwnerSay("Deleting old preferences notecard on owner change.");
                llOwnerSay("Look at PreferencesExample to see how to make yours.");
                llRemoveInventory(NOTECARD_PREFERENCES);
            }

            llSleep(5.0);

            llResetScript();
        }
        if (change & CHANGED_INVENTORY) {
            llOwnerSay("Inventory modified restarting in 30 seconds.");

            llSleep(30.0);

            if (llGetInventoryType(NOTECARD_PREFERENCES) == INVENTORY_NOTECARD) {
                key ncKey = llGetInventoryKey(NOTECARD_PREFERENCES);
                if (ncPrefsLoadedUUID != NULL_KEY && ncKey != NULL_KEY && ncKey != ncPrefsLoadedUUID) {
                    databaseOnline = 0;
                    reset = 1;

                    sendMsg(dollID, "Loading preferences notecard");
                    ncStart = llGetTime();

                    // Start reading from first line (which is 0)
                    ncLine = 0;
                    ncPrefsKey = llGetNotecardLine(NOTECARD_PREFERENCES, ncLine);

                    return;
                }
            }

            llResetScript();
        }
    }

    timer() {
        float t = llGetTime();
        if (t >= 300.0) llSetTimerEvent(6-.0);
        else llSetTimerEvent(15.0);

        if ((startup != 0) && (initState == 104)) {
            llOwnerSay("Starting initialization");
            startup = 1;
            lmInitState(initState++);
        }
        else if (startup != 0) {
            integer i; integer n = llGetInventoryNumber(10);
            for (i = 0; i < n; i++) {
                string script = llGetInventoryName(10, i);

                if (!llGetScriptState(script)) {
                    if (llListFindList([ "Aux", "Avatar", "Dress", "Main", "MenuHandler", "ServiceRequester", "ServiceReceiver", "StatusRLV", "Transform" ], [ script ]) != -1) {
                        // Core key script appears to have suffered a fatal error try restarting
                        float delay = 30.0;
#ifdef DEVELOPER_MODE
                        delay = delay * 6.0; // Increase delay for automatic restarts by a factor of 6;
                                             // this prevents rapidly looping in the event of a developer
                                             // accidently saving a script that fails to compile.
#endif

                        llSleep(delay);

                        cdRunScript(script);
                        llResetScript();
                    }
                }
            }
        }
        else {
            if (attachName = "") return;
            saveAttachment = cdSetValue(saveAttachment,([attachName,0]),(string)llGetLocalPos());
            saveAttachment = cdSetValue(saveAttachment,([attachName,1]),(string)llGetLocalRot());
        }
    }

    run_time_permissions(integer perm) {
        if (perm & PERMISSION_TAKE_CONTROLS) {
            llTakeControls(CONTROL_MOVE, 1, 1);
            if (reset == 2) do_Restart();
        }
    }
}

