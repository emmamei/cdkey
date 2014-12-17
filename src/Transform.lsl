//========================================
// Transform.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

// 29 March: Formatting and general cleanup
// Aug 14, totally changing
// Nov. 12, adding compatibility with hypnosisHUD

#include "include/GlobalDefines.lsl"

#define TYPE_FLAG "*"
#define NO_FILTER ""

#define cdProfileURL(i) "secondlife:///app/agent/"+(string)(i)+"/about"
#define cdStringEndMatch(a,b) llGetSubString(a,-llStringLength(b),STRING_END)==b
#define cdListenMine(a)   llListen(a, NO_FILTER, dollID, NO_FILTER)

// Channel to use to discard dialog output
#define DISCARD_CHANNEL 9999

// Transformation (locked) time in seconds
#define TRANSFORM_LOCK_TIME 300

// Script Control
#define RUNNING 1
#define NOT_RUNNING 0
#define cdRunScript(a) llSetScriptState(a, RUNNING);
#define cdStopScript(a) llSetScriptState(a, NOT_RUNNING);

#define isFound(a) (a!="")
#define isNotFound(a) (a=="")
#define MAX_SEARCH_RETRIES 2
#define RLV_TIMEOUT 15.0

//========================================
// VARIABLES
//========================================
vector gemColour;
string nudeFolder;
string normalselfFolder;
integer phraseCount;
string msg;
integer i;
//string stateName;
list types;
float menuTime;
key transformerId;
integer readLine;
integer readingNC;
string typeNotecard;

integer outfitSearchTries;
integer typeSearchTries;
float outfitsSearchTimer;
string outfitsFolder;
integer outfitSearching;

integer findTypeFolder;

//integer rlvHandle;
integer typeSearchHandle;
integer outfitSearchHandle;
integer useTypeFolder;
integer transformedViaMenu;
string transform;
string typeFolder;

integer rlvChannel;
integer typeSearchChannel;
integer outfitSearchChannel;

integer transformLockExpire;

//integer startup = 1;

//integer menulimit = 9;     // 1.5 minute

integer dbConfig;
integer mustAgreeToType;
#ifdef WEAR_AT_LOGIN
integer wearAtLogin;
#endif
//integer isTransformingKey;
string typeFolderExpected;

key kQuery;

list currentPhrases;

//========================================
// FUNCTIONS
//========================================

#define AUTOMATED 1
#define NOT_AUTOMATED 0

setDollType(string stateName, integer automated) {
    // This is BAD: it shows a knowledge of how we
    // were called outside of the function - and ties
    // the function to data outside the function without any
    // gatekeeper or documentation
    //if (choice == "Transform") stateName = transform;
    //else stateName = choice;

    //debugSay(2,"DEBUG-DOLLTYPE","Transforming to " + stateName);
    //llOwnerSay("Transforming into a " + stateName + " dolly");

    // Convert state name to Title case
    stateName = cdGetFirstChar(llToUpper(stateName)) + cdButFirstChar(llToLower(stateName));

    // If no change, abort
    if (stateName == dollType) return;

    // By not aborting, selecting the same state can cause a "refresh" ...
    // though our menus do not currently allow this
    currentPhrases = [];
    readLine = 0;
    typeNotecard = TYPE_FLAG + stateName;
    typeFolderExpected = TYPE_FLAG + stateName;

    // Look for Notecard for the Doll Type and start reading it if showPhrases is enabled
    //
    // Builder and Key types don't allow for Notecard Hypno - this is also left in even
    // if Key type is unused, as it disallows the Key Type altogether
    if (showPhrases) {
        if (stateName != "Builder" && stateName != "Key") {
            if (llGetInventoryType(typeNotecard) == INVENTORY_NOTECARD) {

                kQuery = llGetNotecardLine(typeNotecard,readLine++);

                debugSay(2,"DEBUG-DOLLTYPE","Found notecard: " + typeNotecard);
            }
#ifdef DEVELOPER_MODE
            else {
                debugSay(2,"DEBUG-DOLLTYPE","Found no notecard titled " + typeNotecard);
            }
#endif
        }
    }

    // Dont lock if transformation is automated (or is a Builder or Key type)
    if (!automated
         && stateName != "Builder"
#ifdef KEY_TYPE
         && stateName != "Key"
#endif
    ) {
        transformLockExpire = llGetUnixTime() + TRANSFORM_LOCK_TIME;
        lmSendConfig("transformLockExpire",(string)TRANSFORM_LOCK_TIME);
    }
    else {
        lmSendConfig("transformLockExpire",(string)(transformLockExpire = 0));
    }

    // We dont respond to this: we don't have to
    lmSendConfig("dollType", (dollType = stateName));

    cdPause();

    if (!quiet) cdChat(dollName + " has become a " + dollType + " Doll.");
    else llOwnerSay("You have become a " + dollType + " Doll.");

    // This is being done too early...
    //if (!RLVok) { lmSendToAgentPlusDoll("Because RLV is disabled, Dolly does not have the capability to change outfit.",transformerId); };

    // The Key Dolly is not allowed to have outfits so
    // no search for Type is warranted; note that
    // the Builder can have outfits if they like.
    typeFolder = "";

#ifdef KEY_TYPE
    if (dollType != "Key") {
#endif
        outfitSearchTries = 0;
        typeSearchTries = 0;

        // if RLV is non-functional, dont search for a Type Folder
        if (RLVok) {
            debugSay(2,"DEBUG-DOLLTYPE","Searching for " + typeFolderExpected);
            //outfitsSearchTimer = llGetTime();
            typeSearchHandle = cdListenMine(typeSearchChannel);
            folderSearch(outfitsFolder,typeSearchChannel);
        }
    // if NOT RLVok then we have a DollType with no associated typeFolder...
#ifdef KEY_TYPE
    }
#endif
}

