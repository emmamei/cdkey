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
#define cdMenuInject(a) lmMenuReply((a),name,id);
#define cdResetKey() llResetOtherScript("Start")

// Wait for the user for 5 minutes - but for a program, only
// wait 60s. The request for a dialog menu should happen before then -
// and change the timeout to wait for a user.
#define MENU_TIMEOUT 600.0
#define SYS_MENU_TIMEOUT 60.0

#define BLACKLIST_CHANNEL_OFFSET 666
#define CONTROL_CHANNEL_OFFSET 888

//========================================
// VARIABLES
//========================================
// Current Controller - or Mistress
//key MistressID = NULL_KEY;
key poserID = NULL_KEY;
key dollID = NULL_KEY;
key menuID = NULL_KEY;

// does this need to be a global?
key uniqueID = NULL_KEY;

//list windTimes = [ 30 ];

float timeLeftOnKey;
float windDefault = WIND_DEFAULT;
float collapseTime;

integer afk;
integer autoAFK = 1;
//integer autoTP;
//integer canAFK = 1;
integer canCarry = 1;
integer canDress = 1;
integer canDressSelf = 1;
//integer canFly = 1;
//integer canSit = 1;
//integer canStand = 1;
integer canRepeat = 1;
//integer poseSilence;
//integer canDressSelf;
//integer canUnwear;
integer carryMoved;
integer primLight = 1;
integer clearAnim;
integer collapsed;
integer configured;
integer demoMode;
//integer detachable = 1;
//integer doWarnings;
//integer tpLureOnly;
//integer pleasureDoll;
//integer isTransformingKey;
integer visible = 1;
//integer quiet;
integer RLVok = -1;
//integer signOn;
//integer takeoverAllowed;
//integer warned;
//integer offlineMode;
integer wearLock;
integer dbConfig;
integer textboxType;
integer debugLevel = DEBUG_LEVEL;
//integer startup = 1;

integer blacklistChannel;
integer controlChannel;
integer dialogChannel;
integer blacklistHandle;
integer controlHandle;
integer dialogHandle;
string isDollName;
string dollType = "Regular";
string pronounHerDoll = "Her";
string pronounSheDoll = "She";
#ifdef MARKETPLACE
string marketplaceURL = "";
#endif

vector gemColour;

string carrierName;
string mistressName;
string keyAnimation;
//string dollyName;
string menuName;

integer winderRechargeTime;

list blacklist;
list dialogKeys;
list dialogNames;
list dialogButtons;

//========================================
// FUNCTIONS
//========================================

// This function generates a new dialogChannel and opens it -
// EVERY time it is called... possibly for a security feature
// using a dialogChannel periodic change setup

doDialogChannel() {
    // generate a uniqueID for dolly to use
    lmSendConfig("uniqueID", (string)(uniqueID = llGenerateKey()));
    debugSay(2, "DEBUG-MENU", "Your unique key is " + (string)uniqueID);

    integer generateChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)uniqueID, -7, -1));

    lmSendConfig("dialogChannel", (string)(dialogChannel = generateChannel));
    debugSay(2, "DEBUG-MENU", "Dialog channel is set to " + (string)dialogChannel);
    llSleep(2); // Make sure dialogChannel setting has time to propogate

    blacklistChannel = dialogChannel - BLACKLIST_CHANNEL_OFFSET;
    controlChannel = dialogChannel - CONTROL_CHANNEL_OFFSET;

    llListenRemove(dialogHandle);
    dialogHandle = cdListenAll(dialogChannel);

    // Deactivate listener for finer control - but this is not yet ready
    //cdListenerDeactivate(dialogHandle);
    debugSay(2, "DEBUG-MENU", "Dialog Handle is set....");
}

