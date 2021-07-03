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
#define USER_NAME_QUERY_TIMEOUT 15
#define cdRunScript(a) llSetScriptState(a, RUNNING)
#define cdStopScript(a) llSetScriptState(a, NOT_RUNNING)
#define cdIsScriptRunning(a) llGetScriptState(a)
#define cdNotecardNotExist(a) (llGetInventoryType(a) != INVENTORY_NONE)
#define cdNotecardExists(a) (llGetInventoryType(a) == INVENTORY_NOTECARD)
#define cdList2String(a) llDumpList2String(a,"|")

// This action is different in different scripts;
// they do the same thing (reset Start.lsl)
#define cdResetKey() llResetScript()

#define PREFS_READ 1
#define PREFS_NOT_READ 0

#define cdResetKeyName() llSetObjectName(PACKAGE_NAME + " " + __DATE__)

// If we have permissions, we don't need to do it again
// If we do not, getting permissions does what we need
#define workInNoScriptLand(d) if (permUnset) llRequestPermissions((d), PERMISSION_MASK)
#define makeWorkInNoScriptLand(d) llRequestPermissions((d), PERMISSION_MASK)

#define keyDetached(id) (id == NULL_KEY)

//=======================================
// VARIABLES
//=======================================
string msg;
float delayTime = 15.0; // in seconds
float initTimer;

integer ncLine;
integer failedReset;
integer rlvPreviously;

integer dbConfigCount;
integer i;

string outfitFolderExpected;
string dollTypeExpected;

integer startParameter;
#define RESET_NONE 0
#define RESET_NORMAL 1
#define RESET_STARTUP 2

list keySpecificConfigs;

key notecardQueryID;

key blacklistQueryID;
key controllerQueryID;
key blacklistQueryUUID;
key controllerQueryUUID;
string queryUUID;

//=======================================
// FUNCTIONS
//=======================================

list remList(list workingList, string uuid, key id) {
    list workingList;

    string nameURI = "secondlife:///app/agent/" + uuid + "/displayname";

    // Test for presence of uuid in list: if it's not there, we can't remove it
    string s;
    integer i;

    if (~(i = llListFindList(workingList, (list)uuid))) {

        s = "Removing user " + nameURI + " from the list";
        cdSayToAgentPlusDoll(s, id);

        workingList = llDeleteSubList(workingList, i, i + 1);
    }
    else {
        cdSayTo("User " + nameURI + " is not in the list",id);
    }

    return workingList;
}

//---------------------------------------
// Configuration Functions
//---------------------------------------

processBooleanSetting(string settingName, string settingValue) {

    settingValue = llToLower(settingValue);

    switch(settingValue): {

        case "yes":
        case "on":
        case "y":
        case "t":
        case "true":
        case "1": {

            // Special handling for ghost setting: configSettingValue is a boolean,
            // but result is to change the visibility value...
            //
            // Special handling, too, for auto tp setting: "auto tp" maps onto canRejectTP
            // but inverted: so we invert the value setting. (The term auto tp is historical.)
            //
            // Special handling for pose silence setting likewise.
            //
            if (settingName == "ghost") lmSendConfig("visibility",(string)GHOST_VISIBILITY);
            else if (settingName == "auto tp") lmSendConfig("canRejectTP",(string)FALSE);
            else if (settingName == "pose silence") lmSendConfig("canTalkInPose",(string)FALSE);
            else lmSendConfig(settingName, "1");
            break;

        }

        case "no":
        case "off":
        case "n":
        case "f":
        case "false":
        case "0": {

            if (settingName == "auto tp") lmSendConfig("canRejectTP",(string)TRUE);
            else if (settingName == "pose silence") lmSendConfig("canTalkInPose",(string)TRUE);
            else lmSendConfig(settingName, "0");
            break;

        }

        default: {
            llSay(DEBUG_CHANNEL,"Invalid preferences setting! (" + settingName + " = " + settingValue + ")");
            break;
        }
    }
}

