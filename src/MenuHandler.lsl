//========================================
// MenuHandler.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

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
//#define lmCollapse(a) lmInternalCommand("collapse",(string)(a),NULL_KEY)
#define keyDetached(id) (id == NULL_KEY)

// Wait for the user for 5 minutes - but for a program, only
// wait 60s. The request for a dialog menu should happen before then -
// and change the timeout to wait for a user.
#define MENU_TIMEOUT 600.0
#define SYS_MENU_TIMEOUT 60.0

#define BLACKLIST_CHANNEL_OFFSET 666
#define CONTROL_CHANNEL_OFFSET 888
#define POSE_CHANNEL_OFFSET 777
#define TYPE_CHANNEL_OFFSET 778

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
integer clearAnim;
integer dbConfig;
integer textboxType;
integer hasCarrier;
integer isCarrier;
integer isController;
integer isDoll;
integer numControllers;
integer transformLockExpire;
integer keyLocked = FALSE;

integer blacklistChannel;
integer blacklistHandle;
integer controlChannel;
integer controlHandle;
integer poseChannel;
integer poseHandle;
integer typeChannel;
integer typeHandle;
string isDollName;

string mistressName;
string menuName;
string outfitFolder;

list dialogKeys;
list dialogNames;
list dialogButtons;
#ifdef SINGLE_SELF_WIND
key lastWinderID;
#endif

//========================================
// FUNCTIONS
//========================================

chooseDialogChannel() {
    debugSay(4,"DEBUG-MENU","chooseDialogChannel() called");

    if (dialogHandle) {

        llListenRemove(dialogHandle);
        llListenRemove(poseHandle);
        llListenRemove(typeHandle);

        dialogHandle = 0;
          poseHandle = 0;
          typeHandle = 0;
    }

    dialogChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)llGenerateKey(), -7, -1));
    poseChannel = dialogChannel - POSE_CHANNEL_OFFSET;
    typeChannel = dialogChannel - TYPE_CHANNEL_OFFSET;

    // NOTE: blacklistChannel and controlChannel are not opened here
    blacklistChannel = dialogChannel - BLACKLIST_CHANNEL_OFFSET;
      controlChannel = dialogChannel - CONTROL_CHANNEL_OFFSET;

    //lmSendConfig("dialogChannel", (string)(dialogChannel));
    doDialogChannel();
}

// This function ONLY activates the dialogChannel - no
// reset is done unless necessary

doDialogChannel() {
    debugSay(4,"DEBUG-MENU","doDialogChannel() called");
    debugSay(4,"DEBUG-MENU","dialogChannel = " + (string)dialogChannel);

    // Open dialogChannel and typeChannel, poseChannel, with it
    if (dialogHandle) {

        // Uses llListenControl(a, 1)
        cdListenerActivate(dialogHandle);
        cdListenerActivate(poseHandle);
        cdListenerActivate(typeHandle);
    }
    else {
        // Uses llListen(a, NO_FILTER, NO_FILTER, NO_FILTER)
        dialogHandle = cdListenAll(dialogChannel);
          poseHandle = cdListenAll(poseChannel);
          typeHandle = cdListenAll(typeChannel);
    }
    lmSendConfig("dialogChannel", (string)(dialogChannel));
}

//integer listCompare(list a, list b) {
//    if (a != b) return FALSE;    // Note: This is comparing list lengths only
//
//    return !llListFindList(a, b);  
//    // As both lists are the same length, llListFindList() can only return 0 or -1 
//    // Which we return as TRUE or FALSE respectively    
//}

