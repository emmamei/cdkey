//========================================
// MenuHandler.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 28 February 2014

#include "include/GlobalDefines.lsl"

#define LISTENER_ACTIVE 1
#define LISTENER_INACTIVE 0
#define NO_FILTER ""
#define cdListenAll(a)    llListen(a, NO_FILTER, NO_FILTER, NO_FILTER)
#define cdListenUser(a,b) llListen(a, NO_FILTER,         b, NO_FILTER)
#define cdListenMine(a)   llListen(a, NO_FILTER,    dollID, NO_FILTER)
#define cdListenerDeactivate(a) llListenControl(a, 0)
#define cdListenerActivate(a) llListenControl(a, 1)

// Current Controller - or Mistress
//key MistressID = NULL_KEY;
key poserID = NULL_KEY;
key dollID = NULL_KEY;
key menuID = NULL_KEY;
key uniqueID = NULL_KEY;

list windTimes = [ 30 ];

float timeLeftOnKey;
float windDefault = 1800.0;
float windRate = 1.0;
float baseWindRate = 1.0;
float collapseTime;
float displayWindRate = 1.0;

integer afk;
integer autoAFK = 1;
//integer autoTP;
//integer canAFK = 1;
integer canCarry = 1;
integer canDress = 1;
//integer canFly = 1;
//integer canSit = 1;
//integer canStand = 1;
integer canRepeat = 1;
//integer poseSilence;
//integer canWear;
//integer canUnwear;
integer carryMoved;
integer clearAnim;
integer collapsed;
integer configured;
integer demoMode;
//integer detachable = 1;
//integer doWarnings;
//integer helpless;
//integer pleasureDoll;
integer isTransformingKey;
integer visible = 1;
//integer quiet;
integer RLVok;
//integer signOn;
//integer takeoverAllowed;
//integer warned;
//integer offlineMode;
integer wearLock;
integer dbConfig;
integer textboxType;
//integer debugLevel = DEBUG_LEVEL;
integer startup = 1;

integer blacklistChannel;
integer textboxChannel;
integer controlChannel;
integer dialogChannel;
integer blacklistHandle;
integer textboxHandle;
integer controlHandle;
integer dialogHandle;
string isDollName;
string dollType = "Regular";
string pronounHerDoll = "Her";
string pronounSheDoll = "She";
string marketplaceURL = "";

vector gemColour;

string carrierName;
string mistressName;
string keyAnimation;
//string dollyName;
string nextMenu;
string menuName;

float winderRechargeTime;

list blacklist;
list dialogKeys;
list dialogNames;
list dialogButtons;

doDialogChannel() {
    // If no uniqueID has been generated for dolly generate a new one now
    if (uniqueID == NULL_KEY) lmSendConfig("uniqueID", (string)(uniqueID = llGenerateKey()));

    integer generateChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)uniqueID, -7, -1));
    if (dialogChannel != generateChannel) lmSendConfig("dialogChannel", (string)(dialogChannel = generateChannel));

    debugSay(2, "DEBUG-MENU", "Your unique key is " + (string)uniqueID + " primary dialogChannel is " + (string)dialogChannel);

    blacklistChannel = dialogChannel - 666;
    controlChannel = dialogChannel - 888;
    textboxChannel = dialogChannel - 1111;

    llListenRemove(dialogHandle);
    dialogHandle = cdListenAll(dialogChannel);
    cdListenerDeactivate(dialogHandle);
}

