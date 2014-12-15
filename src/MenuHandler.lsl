//========================================
// MenuHandler.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

#include "include/GlobalDefines.lsl"

// code to clean up name and key list
//#define KEY2NAME 1
//
// Code to handle a name2key script
//#define NAME4KEY 1
//
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

#define UNSET -1

//========================================
// VARIABLES
//========================================
// Current Controller - or Mistress
//key MistressID = NULL_KEY;
key menuID = NULL_KEY;

list uuidList;
integer i;
integer n;

float windDefault = WIND_DEFAULT;

string msg;
integer carryMoved;
integer primLight = 1;
integer clearAnim;
integer dbConfig;
integer textboxType;
integer hasCarrier;
integer isCarrier;
integer isController;
integer isDoll;
integer numControllers;

integer blacklistChannel;
integer controlChannel;
integer blacklistHandle;
integer controlHandle;
string isDollName;

vector gemColour;

string mistressName;
string menuName;

list dialogKeys;
list dialogNames;
list dialogButtons;

key nameRequest;

//========================================
// FUNCTIONS
//========================================

// This function generates a new dialogChannel and opens it -
// EVERY time it is called... possibly for a security feature
// using a dialogChannel periodic change setup

doDialogChannelWithReset() {
    uniqueID = 0;
    dialogChannel = 0;
    llListenRemove(dialogHandle);
    doDialogChannel();
}

// This function ONLY activates the dialogChannel - no
// reset is done unless necessary

doDialogChannel() {
    if (dialogChannel != 0) {
        // This assumes that if dialogChannel is set, it is open
        cdListenerActivate(dialogHandle);
        lmSendConfig("dialogChannel", (string)(dialogChannel));
        return;
    }

    // generate a uniqueID for dolly to use
    lmSendConfig("uniqueID", (string)(uniqueID = llGenerateKey()));

    integer generateChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)uniqueID, -7, -1));

    dialogChannel = generateChannel;
    blacklistChannel = dialogChannel - BLACKLIST_CHANNEL_OFFSET;
    controlChannel = dialogChannel - CONTROL_CHANNEL_OFFSET;

    dialogHandle = cdListenAll(dialogChannel);
    //llSleep(1); // settling time?

    // Dont announce the channel until its open
    lmSendConfig("dialogChannel", (string)(dialogChannel));
    //llSleep(2); // Make sure dialogChannel setting has time to propogate

    cdListenerDeactivate(dialogHandle);
}

integer listCompare(list a, list b) {
    if (a != b) return FALSE;    // Note: This is comparing list lengths only

    return !llListFindList(a, b);  
    // As both lists are the same length, llListFindList() can only return 0 or -1 
    // Which we return as TRUE or FALSE respectively    
}

//========================================
// STATES
//========================================
default {

    //----------------------------------------
    // STATE ENTRY
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
        RLVok = UNSET;
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer sender, integer i, string data, key id) {

        // Parse link message header information
        split             =     cdSplitArgs(data);
        script            =     cdListElement(split, 0);
        remoteSeq         =     (i & 0xFFFF0000) >> 16;
        optHeader         =     (i & 0x00000C00) >> 10;
        code              =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        if (code == CONFIG) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);
            split = llDeleteSubList(split, 0, 0);
            string c = cdGetFirstChar(name);

                 if (name == "timeLeftOnKey")           timeLeftOnKey = (float)value;
            else if (name == "collapseTime") {
                // value from the wire is the amount of time the Dolly has been down (in negative s)
                // value to us is the actual UNIX time Dolly went down - we use the UNIX time because
                // when Dolly expires, they might log out and back in but we want to preserve the
                // collapse time - and not lose it
                if ((float)value != 0.0)                 collapseTime = (llGetUnixTime() + (float)value);
                else                                     collapseTime = 0.0;
            }
            else if (name == "baseWindRate")             baseWindRate = (float)value;
            else if (name == "windRate")                     windRate = (float)value;
            else if (name == "windingDown")               windingDown = (integer)value;
            else if (name == "lowScriptMode")           lowScriptMode = (integer)value;
            else if (name == "winderRechargeTime") winderRechargeTime = (integer)value;

