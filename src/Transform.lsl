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

// Transformation (locked) time in seconds
#define TRANSFORM_LOCK_TIME 300

// Script Control
#define RUNNING 1
#define NOT_RUNNING 0
#define cdRunScript(a) llSetScriptState(a, RUNNING);
#define cdStopScript(a) llSetScriptState(a, NOT_RUNNING);
#define getInv(a,b) \
    if (a == "") lmRunRLV("getinv=" + (string)(b)); \
    else lmRunRLV("getinv:" + a + "=" + (string)(b))

#define isFound(a) (a!="")
#define isNotFound(a) (a=="")

// Note that these two values are used by ALL searches...
#define MAX_SEARCH_RETRIES 2
#define RLV_TIMEOUT 15.0

#define adjustTimer() \
    if (lowScriptMode) llSetTimerEvent(LOW_RATE);\
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
key transformerID;
integer readLine;
integer readingNC;
string typeNotecard;
integer timerMark;

#ifdef DEVELOPER_MODE
integer lastTimerMark;
#endif

integer outfitSearching;
integer outfitSearchTries;
integer typeSearchTries;
integer systemSearchTries;

integer findTypeFolder;

integer useTypeFolder;
string transform;

// These dual variables allow us to separate the actual valid typeFolder
// from the one being searched for
string typeFolder; // Valid and current typeFolder
string typeFolderExpected; // typeFolder being searched for

// And dual variables for outfit too, just like type - except these only
// get used if the preferences file has an entry in it
string outfitFolder;
string outfitFolderExpected;

// And dual variables for dollType too, just like type - except these only
// get used if the preferences file has an entry in it
//string dollType;
string dollTypeExpected;

integer rlvChannel;
integer typeSearchHandle;
integer typeSearchChannel;
integer outfitSearchHandle;
integer outfitSearchChannel;
integer systemSearchHandle;
integer systemSearchChannel;

integer typeDialogChannel;

integer transformLockExpire;

integer dbConfig;
integer mustAgreeToType;

key kQuery;

list currentPhrases;

//========================================
// FUNCTIONS
//========================================

setDollType(string typeName) {
    // Convert state name to Title case
    //typeName = cdGetFirstChar(llToUpper(typeName)) + cdButFirstChar(llToLower(typeName));

    reloadTypeNames(NULL_KEY);
    if (llListFindList(typeBufferedList, (list)typeName) == NOT_FOUND) {
      llSay(DEBUG_CHANNEL,"Invalid Doll Type specified!");
      return;
    }

    if (typeName == "") typeName = "Regular";

#ifdef DEVELOPER_MODE
    debugSay(2,"DEBUG-DOLLTYPE","Changing dolltype to type '" + typeName + "' from '" + dollType + "'");
#endif

    // By not aborting, selecting the same state can cause a "refresh" ...
    // though our menus do not currently allow this
    currentPhrases = [];
    readLine = 0;
    typeNotecard = TYPE_FLAG + typeName;
    typeFolderExpected = TYPE_FLAG + typeName;

    // Look for Notecard for the Doll Type and start reading it if showPhrases is enabled
    //
    if (showPhrases) {
        if (llGetInventoryType(typeNotecard) == INVENTORY_NOTECARD) {

            kQuery = llGetNotecardLine(typeNotecard,readLine++);

            debugSay(2,"DEBUG-DOLLTYPE","Found notecard: " + typeNotecard);
        }
    }

    // This propogates dollType value to the rest of the system
    lmSendConfig("dollType", (dollType = typeName));
    llOwnerSay("You have become a " + dollType + " Doll.");

    // Now search for a Type folder for Dolly and set it
    typeFolder = "";
    outfitSearchTries = 0;
    typeSearchTries = 0;

    // Only search for a type folder - outfit folder - if RLV is active
    if (RLVok == TRUE) {
        debugSay(4,"DEBUG-DOLLTYPE","Searching for " + typeFolderExpected);

        typeSearchHandle = cdListenMine(typeSearchChannel);

        // Search for type folder
        typeSearch(typeSearchChannel,typeSearchHandle);
    }

    lmInternalCommand("setWindRate","",NULL_KEY); // runs in Main
    debugSay(2,"DEBUG-DOLLTYPE","Changed to type " + dollType);
}