default
{
    state_entry() {
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);
    }

    link_message(integer sender, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);

        string script = llList2String(split, 0);

        if (code == 102) {
            if (script == "ServiceReceiver") {
                dbConfig = 1;
                doDialogChannel();
            }
            else if (data == "Start") configured = 1;
            scaleMem();
        }
        else if (code == 110) {
            lmInternalCommand("updateExceptions", "", NULL_KEY);

            startup = 0;
        }
        else if (code == 135) {
            float delay = llList2Float(split, 1);
            memReport(delay);
        }
        else if (code == 150) {
            string script = llList2String(split, 0);
            simRating = llList2String(split, 1);
        }
        else if (code == 300) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);
            split = llDeleteSubList(split, 0, 1);

                 if (name == "baseWindRate")             baseWindRate = (float)value;
            else if (name == "displayWindRate")       displayWindRate = (float)value;
            else if (name == "keyAnimation")             keyAnimation = value;
            else if (name == "pronounHerDoll")         pronounHerDoll = value;
            else if (name == "pronounSheDoll")         pronounSheDoll = value;
            else if (name == "marketplaceURL")         marketplaceURL = value;
            //else if (name == "dollyName")                   dollyName = value;
            else if (name == "afk")                               afk = (integer)value;
            //else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "canAFK")                         canAFK = (integer)value;
            else if (name == "canCarry")                     canCarry = (integer)value;
            else if (name == "canDress")                     canDress = (integer)value;
            else if (name == "canPose")                       canPose = (integer)value;
            else if (name == "canWear")                       canWear = (integer)value;
            else if (name == "wearLock")                     wearLock = (integer)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
            //else if (name == "canFly")                         canFly = (integer)value;
            //else if (name == "canSit")                         canSit = (integer)value;
            //else if (name == "canStand")                     canStand = (integer)value;
            //else if (name == "canRepeat")                   canRepeat = (integer)value;
            //else if (name == "poseSilence")               poseSilence = (integer)value;
            else if (name == "configured")                 configured = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                 debugLevel = (integer)value;