#ifdef NAME4KEY
            // This name4key function becomes "dead code" unless a companion script
            // with the ability to look up names offline is added.
            //
            // This script sends a name2key link message 300 and name4key handles the
            // response.
            //
            // The function assumes that a null key response means that there is no
            // key found.
            else if (name == "name4key") {
                string name = llList2String(split, 0);
                key uuid = llList2Key(split, 1);

                if (uuid) {
                    if ((i = llListFindList(controllers, [ name ] )) != NOT_FOUND)
                        controllers = llListReplaceList(controllers, [ uuid, name ], i - 1, i);
                    if ((i = llListFindList(blacklist, [ name ] )) != NOT_FOUND)
                        blacklist = llListReplaceList(blacklist, [ uuid, name ], i - 1, i);
                    lmSendConfig("controllers", llDumpList2String(controllers, "|"));
                    lmSendConfig("blacklist", llDumpList2String(blacklist, "|"));
                }
            }
#endif
            else if (name == "keyAnimation")             keyAnimation = value;
            else if (name == "afk")                               afk = (integer)value;

#ifdef KEY2NAME
            // have to test before shortcut "c" because of compound conditional: "controllers"
            else if ((name == "controllers") || (name == "blacklist") && script != "MenuHandler") {
                integer i = llGetListLength(split) - 1;
                string name;
                key uuid;

                while (i >= 0) {
                    name = llList2String(split, i);
                    uuid = llList2Key(split, i - 1);
                    uuidList = [];

                    if (name == "") {
                        if (uuid == NULL_KEY)
                            llDeleteSubList(split, i - 1, i);

                        // Try llKey2Name first - for case when they
                        // are present: this makes the assumption that
                        // llKey2Name is faster and easier than
                        // llRequestAgentData.... but is it?
                        //
                        else if ((name = llKey2Name(uuid)) == "") {
                            uuid = llList2String(split, i - 1);
                            uuidList += uuid;

                            // if the nameRequest is unset, start it up.
                            // The dataserver nameRequest event will be
                            // reading from the uuidList and getting the data put
                            // into the list.
                            if (nameRequest == NULL_KEY)
                                nameRequest = llRequestAgentData(uuid, DATA_NAME);
                        }
                    }
                    else {
                        if (uuid == NULL_KEY) {
                            if (name == "")
                                llDeleteSubList(split, i - 1, i);
                            else
                                // This may or may not succeed... put it out there
                                lmSendConfig("name2key", name);
                        }
                    }

                    i--;
                }

                // We test to see if there was a change: we only need to propogate
                // the new list if it has changed. In this way we prevent endless
                // loops through this code. If there is no change - even if not
                // all names or uuids are set - then the loop stops and we continue
                // onwards
                if (name == "controllers") {
                    if (!listCompare(controllers,split)) {
                        controllers = split;
                        lmSendConfig("controllers", llDumpList2String(controllers, "|"));
                        //if (!startup) lmInternalCommand("updateExceptions", "", NULL_KEY);
                        lmInternalCommand("updateExceptions", "", NULL_KEY);
                    }
                }
                else {
                    if (!listCompare(blacklist,split)) {
                        blacklist = split;
                        lmSendConfig("blacklist", llDumpList2String(blacklist, "|"));
                    }
                }
            }
