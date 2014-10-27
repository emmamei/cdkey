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

#define cdProfileURL(i) "secondlife:///app/agent/"+(string)(i)+"/about"
#define cdStringEndMatch(a,b) llGetSubString(a,-llStringLength(b),STRING_END)==b

// Channel to use to discard dialog output
#define DISCARD_CHANNEL 9999

// Transformation (locked) time in minutes
#define TRANSFORM_LOCK_TIME 5
#define cdTransformLocked() (minMinutes > 0)

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
string dollName;
string stateName;
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

integer rlvHandle;
integer rlvHandle2;
integer rlvHandle3;
integer useTypeFolder;
integer transformedViaMenu;
string transform;
string typeFolder;

integer dialogChannel;
integer rlvChannel;
integer rlvChannel2;
integer rlvChannel3;

integer minMinutes;
integer configured;
integer RLVok;

//integer startup = 1;

//integer menulimit = 9;     // 1.5 minute

string currentState;
integer dbConfig;
integer mustAgreeToType;
integer showPhrases;
#ifdef WEAR_AT_LOGIN
integer wearAtLogin;
#endif
//integer isTransformingKey;
key dollID;
string typeFolderExpected;

key kQuery;

list currentPhrases;

integer quiet;

//========================================
// FUNCTIONS
//========================================

#define AUTOMATED 1
#define NOT_AUTOMATED 0

setDollType(string choice, integer automated) {
    if (choice == "Transform") stateName = transform;
    else stateName = choice;

    // Convert state name to Title case
    stateName = cdGetFirstChar(llToUpper(stateName)) + cdButFirstChar(llToLower(stateName));
    if (stateName == currentState)
        return;

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
#ifdef DEVELOPER_MODE
        else {
            debugSay(2,"DEBUG-DOLLTYPE","Found no notecard - looked for " + typeNotecard);
        }
#endif
    }

    // Dont lock if transformation is automated
    if (automated) minMinutes = 0;
    else minMinutes = TRANSFORM_LOCK_TIME;

    currentState = stateName;
    lmSendConfig("dollType", stateName);

    cdPause();

    if (!quiet) cdChat(dollName + " has become a " + stateName + " Doll.");
    else llOwnerSay("You have become a " + stateName + " Doll.");

    // This is being done too early...
    //if (!RLVok) { lmSendToAgentPlusDoll("Because RLV is disabled, Dolly does not have the capability to change outfit.",transformerId); };

    typeFolder = "";
    outfitSearchTries = 0;
    typeSearchTries = 0;

    // if RLV is non-functional, dont search for a Type Folder
    if (RLVok) {
        debugSay(2,"DEBUG-DOLLTYPE","Searching for " + typeFolderExpected);
        outfitsSearchTimer = llGetTime();
        folderSearch(outfitsFolder,rlvChannel2);
    }
    // if NOT RLVok then we have a DollType with no associated typeFolder...
}

reloadTypeNames() {
    string typeName;

    integer n = llGetInventoryNumber(INVENTORY_NOTECARD);
    types = [];

    while(n) {
        typeName = llGetInventoryName(INVENTORY_NOTECARD, --n);

        if (cdGetFirstChar(typeName) == TYPE_FLAG) {
            types += cdButFirstChar(typeName);
        }
    }
}

runTimedTriggers() {
    // transform lock: decrease count
    if (minMinutes > 0) minMinutes--;
    else minMinutes = 0; // bulletproofing

    // No phrases to choose from
    integer phraseCount = llGetListLength(currentPhrases);
    if (phraseCount == 0) return;

    if (showPhrases) {
        string msg;

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
                if (currentState  == "Domme") msg = "*** You like to ";
                else msg = "*** feel how people like you to ";
            }
        } else msg = "*** ";

        msg += phrase;

        // Phrase has been chosen and put together; now say it
        llOwnerSay(msg);
    }
}