//========================================
// STATES
//========================================
default
{
    //----------------------------------------
    // STATE ENTRy
    //----------------------------------------
    state_entry() {
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);

        cdInitializeSeq();
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        RLVok = -1;
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer sender, integer i, string data, key id) {

        // Parse link message header information
        list split        =     cdSplitArgs(data);
        string script     =     cdListElement(split, 0);
        integer remoteSeq =     (i & 0xFFFF0000) >> 16;
        integer optHeader =     (i & 0x00000C00) >> 10;
        integer code      =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        if (code == 102) {
            //if (script == "ServiceReceiver") dbConfig = 1;
            //else
            if (data == "Start") configured = 1;

            debugSay(4, "DEBUG-MENU", "Setting dialog channel...");
            doDialogChannel();
            scaleMem();
        }
        else if (code == 110) {
            //startup = 0;
            lmInternalCommand("setGemColour", (string)gemColour, NULL_KEY);
        }
        else if (code == 135) {
            float delay = llList2Float(split, 0);
            memReport(cdMyScriptName(),delay);
        }
        else

        cdConfigReport();

        else if (code == 150) {
            simRating = llList2String(split, 0);
        }
        else if (code == 300) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);
            split = llDeleteSubList(split, 0, 0);
            string c = cdGetFirstChar(name);

            if (value == RECORD_DELETE) {
                value = "";
                split = [];
            }

                 if (name == "timeLeftOnKey")           timeLeftOnKey = (float)value;
            else if (name == "collapseTime") {
                // value is the amount of time the Dolly has been down (in negative s)
                if ((float)value != 0.0)                 collapseTime = (llGetTime() + (float)value);
                else                                     collapseTime = 0.0;
            }
            else if (name == "baseWindRate")             baseWindRate = (float)value;
            else if (name == "winderRechargeTime") winderRechargeTime = (integer)value;
            else if (name == "displayWindRate") {
                if ((float)value != 0) displayWindRate = (float)value;
            }
            else if (name == "keyAnimation")             keyAnimation = value;
#ifdef MARKETPLACE
            else if (name == "marketplaceURL")         marketplaceURL = value;
