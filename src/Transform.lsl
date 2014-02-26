//========================================
// Transform.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 25 February 2014

// 29 March: Formatting and general cleanup
//Aug 14, totally changing
//Nov. 12, adding compatibility with hypnosisHUD

#include "include/GlobalDefines.lsl"

#define STRING_END -1
#define TYPE_FLAG "*"
#define YES 1
#define NO 0

#define cdGetChar(s,a) llGetSubString(s, a, a)
#define cdGetFirstChar(s) llGetSubString(s, 0, 0)

//========================================
// VARIABLES 
//========================================
string dollName;
string stateName; 
list types;
integer lineno;
integer readingNC;
integer tryOutfits;
integer retryOutfits;
integer findTypeFolder;
integer rlvHandle;
string transform;
string outfitsTest;
string outfitsFolder;
string typeFolder;

//integer cd8666;
//integer cd8667;
//integer cd8665;
 
integer dialogChannel;
integer rlvChannel;

//integer listen_id_8666;
//integer listen_id_8667;
//integer listen_id_8665;
//integer listen_id_ask;
integer minMinutes = 0;
//integer maxMinutes;
//integer avoid;
//integer channel_dialog;
//integer channelHUD;
//integer channelAsk;
integer configured;
integer RLVok;

integer startup = YES;

//integer menulimit = 9;     // 1.5 minute

string currentState;
integer dbConfig;
integer initState = 104;
integer mustAgreeToType;
integer showPhrases;
integer isTransformingKey;
key dollID;
string clothingprefix;

key kQuery;

list currentphrases;

integer quiet;

//========================================
// FUNCTIONS
//========================================
setDollType(string choice, integer automated) {
    if (choice == "Transform") stateName = transform;
    else stateName = choice;
    
    stateName = cdGetFirstChar(llToUpper(stateName)) + llGetSubString(llToLower(stateName), 1, STRING_END);
    
    // I am unsure what this function is doing it seems like
    // a possible hangover but maybe I am missing something.
    // Commenting for now until confirmed.
    //sendStateName();

    if (stateName != currentState) {
        if (automated) minMinutes = 0;
        else minMinutes = 5;    
        typeFolder = "";
        llSetTimerEvent(3.0);
    
        currentState = stateName;

        clothingprefix = TYPE_FLAG + stateName;
        currentphrases = [];
        lineno = 0;
        
        if (llGetInventoryType(TYPE_FLAG + stateName) == INVENTORY_NOTECARD) kQuery = llGetNotecardLine(TYPE_FLAG + stateName,0);
    
        lmSendConfig("dollType", stateName);
        lmSendConfig("currentState", stateName);
        llSleep(0.5);
    
        lmInternalCommand("randomDress", "", NULL_KEY);
    
        if (!quiet) llSay(0, dollName + " has become a " + stateName + " Doll.");
        else llOwnerSay("You have become a " + stateName + " Doll.");
    }
}

/*sendStateName() {
    string stateToSend = stateName;

    // convert state names as needed
    //
    //   Regular -> Normal
    //   Domme -> Dominant
    //   Submissive -> submissive
    //
    if (stateToSend == "Regular") {
        stateToSend = "Normal";
    }
    else if (stateToSend = "Domme") {
        stateToSend = "Dominant";
    }
    else if (stateToSend = "Submissive") {
        stateToSend = "submissive";
    }

    llSay(channelHUD,stateToSend);
}*/
    
reloadTypeNames() {
    string typeName;

    integer n = llGetInventoryNumber(INVENTORY_NOTECARD);
    types = [];

    while(n) {
        typeName = llGetInventoryName(INVENTORY_NOTECARD, --n);
        if (cdGetFirstChar(typeName) == TYPE_FLAG) {
            types += llGetSubString(typeName, 1, STRING_END);
        }
    }
}

