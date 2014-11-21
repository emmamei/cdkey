//========================================
// Start.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

#include "include/Json.lsl"
#include "include/GlobalDefines.lsl"
#define sendMsg(id,msg) lmSendToAgent(msg, id);

#define RUNNING 1
#define NOT_RUNNING 0
#define YES 1
#define NO 0
#define NOT_FOUND -1
#define UNSET -1
#define cdRunScript(a) llSetScriptState(a, RUNNING)
#define cdStopScript(a) llSetScriptState(a, NOT_RUNNING)
#define cdIsScriptRunning(a) llGetScriptState(a)
#define cdNotecardNotExist(a) (llGetInventoryType(a) != INVENTORY_NONE)
#define cdNotecardExists(a) (llGetInventoryType(a) == INVENTORY_NOTECARD)

// This action is different in different scripts;
// they do the same thing (reset Start.lsl)
#define cdResetKey() llResetScript()

#define PREFS_READ 1
#define PREFS_NOT_READ 0

#define cdSetKeyName(a) llSetObjectName(a)
#define cdResetKeyName() llSetObjectName(PACKAGE_NAME + " " + __DATE__)

//=======================================
// VARIABLES
//=======================================
float delayTime = 15.0; // in seconds
#ifdef DEVELOPER_MODE
float initTimer;
#endif

key dollID = NULL_KEY;
key MistressID = NULL_KEY;

string dollName;
string dollyName;
string appearanceData;
string chatFilter = "";
integer chatEnable = TRUE;

#define APPEARANCE_NC "DataAppearance"
key ncPrefsKey;
list ncPrefsLoadedUUID;
key ncIntroKey;
key ncResetAttach;
key ncRequestAppearance;

float timeLeftOnKey;
float keyLimit;
integer ncLine;
integer demoMode;
integer failedReset;

#ifdef DEVELOPER_MODE
float ncStart;
#endif
integer lastAttachPoint;
key lastAttachAvatar;

list controllers;
list blacklist;
list recentDilation;

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
integer isAttached;

// These RLV commands are set by the user
string userAfkRLVcmd;
string userBaseRLVcmd;
string userCollapseRLVcmd;
string userPoseRLVcmd;

// These are hardcoded and should never change during normal operation
string defaultAfkRLVcmd = "";
string defaultBaseRLVcmd = "";
string defaultCollapseRLVcmd = "fly=n,sendchat=n,tplm=n,tplure=n,tploc=n,showinv=n,edit=n,sit=n,sittp=n,fartouch=n,showworldmap=n,showminimap=n,showloc=n,shownames=n,showhovertextall=n";
string defaultPoseRLVcmd = "";

string dollGender = "Female";
string pronounHerDoll = "Her";
string pronounSheDoll = "She";
integer introLine;
integer introLines;

integer resetState;
#define RESET_NONE 0
#define RESET_NORMAL 1
#define RESET_STARTUP 2

integer rlvWait;
integer RLVok = UNSET;
float keyLimit;

integer afk;
integer lowScriptMode;

