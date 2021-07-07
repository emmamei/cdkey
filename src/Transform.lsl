//========================================
// Transform.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl

#include "include/GlobalDefines.lsl"

#define TYPE_CHANNEL_OFFSET 778
#define TYPE_FLAG "*"
#define NO_FILTER ""
#define UNSET -1

#define cdProfileURL(i) "secondlife:///app/agent/"+(string)(i)+"/about"
#define cdStringEndMatch(a,b) llGetSubString(a,-llStringLength(b),STRING_END)==b

#define cdListenMine(a)   llListen(a, NO_FILTER, dollID, NO_FILTER)

// Channel to use to discard dialog output
#define DISCARD_CHANNEL 9999

// Script Control
#define RUNNING 1
#define NOT_RUNNING 0
#define cdRunScript(a) llSetScriptState(a, RUNNING);
#define cdStopScript(a) llSetScriptState(a, NOT_RUNNING);
#define getInv(a,b) \
    if (a == "") lmRunRlv("getinv=" + (string)(b)); \
    else lmRunRlv("getinv:" + a + "=" + (string)(b))

#define isFound(a) (a!="")
#define isNotFound(a) (a=="")

// Note that these two values are used by ALL searches...
#define MAX_SEARCH_RETRIES 2
#define RLV_TIMEOUT 15.0

#define adjustTimer() \
    if (lowScriptExpire > 0) llSetTimerEvent(LOW_RATE);\
    else llSetTimerEvent(STD_RATE)

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

// The typeSearch and systemSearch start the same way, but the channels are
// different...
//
// Define macros to make the process more readable

#define folderSearch(a,b) \
    if (rlvOk == FALSE) return;\
    b = cdListenMine(a);\
    getInv(outfitFolder,a);\
    llSetTimerEvent(RLV_TIMEOUT)

#define typeSearch(a,b)   folderSearch(a,b)
#define systemSearch(a,b) folderSearch(a,b)

#define outfitSearchComplete (outfitFolder != "")

//========================================
// VARIABLES
//========================================
string nudeFolder;
string normalselfFolder;
string normaloutfitFolder;

integer phraseCount;
integer changeOutfit;
string msg;
integer i;

list typeBufferedList;
list typeFolderBufferedList;
integer typeFolderBufferChannel;
integer typeFolderBufferHandle;

key transformerID;
integer readLine;
integer readingNC;
string typeNotecard;
integer timerMark;

integer outfitSearching;
integer outfitSearchTries;
integer typeSearchTries;
integer systemSearchTries;

integer findTypeFolder;

string typeToConfirm;

// These dual variables allow us to separate the actual valid typeFolder
// from the one being searched for
string typeFolder; // Valid and current typeFolder
string typeFolderExpected; // typeFolder being searched for

// And dual variables for outfit too, just like type - except these only
// get used if the preferences file has an entry in it
string outfitFolder;
string outfitFolderExpected;

// Folder that contains full avatars, not outfits
string avatarFolder;

// And dual variables for dollType too, just like type - except these only
// get used if the preferences file has an entry in it
//string dollType;
string dollTypeExpected;

//integer rlvChannel;
integer typeSearchHandle;
integer typeSearchChannel;
integer outfitSearchHandle;
integer outfitSearchChannel;
integer systemSearchHandle;
integer systemSearchChannel;

integer typeDialogChannel;
integer typeDialogHandle;

integer dbConfig;
integer mustAgreeToType;
string keySpecificMenu;

key typeNotecardQuery;

list currentPhrases;

//========================================
// FUNCTIONS
//========================================

setDollType(string typeName) {
    // Convert state name to Title case
    //typeName = cdGetFirstChar(llToUpper(typeName)) + cdButFirstChar(llToLower(typeName));

    reloadTypeNames(NULL_KEY);

    //----------------------------------------
    // VALIDATE TYPE
    //
    // Note we test against the buffered list (notecards) but
    // also test againts the buffered list of folders if it
    // exists.
    //
    if (!cdFindInList(typeBufferedList, typeName)) {

        if (typeFolderBufferedList == []) {

            llSay(DEBUG_CHANNEL,"Invalid Doll Type specified!");
            return;
        }
        else {

            if (!cdFindInList(typeFolderBufferedList, typeName)) {

                // Not in Type List, and not in Type Folder List either...
                llSay(DEBUG_CHANNEL,"Invalid Doll Type specified!");
                return;

            }
        }
    }

    if (typeName == "") typeName = "Regular";

#ifdef DEVELOPER_MODE
    debugSay(2,"DEBUG-DOLLTYPE","Changing dolltype to type '" + typeName + "' from '" + dollType + "'");
#endif

    // By not aborting, selecting the same state can cause a "refresh" ...
    // though our menus do not currently allow this
    currentPhrases = [];
    readLine = 0;

    if (typeName != "Regular") {
        typeNotecard = TYPE_FLAG + typeName;
        typeFolderExpected = TYPE_FLAG + typeName;

        // Look for Notecard for the Doll Type and start reading it if showPhrases is enabled
        //
        if (showPhrases) {
            if (llGetInventoryType(typeNotecard) == INVENTORY_NOTECARD) {

                typeNotecardQuery = llGetNotecardLine(typeNotecard,readLine++);

                debugSay(2,"DEBUG-DOLLTYPE","Found notecard: " + typeNotecard);
            }
        }
    }

    // This propogates dollType value to the rest of the system
    lmSendConfig("dollType", (dollType = typeName));
    llOwnerSay("You have become a " + dollType + " Doll.");

    // Now search for a Type folder for Dolly and set it
    typeFolder = "";
    outfitSearchTries = 0;
    typeSearchTries = 0;

    // Only search for a type folder - outfit folder - if RLV is active and Doll is
    // not a Regular Doll
    //
    if (typeName != "Regular") {
        if (rlvOk == TRUE) {
            debugSay(4,"DEBUG-DOLLTYPE","Searching for type folder: " + typeFolderExpected);

            typeSearchHandle = cdListenMine(typeSearchChannel);

            // Search for type folder
            typeSearch(typeSearchChannel,typeSearchHandle);
        }
    }

    lmInternalCommand("setWindRate","",NULL_KEY); // runs in Main
    debugSay(2,"DEBUG-DOLLTYPE","Changed to type " + dollType);
}