#endif
            else if (name == "afk")                               afk = (integer)value;
            //else if (name == "autoTP")                         autoTP = (integer)value;

            // have to test before shortcut "c" because of compound conditional: "controllers"
            else if ((name == "controllers") || (name == "blacklist")) {
                integer i;
                for (; i < llGetListLength(split); i++) {
                    if (llList2String(split, i) == "") split = llDeleteSubList(split, i, i--);
                }

                if (name == "controllers") {
                    controllers = split;
                    //if (!startup) lmInternalCommand("updateExceptions", "", NULL_KEY);
                    lmInternalCommand("updateExceptions", "", NULL_KEY);
                }
                else blacklist = split;
            }

            // shortcut: c
            else if (c == "c") {
                     if (name == "carrierID")                   carrierID = (key)value;
                else if (name == "canAFK")                         canAFK = (integer)value;
                else if (name == "canCarry")                     canCarry = (integer)value;
                else if (name == "canDress")                     canDress = (integer)value;
                else if (name == "canPose")                       canPose = (integer)value;
                else if (name == "canDressSelf")             canDressSelf = (integer)value;
                else if (name == "collapsed")                   collapsed = (integer)value;
                else if (name == "configured")                 configured = (integer)value;
                //else if (name == "canFly")                         canFly = (integer)value;
                //else if (name == "canSit")                         canSit = (integer)value;
                //else if (name == "canStand")                     canStand = (integer)value;
                //else if (name == "canRepeat")                   canRepeat = (integer)value;
            }
            else if (name == "wearLock")                     wearLock = (integer)value;
            else if (name == "RLVok")                           RLVok = (integer)value;

            // shortcut: d
            else if (c == "d") {
                     if (name == "dialogChannel")           dialogChannel = (integer)value;
                else if (name == "detachable")                 detachable = (integer)value;
                else if (name == "demoMode")                     demoMode = (integer)value;
                else if (name == "dollType") {
                    // this script is the only one with this sort of "protected" setting... is it needed?
                    //dollType = llGetSubString(llToUpper(value), 0, 0) + llGetSubString(llToLower(value), 1, -1);
                    dollType = value;
                }
#ifdef DEVELOPER_MODE
                else if (name == "debugLevel")                 debugLevel = (integer)value;
#endif
                //else if (name == "dollyName")                   dollyName = value;
            }

            // shortcut: p
            else if (c == "p") {
                     if (name == "poserID")                       poserID = (key)value;
                //else if (name == "poseSilence")               poseSilence = (integer)value;
                else if (name == "primLight") {
                    primLight = (integer)value;
                    lmInternalCommand("setGemColour", (string)gemColour, NULL_KEY);
                }
#ifdef ADULT_MODE
                else if (name == "pleasureDoll")             pleasureDoll = (integer)value;
#endif
                else if (name == "pronounHerDoll")         pronounHerDoll = value;
                else if (name == "pronounSheDoll")         pronounSheDoll = value;
            }
            //else if (name == "tpLureOnly")               tpLureOnly = (integer)value;
            //else if (name == "isTransformingKey")   isTransformingKey = (integer)value;
            else if (name == "quiet")                           quiet = (integer)value;
            //else if (name == "signOn")                         signOn = (integer)value;
            //else if (name == "uniqueID") {
            //    if (script != "ServiceReceiver") return;
            //    uniqueID = (key)value;
            //}
            else if (name == "isVisible") {
                visible = (integer)value;
                llSetLinkAlpha(LINK_SET, (float)visible, ALL_SIDES);
            }
        }
        else if (code == 305) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);


            // Deny access to the menus when the command was recieved from blacklisted avatar
            if (llListFindList(blacklist, [ (string)id ]) != -1) {
                lmSendToAgent("You are not permitted to access this key.", id);
                return;
            }

            if (cmd == "dialogListen") {
                doDialogChannel();
                cdListenerActivate(dialogHandle);
                llSetTimerEvent(MENU_TIMEOUT);
            }
            else if (cmd == "dialogClose") {
                cdListenerDeactivate(dialogHandle);
                llSetTimerEvent(0.0);
                dialogKeys = []; dialogButtons = []; dialogNames = [];

                menuName = "";
                menuID = NULL_KEY;
            }
            else if (cmd == "setGemColour") {
                vector newColour = (vector)llList2String(split, 0);
                integer i; integer j; integer s; list params; list colourParams;

                for (i = 1; i < llGetNumberOfPrims(); i++) {
                    params += [ PRIM_LINK_TARGET, i ];
                    if (llGetSubString(llGetLinkName(i), 0, 4) == "Heart") {
                        if (gemColour != newColour) {
                            if (!s) {
                                for (j = 0; j < llGetLinkNumberOfSides(i); j++) {
                                    vector shade = <llFrand(0.2) - 0.1 + newColour.x, llFrand(0.2) - 0.1 + newColour.y, llFrand(0.2) - 0.1 + newColour.z> * (1.0 + (llFrand(0.2) - 0.1));

                                    if (shade.x < 0.0) shade.x = 0.0;
                                    if (shade.y < 0.0) shade.y = 0.0;
                                    if (shade.z < 0.0) shade.z = 0.0;

                                    if (shade.x > 1.0) shade.x = 1.0;
                                    if (shade.y > 1.0) shade.y = 1.0;
                                    if (shade.z > 1.0) shade.z = 1.0;

                                    colourParams += [ PRIM_COLOR, j, shade, 1.0 ];
                                }
                                params += colourParams;
                                s = 1;
                            }
                            else params += colourParams;
                        }
                    }
                }
                llSetLinkPrimitiveParamsFast(0, params);
                if (gemColour != newColour) {
                    lmSendConfig("gemColour", (string)(gemColour = newColour));
                }
                params = [];
            }
            else if (cmd == "updateExceptions") {

                // Exempt builtin or user specified controllers from TP restictions

                list allow = BUILTIN_CONTROLLERS + cdList2ListStrided(controllers, 0, -1, 2);

                // Also exempt the carrier StatusRLV will ignore the duplicate if carrier is a controller so save work

                if cdCarried() allow += carrierID;

                // Directly dump the list using the static parts of the RLV command as a seperator no looping

                lmRunRLVas("Base", "clear=tplure:,tplure:"          + llDumpList2String(allow, "=add,tplure:")    + "=add");
                lmRunRLVas("Base", "clear=accepttp:,accepttp:"      + llDumpList2String(allow, "=add,accepttp:")  + "=add");
                lmRunRLVas("Base", "clear=sendim:,sendim:"          + llDumpList2String(allow, "=add,sendim:")    + "=add");
                lmRunRLVas("Base", "clear=recvim:,recvim:"          + llDumpList2String(allow, "=add,recvim:")    + "=add");
                lmRunRLVas("Base", "clear=recvchat:,recvchat:"      + llDumpList2String(allow, "=add,recvchat:")  + "=add");
                lmRunRLVas("Base", "clear=recvemote:,recvemote:"    + llDumpList2String(allow, "=add,recvemote:") + "=add");

                // Apply exemptions to base RLV
            }
            else if (cmd == "mainMenu") {
                string msg; list menu; string manpage; string windButton = llList2String(split, 0);

                //if (startup) lmSendToAgent("Dolly's key is still establishing connections with " + llToLower(pronounHerDoll) + " systems please try again in a few minutes.", id);

                if (llListFindList(blacklist, [ (string)id ]) == NOT_FOUND) {
                    // Cache access test results
                    integer hasCarrier      = cdCarried()  ;
                    integer isCarrier       = cdIsCarrier(id)       || cdIsBuiltinController(id);
                    integer isController    = cdIsController(id);
                    integer isDoll          = cdIsDoll(id);
                    integer numControllers  = cdControllerCount();

                    // Compute "time remaining" message for mainMenu/windMenu
                    string timeleft;

                    integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));

                    if (minsLeft > 0) {
                        timeleft = "Dolly has " + (string)minsLeft + " minutes remaining.\n";

                        timeleft += "Key is ";
                        if (windRate == 0.0) timeleft += "not winding down.\n";
                        else timeleft += "winding down at " + formatFloat(displayWindRate, 1) + "x rate.\n";
                    }
                    else timeleft = "Dolly has no time left.\n";

                    // Handle our "special" states first which significantly alter the menu

                    // When the doll is carried they have exclusive control
                    if (hasCarrier) {
                        // Doll being carried clicked on key
                        if (isDoll) {
                            msg = "You are being carried by " + carrierName + ". ";
                            menu = ["Help..."];
                        }
                        else if (isCarrier) {
                            msg = "Uncarry frees " + dollName + " when you are done with " + pronounHerDoll;
                            menu = ["Uncarry"];
                        }

                        // Someone else clicked on key
                        else {
                            msg = dollName + " is currently being carried by " + carrierName + ". They have full control over this doll.\n";
                            menu = ["Help..."];
                        }
                        if (!isCarrier) {
                            llDialog(id, timeleft + msg, dialogSort(llListSort(menu, 1, 1)) , dialogChannel);
                            return;
                        }
                    }

                    // When the doll is collapsed they lose their access to most
                    // key functions with a few exceptions

                    else if (collapsed && isDoll) {
                        msg = "You need winding. ";

                        // is it possible to be collapsed but collapseTime be equal to 0.0?
                        if (collapseTime != 0.0) {
                            float timeCollapsed = llGetTime() - collapseTime;

                            // Only present the TP home option for the doll if they have been collapsed
                            // for at least 900 seconds (15 minutes) - Suggested by Christina

                            if (timeCollapsed > 900.0) {
                                if (llGetInventoryType(LANDMARK_HOME) == INVENTORY_LANDMARK) {
                                    menu = ["TP Home"];
                                }

                                // If the doll is still down after 1800 seconds (30 minutes) and their
                                // emergency winder is recharged add a button for it

                                if ((timeCollapsed > 1800.0) && (winderRechargeTime <= llGetUnixTime())) {
                                    menu += ["Wind Emg"];
                                }
                            }
                        }
                    }

                    if (!collapsed && (!hasCarrier || isCarrier)) {
                        // State: not collapsed; and either: a) toucher is carrier; or b) doll has no carrier...
                        //
                        // Toucher could be...
                        //   1. Doll
                        //   2. Carrier
                        //   3. Controller
                        //   4. Someone else

                        // Options only available to dolly
                        if (isDoll) {
                            menu += "Options...";
                            if (detachable) menu += "Detach";

                            if (canAFK) menu += "AFK";

                            menu += "Visible";
                        }
                        else {
                            manpage = "communitydoll.htm";

                            // Toucher is not Doll.... could be anyone
                            msg =  dollName + " is a doll and likes to be treated like " +
                                   "a doll. So feel free to use these options.\n";
                        }

                        // Can the doll be dressed? Add menu button
                        if (RLVok == 1) {
                            if (isDoll) {
                                if (canDressSelf && !wearLock) menu += "Outfits...";
                            } else {
                                if (canDress) menu += "Outfits...";
                            }
                        }

                        // Can the doll be transformed? Add menu button
                        //if (isTransformingKey) menu += "Types...";
                        menu += "Types...";

                        if (keyAnimation != "") {
                            msg += "Doll is currently posed.\n";

                            if ((!isDoll && canPose) || (poserID == dollID)) {
                                menu += ["Poses...","Unpose"];
                            }
                        }
                        else {
                            if ((!isDoll && canPose) || isDoll)
                                menu += "Poses...";
                        }

                        // Fix for issue #157
                        if (!isDoll) {
                            if (canCarry) {
                                msg += "Carry option picks up " + dollName + " and temporarily makes the Dolly exclusively yours.\n";

                                if (!hasCarrier) menu += "Carry";
                            }
                        }

#ifdef ADULT_MODE
                        // Is doll strippable?
                        if ((RLVok == 1) && (pleasureDoll || dollType == "Slut")) {
                            if (isController || isCarrier
#ifdef TESTER_MODE
                                    || ((debugLevel != 0) && isDoll)
#endif
                            ) {
                                    if (simRating == "MATURE" || simRating == "ADULT") menu += "Strip...";
                            }
                        }
#endif
                    }

