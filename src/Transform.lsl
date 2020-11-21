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
#define UNSET -1

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
string nudeFolder;
string normalselfFolder;
integer phraseCount;
integer changeOutfit;
string msg;
integer i;
list types;
//integer menuTime;
key transformerID;
integer readLine;
integer readingNC;
string typeNotecard;

integer outfitSearchTries;
integer typeSearchTries;
float outfitsSearchTimer;
string outfitsFolder;
integer outfitSearching;

integer findTypeFolder;

integer useTypeFolder;
integer transformedViaMenu;
string transform;
string typeFolder;

integer rlvChannel;
integer typeSearchHandle;
integer typeSearchChannel;
integer outfitSearchHandle;
integer outfitSearchChannel;

integer typeChannel;

integer transformLockExpire;

//integer startup = 1;

//integer menulimit = 9;     // 1.5 minute

integer dbConfig;
integer mustAgreeToType;
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
    // Convert state name to Title case
    stateName = cdGetFirstChar(llToUpper(stateName)) + cdButFirstChar(llToLower(stateName));

    if (stateName == "") {
        //llSay(DEBUG_CHANNEL,"Attempt made to set dollType to null string by " + script + "! Setting to Regular...");
        stateName = "Regular";
    }

    // If no change, abort
    //if (stateName == dollType) {
    //    debugSay(2,"DEBUG-DOLLTYPE","No doll type change necessary...");
    //    return;
    //}

    debugSay(2,"DEBUG-DOLLTYPE","Changing (" + (string)automated + ") to type " + stateName + " from " + dollType);

    // By not aborting, selecting the same state can cause a "refresh" ...
    // though our menus do not currently allow this
    currentPhrases = [];
    readLine = 0;
    typeNotecard = TYPE_FLAG + stateName;
    typeFolderExpected = TYPE_FLAG + stateName;

    // Look for Notecard for the Doll Type and start reading it if showPhrases is enabled
    //
    if (showPhrases) {
        if (llGetInventoryType(typeNotecard) == INVENTORY_NOTECARD) {

            kQuery = llGetNotecardLine(typeNotecard,readLine++);

            debugSay(2,"DEBUG-DOLLTYPE","Found notecard: " + typeNotecard);
        }
    }

    if (!automated) transformLockExpire = llGetUnixTime() + TRANSFORM_LOCK_TIME;
    else transformLockExpire = 0;
    lmSendConfig("transformLockExpire",(string)transformLockExpire);

    // We dont respond to this: we don't have to
    lmSendConfig("dollType", (dollType = stateName));

    llOwnerSay("You have become a " + dollType + " Doll.");

    typeFolder = "";

    outfitSearchTries = 0;
    typeSearchTries = 0;

    // if RLV is non-functional, dont search for a Type Folder
    if (RLVok == TRUE) {
        debugSay(2,"DEBUG-DOLLTYPE","Searching for " + typeFolderExpected);
        outfitsSearchTimer = llGetTime();
        typeSearchHandle = cdListenMine(typeSearchChannel);
        folderSearch(outfitsFolder,typeSearchChannel);
    }
    // if NOT RLVok then we have a DollType with no associated typeFolder...

    lmInternalCommand("setWindRate","",NULL_KEY);
    debugSay(2,"DEBUG-DOLLTYPE","Changed to type " + dollType);
}

reloadTypeNames(key id) {
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
#ifndef ADULT_MODE
            if (typeName != "Slut") types += typeName;
#else
            types += typeName;
#endif
        }
    }

    //We don't need a Notecard to be present for these to be active
    //
    // Note the following rules of the built-in types:
    //   - Display: Notecard is ok but not needed
    //   - Slut: rejects type even if Notecard is present if not ADULT, else Notecard ok but not needed
    //
    if (llListFindList(types, (list)"Display") == NOT_FOUND) types += [ "Display" ];
#ifdef ADULT_MODE
    if (simRating == "MATURE" || simRating == "ADULT")
        if (llListFindList(types, (list)"Slut") == NOT_FOUND) types += [ "Slut" ];
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

    if (channel == 0) {
        if (folder != "") {
            llSay(DEBUG_CHANNEL,"Searching folder " + folder + " invalid with no channel!");
        }
        else {
            llSay(DEBUG_CHANNEL,"Searching folder (unspecified) invalid with no channel!");
        }
    }
    else {
        // The folder search starts as a RLV @getinv call...
        //
        if (folder == "") lmRunRLV("getinv=" + (string)channel);
        else lmRunRLV("getinv:" + folder + "=" + (string)channel);

        // The next stage is the listener, while we create a time
        // out to timeout the RLV call...
        llSetTimerEvent(RLV_TIMEOUT);
    }
}