reloadTypeFolderNames() {
    if (outfitFolder == "") return;

    typeFolderBufferHandle = llListen(typeFolderBufferChannel, NO_FILTER, dollID, NO_FILTER);
    lmRunRlv("getinv:" + outfitFolder + "=" + (string)(typeFolderBufferChannel));
}

reloadTypeNames(key id) {
    string typeName;

    integer n = llGetInventoryNumber(INVENTORY_NOTECARD);

    //if (n == 0) {
    //    llOwnerSay("No types found.");
    //    return;
    //}

    if (typeBufferedList == []) {

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
#ifdef ADULT_MODE
                typeBufferedList += typeName;
#else
                // Don't allow Slut notecard to define Slut type (not an Adult Key)
                if (typeName != "Slut") typeBufferedList += typeName;
#endif
            }
        }

#define inTypeBufferedList(a) (~llListFindList(typeBufferedList, (list)(a)))

        //We don't need a Notecard to be present for these to be active
        //
        // Note the following rules of the built-in types:
        //   - Display: Notecard is ok but not needed
        //   - Slut: rejects type even if Notecard is present if not ADULT, else Notecard ok but not needed
        //   - Regular: Notecard is ignored
        //   - Domme: only activated if Notecard present
        //
        if (!inTypeBufferedList("Display")) typeBufferedList += (list)"Display";
        if (!inTypeBufferedList("Regular")) typeBufferedList += (list)"Regular";

#ifdef ADULT_MODE
        // This makes the process location-dependent...
        if (simRating == "MATURE" || simRating == "ADULT")
            if (!inTypeBufferedList("Slut")) typeBufferedList += (list)"Slut";
#endif
    }
}

outfitSearch(integer channel,integer handle) {

    // This should bypass repeated calls to search for outfit folder
    //
    // Note that this means if you switch from one Outfits folder name
    // to another, this will fail: a key reset will be needed
    //
    //if (outfitFolder != "") return;
    if (rlvOk == FALSE) {
        // Reset the works before we abort
        lmSendConfig("outfitFolder",(outfitFolder = ""));
        lmSendConfig("nudeFolder",(nudeFolder = ""));
        lmSendConfig("normalselfFolder",(normalselfFolder = ""));
        lmSendConfig("normaloutfitFolder",(normaloutfitFolder = ""));
        lmInitStage(INIT_STAGE4); // Outfits search failed (no RLV): continue
        return;
    }

    outfitSearching = TRUE;

    debugSay(6,"DEBUG-SEARCHING","outfitSearch in progress (rlvOk = " + (string)rlvOk + ")");

    folderSearch(channel,handle);
}