folderSearch(string folder, integer channel) {

    debugSay(2,"DEBUG-FOLDERSEARCH","folderSearch: Searching within \"" + folder + "\"");

    // The folder search starts as a RLV @getinv call...
    //
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
        stateName = "Regular";

        cdInitializeSeq();

#ifdef WAKESCRIPT
        // Stop myself: stop this script from running
        cdStopScript(cdMyScriptName());
#endif
        debugSay(2,"DEBUG-TRANSFORM","Done with state_entry...");
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer iParam) {
        //dbConfig = 0;
        //startup = 2;
        debugSay(2,"DEBUG-TRANSFORM","Done with on_rez...");
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & CHANGED_ALLOWED_DROP)
            reloadTypeNames();

        // if CHANGED_INVENTORY
        //    then Start.lsl will be Resetting the Key
        //    thus: ignore and wait for reset
        //
        //if (change & CHANGED_INVENTORY)
        //    reloadTypeNames();
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

        if (RLVok) {
            debugSay(2,"DEBUG-SEARCHING","Timer tripped at " + formatFloat(llGetTime() - outfitsSearchTimer,1) + "s");
            if (outfitSearching == 0)
                llSetTimerEvent(0.0);
            else {
                if (outfitsFolder == "") {
                    if (outfitSearchTries++ < MAX_SEARCH_RETRIES)
                        folderSearch("",rlvChannel3);
                } else {
                    if (typeFolder == "" && typeFolderExpected != "") {
                        if (typeSearchTries++ < MAX_SEARCH_RETRIES)
                            folderSearch(outfitsFolder,rlvChannel2);
                    }
                }
            }
        }
        else if (showPhrases) {
            debugSay(5,"DEBUG-TRANSFORM","Stopping timer");
            // Phrases are being shown...
            cdStopTimer();
        }
#ifdef WAKESCRIPT
        else {
            // If no phrases are being shown, then stop script: no need to keep running
            if ((menuTime + 60.0) < llGetTime()) cdStopScript(cdMyScriptName());
        }
#endif
    }

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

        string choice = cdListElement(split, 0);
        string name = cdListElement(split, 1);
        transformerId = id;

#ifdef DEVELOPER_MODE
        // If greater than 4, print Link Messages other than "heartbeat" Link Messages
        // If greater than 6, print everything

        if (debugLevel > 4) {
            if (debugLevel < 6) {
                if (code == 700) return;
                //if (choice == "keyHandler" || choice == "getTimeUpdates" || choice == "timeLeftOnKey") return;
            }

            string s = "Transform Link Msg:" + script + ":" + (string)code + ":choice/name";
            string t = choice + "/" + name;

            if (id != NULL_KEY) debugSay(5,"DEBUG-LINK",s + "/id = " + t + "/" + (string)id);
            else debugSay(5,"DEBUG-LINK",s + " = " + t);
        }