reloadTypeNames() {
    string typeName;

    integer n = llGetInventoryNumber(INVENTORY_NOTECARD);
    types = [];

    while(n) {
        typeName = llGetInventoryName(INVENTORY_NOTECARD, --n);

        if (cdGetFirstChar(typeName) == TYPE_FLAG) {
            typeName = cdButFirstChar(typeName);

            // Disallow several types of Keys: if we allowed
            // these, then creating a notecard would enable
            // the type without any access controls
            //
            // The Slut model is allowed (in a normal fashion)
            // if this is an ADULT key
            //
            if (   (typeName != "Builder")
                && (typeName != "Key")
#ifndef ADULT_MODE
                && (typeName != "Slut")
#endif
                ) {

                types += typeName;
            }
        }
    }

    //We don't need a Notecard to be present for these to be active
    //
    // Note the following rules of the built-in types:
    //   - Display: Notecard is ok but not needed
    //   - Slut: rejects type even if Notecard is present if not ADULT, else Notecard ok but not needed
    //   - Builder: rejects Notecards entirely
    //   - Key: rejects Notecards entirely
    //
    if (llListFindList(types, (list)"Display") == NOT_FOUND) types += [ "Display" ];
#ifdef ADULT_MODE
    if (simRating == "MATURE" || simRating == "ADULT")
        if (llListFindList(types, (list)"Slut") == NOT_FOUND) types += [ "Slut" ];
#endif
    if (cdDollyIsBuiltinController(transformerId)) { types += [ "Builder" ]; showPhrases = 0; }
#ifdef KEY_TYPE
    if (cdIsBuiltinController(transformerId))      { types += [ "Key" ];     showPhrases = 0; }
#endif
}

// Folders need to be searched for: the outfits folder, and the
// type folder also - plus the ~nude and ~normal folders on top
// of that.
//
// First, search for outfits folder. Not finding this should be
// an error.
//
// Once found, find a type folder within the outfits folder.
// This type folder search may be repeated, and not finding one
// is not an error.
//
// The ~nude and ~normal folders should be within the outfits folder,
// but could be at the same level too.
//
// Both major searches (outfits and type) are combined with a timeout
// and multiple retry.

folderSearch(string folder, integer channel) {
    integer handle;

    debugSay(2,"DEBUG-FOLDERSEARCH","folderSearch: Searching within \"" + folder + "\"");

    // The folder search starts as a RLV @getinv call...
    //
    //handle = cdListenMine(channel);
    if (folder == "")
        lmRunRLV("getinv=" + (string)channel);
    else
        lmRunRLV("getinv:" + folder + "=" + (string)channel);

    // The next stage is the listener, while we create a time
    // out to timeout the RLV call...
    //
    llSetTimerEvent(RLV_TIMEOUT);
}