#endif
            else if (name == "detachable")                 detachable = (integer)value;
            else if (name == "demoMode")                     demoMode = (integer)value;
            //else if (name == "helpless")                     helpless = (integer)value;
            //else if (name == "pleasureDoll")             pleasureDoll = (integer)value;
            else if (name == "isTransformingKey")   isTransformingKey = (integer)value;
            else if (name == "quiet")                           quiet = (integer)value;
            //else if (name == "signOn")                         signOn = (integer)value;
            else if (name == "dialogChannel")           dialogChannel = (integer)value;
            else if (name == "poserID")                       poserID = (key)value;
            else if (name == "collapseTime")             collapseTime = (llGetTime() - (float)value);
            else if (name == "winderRechargeTime") winderRechargeTime = (float)value;
            else if (name == "gemColour") {
                if (gemColour != (vector)value) lmInternalCommand("setGemColour", value, NULL_KEY);
            }
            else if (name == "uniqueID") {
                if (script != "ServiceReceiver") return;
                uniqueID = (key)value;
            }
            else if (name == "timeLeftOnKey") {
                timeLeftOnKey = (float)value;
            }
            else if (name == "isVisible") {
                visible = (integer)value;
                llSetLinkAlpha(LINK_SET, (float)visible, ALL_SIDES);
            }
            else if (name == "dollType") {
                dollType = llGetSubString(llToUpper(value), 0, 0) + llGetSubString(llToLower(value), 1, -1);
            }
            else if ((name == "MistressList") || (name == "blacklist")) {
                integer i;
                for (i = 0; i < llGetListLength(split); i++) {
                    if (llList2String(split, i) == "") split = llDeleteSubList(split, i, i--);
                }

                if (name == "MistressList") {
                    MistressList = split;
                    if (!startup) lmInternalCommand("updateExceptions", "", NULL_KEY);
                }
                else blacklist = split;
            }
        }
        else if (code == 305) {
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llList2List(split, 2, -1);

            if (cmd == "carry") {
                // Doll has been picked up...
                carrierID = id;
                carrierName = llList2String(split, 0);
            }
            else if (cmd == "uncarry") {
                // Doll has been placed down...
                carrierID = NULL_KEY;
                carrierName = "";
            }
            else if (cmd == "setAFK") afk = llList2Integer(split, 0);
            else if (cmd == "collapse") {
                keyAnimation = ANIMATION_COLLAPSED;
                collapsed = 1;
            }
            else if (cmd == "uncollapse") {
                keyAnimation = "";
                collapsed = 0;
            }
            else if (cmd == "dialogListen") {
                cdListenerActivate(dialogHandle);
                llSetTimerEvent(60.0);
            }

            // Deny access to the menus when the command was recieved from blacklisted avatar
            if (llListFindList(blacklist, [ (string)id ]) != -1) {
                lmSendToAgent("You are not permitted to access this key.", id);
                return;
            }
            else if (cmd == "setGemColour") {
                string value = llList2String(split, 0);
                integer i; list params;

                if (gemColour != (vector)value) lmSendConfig("gemColour", (string)(gemColour = (vector)value));

                for (i = 0; i < llGetLinkNumberOfSides(4); i++) {
                    vector shade = <llFabs((llFrand(0.2) - 0.1) + gemColour.x), llFabs((llFrand(0.2) - 0.1) + gemColour.y), llFabs((llFrand(0.2) - 0.1) + gemColour.z)>;
                    float mag = llVecMag(shade);

                    if (llVecMag(shade) > 1.0) {
                        if (llVecMag(shade) < 1.2) shade = llVecNorm(shade);
                        else shade /= 256.0;
                    }

                    params += [ PRIM_COLOR, i, shade, 1.0 ];
                }

                params = [ PRIM_POINT_LIGHT, TRUE, gemColour, 0.350, 3.50, 2.00 ] + params;
                llSetLinkPrimitiveParamsFast(4, params + [ PRIM_LINK_TARGET, 5 ] + params);
            }
            else if (cmd == "mainMenu") {
                string msg; list menu; string manpage;

                // Compute "time remaining" message for mainMenu/windMenu
                string timeleft;

                integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));

                if (minsLeft > 0) {
                    timeleft = "Dolly has " + (string)minsLeft + " minutes remaining.\n";

                    timeleft += "Key is ";
                    if (windRate == 0.0) timeleft += "not ";
                    timeleft += "winding down";

                    if (windRate == 0.0) timeleft += ".";
                    else timeleft += " at " + formatFloat(displayWindRate, 1) + "x rate.";

                    timeleft += ". ";
                }
                else timeleft = "Dolly has no time left.";
                timeleft += "\n";

                // Handle our "special" states first which significantly alter the menu

                // When the doll is carried they have exclusive control
                if (hasCarrier) {
                    // Doll being carried clicked on key
                    if isDoll {
                        msg = "You are being carried by " + carrierName + ".";
                        menu = ["Help/Support"];
                    }

                    else if (isCarrier) {
                        msg = "Place Down frees " + dollName + " when you are done with " + pronounHerDoll;

                        menu += "Uncarry";
                    }

                    // Someone else clicked on key
                    else {
                        msg = dollName + " is currently being carried by " + carrierName + ". They have full control over this doll.\n";
                        menu = ["Help/Support"];
                    }
                    if (!isCarrier) {
                        llDialog(id, timeleft + msg, dialogSort(llListSort(menu, 1, 1)) , dialogChannel);
                        return;
                    }
                }
                // When the doll is collapsed they lose their access to most key functions with a few exceptions
                else if (collapsed && isDoll) {
                    msg = "You need winding.";
                    // Only present the TP home option for the doll if they have been collapsed
                    // for at least 900 seconds (15 minutes) - Suggested by Christina
                    if ((collapseTime + 900.0) < llGetTime()) {
                        if (llGetInventoryType(LANDMARK_HOME) == INVENTORY_LANDMARK) {
                            menu = ["TP Home"];
                        }
                        // If the doll is still down after 1800 seconds (30 minutes) and their emergency winder
                        // is recharged add a button for it
                        if (((collapseTime + 1800.0) < llGetTime()) && (winderRechargeTime == 0.0)) {
                            menu += ["Wind Emg"];
                        }
                    }
                }

                if (!collapsed && (!hasCarrier || isCarrier)) {
                    //not  being carried (or for carrier), not collapsed - normal in other words
                    // Toucher could be...
                    //   1. Doll
                    //   2. Carrier
                    //   3. Controller
                    //   4. Someone else

                    // Options only available to dolly
                    if (isDoll) {
                        if (!collapsed) {
                            menu += "Options";
                            if (detachable) menu += "Detach";
    
                            if (canAFK) menu += getButton("AFK", id, afk, 0);
    
                            menu += getButton("Visible", id, visible, 0);
                        }
                    }
                    else {
                        manpage = "communitydoll.htm";

                        // Toucher is not Doll.... could be anyone
                        msg =  dollName + " is a doll and likes to be treated like " +
                               "a doll. So feel free to use these options.\n";
                    }

                    // Can the doll be dressed? Add menu button
                    if (RLVok && !collapsed && ((!isDoll && canDress) || (isDoll && canWear && !wearLock))) {
                        menu += "Dress";
                    }

                    // Can the doll be transformed? Add menu button
                    if (!collapsed && isTransformingKey) {
                        menu += "Type of Doll";
                    }

                    if (!collapsed) {
                        if (keyAnimation != "") {
                            msg += "Doll is currently posed.\n";
    
                            if ((!isDoll && canPose) || (poserID == dollID)) {
                                menu += ["Pose","Unpose"];
                            }
                        }
                        else {
                            if ((!isDoll && canPose) || isDoll)
                                menu += "Pose";
                        }
                    }

                    if (!collapsed && ((numControllers == 0) || (isController && !isDoll))) {
                        if (canCarry) {
                            msg += "Carry option picks up " + dollName + " and temporarily" +
                                   " makes the Dolly exclusively yours.\n";

                            if (!hasCarrier) menu += "Carry";
                        }
                    }

#ifdef ADULT_MODE
                        // Is doll strippable?
                        if (RLVok && !collapsed && (pleasureDoll || dollType == "Slut")) {
#ifdef TESTER_MODE
                            if (isController || isCarrier || ((debugLevel != 0) && isDoll)) {
#else
                            if (isController || isCarrier) {
#endif
                                if (simRating == "MATURE" || simRating == "ADULT") menu += "Strip";
                            }
                        }
#endif
                }

#ifdef TESTER_MODE
                if ((debugLevel != 0) && isDoll) menu += "Wind";
#endif
                if (!isDoll) menu += "Wind";
                menu += "Help/Support";

                // Options only available if controller
                if (isController) {
                    if (!isDoll) menu += [ "Options" ];
                    if (!isDoll || !detachable) menu += [ "Detach" ];
                }
                
                if (!isDoll) {
                    if (marketplaceURL != "") menu += "Get a Key";
                }

                cdListenerActivate(dialogHandle);
                llSetTimerEvent(60.0);

                if (!RLVok) msg += "No RLV detected some features unavailable.\n";

                msg += "See " + WEB_DOMAIN + manpage + " for more information." ;
                llDialog(id, timeleft + msg, dialogSort(llListSort(menu, 1, 1)) , dialogChannel);
            }
        }
        else if (code == 350) {
            string script = llList2String(split, 0);
            RLVok = llList2Integer(split, 1);
        }
        else if (code == 500) {
            string script = llList2String(split, 0);
            string choice = llList2String(split, 1);
            
            if (choice == "Factory Reset") {
                textboxType = 4;
                if (textboxHandle) llListenRemove(textboxHandle);
                textboxHandle = cdListenUser(textboxChannel, id);
                llSetTimerEvent(60.0);
                string msg = "Are you sure you want to perform a factory reset, you will lose all your settings and your controllers will be notified.\n\n";
                if (script == SCRIPT_NAME) msg += "Type FACTORY RESET to confirm.";
                else msg += "You must type FACTORY RESET exactly to confirm.";
                llTextBox(dollID, msg, textboxChannel);
            }
        }
    }

    on_rez(integer start) {
        dbConfig = 0;
    }

    timer() {
        if (nextMenu != "") {
            lmInternalCommand(nextMenu, menuName, menuID);
            llSetTimerEvent(30.0);
        }
        else {
            if(blacklistHandle) { llListenRemove(blacklistHandle); blacklistHandle = 0; }
            if (controlHandle)  { llListenRemove(controlHandle);     controlHandle = 0; }
            if (textboxHandle)  { llListenRemove(textboxHandle);     textboxHandle = 0; }

            cdListenerDeactivate(dialogHandle);
            dialogKeys = []; dialogButtons = []; dialogNames = [];
            llSetTimerEvent(0.0);
        }

        nextMenu = "";
        menuName = "";
        menuID = NULL_KEY;
    }

    sensor(integer num) {
        integer i; dialogKeys = []; dialogNames = []; dialogButtons = [];
        if (num > 12) num = 12;
        for (i = 0; i < num; i++) {
            dialogKeys += llDetectedKey(i);
            dialogNames += llDetectedName(i);
            dialogButtons += llGetSubString(llDetectedName(i), 0, 23);
        }

        if (blacklistHandle) llDialog(dollID, "Select the avatar to be added to the blacklist.", dialogSort(dialogButtons + MAIN), blacklistChannel);
        else if (controlHandle) llDialog(dollID, "Select the avatar to be added to the controller list.", dialogSort(dialogButtons + MAIN), controlChannel);
    }

    no_sensor() {
        llDialog(dollID, "No avatars detected within chat range", [MAIN], dialogChannel);
    }

    touch_start(integer num) {
        integer i;
        for (i = 0; i < num; i++) {
            key id = llDetectedKey(i);
            if (startup) lmSendToAgent("Dolly's key is still establishing connections with " + llToLower(pronounHerDoll) + " systems please try again in a few minutes.", id);
            else lmInternalCommand("mainMenu", llGetDisplayName(id), id);
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {
        // channel = chat channel to listen on
        //    name = filter by prim name
        //     key = filter by avatar key
        //  choice = filter by specific message
        if (llListFindList(blacklist, [ (string)id ]) != -1) {
            lmSendToAgent("You are not permitted to access this key.", id);
            return;
        }

        list split = llParseStringKeepNulls(choice, [ " " ], []);

        string displayName = llGetDisplayName(id);
        if ((displayName != "") && (displayName != "???")) name = displayName;

        string optName = llDumpList2String(llList2List(split, 1, -1), " ");
        string curState = llList2String(split, 0);

        if (channel != textboxChannel) {
            debugSay(3, "DEBUG-MENU", "Button clicked: " + choice + ", optName=\"" + optName + "\", curState=\"" + curState + "\"");
            lmMenuReply(choice, name, id);

            menuID = id;
            menuName = name;
        }

        if (channel == dialogChannel) {
            integer isAbility; // Temporary variables used to determine if an option
            integer isFeature; // from the features or abilities menu was clicked that
                               // way we can restore it making setting several choices
                               // much more user friendly.

            if (choice == MAIN) {
                lmInternalCommand("mainMenu", "", id);
                return;
            }

            if (choice == "Get a Key") {
                llLoadURL(id, "To get your own free community doll key from our marketplace store click \"Go to page\"", marketplaceURL);
            }
            else if (choice == "Options") {
                string msg; list pluslist;
                if (isDoll) {
                    msg = "See " + WEB_DOMAIN + "keychoices.htm for explanation.";

                    pluslist += [ "Type...", "Access..." ];

                    if (isController) pluslist += "Abilities...";
                }
                else if (isController) {

                    msg = "See " + WEB_DOMAIN + "controller.htm. Choose what you want to happen.";

                    pluslist += [ "Abilities...", "Drop Control" ];
                    
                    if (llListFindList(BuiltinControllers, [(string)id]) != -1) pluslist += [ "Access..." ];
                }
                else return;

                pluslist += [ "Features...", "Key..." ];

                llDialog(id, msg, dialogSort(pluslist + MAIN), dialogChannel);
            }

            // Key menu is only shown for Controllers and for the Doll themselves
            else if (choice == "Key..." && (isController || isDoll)) {

                list pluslist = [ "Dolly Name", "Gem Colour" ];
                if (isController) pluslist += [ "Max Time", "Wind Times" ];
                llDialog(id, "Here you can set various general key settings.", dialogSort(llListSort(pluslist + MAIN, 1, 1)), dialogChannel);
            }

            // Max Winding Keys
            else if (llGetSubString(choice, 0, 3) == "Max ") {
                if (optName == "Time") {
                    llDialog(id, "You can set the maximum wind time here.  Dolly cannot be wound beyond this amount of time.\nDolly currently has " + (string)llRound(timeLeftOnKey / SEC_TO_MIN) +
                                 " left, if you choose a lower time than this they will lose time immidiately.", dialogSort([
                          "Max 60m", "Max 120m", "Max 180m",
                         "Max 240m", "Max 300m", "Max 360m",
                         "Max 420m", "Max 480m", "Max 540m",
                         "Max 600m", "Max 720m", MAIN
                    ]), dialogChannel);
                }
                else lmSendConfig("keyLimit", (string)((float)llGetSubString(optName, 0, -2) * SEC_TO_MIN));
            }
            else if (choice == "Wind Times") {
                textboxType = 3;
                if (textboxHandle) llListenRemove(textboxHandle);
                textboxHandle = cdListenUser(textboxChannel, id);
                llTextBox(id, "You can set the amount of time a wind gives to the dolly. Times are integers and can be separated by spaces, commas, or vertical bars (|).", textboxChannel);
            }
            else if (choice == "Dolly Name") {
                textboxType = 2;
                if (textboxHandle) llListenRemove(textboxHandle);
                textboxHandle = cdListenUser(textboxChannel, id);
                llTextBox(id, "You choose your own name to be used with the key here.", textboxChannel);
            }
            else if ((choice == "Gem Colour") || (llListFindList(COLOR_NAMES, [ choice ]) != -1)) {
                if ((choice != "CUSTOM") && (choice != "Gem Colour")) {
                    integer index = llListFindList(COLOR_NAMES, [ choice ]);
                    string choice = (string)llList2Vector(COLOR_VALUE, index);

                    lmInternalCommand("setGemColour", choice, id);
                }
                else if (choice == "CUSTOM") {
                    textboxType = 1;
                    if (textboxHandle) llListenRemove(textboxHandle);
                    textboxHandle = cdListenUser(textboxChannel, id);
                    llTextBox(id, "Here you can input a custom colour value\n\nSupported Formats:\nLSL Vector <0.900, 0.500, 0.000>\n" +
                                  "Web Format Hex #A4B355\nRGB Value 240, 120, 10", textboxChannel);
                    return;
                }

                string msg = "Here you can set various key settingd. (" + OPTION_DATE + " version)";
                list pluslist;

                pluslist = COLOR_NAMES;

                llDialog(id, msg, dialogSort(pluslist + MAIN), dialogChannel);
            }
            else if (choice == "Detach")
                lmInternalCommand("detach", "", id);
            else if (optName == "Visible") lmSendConfig("isVisible", (string)(visible = (curState == CROSS)));
            else if (choice == "Reload Config") {
                llResetOtherScript("Start");
            }
            else if (choice == "TP Home") {
                lmInternalCommand("TP", LANDMARK_HOME, id);
            }
            else if (optName == "AFK") {
                afk = (curState == CROSS);
                integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));
                lmInternalCommand("setAFK", (string)afk + "|0|" + formatFloat(windRate, 1) + "|" + (string)minsLeft, id);

                string nextMenu = "mainMenu";
                llSetTimerEvent(1.0);
            }
            if ((optName == "Blacklist") || (optName == "Controller")) {
                integer activeChannel; integer i;
                dialogKeys = []; dialogNames = []; dialogButtons = [];
                if (optName == "Blacklist") {
                    if (controlHandle) {
                        llListenRemove(controlHandle);
                        controlHandle = 0;
                    }
                    activeChannel = blacklistChannel;
                    for (i = 0; i < llGetListLength(blacklist); i++) {
                        dialogKeys += llList2Key(blacklist, i);
                        dialogNames += llList2String(blacklist, ++i);
                        dialogButtons += llGetSubString(llList2String(blacklist, i), 0, 23);
                    }
                    blacklistHandle = cdListenUser(blacklistChannel, dollID);
                }
                else {
                    if (blacklistHandle) {
                        llListenRemove(blacklistHandle);
                        blacklistHandle = 0;
                    }
                    activeChannel = controlChannel;
                    for (i = 0; i < llGetListLength(MistressList); i++) {
                        dialogKeys += llList2Key(MistressList, i);
                        dialogNames += llList2String(MistressList, ++i);
                        dialogButtons += llGetSubString(llList2String(MistressList, i), 0, 23);
                    }
                    controlHandle = cdListenUser(controlChannel, dollID);
                }

                if (curState == "⊕") {
                    if (llGetListLength(dialogKeys) < 11) {
                        llSensor("", "", AGENT, 20.0, PI);
                    }
                    else {
                        string msg = "You already have the maximum (11) entries in your ";
                        if (activeChannel == controlChannel) msg += "controller list, ";
                        else msg += "blacklist, ";
                        msg += "please remove one or more entries before attempting to add another.";
                        llRegionSayTo(id, 0, msg);
                    }
                }
                else if (curState == "⊖") {
                    string msg;
                    if (dialogKeys != []) msg = "Choose a person to remove from ";
                    else msg = "You currently have nobody listed in your ";

                    if (activeChannel == controlChannel) msg += "controller list.";
                    else msg += "blacklist.";

                    if (dialogKeys == []) {
                        msg += "did you mean to select the add option instead?.";
                        llRegionSayTo(id, 0, msg);
                        return;
                    }

                    llDialog(id, msg, dialogSort(llListSort(dialogButtons, 1, 1) + MAIN), activeChannel);
                    llSetTimerEvent(60.0);
                }
                else if (curState == "List") {
                    integer i; string output; list tempList;

                    if (optName == "Controller") output = "Allowed Controllers";
                    else output = "Blacklisted Avatars";
                    
                    if (llGetListLength(dialogNames) == 0) output = "No " + output;
                    else {
                        output += ":";

                        for (i = 0; i < llGetListLength(dialogNames); i++) output += "\n" + (string)(i+1) + ". " + llList2String(dialogNames, i);
                    }
                    
                    llOwnerSay(output);
                }
            }

            // Entering options menu section

            // Entering abilities menu section
            isAbility = 1;
            if (optName == "Self TP") lmSendConfig("helpless", (string)(curState == CHECK));
            else if (optName == "Self Dress") lmSendConfig("canWear", (string)(canWear = (curState == CROSS)));
            else if (optName == "Detachable") lmSendConfig("detachable", (string)(detachable = (curState == CROSS)));
            else if (optName == "Flying") lmSendConfig("canFly", (string)(curState == CROSS));
            else if (optName == "Sitting") lmSendConfig("canSit", (string)(curState == CROSS));
            else if (optName == "Standing") lmSendConfig("canStand", (string)(curState == CROSS));
            else if (optName == "Force TP") lmSendConfig("autoTP", (string)(curState == CROSS));
            else if (optName == "Pose Silence") lmSendConfig("poseSilence", (string)(curState == CROSS));
            else isAbility = 0; // Not an options menu item after all

            isFeature = 1; // Maybe it'a a features menu item
            if (optName == "Type Text") lmSendConfig("signOn", (string)(curState == CROSS));
            else if (optName == "Quiet Key") lmSendConfig("quiet", (string)(quiet = (curState == CROSS)));
            else if (optName == "Rpt Wind") lmSendConfig("canRepeat", (string)(curState == CROSS));
            else if (optName == "Carryable") lmSendConfig("canCarry", (string)(canCarry = (curState == CROSS)));
            else if (optName == "Outfitable") lmSendConfig("canDress", (string)(canDress = (curState == CROSS)));
            else if (optName == "Poseable") lmSendConfig("canPose", (string)(canPose = (curState == CROSS)));
            else if (optName == "Warnings") lmSendConfig("doWarnings", (string)(curState == CROSS));
            else if (optName == "Offline") lmSendConfig("offlineMode", (string)(curState == CROSS));
            else if (optName == "Allow AFK") {
                lmSendConfig("canAFK", (string)(canAFK = (curState == CROSS)));
                if (!canAFK && afk) {
                    afk = 0;
                    displayWindRate = setWindRate();
                    integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));
                    lmInternalCommand("setAFK", (string)afk + "|0|" + formatFloat(windRate, 1) + "|" + (string)minsLeft, id);
                }
            }