#endif
        scaleMem();

        // First, dump those we don''t want... (but occur frequently!)
        if (code == 700) return;

        //else if (code == 136) return;
        //else if (code == 150) return;
        //else if (code == 315) return;
        //else if (code == 11) return;

        else if (code == 102) {
            // FIXME: Is this relevant?
            // Trigger Transforming Key setting
            // if (!isTransformingKey) lmSendConfig("isTransformingKey", (string)(isTransformingKey = 1));
            // lmSendConfig("isTransformingKey", (string)(isTransformingKey = 1));

            configured = 1;
            //if (stateName != currentState) setDollType(stateName, AUTOMATED);
        }

        else if (code == 104) {
            if (script == "Start") {
                reloadTypeNames();
                //-- startup = 1;
                llSetTimerEvent(60.0);   // every minute
            }
        }

        //else if (code == 105) {
        //    if (script != "Start") return;
        //}

        else if (code == 110) {
            //initState = 105;
            setDollType(stateName, AUTOMATED);
            //startup = 0;
            ;
        }

        else if (code == 135) {
            float delay = (float)choice;
            memReport(cdMyScriptName(),delay);
        }
        else

        cdConfigReport(); // FIXME: this "code" is invalid

        else if (code == 300) {
            string value = name;
            string name = choice;

            if (script != cdMyScriptName()) {
                     if (name == "timeLeftOnKey") runTimedTriggers();
#ifdef KEY_HANDLER
                else if (name == "keyHandler") return;
#endif
                else if (name == "quiet")                                          quiet = (integer)value;
                else if (name == "mustAgreeToType")                      mustAgreeToType = (integer)value;
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
                else if (name == "stateName")                                  stateName = value;
                else if ((name == "RLVok") || (name == "dialogChannel")) {

                    if (name == "RLVok") RLVok = (integer)value;
                    else if (name == "dialogChannel") {
                        dialogChannel = (integer)value;
                        rlvChannel = ~dialogChannel + 1;
                        rlvChannel2 = rlvChannel + 1;
                        rlvChannel3 = rlvChannel + 2;
                    }


                    // If RLV is ok AND rlvChannel is set... then reset
                    // the rlvChannel and search for OutfitsFolder

                    if (RLVok) {
                        if (rlvChannel) {
                            //
                            // Now we have a result of RLV checks - and if it is Ok,
                            // startup the RLV channels and search for folders
                            //
                            if (!rlvHandle) llListenRemove(rlvHandle);
                            rlvHandle = cdListenAll(rlvChannel);
                            if (!rlvHandle2) llListenRemove(rlvHandle2);
                            rlvHandle2 = cdListenAll(rlvChannel2);
                            if (!rlvHandle3) llListenRemove(rlvHandle3);
                            rlvHandle3 = cdListenAll(rlvChannel3);

                            if (outfitsFolder == "" && !outfitSearching) {
                                outfitSearching++;

                                if (outfitSearching < 2) {
                                    debugSay(2,"DEBUG-RLVOK","Searching for Outfits and Typefolders");
                                    outfitsFolder = "";
                                    typeFolder = "";
                                    useTypeFolder = 0;
                                    typeSearchTries = 0;
                                    outfitSearchTries = 0;

                                    outfitsSearchTimer = llGetTime();
                                    folderSearch(outfitsFolder,rlvChannel3);
                                }
                            }
                        }
                    }
                }
#ifdef DEVELOPER_MODE
                else if (name == "debugLevel") {
                                                                              debugLevel = (integer)value;
                }
#endif

                else if (name == "dollType") {
                    stateName = value;
                    // this only runs if some other script sets the Type, not this one
                    if (configured) setDollType(stateName, AUTOMATED);
                }
            }
        }

        else if (code == 305) {
#ifdef WAKESCRIPT
            if (choice == "wakeScript") {
                // This is a call to ServiceReceiver.lsl
                if (name == cdMyScriptName()) cdLinkMessage(LINK_THIS, 0, 303, "debugLevel|dialogChannel|dollType|quiet|mustAgreeToType|RLVok|showPhrases|wearAtLogin", llGetKey());
            }
#endif
            ;
        }

        else if (code == 350) {
            RLVok = ((integer)choice == 1);

            outfitsFolder = "";
            typeFolder = "";
            outfitSearchTries = 0;
            typeSearchTries = 0;

            if (RLVok) {
                if (rlvChannel) {
                    if (rlvHandle) llListenRemove(rlvHandle);
                    rlvHandle = cdListenAll(rlvChannel);
                    if (rlvHandle2) llListenRemove(rlvHandle2);
                    rlvHandle2 = cdListenAll(rlvChannel2);
                    if (!rlvHandle3) llListenRemove(rlvHandle3);
                    rlvHandle3 = cdListenAll(rlvChannel3);

                    if (outfitsFolder == "" && !outfitSearching) {
                        outfitSearching++;
                        if (outfitSearching < 2) {

                            debugSay(2,"DEBUG-RLVOK","Searching for Outfits and Typefolders");
                            outfitsFolder = "";
                            typeFolder = "";
                            useTypeFolder = 0;
                            typeSearchTries = 0;
                            outfitSearchTries = 0;

                            outfitsSearchTimer = llGetTime();
                            folderSearch(outfitsFolder,rlvChannel3);
                        }
                    }
                }
            }
        }

        else if (code == 500) {
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
                if (cdTransformLocked()) {
                    debugSay(5,"DEBUG-TYPES","Transform locked");
                    if (cdIsDoll(id)) {
                        llDialog(id,"You cannot be transformed right now, as you were recently transformed. You can be transformed in " + (string)minMinutes + " minutes.",["OK"], DISCARD_CHANNEL);
                    } else {
                        llDialog(id,"The Doll " + dollName + " cannot be transformed right now. The Doll was recently transformed. Dolly can be transformed in " + (string)minMinutes + " minutes.",["OK"], DISCARD_CHANNEL);
                    }
                }
                else {
                    // Transformation lock time has expired: transformations (type changes) now allowed
                    reloadTypeNames();

                    string msg = "These change the personality of " + dollName + "; Dolly is currently a " + stateName + " Doll. ";
                    list choices = types;

                    if (cdIsDoll(id)) {
                        msg += "What type of doll do you want to be?";
                    }
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
                choice = transform; // Type name saved from Transform confirmation
                transformedViaMenu = YES;
                setDollType(choice, NOT_AUTOMATED);
            }
            else if (cdListElementP(types, choice) != NOT_FOUND) {
                // "choice" is a valid Type: change to it as appropriate
                if (cdIsDoll(id)) {
                    // Doll chose a Type: just do it
                    transformedViaMenu = YES;
                    setDollType(choice, NOT_AUTOMATED);
                }
                else {
                    // Someone else chose a Type
                    if (mustAgreeToType) {
                        if (!cdIsDoll(id)) lmSendToAgent("Getting confirmation from Doll...",id);

                        transform = choice; // save transformation Type
                        list choices = ["Transform", "Dont Transform", MAIN ];
                        string msg = "Do you wish to be transformed to a " + choice + " Doll?";

                        cdDialogListen();
                        llDialog(dollID, msg, choices, dialogChannel); // this starts a new choice on this channel
                    }
                    else {
                        transformedViaMenu = YES;
                        setDollType(choice, NOT_AUTOMATED);
                    }
                }
            }
#ifdef DEVELOPER_MODE
            else {
                debugSay(5,"DEBUG-TRANSFORM","500/Choice not handled: " + choice);
            }
#endif

#ifdef WAKESCRIPT
            if ((!showPhrases) && ((menuTime == 0.0) || ((menuTime + 60) < llGetTime()))) llSetScriptState(cdMyScriptName(), 0);
#endif
        }
