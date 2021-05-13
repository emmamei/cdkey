//========================================
// Start.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

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

#define cdResetKeyName() llSetObjectName(PACKAGE_NAME + " " + __DATE__)

//=======================================
// VARIABLES
//=======================================
string msg;
float delayTime = 15.0; // in seconds
float initTimer;

key ncPrefsKey;
//integer prefsRead;

integer ncLine;
integer failedReset;

//float ncStart;
integer lastAttachPoint;
key lastAttachAvatar;

integer newAttach = YES;
integer dbConfigCount;
integer i;

string attachName;
integer isAttached;

string outfitFolderExpected;
string dollTypeExpected;

//integer introLine;
//integer introLines;

integer startParameter;
//integer resetState;
#define RESET_NONE 0
#define RESET_NORMAL 1
#define RESET_STARTUP 2

//integer rlvWait;

//=======================================
// FUNCTIONS
//=======================================

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
#ifdef USER_RLV
                     "collapse rlv", "pose rlv",
#endif
                     "doll gender", "helpless dolly", "chat mode", "controller", "blacklist"
                   ];

    // The settings list and the settingName list much match up
    // with entries
    list settings = [ "hardcore", "busy is away",
                      "can fly", "poseable", "can sit", "can stand", "can dress self", "detachable",
#ifdef ADULT_MODE
                      "strippable",
#endif
                      "pose silence", "auto tp", "dressable", "outfitable", "can dress",
                      "show phrases", "carryable", "repeatable wind", "ghost"
                    ];

    list settingName = [ "hardcore", "busyIsAway",
                         "canFly", "allowPose", "canSit", "canStand", "canDressSelf", "detachable",
#ifdef ADULT_MODE
                         "allowStrip",
#endif
                         "poseSilence", "autoTP", "allowDress", "allowDress", "canDressSelf",
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
            // Defer actual setting of outfitsFolder until later
            //
            //lmSetConfig("outfitFolder", value);
            outfitFolderExpected = value;
        }
        else if (name == "doll type") {
            // Defer actual setting of dollType until later
            //
            //lmSetConfig("dollType", value);
            dollTypeExpected = value;
        }
        else if (name == "chat channel") {
            // cant be 0 or MAXINT (DEBUG_CHANNEL)
            lmSetConfig("chatChannel", value);
        }
        else if (name == "dolly name") {
            // should be printable
            lmSendConfig("dollDisplayName", (dollDisplayName = value));
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
#ifdef USER_RLV
        else if (name == "collapse rlv") {
            // has to be valid rlv
            defaultCollapseRLVcmd += "," + value;
            lmSendConfig("defaultCollapseRLVcmd", value);
        }
        else if (name == "pose rlv") {
            // has to be valid rlv
            defaultPoseRLVcmd += "," + value;
            lmSendConfig("defaultPoseRLVcmd", value);
        }
#endif

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
        else if (name == "blacklist") {
            string uuid = (string)value;
            blacklist = (blacklist = []) + blacklist + [ (string)value, (string)value ];
            lmSetConfig("blacklist", llDumpList2String(blacklist, "|"));
        }
        else if (name == "controller") {
            string uuid = (string)value;
            controllers = (controllers = []) + controllers + [ (string)value, (string)value ];
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

    // Check to see if the file exists and is a notecard
    if (cdNotecardExists(NOTECARD_PREFERENCES)) {
        llOwnerSay("Loading Key Preferences Notecard");

        // Start reading from first line (which is 0)
        ncLine = 0;
        ncPrefsKey = llGetNotecardLine(NOTECARD_PREFERENCES, ncLine);
    }
    else {
        llOwnerSay("No preferences file was found (\"" + NOTECARD_PREFERENCES + "\")");

        //prefsRead = PREFS_NOT_READ;
        lmInitState(INIT_STAGE3);
    }
}

doRestart() {

    integer n;
    string script;

    // Set all other scripts to run state and reset them
    n = llGetInventoryNumber(INVENTORY_SCRIPT);
    while(n--) {

        // if script is Start, then thats US! don't reset...
        // if script is New, then the script should finish
        // running and self-erase; so ignore
        script = llGetInventoryName(INVENTORY_SCRIPT, n);
        if (script != "Start") {

            // Set other scripts to running, then reset them all
            cdRunScript(script);
            llResetOtherScript(script);
        }
    }

    //resetState = RESET_NONE;
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

        //scaleMem();

        if (code == SEND_CONFIG) {
            string name = (string)split[0];
            string value = (string)split[1];
            split = llDeleteSubList(split,0,0);

                 if (name == "keyLimit")                      keyLimit = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                  debugLevel = (integer)value;
#endif
            else if (name == "collapsed")                    collapsed = (integer)value;
            else if (name == "dollType")                      dollType = value;
            else if (name == "blacklist") {
                if (split == [""]) blacklist = [];
                else blacklist = split;
            }

            else if (name == "poseAnimation") {
                poseAnimation = value;

                //lmSendConfig("poseAnimation", value);

                if ((!collapsed) && (RLVok == TRUE)) {

                    // Dolly is operating normally (not collapsed)
                    // and this is a pose, not a collapse

                    if (poseAnimation == "" && !collapsed) {
                        // Not collapsed or posed - so clear to base RLV
                        lmRunRLVcmd("clearRLVcmd",defaultBaseRLVcmd);
                    }
                    else {
                        // Posed: activate RLV restrictions
                        lmRestrictRLV(defaultPoseRLVcmd);
                    }
                }
            }
            else if (name == "defaultBaseRLVcmd")    defaultBaseRLVcmd = value;
        }
        else if (code == RLV_RESET) {
            RLVok = (integer)split[0];
            //rlvWait = 0;

            if (newAttach) {

                newAttach = 0;

                if (isAttached) {
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
                    debugSay(2, "DEBUG-START", "Clearing on RLV_RESET");
                    lmRunRLVcmd("clearRLVcmd","");

                    // Are we posed? Trigger RLV restrictions for being posed
                    if (poseAnimation != ANIMATION_NONE) {
                        lmRestrictRLV(defaultPoseRLVcmd);
                    }
                }
            }
        }
        else if (code == MENU_SELECTION) {
            string selection = (string)split[0];
            string name = (string)split[1];

            if (selection == "Reset Key") cdResetKey();
        }
        else if (code < 200) {
            if (code == INIT_STAGE1) {
                debugSay(3,"DEBUG-START","Stage 1 begun.");

                lmInternalCommand("collapse", "0", keyID);
            }
            else if (code == INIT_STAGE2) {
                debugSay(3,"DEBUG-START","Stage 2 begun.");

                readPreferences();

                // Check for items necessary for proper operation
                // and give error messages or warnings
                //
                if (!(arePosesPresent()))
                    llSay(DEBUG_CHANNEL,"No pose animations are present!");

                if (!(isCollapseAnimationPresent()))
                    llSay(DEBUG_CHANNEL,"No collapse animation!");

                if (!(isPreferencesNotecardPresent())) {
                    llOwnerSay("No preferences notecard present.");

                    // This only checks for Preferences Example notecard if Preferences notecard is missing
                    if (!(isNotecardPresent("Preferences Example")))
                        llOwnerSay("No preferences example file present.");
                }

                if (!(isNotecardPresent(NOTECARD_HELP)))
                    llOwnerSay("No help file present.");

                if (!(isLandmarkPresent(LANDMARK_CDHOME)))
                    llOwnerSay("No Community Dolls home landmark present.");

                if (!(isLandmarkPresent(LANDMARK_HOME)))
                    llOwnerSay("No home landmark present: Homing beacon will be disabled.");
            }
            else if (code == INIT_STAGE3) {
                // Stage 3 is triggered by CheckRLV completing its RLV checks...
                //
                // At this point, RLV has been determined and set
                debugSay(3,"DEBUG-START","Stage 3 begun.");

                // Put out settings that we may or may not have read in the preferences file,
                // with their appropriate defaults as necessary
                lmSetConfig("outfitFolder", outfitFolderExpected);
                lmSetConfig("dollType", dollTypeExpected);
            }
            else if (code == INIT_STAGE4) {
                // Stage 4 is triggered by Transform completing its search for an outfit folder...
                //
                // At this point, outfitFolder has been set one way or the other
                debugSay(3,"DEBUG-START","Stage 4 begun.");
                string name = dollName;

                // Check if dollDisplayName is unset
                if (dollDisplayName == "") {
                    integer i = llSubStringIndex(dollName, " ");

                    // if a space is found, use the first word as the name
                    if (i != NOT_FOUND) dollDisplayName = "Dolly " + llGetSubString(dollName, 0, i - 1);
                    else dollDisplayName = "Dolly " + dollName;
                }

                // WearLock should be clear
                lmSetConfig("wearLock","0");

                lmSendConfig("dollDisplayName", dollDisplayName);
                cdSetKeyName(dollDisplayName + "'s Key");

                lmInitState(INIT_STAGE5);
            }
            else if (code == INIT_STAGE5) {
                debugSay(3,"DEBUG-START","Stage 5 begun.");
                
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
                    llSay(PUBLIC_CHANNEL, llGetDisplayName(llGetOwner()) + " is now a dolly - anyone may play with their Key.");
            }
#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                if (script == cdMyScriptName()) return;

                float delay = (float)split[0];
                memReport(cdMyScriptName(),delay);
            }
#endif
            else if (code == CONFIG_REPORT) {
                cdConfigureReport();
            }
        }
    }

    // * state_entry:
    //     - This will run if it has not already run, and before on_rez and attach
    //
    // * on_rez:
    //     - This section will run before attach when attaching from inventory or when logging in
    //
    // * attach:
    //     - This runs when Dolly logs in or attaches from inventory or attaches from ground
    //
    // THUS:
    //
    // * Brand New Key Worn: state_entry, on_rez, attach
    // * Dolly Attaches Her Key: on_rez, attach
    // * Dolly Logs In: on_rez, attach
    // * Dolly Updates Key: state_entry
    // * Dolly Resets Key: state_entry

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        startParameter = llGetStartParameter();

        // This helps during debugging to set off the reset sequence in logs
        llOwnerSay("******** KEY RESET ********");

        // start parameter can ONLY be set via llRemoteLoadScriptPin()
        if (startParameter == 100) {
            llOwnerSay("Key has been updated.");
        }

        initTimer = llGetTime();

        dollID = llGetOwner();
        keyID = llGetKey();
        dollName = lmMyDisplayName(dollID);

        //rlvWait = 1;
        cdInitializeSeq();
        //resetState = RESET_STARTUP;

        isAttached = cdAttached();
        if (isAttached) llRequestPermissions(dollID, PERMISSION_MASK);
        else {
            llOwnerSay("Key not attached");
            //cdResetKeyName();
        }

        // WHen this script (Start.lsl) resets... EVERYONE resets...
        doRestart();
        llSleep(0.5);

        lmInitState(INIT_STAGE1);
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        llResetTime();
        dollID = llGetOwner();
        dollName = lmMyDisplayName(dollID);

        isAttached = cdAttached();
        if (isAttached) llRequestPermissions(dollID, PERMISSION_MASK);

