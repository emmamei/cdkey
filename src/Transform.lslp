// 29 March: Formatting and general cleanup

//Aug 14, totally changing
//Nov. 12, adding compatibility with hypnosisHUD
#include "include/GlobalDefines.lsl"

//========================================
// VARIABLES 
//========================================
string dollname;
string stateName; 
list types;
integer lineno;
string transform;

//integer cd8666;
//integer cd8667;
//integer cd8665;
 
integer dialogChannel;

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

integer startup = 1;

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

setup()  {
    dollID =   llGetOwner();
    dollname = llGetDisplayName(dollID);
    stateName = "Regular";

    //integer ncd = ( -1 * (integer)("0x"+llGetSubString((string)llGetKey(),-5,-1)) ) -1;
    //if (channel_dialog != ncd) {
        
    dialogChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)llGetLinkKey(2), -8, -1));

    //llListenRemove(listen_id_8666);
    //llListenRemove(listen_id_8665);
    //llListenRemove(listen_id_8667);
    //llListenRemove(listen_id_ask);

    //channel_dialog = ncd;
    //cd8666 = channel_dialog - 8666;
    //cd8665 = cd8666 - 1;
    //cd8667 = cd8666 + 1;

    //listen_id_8665 = llListen( cd8665, "", "", "");
    //listen_id_8666 = llListen( cd8666, "", "", "");
    //listen_id_8667 = llListen( cd8667, "", "", "");

    //channelHUD = ( -1 * (integer)("0x"+llGetSubString((string)llGetOwner(),-5,-1)) )  - 1114;
    //channelAsk = channelHUD - 1;
    //listen_id_ask = llListen( cd8665, "", "", "");
    //}

    //sendStateName();
}

setDollType(string choice, integer force) {
    if (stateName != currentState) {
        if (force) {
            transform = llGetSubString(llToUpper(choice), 0, 0) + llGetSubString(llToLower(choice), 1, -1);
            choice = "Yes";
            minMinutes = 0;
        } else {
            minMinutes = 5;
        }
        
        if (choice == "Yes") stateName = transform;
        else stateName = choice;
    
        // I am unsure what this function is doing it seems like
        // a possible hangover but maybe I am missing something.
        // Commenting for now until confirmed.
        //sendStateName();
    
        currentState = stateName;
        clothingprefix = "*" + stateName;
        currentphrases = [];
        lineno = 0;
        
        if (llGetInventoryType("*" + stateName) == INVENTORY_NOTECARD) kQuery = llGetNotecardLine("*" + stateName,0);
    
        lmSendConfig("dollType", stateName);
        lmSendConfig("currentState", stateName);
        llSleep(0.5);
        
        lmSendConfig("clothingFolder", clothingprefix);
        llSleep(0.5);
    
        lmInternalCommand("randomDress", "", NULL_KEY);
    
        if (!quiet) llSay(0, dollname + " has become a " + stateName + " Doll.");
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
        if (llGetSubString(typeName, 0, 0) == "*") {
            types += llGetSubString(typeName, 1, -1);
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

        if (llGetSubString(phrase, 0, 0) == "*") {

            phrase = llGetSubString(phrase, 1, -1);
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
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer source, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);
        string choice = llList2String(split, 0);
        string name = llList2String(split, 1);
        
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
            if (llList2String(split, 0) != "Start") return;
            setup();
            reloadTypeNames();
            startup = 1;
            llSetTimerEvent(60.0);   // every minute
            if (initState == 104) lmInitState(initState++);
        }
        
        else if (code == 105) {
            if (llList2String(split, 0) != "Start") return;
            if (initState == 105) lmInitState(initState++);
        }
        
        else if (code == 110) {
            initState = 105;
            setDollType(stateName, 1);
            startup = 0;
        }
        
        else if (code == 135) {
            float delay = llList2Float(split, 1);
            memReport(delay);
        }
        
        else if (code == 300) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);
            
            if (script != SCRIPT_NAME) {
                if (name == "dollType") {
                    stateName = value;
                    if (!startup && stateName != currentState) setDollType(stateName, 1);
                }
                else if (name == "quiet") quiet = (integer)value;
                else if (name == "mustAgreeToType") mustAgreeToType = (integer)value;
                else if (name == "showPhrases") showPhrases = (integer)value;
                else if (name == "currentState") currentState = value;
                else if (name == "isTransformingKey") isTransformingKey = (integer)value;
                else if (script == "Main" && name == "timeLeftOnKey") runTimedTriggers();
            }
        }
        
        else if (code == 350) {
            RLVok = llList2Integer(split, 0);
        }
        
        if (code == 500) {
            string optName = llGetSubString(choice, 2, -1);
            string curState = llGetSubString(choice, 0, 0);
            
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
                    llDialog(id,"The Doll " + dollname + " cannot be transformed right now. The Doll was recently transformed. Dolly can be transformed in " + (string)minMinutes + " minutes.",["OK"], 9999);
                }
                else {
                    string msg = "These change the personality of " + dollname + " This Doll is currently a " + stateName + " Doll. What type of doll do you want the Doll to be?";
                    list choices = types;

                    llOwnerSay(name + " is looking at your doll types.");

                    /*if (id == dollID) {
                        choices += "Transform Options";
                    }*/

                    llDialog(id, msg, dialogSort(llListSort(choices, 1, 1) + MAIN), dialogChannel);
                }
            }
            else if ((llListFindList(types, [ choice ]) != -1) || (choice == "Transform")) {
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
                debugSay(5, "transform = " + (string)transform);
                debugSay(5, "choice = " + (string)choice);
                debugSay(5, "stateName = " + (string)(stateName = choice));
                debugSay(5, "currentState = " + (string)currentState);

                if (stateName != currentState) setDollType(choice, 0);
            }
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    /*listen(integer channel, string name, key id, string choice) {
        

        // Verify current Transform choice
        if (channel == channelAsk) {
            if (choice == "ask") {
                sendStateName();
            }
        }
    }*/

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
                kQuery = llGetNotecardLine("*" + currentState,lineno);

            }
        }
    }
}