//========================================
// STATES
//========================================
default {

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        dollID = llGetOwner();
        keyID = llGetKey();
        dollName = dollyName();
        myName = llGetScriptName();

        cdInitializeSeq();
        RLVok = UNSET;
        chooseDialogChannel();
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        RLVok = UNSET;
        cdInitializeSeq();
        chooseDialogChannel();
    }

    //----------------------------------------
    // ATTACH
    //----------------------------------------
    // During attach we perform:
    //
    //     * Unset RLVok
    //     * Set up DialogChannel
    //
    attach(key id) {

        if (!(keyDetached(id))) {

            RLVok = UNSET;
            chooseDialogChannel();
        }
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer sender, integer i, string data, key id) {

        // Parse link message header information
        split             =     cdSplitArgs(data);
        script            =     (string)split[0];
        remoteSeq         =     (i & 0xFFFF0000) >> 16;
        optHeader         =     (i & 0x00000C00) >> 10;
        code              =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        //scaleMem();

        if (code == SEND_CONFIG) {
            string name = (string)split[0];
            string value = (string)split[1];
            split = llDeleteSubList(split, 0, 0);
            string c = cdGetFirstChar(name);

                 if (name == "timeLeftOnKey")             timeLeftOnKey = (integer)value;
            else if (name == "windRate")                       windRate = (float)value;
            else if (name == "outfitFolder")               outfitFolder = value;
            else if (name == "RLVok")                             RLVok = (integer)value;
            else if (name == "backMenu")                       backMenu = value;
            else if (name == "hardcore")                       hardcore = (integer)value;
            else if (name == "keyLimit")                       keyLimit = (integer)value;
            else if (name == "keyLocked")                     keyLocked = (integer)value;
            else if (name == "lowScriptMode")             lowScriptMode = (integer)value;
            else if (name == "winderRechargeTime")   winderRechargeTime = (integer)value;
#ifdef SINGLE_SELF_WIND
            else if (name == "lastWinderID")               lastWinderID = (key)value;
#endif

            // poseAnimation used to test for being posed
            else if (name == "poseAnimation")             poseAnimation = value;

            else if (name == "showPhrases")                 showPhrases = (integer)value;
            else if (name == "transformLockExpire") transformLockExpire = (integer)value;

            // shortcut: a
            else if (c == "a") {
                     if (name == "allowCarry")                 allowCarry = (integer)value;
#ifdef ADULT_MODE
                else if (name == "allowStrip")                 allowStrip = (integer)value;
#endif
                else if (name == "allowDress")                 allowDress = (integer)value;
                else if (name == "allowPose")                   allowPose = (integer)value;
            }

            // shortcut: c
            else if (c == "c") {
                     if (name == "carrierID")                   carrierID = (key)value;
                else if (name == "carrierName")               carrierName = value;
                else if (name == "canAFK")                         canAFK = (integer)value;
                else if (name == "canDressSelf")             canDressSelf = (integer)value;
                else if (name == "canSelfTP")                   canSelfTP = (integer)value;
                else if (name == "collapsed")                   collapsed = (integer)value;
                else if (name == "configured")                 configured = (integer)value;
                else if (name == "chatChannel")               chatChannel = (integer)value;
                else if (name == "chatPrefix")                 chatPrefix = value;
            }

            // shortcut: d
            else if (c == "d") {
                if (name == "dialogChannel") {
                    dialogChannel = (integer)value;
                    //debugSay(4,"DEBUG-MENU","dialogChannel recieved and set to " + (string)dialogChannel);
                }
                //else if (name == "detachable")                 detachable = (integer)value;
#ifdef ADULT_MODE
                // if not Adult Mode we don't need this...
                else if (name == "dollType")                     dollType = value;
#endif
#ifdef DEVELOPER_MODE
                else if (name == "debugLevel")                 debugLevel = (integer)value;
#endif
            }

            // shortcut: p
            else if (c == "p") {
                     if (name == "poserID")                   poserID = (key)value;
                else if (name == "poseSilence")           poseSilence = (integer)value;
                else if (name == "pronounHerDoll")     pronounHerDoll = value;
                else if (name == "pronounSheDoll")     pronounSheDoll = value;
            }
            else if (name == "hovertextOn")               hovertextOn = (integer)value;
            else if (name == "visibility")                 visibility = (float)value;
            else if (name == "isVisible") {
                visible = (integer)value;
                if (visible) llSetLinkAlpha(LINK_SET, (float)visibility, ALL_SIDES);
                else         llSetLinkAlpha(LINK_SET,               0.0, ALL_SIDES);
            }
        }
        else if (code == SET_CONFIG) {
            string name = (string)split[0];
            string value = (string)split[1];

            split = llDeleteSubList(split, 0, 0);

                 if (name == "blacklist") {

                    if (split == [""]) blacklist = [];
                    else blacklist = split;
                    lmSendConfig("blacklist",llDumpList2String(blacklist,"|"));
            }
            else if (name == "controllers") {
                    if (split == [""]) controllers = [];
                    else controllers = split;
                    lmSendConfig("controllers",llDumpList2String(controllers,"|"));
            }
        }
        else if (code == INTERNAL_CMD) {
            string cmd = (string)split[0];
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "dialogListen") {

                doDialogChannel();
                //cdListenerActivate(dialogHandle);
                llSetTimerEvent(MENU_TIMEOUT);
            }
            else if (cmd == "dialogClose") {
                cdListenerDeactivate(dialogHandle);
                cdListenerDeactivate(poseHandle);
                cdListenerDeactivate(typeHandle);

                llSetTimerEvent(0.0);

                dialogKeys = []; dialogButtons = []; dialogNames = [];

                menuName = "";
                menuID = NULL_KEY;
            }
            else if (cmd == "mainMenu") {
                string msg;
                list menu;
                string manpage;

                // Cache access test results
                hasCarrier      = cdCarried();
                isCarrier       = cdIsCarrier(id);
                isController    = cdIsController(id);
                isDoll          = cdIsDoll(id);
                numControllers  = cdControllerCount();

                //----------------------------------------
                // If other menus are appropriate, bypass the main menu quickly

                // if this is Dolly... show dolly other menu as appropriate
                if (isDoll) {

                    // Collapse has precedence over having a carrier...
                    if (collapsed) {
                        lmInternalCommand("collapsedMenu", (string)id, NULL_KEY);
                        return;

                    } else if (hasCarrier) {
                        lmInternalCommand("carriedMenu", (string)id + "|" + carrierName, NULL_KEY);
                        return;
                    }
                }

                //----------------------------------------
                // Build message for Main Menu display

                // Compute "time remaining" message for mainMenu/windMenu
                string timeLeftMsg;

                if (!hardcore && !hasCarrier) {
                    integer minsLeft;

                    // timeLeftOnKey is in seconds, and timeLeftOnKey / 60.0 converts
                    // the number to minutes. The value windRate is a scaling factor:
                    // a key running fast (windRate = 2.0) has fewer minutes left;
                    // timeLeftOnKey is "real" seconds left.

                    if (windRate > 0) {
                        minsLeft = llRound(timeLeftOnKey / (60.0 * windRate));
                        timeLeftMsg = "Dolly has " + (string)minsLeft + " minutes remaining. ";

                        timeLeftMsg += "Key is ";

                             if (windRate == 1) timeLeftMsg += "winding down at a normal rate. ";
                        else if (windRate > 1)  timeLeftMsg += "winding down at an accelerated rate. ";
                        else if (windRate < 1)  timeLeftMsg += "winding down at a slowed rate. ";
                    }
                    else timeLeftMsg += "not winding down. ";
                }

                //----------------------------------------
                // Prepare listeners: this allows for lag time by doing this up front

                cdListenerActivate(dialogHandle);
                //lmDialogListen();

                //----------------------------------------
                // Start building menu

                // Handle our "special" states first which significantly alter the menu
                //
                // 1. Doll has carrier
                // 2. Doll is collapsed and is accessing their menu
                // 3. Doll is not collapsed and either has no carrier, or carrier is accessor

                // When the doll is collapsed they lose their access to most
                // key functions with a few exceptions; note too, that the
                // collapsedMenu handles ALL aspects...

                //----------------------------------------
                // FULL (NORMAL) MENU
                //
                // Button list:
                // * Visible
                // * Unwind
                // * Outfits
                // * Types
                // * Poses
                // * Unpose
                // * Carry/Uncarry
                // * Strip
                // * Wind
                // * Options
                // * Help


                // After this point, we can assume one of two things:
                // 1. Menu is for Dolly, and Dolly is not collapsed or carried
                // 2. Menu is for others

                // When the doll is carried the carrier has exclusive control
                // This section will not be used for Dolly
                //
                if (hasCarrier) {
                    // Doll has carrier - but who clicked her key?

                    //--------------------
                    // ...Carrier?
                    if (isCarrier) {
                        msg = "Uncarry frees " + dollName + " when you are done with " + pronounHerDoll + ". ";
                        menu = ["Uncarry"];
                        if (collapsed) msg += "(Doll is collapsed.) ";
                    }

                    //--------------------
                    // ...Controller (NOT Dolly)
                    else if (cdIsController(id)) {
                        msg = dollName + " is being carried by " + carrierName + ". ";
                        menu = ["Uncarry"];
                    }

                    //--------------------
                    // ...public
                    else {
                        lmInternalCommand("carriedMenu", carrierName, NULL_KEY);
                        return;
                    }
                }

                // IF Dolly is being carried, we can assume:
                // 1. The carrier is looking at the key
                // 2. A controller is looking at the key
                //
                // IF Dolly is collapsed, then we can assume:
                // 1. Someone (NOT Dolly) is looking at the menu
                //
                // Those are the only assumptions we can make, if
                // Dolly is neither collapsed nor carried.

                //--------------------
                // Options Button
                if (isDoll) {

                    // Give Dolly only options if not posed
                    if (poseAnimation == ANIMATION_NONE) menu += [ "Options..." ];
                }

                else {
                    // Give controllers access to options
                    if (isController) menu += "Options...";
                }

                //--------------------
                // Help Button
                menu += [ "Help..." ];

                // Standard Main Menu
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

                    // Buttons:

                    //--------------------
                    // Visible Button
                    if (isDoll) {
                        menu += "Visible";
                        if (keyLocked) menu += "Unlock";
                        else menu += "Lock";
                    }

                    //--------------------
                    // Unwind Button
                    if (!isDoll) {
                        manpage = "communitydoll.htm";

                        // Toucher is not Doll.... could be anyone
                        msg =  dollName + " is a doll and likes to be treated like a doll. So feel free to use these options. ";
                        menu += "Unwind";
                    }

                    //--------------------
                    // Outfits Button
                    if (RLVok == TRUE) {
                        // Can the doll be dressed? Add menu button
                        //
                        // Dolly can change her outfits if she is able.
                        // Others can if Dolly allows, OR if the toucher is a Controller.
                        // Note that this means Carriers cannot change Dolly unless
                        // permitted: this is appropriate.

                        if (outfitFolder == "") {
                            llSay(DEBUG_CHANNEL, "Outfits folder is unset!");
                        }
                        else {
                            if (isDoll) {
                                if (canDressSelf && poseAnimation == ANIMATION_NONE && !hardcore) menu += "Outfits...";
                            }
                            else {
                                if (hardcore || allowDress || isController) menu += "Outfits...";
                            }
                        }
                    }

                    //--------------------
                    // Types Button
                    if (poseAnimation == ANIMATION_NONE) {
                        // Only present the Types button if Dolly is not posed

                        if (transformLockExpire == 0) {
                            // Members of the public are allowed if allowed
                            //if (!isDoll && !isController) menu += "Types...";

                            // Dolly or Controllers always can use Types
                            //else menu += "Types...";

                            // No difference?!
                            menu += "Types...";
                        }
                    }

#define isDollySitting (llGetAgentInfo(llGetOwner()) & AGENT_SITTING)
#define isDollSelfPosed (poserID == dollID)

                    //--------------------
                    // Poses and Unpose Buttons
                    if (isDollySitting == FALSE) { // Agent not sitting
                        // if dolly is sitting, dont allow poses

                        if (arePosesPresent()) {
                            if (poseAnimation != ANIMATION_NONE) {
                                msg += "Doll is currently posed. ";

                                // If accessor is Dolly... allow Dolly to pose and unpose,
                                // but NOT when posed by someone else.

                                if (isDoll) {
                                    if (isDollSelfPosed) menu += [ "Poses...", "Unpose" ];
                                }

                                // If accessor is NOT Dolly... allow the public access if
                                // permitted by Dolly, and allow access to all Controllers
                                // (NOT Dolly by virtue of ruling out Doll previously).
                                // Also allow anyone to Unpose Dolly if Dolly self posed.

                                else {
                                    if (isController || allowPose || hardcore)
                                        menu += [ "Poses...", "Unpose" ];
                                    else if (isDollSelfPosed)
                                        menu += [ "Unpose" ];
                                }
                            }
                            else {
                                // Notice again: Carrier can only pose Dolly if permitted.
                                if ((!isDoll && allowPose) || isDoll || isController) menu += "Poses...";
                            }
                        }
                    }

                    //--------------------
                    // Carry Button
                    // Fix for issue #157
                    //
                    // Dolly doesn't carry self...
                    if (!isDoll) {

                        // Dolly has no carrier
                        if (!hasCarrier) {

                            // Dolly can be carried if allowed, and Controller can at any time
                            if (allowCarry || hardcore || isController) {
                                msg += "Carry option picks up " + dollName + " and temporarily makes the Dolly exclusively yours. ";
                                menu += "Carry";
                            }
                        }
                    }

#ifdef ADULT_MODE
                    //--------------------
                    // Strip Button
                    // Is doll strippable?
                    if (RLVok == TRUE) {
                        if (simRating == "MATURE" || simRating == "ADULT") {

                            // Only show for Slut Dollies
                            if (dollType == "Slut" || hardcore) {
                                menu += "Strip";
                            }

                            // Otherwise, show if Strip is allowed, and Dress is allowed
                            else if (allowStrip && allowDress) {
                                if (isController || isCarrier || isDoll) menu += "Strip";
                            }
                        }
                    }
#endif
                }

                // At this point, we have no assumptions about
                // whether Dolly is collapsed, carried, or whatnot.

                //--------------------
                // Wind Button
                if (isDoll) {

                    if (allowSelfWind) {
                        if (keyLimit - timeLeftOnKey > 30) {
#ifdef SINGLE_SELF_WIND
                            if (lastWinderID != dollID) menu += [ "Wind" ];
#else
                            menu += [ "Wind" ];
#endif
                        }
                        else menu += [ "-" ];
                    }
                }
                else {
                    // Anyone can wind Dolly :)
                    if (keyLimit - timeLeftOnKey > 30) menu += [ "Wind" ];
                    else menu += [ "-" ];
                }

                //--------------------
                // END OF BUTTONS
                if (lowScriptMode) msg += "Key is in power-saving mode. ";

#ifdef DEVELOPER_MODE
                if (RLVok == UNSET) msg += "Still checking for RLV support some features unavailable. ";
                else
#endif
                if (RLVok != TRUE) {
                    msg += "No RLV detected; therefore, some features are unavailable. ";
                }

                msg += "See " + WEB_DOMAIN + manpage + " for more information. "
#ifdef DEVELOPER_MODE
                + "(Key is in Developer Mode.) "
                + "\n\nCurrent region FPS is " + formatFloat(llGetRegionFPS(),1) + " FPS and time dilation is " + formatFloat(llGetRegionTimeDilation(),3) + "."
#endif
                ;

                if (isDoll) {
                    msg += "\n\nCurrently listening on channel " + (string)chatChannel + " with prefix " + chatPrefix;
                }

                //menu = llListSort(menu, 1, 1);

                // This is needed because we want to sort by name;
                // this section puts the checkmark marker on both
                // keys by replacing them within the list - and thus
                // not disturbing the alphabetic order

                if ((i = llListFindList(menu, ["Visible"])) != NOT_FOUND) menu = llListReplaceList(menu, cdGetButton("Visible", id, visible, 0), i, i);

                msg = timeLeftMsg + msg;
                timeLeftMsg = "";

                if (llGetListLength(menu) > 12)
                    llSay(DEBUG_CHANNEL,"Menu appears to have overfilled with buttons (" + (string)(llGetListLength(menu)));
                llDialog(id, msg, dialogSort(menu), dialogChannel);
                llSetTimerEvent(MENU_TIMEOUT);
            }
        }
        else if (code == MENU_SELECTION) {
            string name = (string)split[0];

            if (name == "Options...") {
                lmInternalCommand("optionsMenu", llGetDisplayName(id), id);
            }
        }
        else if (code == RLV_RESET) {
            RLVok = (integer)split[0];
        }
        else if (code < 200) {
            if (code == INIT_STAGE2) {
                if (data == "Start") configured = 1;

                doDialogChannel();
                //scaleMem();
            }
            else if (code == INIT_STAGE5) {
                //startup = 0;
                ;
            }
#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                float delay = (float)split[0];
                memReport(myName,delay);
            }