#ifdef DEVELOPER_MODE
        // Note this should be set by prefs, but the prefs require a lot before
        // they are read
        debugLevel = 8;

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

            //if(!llGetAttached()) cdResetKeyName();

            // At this point, we know that we have a REAL detach:
            // key id is NULL_KEY and llGetAttached() == 0

            llMessageLinked(LINK_SET, 106,  "Start|detached|" + (string)lastAttachPoint, lastAttachAvatar);
            llOwnerSay("The key is wrenched from your back, and you double over at the unexpected pain as the tendrils are ripped out. You feel an emptiness, as if some beautiful presence has been removed.");

        } else {

            isAttached = 1;
            llMessageLinked(LINK_SET, 106, "Start|attached|" + (string)isAttached, id);

            if (llGetPermissionsKey() == dollID && (llGetPermissions() & PERMISSION_TAKE_CONTROLS) != 0) llTakeControls(CONTROL_MOVE, 1, 1);
            else llRequestPermissions(dollID, PERMISSION_MASK);

            if (lastAttachAvatar == NULL_KEY) newAttach = 1;
        }

        // when attaching key, user is NOT AFK...
        lmSetConfig("isAFK", "0");

        // reset collapse environment
        lmInternalCommand("collapse", (string)collapsed, keyID);

        lastAttachPoint = cdAttached();
        lastAttachAvatar = id;
    }

    //----------------------------------------
    // TOUCH START
    //----------------------------------------
    touch_start(integer num) {
        if (isAttached) llRequestPermissions(dollID, PERMISSION_MASK);
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key query_id, string data) {

        if (query_id == ncPrefsKey) {

            // Read notecard: Preferences

            if (data == EOF) {

                // Make sure the wind is a reasonable value. If not:
                // windNormal is set to force six winds - but rounded to a
                // value divided by 5. (The latter step is merely for user
                // comfort, rather than a strange and odd number coming out.)
                if (windNormal > keyLimit) {
                    windNormal = (keyLimit / 6) % 5;
                    llSay(DEBUG_CHANNEL,"Wind setting exceeds max time on key! (changed to " + (string)(windNormal) + ")");
                }

                lmSendConfig("windNormal",(string)windNormal);
                lmSetConfig("keyLimit",(string)keyLimit);

                //prefsRead = PREFS_READ;
                lmInitState(INIT_STAGE3);
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
                    debugSay(6, "DEBUG-START", "Processing configuration: name = " + name + "; value = " + value);
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

            // Remove preferences notecard if present
            if (isPreferencesNotecardPresent())
                    llRemoveInventory(NOTECARD_PREFERENCES);

            llOwnerSay("You have a new key! Congratulations!\n");

            if (isNotecardPresent("Preferences Example")) {
                llOwnerSay("Look at the example Preferences file in the Key contents to see how to set the preferences for your new key.");
                llGiveInventory(llGetOwner(), "Preferences Example");
            }

            if (isNotecardPresent(NOTECARD_HELP)) {
                llOwnerSay("Look at help file to learn about your key.");
                llGiveInventory(llGetOwner(), NOTECARD_HELP);
            }

            if (isLandmarkPresent(LANDMARK_CDHOME)) {
                llOwnerSay("Here is the landmark to the Community Dolls home sim.");
                llGiveInventory(llGetOwner(), LANDMARK_CDHOME);
            }

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
