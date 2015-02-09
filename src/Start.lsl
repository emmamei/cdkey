//========================================
// Start.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

#include "include/Json.lsl"
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
#ifdef GEMGLOW_OPT
integer gemGlow = YES;
#endif
integer gemLight = YES;
integer dbConfigCount;
integer i;

string attachName;
string prefGemColour; // use this to set gem color
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

        list params;
        integer nPrims = llGetNumberOfPrims();
        integer i;
        string name;
        float glow;
        integer primN;

        i = nPrims;
        while (i--) {
            primN = i + 1;
            name = llGetLinkName(primN);
            glow = 0.0;

            // Start a new Link Target
            params += [ PRIM_LINK_TARGET, primN ];

            if (llGetSubString(name, 0, 4) == "Heart") {
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

    // Configuration entries: these are the actual configuration
    // commands; they must match with a sendName below
    list configs = [ "quiet key", "outfits path",
                     "busy is away", "can afk", "can fly", "poseable", "can sit", "can stand",
                     "can dress", "detachable", "doll type",
#ifdef ADULT_MODE
                     "strippable",
#endif
                     "pose silence",
                     "auto tp", "outfitable", "max time", "chat channel", "dolly name", "demo mode",
                     "afk rlv", "collapse rlv", "pose rlv" , "show phrases",
#ifdef DEVELOPER_MODE
                     "debug level",
#endif
                     "dressable", "carryable", "repeatable wind"
                   ];

    // "Send Names": these are the configuration variable names;
    // they must be matched with a configs entry above
    list sendName = [ "quiet", "outfitsFolder",
                      "busyIsAway", "canAfk", "canFly", "allowPose", "canSit", "canStand",
                      "canDressSelf", "detachable", "dollType",
#ifdef ADULT_MODE
                      "allowStrip",
#endif
                      "poseSilence",
                      "autoTP", "allowDress", "keyLimit", "chatChannel", "dollDisplayName", "demoMode",
                      "userAfkRLVcmd", "userCollapseRLVcmd", "userPoseRLVcmd" , "showPhrases",
#ifdef DEVELOPER_MODE
                     "debugLevel",
#endif
                      "allowDress", "allowCarry", "allowRepeatWind"
                    ];

    // Three specially handled configuration entries:
    //   * doll gender
    //   * blacklist key
    //   * controller key

    // This processes a single line from the preferences notecard...
    // processing done a single time during the read of the nc belong elsewhere

    name = llToLower(name);

    if ((i = cdListElementP(configs,name)) != NOT_FOUND) {
        if (name == "max time") {
            float val = (float)value;

            // validate value for max time (in minutes)
            if (val > 240) val = 240;
            else if (val < 10) val = 30;

            // convert to seconds and store back
            value = (string)(val * SEC_TO_MIN);
        }

        // FIXME: Note the lack of validation here (!)
        debugSay(2, "DEBUG-START", "Sending message " + cdListElement(sendName,i) + " with value " + (string)value);

        // Do both ways for now, just until all are converted or handled
        lmSetConfig(cdListElement(sendName,i), value);
        lmSendConfig(cdListElement(sendName,i), value);
        llSleep(0.1);  // approx 5 frames - be nice to sim!
    }
    else if (name == "max time") {
        keyLimit = (integer)value;

        if (keyLimit > 240) keyLimit = 240;
        else if (keyLimit < 15) keyLimit = 15;

        if (keyLimit < windNormal) windNormal = llFloor(keyLimit / 6);

        lmSendConfig("windNormal",(string)windNormal);
        lmSetConfig("keyLimit",(string)keyLimit);
    }
    else if (name == "wind time") {
        integer windMins = (integer)value;

        // validate value
        if (windMins > 90) windMins = 90;
        else if (windMins < 15) windMins = 15;
        windNormal = windMins * (integer)SECS_PER_MIN;

        // If it takes 2 winds or less to wind dolly, then we fall back to 6
        // winds: note that this happens AFTER the numerical validation: so
        // potentioally, after this next statement, we could have a wind time
        // of less than 15 - which is to be expected
        if (windNormal > (keyLimit / 2)) windNormal = llFloor(keyLimit / 6);

        lmSendConfig("windNormal",(string)windNormal);
        lmSetConfig("keyLimit",(string)keyLimit);
    }
    else if (name == "gem colour" || name == "gem color") {
        if ((vector)value != ZERO_VECTOR) prefGemColour = value;
    }
    else if (name == "chat mode") {
        // Set the way chat operates

        // Note that a value of "world" doesn't actually require
        // any action at all
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
#ifdef DEVELOPER_MODE
    else {
        llSay(DEBUG_CHANNEL,"Unknown configuration value in preferences: " + name + " on line " + (string)(ncLine + 1));
    }
#endif
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
    } else {
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
        integer space = llSubStringIndex(name, " ");

        if (space != NOT_FOUND) name = llGetSubString(name, 0, space - 1);

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

                    if (cdPoseAnim()) {
                        // keyAnimation is a pose of some sort
                        if (defaultPoseRLVcmd)
                            lmRunRLV(defaultPoseRLVcmd);
                        if (userPoseRLVcmd)
                            lmRunRLVas("UserPose", userPoseRLVcmd);
                    }
                    else if (oldKeyAnimation != keyAnimation) {
                        // animation just became null
                        lmRunRLV("clear");
                    }
                }
            }
            else if (name == "afk") {
                integer oldAfk = afk;
                afk = (integer)value;

                if (!collapsed) {
                    // a collapse overrides AFK - ignore AFK if we are collapsed
                    if (afk) {
                        lmRunRLV(defaultAfkRLVcmd);
                        if (userAfkRLVcmd)
                            lmRunRLVas("UserAfk", userAfkRLVcmd);
                    }
                    else if (oldAfk != afk) {
                        // afk value JUST became zero
                        lmRunRLV("clear");
                    }
                }
            }
            else if (name == "userCollapseRLVcmd")  userCollapseRLVcmd = value;
            else if (name == "userPoseRLVcmd")          userPoseRLVcmd = value;
            else if (name == "userAfkRLVcmd")            userAfkRLVcmd = value;

            else if (name == "gemColour") {      gemColour = (vector)value; doLuminosity(); }
#ifdef GEMGLOW_OPT
            else if (name == "gemGlow")  {      gemGlow = (integer)value; doLuminosity(); }
#endif
            else if (name == "gemLight") {     gemLight = (integer)value; doLuminosity(); }
            else if (name == "isVisible") {       visible = (integer)value; doLuminosity(); }

            else if (name == "collapsed") {
                integer wasCollapsed = collapsed;
                collapsed = (integer)value;

                //debugSay(2, "DEBUG-START", "Collapsed = " + (string)collapsed);
                //debugSay(2, "DEBUG-START", "defaultCollapseRLVcmd = " + defaultCollapseRLVcmd);
                //debugSay(2, "DEBUG-START", "userCollapseRLVcmd = " + userCollapseRLVcmd);

                if (collapsed) {
                    // We are collapsed: activate RLV restrictions
                    lmRunRLV(defaultCollapseRLVcmd);
                    if (userCollapseRLVcmd != "") lmRunRLVas("UserCollapse", userCollapseRLVcmd);

                    // set gem colour to gray
                    lmInternalCommand("setGemColour", "<0.867, 0.867, 0.867>", NULL_KEY);
                }
                else {
                    lmInternalCommand("resetGemColour", "", NULL_KEY);
                    if (wasCollapsed) {
                        // We were collapsed but aren't now... so clear RLV restrictions
                        lmRunRLV("clear");
                    }
                }
                doLuminosity();
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
            RLVok = (llList2Integer(split, 0) == 1);
            rlvWait = 0;

            if (newAttach) {

                newAttach = 0;

                if (cdAttached()) {
                    string msg = dollName + " has logged in with";

                    if (!RLVok) msg += "out";
                    msg += " RLV at " + wwGetSLUrl();

                    lmSendToController(msg);
                }
            }

            if (RLVok) {
                // If RLV is ok, then trigger all of the necessary RLV restrictions
                // (collapse is managed by Main)
                if (!collapsed) {
                    // Not collapsed: clear any user collapse RLV restrictions
                    lmRunRLV("clear");

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

        // Set the debug level for all scripts early
#ifdef DEVELOPER_MODE
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

        RLVok = UNSET;
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

        // when attaching we're not in lowScriptMode
        //lowScriptMode = 0;
        //lmSendConfig("lowScriptMode", "0");

        // reset collapse environment
#ifdef JAMMABLE
        if (collapsed == JAMMED) collapsed = NOT_COLLAPSED;
#endif
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
                lmInternalCommand("setNormalGemColour",(string)prefGemColour,NULL_KEY);

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
                if ((llGetSubString(name,0,0) == "*") || (name == NOTECARD_PREFERENCES)) {
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
