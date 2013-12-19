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

integer cd8666;
integer cd8667;
integer cd8665;

integer listen_id_8666;
integer listen_id_8667;
integer listen_id_8665;
integer listen_id_ask;
integer minMinutes = 0;
//integer maxMinutes;
//integer avoid;
integer channel_dialog;
integer channelHUD;
integer channelAsk;
integer configured;

//integer menulimit = 9;     // 1.5 minute

string currentState;
integer winddown;
integer mustAgreeToType;
integer showPhrases = TRUE;
key dollID;
string clothingprefix;

key kQuery;

list currentphrases;

integer quiet;

//========================================
// FUNCTIONS
//========================================
//---------------------------------------
// Configuration Functions
//---------------------------------------
// This code assumes a human-generated config file
processConfiguration(string name, list values) {
    //----------------------------------------
    // Assign values to program variables

    if (name == "doll type") {
        // Ensure proper capitalization for matching or display
        setDollType(llList2String(values, 0), 1);
    }
    else if (name == "quiet key") {
        quiet = llList2Integer(values, 0);
    }
}

setup()  {
    dollID =   llGetOwner();
    dollname = llGetDisplayName(dollID);
    stateName = "Regular";

    integer ncd = ( -1 * (integer)("0x"+llGetSubString((string)llGetKey(),-5,-1)) ) -1;
    if (channel_dialog != ncd) {

        llListenRemove(listen_id_8666);
        llListenRemove(listen_id_8665);
        llListenRemove(listen_id_8667);
        llListenRemove(listen_id_ask);

        channel_dialog = ncd;
        cd8666 = channel_dialog - 8666;
        cd8665 = cd8666 - 1;
        cd8667 = cd8666 + 1;

        listen_id_8665 = llListen( cd8665, "", "", "");
        listen_id_8666 = llListen( cd8666, "", "", "");
        listen_id_8667 = llListen( cd8667, "", "", "");

        channelHUD = ( -1 * (integer)("0x"+llGetSubString((string)llGetOwner(),-5,-1)) )  - 1114;
        channelAsk = channelHUD - 1;
        listen_id_ask = llListen( cd8665, "", "", "");
    }

    sendStateName();
}

setDollType(string choice, integer force) {
    if (force) {
        transform = llGetSubString(llToUpper(choice), 0, 0) + llGetSubString(llToLower(choice), 1, -1);
        choice = "Yes";
        minMinutes = 0;
    } else {
        minMinutes = 5;
    }
    
    if (choice == "Yes") stateName = transform;
    else stateName = choice;

    sendStateName();

    currentState = stateName;
    clothingprefix = "*" + stateName;
    currentphrases = [];
    lineno = 0;
    
    if (llGetInventoryType(stateName) == INVENTORY_NOTECARD) kQuery = llGetNotecardLine(stateName,0);

    llMessageLinked(LINK_THIS, 2, clothingprefix, dollID);
    llSleep(1.0);

    llMessageLinked(LINK_THIS, 1, "random", dollID);
    lmSendConfig("dollType", currentState, dollID);

    if (!quiet) llSay(0, dollname + " has become a " + stateName + " Doll.");
    else llOwnerSay("You have become a " + stateName + " Doll.");
}

sendStateName() {
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
}
    
reloadTypeNames() {
    string typeName;

    integer n = llGetInventoryNumber(INVENTORY_NOTECARD);
    types = [];

    while(n) {
        typeName = llGetInventoryName(INVENTORY_NOTECARD, --n);
        if (llGetSubString(typeName, 0, 10) != "Preferences") {
            types += typeName;
        }
    }
}

//========================================
// STATES
//========================================
default {

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() { lmScriptReset(); }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    //on_rez(integer iParam) {
        
    //}

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
    timer() {   //called everytimeinterval
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

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer source, integer num, string data, key id) {
        list parameterList = llParseString2List(data, [ "|" ], []);
        string choice = llList2String(parameterList, 0);
        
        if (num == 17) {

            // Doll must remain in a type for a period of time
            if (minMinutes > 0) {
                // Since the output goes to the listener "handle" of 9999, it is discarded silently
                llDialog(id,"The Doll " + dollname + " cannot be transformed right now. The Doll was recently transformed. Dolly can be transformed in " + (string)minMinutes + " minutes.",["OK"], 9999);
            }
            else {
                string msg = "These change the personality of " + dollname + " This Doll is currently a " + stateName + " Doll. What type of doll do you want the Doll to be?";
                list choices = types;

                llOwnerSay(choice + " is looking at your doll types.");

                if (id == dollID) {
                    choices += "Options";
                }

                integer channel;

                if (mustAgreeToType) {
                    channel = cd8665;
                } else {
                    channel = cd8666;
                }

                llDialog(id, msg, choices, channel);
            }
        }
        
        else if (num == 101) {
            if (!configured) processConfiguration(llList2String(parameterList, 0), llList2List(parameterList, 1, -1));
        }
        
        else if (num == 102) {
            // Trigger Transforming Key setting
            lmSendConfig("isTransformingKey", (string)1, NULL_KEY);
            configured = 1;
        }
        
        else if (num == 104) {
            setup();
            reloadTypeNames();
    
            llSetTimerEvent(60.0);   // every minute
    
            cd8666 = ( -1 * (integer)("0x"+llGetSubString((string)llGetKey(),-5,-1)) ) - 8666;
    
            llMessageLinked(LINK_SET, 103, llGetScriptName(), NULL_KEY);
        }
        
        else if (num == 105) {
            setup();
            llMessageLinked(LINK_SET, 103, llGetScriptName(), NULL_KEY);
        }
        
        else if (num == 135) memReport();
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {
        if (choice == "Options") {
            list choices;

            if (mustAgreeToType == TRUE) {
                choices = ["no verify"];
            } else {
                choices = ["verify"];
            }

            if (showPhrases == TRUE) {
                choices += ["no phrases"];
            } else {
                choices += ["phrases"];
            }

            llDialog(dollID,"Options",choices, cd8667);
        }

        // Verify current Transform choice
        else if (channel == cd8665) {
            transform = choice;
            list choices = ["Yes", "No"];

            string msg = "Do you wish to transform to a " + choice + " Doll?";

            llDialog(dollID, msg, choices, cd8667);
            //avoid = TRUE;
        }
        
        // Make transformation
        else if (channel == cd8666 && \
            choice != "OK" && choice != "No") {

            //avoid = FALSE;
#ifdef DEVELOPER_MODE
            llSay(DEBUG_CHANNEL,"transform = " + (string)transform);
            llSay(DEBUG_CHANNEL,"choice = " + (string)choice);
            llSay(DEBUG_CHANNEL,"stateName = " + (string)stateName);
#endif

            setDollType(choice, 0);
        // Set options - "Options"
        } else if (channel == cd8667) {
            if (choice == "verify") {
                mustAgreeToType = TRUE;
                llOwnerSay("Changes in Doll Types will be verified.");
            }
            else if (choice == "no verify") {
                mustAgreeToType = FALSE;
                llOwnerSay("Changes in Doll Types will not be verified.");
            }
            else if (choice == "no phrases") {
                showPhrases = FALSE;
                llOwnerSay("No hypnotic phrases will be displayed.");
            }
            else if (choice == "phrases") {
                showPhrases = TRUE;
                llOwnerSay("Hypnotic phrases will be displayed.");
            }
        }
        else if (channel == channelAsk) {
            if (choice == "ask") {
                sendStateName();
            }
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
                kQuery = llGetNotecardLine(currentState,lineno);

            }
        }
    }
}