processConfiguration(string configSettingName, string configSettingValue) {

    //----------------------------------------
    // Assign values to program variables

    integer i;

    //----------------------------------------
    // Configs has all entries that are not boolean, and require
    // special handling.
    //
    list configs = [
                     "debug level",
#ifdef USER_RLV
                     "collapse rlv",
                     "pose rlv",
#endif
                     "outfits path",
                     "doll type",
                     "max time",
                     "chat channel",
                     "dolly name",
                     "wind time",
                     "doll gender",
                     "helpless dolly",
                     "controller",
                     "blacklist"
                   ];

    //----------------------------------------
    // Every entry in settings must match up with a corresponding
    // entry in settingName. The first are the words used to set the config
    // value in preferences; the latter are the names of the actual
    // variable that relates to that setting.
    //
    // These are all boolean settings.
    //
    list settings = [
#ifdef ADULT_MODE
                      "strippable",
                      "hardcore",
#endif
                      "auto tp",
                      "can reject tp",
                      "pose silence",
                      "can talk in pose",
                      "busy is away",
                      "can fly",
                      "poseable",
                      "can dress self",
                      "dressable",
                      "outfitable",
                      "can dress",
                      "show phrases",
                      "carryable",
                      "repeatable wind",
                      "transforming doll",
                      "types",
                      "ghost"
                    ];

    list settingName = [
#ifdef ADULT_MODE
                         "allowStrip",
                         "hardcore",
#endif
                         "canRejectTP",
                         "canRejectTP",
                         "canTalkInPose",
                         "canTalkInPose",
                         "busyIsAway",
                         "canFly",
                         "allowPose",
                         "canDressSelf",
                         "allowDress",
                         "allowDress",
                         "canDressSelf",
                         "showPhrases",
                         "allowCarry",
                         "allowRepeatWind",
                         "allowTypes",
                         "allowTypes",
                         "ghost"
                       ];

    // This processes a single line from the preferences notecard...
    // processing done a single time during the read of the nc belong elsewhere

    // Check for settings - boolean true or false
    if (~(i = llListFindList(settings,(list)configSettingName))) {
        processBooleanSetting(configSettingName,configSettingValue);
    }

    // Check for non-boolean settings
    else if (~(i = llListFindList(configs,(list)configSettingName))) {
        if (configSettingName == "outfits path") {
            // Defer actual setting of outfitsFolder until later
            //
            //lmSetConfig("outfitFolder", configSettingValue);
            outfitFolderExpected = configSettingValue;
        }
        else if (configSettingName == "doll type") {
            // Defer actual setting of dollType until later
            //
            //lmSetConfig("dollType", configSettingValue);
            dollTypeExpected = configSettingValue;
        }
        else if (configSettingName == "chat channel") {
            // cant be 0 or MAXINT (DEBUG_CHANNEL)
            lmSetConfig("chatChannel", configSettingValue);
        }
        else if (configSettingName == "dolly name") {
            // should be printable
            lmSendConfig("dollDisplayName", (dollDisplayName = configSettingValue));
        }
        // This allows the debug level setting to be present, but ignored in non-developer keys...
        else if (configSettingName == "debug level") {
#ifdef DEVELOPER_MODE
            debugLevel = (integer)configSettingValue;

            lmSetConfig("debugLevel", (string)debugLevel);
#else
            ; // Nothing to do
#endif
        }
        else if (configSettingName == "collapse rlv") {
#ifdef USER_RLV
            // has to be valid rlv
            rlvDefaultCollapseCmd += "," + configSettingValue;
            lmSendConfig("rlvDefaultCollapseCmd", configSettingValue);
#else
            ; // Nothing to do
#endif
        }
        else if (configSettingName == "pose rlv") {
#ifdef USER_RLV
            // has to be valid rlv
            rlvDefaultPoseCmd += "," + configSettingValue;
            lmSendConfig("rlvDefaultPoseCmd", configSettingValue);
#else
            ; // Nothing to do
#endif
        }

        // Note that the entries "max time" and "wind time" are
        // somewhat unique in that they affect each other: so,
        // we don't use the one to validate the other until preferences
        // are completely read, nor do we set these values system-wide
        //
        // We might set the wind time to something invalid, UNTIL the
        // configured max time is read, for instance.
        //
        else if (configSettingName == "max time") {
            if ((integer)configSettingValue != 0) {
                keyLimit = (integer)configSettingValue * SECS_PER_MIN;
            }
        }
        else if (configSettingName == "wind time") {
            if ((integer)configSettingValue != 0) {
                windNormal = (integer)configSettingValue * SECS_PER_MIN;
            }
        }
        else if (configSettingName == "blacklist") {
            string blacklistUUID = (string)configSettingValue;
            lmInternalCommand("addBlacklist", blacklistUUID, NULL_KEY);
        }
        else if (configSettingName == "controller") {
            string controllerUUID = (string)configSettingValue;
            lmInternalCommand("addController", controllerUUID, NULL_KEY);
        }
        else if (configSettingName == "helpless dolly") {
            // Note inverted sense of this value: this is intentional
            if (configSettingValue == "1") lmSendConfig("canSelfTP", "0");
            else lmSendConfig("canSelfTP", "1");
        }
        else if (configSettingName == "doll gender") {
            // set gender of dolly

            switch(llToLower(configSettingValue)): {

                case "female":
                case "woman":
                case "girl": {

                    dollGender = "female";
                    break;
                }

                case "male":
                case "man":
                case "boy": {

                    dollGender = "male";
                    break;
                }

                case "agender": {

                    dollGender = "agender";
                    break;
                }

                default: {
                    llSay(DEBUG_CHANNEL, "Unknown value for dolly gender: " + dollGender + " - defaulting to female.");
                    dollGender = "female";
                    break;
                }
            }

            lmSetConfig("dollGender", dollGender);
        }
    }
    else if (~(i = llListFindList(keySpecificConfigs, (list)configSettingName))) {
        // Let the Key-Specific file validate the value
        lmSendConfig(configSettingName,configSettingValue);
    }
    else {
        llSay(DEBUG_CHANNEL,"Unknown configuration value in preferences: " + configSettingName + " on line " + (string)(ncLine + 1));
    }

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
        notecardQueryID = llGetNotecardLine(NOTECARD_PREFERENCES, ncLine);
    }
    else {
        llOwnerSay("No preferences file was found (\"" + NOTECARD_PREFERENCES + "\")");

        lmInitStage(INIT_STAGE3);
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
        dollName = dollyName();
        myName = llGetScriptName();
        keySpecificConfigs = [];

        //rlvWait = 1;
        cdInitializeSeq();
        //resetState = RESET_STARTUP;

#ifdef DEVELOPER_MODE
        // Set the debug level for all scripts early
        lmSendConfig("debugLevel",(string)debugLevel);
#endif

        // WHen this script (Start.lsl) resets... EVERYONE resets...
        doRestart();
        llSleep(0.5);

        makeWorkInNoScriptLand(dollID);

        // Start with key visible
        lmSendConfig("visibility",(string)1.0);
        lmSendConfig("isVisible",(string)TRUE);

        lmInitStage(INIT_STAGE1);
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        llResetTime();
        dollID = llGetOwner();
        dollName = dollyName();

        rlvPreviously = rlvOk;
        lmInternalCommand("startRlvCheck", "", keyID);

        // Reset visibility so we don't forget or get confused
        lmSendConfig("visibility",(string)1.0);
        lmSendConfig("isVisible",(string)TRUE);

        // Clear the low script mode and start from beginning
        lmSendConfig("lowScriptExpire",(string)0);

        // This is probably overkill - but pass these on to everybody
        lmSendConfig("typeLockExpire",(string)typeLockExpire);
        lmSendConfig("poseLockExpire",(string)poseLockExpire);
        lmSendConfig("carryExpire",(string)carryExpire);

        llOwnerSay("The Key is now fully ready; you hear the gears whir and spin up.");
    }

    //----------------------------------------
    // ATTACH
    //----------------------------------------
    // During attach we do the following:
    //
    //     * set winding rate
    //     * take controls so we work in no-script land
    //     * set AFK mode to false
    //     * restore collapse mode
    //
    // During DETACH we give the dolly an RP message.
    //
    attach(key id) {

        if (keyDetached(id)) {

            llOwnerSay("The key is wrenched from your back, and you double over at the unexpected pain as the tendrils are ripped out. You feel an emptiness, as if some beautiful presence has been removed.");

        }
        else {

            makeWorkInNoScriptLand(dollID);

            // when attaching key, user is NOT AFK...
            lmSetConfig("isAFK", (string)FALSE);

            // restore collapse environment
            lmInternalCommand("collapse", (string)collapsed, keyID);

            // doSpin sets the key to spinning - or should
            lmInternalCommand("doSpin","",NULL_KEY);
        }
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer lmSource, integer lmInteger, string lmData, key lmID) {

        parseLinkHeader(lmData,lmInteger);

        if (code == SEND_CONFIG) {
            string name = (string)split[0];
            string value = (string)split[1];
            split = llDeleteSubList(split,0,0);

                 if (name == "keyLimit")                       keyLimit = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                   debugLevel = (integer)value;
#endif
            else if (name == "collapsed")                     collapsed = (integer)value;
            else if (name == "typeLockExpire")           typeLockExpire = (integer)value;
            else if (name == "poseLockExpire")           poseLockExpire = (integer)value;
            else if (name == "carryExpire")                 carryExpire = (integer)value;
            else if (name == "dollType")                       dollType = value;
            else if (name == "keySpecificConfigs")  keySpecificConfigs += [ value ];
            else if (name == "blacklist") {
                if (split == [""]) blacklistList = [];
                else blacklistList = split;
            }

            else if (name == "poseAnimation") {
                poseAnimation = value;

                //lmSendConfig("poseAnimation", value);

                if ((!collapsed) && (rlvOk == TRUE)) {

                    // Dolly is operating normally (not collapsed)
                    // and this is a pose, not a collapse

                    if (poseAnimation == "" && !collapsed) {
                        // Not collapsed or posed - so clear to base RLV
                        lmRlvInternalCmd("rlvClearCmd",rlvDefaultBaseCmd); // received a null poseAnimation, and not collapsed: reset
                    }
                    else {
                        // Posed: activate RLV restrictions
                        lmRunRlv(rlvDefaultPoseCmd);
                    }
                }
            }
            else if (name == "rlvDefaultBaseCmd")    rlvDefaultBaseCmd = value;
        }

#ifdef DEVELOPER_MODE
        else if (code == SET_CONFIG) {
            string configName = (string)split[0];
            string configValue = (string)split[1];

            split = llDeleteSubList(split, 0, 0);

            if (configName == "debugLevel") {
                debugLevel = (integer)configValue;

                if (debugLevel > 9) {
                    debugLevel = 9;
                    llSay(DEBUG_CHANNEL,"Clipped debug level to 9.");
                }
                else if (debugLevel < 0) {
                    debugLevel = 0;
                    llSay(DEBUG_CHANNEL,"Clipped debug level to 0.");
                }

                lmSendConfig("debugLevel", (string)debugLevel);
            }
        }
#endif
        else if (code == INTERNAL_CMD) {
            string cmd = (string)split[0];

            // Commands:
            //   * addController
            //   * addBlacklist
            //   * remController
            //   * remBlacklist
            //
            switch (cmd): {

                case "addController":
                case "addBlacklist": {

                    string uuid = (string)split[1];
                    string name = (string)split[2];
                    string nameURI = "secondlife:///app/agent/" + uuid + "/profile";

                    //----------------------------------------
                    // VALIDATION
                    //
                    // Can't add if trying to add Dolly
                    //
                    if (cdIsDoll((key)uuid)) {

                        // Dolly can NOT be added to either list
                        cdSayTo("You can't select Dolly for this list.",(key)uuid);
                        return;
                    }

                    // Can't add carrier
                    //
                    if (carrierID == uuid) {

                        // We potentially could select a carrier for the controller list;
                        // however, how much complexity would that introduce?
                        cdSayTo("You can't select your carrier for this list.",(key)dollID);
                        return;
                    }

                    debugSay(5,"DEBUG-ADDMISTRESS","Blacklist = " + cdList2String(blacklistList) + " (" + (string)llGetListLength(blacklistList) + ")");

                    string typeString; // used to construct messages
                    list tmpList; // used as working area for whatever list

#define inRejectList(a) (~llListFindList(rejectList, (list)a))
#define inWorkingList(a) (~llListFindList(tmpList, (list)a))
#define noUserName (name == "")
#define queryMarker "++"

                    // we don't want controllers to be added to the blacklist;
                    // likewise, we don't want to allow those on the blacklist to
                    // be controllers. barlist represents the "contra" list
                    // opposing the added-to list.
                    //
                    list rejectList;

                    // Initial settings
                    if (cmd != "addBlacklist") {
                        typeString = "controller";
                        tmpList = controllerList;
                        rejectList = blacklistList;
                    }
                    else {
                        typeString = "blacklisted";
                        tmpList = blacklistList;
                        rejectList = controllerList;
                    }

                    // #1a: Cannot add UUID as controller if found in blacklist
                    // #1b: Cannot blacklist UUID if found in controllers list
                    //
                    if (inRejectList(uuid)) {

                        if (cmd != "addBlacklist") msg = nameURI + " is blacklisted; you must first remove them from the blacklist before adding them as a controller.";
                        else msg = nameURI + " is one of your controllers; until they remove themselves from being your controller, you cannot add them to the blacklist.";

                        cdSayTo(msg, lmID);
                        return;
                    }

                    // #2: Check if UUID exists already in the list
                    //
                    if (inWorkingList(uuid)) {

                        // Report already found
                        cdSayTo(nameURI + " is already found listed as " + typeString, lmID);
                        return;
                    }

                    //----------------------------------------
                    // ADD
                    //
                    // Actual add
                    //
                    cdSayToAgentPlusDoll("Adding " + nameURI + " as " + typeString, lmID);

                    if (cmd == "addBlacklist") {
                        blacklistList = tmpList + [ uuid ];
                    }
                    else {
                        controllerList = tmpList + [ uuid ];

                        if (rlvOk) {
                            // Controllers get added to the exceptions
                            llOwnerSay("@tplure:"    + uuid + "=add," +
                                        "accepttp:"  + uuid + "=add," +
                                        "sendim:"    + uuid + "=add," +
                                        "recvim:"    + uuid + "=add," +
                                        "recvchat:"  + uuid + "=add," +
                                        "recvemote:" + uuid + "=add");
                        }
                    }

                    // Add user name - find it if need be
                    //
                    if (noUserName) {
                        debugSay(5,"DEBUG-ADD","No name found for user; making query: " + nameURI);

                        if (queryUUID != "") {
                            llSay(DEBUG_CHANNEL,"Query conflict detected!");
                            return;
                        }

                        queryUUID = uuid;

                        // This is a hack: it lets us match the UUID with the
                        // name we get back
                        //
                        if (cmd == "addBlacklist") {

                            blacklistList += queryMarker + queryUUID;
                            blacklistQueryID = llRequestDisplayName((key)uuid);
                        }
                        else {
                            controllerList += queryMarker + queryUUID;
                            controllerQueryID = llRequestDisplayName((key)uuid);
                        }

                        llSetTimerEvent(USER_NAME_QUERY_TIMEOUT);
                        return;
                    }
                    else {
                        // This is normal add of selected name
                        if (cmd == "addBlacklist") blacklistList += name;
                        else controllerList += name;
                    }

                    // we may or may not have changed either of these - but this code
                    // forces a refresh in any case
                    lmSetConfig("blacklist",   cdList2String(blacklistList)  );
                    lmSetConfig("controllers", cdList2String(controllerList));

                    debugSay(5,"DEBUG-ADDMISTRESS",   "blacklist >> " + llDumpList2String(blacklistList,   ",") + " (" + (string)llGetListLength(blacklistList  ) + ")");
                    debugSay(5,"DEBUG-ADDMISTRESS", "controllers >> " + llDumpList2String(controllerList, ",") + " (" + (string)llGetListLength(controllerList) + ")");

                    break;
                }

                case "remController":
                case "remBlacklist": {

                    string uuid = (string)split[1];

                    if (cmd == "remBlacklistList")
                        blacklistList = remList(blacklistList,uuid,lmID);
                    else {
                        controllerList = remList(controllerList,uuid,lmID);

                        // because we cant remove by UUID, a complete redo of
                        // exceptions is necessary
                        lmInternalCommand("reloadExceptions",script,NULL_KEY);
                    }

                    // we may or may not have changed either of these - but this code
                    // forces a refresh in any case
                    lmSetConfig("blacklist",   cdList2String(blacklistList)  );
                    lmSetConfig("controllers", cdList2String(controllerList));

                    break;
                }
            }
        }
        else if (code == RLV_RESET) {
            rlvOk = (integer)split[0];

            if (rlvOk == FALSE) {
                if (rlvPreviously == TRUE) {
                    lmSendToController(dollName + " has logged in without RLV at " + wwGetSLUrl());
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

                lmInternalCommand("collapse", (string)FALSE, keyID);
            }
            else if (code == INIT_STAGE2) {
                debugSay(3,"DEBUG-START","Stage 2 begun.");

                readPreferences();

                // Send out defaults
                lmSendConfig("rlvDefaultCollapseCmd", rlvDefaultCollapseCmd);
                lmSendConfig("rlvDefaultPoseCmd", rlvDefaultPoseCmd);
                lmSendConfig("rlvDefaultBaseCmd", rlvDefaultBaseCmd);

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

                lmInitStage(INIT_STAGE5);
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
                llSay(PUBLIC_CHANNEL, llGetDisplayName(llGetOwner()) + " is now a dolly - anyone may play with their Key.");
            }
#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                if (script == myName) return;

                float delay = (float)split[0];
                memReport(myName,delay);
            }
#endif
            else if (code == CONFIG_REPORT) {
                cdConfigureReport();
            }
        }
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key queryID, string queryData) {
        integer index;

        // FIXME: Using a switch may be overkill - but we could add more selections later
        switch (queryID): {

            case notecardQueryID: {

                // Read notecard: Preferences

                if (queryData == EOF) {

                    // Make sure the wind is a reasonable value.
                    //
                    // This happens after the prefs file is read because we don't
                    // know whether the normal wind will be set first or the maximum
                    // wind time of the key. This makes sure that the normal wind has
                    // a reasonable value given the current wind max.
                    //
                    lmSetConfig("keyLimit",(string)keyLimit);
                    lmSetConfig("windNormal",(string)windNormal);

                    lmInitStage(INIT_STAGE3);
                }
                else {

                    // copy data so we can use it, and properly named
                    string notecardLine = queryData;

                    // Strip comments (prefs)
                    index = llSubStringIndex(notecardLine, "#");

                    if (index != NOT_FOUND) notecardLine = llDeleteSubString(notecardLine, index, -1);

#define isNotBlank(a) ((a) != "")

                    if (isNotBlank(notecardLine)) {
                        index = llSubStringIndex(notecardLine, "=");

                        // name is "lval" and value is "rval" split by equals
                        string configName  = llToLower(llStringTrim(llGetSubString(notecardLine,  0, index - 1),STRING_TRIM));
                        string configValue =           llStringTrim(llGetSubString(notecardLine, index + 1, -1),STRING_TRIM) ;

                        // this is the heart of preferences processing
                        debugSay(6, "DEBUG-START", "Processing configuration: configName = " + configName + "; configValue = " + configValue);
                        processConfiguration(configName, configValue);
                    }

                    // get next Notecard Line
                    //llSleep(0.1);
                    notecardQueryID = llGetNotecardLine(NOTECARD_PREFERENCES, ++ncLine);
                }
                break;
            }

#define userName queryData
#define isUserUUIDInList(a) llListFindList(a, (list)(queryMarker + (string)queryUUID))

            case blacklistQueryID: {

                if ((index = isUserUUIDInList(blacklistList)) != NOT_FOUND) {
                    queryUUID = "";
                    blacklistList[ index ] = userName;
                    blacklistQueryID = NULL_KEY;
                    debugSay(5,"DEBUG-ADDMISTRESS",   "blacklist >> " + llDumpList2String(blacklistList,   ",") + " (" + (string)llGetListLength(blacklistList  ) + ")");
                    lmSetConfig("blacklist", cdList2String(blacklistList));
                }
#ifdef DEVELOPER_MODE
                else llSay(DEBUG_CHANNEL,"Couldnt find blacklist UUID:" + queryUUID);
#endif
                break;
            }

            case controllerQueryID: {

                if ((index = isUserUUIDInList(controllerList)) != NOT_FOUND) {
                    queryUUID = "";
                    controllerList[ index ] = userName;
                    controllerQueryID = NULL_KEY;
                    debugSay(5,"DEBUG-ADDMISTRESS", "controllers >> " + llDumpList2String(controllerList, ",") + " (" + (string)llGetListLength(controllerList) + ")");
                    lmSetConfig("controllers", cdList2String(controllerList));
                }
#ifdef DEVELOPER_MODE
                else llSay(DEBUG_CHANNEL,"Couldnt find controller UUID: " + queryUUID);
#endif
                break;
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

        //----------------------------------------
        // PERMISSION_TAKE_CONTROLS

        // This is pro-forma: permission is autogranted to attached avatars
        if (perm & PERMISSION_TAKE_CONTROLS) {

            // By doing this, we permit the Key to work in no-script land
            llTakeControls(CONTROL_MOVE, TRUE, TRUE);
        }
    }
}

//========== START ==========
