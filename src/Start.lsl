//========================================
// Start.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

//#include "include/Json.lsl"
#include "include/GlobalDefines.lsl"

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
string msg;
float delayTime = 15.0; // in seconds
float initTimer;

key ncPrefsKey;
integer prefsRead;

integer ncLine;
integer failedReset;

float ncStart;
integer lastAttachPoint;
key lastAttachAvatar;

integer newAttach = YES;
#ifdef GEM_PRESENT
#ifdef GEMGLOW_OPT
integer gemGlow = YES;
#endif
integer gemLight = YES;
#endif
integer dbConfigCount;
integer i;

string attachName;
#ifdef GEM_PRESENT
string prefGemColour="<0.9, 0.1, 0.8>"; // pink
#endif
integer isAttached;

// These RLV commands are set by the user
string userAfkRLVcmd;
//string userBaseRLVcmd;
string userCollapseRLVcmd;
string userPoseRLVcmd;

// These are hardcoded and should never change during normal operation
string defaultAfkRLVcmd = "fly=n,sendchat=n,tplm=n,tplure=n,tploc=n,sittp=n,fartouch=n,alwaysrun=n";
string defaultBaseRLVcmd = "";
string defaultCollapseRLVcmd = "fly=n,sendchat=n,tplm=n,tplure=n,tploc=n,showinv=n,edit=n,sit=n,sittp=n,fartouch=n,showworldmap=n,showminimap=n,showloc=n,shownames=n,showhovertextall=n";

// Default PoseRLV does not include silence: that is optional
// Also allow touch - for Dolly to access Key
string defaultPoseRLVcmd = "fly=n,tplm=n,tplure=n,tploc=n,sittp=n,fartouch=n";

//integer introLine;
//integer introLines;

integer resetState;
#define RESET_NONE 0
#define RESET_NORMAL 1
#define RESET_STARTUP 2

integer rlvWait;