#ifdef ADULT_MODE
            else if (optName == "Pleasure Doll") lmSendConfig("pleasureDoll", (string)(curState == CROSS));
#endif
            else isFeature = 0;

            if (isAbility) {
                lmMenuReply("Abilities...", name, id);
            }
            else if (isFeature) {
                lmMenuReply("Features...", name, id);
            }

            if (isController && choice == "Drop Control") {
                integer index = llListFindList(MistressList, [ (string)id ]);
                if (index != -1) {
                    MistressList = llDeleteSubList(MistressList, index, index + 1);
                    lmSendConfig("MistressList", llDumpList2String(MistressList, "|"));
                }
            }

#ifdef ADULT_MODE
                // Strip items... only for Pleasure Doll and Slut Doll Types...
                list buttons = llListSort(["Top", "Bra", "Bottom", "Panties", "Shoes", "*ALL*"], 1, 1);
                if (choice == "Strip")
                    llDialog(id, "Take off:", dialogSort(buttons + MAIN), dialogChannel); // Do strip menu
                else if (llListFindList(buttons, [ choice ]) != -1)
                    lmStrip(choice);
#endif
        }

        if ((channel == blacklistChannel) || (channel == controlChannel)) {
            if (choice == MAIN) {
                lmInternalCommand("mainMenu", "", id);
                return;
            }
            
            string button = choice;
            integer index = llListFindList(dialogButtons, [ choice ]);
            string name = llList2String(dialogNames, index);
            string uuid = llList2String(dialogKeys, index);

            list tempList; integer i;
            dialogKeys = []; dialogNames = []; dialogButtons = [];
            if (channel == blacklistChannel) {
                if (blacklistHandle) {
                    llListenRemove(blacklistHandle);
                    blacklistHandle = 0;
                }
                for (i = 0; i < llGetListLength(blacklist); i++) {
                    dialogKeys += llList2Key(blacklist, i);
                    dialogNames += llList2String(blacklist, ++i);
                    dialogButtons += llGetSubString(llList2String(blacklist, i), 0, 23);
                }
            }
            else {
                if (controlHandle) {
                    llListenRemove(controlHandle);
                    controlHandle = 0;
                }
                for (i = 0; i < llGetListLength(MistressList); i++) {
                    dialogKeys += llList2Key(MistressList, i);
                    dialogNames += llList2String(MistressList, ++i);
                    dialogButtons += llGetSubString(llList2String(MistressList, i), 0, 23);
                }
            }
            
            index = llListFindList(dialogButtons, [ choice ]);

            if (channel == blacklistChannel) lmInternalCommand("addRemBlacklist", (string)uuid + "|" + name, id);
            else if (index != -1) lmInternalCommand("remMistress", (string)uuid + "|" + name, id);
            else lmInternalCommand("addMistress", (string)uuid + "|" + name, id);
        }

        // If the current channel is from a text input box, send the data using LinkMessage 501.
        if (channel == textboxChannel) {
            llListenRemove(textboxHandle);
            textboxHandle = 0;

            lmTextboxReply(textboxType, name, choice, id);
            if (textboxType == 4) {
                if (choice == "FACTORY RESET") {
                    llSleep(30.0);
                    llResetOtherScript("Start");
                }
            }
        }

        // Ideally the listener should be closing here and only reopened when we spawn another menu
        // other scripts also use the dialog listerner in this script.  Until they are writtent to send
        // a dialogListen command whenever they respawn a dialog we have to keep the listener open
        // at any sign of usage.
        llListenControl(dialogHandle, 1);
        llSetTimerEvent(60.0);
    }
}

