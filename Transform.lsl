// 29 March: Formatting and general cleanup

//Aug 14, totally changing
//Nov. 12, adding compatibility with hypnosisHUD

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

//integer menulimit = 9;     // 1.5 minute

string currentState;
integer winddown;
integer mustAgreeToType;
integer showPhrases;
key dollID;
string clothingprefix;

key kQuery;

list currentphrases;

//========================================
// FUNCTIONS
//========================================
setup ()  {
    dollID =   llGetOwner();
    dollname = llGetDisplayName(dollID);
    stateName = "Regular";

    // Trigger Transforming Key setting
    llMessageLinked(LINK_THIS, 18, "here", dollID );

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
    types = [];
    integer n = llGetInventoryNumber(INVENTORY_NOTECARD);

    while(n) {
        types += llGetInventoryName(INVENTORY_NOTECARD, --n);
    }
}

//========================================
// STATES
//========================================
default {

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        setup();
        reloadTypeNames();

        llSetTimerEvent(60.0);   // every minute

        cd8666 = ( -1 * (integer)("0x"+llGetSubString((string)llGetKey(),-5,-1)) ) - 8666;

        //maxMinutes = -1;
        mustAgreeToType = FALSE;
        showPhrases = TRUE;
        //avoid = FALSE;
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer iParam) {
        setup();
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
    link_message(integer source, integer num, string choice, key id) {

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

            llSay(DEBUG_CHANNEL,"transform = " + (string)transform);
            llSay(DEBUG_CHANNEL,"choice = " + (string)choice);
            llSay(DEBUG_CHANNEL,"stateName = " + (string)stateName);

            if (choice == "Yes") {
                stateName = transform;
            } else {
                stateName = choice;
            }

            sendStateName();

            minMinutes = 5;
            currentState = stateName;
            clothingprefix = "*" + stateName;
            currentphrases = [];
            lineno = 0;
            kQuery = llGetNotecardLine(stateName,0);

            llMessageLinked(LINK_THIS, 2, clothingprefix, dollID);
            llSleep(1.0);

            llMessageLinked(LINK_THIS, 1, "random", dollID);
            llMessageLinked(LINK_THIS, 16, currentState, dollID);

            llSay(0, dollname + " has become a " + stateName + " Doll.");

            if (currentState == "Regular") {
               llSetText("", <1,1,1>, 2);
            } else {
               llSetText(stateName + " Doll", <1,1,1>, 2);
            }

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


