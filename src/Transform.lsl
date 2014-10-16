//========================================
// Transform.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 25 February 2014

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
integer outfitsFolderItem;
integer outfitsFolderTestRetries;
integer findTypeFolder;
integer rlvHandle;
integer useTypeFolder;
integer transformedViaMenu;
string transform;
string outfitsFolderTest;
string outfitsFolder;
string typeFolder;

integer dialogChannel;
integer rlvChannel;

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
string clothingprefix;

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

    clothingprefix = TYPE_FLAG + stateName;
    currentPhrases = [];
    readLine = 0;
    typeNotecard = TYPE_FLAG + stateName;

    // Look for Notecard for the Doll Type and start reading it if showPhrases is enabled
    //
    if (showPhrases) {
        if (llGetInventoryType(typeNotecard) == INVENTORY_NOTECARD) {
            // FIXME: This is an infinite loop!!
            kQuery = llGetNotecardLine(typeNotecard,++readLine);
            debugSay(2,"DEBUG-DOLLTYPE","Found notecard: " + typeNotecard);
        }
    }

    // Are we changing types?
    if (stateName != currentState) {
        // Dont lock if transformation is automated
        if (automated) minMinutes = 0;
        else minMinutes = TRANSFORM_LOCK_TIME;

        typeFolder = "";

        currentState = stateName;
        lmSendConfig("dollType", stateName);

        cdPause();

        if (!quiet) cdChat(dollName + " has become a " + stateName + " Doll.");
        else llOwnerSay("You have become a " + stateName + " Doll.");

        if (!RLVok) { lmSendToAgentPlusDoll("Because RLV is disabled, Dolly does not have the capability to change outfit.",transformerId); };

        //typeFolder = "";
        outfitsFolderTestRetries = 0;
        outfitsFolderItem = 1;
        llSetTimerEvent(15.0);
    }
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
        dbConfig = 0;
        //startup = 2;
        debugSay(2,"DEBUG-TRANSFORM","Done with on_rez...");
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if ((change & CHANGED_INVENTORY)     ||
            (change & CHANGED_ALLOWED_DROP)) {

            reloadTypeNames();
        }
        debugSay(2,"DEBUG-TRANSFORM","Done with changed...");
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
        list outfitsMasterFolders = [ ">&&Outfits", "Outfits", ">&&Dressup", "Dressup" ];

        // Reading Notecard: happens first
        //if (readingNC) {
        //    debugSay(5,"DEBUG-TRANSFORM","Reading notecard " + TYPE_FLAG + currentState + " line number " + (string)readLine);
        //    kQuery = llGetNotecardLine(TYPE_FLAG + currentState,readLine);
        //}
        // Searching for Outfits folders (but only if RLV is ok)
        //else
        if (RLVok) {
            debugSay(5,"DEBUG-TRANSFORM","Searching for outfits folders... ");
            //debugSay(5,"DEBUG-TRANSFORM",">>outfitsFolderItem = " + (string)outfitsFolderItem);
            //debugSay(5,"DEBUG-TRANSFORM",">>outfitsFolder = " + (string)outfitsFolder);
            //debugSay(5,"DEBUG-TRANSFORM",">>outfitsFolderTest = " + (string)outfitsFolderTest);

            if (outfitsFolderItem > 0) {
                debugSay(5,"DEBUG-TRANSFORM","outfitsFolderItem = " + (string)outfitsFolderItem);
                if (outfitsFolder == "") {
                    debugSay(5,"DEBUG-TRANSFORM","outfitsFolder = " + (string)outfitsFolder);

                    // Search for Outfits folder, using outfitsMasterFolders as guide
                    if ((outfitsFolderTest == "") || (outfitsFolderTestRetries < 2)) {
                        outfitsFolderTest = cdListElement(outfitsMasterFolders, outfitsFolderItem - 1);
                    }
                    else {
                        if (outfitsFolderItem == llGetListLength(outfitsMasterFolders)) {
                            outfitsFolderItem = 0;
                            outfitsFolderTest = "";
                        }
                        outfitsFolderTest = cdListElement(outfitsMasterFolders, outfitsFolderItem++);
                        outfitsFolderTestRetries = 0;
                    }
                }
                else if ((clothingprefix != "") && (typeFolder == "") && (outfitsFolderTestRetries < 2)) {
                    debugSay(5,"DEBUG-TRANSFORM","clothingprefix = " + (string)clothingprefix);
                    debugSay(5,"DEBUG-TRANSFORM","typeFolder = " + (string)typeFolder);
                    outfitsFolderTest = clothingprefix;
                }
                else {
                    if (typeFolder == "") lmSendConfig("useTypeFolder", (string)(useTypeFolder = 0));
                    debugSay(5,"DEBUG-TRANSFORM","typeFolder = " + (string)typeFolder);
                    outfitsFolderItem = 0;
                }

                // Try an actual folder - outfitsFolderTest - and see what comes back on listener channel
                //llListenControl(rlvHandle, 1); -- never turned off apparently
                lmRunRLV("findfolder:" + outfitsFolderTest + "=" + (string)rlvChannel);
                outfitsFolderTestRetries++;
            }
        }
        else if (showPhrases) {
            debugSay(5,"DEBUG-TRANSFORM","Stopping timer");
            // Scripts are being shown...
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
                if (code == 700 || code == 850) return;
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
        else if (code == 850) return;

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
            if(stateName != currentState) setDollType(stateName, AUTOMATED);
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
            //setDollType(stateName, AUTOMATED);
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

            if (value == RECORD_DELETE) {
                value = "";
                split = [];
            }

#if DEVELOPER_MODE
            //llOwnerSay("==== got 300 Link Message:" + script + ":" + name + "/" + value);
            //if (name == "RLVok") llOwnerSay("---- got RLVok");
            //if (name == "dialogChannel") llOwnerSay("---- got dialogChannel");
#endif

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
                    }

                    //if (name == "RLVok") llOwnerSay("got RLVok");
                    //else if (name == "dialogChannel") llOwnerSay("got dialogChannel");

                    if (RLVok) {
                        if (rlvChannel) {
                            //llOwnerSay("rlvChannel reset...");
                            if (!rlvHandle) llListenRemove(rlvHandle);
                            rlvHandle = cdListenAll(rlvChannel);
                            llSetTimerEvent(15.0);
                            //llOwnerSay("rlvChannel reset done...");
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
            outfitsFolderItem = 1;
            outfitsFolderTestRetries = 0;

            if (RLVok) {
                if (rlvChannel) {
                    if (rlvHandle) llListenRemove(rlvHandle);
                    rlvHandle = cdListenAll(rlvChannel);
                    llSetTimerEvent(15.0);
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

        debugSay(2,"DEBUG-TRANSFORM","Listener tickled: " + choice + "/" + (string)id + "/" + (string)name);
        // llOwnerSay("choice = " + choice); // DEBUG:
        // llOwnerSay("clothing prefix = " + clothingprefix); // DEBUG:
        // llOwnerSay("    substring = " + (string)llGetSubString(choice, -llStringLength(clothingprefix), STRING_END)); // DEBUG:
        // llOwnerSay("outfitsFolderTest = " + outfitsFolderTest); // DEBUG:
        // llOwnerSay("    substring = " + (string)llGetSubString(choice, -llStringLength(outfitsFolderTest), STRING_END)); // DEBUG:

        debugSay(6,"DEBUG-TRANSFORM","Listen processing...");
        // Does choice end in outfitsFolderTest path?
        if ((outfitsFolder == "") && (cdStringEndMatch(choice,outfitsFolderTest))) {
            debugSay(6,"DEBUG-TRANSFORM","Outfits folder?");
            outfitsFolder = choice + "/";
            lmSendConfig("outfitsFolder", outfitsFolder);
            if (typeFolder != "") {
                outfitsFolderItem = 0;
                cdStopTimer();
            }
            llOwnerSay("Your outfits folder is '" + outfitsFolder + "'");
            outfitsFolderTestRetries = 0;
        }

        // Does choice end in clothing prefix?
        else if ((typeFolder == "") && (cdStringEndMatch(choice,clothingprefix))) {
            debugSay(6,"DEBUG-TRANSFORM","Clothing prefix found");
            typeFolder = choice;
            outfitsFolderItem = 0;

            cdStopTimer();
            //integer n = llStringLength(outfitsFolder);

            //if (llGetSubString(typeFolder, 0, n - 1) != outfitsFolder)
            if (llGetSubString(typeFolder, 0, llStringLength(outfitsFolder) - 1) != outfitsFolder) {
                llOwnerSay("Found a matching type folder in '" + typeFolder + "' but it is not located within your outfits folder '" + outfitsFolder + "'" +
                           "please make sure that the '" + TYPE_FLAG + stateName + "' folder is inside of '" + outfitsFolder + "'");
                typeFolder = "";
                useTypeFolder = NO;
            }
            else {
                typeFolder = llDeleteSubString(typeFolder, 0, llStringLength(outfitsFolder));
                //typeFolder = llGetSubString(typeFolder, n, STRING_END);
                llOwnerSay("Your outfits folder is now " + outfitsFolder);
                llOwnerSay("Your type folder is now " + outfitsFolder + "/" + typeFolder);
                useTypeFolder = YES;
            }

            lmSendConfig("typeFolder", typeFolder);
            lmSendConfig("outfitsFolder", outfitsFolder);
            lmSendConfig("useTypeFolder", (string)useTypeFolder);

            cdPause();

            if (transformedViaMenu) {
                debugSay(6,"DEBUG-TRANSFORM","Activating random dress...");
                lmInternalCommand("randomDress", "", NULL_KEY);
                transformedViaMenu = NO; // default setting
            }

            outfitsFolderTestRetries = 0;
        }
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key query_id, string data)  {

        if (query_id == kQuery) {
            if (data == EOF) {
                llOwnerSay("Read " + (string)readLine + " lines from " + typeNotecard);
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