#ifdef DEVELOPER_MODE
        else {
            debugSay(6,"DEBUG-TRANSFORM","Transform Link Message not handled: " + name + "/" + (string)code);
        }
#endif
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {

        // if a @getinv call succeeds, then we are here - looking for the
        // folders we want...
        //
        if (channel == rlvChannel3) {
            debugSay(2,"DEBUG-LISTEN","Channel #1 received (outfitsFolder = \"" + outfitsFolder + "\"): " + choice);

            list folderList = llCSV2List(choice);

            if (outfitsFolder == "") {
                if (llSubStringIndex(choice,"Outfits") >= 0 ||
                    llSubStringIndex(choice,"Dressup") >= 0)   {

                         if (~llListFindList(folderList, (list)"Outfits"))    outfitsFolder = "Outfits";
                    else if (~llListFindList(folderList, (list)"> Outfits"))  outfitsFolder = "> Outfits";
                    else if (~llListFindList(folderList, (list)"Dressup"))    outfitsFolder = "Dressup";
                    else if (~llListFindList(folderList, (list)"> Dressup"))  outfitsFolder = "> Dressup";

                    debugSay(2,"DEBUG-LISTEN","outfitsFolder = " + outfitsFolder);

                    lmSendConfig("outfitsFolder", outfitsFolder);
                    lmSendConfig("typeFolder", typeFolder);
                    lmSendConfig("useTypeFolder", (string)useTypeFolder);

                    debugSay(2,"DEBUG-SEARCHING","typeFolder = \"" + typeFolder + "\" and typeFolderExpected = \"" + typeFolderExpected + "\"");
                    // Search for a typeFolder...
                    if (typeFolder == "" && typeFolderExpected != "") {
                        debugSay(2,"DEBUG-SEARCHING","Outfit folder found at " + formatFloat(llGetTime() - outfitsSearchTimer,1) + "s; searching for typeFolder");
                        // outfitsFolder search is done: search for typeFolder
                        folderSearch(outfitsFolder,rlvChannel2);
                    }
                }
            }

            if (~llListFindList(folderList, (list)"~nude"))        lmSendConfig("nudeFolder","~nude");
#ifdef DEVELOPER_MODE
            else llOwnerSay("WARN: No nude (~nude) folder found with your outfits folder...");
#endif
            if (~llListFindList(folderList, (list)"~normalself"))  lmSendConfig("normalselfFolder","~normalself");
#ifdef DEVELOPER_MODE
            else llOwnerSay("WARN: No normal self (~normalself) folder found with your outfits folder...");
#endif
        }
        else if (channel == rlvChannel2) {
            debugSay(2,"DEBUG-LISTEN","Channel #2 received (\"" + typeFolder + "\"): " + choice);

            if (typeFolderExpected != "" && typeFolder != typeFolderExpected) {
                if (llSubStringIndex(choice,typeFolderExpected) >= 0) {

                    list folderList = llCSV2List(choice);
                    if (~llListFindList(folderList, (list)typeFolderExpected)) {

                        useTypeFolder = YES;
                        typeFolder = typeFolderExpected;
                        debugSay(2,"DEBUG-LISTEN","typeFolder = " + typeFolder);

                        lmSendConfig("outfitsFolder", outfitsFolder);
                        lmSendConfig("typeFolder", typeFolder);
                        lmSendConfig("useTypeFolder", (string)useTypeFolder);
                    }
                    else {
                        useTypeFolder = NO;
                        lmSendConfig("outfitsFolder", outfitsFolder);
                        lmSendConfig("useTypeFolder", (string)useTypeFolder);
                        lmSendConfig("typeFolder", "");
                    }

                    outfitSearching = 0;
                    llSetTimerEvent(0.0);
                    llListenRemove(rlvHandle3);
                    debugSay(2,"DEBUG-SEARCHING","Outfits search completed in " + formatFloat(llGetTime() - outfitsSearchTimer,1) + "s");
                    // We're done at this stage

                    // is this redundant or prudent?
                    lmSendConfig("nudeFolder","");
                    lmSendConfig("normalselfFolder","");

                    if (~llListFindList(folderList, (list)"~nude"))        lmSendConfig("nudeFolder",outfitsFolder + "/~nude");
                    else llOwnerSay("WARN: No nude (~nude) folder found in your outfits folder...");
                    if (~llListFindList(folderList, (list)"~normalself"))  lmSendConfig("normalselfFolder",outfitsFolder + "/~normalself");
                    else llOwnerSay("WARN: No normal self (~normalself) folder found in your outfits folder...");
                }
            }
        }
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key query_id, string data)  {

        if (query_id == kQuery) {
            if (data == EOF) {
                debugSay(2,"DEBUG-TRANSFORM","Read " + (string)readLine + " lines from " + typeNotecard);
                kQuery = NULL_KEY;
                readLine = 0;
            }
            else {
                // This is the real meat: currentPhrases is built up
                if (llStringLength(data) > 1) currentPhrases += data;

                //llSetTimerEvent(5.0);
                kQuery = llGetNotecardLine(typeNotecard,readLine++);
            }
        }
    }
}


