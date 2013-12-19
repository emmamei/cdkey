// 1 "Transform.lslp"
// 1 "<built-in>"
// 1 "<command-line>"
// 1 "Transform.lslp"
// 29 March: Formatting and general cleanup

//Aug 14, totally changing
//Nov. 12, adding compatibility with hypnosisHUD
// 1 "include/GlobalDefines.lsl" 1
// include/GlobalDefines.lsl
//
// Global preprocessor and variable definitions for the key
//
// 35 "include/GlobalDefines.lsl"
// Link messages
// 44 "include/GlobalDefines.lsl"
// Keys of important people in life of the Key:





// 1 "include/Utility.lsl" 1
//----------------------------------------
// Utility Functions
//----------------------------------------
string wwGetSLUrl() {
    string region = llGetRegionName();
    vector pos = llGetPos();
    string posx = (string)llRound(pos.x);
    string posy = (string)llRound(pos.y);
    string posz = (string)llRound(pos.z);

    return ("secondlife://" + llEscapeURL(region) +"/" + posx + "/" + posy + "/" + posz);
}

string bits2nybbles(integer bits)
{
    string nybbles = "";
    do
    {
        integer lsn = bits & 0xF; // least significant nybble
        nybbles = llGetSubString("0123456789ABCDEF", lsn, lsn) + nybbles;
    } while (bits = (0xfffFFFF & (bits >> 4)));
    return nybbles;
}

string formatFloat(float val, integer dp)
{
    string out = "ERROR";
    if (dp == 0) {
        out = (string)llRound(val);
    } else if (dp > 0 && dp <= 6) {
        val = llRound(val * llPow(10.0, dp)) / llPow(10.0, dp);
        out = llGetSubString((string)val, 0, -7 + dp);
    }
    return out;
}

memReport() {
    float free_memory = (float)llGetFreeMemory();
    float used_memory = (float)llGetUsedMemory();

    llOwnerSay(llGetScriptName() + ": Memory " + formatFloat(used_memory/1024.0, 2) + "/" + (string)llRound((used_memory + free_memory)/1024.0) + "kB, " + formatFloat(free_memory/1024.0, 2) + " kB free");
}
// 51 "include/GlobalDefines.lsl" 2
// 1 "include/KeySharedFuncs.lsl" 1
//-----------------------------------
// Internal Shared Functions
//-----------------------------------

float lastTimerEvent;

float setWindRate() {
    float newWindRate;
    vector agentPos = llList2Vector(llGetObjectDetails(dollID, [ OBJECT_POS ]), 0);
    integer agentInfo = llGetAgentInfo(dollID);
    integer windDown = (llGetAttached() == ATTACH_BACK) && !collapsed && dollType != "Builder" && dollType != "Key";

    newWindRate = 1.0;
    if (afk) newWindRate *= 0.5;

    if (windRate != newWindRate * windDown) {
        windRate = newWindRate * windDown;

        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "windRate" + "|" + (string)windRate,NULL_KEY);
    }

    // llTargetOmega: With normalized vector spinrate is equal to radians per second
    // 2𝜋 radians per rotation.  This sets a normal rotation rate of 4 rpm about the
    // Z axis multiplied by the wind rate this way the key will visually run faster as
    // the dolly begins using their time faster.
    llTargetOmega(llVecNorm(<0.0, 0.0, 1.0>), windRate * (TWO_PI / 15.0), 1);

    return newWindRate;
}

integer setFlags(integer clear, integer set) {
    integer oldFlags = globalFlags;
    globalFlags = (globalFlags & ~clear) | set;
    if (globalFlags != oldFlags) {
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "globalFlags" + "|" + "0x" + bits2nybbles(globalFlags),NULL_KEY);
        return 1;
    }
    else return 0;
}
// 52 "include/GlobalDefines.lsl" 2
// 6 "Transform.lslp" 2

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
integer RLVok;

integer startup = 1;

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

setup() {
    dollID = llGetOwner();
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

        channelHUD = ( -1 * (integer)("0x"+llGetSubString((string)llGetOwner(),-5,-1)) ) - 1114;
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

    llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "clothingFolder" + "|" + clothingprefix,NULL_KEY);
    llSleep(1.0);

    llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|" + "randomDress" + "|" +"", NULL_KEY);

    if (!quiet) llSay(0, dollname + " has become a " + stateName + " Doll.");
    else llOwnerSay("You have become a " + stateName + " Doll.");

    if (startup == 2) {
        llMessageLinked(LINK_THIS, 105, llGetScriptName(), NULL_KEY);
        startup = 0;
    }
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
    state_entry() { llMessageLinked(LINK_THIS, 999, llGetScriptName(), NULL_KEY); }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer iParam) {
        startup = 2;
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if ((change & CHANGED_INVENTORY) ||
            (change & CHANGED_ALLOWED_DROP)) {

            reloadTypeNames();
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() { //called everytimeinterval
        if (minMinutes > 0) {
            minMinutes--;
            }

        if (showPhrases) {
            integer i = (integer) llFrand(llGetListLength(currentphrases));

            // if no phrases to be used, exit
            if (i == 0) {
                return;
            }

            string phrase = llList2String(currentphrases, i);

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
                    if (currentState == "Domme") {
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
    link_message(integer source, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);
        string choice = llList2String(split, 0);

        if (code == 17) {

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

        else if (code == 102) {
            // Trigger Transforming Key setting
            llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "isTransformingKey" + "|" + "1",NULL_KEY);
            configured = 1;
            setDollType(stateName, 1);
        }

        else if (code == 104) {
            if (llList2String(split, 0) != "Start") return;
            setup();
            reloadTypeNames();
            startup = 1;

            llSetTimerEvent(60.0); // every minute

            cd8666 = ( -1 * (integer)("0x"+llGetSubString((string)llGetKey(),-5,-1)) ) - 8666;

            llMessageLinked(LINK_THIS, 104, llGetScriptName(), NULL_KEY);
        }

        else if (code == 105) {
            if (llList2String(split, 0) != "Dress") return;
            startup = 2;
            RLVok = 0;
            setDollType(stateName, 1);
        }

        else if (code == 135) memReport();

        else if (code == 300) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);

            if (script != llGetScriptName()) {
                if (name == "dollType") {
                    stateName = value;
                    if (!startup) setDollType(stateName, 0);
                }
                if (name == "quiet") quiet = (integer)value;
            }
        }

        else if (code == 350) {
            RLVok = llList2Integer(split, 0);
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
        else if (channel == cd8666 &&
            choice != "OK" && choice != "No") {

            //avoid = FALSE;

            llSay(DEBUG_CHANNEL,"transform = " + (string)transform);
            llSay(DEBUG_CHANNEL,"choice = " + (string)choice);
            llSay(DEBUG_CHANNEL,"stateName = " + (string)stateName);


            if (!startup) setDollType(choice, 0);
            llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "dollType" + "|" + stateName,NULL_KEY);
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
    dataserver(key query_id, string data) {
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