//=======================================
// FUNCTIONS
//=======================================
#ifdef GEM_PRESENT
doLuminosity() {
    // The two options below do the same thing - but when not visible or collapsed,
    // it bypasses all the scanning and testing and goes straight to work.
    // Note that it sets the color on every prim to the gemColour - but the
    // textured Key items don't change color (texture overrides color?).

#ifdef GEMGLOW_OPT
    if (!visible || !gemGlow || collapsed) {
#else
    if (!visible || collapsed) {
#endif
        // Turn off glow et al when not visible or collapsed
        llSetLinkPrimitiveParamsFast(LINK_SET, [ PRIM_POINT_LIGHT, FALSE, gemColour, 0.5, 2.5, 2.0 ]);
        llSetLinkPrimitiveParamsFast(LINK_SET, [ PRIM_GLOW, ALL_SIDES, 0.0 ]);
    }
    else {
        // Set gem light and glow parameters using llSetLinkPrimitiveParamsFast
        //
        // Note that this sets light and glow - even IF the Key light is off

        // FIXME: Prim Search
        list params;
        integer nPrims = llGetNumberOfPrims();
        integer i;
        string name;
        float glow;
        integer primN;
        string primPrefix;

        i = nPrims;
        while (i--) {
            primN = i + 1;
            name = llGetLinkName(primN);
            glow = 0.0;

            // Start a new Link Target
            params += [ PRIM_LINK_TARGET, primN ];

            primPrefix = llGetSubString(llGetLinkName(i), 0, 2);
            if (primPrefix == "Hea" || primPrefix == "Gem") {
                // JSON parameters were .............................. <0.6, 0.0, 0.9>, 0.3, 3.0, 0.2
                params += [ PRIM_POINT_LIGHT, (gemLight & !collapsed),      gemColour, 0.5, 2.5, 2.0 ];
                if (gemLight) glow = 0.08;
            }
            else if (gemLight) {
                if (name == "Body") glow = 0.3;
                //else if (name == "Center") glow = 0.0;
                else if (llGetSubString(name, 0, 5) == "Mount") glow = 0.1;
            }

            params += [ PRIM_GLOW, ALL_SIDES, glow ];
        }

        debugSay(4, "DEBUG-START", "Set Params list: " + llDumpList2String(params, ","));
        llSetLinkPrimitiveParamsFast(0, params);
    }
}
#endif

//---------------------------------------
// Configuration Functions
//---------------------------------------

processConfiguration(string name, string value) {

    //----------------------------------------
    // Assign values to program variables

    integer i;

    // Configuration entries: these are the actual configuration
    // commands; they must match with a sendName below
    list configs = [ "outfits path", "doll type", "max time", "chat channel", "dolly name", "wind time",
#ifdef DEVELOPER_MODE
                     "debug level",
#endif
                     "afk rlv", "collapse rlv", "pose rlv",
#ifdef GEM_PRESENT
                     "gem color", "gem colour",
#endif
                     "doll gender", "helpless dolly", "chat mode", "controller"
                   ];

    // The settings list and the settingName list much match up
    // with entries
    list settings = [ "quiet key", "hardcore", "busy is away", "can afk", "can fly",
                      "poseable", "can sit", "can stand", "can dress self", "detachable",
#ifdef ADULT_MODE
                      "strippable",
#endif
                      "pose silence", "auto tp", "dressable", "outfitable", "can dress", "demo mode",
                      "show phrases", "carryable", "repeatable wind", "ghost"
                    ];

    list settingName = [ "quiet", "hardcore", "busyIsAway", "canAfk", "canFly",
                         "allowPose", "canSit", "canStand", "canDressSelf", "detachable",
#ifdef ADULT_MODE
                         "allowStrip",
#endif
                         "poseSilence", "autoTP", "allowDress", "allowDress", "allowDress", "demoMode",
                         "showPhrases", "allowCarry", "allowRepeatWind", "ghost"
                       ];

    // This processes a single line from the preferences notecard...
    // processing done a single time during the read of the nc belong elsewhere

    name = llToLower(name);

    // Check for settings - boolean true or false
    if ((i = cdListElementP(settings,name)) != NOT_FOUND) {
            value = llToLower(value);

            if (value == "yes"  ||
                value == "on"   ||
                value == "y"    ||
                value == "t"    ||
                value == "true" ||
                value == "1") {

            value = "1";

        }
        else if (value == "no"    ||
                 value == "off"   ||
                 value == "n"     ||
                 value == "f"     ||
                 value == "false" ||
                 value == "0") {
                 
            value = "0";
        }
        else {
            llSay(DEBUG_CHANNEL,"Invalid preferences setting! (" + name + " = " + value + ")");
            return;
        }

        string name = cdListElement(settingName,i);

        // Special handling for ghost setting: value is a boolean,
        // but result is to change the visibility value...
        //
        if (name == "ghost") { lmSendConfig("visibility",(string)GHOST_VISIBILITY); }
        else { lmSendConfig(name, value); }
    }
    // Check for non-boolean settings
    else if ((i = cdListElementP(configs,name)) != NOT_FOUND) {
        if (name == "outfits path") {
            // should be present
            lmSetConfig("outfitsFolder", value);
        }
        else if (name == "doll type") {
            // should be part of a valid set
            lmSetConfig("dollType", value);
        }
        else if (name == "chat channel") {
            // cant be 0 or MAXINT (DEBUG_CHANNEL)
            lmSetConfig("chatChannel", value);
        }
        else if (name == "dolly name") {
            // should be printable
            lmSendConfig("dollDisplayName", value);
        }
#ifdef DEVELOPER_MODE
        else if (name == "debug level") {
            // has to be between 0 and 9
            debugLevel = (integer)value;

            if (debugLevel > 9) debugLevel = 9;
            else if (debugLevel < 0) debugLevel = 0;

            lmSendConfig("debugLevel", (string)debugLevel);
        }
#endif
        else if (name == "afk rlv") {
            // has to be valid rlv
            lmSendConfig("userAfkRLVcmd", value);
        }
        else if (name == "collapse rlv") {
            // has to be valid rlv
            lmSendConfig("userCollapseRLVcmd", value);
        }
        else if (name == "pose rlv") {
            // has to be valid rlv
            lmSendConfig("userPoseRLVcmd", value);
        }

        // Note that the entries "max time" and "wind time" are
        // somewhat unique in that they affect each other: so,
        // we don't use the one to validate the other until preferences
        // are completely read, nor do we set these values system-wide
        else if (name == "max time") {
            if ((integer)value != 0) {
                keyLimit = (integer)value * SECS_PER_MIN;

                if (keyLimit > 14400) keyLimit = 14400;
                else if (keyLimit < 900) keyLimit = 900;
            }
        }
        else if (name == "wind time") {
            if ((integer)value != 0) {
                windNormal = (integer)value * SECS_PER_MIN;

                // validate value
                if (windNormal > 5400) windNormal = 5400;
                else if (windNormal < 900) windNormal = 900;
            }
        }
#ifdef GEM_PRESENT
        else if (name == "gem colour" || name == "gem color") {
            if ((vector)value != ZERO_VECTOR) prefGemColour = value;
        }
#endif
        else if (name == "controller") {
            string uuid = (string)value;
            controllers = (controllers = []) + controllers + [ (string)value, "x" ];
            lmSetConfig("controllers", llDumpList2String(controllers, "|"));
            // Controllers get added to the exceptions
            llOwnerSay("@tplure:"    + uuid + "=add," +
                        "accepttp:"  + uuid + "=add," +
                        "sendim:"    + uuid + "=add," +
                        "recvim:"    + uuid + "=add," +
                        "recvchat:"  + uuid + "=add," +
                        "recvemote:" + uuid + "=add");
        }
        else if (name == "chat mode") {
            // Set the way chat operates

            // Note that a value of "world" doesn't actually require any action at all
            value = llToLower(value);

            if (value == "dolly") lmSetConfig("chatFilter",(string)dollID);
            else if (value == "disabled") lmInternalCommand("chatDisable","",NULL_KEY);
            else if (value != "world") llSay(DEBUG_CHANNEL,"Bad chat mode (" + value + ")");
        }
        else if (name == "helpless dolly") {
            // Note inverted sense of this value: this is intentional
            if (value == "1") lmSendConfig("canSelfTP", "0");
            else lmSendConfig("canSelfTP", "1");
        }
        else if (name == "doll gender") {
            // set gender of dolly

            if (value == "female" || value == "woman" || value == "girl") dollGender = "female";
            else if (value == "male" || value == "man" || value == "boy") dollGender = "male";
            else dollGender = "female";

            lmSetConfig("dollGender", dollGender);
        }
    }
#ifdef DEVELOPER_MODE
    else {
        llSay(DEBUG_CHANNEL,"Unknown configuration value in preferences: " + name + " on line " + (string)(ncLine + 1));
    }
#endif
    llSleep(0.1);  // approx 5 frames - be nice to sim!
}

// PURPOSE: readPreferences reads the Preferences notecard, if any -
//          and runs doneConfiguration if no notecard is found

readPreferences() {
    ncStart = llGetTime();

    // Check to see if the file exists and is a notecard
    if (cdNotecardExists(NOTECARD_PREFERENCES)) {
        llOwnerSay("Loading Key Preferences Notecard");

        // Start reading from first line (which is 0)
        ncLine = 0;
        ncPrefsKey = llGetNotecardLine(NOTECARD_PREFERENCES, ncLine);
    }
    else {
        // File missing - report for debugging only
        debugSay(1, "DEBUG-START", "No configuration found (" + NOTECARD_PREFERENCES + ")");

        prefsRead = PREFS_NOT_READ;
        lmInitState(101);
    }
}

// PURPOSE: doneConfiguration is called after preferences are done:
//          that is, preferences have been read if they exist

doneConfiguration(integer prefsRead) {
    // By now preferences SHOULD have been read - if there were any.
    // the variable prefsRead allows us to know if prefs were read...
    // but how do we use this knowledge?

    if (!prefsRead) llOwnerSay("No preferences were read");

    // Make sure the wind is a reasonable value. If not:
    // windNormal is set to force six winds - but rounded to a
    // value divided by 5. (The latter step is merely for user
    // comfort, rather than a strange and odd number coming out.)
    if (windNormal > keyLimit) windNormal = (keyLimit / 6) % 5;

    lmSendConfig("windNormal",(string)windNormal);
    lmSetConfig("keyLimit",(string)keyLimit);

    resetState = RESET_NONE;

    // The messages 102, 104, 105 - and 110 - are not handled by us,
    // but by others. They are a message that things are done here, and certain
    // items are are completed.
    debugSay(3,"DEBUG-START","Configuration done - starting init code 102 and 104 and 105");
    lmInitState(102);
    lmInitState(104);
    lmInitState(105);

    //initializationCompleted
    isAttached = cdAttached();

    if (dollDisplayName == "") {
        string name = dollName;
        integer i = llSubStringIndex(name, " ");

        if (i != NOT_FOUND) name = llGetSubString(name, 0, i - 1);

        lmSendConfig("dollDisplayName", (dollDisplayName = "Dolly " + name));
    }

    // WearLock should be clear
    lmSetConfig("wearLock","0");

    if (isAttached) cdSetKeyName(dollDisplayName + "'s Key");

    lmInitState(110);

    debugSay(3,"DEBUG-START","doneConfiguration done - exiting");
}

doRestart() {

    integer n;
    string script;

    // Set all other scripts to run state and reset them
    n = llGetInventoryNumber(INVENTORY_SCRIPT);
    while(n--) {
        script = llGetInventoryName(INVENTORY_SCRIPT, n);
        if (script != "Start") {

            debugSay(5,"DEBUG-START","====> Resetting script: '" + script + "'");

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
        split             =     cdSplitArgs(data);
        script            =     cdListElement(split, 0);
        remoteSeq         =     (i & 0xFFFF0000) >> 16;
        optHeader         =     (i & 0x00000C00) >> 10;
        code              =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        scaleMem();

        if (code == CONFIG) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);
            split = llDeleteSubList(split,0,0);

                 if (name == "keyLimit")                      keyLimit = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                  debugLevel = (integer)value;
#endif
            else if (name == "blacklist") {
                if (split == [""]) blacklist = [];
                else blacklist = split;
            }
            else if (name == "keyAnimation") {
                string oldKeyAnimation = keyAnimation;
                keyAnimation = value;

                if (!collapsed) {

                    // Dolly is operating normally (not collapsed)

                    if (RLVok == TRUE) {
                        if (cdPoseAnim()) {
                            // keyAnimation is a pose of some sort
			    if (defaultPoseRLVcmd) {
			        lmRunRLV(defaultPoseRLVcmd);
                            }
			    if (userPoseRLVcmd) {
			        lmRunRLVas("UserPose", userPoseRLVcmd);
                            }
                        }
                        else if (oldKeyAnimation != keyAnimation) {
                            // animation just became null
                            //lmRunRLV("clear"); // FIXME: This is too generic
		            lmRunRLVcmd("clearRLVcmd","");
                        }
                    }
                }
            }
            else if (name == "afk") {
                integer oldAfk = afk;
                afk = (integer)value;

                if (!collapsed) {
                    // a collapse overrides AFK - ignore AFK if we are collapsed
                    if (RLVok == TRUE) {
                        if (afk) {
                            lmRunRLV(defaultAfkRLVcmd);
                            if (userAfkRLVcmd) lmRunRLVas("UserAfk", userAfkRLVcmd);
                        }
                        else if (oldAfk != afk) {
                            // afk value JUST became zero
                            if (RLVok == TRUE) // lmRunRLV("clear"); // FIXME: This is too generic
		                lmRunRLVcmd("clearRLVcmd","");
                        }
                    }
                }
            }
            else if (name == "userCollapseRLVcmd")  userCollapseRLVcmd = value;
            else if (name == "userPoseRLVcmd")          userPoseRLVcmd = value;
            else if (name == "userAfkRLVcmd")            userAfkRLVcmd = value;
            else if (name == "defaultBaseRLVcmd")    defaultBaseRLVcmd = value;

#ifdef GEM_PRESENT
            else if (name == "gemColour") {      gemColour = (vector)value; doLuminosity(); }
#ifdef GEMGLOW_OPT
            else if (name == "gemGlow")  {      gemGlow = (integer)value; doLuminosity(); }
#endif
            else if (name == "gemLight") {     gemLight = (integer)value; doLuminosity(); }
            else if (name == "isVisible") {       visible = (integer)value; doLuminosity(); }
#endif
            else if (name == "collapsed") {
                integer wasCollapsed = collapsed;
                collapsed = (integer)value;

                if (RLVok == TRUE) {
                    if (collapsed) {
                        // We are collapsed: activate RLV restrictions
                        lmRunRLV(defaultCollapseRLVcmd);
                        if (userCollapseRLVcmd != "") lmRunRLVas("UserCollapse", userCollapseRLVcmd);
                    }
                    else {
                        if (wasCollapsed) {
                            // We were collapsed but aren't now... so clear RLV restrictions
                            //lmRunRLV("clear"); // FIXME: this is too generic
		            lmRunRLVcmd("clearRLVcmd","");
                        }
                    }
                }

#ifdef GEM_PRESENT
                if (collapsed)
                    // set gem colour to gray
                    lmInternalCommand("setGemColour", "<0.867, 0.867, 0.867>", NULL_KEY);
                else
                    lmInternalCommand("resetGemColour", "", NULL_KEY);
                doLuminosity();
#endif
            }
            else if (name == "dollDisplayName") {
                if (script != cdMyScriptName()) {
                    dollDisplayName = value;

                    if (dollDisplayName == "") {
                        string name = dollName;
                        integer space = llSubStringIndex(name, " ");

                        if (space != NOT_FOUND) name = llGetSubString(name, 0, space -1);

                        lmSendConfig("dollDisplayName", (dollDisplayName = "Dolly " + name));
                    }
                    if (cdAttached()) cdSetKeyName(dollDisplayName + "'s Key");
                }
            }
        }
        else if (code == RLV_RESET) {
            RLVok = llList2Integer(split, 0);
            rlvWait = 0;

            if (newAttach) {

                newAttach = 0;

                if (cdAttached()) {
                    string msg = dollName + " has logged in with";

                    if (RLVok != TRUE) msg += "out";
                    msg += " RLV at " + wwGetSLUrl();

                    lmSendToController(msg);
                }
            }

            if (RLVok == TRUE) {
                // If RLV is ok, then trigger all of the necessary RLV restrictions
                // (collapse is managed by Main)
                if (!collapsed) {
                    // Not collapsed: clear any user collapse RLV restrictions
                    //lmRunRLV("clear"); // FIXME: This messes things up
		    lmRunRLVcmd("clearRLVcmd","");

                    // Is Dolly AFK? Trigger RLV restrictions as appropriate
                    if (afk) {
                        lmRunRLV(defaultAfkRLVcmd);
                        if (userAfkRLVcmd != "") lmRunRLVas("UserAfk", userAfkRLVcmd);
                    }

                    // Are we posed? Trigger RLV restrictions for being posed
                    if (cdPoseAnim()) {
                        lmRunRLV(defaultPoseRLVcmd);
                        if (userPoseRLVcmd != "") lmRunRLVas("UserPose", userPoseRLVcmd);
                    }
                }
            }
        }
#ifdef DEVELOPER_MODE
        else if (code == MENU_SELECTION) {
            string selection = llList2String(split, 0);
            string name = llList2String(split, 1);

            if (selection == "Reset Key") cdResetKey();
        }
#endif
        else if (code < 200) {
            if (code == 101) {
                doneConfiguration(prefsRead);
            }
            else if (code == 102) {
                ;
            }
            else if (code == 110) {
                
                msg = "Initialization completed in " +
                      formatFloat((llGetTime() - initTimer), 1) + "s" +
                      "; key ready";

                llOwnerSay(msg);

                msg =
#ifdef DEVELOPER_MODE
                      "This is a Developer Key. Treat it with tender loving care: polish once a week, and oil four times a year.";
#else
#ifdef ADULT_MODE
                      "This is an Adult Key. Treat it with tender loving care: polish once a week, and oil four times a year.";
#else
                      "This is a Child Key. Tell your Parent or Guardian or other Trusted Adult to polish it once a week, and oil it four times a year.";
#endif
#endif

                llOwnerSay(msg);

                // When starting up, let people know...
                if (newAttach && isAttached)
                    llSay(0, llGetDisplayName(llGetOwner()) + " is now a dolly - anyone may play with their Key.");
            }
            else if (code == MEM_REPORT) {
                if (script == cdMyScriptName()) return;

                float delay = llList2Float(split, 0);
                memReport(cdMyScriptName(),delay);
            }
            else if (code == CONFIG_REPORT) {
                cdConfigureReport();
            }
        }
    }

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {

        initTimer = llGetTime();

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
        llSleep(0.5);

#ifdef DEVELOPER_MODE
        // Set the debug level for all scripts early
        lmSendConfig("debugLevel",(string)debugLevel);
#endif
        readPreferences();
        llSleep(0.1);
        lmInternalCommand("collapse", "0", llGetKey());
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
        llResetTime();
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);

        if (cdAttached()) llRequestPermissions(dollID, PERMISSION_MASK);
        else cdResetKeyName();

        //RLVok = UNSET;
#ifdef DEVELOPER_MODE
        // Set the debug level for all scripts early
        lmSendConfig("debugLevel",(string)debugLevel);
#endif
    }

    //----------------------------------------
    // ATTACH
    //----------------------------------------
    attach(key id) {

        lmInternalCommand("setWindRate","",NULL_KEY);
        if (id == NULL_KEY) {

            if(!llGetAttached()) cdResetKeyName();

            // At this point, we know that we have a REAL detach:
            // key id is NULL_KEY and llGetAttached() == 0

            llMessageLinked(LINK_SET, 106,  "Start|detached|" + (string)lastAttachPoint, lastAttachAvatar);
            llOwnerSay("The key is wrenched from your back, and you double over at the unexpected pain as the tendrils are ripped out. You feel an emptiness, as if some beautiful presence has been removed.");

        } else {

            isAttached = 1;
            llMessageLinked(LINK_SET, 106, "Start|attached|" + (string)cdAttached(), id);

            if (llGetPermissionsKey() == dollID && (llGetPermissions() & PERMISSION_TAKE_CONTROLS) != 0) llTakeControls(CONTROL_MOVE, 1, 1);
            else llRequestPermissions(dollID, PERMISSION_MASK);

            if (lastAttachAvatar == NULL_KEY) newAttach = 1;
        }

        // when attaching key, user is NOT AFK...
        lmSetConfig("afk", NOT_AFK);

        // reset collapse environment
        lmInternalCommand("collapse", (string)collapsed, llGetKey());

        lastAttachPoint = cdAttached();
        lastAttachAvatar = id;
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key query_id, string data) {

        if (query_id == ncPrefsKey) {
            // Read notecard: Preferences
            if (data == EOF) {
                //lmSendConfig("ncPrefsLoadedUUID", llDumpList2String(llList2List((string)llGetInventoryKey(NOTECARD_PREFERENCES) + ncPrefsLoadedUUID, 0, 9),"|"));
                lmInternalCommand("getTimeUpdates","",NULL_KEY);
#ifdef GEM_PRESENT
                lmInternalCommand("setNormalGemColour",(string)prefGemColour,NULL_KEY);
#endif

                llOwnerSay("Preferences read in " + formatFloat(llGetTime() - ncStart, 2) + "s");

                prefsRead = PREFS_READ;
                lmInitState(101);
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
                    debugSay(2, "DEBUG-START", "Processing configuration: name = " + name + "; value = " + value);
                    processConfiguration(name, value);
                }

                // get next Notecard Line
                llSleep(0.1);
                ncPrefsKey = llGetNotecardLine(NOTECARD_PREFERENCES, ++ncLine);
            }
        }
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & CHANGED_OWNER) {

            integer nCards = llGetInventoryNumber(INVENTORY_NOTECARD);
            string name;

            i = nCards;
            while (i--) {
                name = llGetInventoryName(INVENTORY_NOTECARD,i);
                if (name == NOTECARD_PREFERENCES) {
                    llRemoveInventory(name);
                }
            }

            llOwnerSay("You have a new key! Congratulations!\n" +
                "Look at PreferencesExample to see how to set the preferences for your new key.");

            llSleep(1.0);
            cdResetKey(); // start over with no preferences
        }

        // THis section of code has a danger in it for RLV locked keys:
        // if the user can modify the key - and change its inventory -
        // it may be possible to override values at the least and to
        // reset the key at the worst.
        //
        // Note that if Start.lsl is modified, this does not get run,
        // since Start.lsl is reset immediately - and upon reset,
        // resets the entire key.
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

//========== START ==========
