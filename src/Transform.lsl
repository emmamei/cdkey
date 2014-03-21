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
#define STRING_END -1
#define NOT_FOUND -1
#define NO_FILTER ""
#define YES 1
#define NO 0

#define cdGetFirstChar(a) llGetSubString(a, 0, 0)
#define cdButFirstChar(a) llGetSubString(a, 1, STRING_END)
#define cdChat(a) llSay(0, a)
#define cdStopTimer() llSetTimerEvent(0.0)
#define cdListenAll(a) llListen(a, NO_FILTER, NO_FILTER, NO_FILTER)
#define cdPause() llSleep(0.5)

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
integer lineno;
integer readingNC;
integer tryOutfits;
integer retryOutfits;
integer findTypeFolder;
integer rlvHandle;
integer useTypeFolder;
integer menuChangeType;
string transform;
string outfitsTest;
string outfitsFolder;
string typeFolder;

integer dialogChannel;
integer rlvChannel;

integer minMinutes = 0;
integer configured;
integer RLVok;

integer startup = 1;

//integer menulimit = 9;     // 1.5 minute

string currentState;
integer dbConfig;
integer mustAgreeToType;
integer showPhrases;
integer wearAtLogin;
integer isTransformingKey;
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
    lineno = 0;

    // Look for Notecard for the Doll Type and start reading it
    if (llGetInventoryType(TYPE_FLAG + stateName) == INVENTORY_NOTECARD) kQuery = llGetNotecardLine(TYPE_FLAG + stateName,0);

    // New State?
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
        
        if (!RLVok) { lmSendToAgentPlusDoll("Dolly does not have the capability to change outfit.",transformerId); };

        //typeFolder = "";
        retryOutfits = 0;
        tryOutfits = 1;
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
    if (minMinutes > 0) minMinutes--;
    else minMinutes = 0; // bulletproofing

    if (showPhrases) {
        integer phraseCount = (integer) llGetListLength(currentPhrases);
        string msg;

        if (phraseCount == 0) return;

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

        msg = msg + phrase;

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
        
        // Stop myself: stop this script from running
        cdStopScript(cdMyScriptName());
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer iParam) {
        dbConfig = 0;
        startup = 2;
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if ((change & CHANGED_INVENTORY)     ||
            (change & CHANGED_ALLOWED_DROP)) {

            reloadTypeNames();
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
        list outfitsFolders = [ ">&&Outfits", "Outfits", ">&&Dressup", "Dressup" ];

        // Reading Notecard: happens first
        if (readingNC) {
            kQuery = llGetNotecardLine(TYPE_FLAG + currentState,lineno);
        }
        // Searching for Outfits folders (but only if RLV is ok)
        else if (tryOutfits && RLVok) {
            if (outfitsFolder == "") {
                if ((outfitsTest == "") || (retryOutfits < 2)) {
                    outfitsTest = llList2String(outfitsFolders, tryOutfits - 1);
                }
                else {
                    if (tryOutfits == llGetListLength(outfitsFolders)) {
                        tryOutfits = 0;
                        outfitsTest = "";
                    }
                    outfitsTest = llList2String(outfitsFolders, tryOutfits++);
                    retryOutfits = 0;
                }
            }
            else if ((clothingprefix != "") && (typeFolder == "") && (retryOutfits < 2)) {
                outfitsTest = clothingprefix;
            }
            else {
                if (typeFolder == "") lmSendConfig("useTypeFolder", (string)(useTypeFolder = 0));
                tryOutfits = 0;
            }

            llListenControl(rlvHandle, 1);
            lmRunRLV("findfolder:" + outfitsTest + "=" + (string)rlvChannel);
            retryOutfits++;
        }
        // If no phrases are being shown, then stop script: no need to keep running
        else if (!showPhrases) {
            if ((menuTime + 60.0) < llGetTime()) cdStopScript(cdMyScriptName());
        }
        // Scripts are being shown...
        else cdStopTimer();
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

        //if (id != NULL_KEY) llOwnerSay("Transform Link Msg:" + (string)code + ":choice/name/id = " + choice + "/" + name + "/" + (string)id); //DEBUG
        //else llOwnerSay("Transform Link Msg:" + (string)code + ":choice/name = " + choice + "/" + name); //DEBUG

        scaleMem();

        if (code == 102) {
            // FIXME: Is this relevant?
            // Trigger Transforming Key setting
            if (!isTransformingKey) lmSendConfig("isTransformingKey", (string)(isTransformingKey = 1));

            configured = 1;
            if(stateName != currentState) setDollType(stateName, AUTOMATED);
        }

        else if (code == 104) {
            if (script != "Start") return;
            reloadTypeNames();
            startup = 1;
            llSetTimerEvent(60.0);   // every minute
        }

        else if (code == 105) {
            if (script != "Start") return;
        }

        else if (code == 110) {
            initState = 105;
            setDollType(stateName, AUTOMATED);
            startup = 0;
        }

        else if (code == 135) {
            float delay = (float)choice;
            memReport(cdMyScriptName(),delay);
        }

        cdConfigReport(); // FIXME: this "code" is invalid

        else if (code == 300) {
            string value = name;
            string name = choice;
            
            if (value == RECORD_DELETE) {
                value = "";
                split = [];
            }

            if (script != cdMyScriptName()) {
                     if (name == "quiet")                                          quiet = (integer)value;
                else if (name == "mustAgreeToType")                      mustAgreeToType = (integer)value;
                else if (name == "showPhrases")                              showPhrases = (integer)value;
                else if (name == "wearAtLogin")                              wearAtLogin = (integer)value;
                else if (name == "stateName")                                  stateName = value;
                else if (name == "RLVok") {
                    RLVok = (integer)value;
                    if (RLVok) {
                        if (rlvChannel) {
                            if (!rlvHandle) rlvHandle = cdListenAll(rlvChannel);
                            else {
                                llListenRemove(rlvHandle);
                                rlvHandle = cdListenAll(rlvChannel);
                            }
                            llSetTimerEvent(15.0);
                        }
                    }
                }
                else if (name == "dialogChannel") {
                    dialogChannel = (integer)value;
                    rlvChannel = ~dialogChannel + 1;
                    if (RLVok) {
                        if (!rlvHandle) rlvHandle = cdListenAll(rlvChannel);
                        else {
                            llListenRemove(rlvHandle);
                            rlvHandle = cdListenAll(rlvChannel);
                        }
                        llSetTimerEvent(15.0);
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

                else if (script == "Main" && name == "timeLeftOnKey") runTimedTriggers();
            }
        }
        else if (code == 305) {
            if (choice == "wakeScript") {
                if (name == cdMyScriptName()) cdLinkMessage(LINK_THIS, 0, 303, "debugLevel|dialogChannel|dollType|quiet|mustAgreeToType|RLVok|showPhrases|wearAtLogin", llGetKey());
            }
        }
        else if (code == 350) {
            RLVok = ((integer)choice == 1);

            outfitsFolder = "";
            typeFolder = "";
            tryOutfits = 1;
            retryOutfits = 0;

            if (RLVok) {
                if (rlvChannel) {
                    if (!rlvHandle) rlvHandle = cdListenAll(rlvChannel);
                    else {
                        llListenRemove(rlvHandle);
                        rlvHandle = cdListenAll(rlvChannel);
                    }
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
                (optName == "Show Phrases")  ||
                (optName == "Wear @ Login")) {

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
                else if (optName == "Wear @ Login") {
                    lmSendConfig("wearAtLogin", (string)(wearAtLogin = (curState == CROSS)));
                    if (wearAtLogin) llOwnerSay("If you are not a Regular Doll, a new outfit will be chosen each login.");
                    else llOwnerSay("A new outfit will not be worn at each login.");
                }
                
                list choices;

                choices += cdGetButton("Verify Type", id, mustAgreeToType, 0);
                choices += cdGetButton("Show Phrases", id, showPhrases, 0);
                choices += cdGetButton("Wear @ Login", id, wearAtLogin, 0);

                llDialog(dollID, "Options", dialogSort(choices + MAIN), dialogChannel);
            }

            // Choose a Transformation
            else if (choice == "Types...") {
                // Doll must remain in a type for a period of time
                if (cdTransformLocked()) {
                    if (cdIsDoll(id)) {
                        llDialog(id,"You cannot be transformed right now, as you were recently transformed. You can be transformed in " + (string)minMinutes + " minutes.",["OK"], DISCARD_CHANNEL);
                    } else {
                        llDialog(id,"The Doll " + dollName + " cannot be transformed right now. The Doll was recently transformed. Dolly can be transformed in " + (string)minMinutes + " minutes.",["OK"], DISCARD_CHANNEL);
                    }
                }
                else {
                    reloadTypeNames();
                    
                    string msg = "These change the personality of " + dollName + "; Dolly is currently a " + stateName + " Doll. ";
                    list choices = types;

                    if (cdIsDoll(id)) {
                        msg += "What type of doll do you want to be?";
                    }
                    else {
                        msg += "What type of doll do you want the Doll to be?";
                        llOwnerSay(name + " is looking at your doll types.");
                    }


                    llDialog(id, msg, dialogSort(llListSort(choices, 1, 1) + MAIN), dialogChannel);
                }
            }

            // Transform
            else if (choice == "Transform") {
                choice = transform; // Type name saved from Transform confirmation
                menuChangeType = YES;
                setDollType(choice, NOT_AUTOMATED);
            }
            else if (cdListElementP(types, choice) != NOT_FOUND) {
                // "choice" is a valid Type: change to it as appropriate
                if (cdIsDoll(id)) {
                    // Doll chose a Type: just do it
                    menuChangeType = YES;
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
                        menuChangeType = YES;
                        setDollType(choice, NOT_AUTOMATED);
                    }
                }
            }

            if ((!showPhrases) && ((menuTime == 0.0) || ((menuTime + 60) < llGetTime()))) llSetScriptState(cdMyScriptName(), 0);
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {

		debugSay(6, "DEBUG-TRANSFORM", "choice = " + choice); // DEBUG:
		debugSay(6, "DEBUG-TRANSFORM", "clothing prefix = " + clothingprefix); // DEBUG:
		debugSay(6, "DEBUG-TRANSFORM", "    substring = " + (string)llGetSubString(choice, -llStringLength(clothingprefix), STRING_END)); // DEBUG:
		debugSay(6, "DEBUG-TRANSFORM", "outfitsTest = " + outfitsTest); // DEBUG:
        debugSay(6, "DEBUG-TRANSFORM", "    substring = " + (string)llGetSubString(choice, -llStringLength(outfitsTest), STRING_END)); // DEBUG:

        if ((outfitsFolder == "") && (llGetSubString(choice, -llStringLength(outfitsTest), STRING_END) == outfitsTest)) {
            outfitsFolder = choice + "/";
            lmSendConfig("outfitsFolder", outfitsFolder);
            if (typeFolder != "") {
                tryOutfits = 0;
                cdStopTimer();
            }
            llOwnerSay("Your outfits folder is '" + outfitsFolder + "'");
            retryOutfits = 0;
        }
        else if ((typeFolder == "") && (llGetSubString(choice, -llStringLength(clothingprefix), STRING_END) == clothingprefix)) {
            typeFolder = choice;
            tryOutfits = 0;

            cdStopTimer();

            if (llGetSubString(typeFolder, 0, llStringLength(outfitsFolder) - 1) != outfitsFolder) {
                llOwnerSay("Found a matching type folder in '" + typeFolder + "' but it is not located within your outfits folder '" + outfitsFolder + "'" +
                           "please make sure that the '" + TYPE_FLAG + stateName + "' folder is inside of '" + outfitsFolder + "'");
                typeFolder = "";
                useTypeFolder = 0;
            }
            else {
                typeFolder = llDeleteSubString(typeFolder, 0, llStringLength(outfitsFolder));
                llOwnerSay("Your outfits folder is now " + outfitsFolder);
                llOwnerSay("Your type folder is now " + outfitsFolder + "/" + typeFolder);
                useTypeFolder = 1;
            }

            lmSendConfig("typeFolder", typeFolder);
            lmSendConfig("outfitsFolder", outfitsFolder);
            lmSendConfig("useTypeFolder", (string)useTypeFolder);

            cdPause();

            if (menuChangeType) {
                lmInternalCommand("randomDress", "", NULL_KEY);
                menuChangeType = NO;
            }
            
            retryOutfits = 0;
        }
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key query_id, string data)  {
        if (query_id == kQuery) {
            if (data != EOF) {
                if (llStringLength(data) > 1) currentPhrases += data;

                lineno++;
                readingNC = YES;
                llSetTimerEvent(5.0);
            }
            else readingNC = NO;
        }
    }
}