//========================================
// STATES
//========================================
default {
    state_entry() {
        dollID =   llGetOwner();
        dollName = lmMyDisplayName(dollID);

        cdInitializeSeq();
        RLVok = UNSET;
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & CHANGED_ALLOWED_DROP)
            reloadTypeNames(NULL_KEY);
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
        if (timeReporting) {
            string s;

            s = "Transform Timer fired, interval " + (string)(llGetTime() - lastTimerEvent) + "s. (lowScriptMode ";
            if (lowScriptMode) s += "is active).";
            else s += "is not active).";

            debugSay(5,"DEBUG-TRANSFORM",s);

            lastTimerEvent = llGetTime();
        }
#endif
        // transform lock: check time
        if (transformLockExpire) {
            if (transformLockExpire  <= llGetUnixTime()) {
                lmSendConfig("transformLockExpire",(string)(transformLockExpire = 0));
            }
            else lmSendConfig("transformLockExpire",(string)(transformLockExpire));
        }

#ifdef HOMING_BEACON
        if (homingBeacon) {
            string timeLeft = llList2String(split, 0);

            // is it possible to be collapsed but collapseTime be equal to 0.0?
            if (collapsed) {
                float timeCollapsed = llGetUnixTime() - collapseTime;

                if (timeCollapsed > TIME_BEFORE_TP)
                    if (llGetInventoryType(LANDMARK_HOME) == INVENTORY_LANDMARK)
                        lmInternalCommand("teleport", LANDMARK_HOME, id);
            }
        }
#endif
        if (RLVok == TRUE) {
            // if we get here then the search RLV timed out
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

        //----------------------------------------
        // SHOW PHRASES

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

        //----------------------------------------
        // SET TIMER INTERVAL

        if (lowScriptMode) llSetTimerEvent(LOW_RATE);
        else llSetTimerEvent(STD_RATE);

        //----------------------------------------
        // UPDATE HOVERTEXT
        //
        // every 30s or every 60s is too slow

        // Update sign if appropriate
        //string primText = llList2String(llGetPrimitiveParams([ PRIM_TEXT ]), 0);
        //
        //     if (collapsed)   { cdSetHovertext("Disabled Dolly!",        ( RED    )); }
        //else if (afk)         { cdSetHovertext(dollType + " Doll (AFK)", ( YELLOW )); }
        //else if (hovertextOn) { cdSetHovertext(dollType + " Doll",       ( WHITE  )); }
        //else                  { cdSetHovertext("",                       ( WHITE  )); }

        //----------------------------------------
        // AUTO AFK TRIGGERS

        // if we can AFK, check for auto AFK triggers
        if (canAFK) {
            integer dollAway = ((llGetAgentInfo(dollID) & (AGENT_AWAY | (AGENT_BUSY * busyIsAway))) != 0);

            if (afk) {
                // Dolly is flagged as afk... check to see if afk was automatically triggered,
                // and if Dolly is no longer afk
                if (!dollAway && autoAfk) {
                    lmSetConfig("afk", (string)NOT_AFK);
                    lmSetConfig("autoAfk", (string)FALSE);
                    llOwnerSay("You hear the Key whir back to full power");

                }
            }
            else {
                // Dolly is flagged as NOT afk... see if Dolly has automatically gone afk, and adjust
                // appropriately - and mark afk as auto-triggered
                if (dollAway) {
                    lmSetConfig("afk", (string)TRUE);
                    lmSetConfig("autoAfk", (string)TRUE);
                    llOwnerSay("Automatically entering AFK mode; Key subsystems slowing...");
                }
            }

            lmInternalCommand("setWindRate","",NULL_KEY);
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

        transformerID = id;

        string choice = cdListElement(split, 0);
        string name = cdListElement(split, 1);
#ifdef DEVELOPER_MODE

        // This is a way to watch the messages coming over the wire...
        // no need for a separate script to do it
        if ((debugLevel > 4 && code != 11 && code != 12 && code != 15) || debugLevel > 5) {
            string s = "Transform Link Msg:" + script + ":" + (string)code + ":choice/name";
            string t = choice + "/" + name;

            if (id != NULL_KEY || debugLevel > 6) debugSay(5,"DEBUG-TRANSFORM",s + "/id = " + t + "/" + (string)id);
            else debugSay(5,"DEBUG-TRANSFORM",s + " = " + t);
        }
#endif
        scaleMem();

        if (script == "Transform") return;

        if (code == CONFIG) {

            string name = cdListElement(split, 0);
            string value = cdListElement(split, 1);

            split = llDeleteSubList(split,0,0);

                 if (name == "afk")                               afk = (integer)value;
            else if (name == "autoAfk")                       autoAfk = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "timeReporting")           timeReporting = (integer)value;
            else if (name == "debugLevel")                 debugLevel = (integer)value;
#endif
            else if (name == "lowScriptMode")           lowScriptMode = (integer)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
            else if (name == "simRating")                   simRating = value;
            else if (name == "hardcore")                     hardcore = (integer)value;
            else if (name == "backMenu")                     backMenu = value;
            else if (name == "hovertextOn")               hovertextOn = (integer)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
            else if (name == "busyIsAway")                 busyIsAway = (integer)value;
            else if (name == "controllers") {
                if (split == [""]) controllers = [];
                else controllers = split;
            }
            else if (name == "canAFK")                         canAFK = (integer)value;
            else if (name == "mustAgreeToType")       mustAgreeToType = (integer)value;
            else if (name == "winderRechargeTime") winderRechargeTime = (integer)value;
#ifdef HOMING_BEACON
            else if (name == "homingBeacon")             homingBeacon = (integer)value;
            else if (name == "collapseTime")             collapseTime = (integer)value;
#endif
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
            else if (name == "dialogChannel") {
                dialogChannel = (integer)value;

                //llSay(DEBUG_CHANNEL,"Dialog channel set to" + (string)dialogChannel);

                rlvChannel = ~dialogChannel + 1;
                typeChannel = dialogChannel - 778;

                typeSearchChannel = rlvChannel + 1;
                outfitSearchChannel = rlvChannel + 2;
            }
        }

        else if (code == SET_CONFIG) {

            string name = cdListElement(split, 0);
            string value = cdListElement(split, 1);

            if (name == "dollType") {
                setDollType(value, AUTOMATED);
            }
            else if (name == "transformLockExpire") {
                lmSendConfig("transformLockExpire",(string)(transformLockExpire = (integer)value));
            }
            else if (name == "outfitsFolder") {
                lmSendConfig("outfitsFolder",outfitsFolder = value);
            }
        }
        else if (code == INTERNAL_CMD) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "optionsMenu") {
                list pluslist;
                lmSendConfig("backMenu",(backMenu = MAIN));
                debugSay(2,"DEBUG-OPTIONS","Building Options menu...");
                debugSay(2,"DEBUG-OPTIONS","isDoll = " + (string)cdIsDoll(id));
                debugSay(2,"DEBUG-OPTIONS","isCarrier = " + (string)cdIsCarrier(id));
                debugSay(2,"DEBUG-OPTIONS","isUserController = " + (string)cdIsUserController(id));

                if (cdIsDoll(id)) {
                    msg = "See " + WEB_DOMAIN + "keychoices.htm for explanation. ";
                    pluslist += [ "Operation...", "Public...", "Key..." ];

                    if (cdCarried() || cdControllerCount() > 0) {
                        pluslist += [ "Access..." ];
                    }
                    else {
                        pluslist += [ "Type...", "Access..." ];
                        if (RLVok == TRUE) pluslist += [ "Restrictions..." ];
                    }
                }
                else if (cdIsCarrier(id)) {
                    pluslist += [ "Type..." ];
                    if (RLVok == TRUE) pluslist += [ "Restrictions..." ];
                }
                else if (cdIsUserController(id)) {

                    msg = "See " + WEB_DOMAIN + "controller.htm. Choose what you want to happen.";

                    pluslist += [ "Type...", "Access..." ];
                    if (RLVok == TRUE) pluslist += [ "Restrictions..." ];
                    pluslist += [ "Drop Control" ];

                }
                // This section should never be triggered: it means that
                // someone who shouldn't see the Options menu did.
                else return;

                debugSay(2,"DEBUG-OPTIONS","Options menu built; presenting to " + (string)id);
                cdDialogListen();
                llDialog(id, msg, dialogSort(pluslist + "Back..."), dialogChannel);
            }
        }

        else if (code == RLV_RESET) {
            RLVok = (integer)choice;
            if (dollType == "") {
                setDollType("Regular", AUTOMATED);
                llSay(DEBUG_CHANNEL,"dollType had to be fixed from blank");
            }

            outfitsFolder = "";
            typeFolder = "";
            outfitSearchTries = 0;
            typeSearchTries = 0;
            changeOutfit = 1;

            if (RLVok == TRUE) {
                if (rlvChannel) {
                    typeSearchHandle = cdListenMine(typeSearchChannel);
                    outfitSearchHandle = cdListenMine(outfitSearchChannel);

                    if (outfitsFolder == "" && !outfitSearching) {
                        // No outfit folder: let's search.

                        debugSay(2,"DEBUG-RLVOK","Searching for Outfits and Typefolders");

                        outfitSearching = 1;
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
        else if (code == MENU_SELECTION) {
            string optName = llGetSubString(choice, 2, STRING_END);
            string curState = cdGetFirstChar(choice);

            // for timing out the Menu
            //menuTime = llGetTime();

            // Transforming options
            if ((choice == "Type...")        ||
                (optName == "Verify Type")   ||
                (optName == "Show Phrases")
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
                list choices;

                if (!hardcore)
                    choices += cdGetButton("Verify Type", id, mustAgreeToType, 0);

                choices += cdGetButton("Show Phrases", id, showPhrases, 0);

                lmSendConfig("backMenu",(backMenu = "Options..."));
                backMenu = MAIN;
                cdDialogListen();
                llDialog(id, "Options", dialogSort(choices + "Back..."), dialogChannel);
            }

            // Choose a Transformation
            else if (choice == "Types...") {
                string msg3 = " cannot be transformed right now, as ";
                string msg4 = " recently transformed into a " + dollType + " doll. ";

                integer i;

                debugSay(5,"DEBUG-TYPES","Types selected");
                // Doll must remain in a type for a period of time
                if (transformLockExpire) {
                    debugSay(5,"DEBUG-TYPES","Transform locked");

                    if (cdIsDoll(id)) msg = "You " + msg3 + " you were " + msg4;
                    else msg = dollName + msg3 + " Dolly was " + msg4;

                    // This conditional is needed in case the timing is off...
                    if ((i = llFloor((transformLockExpire - llGetUnixTime()) / SEC_TO_MIN)) > 0) {
                        if (cdIsDoll(id)) msg += "You ";
                        else msg += "Dolly ";
                        msg += " can be transformed in " + (string)i + " minutes. ";
                    }

                    llDialog(id, msg, ["OK"], DISCARD_CHANNEL);
                }
                else {
                    // Transformation lock time has expired: transformations (type changes) now allowed
                    reloadTypeNames(id);
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

                        if (!hardcore)
                            llOwnerSay(cdProfileURL(id) + " is looking at your doll types.");
                    }

                    lmSendConfig("backMenu",(backMenu = MAIN));
                    cdDialogListen();
                    llDialog(id, msg, dialogSort(llListSort(choices, 1, 1) + "Back..."), typeChannel);
                }
                debugSay(5,"DEBUG-TYPES","Transform complete");
            }

            // Transform
            else if (choice == "Transform") {
                // We get here because dolly had to confirm the change
                // of type - and chose "Transform" from the menu
                transformedViaMenu = YES;
                setDollType(transform, NOT_AUTOMATED);
#ifdef DEVELOPER_MODE
                //llSay(DEBUG_CHANNEL,"randomDress called: Transform button");
#endif
                //lmInternalCommand("randomDress","",NULL_KEY);
            }
        }
        else if (code == TYPE_SELECTION) {
            // "choice" is a valid Type: change to it as appropriate

            if (cdIsDoll(id) || cdIsController(id) || !mustAgreeToType || hardcore) {
                transform = "";

                // Doll (or a Controller) chose a Type - or no confirmation needed: just do it
                transformedViaMenu = YES;
                setDollType(choice, NOT_AUTOMATED);
#ifdef DEVELOPER_MODE
                //llSay(DEBUG_CHANNEL,"randomDress called: (Type) button");
#endif
                //lmInternalCommand("randomDress","",NULL_KEY);
            }
            else {
                // This section is executed when:
                //
                // 1. Accessor is NOT Dolly, AND
                // 2. Accessor is NOT a Controller, AND
                // 3. Dolly must agree to Type...

                // A member of the public chose a Type and confirmation is required
                cdSayTo("Getting confirmation from Doll...",id);

                transform = choice; // save transformation Type
                list choices = ["Transform", "Dont Transform", MAIN ];
                string msg = "Do you wish to be transformed to a " + choice + " Doll?";

                cdDialogListen();
                llDialog(dollID, msg, choices, dialogChannel); // this starts a new choice on this channel
            }
        }
        else if (code < 200) {
            if (code == 102) {
                configured = 1;
            }
            else if (code == 104) {
                reloadTypeNames(NULL_KEY);
                llSetTimerEvent(30.0);

                // Might have been set in Prefs, so do this late
            }
            else if (code == 110) {
                //initState = 105;
                //
                // note that dollType is ALREADY SET....
                // this is bad form but allows us to defer the subroutine
                // until now in the startup process
                setDollType(dollType, AUTOMATED);
            }
            else if (code == MEM_REPORT) {
                memReport(cdMyScriptName(),(float)choice);
            }
            else if (code == CONFIG_REPORT) {
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
            outfitSearching = 1; // if we get here - well, we're outfit searchiung ja?

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
                        if (~llListFindList(folderList, (list)"~nude"))        lmSendConfig("nudeFolder",      (nudeFolder       = outfitsFolder + "/~nude"));
                        if (~llListFindList(folderList, (list)"~normalself"))  lmSendConfig("normalselfFolder",(normalselfFolder = outfitsFolder + "/~normalself"));
                    }

                    debugSay(2,"DEBUG-SEARCHING","outfitsFolder = " + outfitsFolder);

                    lmSendConfig("outfitsFolder", outfitsFolder);
                    //lmSendConfig("typeFolder", typeFolder);
                    //lmSendConfig("useTypeFolder", (string)useTypeFolder);

                    debugSay(2,"DEBUG-SEARCHING","typeFolder = \"" + typeFolder + "\" and typeFolderExpected = \"" + typeFolderExpected + "\"");
                    // Search for a typeFolder...
                    if (typeFolder == "" && typeFolderExpected != "") {
                        debugSay(2,"DEBUG-SEARCHING","Outfit folder found in " + (string)(llGetTime() - outfitsSearchTimer) + "s; searching for typeFolder");
                        // outfitsFolder search is done: search for typeFolder
                        folderSearch(outfitsFolder,typeSearchChannel);
                    }
                    //else {
                          // typeFolder is set, or no typeFolder is expected
                    //    lmInternalCommand("randomDress","",NULL_KEY);
                    //}
                }
            }


        }
        else if (channel == typeSearchChannel) {

            // Note that we may have gotten here *without* having run through
            // the outfits search first - due to having done the outfits search
            // much earlier... However.... if we are here, then the outfits search
            // must have run before, but not necessarily immediately before...

            // Note that, unlike the dialog channel, the type search channel is
            // removed and recreated... maybe it should not be
            llListenRemove(typeSearchHandle);

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

                    // This is the exact check:
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

                // at this point we've either found the typeFolder or not,
                // and the outfitsFolder is set

                // are we doing the initial complete search? or is this just
                // a type change?
                if (outfitSearching) {

                    debugSay(2,"DEBUG-SEARCHING","Ending an outfit Search...");

                    // we finished our outfit search: so end the search and
                    // put out results
                    outfitSearching = 0;
                    llOwnerSay("Outfits search completed in " + (string)(llGetTime() - outfitsSearchTimer) + "s");
                    outfitsSearchTimer = 0;
                    nudeFolder = "";
                    normalselfFolder = "";

                    // Check for ~nude and ~normalself in the same level as the typeFolder
                    //
                    // This suggests that normalselfFolder and nudeFolder are "set-once" variables - which seems logical.
                    // It also means that any ~nudeFolder and/or ~normalselfFolder found along side the Outfits folder
                    // will override any inside of the same

                    if (~llListFindList(folderList, (list)"~nude")) nudeFolder = outfitsFolder + "/~nude";
                    else {
                        llOwnerSay("WARN: No nude (~nude) folder found in your outfits folder (\"" + outfitsFolder + "\")...");
#ifdef DEVELOPER_MODE
                        llSay(DEBUG_CHANNEL,"No ~nude folder found in \"" + outfitsFolder + "\"");
#endif
                    }

                    if (~llListFindList(folderList, (list)"~normalself")) normalselfFolder = outfitsFolder + "/~normalself";
                    else {
                        llOwnerSay("ERROR: No normal self (~normalself) folder found in your outfits folder (\"" + outfitsFolder + "\")... this folder is necessary for proper operation");
                        llSay(DEBUG_CHANNEL,"No ~normalself folder found in \"" + outfitsFolder + "\": this folder is required for proper Key operation");
                    }

                    lmSendConfig("nudeFolder",nudeFolder);
                    lmSendConfig("normalselfFolder",normalselfFolder);
                }
                //else {
                //    debugSay(2,"DEBUG-SEARCHING","Random dress being chosen");
#ifdef DEVELOPER_MODE
                //    llSay(DEBUG_CHANNEL,"randomDress called after Search");
#endif
                //    lmInternalCommand("randomDress","",NULL_KEY);
                //}
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