//========================================
// STATES
//========================================
default {
    state_entry() {
        dollID =   llGetOwner();
        dollName = llGetDisplayName(dollID);

        cdInitializeSeq();
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & CHANGED_ALLOWED_DROP)
            reloadTypeNames();
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {

        // No searching happens unless RLV is ok...
        //
        // Checks happen when:
        //
        //    1. rlvChannel is good and RLV is ok...
        //    2. Doll Type changes
        //    3. Link message 350: RLVok and/or Reset
        //
        // Everything related to Outfits Changes happens here (and in the listener)
        // What made the former code complicated is that there are several processes
        // intermingled together:
        //
        //    1. Searching for a particular default Outfits folder
        //    2. Multiple retries for each search
        //    3. Searching for a Types folder
        //
        // outfitsFolder = Top Level folder that contains all outfits (e.g., "> Outfits")
        // typeFolder = Folder related to current Doll Type (e.g., "*Japanese")
        // typeFolderExpected = Computed but untested typeFolder

#ifdef DEVELOPER_MODE
        string s;
        //if (timeReporting) llOwnerSay("Transform Timer fired, interval " + formatFloat(llGetTime() - lastTimerEvent,3) + "s. (lowScriptMode ");

        s = "Transform Timer fired, interval " + formatFloat(llGetTime() - lastTimerEvent,3) + "s. (lowScriptMode ";

        lastTimerEvent = llGetTime();

        if (lowScriptMode) s += "is active).";
        else s += "is not active).";

        if (timeReporting) llOwnerSay(s);
#endif
        // transform lock: check time
        if (transformLockExpire) {
            if (transformLockExpire  <= llGetUnixTime()) {
                lmSendConfig("transformLockExpire",(string)(transformLockExpire = 0));
            }
            else lmSendConfig("transformLockExpire",(string)(transformLockExpire - llGetUnixTime()));
        }

        if (RLVok) {
            if (outfitsSearchTimer) {
                debugSay(2,"DEBUG-SEARCHING","Search aborted after " + formatFloat(llGetTime() - outfitsSearchTimer,1) + "s");
                outfitsSearchTimer = 0.0; // reset

            }

            if (outfitSearching) {
                // Note carefully - if the search tries is maxed,
                // that means that the attempted RLV call failed
                // and the listener got nothing - NOT that the
                // search failed... search failures ("failure to find")
                // are marked by the listener code.

                if (outfitsFolder == "") {
                    if (outfitSearchTries++ < MAX_SEARCH_RETRIES)
                        folderSearch("",outfitSearchChannel);
                    else llListenRemove(outfitSearchHandle);
                } else {
                    if (typeFolder == "" && typeFolderExpected != "") {
                        if (typeSearchTries++ < MAX_SEARCH_RETRIES)
                            folderSearch(outfitsFolder,typeSearchChannel);
                        else llListenRemove(typeSearchHandle);
                    }
                }
            }
            else {
                if (typeSearchHandle) {
                    llListenRemove(typeSearchHandle);
                    typeSearchHandle = 0;
                }

                if (outfitSearchHandle) {
                    llListenRemove(outfitSearchHandle);
                    outfitSearchHandle = 0;
                }
            }
        }

        if (showPhrases) {
            if (phraseCount) {

                // select a phrase from the notecard at random
                string phrase  = llList2String(currentPhrases, llFloor(llFrand(phraseCount)));

                // Starting with a '*' marks a fragment; with none,
                // the phrase is used as is

                if (cdGetFirstChar(phrase) == "*") {

                    phrase = cdButFirstChar(phrase);
                    float r = llFrand(5);

                         if (r < 1.0) msg = "*** feel your need to ";
                    else if (r < 2.0) msg = "*** feel your desire to ";
                    else if (r < 3.0) msg = "*** it pleases you to ";
                    else if (r < 4.0) msg = "*** you want to ";
                    else {
                        if (dollType  == "Domme") msg = "*** You like to ";
                        else msg = "*** feel how people like you to ";
                    }
                } else msg = "*** ";

                msg += phrase;

                // Phrase has been chosen and put together; now say it
                llOwnerSay(msg);
            }
        }

        if (lowScriptMode) llSetTimerEvent(LOW_RATE);
        else llSetTimerEvent(STD_RATE);

        //----------------------------------------
        // UPDATE HOVERTEXT

        // Update sign if appropriate
        string primText = llList2String(llGetPrimitiveParams([ PRIM_TEXT ]), 0);

//#define cdSetHovertext(x,c) if(primText!=x)llSetText(x,c,1.0)

//#define RED    <1.0,0.0,0.0>
//#define YELLOW <1.0,1.0,0.0>
//#define WHITE  <1.0,1.0,1.0>

             if (collapsed)   { cdSetHovertext("Disabled Dolly!",        ( RED    )); }
        else if (afk)         { cdSetHovertext(dollType + " Doll (AFK)", ( YELLOW )); }
        else if (hoverTextOn) { cdSetHovertext(dollType + " Doll",       ( WHITE  )); }
        else                  { cdSetHovertext("",                       ( WHITE  )); }

        //----------------------------------------
        // AUTO AFK TRIGGERS

        // if we can AFK, check for auto AFK triggers
        if (canAFK) {
            integer dollAway = ((llGetAgentInfo(dollID) & (AGENT_AWAY | (AGENT_BUSY * busyIsAway))) != 0);

            // When Dolly is "away" - enter AFK
            // Also set away when busy

            if (autoAFK && (afk != dollAway)) {

                if (dollAway) {
                    lmSetConfig("afk", "2");
                    llOwnerSay("Automatically entering AFK mode; Key subsystems slowing...");
                }
                else {
                    lmSetConfig("afk", "0");
                    llOwnerSay("Entering AFK mode; Key subsystems slowing...");
                }

                //displayWindRate = setWindRate();
                //lmInternalCommand("setAFK", (string)afk + "|1|" + formatFloat(windRate, 1) + "|" + (string)llRound(timeLeftOnKey / (SEC_TO_MIN * displayWindRate)), NULL_KEY);
            }
        }
    }

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

        string choice = cdListElement(split, 0);
        string name = cdListElement(split, 1);
        transformerId = id;

#ifdef DEVELOPER_MODE
        // This is a way to watch the messages coming over the wire...
        // no need for a separate script to do it
        if ((debugLevel > 4 && code != 11 && code != 12 && code != 15) || debugLevel > 5) {
            string s = "Transform Link Msg:" + script + ":" + (string)code + ":choice/name";
            string t = choice + "/" + name;

            if (id != NULL_KEY || debugLevel > 6) debugSay(5,"DEBUG-LINK",s + "/id = " + t + "/" + (string)id);
            else debugSay(5,"DEBUG-LINK",s + " = " + t);
        }
#endif
        scaleMem();

        if (script == "Transform") return;

        if (code == CONFIG) {

            string value = name;
            string name = choice;

                 if (name == "timeLeftOnKey")                          timeLeftOnKey = (float)value;
            else if (name == "afk")                                              afk = (integer)value;
            else if (name == "autoAFK")                                      autoAFK = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "timeReporting")                          timeReporting = (integer)value;
#endif
            else if (name == "lowScriptMode") {
                if (lowScriptMode = (integer)value) llSetTimerEvent(LOW_RATE);
                else llSetTimerEvent(STD_RATE);
            }
            else if (name == "collapsed")                                  collapsed = (integer)value;
            else if (name == "simRating")                                  simRating = value;
            else if (name == "quiet")                                          quiet = (integer)value;
            else if (name == "hoverTextOn")                              hoverTextOn = (integer)value;
            else if (name == "busyIsAway")                                busyIsAway = (integer)value;
            else if (name == "canAFK")                                        canAFK = (integer)value;
            else if (name == "mustAgreeToType")                      mustAgreeToType = (integer)value;
            else if (name == "winderRechargeTime")                winderRechargeTime = (integer)value;
            else if (name == "collapseTime")                            collapseTime = (integer)value;
            else if (name == "showPhrases") {
                showPhrases = (integer)value;
                currentPhrases = [];

                // if showPhrases is turned on, read hypno phrases from notecard
                if (showPhrases) {
                    if (llGetInventoryType(typeNotecard) == INVENTORY_NOTECARD) {
                        kQuery = llGetNotecardLine(typeNotecard,readLine);
                    }
                }
            }
#ifdef WEAR_AT_LOGIN
            else if (name == "wearAtLogin")                              wearAtLogin = (integer)value;
#endif
            else if (name == "stateName") {
                dollType = value;
            }
            else if ((name == "RLVok") || (name == "dialogChannel")) {
                integer oldRLVok = RLVok;

                if (name == "RLVok") RLVok = (integer)value;
                else if (name == "dialogChannel") {
                    dialogChannel = (integer)value;
                    rlvChannel = ~dialogChannel + 1;
                    typeSearchChannel = rlvChannel + 1;
                    outfitSearchChannel = rlvChannel + 2;
                }

                // This makes the RLV activation only happen during
                // an RLV Off to On transition... and speeds things up too
                if (!oldRLVok) {
                    if (RLVok && rlvChannel)
                        lmRLVreport();
                }
            }
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel") {
                                                                          debugLevel = (integer)value;
            }