runTimedTriggers() {
    if (minMinutes > 0) {
        minMinutes--;
        }

    if (showPhrases) {
        integer i = (integer) llFrand(llGetListLength(currentphrases));

        // if no phrases to be used, exit
        if (i == 0) {
            return;
        }

        string phrase  = llList2String(currentphrases, i);

        // Starting with a '*' marks a fragment; with none,
        // the phrase is used as is

        if (cdGetFirstChar(phrase) == "*") {

            phrase = llGetSubString(phrase, 1, STRING_END);
            float r = llFrand(3);

            if (r < 1.0) {
                phrase = "*** feel your need to " + phrase;
            } else if (r < 2.0) {
                phrase = "*** feel your desire to " + phrase;
            } else {
                if (currentState  == "Domme") {
                    phrase = "*** You like to " + phrase;
                } else {
                    phrase = "*** feel how people like you to " + phrase;
                }
            }
        } else {
            phrase = "*** " + phrase;
        }

        // Add reminder of Doll type
        // FIXME: Do we want constant type reminders?

        //if (currentState == "Regular") {
        //  phrase += " ***";
        //} else {        
        //    phrase += " (since you are a " + stateName + " Doll) ***";
        //}

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
    }
    //----------------------------------------
    // ON REZ!startup
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
        

        if (tryOutfits) {
            if (outfitsFolder == "") {
                if ((outfitsTest == "") || (retryOutfits < 2)) {
                    outfitsTest = llList2String(outfitsFolders, tryOutfits - 1);
                }
                else {
                    if (tryOutfits == llGetListLength(outfitsFolders)) {
                        tryOutfits = 0;
                        outfitsTest = "";
                        if (!readingNC) {
                            llSetTimerEvent(0.0);
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
                tryOutfits = 0;
                llSetTimerEvent(0.0);
            }
            
            llListenControl(rlvHandle, 1);
            llOwnerSay("@findfolder:" + outfitsTest + "=" + (string)rlvChannel);
            retryOutfits++;
        }
        
        
        if (readingNC) {
            kQuery = llGetNotecardLine(TYPE_FLAG + currentState,lineno);
        }
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer source, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);
        string script = llList2String(split, 0);
        string choice = llList2String(split, 1);
        string name = llList2String(split, 2);
        
        scaleMem();
        
        if (code == 102) {
            // Trigger Transforming Key setting
            if (!isTransformingKey) lmSendConfig("isTransformingKey", (string)(isTransformingKey = 1));
            
            if (choice == "Start") {
                configured = 1;
                if(stateName != currentState) setDollType(stateName, 1);
            }
        }
        
        else if (code == 104) {
            if (script != "Start") return;
            reloadTypeNames();
            startup = 1;
            llSetTimerEvent(60.0);   // every minute
            if (initState == 104) lmInitState(initState++);
        }
        
        else if (code == 105) {
            if (script != "Start") return;
            if (initState == 105) lmInitState(initState++);
        }
        
        else if (code == 110) {
            initState = 105;
            setDollType(stateName, 1);
            startup = 0;
        }
        
        else if (code == 135) {
            float delay = (float)choice;
            memReport(delay);
        }
        
        else if (code == 300) {
            string value = name;
            string name = choice;
            
            if (script != SCRIPT_NAME) {
                     if (name == "quiet")                                          quiet = (integer)value;
                else if (name == "mustAgreeToType")                      mustAgreeToType = (integer)value;
                else if (name == "showPhrases")                              showPhrases = (integer)value;
                else if (name == "currentState")                            currentState = value;
                else if (name == "dialogChannel") {
                                                                           dialogChannel = (integer)value;
                                                                              rlvChannel = dialogChannel ^ 0x80000000;
                }
                else if (name == "debugLevel") {
                                                                              debugLevel = (integer)value;
                }
                
                else if (name == "dollType") setDollType((stateName = value), 1);
                
                else if (script == "Main" && name == "timeLeftOnKey") runTimedTriggers();
            }
        }
        
        else if (code == 350) {
            RLVok = (integer)choice;
            
            outfitsFolder = "";
            typeFolder = "";
            tryOutfits = 1;
            retryOutfits = 0;
            
            if (RLVok) {
                if (!rlvHandle) rlvHandle = llListen(rlvChannel, "", "", "");
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
            
            llSetTimerEvent(3.0);
        }
        
        if (code == 500) {
            string name = llList2String(split, 2);
            string optName = llGetSubString(choice, 2, STRING_END);
            string curState = cdGetFirstChar(choice);
            
            if (choice == "Type Options") {
                list choices;

                choices += getButton("Verify Type", id, mustAgreeToType, 0);
                choices += getButton("Show Phrases", id, showPhrases, 0);

                llDialog(dollID, "Options", dialogSort(choices + MAIN), dialogChannel);
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
            else if (choice == "Type of Doll") {
                // Doll must remain in a type for a period of time
                if (minMinutes > 0) {
                    // Since the output goes to the listener "handle" of 9999, it is discarded silently
                    llDialog(id,"The Doll " + dollName + " cannot be transformed right now. The Doll was recently transformed. Dolly can be transformed in " + (string)minMinutes + " minutes.",["OK"], 9999);
                }
                else {
                    string msg = "These change the personality of " + dollName + " This Doll is currently a " + stateName + " Doll. What type of doll do you want the Doll to be?";
                    list choices = types;

                    llOwnerSay(name + " is looking at your doll types.");

                    /*if (id == dollID) {
                        choices += "Transform Options";
                    }*/

                    llDialog(id, msg, dialogSort(llListSort(choices, 1, 1) + MAIN), dialogChannel);
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
                    //avoid = TRUE;
                }
                
                //avoid = FALSE;
                debugSay(5, "DEBUG", "transform = " + (string)transform);
                debugSay(5, "DEBUG", "stateName = " + (string)choice);
                debugSay(5, "DEBUG", "currentState = " + (string)currentState);

                setDollType(choice, 0);
            }
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {
        /* Verify current Transform choice
        if (channel == channelAsk) {
            if (choice == "ask") {
                sendStateName();
            }
        }*/
        
        if ((outfitsFolder == "") && (llGetSubString(choice, -llStringLength(outfitsTest), -1) == outfitsTest)) {
            outfitsFolder = choice;
            lmSendConfig("outfitsFolder", outfitsFolder);
            if (typeFolder != "") {
                tryOutfits = 0;
                llSetTimerEvent(0.0);
            }
            llOwnerSay("Your outfits folder is '" + outfitsFolder + "'");
            retryOutfits = 0;
        }
        else if ((typeFolder == "") && (llGetSubString(choice, -llStringLength(clothingprefix), -1) == clothingprefix)) {
            typeFolder = choice;
            lmSendConfig("typeFolder", typeFolder);
            tryOutfits = 0;
            llSetTimerEvent(0.0);
            if (llGetSubString(typeFolder, 0, llStringLength(outfitsFolder) - 1) != outfitsFolder) {
                llOwnerSay("WARNING: Found type folder '" + typeFolder + "' is not within the outfits folder '" + outfitsFolder + 
                           "' please check it is correct and you do not have two of more folders named *" + stateName);
            }
            else {
                llOwnerSay("Your type folder is " + typeFolder);
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

                if (llStringLength(data) > 1) {
                    currentphrases += data;
                }

                lineno++;
                
                readingNC = 1;
                llSetTimerEvent(3.0);
            }
        }
    }
}