//========================================
// STATES
//========================================
default {

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        dollID =   llGetOwner();
        keyID =   llGetKey();
        dollName = dollyName();
        myName = llGetScriptName();

        cdInitializeSeq();
        rlvOk = UNSET;
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & CHANGED_ALLOWED_DROP) {
            reloadTypeNames(NULL_KEY);
            //reloadTypeFolderNames();
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    //
    // Timer is used when:
    //    - Searching for RLV, and it times out
    //    - Transform lock is active
    //    - Homing device is active
    //    - Phrases are being used
    //
    // These are all affected by the low script mode which reduces
    // the number of timer calls.
    //
    timer() {

        timerMark = llGetUnixTime();

        // No searching happens unless RLV is ok...
        //
        // Checks happen when:
        //
        //    1. rlvChannel is good and RLV is ok...
        //    2. Doll Type changes
        //    3. Link message 350: rlvOk and/or Reset
        //
        // Everything related to Outfits Changes happens here (and in the listener)
        // What made the former code complicated is that there are several processes
        // intermingled together:
        //
        //    1. Searching for a particular default Outfits folder
        //    2. Multiple retries for each search
        //    3. Searching for a Types folder
        //
        // outfitFolder = Top Level folder that contains all outfits (e.g., "> Outfits")
        // typeFolder = Folder related to current Doll Type (e.g., "*Japanese")
        // typeFolderExpected = Computed but untested typeFolder

#ifdef DEVELOPER_MODE
        string s = "Transform Timer fired";

        if (lowScriptExpire) s += " (low script mode enabled)";
        s += ".";

        debugSay(5,"DEBUG-TRANSFORM",s);
#endif
        //----------------------------------------
        // TYPE LOCK
        //
        if (typeLockExpire) {
            if (typeLockExpire  <= timerMark) {
                lmSetConfig("typeLockExpire",(string)(typeLockExpire = 0));
            }
        }

#ifdef HOMING_BEACON
        //----------------------------------------
        // HOMING BEACON: AUTO-TRANSPORT
        //
        if (homingBeacon) {
            string timeLeft = (string)split[0];

            // is it possible to be collapsed but collapseTime be equal to 0.0?
            if (collapsed) {
                if ((timerMark - collapseTime) > TIME_BEFORE_TP)
                    lmInternalCommand("teleport", LANDMARK_HOME, dollID);
            }
        }
#endif
        //----------------------------------------
        // OUTFIT SEARCH: RLV TIMEOUTS
        //
        if (rlvOk == TRUE) {
            // If rlvOk is true, then check if outfit searches need to be retried...
            if (outfitSearchHandle) {
                if (outfitSearchTries++ < MAX_SEARCH_RETRIES)

                    // Try another search for outfits
                    outfitSearch(outfitSearchChannel,outfitSearchHandle);

                else {
                    llListenRemove(outfitSearchHandle);
                    outfitSearchHandle = 0;
                    outfitSearching = FALSE;

                    outfitFolder = "";
                    typeFolder = "";
                    outfitFolderExpected = "";
                    typeFolderExpected = "";

                    // This is functional error...
                    llSay(DEBUG_CHANNEL,"Outfit search FAILED. No outfits or types are available.");
                    adjustTimer();
                    lmInitStage(INIT_STAGE4); // Outfits search failed: continue
                }
            }
            else if (typeSearchHandle) {
                if (typeSearchTries++ < MAX_SEARCH_RETRIES) {

                    // Try another search for Type directories
                    typeSearch(typeSearchChannel,typeSearchHandle);

                }
                else {
                    llListenRemove(typeSearchHandle);
                    typeSearchHandle = 0;

                    typeFolder = "";
                    typeFolderExpected = "";

                    // This is not a functional error, though it detracts functionality.
                    llOwnerSay("No type folder was found for " + dollType + " Dolls.");
                    adjustTimer();
                }
            }
            else if (systemSearchHandle) {
                if (systemSearchTries++ < MAX_SEARCH_RETRIES) {

                    // Try another search for outfits
                    systemSearch(systemSearchChannel,systemSearchHandle);

                }
                else {
                    llListenRemove(systemSearchHandle);
                    systemSearchHandle = 0;

                    nudeFolder = "";
                    normalselfFolder = "";
                    normaloutfitFolder = "";

                    // This is functional error...
                    llSay(DEBUG_CHANNEL,"Outfit search FAILED. No system folders were found.");
                    adjustTimer();
                    lmInitStage(INIT_STAGE4); // System folder search failed: continue
                }
            }
        }

        //----------------------------------------
        // SHOW PHRASES
        //
        if (showPhrases) {
            if (phraseCount) {

                // select a phrase from the notecard at random
                string phrase  = (string)currentPhrases[llFloor(llFrand(phraseCount))];

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
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer lmSource, integer lmInteger, string lmData, key lmID) {

        parseLinkHeader(lmData,lmInteger);

        transformerID = lmID;

        // This means that ANY link message sent by Transform is ignored by these
        // items, except for the SET_CONFIG section...
        //
        // Link messages sent by other scripts are not ignored in the slightest..
        //
        // This script uses SEND_CONFIG extensively, plus a couple RLV calls and
        // internal commands. Ignoring SEND_CONFIG is probably wise, but the
        // rest is likely overkill, though not problematic in practice.
        //
        if (script == "Transform" && code == SEND_CONFIG) return;

        if (code == SEND_CONFIG) {

            string name = (string)split[0];

            list cmdList = [
                             "collapsed",
#ifdef DEVELOPER_MODE
                             "debugLevel",
#endif
                             "simRating",
#ifdef ADULT_MODE
                             "hardcore",
#endif
                             "backMenu",
                             "typeHovertext",
                             "collapsed",
                             "busyIsAway",
                             "controllers",
                             "rlvOk",
                             "mustAgreeToType",
                             "winderRechargeTime",
                             "keySpecificMenu",
#ifdef HOMING_BEACON
                             "homingBeacon",

                             // collapseTime only needed for homingBeacon use
                             "collapseTime",
#endif
                             "showPhrases",
                             "dialogChannel"
            ];

            // Commands need to be in the list cmdList in order to be
            // recognized, before testing down below
            //
            if (!cdFindInList(cmdList, name))
                return;

            string value = (string)split[1];

            split = llDeleteSubList(split,0,0);

                 if (name == "collapsed")                   collapsed = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                 debugLevel = (integer)value;
#endif
            else if (name == "simRating")                   simRating = value;
#ifdef ADULT_MODE
            else if (name == "hardcore")                     hardcore = (integer)value;
#endif
            else if (name == "backMenu")                     backMenu = value;
            else if (name == "typeHovertext")           typeHovertext = (integer)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
            else if (name == "busyIsAway")                 busyIsAway = (integer)value;
            else if (name == "controllers") {
                if (split == [""]) controllerList = [];
                else controllerList = split;
            }
            else if (name == "rlvOk")                           rlvOk = (integer)value;
            else if (name == "mustAgreeToType")       mustAgreeToType = (integer)value;
            else if (name == "winderRechargeTime") winderRechargeTime = (integer)value;
            else if (name == "keySpecificMenu")       keySpecificMenu = value;
#ifdef HOMING_BEACON
            else if (name == "homingBeacon")             homingBeacon = (integer)value;

            // collapseTime only needed for homingBeacon use
            else if (name == "collapseTime") {
                collapseTime = (integer)value;
                if (homingBeacon) adjustTimer();
            }
#endif
            else if (name == "showPhrases") {
                showPhrases = (integer)value;
                currentPhrases = [];

                // if showPhrases is turned on, read hypno phrases from notecard
                if (showPhrases) {
                    if (llGetInventoryType(typeNotecard) == INVENTORY_NOTECARD) {
                        typeNotecardQuery = llGetNotecardLine(typeNotecard,readLine);
                    }
                    adjustTimer();
                }
            }
            else if (name == "dialogChannel") {
                dialogChannel = (integer)value;

                typeDialogChannel = dialogChannel - TYPE_CHANNEL_OFFSET;

//                           rlvChannel = ~dialogChannel + 1;
                      typeSearchChannel = ~dialogChannel + 2;
                    outfitSearchChannel = ~dialogChannel + 3;
                    systemSearchChannel = ~dialogChannel + 4;
                typeFolderBufferChannel = ~dialogChannel + 5;
            }
        }

        else if (code == SET_CONFIG) {

            string name = (string)split[0];
            string value = (string)split[1];

            if (name == "dollType") {
                if (value != dollType) {
                    dollTypeExpected = value;

                    // Here, this conditional allows us to "set" dollTypeExpected, but defer the actual
                    // setting until stage 5 below.
                    if (outfitSearchComplete) setDollType(value);
                }
            }
            else if (name == "typeLockExpire") {
                if (value == "0")
                    typeLockExpire = 0;
                else {
                    typeLockExpire = llGetUnixTime() + TYPE_LOCK_TIME;
                    adjustTimer();
                }
                lmSendConfig("typeLockExpire",(string)(typeLockExpire));
            }
            else if (name == "outfitFolder") {
                // Search for and validate user-specified outfit folder
                outfitFolderExpected = value;
                outfitSearch(outfitSearchChannel,outfitSearchHandle);
            }
        }

        else if (code == INTERNAL_CMD) {
            string cmd = (string)split[0];
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "optionsMenu") {
                list optionsMenuButtons;
                string optionsMenuMessage;

                lmSendConfig("backMenu",(backMenu = MAIN));
                debugSay(6,"DEBUG-OPTIONS","Building Options menu...");

                if (cdIsDoll(lmID)) {
                    optionsMenuMessage = "See the help file for information on these options.";
                }
                else if (cdIsExternalController(lmID) || cdIsCarrier(lmID)) {
                    optionsMenuMessage = "See the help file for more information on these options. Choose what you want to happen.";
                }

                // ----------------------------------------
                // Key... and Access... Buttons
                //
                // SECURITY: These buttons are only available to Dolly
                if (cdIsDoll(lmID)) 
                    optionsMenuButtons += [ "Key...", "Access..." ];

                // ----------------------------------------
                // Public... Button
                //
                // SECURITY: This button is for Dolly only, unless
                // there is a Controller. If hardcore mode, then this
                // button is not available.
                //
                // Not sure about Carrier... probably not.
                if (cdIsController(lmID)) {

#ifdef ADULT_MODE
                    if (!hardcore)
#endif
                        optionsMenuButtons += (list)"Public...";
                }

                // ----------------------------------------
                // Key-specific Menu
                //
                // NOTE: There's no telling WHAT this menu will be about, except that
                // it will be specific to the key hardware that the scripts are in.
                //
                // SECURITY: This button is limited solely to Dolly.
                if (cdIsDoll(lmID)) {
                    if (keySpecificMenu != "")
                        optionsMenuButtons += (list)keySpecificMenu;
                }

                // SECURITY: The Drop Control button is for the Controller ONLY.
                //
                if (cdIsExternalController(lmID))
                    optionsMenuButtons += "Drop Control";

                // ----------------------------------------
                // Type... and Restrictions... Button
                //
                // SECURITY: Show Type to Dolly unless Dolly has Controllers or is Carried.
                // Show to Controllers and Carriers on demand.
                //
                // SECURITY: Show Restrictions to Dolly unless Dolly has Controllers,
                // is Carried, or is in hardcore mode.
                //
                // Show Restrictions to Controllers and Carriers on demand.
                //
                if (cdIsDoll(lmID)) {
                    if (!cdCarried() && cdControllerCount() == 0) {

                        optionsMenuButtons += (list)"Type...";

                        if (rlvOk) {
#ifdef ADULT_MODE
                            if (!hardcore)
#endif
                                optionsMenuButtons += (list)"Restrictions...";
                        }
                    }
                }
                else if (cdIsExternalController(lmID) || cdIsCarrier(lmID)) {

                    optionsMenuButtons += (list)"Type...";
                    if (rlvOk) optionsMenuButtons += (list)"Restrictions...";

                }
#ifdef DEVELOPER_MODE
                else {
                    // This section should never be triggered: it means that
                    // someone who shouldn't see the Options menu did.
                    llSay(DEBUG_CHANNEL,"Someone saw the options menu who wasn't supposed to.");
                    return;
                }

                debugSay(6,"DEBUG-OPTIONS","Options menu built; presenting to " + (string)lmID);
#endif
                lmDialogListen();
                llDialog(lmID, optionsMenuMessage, dialogSort(optionsMenuButtons + "Back..."), dialogChannel);
            }
        }

        else if (code == RLV_RESET) {
            rlvOk = (integer)split[0];
        }
        else if (code == MENU_SELECTION) {
            string choice = (string)split[0];

            string optName = llGetSubString(choice, 2, STRING_END);
            string curState = cdGetFirstChar(choice);

            // Transforming options
            if ((choice == "Type...")         ||
                (optName == "Verify Type")    ||
                (optName == "Type Hovertext") ||
                (optName == "Show Phrases")
                ) {

                if (optName == "Verify Type") {
                    lmSendConfig("mustAgreeToType", (string)(mustAgreeToType = (curState == CROSS)));
                }
                else if (optName == "Show Phrases") {
                    lmSendConfig("showPhrases", (string)(showPhrases = (curState == CROSS)));
                }
                else if (optName == "Type Hovertext") {
                    lmSendConfig("typeHovertext", (string)(typeHovertext = (curState == CROSS)));
                }

                list choices;

#ifdef ADULT_MODE
                if (!hardcore)
#endif
                    choices += cdGetButton("Verify Type", lmID, mustAgreeToType, 0);

                choices += cdGetButton("Show Phrases", lmID, showPhrases, 0);
                choices += cdGetButton("Type Hovertext", lmID, typeHovertext, 0);

                lmSendConfig("backMenu",(backMenu = "Options..."));
                backMenu = MAIN;
                lmDialogListen();
                llDialog(lmID, "Options", dialogSort(choices + "Back..."), dialogChannel);
            }

            // Choose a Transformation
            else if (choice == "Types...") {

                // Doll must remain in a type for a period of time
                if (typeLockExpire) {

                    // Dolly's type cannot be changed now: build dialog and message
                    debugSay(5,"DEBUG-TYPES","Transform is currently locked");

                    string msg3 = " cannot be transformed right now, as ";
                    string msg4 = " recently transformed into a " + dollType + " doll. ";

                    if (cdIsDoll(lmID)) msg = "You " + msg3 + " you were " + msg4;
                    else msg = dollName + msg3 + " Dolly was " + msg4;

                    if (typeLockExpire - llGetUnixTime() > 0) {
                        if (cdIsDoll(lmID)) msg += "You ";
                        else msg += "Dolly ";

                        msg += " can be transformed in ";

                        i = llFloor((typeLockExpire - llGetUnixTime()) / SEC_TO_MIN);
                        if (i > 0) msg += (string)i + " minutes. ";
                        else msg += "less than a minute. ";
                    }

                    llDialog(lmID, msg, ["OK"], DISCARD_CHANNEL);
                }
                else {
                    typeDialogHandle = llListen(typeDialogChannel, NO_FILTER, dollID, NO_FILTER);

                    // Dolly can change type: not locked
                    reloadTypeNames(lmID);
                    debugSay(5,"DEBUG-TYPES","Type names reloaded");

                    msg = "These change the personality of " + dollName + "; Dolly is currently a " + dollType + " Doll. " +
                          "Dolly's clothes will be limited to those for " + pronounHerDoll + " type, and hypnotic " +
                          "phrases may be used on Dolly if permitted.";

                    // We need a new list var to be able to change the display, not the
                    // available types. These are the types based on available notecards.
                    list typeMenuChoices = typeBufferedList;
                    integer i;

                    //debugSay(6,"DEBUG-TYPES","Type Folder List (during menu build) = " + llDumpList2String(typeFolderBufferedList,","));
                    //debugSay(6,"DEBUG-TYPES","Type List (during menu build) = " + llDumpList2String(typeBufferedList,","));
                    debugSay(6,"DEBUG-TYPES","Type Menu Choices (during menu build) = " + llDumpList2String(typeMenuChoices,","));
                    //debugSay(6,"DEBUG-TYPES","Current doll type = " + dollType);

                    // Delete the current type: transforming to current type is redundant
                    if (~(i = llListFindList(typeMenuChoices, (list)dollType))) {
                        typeMenuChoices = llDeleteSubList(typeMenuChoices, i, i);
                    }

                    debugSay(6,"DEBUG-TYPES","Type menu choices = " + llDumpList2String(typeMenuChoices,","));

#define isSpecialType(a) (~llListFindList(SPECIAL_TYPES, (list)a))

                    // We don't need to add special types, as they have been added up front
                    // when typeBufferedList was created
                    //
                    string typeTemp;

                    // Now, IF there are no phrases allowed...
                    //
                    // Without phrases, then a type with no outfit directory is
                    // useless. We want to remove these from the types menu, UNLESS
                    // they are special, in which case we keep the type.
                    //
                    if (!showPhrases) {

                        // Check each menu choice and see if it has
                        // a matching directory...
                        //
                        i = llGetListLength(typeMenuChoices);

                        while (i--) {
                            typeTemp = (string)typeMenuChoices[i];
                            //debugSay(5,"DEBUG-TYPES","Type being scanned[" + (string)i + "]: " + typeTemp);

                            // If type entry is a SPECIAL_TYPE, then skip to next;
                            // Special types are kept in the menu choices, no matter what

                            if (!(isSpecialType(typeTemp))) {

                                // If (non-special) type entry is not in the type folder
                                // list, then remove from // menu list: the type will have
                                // no phrases, and no outfits - and no purpose
                                //
                                if (!(cdFindInList(typeFolderBufferedList, typeTemp))) {

                                    typeMenuChoices = llDeleteSubList(typeMenuChoices, i, i);
                                    //debugSay(5,"DEBUG-TYPES","Type removed from menu: " + typeTemp);
                                }
#ifdef DEVELOPER_MODE
                                else {
                                    debugSay(5,"DEBUG-TYPES","Folder found: " + typeTemp);
                                }
#endif
                            }
                        }
                    }

                    // Add all directories to list (including those without phrases)
                    //
                    // FIXME: Do we want to do this at creation of typeBufferedList?
                    // FIXME: Do we want this to be permanent with typeBufferedList?
                    //
                    i = llGetListLength(typeFolderBufferedList);

                    while (i--) {
                        typeTemp = (string)typeFolderBufferedList[i];

                        if (!(cdFindInList(typeMenuChoices, typeTemp))) {

                            typeMenuChoices += typeTemp;
                            debugSay(5,"DEBUG-TYPES","Type added to menu: " + typeTemp);
                        }
                    }

#ifdef DEVELOPER_MODE
                    debugSay(6,"DEBUG-TYPES","Type menu choices = " + llDumpList2String(typeMenuChoices,","));
#endif
                    // FIXME: This should not happen, but until things are fixed up, leave it in.
                    if (typeMenuChoices == []) {
                        lmDialogListen();
                        llDialog(lmID, "There are no types to choose from.", [], typeDialogChannel);
                    }
                    else {

                        if (cdIsDoll(lmID)) msg += "What type of doll do you want to be?";
                        else {
                            msg += "What type of doll do you want the Doll to be?";

#ifdef ADULT_MODE
                            if (!hardcore)
#endif
                                llOwnerSay(cdProfileURL(lmID) + " is looking at your doll types.");
                        }

                        lmSendConfig("backMenu",(backMenu = MAIN));
                        lmDialogListen();
                        llDialog(lmID, msg, dialogSort(llListSort(typeMenuChoices, 1, 1) + "Back..."), typeDialogChannel);
                    }
                }
            }

            // Transform
            else if (choice == "Transform") {
                // We get here because dolly had to confirm the change
                // of type - and chose "Transform" from the menu
                cdSayTo("Doll has accepted transformation to a " + typeToConfirm + " Doll.",lmID);
                lmSetConfig("dollType", typeToConfirm);
                lmSetConfig("typeLockExpire","1");
                typeToConfirm = "";
            }
            else if (choice == "Dont Transform") {
                cdSayTo("Doll has rejected transformation to a " + typeToConfirm + " Doll.",lmID);
                typeToConfirm = "";
            }
        }
        else if (code == TYPE_SELECTION) {
            string typeName = (string)split[0];

            debugSay(2,"DEBUG-DOLLTYPE","Changing doll type to " + typeName);

            // A Doll Type was chosen: change to it as is appropriate

            // Accessor is either:
            //    * Dolly
            //    * Controller
            //    * Other when Dolly does not have to agree
            //    * Other when Dolly is hardcore
            //
            if (cdIsDoll(lmID) || cdIsController(lmID) || !mustAgreeToType) {
                typeToConfirm = "";

                // Doll (or a Controller) chose a Type - or no confirmation needed: just do it
                lmSetConfig("dollType", typeName);
                lmSetConfig("typeLockExpire","1");
            }
            else {
                // This part is when Dolly needs to agree

                // A member of the public chose a Type and confirmation is required
                cdSayTo("Getting confirmation from Doll...",lmID);

                typeToConfirm = typeName; // save transformation Type
                list menuChoices = ["Transform", "Dont Transform", MAIN ];
                string menuMessage = "Do you wish to be transformed to a " + typeName + " Doll?";

                lmDialogListen();
                llDialog(dollID, menuMessage, dialogSort(menuChoices), dialogChannel); // this starts a new choice on this channel
            }
        }
        else if (code < 200) {
            string choice = (string)split[0];

            if (code == INIT_STAGE2) {
                configured = 1;
            }
            else if (code == INIT_STAGE3) {
                // this loads the type names buffer
                reloadTypeNames(NULL_KEY);

                // Might have been set in Prefs, so do this late
            }
            else if (code == INIT_STAGE5) {
                // This updates the doll type using setDollType()
                lmSetConfig("dollType", dollTypeExpected);

                // This clears the transformation lock
                lmSetConfig("typeLockExpire","0");
            }
#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                memReport(myName,(float)choice);
            }
#endif
            else if (code == CONFIG_REPORT) {
                cdConfigureReport();
            }
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer listenChannel, string listenName, key listenID, string listenMessage) {

        // if a @getinv call succeeds, then we are here - looking for the
        // folders we want...
        //
        if (listenChannel == outfitSearchChannel) {
            llListenRemove(outfitSearchHandle);
            outfitSearchHandle = 0;
            adjustTimer();

            debugSay(6,"DEBUG-SEARCHING","Search channel received: " + listenMessage);
            debugSay(6,"DEBUG-SEARCHING","Search channel - outfitFolder = \"" + outfitFolder + "\"");
            debugSay(6,"DEBUG-SEARCHING","Search channel - outfitFolderExpected = \"" + outfitFolderExpected + "\"");
#ifdef DEVELOPER_MODE
            if (outfitFolder != "") {

                // Once the outfitFolder has been found, no need to repeat the search
                //
                // This does mean that the key will have to be reset to use a different
                // outfit folder... but not an unreasonable expectation, given buffered items
                // and other whatnot.
                //
                llSay(DEBUG_CHANNEL,"outfit folder search called unnecessarily!");
                return;
            }
#endif

            list folderList = llCSV2List(listenMessage);
            //integer searchForTypeFolder;
            nudeFolder = "";
            normalselfFolder = "";
            normaloutfitFolder = "";

            debugSay(6,"DEBUG-SEARCHING","folderList: " + llDumpList2String(folderList,","));

            // Are we searching for something specific? Bypass defaults if so
            if (outfitFolderExpected != "") {
                if (cdFindInList(folderList, outfitFolderExpected)) outfitFolder = outfitFolderExpected;
                else llSay(DEBUG_CHANNEL,"Outfit folder \"" + outfitFolderExpected + "\" could not be found - searching for defaults");
                // else outfitFolder is unaffected - and remains unset
            }

            // Search for defaults if no outfit folder specified, but *ALSO* if search for specified folder fails
            if (outfitFolderExpected == "" || outfitFolder == "") {
                // Search for the defaults...
                debugSay(6,"DEBUG-SEARCHING","Searching for default outfit folders...");

                // vague substring check done here for speed
                if (llSubStringIndex(listenMessage,"Outfits") >= 0) {

                    // exact match check
                         if (cdFindInList(folderList, "> Outfits"))  outfitFolder = "> Outfits";
                    else if (cdFindInList(folderList, "Outfits"))    outfitFolder = "Outfits";

                }
                else if (llSubStringIndex(listenMessage,"Dressup") >= 0) {

                         if (cdFindInList(folderList, "> Dressup"))  outfitFolder = "> Dressup";
                    else if (cdFindInList(folderList, "Dressup"))    outfitFolder = "Dressup";
                }
            }

            // At this point, either the outfit folder has been set to a default, to a user-specified folder that
            // was found and used, or none of them have been found

            debugSay(6,"DEBUG-SEARCHING","outfitFolder = \"" + outfitFolder + "\"");

            // Send the outfitFolder so all will know, no matter what it is
            //lmSendConfig("outfitsFolder", outfitFolder);
            lmSendConfig("outfitFolder", outfitFolder);

            //debugSay(6,"DEBUG-SEARCHING","typeFolder = \"" + typeFolder + "\" and typeFolderExpected = \"" + typeFolderExpected + "\"");

            // Now that we have a designated outfitFolder, search for a typeFolder if needed
            //searchForTypeFolder = (typeFolder == "" && typeFolderExpected != ""); // FIXME: how do we get here?

            //if (searchForTypeFolder) {

            //    // Search for outfits folder complete; now search for Type folder
            //    typeSearch(typeSearchChannel,typeSearchHandle);
            //}

            outfitSearching = FALSE;

            // Type folder is not directly related to outfit folder searching; system folders are
            // completely inseparable
            //
            // Both system folders and type folders are loaded with this command
            //
            systemSearch(systemSearchChannel,systemSearchHandle);
        }
        else if (listenChannel == typeSearchChannel) {

            // Note that we may have gotten here *without* having run through
            // the outfits search first - due to having done the outfits search
            // much earlier... However.... if we are here, then the outfits search
            // must have run before, but not necessarily immediately before...

            // Note that, unlike the dialog channel, the type search channel is
            // removed and recreated... maybe it should not be
            llListenRemove(typeSearchHandle);
            typeSearchHandle = 0;
            adjustTimer();

            // if there is no outfits folder we mark the type folder search
            // as "failed" and don't use a type folder...
            if (outfitFolder == "") {
                typeFolder = "";
                typeFolderExpected = "";

                lmSendConfig("typeFolder", "");
                return;
            }

            debugSay(6,"DEBUG-SEARCHING","typeFolder search: looking for type folder: \"" + typeFolderExpected + "\": " + listenMessage);
            debugSay(6,"DEBUG-SEARCHING","typeFolder search: Outfits folder previously found to be \"" + outfitFolder + "\"");

            // We should NOT be here if the following statement is false.... RIGHT?
            if (typeFolderExpected != "" && typeFolder != typeFolderExpected) {
                list folderList = llCSV2List(listenMessage);

                debugSay(6,"DEBUG-SEARCHING","looking for typeFolder(Expected) = " + typeFolderExpected);
                // This comparison is inexact - but a quick check to see
                // if the typeFolderExpected is contained in the string
                if (llSubStringIndex(listenMessage,typeFolderExpected) >= 0) {

                    // This is the exact check:
                    if (cdFindInList(folderList, typeFolderExpected)) {
                        typeFolder = typeFolderExpected;
                        typeFolderExpected = "";
                    }
                    else {
                        typeFolder = "";
                        typeFolderExpected = "";
                    }

                }
                // typeFolderExpected not found at all
                else {
                    typeFolder = "";
                    typeFolderExpected = "";
                }

                lmSendConfig("typeFolder", typeFolder);
            }
        }
        else if (listenChannel == systemSearchChannel) {
            llListenRemove(systemSearchHandle);
            systemSearchHandle = 0;
            adjustTimer();

            list folderList = llCSV2List(listenMessage);

            //outfitSearching = FALSE;
            nudeFolder = "";
            normalselfFolder = "";
            normaloutfitFolder = "";

            // Check for ~nude and ~normalself in the same level as the typeFolder
            //
            // This suggests that normalselfFolder and nudeFolder are "set-once" variables - which seems logical.
            // It also means that any ~nudeFolder and/or ~normalselfFolder found along side the Outfits folder
            // will override any inside of the same

            if (cdFindInList(folderList, "~nude")) nudeFolder = outfitFolder + "/~nude";
            else {
                llOwnerSay("WARN: No nude (~nude) folder found in your outfits folder (\"" + outfitFolder + "\")...");
            }

            if (cdFindInList(folderList, "~normalself")) normalselfFolder = outfitFolder + "/~normalself";
            else {
                llOwnerSay("ERROR: No normal self (~normalself) folder found in your outfits folder (\"" + outfitFolder + "\")... this folder is necessary for proper operation");
                llSay(DEBUG_CHANNEL,"No ~normalself folder found in \"" + outfitFolder + "\": this folder is required for proper Key operation");
            }

            if (cdFindInList(folderList, "~normaloutfit")) normaloutfitFolder = outfitFolder + "/~normaloutfit";
            else {
                llOwnerSay("WARN: No normaloutfit (~normaloutfit) folder found in your outfits folder (\"" + outfitFolder + "\")...");
            }

            lmSendConfig("nudeFolder",nudeFolder);
            lmSendConfig("normalselfFolder",normalselfFolder);
            lmSendConfig("normaloutfitFolder",normaloutfitFolder);

            // Check for Type Folders and store in buffered list
            //
            integer index;
            index = llGetListLength(folderList);
            while (index--) {
                if (cdGetFirstChar((string)folderList[index]) == TYPE_FLAG) {
                    typeFolderBufferedList += cdButFirstChar((string)folderList[index]);
                }
            }

            debugSay(6,"DEBUG-TYPES","Type Folder List = " + llDumpList2String(typeFolderBufferedList,","));

            llSleep(1.0);
            lmInitStage(INIT_STAGE4); // Outfits and System folder search succeeded: continue
        }
        else if (listenChannel == typeDialogChannel) {

            llListenRemove(typeDialogHandle);

            if (listenMessage == "Back...") {
                lmMenuReply(backMenu = MAIN,llGetDisplayName(listenID),listenID);
            }
            // FIXME: listenMessage should never equal "OK" - no types - but we check for it anyway
            else if (listenMessage != "OK") {
                string typeName = listenMessage;

                cdSayTo("Dolly's internal mechanisms engage, and a transformation comes over Dolly, making " + pronounHerDoll + " into a " + listenMessage + " Dolly",listenID);
                lmTypeChange(typeName, llGetDisplayName(listenID), listenID); // this performs type switch
            }
        }
        else if (listenChannel == typeFolderBufferChannel) {
            llListenRemove(typeFolderBufferHandle);
            list folderList = llCSV2List(listenMessage);
            integer i;

            debugSay(6,"DEBUG-OPTIONS","folderList: " + llDumpList2String(folderList,","));
            typeFolderBufferedList = [];

            i = llGetListLength(folderList);
            while (i--) {
                if (isTypeFolder((string)folderList[i]))
                    typeFolderBufferedList += (string)folderList[i];
            }

            debugSay(6,"DEBUG-OPTIONS","typeFolderBufferedList: " + llDumpList2String(typeFolderBufferedList,","));
        }
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key queryID, string queryData)  {

        if (queryID == typeNotecardQuery) {
            if (queryData == EOF) {
                phraseCount = llGetListLength(currentPhrases);
                llOwnerSay("Load of hypnotic device complete: " + (string)phraseCount + " phrases in memory");
                typeNotecardQuery = NULL_KEY;
                readLine = 0;
            }
            else {
                // This is the real meat: currentPhrases is built up
                if (llStringLength(queryData) > 1) currentPhrases += queryData;

                // Read next line
                typeNotecardQuery = llGetNotecardLine(typeNotecard,readLine++);
            }
        }
    }
}

//========== TRANSFORM ==========