reloadTypeNames(key id) {
    string typeName;

    integer n = llGetInventoryNumber(INVENTORY_NOTECARD);

    if (n == 0) {
        llOwnerSay("No types found.");
        return;
    }

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

        //We don't need a Notecard to be present for these to be active
        //
        // Note the following rules of the built-in types:
        //   - Display: Notecard is ok but not needed
        //   - Slut: rejects type even if Notecard is present if not ADULT, else Notecard ok but not needed
        //
        if (llListFindList(typeBufferedList, (list)"Display") == NOT_FOUND) typeBufferedList += [ "Display" ];
#ifdef ADULT_MODE
        // This makes the process location-dependent...
        if (simRating == "MATURE" || simRating == "ADULT")
            if (llListFindList(typeBufferedList, (list)"Slut") == NOT_FOUND) typeBufferedList += [ "Slut" ];
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
    outfitSearching = TRUE;

    debugSay(6,"DEBUG-SEARCHING","outfitSearch in progress (RLVok = " + (string)RLVok + ")");

    folderSearch(channel,handle);
}

//========================================
// STATES
//========================================
default {
    state_entry() {
        dollID =   llGetOwner();
        keyID =   llGetKey();
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
    //
    // Timer is used when:
    //    - Searching for RLV, and it times out
    //    - Transform lock is active
    //    - Homing device is active
    //    - Phrases are being used
    //
    // These are all affected by lowScriptMode which reduces
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
        // outfitFolder = Top Level folder that contains all outfits (e.g., "> Outfits")
        // typeFolder = Folder related to current Doll Type (e.g., "*Japanese")
        // typeFolderExpected = Computed but untested typeFolder

#ifdef DEVELOPER_MODE
        if (timeReporting) {
            string s;

            if (lastTimerMark > 0) {
                s = "Transform Timer fired, interval " + formatFloat(timerMark - lastTimerMark,2) + "s";
                if (lowScriptMode) s += " (lowScriptMode enabled)";
                s += ".";

                debugSay(5,"DEBUG-TRANSFORM",s);
            }

            lastTimerMark = timerMark;
        }
#endif
        //----------------------------------------
        // TRANSFORM LOCK
        //
        if (transformLockExpire) {
            if (transformLockExpire  <= timerMark) {
                lmSetConfig("transformLockExpire",(string)(transformLockExpire = 0));
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
                    if (llGetInventoryType(LANDMARK_HOME) == INVENTORY_LANDMARK)
                        lmInternalCommand("teleport", LANDMARK_HOME, id); // runs in Avatar
            }
        }
#endif
        //----------------------------------------
        // OUTFIT SEARCH: RLV TIMEOUTS
        //
        if (RLVok == TRUE) {
            // If RLVok is true, then check if outfit searches need to be retried...
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

                    llSay(DEBUG_CHANNEL,"Outfit search FAILED. No outfits or types are available.");
                    adjustTimer();
                    lmInitState(INIT_STAGE4); // start next phase
                }
            }
            else if (typeSearchHandle) {
                if (typeSearchTries++ < MAX_SEARCH_RETRIES) {

                    // Try another search for Type directories
                    typeSearch(typeSearchChannel,typeSearchHandle);

                }
                else {
                    llListenRemove(typeSearchHandle);

                    typeFolder = "";
                    typeFolderExpected = "";

                    llSay(DEBUG_CHANNEL,"Type search FAILED. No types are available.");
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

                    llSay(DEBUG_CHANNEL,"Outfit search FAILED. No system folders were found.");
                    adjustTimer();
                    lmInitState(INIT_STAGE4); // start next phase
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

        //----------------------------------------
        // ADJUST NEXT TIMER INTERVAL
        //
        //if (lowScriptMode) llSetTimerEvent(LOW_RATE);
        //else llSetTimerEvent(STD_RATE);
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

        // This means that ANY link message sent by Transform is ignored by these
        // items, except for the SET_CONFIG section...
        //
        // Link messages sent by other scripts are not ignored in the slightest..
        //
        // This script uses SEND_CONFIG extensively, plus a couple RLV calls and
        // internal commands. Ignoring SEND_CONFIG is probably wise, but the
        // rest is likely overkill, though not problematic in practice.
        //
        if (script == "Transform" && code != SET_CONFIG) return;

        if (code == SEND_CONFIG) {

            string name = cdListElement(split, 0);
            string value = cdListElement(split, 1);

            split = llDeleteSubList(split,0,0);

                 if (name == "collapsed")                   collapsed = (integer)value;
            //else if (name == "isAFK")                       isAFK = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "timeReporting")           timeReporting = (integer)value;
            else if (name == "debugLevel")                 debugLevel = (integer)value;
#endif
            else if (name == "lowScriptMode")           lowScriptMode = (integer)value;
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
            else if (name == "RLVok")                           RLVok = (integer)value;
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

                rlvChannel = ~dialogChannel + 1;
                typeDialogChannel = dialogChannel - TYPE_CHANNEL_OFFSET;

                typeSearchChannel = rlvChannel + 1;
                outfitSearchChannel = rlvChannel + 2;
                systemSearchChannel = rlvChannel + 3;
            }
        }

        else if (code == SET_CONFIG) {

            string name = cdListElement(split, 0);
            string value = cdListElement(split, 1);

            debugSay(6,"DEBUG-TRANSFORM","SET_CONFIG[" + name + "] = " + value);
            if (name == "dollType") {
                if (value != dollType) {
                    dollTypeExpected = value;

                    // Here, this conditional allows us to "set" dollTypeExpected, but defer the actual
                    // setting until stage 5 below.
                    if (outfitSearchComplete) setDollType(value);
                }
            }
            else if (name == "transformLockExpire") {
                if (value == "0") transformLockExpire = 0;
                else transformLockExpire = llGetUnixTime() + TRANSFORM_LOCK_TIME;
                lmSendConfig("transformLockExpire",(string)(transformLockExpire));
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
                list pluslist;
                lmSendConfig("backMenu",(backMenu = MAIN));
                debugSay(6,"DEBUG-OPTIONS","Building Options menu...");
                debugSay(6,"DEBUG-OPTIONS","isDoll = " + (string)cdIsDoll(id));
                debugSay(6,"DEBUG-OPTIONS","isCarrier = " + (string)cdIsCarrier(id));
                debugSay(6,"DEBUG-OPTIONS","isUserController = " + (string)cdIsUserController(id));

                if (cdIsDoll(id)) {
                    msg = "See the help file for information on these options.";
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

                    msg = "See the help file for more information on these options. Choose what you want to happen.";

                    pluslist += [ "Type...", "Access..." ];
                    if (RLVok == TRUE) pluslist += [ "Restrictions..." ];
                    pluslist += [ "Drop Control" ];

                }
                // This section should never be triggered: it means that
                // someone who shouldn't see the Options menu did.
                else return;

                debugSay(6,"DEBUG-OPTIONS","Options menu built; presenting to " + (string)id);
                cdDialogListen();
                llDialog(id, msg, dialogSort(pluslist + "Back..."), dialogChannel);
            }
        }

        else if (code == RLV_RESET) {
            RLVok = (integer)choice;
#ifdef NOT_USED
//          if (dollType == "") {
//              lmSetConfig("dollType", "Regular");
//              lmSetConfig("transformLockExpire","0");
//              llSay(DEBUG_CHANNEL,"RLV_RESET: dollType had to be fixed from blank");
//          }

            outfitFolder = "";
            typeFolder = "";
            outfitSearchTries = 0;
            typeSearchTries = 0;
            changeOutfit = 1;

            if (RLVok == TRUE) {
                if (rlvChannel) {
                    typeSearchHandle = cdListenMine(typeSearchChannel);
                    outfitSearchHandle = cdListenMine(outfitSearchChannel);

                    if (outfitFolder == "" && !outfitSearching) {
                        // No outfit folder: let's search.

                        debugSay(2,"DEBUG-RLVOK","Searching for Outfits and Typefolders");

                        outfitSearching = TRUE;
                        outfitFolder = "";
                        typeFolder = "";
                        useTypeFolder = 0;
                        typeSearchTries = 0;
                        outfitSearchTries = 0;

                        // Initial search to set global variables up
                        outfitSearch(outfitSearchChannel,outfitSearchHandle);
                    }
                }
            }
#endif
        }
        else if (code == MENU_SELECTION) {
            string optName = llGetSubString(choice, 2, STRING_END);
            string curState = cdGetFirstChar(choice);

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

                // Doll must remain in a type for a period of time
                if (transformLockExpire) {
                    debugSay(5,"DEBUG-TYPES","Transform is currently locked");

                    if (cdIsDoll(id)) msg = "You " + msg3 + " you were " + msg4;
                    else msg = dollName + msg3 + " Dolly was " + msg4;

                    if (transformLockExpire - llGetUnixTime() > 0) {
                        if (cdIsDoll(id)) msg += "You ";
                        else msg += "Dolly ";

                        msg += " can be transformed in ";

                        i = llFloor((transformLockExpire - llGetUnixTime()) / SEC_TO_MIN);
                        if (i > 0) msg += (string)i + " minutes. ";
                        else msg += "less than a minute. ";
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
                    list typeMenuChoices = typeBufferedList;

                    // Delete the current type: transforming to current type is redundant
                    if ((i = llListFindList(typeMenuChoices, (list)dollType)) != NOT_FOUND) {
                        typeMenuChoices = llDeleteSubList(typeMenuChoices, i, i);
                    }

                    if (cdIsDoll(id)) msg += "What type of doll do you want to be?";
                    else {
                        msg += "What type of doll do you want the Doll to be?";

                        if (!hardcore)
                            llOwnerSay(cdProfileURL(id) + " is looking at your doll types.");
                    }

                    lmSendConfig("backMenu",(backMenu = MAIN));
                    cdDialogListen();
                    llDialog(id, msg, dialogSort(llListSort(typeMenuChoices, 1, 1) + "Back..."), typeDialogChannel);
                }
            }

            // Transform
            else if (choice == "Transform") {
                // We get here because dolly had to confirm the change
                // of type - and chose "Transform" from the menu
                lmSetConfig("dollType", transform);
                lmSetConfig("transformLockExpire","1");
                transform = "";
            }
        }
        else if (code == TYPE_SELECTION) {
            debugSay(2,"DEBUG-DOLLTYPE","Changing doll type to " + choice);

            // A Doll Type was chosen: change to it as is appropriate

            // Accessor is either:
            //    * Dolly
            //    * Controller
            //    * Other when Dolly does not have to agree
            //    * Other when Dolly is hardcore
            //
            if (cdIsDoll(id) || cdIsController(id) || !mustAgreeToType || hardcore) {
                transform = "";

                // Doll (or a Controller) chose a Type - or no confirmation needed: just do it
                lmSetConfig("dollType", choice);
                lmSetConfig("transformLockExpire","1");
            }
            else {
                // This part is when Dolly needs to agree

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
                lmSetConfig("transformLockExpire","0");
            }
#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                memReport(cdMyScriptName(),(float)choice);
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
    listen(integer channel, string name, key id, string choice) {

        // if a @getinv call succeeds, then we are here - looking for the
        // folders we want...
        //
        if (channel == outfitSearchChannel) {
            llListenRemove(outfitSearchHandle);
            adjustTimer();

            debugSay(6,"DEBUG-SEARCHING","Search channel received: " + choice);
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

            list folderList = llCSV2List(choice);
            //integer searchForTypeFolder;
            nudeFolder = "";
            normalselfFolder = "";
            normaloutfitFolder = "";

            debugSay(6,"DEBUG-SEARCHING","folderList: " + llDumpList2String(folderList,","));

            // Are we searching for something specific? Bypass defaults if so
            if (outfitFolderExpected != "") {
                if (~llListFindList(folderList, (list)outfitFolderExpected))  outfitFolder = outfitFolderExpected;
                else llSay(DEBUG_CHANNEL,"Outfit folder \"" + outfitFolderExpected + "\" could not be found - searching for defaults");
                // else outfitFolder is unaffected - and remains unset
            }

            // Search for defaults if no outfit folder specified, but *ALSO* if search for specified folder fails
            if (outfitFolderExpected == "" || outfitFolder == "") {
                // Search for the defaults...
                debugSay(6,"DEBUG-SEARCHING","Searching for default outfit folders...");

                // vague substring check done here for speed
                if (llSubStringIndex(choice,"Outfits") >= 0) {

                    // exact match check
                         if (~llListFindList(folderList, (list)"> Outfits"))  outfitFolder = "> Outfits";
                    else if (~llListFindList(folderList, (list)"Outfits"))    outfitFolder = "Outfits";

                }
                else if (llSubStringIndex(choice,"Dressup") >= 0) {

                         if (~llListFindList(folderList, (list)"> Dressup"))  outfitFolder = "> Dressup";
                    else if (~llListFindList(folderList, (list)"Dressup"))    outfitFolder = "Dressup";
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
            systemSearch(systemSearchChannel,systemSearchHandle);
        }
        else if (channel == typeSearchChannel) {

            // Note that we may have gotten here *without* having run through
            // the outfits search first - due to having done the outfits search
            // much earlier... However.... if we are here, then the outfits search
            // must have run before, but not necessarily immediately before...

            // Note that, unlike the dialog channel, the type search channel is
            // removed and recreated... maybe it should not be
            llListenRemove(typeSearchHandle);
            adjustTimer();

            // if there is no outfits folder we mark the type folder search
            // as "failed" and don't use a type folder...
            if (outfitFolder == "") {
                useTypeFolder = NO;
                typeFolder = "";
                typeFolderExpected = "";

                //lmSendConfig("outfitsFolder", outfitFolder);
                //lmSendConfig("outfitFolder", outfitFolder);
                lmSendConfig("useTypeFolder", "0");
                lmSendConfig("typeFolder", "");
                return;
            }

            debugSay(6,"DEBUG-SEARCHING","typeFolder search: looking for type folder: \"" + typeFolderExpected + "\": " + choice);
            debugSay(6,"DEBUG-SEARCHING","typeFolder search: Outfits folder previously found to be \"" + outfitFolder + "\"");

            // We should NOT be here if the following statement is false.... RIGHT?
            if (typeFolderExpected != "" && typeFolder != typeFolderExpected) {
                list folderList = llCSV2List(choice);

                debugSay(6,"DEBUG-SEARCHING","looking for typeFolder(Expected) = " + typeFolderExpected);
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

                //lmSendConfig("outfitsFolder", outfitFolder);
                //lmSendConfig("outfitFolder", outfitFolder);
                lmSendConfig("useTypeFolder", (string)useTypeFolder);
                lmSendConfig("typeFolder", typeFolder);

#ifdef NOT_USED
                // at this point we've either found the typeFolder or not,
                // and the outfitFolder is set

                // are we doing the initial complete search? or is this just
                // a type change?
                if (outfitSearching) {

                    debugSay(6,"DEBUG-SEARCHING","Ending an outfit Search...");

                    // we finished our outfit search: so end the search and put out results
                    outfitSearching = FALSE;
                    nudeFolder = "";
                    normalselfFolder = "";

                    // Check for ~nude and ~normalself in the same level as the typeFolder
                    //
                    // This suggests that normalselfFolder and nudeFolder are "set-once" variables - which seems logical.
                    // It also means that any ~nudeFolder and/or ~normalselfFolder found along side the Outfits folder
                    // will override any inside of the same

                    if (~llListFindList(folderList, (list)"~nude")) nudeFolder = outfitFolder + "/~nude";
                    else {
                        llOwnerSay("WARN: No nude (~nude) folder found in your outfits folder (\"" + outfitFolder + "\")...");
                        llSay(DEBUG_CHANNEL,"No ~nude folder found in \"" + outfitFolder + "\"");
                    }

                    if (~llListFindList(folderList, (list)"~normalself")) normalselfFolder = outfitFolder + "/~normalself";
                    else {
                        llOwnerSay("ERROR: No normal self (~normalself) folder found in your outfits folder (\"" + outfitFolder + "\")... this folder is necessary for proper operation");
                        llSay(DEBUG_CHANNEL,"No ~normalself folder found in \"" + outfitFolder + "\": this folder is required for proper Key operation");
                    }

                    if (~llListFindList(folderList, (list)"~normaloutfit")) normaloutfitFolder = outfitFolder + "/~normaloutfit";
                    else {
                        llOwnerSay("ERROR: No normal self (~normaloutfit) folder found in your outfits folder (\"" + outfitFolder + "\")... this folder is necessary for proper operation");
                        llSay(DEBUG_CHANNEL,"No ~normaloutfit folder found in \"" + outfitFolder + "\": this folder is required for proper Key operation");
                    }

                    lmSendConfig("nudeFolder",nudeFolder);
                    lmSendConfig("normalselfFolder",normalselfFolder);
                    lmSendConfig("normaloutfitFolder",normaloutfitFolder);
                }
#endif
            }
        }
        else if (channel == systemSearchChannel) {
            list folderList = llCSV2List(choice);
            lmInitState(INIT_STAGE4); // start next phase

            //outfitSearching = FALSE;
            nudeFolder = "";
            normalselfFolder = "";
            normaloutfitFolder = "";

            // Check for ~nude and ~normalself in the same level as the typeFolder
            //
            // This suggests that normalselfFolder and nudeFolder are "set-once" variables - which seems logical.
            // It also means that any ~nudeFolder and/or ~normalselfFolder found along side the Outfits folder
            // will override any inside of the same

            if (~llListFindList(folderList, (list)"~nude")) nudeFolder = outfitFolder + "/~nude";
            else {
                llOwnerSay("WARN: No nude (~nude) folder found in your outfits folder (\"" + outfitFolder + "\")...");
            }

            if (~llListFindList(folderList, (list)"~normalself")) normalselfFolder = outfitFolder + "/~normalself";
            else {
                llOwnerSay("ERROR: No normal self (~normalself) folder found in your outfits folder (\"" + outfitFolder + "\")... this folder is necessary for proper operation");
                llSay(DEBUG_CHANNEL,"No ~normalself folder found in \"" + outfitFolder + "\": this folder is required for proper Key operation");
            }

            if (~llListFindList(folderList, (list)"~normaloutfit")) normaloutfitFolder = outfitFolder + "/~normaloutfit";
            else {
                llOwnerSay("WARN: No normaloutfit (~normaloutfit) folder found in your outfits folder (\"" + outfitFolder + "\")...");
            }

            lmSendConfig("nudeFolder",nudeFolder);
            lmSendConfig("normalselfFolder",normalselfFolder);
            lmSendConfig("normaloutfitFolder",normaloutfitFolder);
            llSleep(1.0);
            lmInitState(INIT_STAGE4); // start next phase
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