#ifdef TESTER_MODE
                    if ((debugLevel != 0) && isDoll) menu += windButton;
#endif
                    if (!isDoll) menu += windButton;
                    menu += "Help...";

                    // Options only available if controller
                    if (isController) {
                        if (!isDoll) menu += [ "Options...","Detach" ];
                        else if (!detachable) menu += [ "Detach" ];
                    }

#ifdef MARKETPLACE
                    if (!isDoll) {
                        if (marketplaceURL != "") menu += "Get a Key";
                    }
#endif

                    if (RLVok == -1) msg += "Still checking for RLV support some features unavailable.\n";
                    else if (RLVok == 0) {
                        msg += "No RLV detected some features unavailable.\n";
                        if (cdIsDoll(id) || cdIsController(id)) menu += "*RLV On*";
                    }

                    msg += "See " + WEB_DOMAIN + manpage + " for more information."

#ifdef DEVELOPER_MODE
                    + " (Key is in Developer Mode.)"
#else
#ifdef TESTER_MODE
                    + " (Key is in Tester Mode.)"
#endif
#endif
                    ;

                    menu = llListSort(menu, 1, 1);

                    integer i;
                    if ((i = llListFindList(menu, ["AFK"]))     != NOT_FOUND) menu = llListReplaceList(menu, cdGetButton("AFK",     id, afk,     0), i, i);
                    if ((i = llListFindList(menu, ["Visible"])) != NOT_FOUND) menu = llListReplaceList(menu, cdGetButton("Visible", id, visible, 0), i, i);

                    msg = timeleft + msg;
                    timeleft = "";
                }
                else {
                    msg = "You are not permitted any access to this dolly's key.";

                    menu = ["Leave Alone"];
                }

                cdListenerActivate(dialogHandle);
                llSetTimerEvent(MENU_TIMEOUT);

                llDialog(id, msg, dialogSort(menu), dialogChannel);
            }
        }
        else if (code == 350) {
            string script = llList2String(split, 0);
            RLVok = llList2Integer(split, 1);

            lmInternalCommand("updateExceptions", "", NULL_KEY);
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
        llSetTimerEvent(0.0);

        if (blacklistHandle) { llListenRemove(blacklistHandle); blacklistHandle = 0; }
        if (controlHandle)   { llListenRemove(controlHandle);     controlHandle = 0; }

        //cdListenerDeactivate(dialogHandle);
        dialogKeys = [];
        dialogButtons = [];
        dialogNames = [];

        menuName = "";
        menuID = NULL_KEY;
    }

    //----------------------------------------
    // SENSOR
    //----------------------------------------
    sensor(integer num) {
        integer i;
        integer channel;
        string type;
        list current;

        key foundKey;
        string foundName;

        dialogKeys = [];
        dialogNames = [];
        dialogButtons = [];

        if (controlHandle) {
            channel = controlChannel;
            type = "controller list";
            current = cdList2ListStrided(controllers, 0, -1, 2);
        }
        else {
            channel = blacklistChannel;
            type = "blacklist";
            current = cdList2ListStrided(blacklist, 0, -1, 2);
        }

        while ((i < num) && (llGetListLength(dialogButtons) < 12)) {
            foundKey = llDetectedKey(i);
            foundName = llDetectedName(i);

            if (llListFindList(current, [(string)foundKey]) == -1) { // Don't list existing users
                dialogKeys += foundKey;
                dialogNames += foundName;
                dialogButtons += llGetSubString(foundName, 0, 23);
            }

            i++;
        }

        llDialog(dollID, "Select the avatar to be added to the " + type + ".", dialogSort(dialogButtons + MAIN), channel);
    }

    //----------------------------------------
    // NO SENSOR
    //----------------------------------------
    no_sensor() {
        llDialog(dollID, "No avatars detected within chat range", [MAIN], dialogChannel);
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {
        // channel = chat channel to listen on
        //    name = filter by prim name
        //     key = filter by avatar key
        //  choice = filter by specific message
        // Deny access to the menus when the command was recieved from blacklisted avatar
        if (llListFindList(blacklist, [ (string)id ]) != NOT_FOUND) {
            lmSendToAgent("You are not permitted to access this key.", id);
            return;
        }

        // Cache access test results
        integer hasCarrier      = cdCarried();
        integer isCarrier       = cdIsCarrier(id)       || cdIsBuiltinController(id);
        integer isController    = cdIsController(id);
        integer isDoll          = cdIsDoll(id);
        integer numControllers  = cdControllerCount();

        list split = llParseStringKeepNulls(choice, [ " " ], []);

        name = llGetDisplayName(id); // FIXME: name can get set to ""

        integer space = llSubStringIndex(choice, " ");
        // 04-03-2014 Dev-Note:
        // Varnames for these two sub strings have changed, current usage makes them misleading.
        string beforeSpace = llStringTrim(llGetSubString(choice, 0, space),STRING_TRIM);
        string afterSpace = llDeleteSubString(choice, 0, space);

        //debugSay(3, "DEBUG-MENU", "Button clicked: " + choice + ", afterSpace=\"" + afterSpace + "\", beforeSpace=\"" + beforeSpace + "\"");

        lmMenuReply(choice, name, id);

        menuID = id;
        menuName = name;

        // Answer to one of three channels:
        //    * dialogChannel
        //    * blacklistChannel
        //    * controllerChannel
        if (channel == dialogChannel) {

            if (space == NOT_FOUND) {
                if (choice == "Options...") {
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
#ifdef MARKETPLACE
                else if (choice == "Get a Key") llLoadURL(id, "To get your own free community doll key from our marketplace store click \"Go to page\"", marketplaceURL);
#endif
                else if (choice == "Detach") { lmInternalCommand("detach", "", id); }
                else if (choice == "Reload Config") {
                    cdResetKey();
                }
                else if (choice == "TP Home") {
                    lmInternalCommand("TP", LANDMARK_HOME, id);
                }
            }
            else {
                // Space Found in Menu Selection
                     if (afterSpace == "Visible") lmSendConfig("isVisible", (string)(visible = (beforeSpace == CROSS)));
                else if (afterSpace == "AFK") {
                    lmSendConfig("afk", (string)(afk = (beforeSpace == CROSS)));
                    float factor = 2.0;

                    if (afk) factor = 0.5;

                    displayWindRate *= factor;
                    windRate *= factor;

                    lmInternalCommand("setAFK", (string)afk + "|0|" + formatFloat(windRate, 1) + "|" + (string)llRound(timeLeftOnKey / (60.0 * displayWindRate)),id);

                    lmMenuReply(MAIN, name, id);
                }
                else if ((afterSpace == "Blacklist") || (afterSpace == "Controller")) {
                    integer activeChannel; string msg;

                    if (afterSpace == "Blacklist") {
                        if (controlHandle) {
                            llListenRemove(controlHandle);
                            controlHandle = 0;
                        }

                        activeChannel = blacklistChannel;
                        msg = "blacklist";
                        dialogKeys  = cdList2ListStrided(blacklist, 0, -1, 2);
                        dialogNames = cdList2ListStrided(blacklist, 1, -1, 2);
                        blacklistHandle = cdListenUser(blacklistChannel, id);
                    }
                    else {
                        if (blacklistHandle) {
                            llListenRemove(blacklistHandle);
                            blacklistHandle = 0;
                        }

                        activeChannel = controlChannel;
                        msg = "controller list";
                        dialogKeys  = cdList2ListStrided(controllers, 0, -1, 2);
                        dialogNames = cdList2ListStrided(controllers, 1, -1, 2);
                        controlHandle = cdListenUser(controlChannel, id);
                    }

                    // Only need this once now, make dialogButtons = numbered list of names truncated to 24 char limit
                    dialogButtons = []; integer i; integer n = llGetListLength(dialogKeys);
                    for (i = 0; i < n; i++) dialogButtons += llGetSubString((string)(i+1) + ". " + llList2String(dialogNames, i), 0, 23);

                    if (beforeSpace == CIRCLE_PLUS) {
                        if (llGetListLength(dialogKeys) < 11) {
                            llSensor("", "", AGENT, 20.0, PI);
                        }
                        else {
                            msg = "You already have the maximum (11) entries in your " + msg + " please remove one or more entries before attempting to add another.";
                            llRegionSayTo(id, 0, msg);
                        }
                    }
                    else if (beforeSpace == CIRCLE_MINUS) {
                        if (dialogKeys == []) {
                            msg = "You currently have nobody listed in your " + msg + " did you mean to select the add option instead?.";
                            llRegionSayTo(id, 0, msg);
                            return;
                        }
                        else msg = "Choose a person to remove from your " + msg;

                        llDialog(id, msg, dialogSort(llListSort(dialogButtons, 1, 1) + MAIN), activeChannel);
                        llSetTimerEvent(MENU_TIMEOUT);
                    }
                    else if (beforeSpace == "List") {
                        if (dialogNames == []) msg = "Your " + msg + " is empty.";
                        else {
                            msg = "Current " + msg + ":";
                            for (i = 0; i < n; i++) msg += "\n" + (string)(i+1) + ". " + llList2String(dialogNames, i);
                        }
                        llOwnerSay(msg);
                    }
                }
                else if (isController && choice == "Drop Control") {
                    integer index = llListFindList(controllers, [ (string)id ]);

                    if (index != -1) {
                        controllers = llDeleteSubList(controllers, index, index + 1);
                        lmSendConfig("controllers", llDumpList2String(controllers, "|"));
                        lmSendToAgent("You are no longer controller of this key.", id);
                    }
                    else {
                        llSay(DEBUG_CHANNEL, "Drop Control option triggered by non-controller!");
                    }
                }
                else if (beforeSpace == CROSS || beforeSpace == CHECK) {
                    // Could be Option or Ability:
                    //     ALL have Checks or Crosses (X) - and all have spaces

                    // Entering options menu section
                    if (isDoll || isController) {
                        integer isX = (beforeSpace == CROSS);

                        //debugSay(4, "DEBUG-MENU", "Option setting is " + (string)isX);
                        //debugSay(5, "DEBUG-MENU", "Option 'beforeSpace' is " + beforeSpace);
                        //debugSay(5, "DEBUG-MENU", "Option 'afterSpace' is " + afterSpace);

                        // Entering key menu section
                        if (afterSpace == "Gem Light") {
                             lmSendConfig("primLight", (string)isX);
                             lmMenuReply("Key...", name, id);
                        }
                        else if (afterSpace == "Key Glow") { 
                            lmSendConfig("primGlow", (string)isX);
                            lmMenuReply("Key...", name, id);
                        }
                        else {
                            integer isAbility; // Temporary variables used to determine if an option
                            integer isFeature; // from the features or abilities menu was clicked; that
                                               // way we can restore the menu - making setting several
                                               // choices a much easier and much more user friendly process.

                            //----------------------------------------
                            // Abilities
                            if (afterSpace == "Silent Pose") {
                                isAbility = 1;
                                if (isX || !isDoll) {
                                    // if is not Doll, they can set and unset this option
                                    // if is Doll, they can only enable this option
                                    lmSendConfig("poseSilence", (string)isX);
                                }
                                else if (isDoll) {
                                    llOwnerSay("The Silent Pose cannot be disabled by you.");
                                }
                            }
                            else if (!isX || !isDoll) {
                                // if is not Doll, they can set and unset these options...
                                // if is Doll, these abilities can only be removed (X)
                                isAbility = 1;
                                if (afterSpace == "Self TP") lmSendConfig("tpLureOnly", (string)isX);
                                else if (afterSpace == "Self Dress") lmSendConfig("canDressSelf", (string)(canDressSelf = isX));
                                else if (afterSpace == "Detachable") lmSendConfig("detachable", (string)(detachable = isX));
                                else if (afterSpace == "Flying") lmSendConfig("canFly", (string)isX);
                                else if (afterSpace == "Sitting") lmSendConfig("canSit", (string)isX);
                                else if (afterSpace == "Standing") lmSendConfig("canStand", (string)isX);
                                else if (afterSpace == "Force TP") lmSendConfig("autoTP", (string)isX);
                                else isAbility = 0;
                            }
                            else if (isX && isDoll) {
                                isAbility = 1;
                                if (afterSpace == "Self TP") llOwnerSay("The Self TP option cannot be re-enabled by you.");
                                else if (afterSpace == "Self Dress") llOwnerSay("The Self Dress option cannot be re-enabled by you.");
                                else if (afterSpace == "Detachable") llOwnerSay("The Detachable option cannot be re-enabled by you.");
                                else if (afterSpace == "Flying") llOwnerSay("The Flying option cannot be re-enabled by you.");
                                else if (afterSpace == "Sitting") llOwnerSay("The Sitting option cannot be re-enabled by you.");
                                else if (afterSpace == "Standing") llOwnerSay("The Standing option cannot be re-enabled by you.");
                                else if (afterSpace == "Force TP") llOwnerSay("The Force TP option cannot be re-enabled by you.");
                                else isAbility = 0;
                            }

                            if (isAbility) {
                                cdMenuInject("Abilities...");
                            }
                            else {
                                //----------------------------------------
                                // Features
                                isFeature = 1; // Maybe it'a a features menu item
                                if (afterSpace == "Type Text") lmSendConfig("signOn", (string)isX);
                                else if (afterSpace == "Quiet Key") lmSendConfig("quiet", (string)(quiet = isX));
                                else if (afterSpace == "Carryable") lmSendConfig("canCarry", (string)(canCarry = isX));
                                else if (afterSpace == "Outfitable") lmSendConfig("canDress", (string)(canDress = isX));
                                else if (afterSpace == "Poseable") lmSendConfig("canPose", (string)(canPose = isX));
                                else if (afterSpace == "Warnings") lmSendConfig("doWarnings", (string)isX);
//                              else if (afterSpace == "Offline") {
//                                  lmSendConfig("offlineMode", (string)isX);
//                                  llSleep(1.0);
//                                  cdLinkMessage(LINK_THIS, 0, 301, "", NULL_KEY);
//                              }
                                // if is not Doll, they can set and unset these options...
                                // if is Doll, these abilities can only be removed (X)
                                else if (afterSpace == "Rpt Wind") {
                                    if (!isX || !isDoll) {
                                        lmSendConfig("canRepeat", (string)isX);
                                    }
                                    else if (isDoll) {
                                        llOwnerSay("The Repeat Wind option cannot be re-enabled by you.");
                                    }
                                }
                                else if (afterSpace == "Allow AFK") {
                                    if (!isX || !isDoll) {
                                        lmSendConfig("canAFK", (string)(canAFK = isX));
                                    }
                                    else if (isDoll) {
                                        llOwnerSay("The Allow AFK option cannot be re-enabled by you.");
                                    }
                                }
#ifdef ADULT_MODE
                                else if (afterSpace == "Pleasure") lmSendConfig("pleasureDoll", (string)(pleasureDoll = isX));
#endif
                                else isFeature = 0;

                                if (isFeature) cdMenuInject("Features...");
                            }
                        }
                    }
                }
            }
        }
        else if ((channel == blacklistChannel) || (channel == controlChannel)) {
            if (choice == MAIN) {
                llSetTimerEvent(MENU_TIMEOUT);
                lmMenuReply(MAIN, name, id);
                return;
            }

            string button = choice;
            integer i = llListFindList(dialogButtons, [ choice ]);
            string name = llList2String(dialogNames, i);
            string uuid = llList2String(dialogKeys, i);

            if (channel == blacklistChannel) {
                if (blacklistHandle) {
                    llListenRemove(blacklistHandle);
                    blacklistHandle = 0;
                }
                if (llListFindList(blacklist, [uuid,name]) == -1) lmSendConfig("blacklistMode", (string)1);
                else lmSendConfig("blacklistMode", (string)-1);
                lmInternalCommand("addRemBlacklist", (string)uuid + "|" + name, id);
            }
            else {
                if (controlHandle) {
                    llListenRemove(controlHandle);
                    controlHandle = 0;
                }

                if (llListFindList(controllers, [uuid,name]) == -1)  lmInternalCommand("addMistress", (string)uuid + "|" + name, id);
                else if (cdIsBuiltinController(id))                  lmInternalCommand("remMistress", (string)uuid + "|" + name, id);
            }
        }

        // Ideally the listener should be closed here and only reopened when we spawn another menu.
        // Other scripts also use the dialog listener created in this script.  Until they are written to send
        // a dialogListen command whenever they respawn a dialog, we have to keep the listener open
        // at any sign of usage.
        cdListenerActivate(dialogHandle);
        llSetTimerEvent(MENU_TIMEOUT);
    }
}