#endif
        }

        else if (code == SET_CONFIG) {

            string value = name;
            string name = choice;

            if (name == "dollType") {
                setDollType(value, AUTOMATED);
                //lmSendConfig("dollType",dollType);
            }
            else if (name == "transformLockExpire") {
                lmSendConfig("transformLockExpire",(string)(transformLockExpire = (integer)value));
            }
        }
        else if (code == INTERNAL_CMD) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "setGemColour") {
                vector newColour = (vector)llList2String(split, 0);
                integer j; integer s; list params; list colourParams;
                integer n; integer m;

                n = llGetNumberOfPrims();
                for (i = 1; i < n; i++) {
                    params += [ PRIM_LINK_TARGET, i ];
                    if (llGetSubString(llGetLinkName(i), 0, 4) == "Heart") {
                        if (gemColour != newColour) {
                            if (!s) {
                                m = llGetLinkNumberOfSides(i);
                                for (j = 0; j < m; j++) {
                                    vector shade = <llFrand(0.2) - 0.1 + newColour.x,
                                                    llFrand(0.2) - 0.1 + newColour.y,
                                                    llFrand(0.2) - 0.1 + newColour.z>  * (1.0 + (llFrand(0.2) - 0.1));

                                    if (shade.x < 0.0) shade.x = 0.0;
                                    if (shade.y < 0.0) shade.y = 0.0;
                                    if (shade.z < 0.0) shade.z = 0.0;

                                    if (shade.x > 1.0) shade.x = 1.0;
                                    if (shade.y > 1.0) shade.y = 1.0;
                                    if (shade.z > 1.0) shade.z = 1.0;

                                    colourParams += [ PRIM_COLOR, j, shade, 1.0 ];
                                }
                                params += colourParams;
                                s = 1;
                            }
                            else params += colourParams;
                        }
                    }
                }
                llSetLinkPrimitiveParamsFast(0, params);
                if (gemColour != newColour) {
                    lmSendConfig("gemColour", (string)(gemColour = newColour));
                }
                params = [];
            }
            else if (cmd == "setHovertext") {
                string primText = llList2String(llGetPrimitiveParams([ PRIM_TEXT ]), 0);

                     if (collapsed)   { cdSetHovertext("Disabled Dolly!",        ( RED    )); }
                else if (afk)         { cdSetHovertext(dollType + " Doll (AFK)", ( YELLOW )); }
                else if (hoverTextOn) { cdSetHovertext(dollType + " Doll",       ( WHITE  )); }
                else                  { cdSetHovertext("",                       ( WHITE  )); }
            }
            else if (cmd == "carriedMenu") {
                string carrierName = llList2String(split, 0);

                if (cdIsDoll(id)) {
                    msg = "You are being carried by " + carrierName + ". ";
                    if (collapsed) msg += "You need winding, too. ";
                }
                else msg = dollName + " is currently being carried by " + carrierName + ". They have full control over this doll. ";

                cdDialogListen();
                llDialog(id, msg, [ "OK" ], dialogChannel);
            }
            else if (cmd == "collapsedMenu") {
                string timeleft = llList2String(split, 0);
                list menu;

                // is it possible to be collapsed but collapseTime be equal to 0.0?
                if (collapseTime != 0.0) {
                    float timeCollapsed = llGetUnixTime() - collapseTime;
                    msg = "You need winding. ";
                    msg += "You have been collapsed for " + (string)llFloor(timeCollapsed / SEC_TO_MIN) + " minutes. ";

                    // Only present the TP home option for the doll if they have been collapsed
                    // for at least 900 seconds (15 minutes) - Suggested by Christina

                    if (timeCollapsed > TIME_BEFORE_TP) {
                        if (llGetInventoryType(LANDMARK_HOME) == INVENTORY_LANDMARK)
                            menu = ["TP Home"];

                        // If the doll is still down after 1800 seconds (30 minutes) and their
                        // emergency winder is recharged; add a button for it

                        if (!hardcore) {
                            if (timeCollapsed > TIME_BEFORE_EMGWIND) {
                                if (winderRechargeTime <= llGetUnixTime())
                                    menu += ["Wind Emg"];
                            }
                        }
                    }

                    cdDialogListen();
                    llDialog(id, timeleft + msg, [ "OK" ], dialogChannel);
                }
            }
            else if (cmd == "optionsMenu") {
                list pluslist;

                if (cdIsDoll(id)) {
                    msg = "See " + WEB_DOMAIN + "keychoices.htm for explanation. ";
                    pluslist += [ "Features...", "Key..." ];

                    if (cdCarried() || cdControllerCount() > 0) {
                        pluslist += [ "Access..." ];
                    }
                    else {
                        pluslist += [ "Type...", "Access...", "Abilities..." ];
                    }
                }
                else if (cdIsCarrier(id)) {
                    pluslist += [ "Type...", "Abilities..." ];
                }
                else if (cdIsBuiltinController(id)) {
                    pluslist += [ "Type...", "Access...", "Abilities..." ];
                }
                else if (cdIsUserController(id)) {

                    msg = "See " + WEB_DOMAIN + "controller.htm. Choose what you want to happen.";
                    pluslist += [ "Type...", "Access...", "Abilities...", "Drop Control" ];

                }
                // This section should never be triggered: it means that
                // someone who shouldn't see the Options menu did.
                else return;

                cdDialogListen();
                llDialog(id, msg, dialogSort(pluslist + MAIN), dialogChannel);
            }
        }

        else if (code == RLV_RESET) {
            RLVok = ((integer)choice == 1);
            if (dollType == "") setDollType("Regular", AUTOMATED);

            outfitsFolder = "";
            typeFolder = "";
            outfitSearchTries = 0;
            typeSearchTries = 0;

            if (RLVok) {
                if (rlvChannel) {
                    typeSearchHandle = cdListenMine(typeSearchChannel);
                    outfitSearchHandle = cdListenMine(outfitSearchChannel);

                    if (outfitsFolder == "" && !outfitSearching) {
                        // No outfit folder: let's search.
                        outfitSearching++;
                        if (outfitSearching < 2) {

                            debugSay(2,"DEBUG-RLVOK","Searching for Outfits and Typefolders");
                            outfitsFolder = "";
                            typeFolder = "";
                            useTypeFolder = 0;
                            typeSearchTries = 0;
                            outfitSearchTries = 0;

                            outfitsSearchTimer = llGetTime();
                            // Start the search
                            folderSearch(outfitsFolder,outfitSearchChannel);
                        }
                    }
                }
            }
        }

        else if (code == MENU_SELECTION) {
            // string name = cdListElement(split, 2);
            string optName = llGetSubString(choice, 2, STRING_END);
            string curState = cdGetFirstChar(choice);

            // llOwnerSay("DEBUG:500: ** name = " + name); // DEBUG

            // for timing out the Menu
            menuTime = llGetTime();

            // Transforming options
            if ((choice == "Type...")        ||
                (optName == "Verify Type")   ||
                (optName == "Show Phrases")
#ifdef WEAR_AT_LOGIN
                || (optName == "Wear @ Login")
#endif
                ) {

                if (optName == "Verify Type") {
                    lmSendConfig("mustAgreeToType", (string)(mustAgreeToType = (curState == CROSS)));
                    if (mustAgreeToType) llOwnerSay("Changes in Doll Types will be verified with you first.");
                    else llOwnerSay("Changes in Doll Types will not be verified with you first.");
                }
                else if (optName == "Show Phrases") {
                    lmSendConfig("showPhrases", (string)(showPhrases = (curState == CROSS)));
                    if (showPhrases) llOwnerSay("Hypnotic phrases will be displayed.");
                    else llOwnerSay("No hypnotic phrases will be displayed.");
                }
#ifdef WEAR_AT_LOGIN
                else if (optName == "Wear @ Login") {
                    lmSendConfig("wearAtLogin", (string)(wearAtLogin = (curState == CROSS)));
                    if (wearAtLogin) llOwnerSay("If you are not a Regular Doll, a new outfit will be chosen each login.");
                    else llOwnerSay("A new outfit will not be worn at each login.");
                }
#endif
                list choices;

                choices += cdGetButton("Verify Type", id, mustAgreeToType, 0);
                choices += cdGetButton("Show Phrases", id, showPhrases, 0);
#ifdef WEAR_AT_LOGIN
                choices += cdGetButton("Wear @ Login", id, wearAtLogin, 0);
#endif

                cdDialogListen();
                llDialog(dollID, "Options", dialogSort(choices + MAIN), dialogChannel);
            }

            // Choose a Transformation
            else if (choice == "Types...") {
                debugSay(5,"DEBUG-TYPES","Types selected");
                // Doll must remain in a type for a period of time
                if (transformLockExpire) {
                    debugSay(5,"DEBUG-TYPES","Transform locked");
                    if (cdIsDoll(id)) {
                        llDialog(id,"You cannot be transformed right now, as you were recently transformed into a " + dollType + " doll. You can be transformed in " + (string)llFloor((transformLockExpire - llGetUnixTime()) / SEC_TO_MIN) + " minutes.",["OK"], DISCARD_CHANNEL);
                    } else {
                        llDialog(id,dollName + " cannot be transformed right now. The Doll was recently transformed into a " + dollType + " doll. Dolly can be transformed in " + (string)llFloor((transformLockExpire - llGetUnixTime()) / SEC_TO_MIN) + " minutes.",["OK"], DISCARD_CHANNEL);
                    }
                }
                else {
                    // Transformation lock time has expired: transformations (type changes) now allowed
                    reloadTypeNames();
                    debugSay(5,"DEBUG-TYPES","Type names reloaded");

                    msg = "These change the personality of " + dollName + "; Dolly is currently a " + dollType + " Doll. ";

                    // We need a new list var to be able to change the display, not the
                    // available types
                    list choices = types;

                    // Delete the current type: transforming to current type is redundant
                    if ((i = llListFindList(choices, (list)dollType)) != NOT_FOUND) {
                        choices = llDeleteSubList(choices, i, i);
                    }

                    if (cdIsDoll(id)) msg += "What type of doll do you want to be?";
                    else {
                        msg += "What type of doll do you want the Doll to be?";
                        llOwnerSay(cdProfileURL(id) + " is looking at your doll types.");
                    }

                    debugSay(5,"DEBUG-TYPES","Generating unlocked dialog");
                    cdDialogListen();
                    llDialog(id, msg, dialogSort(llListSort(choices, 1, 1) + MAIN), dialogChannel);
                }
                debugSay(5,"DEBUG-TYPES","Transform complete");
            }

            // Transform
            else if (choice == "Transform") {
                // We get here because dolly had to confirm the change
                // of type - and chose "Transform" from the menu
                //choice = transform; // Type name saved from Transform confirmation
                transformedViaMenu = YES;
                setDollType(transform, NOT_AUTOMATED);
            }
            else if (cdListElementP(types, choice) != NOT_FOUND) {
                // "choice" is a valid Type: change to it as appropriate
                transform = "";

                if (cdIsDoll(id) || cdIsController(id) || !mustAgreeToType) {
                    // Doll (or a Controller) chose a Type - or no confirmation needed: just do it
                    transformedViaMenu = YES;
                    setDollType(choice, NOT_AUTOMATED);
                }
                else {
                    // This section is executed when:
                    //
                    // 1. Accessor is NOT Dolly, AND
                    // 2. Accessor is NOT a Controller, AND
                    // 3. Dolly must agree to Type...

                    // A member of the public chose a Type and confirmation is required
                    lmSendToAgent("Getting confirmation from Doll...",id);

                    transform = choice; // save transformation Type
                    list choices = ["Transform", "Dont Transform", MAIN ];
                    string msg = "Do you wish to be transformed to a " + choice + " Doll?";

                    cdDialogListen();
                    llDialog(dollID, msg, choices, dialogChannel); // this starts a new choice on this channel
                }
            }
        }
        else if (code < 200) {
            if (code == 102) {
                // FIXME: Is this relevant?
                // Trigger Transforming Key setting
                // if (!isTransformingKey) lmSendConfig("isTransformingKey", (string)(isTransformingKey = 1));
                // lmSendConfig("isTransformingKey", (string)(isTransformingKey = 1));

                configured = 1;
                //if (stateName != dollType) setDollType(stateName, AUTOMATED);
            }

            else if (code == 104) {
                reloadTypeNames();
                llSetTimerEvent(30.0);

                // Might have been set in Prefs, so do this late
            }

            //else if (code == 105) {
            //    if (script != "Start") return;
            //}

            else if (code == 110) {
                //initState = 105;
                //
                // note that dollType is ALREADY SET....
                // this is bad form but allows us to defer the subroutine
                // until now in the startup process
                setDollType(dollType, AUTOMATED);
                //startup = 0;
                ;
            }

            else if (code == 135) {
                float delay = (float)choice;
                memReport(cdMyScriptName(),delay);
            }
            else if (code == 142) {
                cdConfigureReport();
            }
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {

        // if a @getinv call succeeds, then we are here - looking for the
        // folders we want...
        //
        if (channel == outfitSearchChannel) {
            llListenRemove(outfitSearchHandle);
            debugSay(2,"DEBUG-SEARCHING","Channel #1 received (outfitsFolder = \"" + outfitsFolder + "\"): " + choice);

            list folderList = llCSV2List(choice);
            nudeFolder = "";
            normalselfFolder = "";

            if (outfitsFolder == "") {
                // vague substring check done here for speed
                if (llSubStringIndex(choice,"Outfits") >= 0 ||
                    llSubStringIndex(choice,"Dressup") >= 0)   {

                    // exact match check
                         if (~llListFindList(folderList, (list)"> Outfits"))  outfitsFolder = "> Outfits";
                    else if (~llListFindList(folderList, (list)"Outfits"))    outfitsFolder = "Outfits";
                    else if (~llListFindList(folderList, (list)"> Dressup"))  outfitsFolder = "> Dressup";
                    else if (~llListFindList(folderList, (list)"Dressup"))    outfitsFolder = "Dressup";

                    if (outfitsFolder != "") {
                        // This brute force setting is fine: we are searching for the Outfits
                        // folder, and this is the initial setting
                        if (~llListFindList(folderList, (list)"~nude"))        lmSendConfig("nudeFolder",(nudeFolder = "~nude"));
                        if (~llListFindList(folderList, (list)"~normalself"))  lmSendConfig("normalselfFolder",(normalselfFolder = "~normalself"));
                    }

                    debugSay(2,"DEBUG-SEARCHING","outfitsFolder = " + outfitsFolder);

                    lmSendConfig("outfitsFolder", outfitsFolder);
                    //lmSendConfig("typeFolder", typeFolder);
                    //lmSendConfig("useTypeFolder", (string)useTypeFolder);

                    debugSay(2,"DEBUG-SEARCHING","typeFolder = \"" + typeFolder + "\" and typeFolderExpected = \"" + typeFolderExpected + "\"");
                    // Search for a typeFolder...
                    if (typeFolder == "" && typeFolderExpected != "") {
                        debugSay(2,"DEBUG-SEARCHING","Outfit folder found in " + formatFloat(llGetTime() - outfitsSearchTimer,1) + "s; searching for typeFolder");
                        // outfitsFolder search is done: search for typeFolder
                        folderSearch(outfitsFolder,typeSearchChannel);
                    }
                    //else lmInternalCommand("randomDress","",NULL_KEY);
                }
            }


        }
        else if (channel == typeSearchChannel) {

            // Note that we may have gotten here *without* having run through
            // the outfits search first - due to having done the outfits search
            // much earlier... However.... if we are here, then the outfits search
            // must have run before, but not necessarily immediately before...

            // Note that, unlike the dialog channel, the type search channel is removed and recreated... maybe it should not be
            llListenRemove(typeSearchHandle);
            if (lowScriptMode) llSetTimerEvent(LOW_RATE);
            else llSetTimerEvent(STD_RATE);

            // if there is no outfits folder we mark the type folder search
            // as "failed" and don't use a type folder...
            if (outfitsFolder == "") {
                useTypeFolder = NO;
                typeFolder = "";
                typeFolderExpected = "";

                lmSendConfig("outfitsFolder", outfitsFolder);
                lmSendConfig("useTypeFolder", "0");
                lmSendConfig("typeFolder", "");
                return;
            }

            debugSay(2,"DEBUG-SEARCHING","typeFolder search: looking for type folder: \"" + typeFolderExpected + "\": " + choice);
            debugSay(2,"DEBUG-SEARCHING","typeFolder search: Outfits folder previously found to be \"" + outfitsFolder + "\"");

            // We should NOT be here if the following statement is false.... RIGHT?
            if (typeFolderExpected != "" && typeFolder != typeFolderExpected) {
                list folderList = llCSV2List(choice);

                debugSay(2,"DEBUG-SEARCHING","looking for typeFolder(Expected) = " + typeFolderExpected);
                // This comparison is inexact - but a quick check to see
                // if the typeFolderExpected is contained in the string
                if (llSubStringIndex(choice,typeFolderExpected) >= 0) {

                    // This is exact check:
                    if (~llListFindList(folderList, (list)typeFolderExpected)) {

                        useTypeFolder = YES;
                        typeFolder = typeFolderExpected;
                        typeFolderExpected = "";
                    }
                    else {
                        useTypeFolder = NO;
                        typeFolder = "";
                        typeFolderExpected = "";
                    }

                }
                // typeFolderExpected not found at all
                else {
                    useTypeFolder = NO;
                    typeFolder = "";
                    typeFolderExpected = "";
                }

                lmSendConfig("outfitsFolder", outfitsFolder);
                lmSendConfig("useTypeFolder", (string)useTypeFolder);
                lmSendConfig("typeFolder", typeFolder);
                if (lowScriptMode) llSetTimerEvent(LOW_RATE);
                else llSetTimerEvent(STD_RATE);

                // at this point we've either found the typeFolder or not,
                // and the outfitsFolder is set

                // are we doing the initial complete search? or is this just
                // a type change?
                if (outfitSearching) {
                    outfitSearching = 0;
                    llOwnerSay("Outfits search completed in " + formatFloat(llGetTime() - outfitsSearchTimer,1) + "s");
                    outfitsSearchTimer = 0.0;
                    nudeFolder = "";
                    normalselfFolder = "";

                    // Check for ~nude and ~normalself in the same level as the typeFolder
                    //
                    // This suggests that normalselfFolder and nudeFolder are "set-once" variables - which seems logical.
                    // It also means that any ~nudeFolder and/or ~normalselfFolder found along side the Outfits folder
                    // will override any inside of the same

                    if (~llListFindList(folderList, (list)"~nude")) nudeFolder = outfitsFolder + "/~nude";
                    else
                        llOwnerSay("WARN: No nude (~nude) folder found in your outfits folder (\"" + outfitsFolder + "\")...");

                    if (~llListFindList(folderList, (list)"~normalself")) normalselfFolder = outfitsFolder + "/~normalself";
                    else
                        llOwnerSay("ERROR: No normal self (~normalself) folder found in your outfits folder (\"" + outfitsFolder + "\")... this folder is necessary for proper operation");

                    lmSendConfig("nudeFolder",nudeFolder);
                    lmSendConfig("normalselfFolder",normalselfFolder);
                }
                else lmInternalCommand("randomDress","",NULL_KEY);
            }
        }
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key query_id, string data)  {

        if (query_id == kQuery) {
            if (data == EOF) {
                phraseCount = llGetListLength(currentPhrases);
                llOwnerSay("Load of hypnotic device complete: " + (string)phraseCount + " phrases in memory");
                kQuery = NULL_KEY;
                readLine = 0;
            }
            else {
                // This is the real meat: currentPhrases is built up
                if (llStringLength(data) > 1) currentPhrases += data;

                // Read next line
                kQuery = llGetNotecardLine(typeNotecard,readLine++);
            }
        }
    }
}

//========== TRANSFORM ==========
