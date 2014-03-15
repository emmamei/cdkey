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
#define cdGetFirstChar(a) llGetSubString(a, 0, 0)
#define cdButFirstChar(a) llGetSubString(a, 1, STRING_END)
#define cdChat(a) llSay(0, a)
#define cdStopTimer() llSetTimerEvent(0.0)
#define NO_FILTER ""
#define cdListenAll(a) llListen(a, NO_FILTER, NO_FILTER, NO_FILTER)
#define cdPause() llSleep(0.5)
#define YES 1
#define NO 0

//========================================
// VARIABLES
//========================================
string dollName;
string stateName;
list types;
float menuTime;
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
setDollType(string choice, integer automated) {
    if (choice == "Transform") stateName = transform;
    else stateName = choice;

    stateName = cdGetFirstChar(llToUpper(stateName)) + cdButFirstChar(llToLower(stateName));

    clothingprefix = TYPE_FLAG + stateName;
    currentPhrases = [];
    lineno = 0;

    if (llGetInventoryType(TYPE_FLAG + stateName) == INVENTORY_NOTECARD) kQuery = llGetNotecardLine(TYPE_FLAG + stateName,0);

    if (stateName != currentState) {
        if (automated) minMinutes = 0;
        else minMinutes = 5;

        typeFolder = "";
        llSetTimerEvent(3.0);

        currentState = stateName;
        lmSendConfig("dollType", stateName);
        lmSendConfig("currentState", stateName);

        cdPause();

        if (!quiet) cdChat(dollName + " has become a " + stateName + " Doll.");
        else llOwnerSay("You have become a " + stateName + " Doll.");
        
        typeFolder = "";
        retryOutfits = 0;
        tryOutfits = 1;
        llSetTimerEvent(5.0);
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

    if (showPhrases) {
        integer phraseCount = (integer) llGetListLength(currentPhrases);

        if (phraseCount == 0) return;

        // select a phrase from the notecard at random
        string phrase  = llList2String(currentPhrases, llFloor(llFrand(phraseCount)));

        // Starting with a '*' marks a fragment; with none,
        // the phrase is used as is

        if (cdGetFirstChar(phrase) == "*") {

            phrase = cdButFirstChar(phrase);
            float r = llFrand(3);

            if (r < 1.0) phrase = "*** feel your need to " + phrase;
            else if (r < 2.0) phrase = "*** feel your desire to " + phrase;
            else {
                if (currentState  == "Domme") phrase = "*** You like to " + phrase;
                else phrase = "*** feel how people like you to " + phrase;
            }
        } else phrase = "*** " + phrase;

        // Phrase has been chosen and put together; now say it
        llOwnerSay(phrase);
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
        list outfitsFolders = [ "> Outfits", "Outfits", "> Dressup", "Dressup" ];

        if (readingNC) {
            kQuery = llGetNotecardLine(TYPE_FLAG + currentState,lineno);
        }
        else if (tryOutfits) {
            if (outfitsFolder == "") {
                if ((outfitsTest == "") || (retryOutfits < 2)) {
                    outfitsTest = llList2String(outfitsFolders, tryOutfits - 1);
                }
                else {
                    if (tryOutfits == llGetListLength(outfitsFolders)) {
                        tryOutfits = 0;
                        outfitsTest = "";
                        if (!readingNC) {
                            cdStopTimer();
                            if (!showPhrases) llSetScriptState(cdMyScriptName(), 0);
                            return;
                        }
                    }
                    outfitsTest = llList2String(outfitsFolders, tryOutfits++);
                    retryOutfits = 0;
                }
            }
            else if ((typeFolder == "") && (retryOutfits < 2)) {
                outfitsTest = clothingprefix;
            }
            else {
                if (typeFolder == "") lmSendConfig("useTypeFolder", (string)(useTypeFolder = 0));
                tryOutfits = 0;
                if (!readingNC) {
                    cdStopTimer();
                    if (!showPhrases) llSetScriptState(cdMyScriptName(), 0);
                    return;
                }
            }

            llListenControl(rlvHandle, 1);
            lmRunRLV("findfolder:" + outfitsTest + "=" + (string)rlvChannel);
            retryOutfits++;
        }
        else {
            cdStopTimer();
            if (!showPhrases) llSetScriptState(cdMyScriptName(), 0);
        }
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

        scaleMem();

        if (code == 102) {
            // FIXME: Is this relevant?
            // Trigger Transforming Key setting
            if (!isTransformingKey) lmSendConfig("isTransformingKey", (string)(isTransformingKey = 1));

            configured = 1;
            if(stateName != currentState) setDollType(stateName, 1);
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
            setDollType(stateName, 1);
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

            if (script != cdMyScriptName()) {
                     if (name == "quiet")                                          quiet = (integer)value;
                else if (name == "mustAgreeToType")                      mustAgreeToType = (integer)value;
                else if (name == "showPhrases")                              showPhrases = (integer)value;
                else if (name == "wearAtLogin")                              wearAtLogin = (integer)value;
                else if (name == "stateName")                                  stateName = value;
                else if (name == "RLVok") {
                    RLVok = (integer)value;
                    if (RLVok) {
                        if (!rlvHandle) rlvHandle = cdListenAll(rlvChannel);
                        else {
                            rlvHandle = 0;
                            llListenRemove(rlvHandle);
                        }
                    }
                }
                else if (name == "dialogChannel") {
                                                                           dialogChannel = (integer)value;
                                                                              rlvChannel = ~dialogChannel + 1; 
                }
#ifdef DEVELOPER_MODE
                else if (name == "debugLevel") {
                                                                              debugLevel = (integer)value;
                }
#endif

                else if (name == "dollType") {
                    stateName = value;
                    if (configured) setDollType(stateName, 1);
                }

                else if (script == "Main" && name == "timeLeftOnKey") runTimedTriggers();
            }
        }
        else if (code == 350) {
            RLVok = ((integer)choice == 1);

            outfitsFolder = "";
            typeFolder = "";
            tryOutfits = 1;
            retryOutfits = 0;

            if (RLVok) {
                if (!rlvHandle) rlvHandle = cdListenAll(rlvChannel);
                else {
                    rlvHandle = 0;
                    llListenRemove(rlvHandle);
                }
            }
            else {
                if (rlvHandle) {
                    rlvHandle = 0;
                    llListenRemove(rlvHandle);
                }
            }

            llSetTimerEvent(5.0);
        }
        else if (code == 500) {
            string name = cdListElement(split, 2);
            string optName = llGetSubString(choice, 2, STRING_END);
            string curState = cdGetFirstChar(choice);

            menuTime = 0.0;
            if (choice == "Type...") {
                list choices;

                choices += cdGetButton("Verify Type", id, mustAgreeToType, 0);
                choices += cdGetButton("Show Phrases", id, showPhrases, 0);
                choices += cdGetButton("Wear @ Login", id, wearAtLogin, 0);

                llDialog(dollID, "Options", dialogSort(choices + MAIN), dialogChannel);
                menuTime = llGetTime();
            }
            else if (optName == "Verify Type") {
                lmSendConfig("mustAgreeToType", (string)(mustAgreeToType = (curState == CROSS)));
                if (mustAgreeToType) llOwnerSay("Changes in Doll Types will be verified.");
                else llOwnerSay("Changes in Doll Types will not be verified.");
            }
            else if (optName == "Show Phrases") {
                lmSendConfig("showPhrases", (string)(showPhrases = (curState == CROSS)));
                if (showPhrases) llOwnerSay("Hypnotic phrases will be displayed.");
                else llOwnerSay("No hypnotic phrases will be displayed.");
            }
            else if (optName == "Wear @ Login") {
                lmSendConfig("wearAtLogin", (string)(wearAtLogin = (curState == CROSS)));
                if (wearAtLogin) llOwnerSay("If your type folder is set a new outfit will be chosen each login");
                else llOwnerSay("New outfits will no longer be chosen at login");
            }
            else if (choice == "Types...") {
                // Doll must remain in a type for a period of time
                if (minMinutes > 0) {
                    // Since the output goes to the listener "handle" of 9999, it is discarded silently
                    llDialog(id,"The Doll " + dollName + " cannot be transformed right now. The Doll was recently transformed. Dolly can be transformed in " + (string)minMinutes + " minutes.",["OK"], 9999);
                }
                else {
                    reloadTypeNames();
                    
                    string msg = "These change the personality of " + dollName + " This Doll is currently a " + stateName + " Doll. What type of doll do you want the Doll to be?";
                    list choices = types;

                    llOwnerSay(name + " is looking at your doll types.");

                    llDialog(id, msg, dialogSort(llListSort(choices, 1, 1) + MAIN), dialogChannel);
                    menuTime = llGetTime();
                }
            }
            else if ((cdListElementP(types, choice) != NOT_FOUND) || (choice == "Transform")) {
                if (choice == "Transform") choice = transform;
                else if (mustAgreeToType) {
                    transform = choice;
                    list choices = ["Transform", "Dont Transform", MAIN ];

                    string msg = "Do you wish to transform to a " + choice + " Doll?";

                    llDialog(dollID, msg, choices, dialogChannel);

                    // Return for now until we get confirmation
                    return;
                }

                debugSay(5, "DEBUG", "transform = " + (string)transform);
                debugSay(5, "DEBUG", "stateName = " + (string)choice);
                debugSay(5, "DEBUG", "currentState = " + (string)currentState);

                menuChangeType = 1;

                setDollType(choice, 0);
            }
            if ((!showPhrases) && ((menuTime == 0.0) || ((menuTime + 60) < llGetTime()))) llSetScriptState(cdMyScriptName(), 0);
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {

        if ((outfitsFolder == "") && (llGetSubString(choice, -llStringLength(outfitsTest), STRING_END) == outfitsTest)) {
            outfitsFolder = choice;
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
                llOwnerSay("Found a matching type folder in '" + typeFolder + "' but it is not located withing your outfits folder '" + outfitsFolder + "'" +
                           "please make sure that the '" + TYPE_FLAG + stateName + "' folder is inside of '" + outfitsFolder + "'");
                typeFolder = "";
                useTypeFolder = 0;
            }
            else {
                typeFolder = llDeleteSubString(typeFolder, 0, llStringLength(outfitsFolder));
                llOwnerSay("Your outfits folder is now " + outfitsFolder);
                llOwnerSay("Your type folder is now " + outfitsFolder + typeFolder);
                useTypeFolder = 1;
            }

            lmSendConfig("typeFolder", typeFolder);
            lmSendConfig("outfitsFolder", outfitsFolder);
            lmSendConfig("useTypeFolder", (string)useTypeFolder);

            cdPause();

            if (menuChangeType) {
                lmInternalCommand("randomDress", "", NULL_KEY);
                menuChangeType = 0;
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