#endif

            // shortcut: c
            else if (c == "c") {
                     if (name == "carrierID")                   carrierID = (key)value;
                else if (name == "canAFK")                         canAFK = (integer)value;
                else if (name == "allowCarry")                     allowCarry = (integer)value;
                else if (name == "allowDress")                     allowDress = (integer)value;
                else if (name == "allowPose")                       allowPose = (integer)value;
                else if (name == "canDressSelf")             canDressSelf = (integer)value;
                else if (name == "canSelfTP")                   canSelfTP = (integer)value;
                else if (name == "collapsed")                   collapsed = (integer)value;
                else if (name == "configured")                 configured = (integer)value;
                else if (name == "showPhrases")               showPhrases = (integer)value;
            }
            else if (name == "RLVok")                               RLVok = (integer)value;

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
            }

            // shortcut: p
            else if (c == "p") {
                     if (name == "poserID")                       poserID = (key)value;
                else if (name == "poseSilence")               poseSilence = (integer)value;
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
            else if (name == "quiet")                           quiet = (integer)value;
            else if (name == "hoverTextOn")                         hoverTextOn = (integer)value;
            else if (name == "isVisible") {
                visible = (integer)value;
                llSetLinkAlpha(LINK_SET, (float)visible, ALL_SIDES);
            }
        }
        else if (code == SET_CONFIG) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);
            split = llDeleteSubList(split, 0, 0);

                 if (name == "blacklist") {
                    blacklist = split;
                    lmSendConfig("blacklist",llDumpList2String(split,"|"));
            }
            else if (name == "controllers") {
                    controllers = split;
                    lmSendConfig("controllers",llDumpList2String(split,"|"));
            }
        }
        else if (code == INTERNAL_CMD) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            // Deny access to the menus when the command was recieved from blacklisted avatar
            //if (llListFindList(blacklist, [ (string)id ]) != NOT_FOUND) {
            //    lmSendToAgent("You are not permitted to access this key.", id);
            //    return;
            //}

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
            else if (cmd == "mainMenu") {
                string msg;
                list menu;
                string manpage;
                debugSay(5,"CHAT-MENU","Main Menu Triggered");

                // Cache access test results
                hasCarrier      = cdCarried();
                isCarrier       = cdIsCarrier(id);
                isController    = cdIsController(id);
                isDoll          = cdIsDoll(id);
                numControllers  = cdControllerCount();

                //if (startup) lmSendToAgent("Dolly's key is still establishing connections with " + llToLower(pronounHerDoll) + " systems please try again in a few minutes.", id);

                if (llListFindList(blacklist, [ (string)id ]) != NOT_FOUND) {
                    msg = "You are not permitted any access to this dolly's key.";
                    menu = ["Leave Alone"];
                }
                else {
                    //----------------------------------------
                    // Build message for Main Menu display

                    // Compute "time remaining" message for mainMenu/windMenu
                    string timeleft;

                    integer minsLeft = llRound(timeLeftOnKey / (60.0 * windRate));

                    if (minsLeft > 0) {
                        timeleft = "Dolly has " + (string)minsLeft + " minutes remaining. ";

                        timeleft += "Key is ";
                        if (windingDown) {
                            if (windRate == 1) timeleft += "winding down at a normal rate. ";
                            else if (windRate > 1) timeleft += "winding down at an accelerated rate. ";
                            else if (windRate < 1) timeleft += "winding down at a slowed rate. ";
                        }
                        else timeleft += "not winding down. ";
                    }
                    else timeleft = "Dolly has no time left. ";

                    //----------------------------------------
                    // Start building menu

                    // Handle our "special" states first which significantly alter the menu
                    //
                    // 1. Doll has carrier
                    // 2. Doll is collapsed and is accessing their menu
                    // 3. Doll is not collapsed and either has no carrier, or carrier is accessor

                    // When the doll is carried the carrier has exclusive control
                    if (hasCarrier) {
                        // Doll has carrier - but who clicked her key?
                        //
                        // ...Carrier?
                        if (isCarrier) {
                            msg = "Uncarry frees " + dollName + " when you are done with " + pronounHerDoll + ". ";
                            menu = ["Uncarry"];
                            if (collapsed) {
                                msg += "(Doll is collapsed.) ";
                            }
                        }
                        // ...Controller (NOT Dolly)
                        else if (cdIsController(id) && !isDoll) {
                            msg = dollName + " is being carried by " + carrierName + ". ";
                            menu = ["Uncarry"];
                        }
                        // ...Dolly or member of public
                        else {
                            lmInternalCommand("carriedMenu", carrierName, NULL_KEY);
                        }
                    }

                    // The Dolly has no carrier... continue...
                    //
                    // When the doll is collapsed they lose their access to most
                    // key functions with a few exceptions

                    else if (collapsed && isDoll) {
                        lmInternalCommand("collapsedMenu", timeleft, NULL_KEY);
                    }

                    // Two types of folks will never get here: 1) a collapsed Dolly who
                    // clicked on her Key, and 2) Dolly or a member of the public who clicked on
                    // a carried Dolly's Key.
                    //
                    // All the rest pass through this point.

                    //----------------------------------------
                    // FULL (NORMAL) MENU
                    //
                    if (!collapsed && (!hasCarrier || isCarrier)) {
                        // State: not collapsed; and either: a) toucher is carrier; or b) doll has no carrier...
                        // Put another way, a carrier gets the same menu Dolly would if she has no carrier.
                        //
                        // Toucher could be...
                        //   1. Doll
                        //   2. Carrier
                        //   3. Controller
                        //   4. Someone else

                        // Options only available to dolly
                        if (isDoll) {
                            if (canAFK) menu += "AFK";
                            menu += "Visible";
                        }
                        else {
                            manpage = "communitydoll.htm";

                            // Toucher is not Doll.... could be anyone
                            msg =  dollName + " is a doll and likes to be treated like " +
                                   "a doll. So feel free to use these options. ";

                            if (isCarrier || isController)
#ifdef HOLD_KEY
                                menu += [ "Hold", "Unwind" ];
#else
                                menu += [ "Unwind" ];
#endif
                        }

                        if (RLVok == 1) {
                            // Can the doll be dressed? Add menu button
                            //
                            // Dolly can change her outfits if she is able.
                            // Others can if Dolly allows, OR if the toucher is a Controller.
                            // Note that this means Carriers cannot change Dolly unless
                            // permitted: this is appropriate.

                            if (isDoll) if (canDressSelf) menu += "Outfits...";
                            else        if (allowDress || isController)     menu += "Outfits...";

                            if (isController) menu += "RLV Off";
                        } else {
                            // Note this section is valid if RLV == 0 (no RLV)
                            // but ALSO if RLVok == -1 (unset)
                            if (isDoll || isController) menu += "RLV On";
                        }

                        if (allowDress) menu += "Types...";

                        if (keyAnimation != "") {
                            msg += "Doll is currently posed. ";

                            if (isController || (isDoll && poserID == dollID))
                                menu += [ "Poses...", "Unpose" ];
                            else if (!isDoll) {
                                if (allowPose) menu += [ "Poses...", "Unpose" ];
                                else if (poserID == dollID) menu += [ "Unpose" ];
                            }
                        }
                        else {
                            // Notice again: Carrier can only pose Dolly if permitted.
                            if ((!isDoll && allowPose) || isDoll || isController) menu += "Poses...";
                        }

                        // Fix for issue #157
                        if (!isDoll) {
                            if (!hasCarrier) {
                                // Allowing Dolly to carry herself is nonsense... others can
                                // if Dolly allows it, but a Controller can no matter what
                                if (allowCarry || isController) {
                                    msg += "Carry option picks up " + dollName + " and temporarily makes the Dolly exclusively yours. ";
                                    menu += "Carry";
                                }
                            }
                        }

#ifdef ADULT_MODE
                        // Is doll strippable?
                        if (RLVok == 1) {
                            if (pleasureDoll || dollType == "Slut") {
                                if (isController || isCarrier) {
                                    if (simRating == "MATURE" || simRating == "ADULT") menu += "Strip...";
                                }
                            }
                        }
#endif
                    }

                    // At this point, we have no assumptions about
                    // whether Dolly is collapsed, carried, or whatnot.

                    if (isDoll) {
                        if (!collapsed) menu += [ "Options...","Help..." ];
                    }
                    else {
                        // this includes any Controller that is NOT Dolly
                        if (isController) {
                            menu += "Options...";

                            // Do we want Dolly to hae Detach capability... ever?
                            if (detachable) menu += [ "Detach" ];
                        }
                        menu += [ "Wind","Help..." ];
                    }

                    if (lowScriptMode)
                        msg += "Key is in power-saving mode. ";

                    if (RLVok == UNSET) msg += "Still checking for RLV support some features unavailable. ";
                    else if (RLVok == 0) {
                        msg += "No RLV detected some features unavailable. ";
                        //if (cdIsDoll(id) || cdIsController(id)) menu += "RLV On";
                    }

                    msg += "See " + WEB_DOMAIN + manpage + " for more information. "
#ifdef DEVELOPER_MODE
                    + "(Key is in Developer Mode.) "
                    + "\n\nCurrent region FPS is " + formatFloat(llGetRegionFPS(),1) + " FPS and time dilation is " + formatFloat(llGetRegionTimeDilation(),3) + ".";
#endif
                    ;

                    menu = llListSort(menu, 1, 1);

                    // This is needed because we want to sort by name;
                    // this section puts the checkmark marker on both
                    // keys by replacing them within the list - and thus
                    // not disturbing the alphabetic order

                    if ((i = llListFindList(menu, ["AFK"]))     != NOT_FOUND) menu = llListReplaceList(menu, cdGetButton("AFK",     id, afk,     0), i, i);
                    if ((i = llListFindList(menu, ["Visible"])) != NOT_FOUND) menu = llListReplaceList(menu, cdGetButton("Visible", id, visible, 0), i, i);

                    msg = timeleft + msg;
                    timeleft = "";
                }

                cdListenerActivate(dialogHandle);
                llSetTimerEvent(MENU_TIMEOUT);

                cdDialogListen();
                llDialog(id, msg, dialogSort(menu), dialogChannel);
            }
        }
        else if (code == MENU_SELECTION) {
            string name = llList2String(split, 0);

            if (name == "Options...") {
                lmInternalCommand("optionsMenu", "", NULL_KEY);
            }
        }
        else if (code == RLV_RESET) {
            string script = llList2String(split, 0);
            RLVok = llList2Integer(split, 1);

            lmInternalCommand("updateExceptions", "", NULL_KEY);
        }
        else if (code < 200) {
            if (code == 102) {
                if (data == "Start") configured = 1;

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
            else if (code == 142) {

                cdConfigureReport();

            }
            else if (code == 150) {
                simRating = llList2String(split, 0);
            }
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
        llSetTimerEvent(0.0);

        if (blacklistHandle) { llListenRemove(blacklistHandle); blacklistHandle = 0; }
        if (controlHandle)   { llListenRemove(controlHandle);     controlHandle = 0; }

        if (dialogHandle) cdListenerDeactivate(dialogHandle);

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
            current = controllers;
        }
        else {
            channel = blacklistChannel;
            type = "blacklist";
            current = blacklist;
        }

        i = num + 1;
        while ((--i) && (llGetListLength(dialogButtons) < 12)) {
            foundKey = llDetectedKey(i - 1);
            foundName = llDetectedName(i - 1);

            if (llListFindList(current, [ (string)foundKey] ) == NOT_FOUND) { // Don't list existing users
                dialogKeys += foundKey;
                dialogNames += foundName;
                dialogButtons += llGetSubString(foundName, 0, 23);
            }
        }

        cdDialogListen();
        llDialog(dollID, "Select the avatar to be added to the " + type + ".", dialogSort(dialogButtons + MAIN), channel);
    }

    //----------------------------------------
    // NO SENSOR
    //----------------------------------------
    no_sensor() {
        cdDialogListen();
        llDialog(dollID, "No avatars detected within chat range", [MAIN], dialogChannel);
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key query_id, string data) {

        if (query_id == nameRequest) {
            key uuid = llList2Key(uuidList, 0);
            string name = data;

            if (uuid) {
                if ((i = llListFindList(controllers, [ uuid ] )) != NOT_FOUND)
                    controllers = llListReplaceList(controllers, [ uuid, name ], i, i + 1);
                if ((i = llListFindList(blacklist, [ uuid ] )) != NOT_FOUND)
                    blacklist = llListReplaceList(blacklist, [ uuid, name ], i, i + 1);
                lmSendConfig("controllers", llDumpList2String(controllers, "|"));
                lmSendConfig("blacklist", llDumpList2String(blacklist, "|"));
                uuidList = llDeleteSubList(uuidList, 0, 1);
            }

            if (uuidList != []) nameRequest = llRequestAgentData(llList2Key(uuidList, 0), DATA_NAME);
            else nameRequest = NULL_KEY;
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
        // Deny access to the menus when the command was recieved from blacklisted avatar
        if (llListFindList(blacklist, [ (string)id ]) != NOT_FOUND) {
            lmSendToAgent("You are not permitted to access this key.", id);
            return;
        }

        // Cache access test results
        integer hasCarrier      = cdCarried();
        integer isCarrier       = cdIsCarrier(id);
        integer isController    = cdIsController(id);
        integer isDoll          = cdIsDoll(id);
        integer numControllers  = cdControllerCount();

        list split = llParseStringKeepNulls(choice, [ " " ], []);

        name = llGetDisplayName(id); // FIXME: name can get set to ""

        integer space = llSubStringIndex(choice, " ");

        debugSay(5,"CHAT-MENU","Menu choice = " + choice + ", space = " + (string)space);
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
                    cdMenuInject("Options...");
                }
                else if (choice == "Detach") lmInternalCommand("detach", "", id);
                else if (choice == "Accept") lmInternalCommand("addMistress", (string)id + "|" + name, id);
                else if (choice == "Decline") ; // do nothing
            }
            else {
                if (choice == "TP Home") {
                    lmInternalCommand("TP", LANDMARK_HOME, id);
                    return;
                }

                string beforeSpace = llStringTrim(llGetSubString(choice, 0, space),STRING_TRIM);
                string afterSpace = llDeleteSubString(choice, 0, space);

                // Space Found in Menu Selection
                if (afterSpace == "Visible") {
                     lmSendConfig("isVisible", (string)(visible = (beforeSpace == CROSS)));
                     if (visible) lmSendToAgentPlusDoll("You watch as the Key fades away...",id);
                     else lmSendToAgentPlusDoll("The Key magically reappears",id);
                }
                else if (afterSpace == "AFK") {

                    if (beforeSpace == CROSS) {
                        lmSetConfig("afk", "1");
                        lmSendToAgentPlusDoll("AFK Mode manually triggered; Key subsystems slowing...",id);
                    }
                    else {
                        lmSetConfig("afk", "0");
                        lmSendToAgentPlusDoll("You hear the Key whir back to full power",id);
                    }
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
                        if (blacklist == []) {
                            dialogKeys  = cdList2ListStrided(blacklist, 0, -1, 2);
                            dialogNames = cdList2ListStrided(blacklist, 1, -1, 2);
                        }
                        else {
                            dialogKeys  = [];
                            dialogNames = [];
                            blacklist   = []; // an attempt to free memory
                        }
                        blacklistHandle = cdListenUser(blacklistChannel, id);
                    }
                    else {
                        if (blacklistHandle) {
                            llListenRemove(blacklistHandle);
                            blacklistHandle = 0;
                        }

                        activeChannel = controlChannel;
                        msg = "controller list";
                        if (controllers == []) {
                            dialogKeys  = cdList2ListStrided(controllers, 0, -1, 2);
                            dialogNames = cdList2ListStrided(controllers, 1, -1, 2);
                        }
                        else {
                            dialogKeys  = [];
                            dialogNames = [];
                            controllers = []; // an attempt to free memory
                        }
                        controlHandle = cdListenUser(controlChannel, id);
                    }

                    // Only need this once now, make dialogButtons = numbered list of names truncated to 24 char limit
                    dialogButtons = [];
                    n = llGetListLength(dialogKeys);

                    for (i = 0; i < n; i++) dialogButtons += llGetSubString((string)(i+1) + ". " + llList2String(dialogNames, i), 0, 23);

                    if (beforeSpace == CIRCLE_PLUS) {
                        if (n < 11) {
                            llSensor("", "", AGENT, 20.0, PI);
                        }
                        else {
                            msg = "You already have the maximum (11) entries in your " + msg + " please remove one or more entries before attempting to add another.";
                            llRegionSayTo(id, 0, msg);
                        }
                    }
                    else if (beforeSpace == CIRCLE_MINUS) {
                        if (dialogKeys == []) {
                            msg = "Your " + msg + " is empty.";
                            llRegionSayTo(id, 0, msg);
                            return;
                        }
                        else {
                            if (cdIsDoll(id)) msg = "Choose a person to remove from your " + msg;
                            else msg = "Choose a person to remove from Dolly's " + msg;
                        }

                        cdDialogListen();
                        llDialog(id, msg, dialogSort(llListSort(dialogButtons, 1, 1) + MAIN), activeChannel);
                        llSetTimerEvent(MENU_TIMEOUT);
                    }
                    else if (beforeSpace == "List") {
                        if (dialogNames == []) {
                            if (cdIsDoll(id)) msg = "Your " + msg + " is empty.";
                            else msg = "Doll's " + msg + " is empty.";
                        }
                        else {
                            if (cdIsDoll(id)) msg = "Current " + msg + ":";
                            else msg = "Doll's current " + msg + ":";

                            i = n;
                            while (i--)
                                msg += "\n" + (string)(n - i) + ". " + llList2String(dialogNames, n - i - 1);
                        }
                        llRegionSayTo(id, 0, msg);
                    }
                }
                else if (choice == "Drop Control") {
                    integer index;

                    if ((index = llListFindList(controllers, [ id ])) != NOT_FOUND) {
                        controllers = llDeleteSubList(controllers, index, index + 1);
                        lmSetConfig("controllers", llDumpList2String(controllers, "|"));
                        lmSendToAgent("You are no longer a controller of this Dolly.", id);
                        llOwnerSay("Your controller " + name + " has relinquished control.");
                    }
                }
                else if (beforeSpace == CROSS || beforeSpace == CHECK) {
                    // Could be Option or Ability:
                    //     ALL have Checks or Crosses (X) - and all have spaces

                    // Entering options menu section
                    if (isDoll || isController) {
                        integer isX = (beforeSpace == CROSS);

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
                                // if X is true - this value can be changed -OR-
                                // if is NOT Dolly - this value can be changed -OR-
                                // if is a Controller - this value can be changed
                                //
                                // otherwise - if this is a Dolly with Controller - cannot make this setting false.
                                if (isX || !isDoll || isController) lmSendConfig("poseSilence", (string)isX);
                                else if (!isX && isDoll) llOwnerSay("The Silent Pose cannot be disabled by you.");
                            }
                            else if (!isX || !isDoll || isController) {
                                // if X is false - these values can be changed -OR-
                                // if is not Doll - these values can be changed -OR-
                                // if isController - these values can be changed
                                //
                                // However! if X is true and isDoll and is NOT Controller - then skip to next...
                                isAbility = 1;
                                     if (afterSpace == "Self TP")    lmSendConfig("canSelfTP",    (string)(canSelfTP = isX));
                                else if (afterSpace == "Self Dress") lmSendConfig("canDressSelf", (string)(canDressSelf = isX));
                                else if (afterSpace == "Detachable") lmSendConfig("detachable",   (string)(detachable = isX));
                                else if (afterSpace == "Flying")     lmSendConfig("canFly",       (string)isX);
                                else if (afterSpace == "Sitting")    lmSendConfig("canSit",       (string)isX);
                                else if (afterSpace == "Standing")   lmSendConfig("canStand",     (string)isX);
                                else if (afterSpace == "Force TP")   lmSendConfig("autoTP",       (string)isX);
                                else isAbility = 0;
                            }
                            else if (isX && isDoll) {
                                // Dolly (accessor) is trying to enable: reject
                                isAbility = 1;
                                     if (afterSpace == "Self TP")    llOwnerSay("The Self TP option cannot be re-enabled by you.");
                                else if (afterSpace == "Self Dress") llOwnerSay("The Self Dress option cannot be re-enabled by you.");
                                else if (afterSpace == "Detachable") llOwnerSay("The Detachable option cannot be re-enabled by you.");
                                else if (afterSpace == "Flying")     llOwnerSay("The Flying option cannot be re-enabled by you.");
                                else if (afterSpace == "Sitting")    llOwnerSay("The Sitting option cannot be re-enabled by you.");
                                else if (afterSpace == "Standing")   llOwnerSay("The Standing option cannot be re-enabled by you.");
                                else if (afterSpace == "Force TP")   llOwnerSay("The Force TP option cannot be re-enabled by you.");
                                else isAbility = 0;
                            }

                            if (isAbility) {
                                cdMenuInject("Abilities...");
                            }
                            else {
                                //----------------------------------------
                                // Features
                                isFeature = 1; // Maybe it'a a features menu item
                                     if (afterSpace == "Type Text")  lmSendConfig("hoverTextOn",      (string)isX);
                                else if (afterSpace == "Quiet Key")  lmSendConfig("quiet",       (string)(quiet = isX));
                                else if (afterSpace == "Carryable")  lmSendConfig("allowCarry",    (string)(allowCarry = isX));
                                else if (afterSpace == "Outfitable") lmSendConfig("allowDress",    (string)(allowDress = isX));
                                else if (afterSpace == "Phrases")    lmSendConfig("showPhrases", (string)(showPhrases = isX));
                                else if (afterSpace == "Poseable")   lmSendConfig("allowPose",     (string)(allowPose = isX));
                                else if (afterSpace == "Warnings")   lmSendConfig("doWarnings",  (string)isX);

                                // if is not Doll, they can set and unset these options...
                                // if is Doll, these abilities can only be removed (X)
                                else if (afterSpace == "Rpt Wind") {
                                    if (!isX || !isDoll || isController) lmSendConfig("allowRepeatWind", (string)isX);
                                    else if (isDoll) llOwnerSay("The Repeat Wind option cannot be re-enabled by you.");
                                }
                                else if (afterSpace == "Allow AFK") {
                                    if (!isX || !isDoll || isController) lmSendConfig("canAFK", (string)(canAFK = isX));
                                    else if (isDoll) llOwnerSay("The Allow AFK option cannot be re-enabled by you.");
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

                // shutdown the listener
                llListenRemove(blacklistHandle);
                blacklistHandle = 0;

                if (llListFindList(controllers, [uuid,name]) == NOT_FOUND) lmInternalCommand("addBlacklist", (string)uuid + "|" + name, id);
                else                                                       lmInternalCommand("remBlacklist", (string)uuid + "|" + name, id);
            }
            else {

                // shutdown the listener
                llListenRemove(controlHandle);
                controlHandle = 0;

                if (llListFindList(controllers, [uuid,name]) == NOT_FOUND) {
                    msg = "Dolly " + dollName + " has presented you with the power to control her Key. With this power comes great responsibility. Do you wish to accept this power?";
                    cdDialogListen();
                    llDialog((key)uuid, msg, [ "Accept", "Decline" ], dialogChannel);
                }
                else if (cdIsController(id)) lmInternalCommand("remMistress", (string)uuid + "|" + name, id);
            }
        }
    }
}

//========== MENUHANDLER ==========