#endif
            else if (code == CONFIG_REPORT) {

                cdConfigureReport();

            }
            else if (code == SIM_RATING_CHG) {
                simRating = (string)split[0];
            }
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
        llSetTimerEvent(0.0);

        if (blacklistHandle) { llListenRemove(blacklistHandle); blacklistHandle = 0; debugSay(4,"DEBUG-MENU","Timer expired: blacklistHandle removed"); }
        if (controlHandle)   { llListenRemove(controlHandle);     controlHandle = 0; debugSay(4,"DEBUG-MENU","Timer expired: controlHandle removed");   }

        if (poseHandle)      { cdListenerDeactivate(poseHandle);    debugSay(4,"DEBUG-MENU","Timer expired: poseHandle deactivated");   }
        if (typeHandle)      { cdListenerDeactivate(typeHandle);    debugSay(4,"DEBUG-MENU","Timer expired: typeHandle deactivated");   }
        if (dialogHandle)    { cdListenerDeactivate(dialogHandle);  debugSay(4,"DEBUG-MENU","Timer expired: dialogHandle deactivated"); }

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
#ifdef ADULT_MODE
            type = "controller list";
#else
            type = "parent list";
#endif
            current = controllers;
        }
        else {
            channel = blacklistChannel;
            type = "blacklist";
            current = blacklist;
        }

        i = num;
        while ((i--) && (llGetListLength(dialogButtons) < 12)) {
            foundKey = llDetectedKey(i);
            foundName = llDetectedName(i);

            if (llListFindList(current, [ (string)foundKey] ) == NOT_FOUND) { // Don't list existing users
                dialogKeys += foundKey;
                dialogNames += foundName;
                dialogButtons += llGetSubString(foundName, 0, 23);
            }
        }

        lmDialogListen();
        llDialog(dollID, "Select the avatar to be added to the " + type + ".", dialogSort(dialogButtons + "Back..."), channel);
    }

    //----------------------------------------
    // NO SENSOR
    //----------------------------------------
    no_sensor() {
        lmDialogListen();
        llDialog(dollID, "No avatars detected within chat range", [ "Back..." ], dialogChannel);
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {
        // channel = chat channel to listen on
        //    name = filter by prim name
        //     key = filter by avatar key
        //  choice = filter by specific message

        // Cache access test results
        integer hasCarrier      = cdCarried();
        integer isCarrier       = cdIsCarrier(id);
        integer isController    = cdIsController(id);
        integer isDoll          = cdIsDoll(id);
        integer numControllers  = cdControllerCount();

        list split = llParseStringKeepNulls(choice, [ " " ], []);

        name = llGetDisplayName(id); // "id" can be assumed present due to them using the menu dialogs...

        integer space = llSubStringIndex(choice, " ");

        menuID = id;
        menuName = name;

        debugSay(4,"DEBUG-MENU","Listener activated on channel " + (string)channel);

        // Answer to one of these channels:
        //    * dialogChannel
        //    * blacklistChannel
        //    * controlChannel
        //    * poseChannel
        //    * typeChannel
        if (channel == dialogChannel) {
            // This is what starts the Menu process: a reply sent out
            // via Link Message to be responded to by the appropriate script
            llSetTimerEvent(0.0);
            lmMenuReply(choice, name, id);

            if (space == NOT_FOUND) {
                // no space was found in the Menu button selection
                     if (choice == "Accept") lmInternalCommand("addController", (string)id + "|" + name, id);
                //else if (choice == "Detach") lmInternalCommand("detach", "", id);
                else if (choice == "Decline") ; // do nothing
            }
            else {
                // A space WAS found in the Menu button selection
                if (choice == "TP Home") {
                    lmInternalCommand("teleport", LANDMARK_HOME, id);
                    return;
                }
                else if (choice == "Drop Control") {
                    integer index;

                    if ((index = llListFindList(controllers, [ (string)id ])) != NOT_FOUND) {
                        controllers = llDeleteSubList(controllers, index, index + 1);
                        lmSendConfig("controllers", llDumpList2String(controllers, "|"));

                        cdSayTo("You are no longer a controller of this Dolly.", id);
                        llOwnerSay("Your controller " + name + " has relinquished control.");
                        lmInternalCommand("reloadExceptions", script, NULL_KEY);
                    }
#ifdef DEVELOPER_MODE
                    else {
                        llSay(DEBUG_CHANNEL,"id " + (string)id + " not found in Controllers List: " + llDumpList2String(controllers,",") +
                            " - index= = " + (string)index + " - search = " + (string)llListFindList(controllers, [ id ]));
                    }
#endif
                    return;
                }

                string beforeSpace = llStringTrim(llGetSubString(choice, 0, space),STRING_TRIM);
                string afterSpace = llDeleteSubString(choice, 0, space);

                // Space Found in Menu Selection
                if (beforeSpace == CROSS || beforeSpace == CHECK) {
                    // It's an option with a Check or Cross in it - and is in one of the Options menus
                    // This code depends on knowledge of which menu has which option; the only reason we
                    // care at all is because we want to redisplay the menu in which the option occurs

                    string s;

                    if (afterSpace == "Visible") {
                        if (visible) s = "You watch as the Key fades away...";
                        else s = "The Key magically reappears";

                        lmSendConfig("isVisible", (string)(visible = (beforeSpace == CROSS)));
                        cdSayToAgentPlusDoll(s,id);

                        lmMenuReply(MAIN, name, id);
                    }
                    // Could be Option or Ability:
                    //     ALL have Checks or Crosses (X) - and all have spaces

                    // Entering options menu section - only Dolly and Controllers allowed
                    // (not carriers or public)
                    if (isDoll || isController) {
                        integer isX = (beforeSpace == CROSS);

                        // Entering key menu section

                        // These variables are used to track which menu to respond with given
                        // a particular menu selection; that way, a setting can be toggled without
                        // having a menu go away
                        integer isRestriction = 1;
                        integer isPublic = 1;
                        integer isOperation = 1;

                        //----------------------------------------
                        // Abilities
                        if (afterSpace == "Silent Pose") {
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
                                 if (afterSpace == "Self TP")    lmSendConfig("canSelfTP",    (string)(canSelfTP = isX));
                            else if (afterSpace == "Self Dress") lmSendConfig("canDressSelf", (string)(canDressSelf = isX));
                            //else if (afterSpace == "Detachable") lmSendConfig("detachable",   (string)(detachable = isX));
                            else if (afterSpace == "Flying")     lmSendConfig("canFly",       (string)isX);
                            else if (afterSpace == "Sitting")    lmSendConfig("canSit",       (string)isX);
                            else if (afterSpace == "Standing")   lmSendConfig("canStand",     (string)isX);
                            else if (afterSpace == "Force TP")   lmSendConfig("autoTP",       (string)isX);
                            else isRestriction = 0;
                        }
                        else if (isX && isDoll) {
                            // Dolly (accessor) is trying to enable: reject
                                 if (afterSpace == "Self TP")    llOwnerSay("The Self TP option cannot be re-enabled by you.");
                            else if (afterSpace == "Self Dress") llOwnerSay("The Self Dress option cannot be re-enabled by you.");
                            //else if (afterSpace == "Detachable") llOwnerSay("The Detachable option cannot be re-enabled by you.");
                            else if (afterSpace == "Flying")     llOwnerSay("The Flying option cannot be re-enabled by you.");
                            else if (afterSpace == "Sitting")    llOwnerSay("The Sitting option cannot be re-enabled by you.");
                            else if (afterSpace == "Standing")   llOwnerSay("The Standing option cannot be re-enabled by you.");
                            else if (afterSpace == "Force TP")   llOwnerSay("The Force TP option cannot be re-enabled by you.");
                            else isRestriction = 0;
                        }

                        if (isRestriction) {
                            cdMenuInject("Restrictions...");
                            return;
                        }
                        else {
                            //----------------------------------------
                            // Operations
                                 if (afterSpace == "Type Text")     lmSendConfig("hovertextOn",   (string)isX);
                            else if (afterSpace == "Phrases")       lmSendConfig("showPhrases",   (string)(showPhrases = isX));
#ifdef HOMING_BEACON
                            else if (afterSpace == "Homing Beacon") lmSendConfig("homingBeacon",  (string)isX);
#endif
//                          else if (afterSpace == "Warnings")      lmSendConfig("doWarnings",    (string)isX);
#ifdef OPTIONAL_RLV
                            else if (afterSpace == "RLV") {
                                // we don't deal with RLVsupport here, as if RLVsupport is FALSE,
                                // this choice is never made.
                                lmSendConfig("RLVok", (string)isX);
                                lmRLVreport(RLVok,"",isX);
                            }
#endif
                            // if is not Doll, they can set and unset these options...
                            // if is Doll, these abilities can only be removed (X)
                            else if (afterSpace == "Rpt Wind") {
                                if (!isX || !isDoll || isController) lmSendConfig("allowRepeatWind", (string)isX);
                                else if (isDoll) llOwnerSay("The Repeat Wind option cannot be re-enabled by you.");
                            }
                            else isOperation = 0;

                        }

                        if (isOperation) {
                            cdMenuInject("Operation...");
                            return;
                        }
                        else {
                            // Public access and abilities
                                 if (afterSpace == "Carryable")  lmSendConfig("allowCarry",    (string)(allowCarry = isX));
                            else if (afterSpace == "Outfitable") lmSendConfig("allowDress",    (string)(allowDress = isX));
                            else if (afterSpace == "Poseable")   lmSendConfig("allowPose",     (string)(allowPose = isX));
#ifdef ADULT_MODE
                            else if (afterSpace == "Strippable") lmSendConfig("allowStrip", (string)(allowStrip = isX));
#endif
                            else isPublic = 0;
                        }

                        if (isPublic) {
                            cdMenuInject("Public...");
                        }
                    }
                }
                // Item before Space is NOT a Check or Cross -- so must be either
                // a "circle plus" or "circle minus" or the word "List"
                else if ((afterSpace == "Blacklist")
#ifdef ADULT_MODE
                       || (afterSpace == "Controller")
#else
                       || (afterSpace == "Parent")
#endif
                       ) {
                    integer activeChannel; string msg;
                    lmSendConfig("backMenu",(backMenu = "Access..."));

                    if (afterSpace == "Blacklist") {
                        if (controlHandle) {
                            llListenRemove(controlHandle);
                            controlHandle = 0;
                        }

                        activeChannel = blacklistChannel;
                        msg = "blacklist";
                        if (blacklist != []) {
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
#ifdef ADULT_MODE
                        msg = "controller list";
#else
                        msg = "parent list";
#endif
                        if (controllers != []) {
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

                    //for (i = 0; i < n; i++) dialogButtons += llGetSubString((string)(i+1) + ". " + (string)dialogNames[i], 0, 23);

                    i = n;
                    while (i--)
                        dialogButtons += llGetSubString((string)(i + 1) + ". " + (string)dialogNames[i], 0, 23);

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

                        lmDialogListen();
                        llDialog(id, msg, dialogSort(llListSort(dialogButtons, 1, 1) + MAIN), activeChannel);
                        llSetTimerEvent(MENU_TIMEOUT);
                    }
                    else if (beforeSpace == "List") {
                        if (dialogNames == []) {

                            if (cdIsDoll(id)) msg = "Your " + msg + " is empty.";
                            else msg = "Doll's " + msg + " is empty.";
                        }
                        else {
                            debugSay(4,"DEBUG-MENU","Controller list: " + llDumpList2String(controllers,"|"));
                            debugSay(4,"DEBUG-MENU","DialogKeys: " + llDumpList2String(dialogKeys,"|"));
                            debugSay(4,"DEBUG-MENU","DialogNames: " + llDumpList2String(dialogNames,"|"));
                            if (cdIsDoll(id)) msg = "Current " + msg + ":";
                            else msg = "Doll's current " + msg + ":";

                            i = n; 
                            string idX;
                            while (i--) {
                                idX = (string)dialogKeys[n - i - 2];
                                msg += "\n" + (string)(n - i) + "." +
                                       "secondlife:///app/agent/" + idX + "/about";
                            }
                        }
                        llRegionSayTo(id, 0, msg);
                        cdMenuInject("Access...");
                    }
                }
            }
        }
        else if (channel == poseChannel) {
            if (choice == "Back...") {
                cdMenuInject(backMenu);
            }
            else {
                lmPoseReply(choice, name, id);
            }
        }
        else if (channel == typeChannel) {
            if (choice == "Back...") {
                cdMenuInject(backMenu);
            }
            else {
                cdSayTo("Dolly's internal mechanisms engage, and a transformation comes over Dolly, making " + pronounHerDoll + " into a " + choice + " Dolly",id);
                lmTypeReply(choice, name, id);
            }
        }
        else if ((channel == blacklistChannel) || (channel == controlChannel)) {
            // This is what starts the Menu process: a reply sent out
            // via Link Message to be responded to by the appropriate script
            //lmMenuReply(choice, name, id);

            if (choice == MAIN) {
                llSetTimerEvent(MENU_TIMEOUT);
                lmMenuReply(MAIN, name, id);
                return;
            }

            string button = choice;
            integer i = llListFindList(dialogButtons, [ choice ]);
            string name = (string)dialogNames[i];
            string uuid = (string)dialogKeys[i];

            if (channel == blacklistChannel) {

                // shutdown the listener
                llListenRemove(blacklistHandle);
                blacklistHandle = 0;

                if (llListFindList(blacklist, [uuid,name]) != NOT_FOUND) lmInternalCommand("remBlacklist", (string)uuid + "|" + name, id);
                else                                                     lmInternalCommand("addBlacklist", (string)uuid + "|" + name, id);
            }
            else {

                // shutdown the listener
                llListenRemove(controlHandle);
                controlHandle = 0;

                if (llListFindList(controllers, [uuid,name]) == NOT_FOUND) {
                    msg = "Dolly " + dollName + " has presented you with the power to control her Key. With this power comes great responsibility. Do you wish to accept this power?";
                    lmDialogListen();
                    llDialog((key)uuid, msg, [ "Accept", "Decline" ], dialogChannel);
                }
                else if (cdIsController(id)) lmInternalCommand("remController", (string)uuid + "|" + name, id);
            }
        }
    }
}

//========== MENUHANDLER ==========