//=======================================
// FUNCTIONS
//=======================================
doVisibility() {
    vector colour = gemColour;

    if (cdNotecardExists(APPEARANCE_NC)) {

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

         if (value == "yes"  || value == "YES" ||
             value == "on"   || value == "ON"   ||
             value == "true" || value == "TRUE")

             value = "1";

    else if (value == "no"    || value == "NO"     ||
             value == "off"   || value == "OFF"    ||
             value == "false" || value == "FALSE")

             value = "0";

    integer i;
    list configs = [ "barefeet path", "helpless dolly", "quiet key", "outfits path",
                     "busy is away", "can afk", "can fly", "poseable", "can sit", "can stand",
                     "can dress", "detachable", "doll type", "pleasure doll", "pose silence",
                     "auto tp", "outfitable", "max time", "chat channel", "dolly name", "demo mode",
                     "afk rlv", "base rlv", "collapse rlv", "pose rlv" , "show phrases",
#ifdef DEBUG_MODE
                     "debug level",
#endif
#ifdef DEVELOPER_MODE
                     "initial time",
#endif
                     "dressable", "carryable", "repeatable wind"
                   ];

    list sendName = [ "barefeet", "helpless", "quiet", "outfitsFolder",
                      "busyIsAway", "canAfk", "canFly", "canPose", "canSit", "canStand",
                      "canDressSelf", "detachable", "dollType", "pleasureDoll", "poseSilence",
                      "autoTP", "canDress", "timeLeftOnKey", "keyLimit", "chatChannel", "dollyName", "demoMode",
                      "userAfkRLVcmd", "userBaseRLVcmd", "userCollapseRLVcmd", "userPoseRLVcmd" , "showPhrases",
#ifdef DEBUG_MODE
                      "debugLevel",
#endif
#ifdef DEVELOPER_MODE
                      "timeLeftOnKey",
#endif
                      "canDress", "canCarry", "canRepeatWind"
                    ];

//  list internals = [ "wind time", "blacklist key", "controller key" ];
//  list cmdName = [ "setWindTime", "addBlacklist", "addMistress" ];
    list internals = [ "wind time" ];
    list cmdName = [ "setWindTime" ];

    // Three specially handled configuration entries:
    //   * doll gender
    //   * blacklist key
    //   * controller key

    // This processes a single line from the preferences notecard...
    // processing done a single time during the read of the nc belong elsewhere

    name = llToLower(name);
    if ((i = cdListElementP(configs,name)) != NOT_FOUND) {
#ifdef DEVELOPER_MODE
        if (name == "initial time") {
            value = (string)((float)value * SEC_TO_MIN);

            // validate value
            if ((float)value > 90) value = "90";
            else if ((float)value < 15) value = "15";
            if ((float)value > keyLimit) value = (string)keyLimit;
        }
        else
#endif
        if (name == "max time") {
            value = (string)((float)value * SEC_TO_MIN);

            // validate value and also timeLeftOnKey
            if ((float)value > 240) value = "240";
            else if ((float)value < 10) value = "30";
            if (timeLeftOnKey > (float)value) timeLeftOnKey = (float)value;
        }

        // FIXME: Note the lack of validation here (!)
        lmSendConfig(cdListElement(sendName,i), value);
    }
    else if ((i = cdListElementP(internals,name)) != NOT_FOUND) {
        if (name == "wind time") {

            // validate value
            if ((float)value > 90) value = "90";
            else if ((float)value < 15) value = "15";

            // If it takes 2 winds or less to wind dolly, then
            // we fall back to 6 winds: note that this happens AFTER
            // the numerical validation: so potentioally, after this next
            // statement, we could have a wind time of less than 15 - which
            // is to be expected
            if ((float)value > (keyLimit / 2)) value = (string)llFloor(keyLimit / 6);
        }
        lmInternalCommand(cdListElement(cmdName,i), value, NULL_KEY);
    }
    else if (name == "chat mode") {
        chatFilter = "";
        chatEnable = TRUE;

        if (value == "dolly") chatFilter = (string)dollID;
        else if (value == "disabled") chatEnable = FALSE;
        else if (value == "world") chatFilter = "";

        lmSendConfig("chatEnable",(string)chatEnable);
        lmSendConfig("chatFilter",chatFilter);
    }
    else if (name == "doll gender") {
        // This only accepts valid values
        if (value == "female" || value == "woman" || value == "girl") setGender("female");
        else if (value == "male" || value == "man" || value == "boy") setGender("male");
        else setGender("female");
    }
    else if (name == "blacklist key") {
        if (llList2Key([ value ], 0) != NULL_KEY) {
            if (llListFindList(blacklist, [ value ]) == NOT_FOUND)
                lmSendConfig("blacklist", llDumpList2String((blacklist += [ "", value ]), "|"));
        }
    }
    else if (name == "controller key") {
        if (llList2Key([ value ], 0) != NULL_KEY) {
            if (llListFindList(controllers, [ value ]) == NOT_FOUND)
                lmSendConfig("controllers", llDumpList2String((controllers += [ "", value ]), "|"));
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
        dollGender = "Female";
        pronounHerDoll = "Her";
        pronounSheDoll = "She";
    }

    lmSendConfig("dollGender",     dollGender);
    lmSendConfig("pronounHerDoll", pronounHerDoll);
    lmSendConfig("pronounSheDoll", pronounSheDoll);
}

// PURPOSE: readPreferences reads the Preferences notecard, if any -
//          and runs doneConfiguration if no notecard is found

readPreferences() {
#ifdef DEVELOPER_MODE
    ncStart = llGetTime();
#endif

    // Check to see if the file exists and is a notecard
    if (cdNotecardExists(NOTECARD_PREFERENCES)) {
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

// PURPOSE: doneConfiguration is called after preferences are done:
//          that is, preferences have been read if they exist

doneConfiguration(integer prefsRead) {
    // By now preferences SHOULD have been read - if there were any.
    // the variable prefsRead allows us to know if prefs were read...
    // but how do we use this knowledge?

    resetState = RESET_NONE;

    debugSay(3,"DEBUG-START","Configuration done - starting init code 102 and 104 and 105");
    lmInitState(102);
    lmInitState(104);
    lmInitState(105);

    //initializationCompleted
    isAttached = cdAttached();

    if (dollyName == "") {
        string name = dollName;
        integer space = llSubStringIndex(name, " ");

        if (space != NOT_FOUND) name = llGetSubString(name, 0, space - 1);

        lmSendConfig("dollyName", (dollyName = "Dolly " + name));
    }

    // WearLock should be clear
    lmSendConfig("wearLock","0");

    if (isAttached) cdSetKeyName(dollyName + "'s Key");

    debugSay(3,"DEBUG-START","doneConfiguration done - starting init code 110");
    lmInitState(110);

    if (cdNotecardExists(APPEARANCE_NC)) {
        ncLine = 0;
        appearanceData = "";
        ncRequestAppearance = llGetNotecardLine(APPEARANCE_NC, ncLine++);
    }

    //llSetTimerEvent(10.0);
    debugSay(3,"DEBUG-START","doneConfiguration done - exiting");

    string msg = "Initialization completed" +
#ifdef DEVELOPER_MODE
                 " in " + formatFloat((llGetTime() - initTimer), 1) + "s" +
#endif
                 "; key ready";

    sendMsg(dollID, msg);

    if (newAttach && !quiet && isAttached)
        llSay(0, llGetDisplayName(llGetOwner()) + " is now a dolly - anyone may play with their Key.");
}

doRestart() {

    integer n;
    string script;

    debugSay(2,"DEBUG-RESET","Resetting Key scripts");

    // Set all other scripts to run state and reset them
    n = llGetInventoryNumber(INVENTORY_SCRIPT);
    while(n--) {
        script = llGetInventoryName(INVENTORY_SCRIPT, n);
        if (script != "Start") {

            debugSay(5,"DEBUG-RESET","========>> Resetting #" + (string)n + ": '" + script + "'");

            //cdRunScript(script);
            llResetOtherScript(script);
        }
    }

    resetState = RESET_NONE;
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
            ;
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

                 if (name == "ncPrefsLoadedUUID")    ncPrefsLoadedUUID = llDeleteSubList(split,0,0);
            else if (name == "lowScriptMode")            lowScriptMode = (integer)value;
            else if (name == "dialogChannel")            dialogChannel = (integer)value;
            else if (name == "demoMode")                      demoMode = (integer)value;
            else if (name == "quiet")                            quiet = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                  debugLevel = (integer)value;
#endif
            else if (name == "controllers")                controllers = split;
            else if (name == "blacklist")                    blacklist = split;
            else if (name == "keyLimit")                      keyLimit = (float)value;
            else if (name == "keyAnimation") {
                keyAnimation = value;

                if (!collapsed) {

                    // Dolly is operating normally (not collapsed)

                    if (cdPoseAnim()) {
                        // keyAnimation is a pose of some sort
                        lmRunRLV(defaultPoseRLVcmd);
                        if (userPoseRLVcmd != "") lmRunRLVas("UserPose", userPoseRLVcmd);
                    }
                    else {
                        // either animation is null, or animation
                        // is the collapse animation but we're not collapsed
                        // (the latter should be an error)
                        lmRunRLV("clear");
                        if (userPoseRLVcmd != "") lmRunRLVas("UserPose", "clear");
                    }
                }
            }
            else if (name == "afk") {
                afk = (integer)value;

                if (!collapsed) {
                    // a collapse overrides AFK - ignore AFK if we are collapsed
                    if (afk) {
                        lmRunRLV(defaultAfkRLVcmd);
                        if (userAfkRLVcmd != "") lmRunRLVas("UserAfk", userAfkRLVcmd);
                    }
                    else {
                        lmRunRLV("clear");
                        if (userAfkRLVcmd != "") lmRunRLVas("UserAfk", "clear");
                    }
                }
            }
            else if (name == "userBaseRLVcmd")          userBaseRLVcmd = value;
            else if (name == "userCollapseRLVcmd")  userCollapseRLVcmd = value;
            else if (name == "userPoseRLVcmd")          userPoseRLVcmd = value;
            else if (name == "userAfkRLVcmd")            userAfkRLVcmd = value;

            else if (name == "gemColour") {      gemColour = (vector)value; doVisibility(); }
            else if (name == "primGlow")  {      primGlow = (integer)value; doVisibility(); }
            else if (name == "primLight") {     primLight = (integer)value; doVisibility(); }
            else if (name == "isVisible") {       visible = (integer)value; doVisibility(); }

            else if (name == "collapsed") {
                integer wasCollapsed = collapsed;
                collapsed = (integer)value;
                doVisibility();

                debugSay(2, "DEBUG-START", "Collapsed = " + (string)collapsed);
                debugSay(2, "DEBUG-START", "defaultCollapseRLVcmd = " + defaultCollapseRLVcmd);
                debugSay(2, "DEBUG-START", "userCollapseRLVcmd = " + userCollapseRLVcmd);

                if (collapsed) {
                    // We are collapsed: activate RLV restrictions
                    lmRunRLV(defaultCollapseRLVcmd);
                    if (userCollapseRLVcmd != "") lmRunRLVas("UserCollapse", userCollapseRLVcmd);
                }
                else {
                    if (wasCollapsed) {
                        // We were collapsed but aren't now... so clear RLV restrictions
                        lmRunRLV("clear");
                        if (userCollapseRLVcmd != "") lmRunRLVas("UserCollapse", "clear");
                    }
                }
            }
            else if (name == "dollyName") {
                if (script != cdMyScriptName()) {
                    dollyName = value;

                    if (dollyName == "") {
                        string name = dollName;
                        integer space = llSubStringIndex(name, " ");

                        if (space != NOT_FOUND) name = llGetSubString(name, 0, space -1);

                        lmSendConfig("dollyName", (dollyName = "Dolly " + name));
                    }
                    if (cdAttached()) cdSetKeyName(dollyName + "'s Key");
                }
            }
        }
        else if (code == 350) {
            RLVok = (llList2Integer(split, 0) == 1);
            rlvWait = 0;

            if (!newAttach) {
                if (cdAttached()) {
                    string msg = dollName + " has logged in with";

                    if (!RLVok) msg += "out";
                    msg += " RLV at " + wwGetSLUrl();

                    lmSendToController(msg);
                }
            }

            if (RLVok) {
                // If RLV is ok, then trigger all of the necessary RLV restrictions
                if (collapsed) {
                    // Dolly collapse overrides all others
                    lmRunRLV(defaultCollapseRLVcmd);
                    if (userCollapseRLVcmd != "") lmRunRLVas("UserCollapse", userCollapseRLVcmd);
                }
                else {
                    // Not collapsed: clear any user collapse RLV restrictions
                    lmRunRLV("clear");
                    if (userCollapseRLVcmd != "") lmRunRLVas("UserCollapse", "clear");

                    // Is Dolly AFK? Trigger RLV restrictions as appropriate
                    if (afk) {
                        lmRunRLV(defaultAfkRLVcmd);
                        if (userAfkRLVcmd != "") lmRunRLVas("UserAfk", userAfkRLVcmd);
                    }
                    else {
                        lmRunRLV("clear");
                        if (userAfkRLVcmd != "") lmRunRLVas("UserAfk", "clear");
                    }

                    // Are we posed? Trigger RLV restrictions for being posed
                    if (cdPoseAnim()) {
                        lmRunRLV(defaultPoseRLVcmd);
                        if (userPoseRLVcmd != "") lmRunRLVas("UserPose", userPoseRLVcmd);
                    }
                    else {
                        lmRunRLV("clear");
                        if (userPoseRLVcmd != "") lmRunRLVas("UserPose", "clear");
                    }
                }

                newAttach = 0;
            }
        }
        else if (code == 500) {
            string selection = llList2String(split, 0);
            string name = llList2String(split, 1);

            if (selection == "Reset Key") {
                if (cdIsController(id)) cdResetKey();
            }
        }
    }

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {

#ifdef DEVELOPER_MODE
        initTimer = llGetTime();
#endif

        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);

        rlvWait = 1;
        cdInitializeSeq();
        resetState = RESET_STARTUP;

        if (cdAttached()) llRequestPermissions(dollID, PERMISSION_MASK);
        else {
            llOwnerSay("Key not attached");
            cdResetKeyName();
        }

        // WHen this script (Start.lsl) resets... EVERYONE resets...
        doRestart();

        readPreferences();
    }

    //----------------------------------------
    // TOUCH START
    //----------------------------------------
    touch_start(integer num) {
        if (cdAttached()) llRequestPermissions(dollID, PERMISSION_MASK);
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);

        if (cdAttached()) llRequestPermissions(dollID, PERMISSION_MASK);
        else cdResetKeyName();

        RLVok = UNSET;

        llResetTime();
    }

    //----------------------------------------
    // ATTACH
    //----------------------------------------
    attach(key id) {

        if (id == NULL_KEY) {

            if(!llGetAttached()) cdResetKeyName();

            // At this point, we know that we have a REAL detach:
            // key id is NULL_KEY and llGetAttached() == 0

            llMessageLinked(LINK_SET, 106,  cdMyScriptName() + "|" + "detached" + "|" + (string)lastAttachPoint, lastAttachAvatar);
            llOwnerSay("The key is wrenched from your back, and you double over at the unexpected pain as the tendrils are ripped out. You feel an emptiness, as if some beautiful presence has been removed.");

        } else {

            isAttached = 1;
            llMessageLinked(LINK_SET, 106, cdMyScriptName() + "|" + "attached" + "|" + (string)cdAttached(), id);

            if (llGetPermissionsKey() == dollID && (llGetPermissions() & PERMISSION_TAKE_CONTROLS) != 0) llTakeControls(CONTROL_MOVE, 1, 1);
            else llRequestPermissions(dollID, PERMISSION_MASK);

            if (lastAttachAvatar == NULL_KEY) newAttach = 1;
        }

        // when attaching key, user is NOT AFK...
        afk = 0;
        lmSendConfig("afk", "0");

        // when attaching we're not in lowScriptMode
        lowScriptMode = 0;
        lmSendConfig("lowScriptMode", "0");

        // reset collapse environment if needed
        lmInternalCommand("collapse", (string)collapsed, llGetKey());

        lastAttachPoint = cdAttached();
        lastAttachAvatar = id;
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key query_id, string data) {

        // Reading notecard DataAppearance (JSON list of appearance settings)
        if (query_id == ncRequestAppearance) {
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
        else

        // Read notecard: Preferences
        if (query_id == ncPrefsKey) {
            if (data == EOF) {
                lmSendConfig("ncPrefsLoadedUUID", llDumpList2String(llList2List((string)llGetInventoryKey(NOTECARD_PREFERENCES) + ncPrefsLoadedUUID, 0, 9),"|"));
                lmInternalCommand("getTimeUpdates","",NULL_KEY);

#ifdef DEVELOPER_MODE
                sendMsg(dollID, "Preferences read in " + formatFloat(llGetTime() - ncStart, 2) + "s");
#endif
                doneConfiguration(PREFS_READ);
            }
            else {
                // Strip comments (prefs)
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
        if(!cdAttached()) cdResetKeyName();

        if (change & CHANGED_OWNER) {

            llOwnerSay("You have a new key! Congratulations!\n" +
                "Look at PreferencesExample to see how to set the preferences for your new key.");

            if (cdNotecardExists(NOTECARD_PREFERENCES)) {
                llRemoveInventory(NOTECARD_PREFERENCES);
            }

            llSleep(5.0);
            cdResetKey(); // start over with no preferences
        }

        // THis section of code has a danger in it for RLV locked keys:
        // if the user can modify the key - and change its inventory -
        // it may be possible to override values at the least and to
        // reset the key at the worst.
        //
        // Note that if Start.lsl is modified, this does not get run,
        // but Start.lsl is reset immediately - and upon reset,
        // resets the entire key.

        else if (change & CHANGED_INVENTORY) {
            if (cdNotecardExists(NOTECARD_PREFERENCES)) {
                string ncKey = (string)llGetInventoryKey(NOTECARD_PREFERENCES);

                // Did Notecard change? (that is, did its UUID change?)
                if (llListFindList(ncPrefsLoadedUUID,[ncKey]) == NOT_FOUND) {
                    resetState = RESET_NORMAL;

                    sendMsg(dollID, "Reloading preferences card");
#ifdef DEVELOPER_MODE
                    ncStart = llGetTime();
#endif
                    // Start reading from first line (which is 0)
                    ncPrefsKey = llGetNotecardLine(NOTECARD_PREFERENCES, (ncLine = 0));
                    return;
                }
            }

            // if we get here, it was NOT the Preferences Notecard that
            // changed - it was something else...

            // What if inventory changes several times in a row?
            llOwnerSay("Key contents modified; restarting in 120 seconds.");
            llSetTimerEvent(120.0);
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
        // We only get here if the key was modified
        llSetTimerEvent(0.0);

        llOwnerSay("Now resetting key.");
        llSleep(5.0);
        cdResetKey();
    }

    //----------------------------------------
    // RUN TIME PERMISSIONS
    //----------------------------------------
    run_time_permissions(integer perm) {
        if (perm & PERMISSION_TAKE_CONTROLS) {
            llTakeControls(CONTROL_MOVE, 1, 1);
        }
    }
}

