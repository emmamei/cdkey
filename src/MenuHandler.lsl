//========================================
// MenuHandler.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

#include "include/GlobalDefines.lsl"

#include "include/Listeners.lsl"

// code to clean up name and key list
//#define KEY2NAME 1
//
// Code to handle a name2key script
//#define NAME4KEY 1
//
#define LISTENER_ACTIVE 1
#define LISTENER_INACTIVE 0
#define NO_FILTER ""
#define NO_HANDLE 0

#define cdResetKey() llResetOtherScript("Start")
#define cdList2String(a) llDumpList2String(a,"|")
//#define lmCollapse(a) lmInternalCommand("collapse",(string)(a),NULL_KEY)
#define keyDetached(id) (id == NULL_KEY)

// Wait for the user for 5 minutes - but for a program, only
// wait 60s. The request for a dialog menu should happen before then -
// and change the timeout to wait for a user.
#define MENU_TIMEOUT 60.0
#define SYS_MENU_TIMEOUT 60.0

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
integer keyLocked = FALSE;

string isDollName;

string mistressName;
string menuName;
string outfitMasterPath;

list dialogKeys;
list dialogNames;
list dialogButtons;

key lastWinderID = NULL_KEY;

//========================================
// FUNCTIONS
//========================================

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
        rlvOk = UNSET;
        dialogChannel = listenerGetDialogChannel();
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        rlvOk = UNSET;
        cdInitializeSeq();
        dialogChannel = listenerGetDialogChannel();
    }

    //----------------------------------------
    // ATTACH
    //----------------------------------------
    // During attach we perform:
    //
    //     * Unset rlvOk
    //     * Set up DialogChannel
    //
    attach(key id) {

        dialogChannel = listenerGetDialogChannel();

        if (!(keyDetached(id))) {

            rlvOk = UNSET;
        }
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer lmSource, integer lmInteger, string lmData, key lmID) {

        parseLinkHeader(lmData,lmInteger);

        if (code == SEND_CONFIG) {
            string name = (string)split[0];

            list cmdList = [

                             "timeLeftOnKey",
                             "windRate",
                             "outfitMasterPath",
                             "rlvOk",
                             "backMenu",
                             "keyLimit",
                             "keyLocked",
                             "winderRechargeTime",
#ifdef ADULT_MODE
                             "hardcore",
#endif
                             "lastWinderID",
                             "poseAnimation",

                             "showPhrases",
                             "typeLockExpire",

                             "allowCarry",
#ifdef ADULT_MODE
                             "allowStrip",
#endif
                             "allowDress",
                             "allowTypes",
                             "allowSelfWind",
                             "allowPose",

                             "carrierID",
                             "carrierName",
                             "canAFK",
                             "canDressSelf",
                             "canSelfTP",
                             "collapsed",
                             "configured",
                             "chatChannel",
                             "baseChannel",
                             "chatPrefix",

                             //"dialogChannel",
#ifdef ADULT_MODE
                             // if not Adult Mode we don't need this...
                             "dollType",
#endif
#ifdef DEVELOPER_MODE
                             "debugLevel",
#endif
                             "poserID",
                             "canTalkInPose",
                             "pronounHerDoll",
                             "pronounSheDoll",
                             "typeHovertext",
                             "visibility",
                             "isVisible"
            ];

            // Commands need to be in the list cmdList in order to be
            // recognized, before testing down below
            //
            if (!cdFindInList(cmdList, name))
                return;

            string value = (string)split[1];
            split = llDeleteSubList(split, 0, 0);

                 if (name == "timeLeftOnKey")             timeLeftOnKey = (integer)value;
            else if (name == "windRate")                       windRate = (float)value;
            else if (name == "outfitMasterPath")               outfitMasterPath = value;
            else if (name == "rlvOk")                             rlvOk = (integer)value;
            else if (name == "backMenu")                       backMenu = value;
            else if (name == "keyLimit")                       keyLimit = (integer)value;
            else if (name == "keyLocked")                     keyLocked = (integer)value;
            else if (name == "winderRechargeTime")   winderRechargeTime = (integer)value;
#ifdef ADULT_MODE
            else if (name == "hardcore")                       hardcore = (integer)value;
#endif
            else if (name == "lastWinderID")               lastWinderID = (key)value;

            // poseAnimation used to test for being posed
            else if (name == "poseAnimation")             poseAnimation = value;

            else if (name == "showPhrases")                 showPhrases = (integer)value;
            else if (name == "typeLockExpire")           typeLockExpire = (integer)value;

            else if (name == "allowCarry")                 allowCarry = (integer)value;
#ifdef ADULT_MODE
            else if (name == "allowStrip")                 allowStrip = (integer)value;
#endif
            else if (name == "allowDress")                 allowDress = (integer)value;
            else if (name == "allowTypes")                 allowTypes = (integer)value;
            else if (name == "allowSelfWind")           allowSelfWind = (integer)value;
            else if (name == "allowPose")                   allowPose = (integer)value;

            else if (name == "carrierID")                   carrierID = (key)value;
            else if (name == "carrierName")               carrierName = value;
            else if (name == "canAFK")                         canAFK = (integer)value;
            else if (name == "canDressSelf")             canDressSelf = (integer)value;
            else if (name == "canSelfTP")                   canSelfTP = (integer)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
            else if (name == "configured")                 configured = (integer)value;
            else if (name == "chatChannel")               chatChannel = (integer)value;
            else if (name == "baseChannel")               baseChannel = (integer)value;
            else if (name == "chatPrefix")                 chatPrefix = value;

            //else if (name == "dialogChannel")           dialogChannel = (integer)value;
#ifdef ADULT_MODE
            // if not Adult Mode we don't need this...
            else if (name == "dollType")                     dollType = value;
#endif
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                 debugLevel = (integer)value;
#endif
            else if (name == "poserID")                       poserID = (key)value;
            else if (name == "canTalkInPose")           canTalkInPose = (integer)value;
            else if (name == "pronounHerDoll")         pronounHerDoll = value;
            else if (name == "pronounSheDoll")         pronounSheDoll = value;
            else if (name == "typeHovertext")           typeHovertext = (integer)value;
            else if (name == "visibility")                 visibility = (float)value;
            else if (name == "isVisible") {
                isVisible = (integer)value;
                if (isVisible) llSetLinkAlpha(LINK_SET, (float)visibility, ALL_SIDES);
                else           llSetLinkAlpha(LINK_SET,               0.0, ALL_SIDES);
            }
        }
        else if (code == SET_CONFIG) {
            string name = (string)split[0];
            string value = (string)split[1];

            split = llDeleteSubList(split, 0, 0);

                 if (name == "blacklist") {

                    if (split == [""]) blacklistList = [];
                    else blacklistList = split;
                    lmSendConfig("blacklist",cdList2String(blacklistList));
            }
            else if (name == "controllers") {
                    if (split == [""]) controllerList = [];
                    else controllerList = split;
                    lmSendConfig("controllers",cdList2String(controllerList));
            }
        }
        else if (code == INTERNAL_CMD) {
            string cmd = (string)split[0];
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "dialogListen") {

                debugSay(4,"DEBUG-MENU","dialogListen Internal Command called");
                debugSay(4,"DEBUG-MENU","dialogChannel is set to " + (string)dialogChannel);

                lmSendConfig("dialogChannel", (string)(dialogChannel));
                dialogHandle = listenerOpen(dialogChannel,dialogHandle);
            }
            else if (cmd == "mainMenu") {
                string menuMessage;
                list menuButtons;
                string infoPage = "See " + WEB_DOMAIN + "communitydoll.htm for more information. ";

                integer hasControllers;
                integer hasSupervisor;

                // Cache access test results
                hasCarrier = cdCarried();
                isCarrier  = cdIsCarrier(lmID);
                isDoll     = cdIsDoll(lmID);

                // These have LSL functions in them; using a variable to
                // cache results should make testing faster as we do these
                // functions only once here.
                //
                // Note also that Dolly IS a Controller if she has no other
                // controllers. This means you can test for Controller status
                // first in cases where Dolly gets a key UNLESS there is
                // an actual controller. This also means if you only want
                // external controllers to be able to do something, you
                // better test for Dolly first.
                // 
                isController    = cdIsController(lmID);
                numControllers  = cdControllerCount();
                hasControllers  = cdHasControllers();
                hasSupervisor   = (hasControllers || hasCarrier);

                //----------------------------------------
                // If other menus are appropriate, bypass the main menu quickly

                // if this is Dolly... show dolly other menu as appropriate
                if (isDoll) {

                    // Collapse has precedence over having a carrier...
                    if (collapsed) {
                        lmInternalCommand("collapsedMenu", (string)lmID, NULL_KEY);
                        return;

                    } else if (hasCarrier) {
                        lmInternalCommand("carriedMenu", (string)lmID + "|" + carrierName, NULL_KEY);
                        return;
                    }
                }

                //----------------------------------------
                // Build message for Main Menu display

                // Compute "time remaining" message for mainMenu/windMenu
                string timeLeftMsg;

#ifdef ADULT_MODE
                if (!hardcore) {
#endif
                    // timeLeftOnKey is in seconds, and timeLeftOnKey / 60.0 converts
                    // the number to minutes. The value windRate is a scaling factor:
                    // a key running fast (windRate = 2.0) has fewer minutes left;
                    // timeLeftOnKey is "real" seconds left.

                    if (windRate > 0.0) {

                        timeLeftMsg = "Dolly has " + (string)(llRound(timeLeftOnKey / (60.0 * windRate))) +
                                      " minutes remaining. Key is ";

                             if (windRate == 1.0) timeLeftMsg += "winding down at a normal rate. ";
                        else if (windRate  > 1.0) timeLeftMsg += "winding down at an accelerated rate. ";
                        else if (windRate  < 1.0) timeLeftMsg += "winding down at a slowed rate. ";
                    }
                    else {
                        timeLeftMsg = "Dolly has no time remaining. ";
                    }
#ifdef ADULT_MODE
                }
#endif

                //----------------------------------------
                // Prepare listeners: this allows for lag time by doing this up front

                lmDialogListen();
                llSleep(0.5); // Let messages settle in to update menu...

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
                //--------------------
                // Uncarry Button
                //
                // SECURITY: The Uncarry button is shown to the carrier, and to
                // External Controllers. The carrier can drop Dolly normally, and
                // Controllers can essentially for the carrier to drop Dolly.
                //
                // If Doll is getting the menu and has carrier - Dolly never gets here.
                //
                if (hasCarrier) {
                    // Doll has carrier - but who clicked her key?

                    //--------------------
                    // ...Carrier?
                    if (isCarrier) {
                        menuMessage = "Uncarry frees " + dollName + " when you are done with " + pronounHerDoll + ". ";
                        menuButtons += (list)"Uncarry";
                        if (collapsed) menuMessage += "(Doll is collapsed.) ";
                    }

                    //--------------------
                    // ...Controller (NOT Dolly)
                    else if (cdIsController(lmID)) {
                        menuMessage = dollName + " is being carried by " + carrierName + ". ";
                        menuButtons += (list)"Uncarry";
                    }

                    //--------------------
                    // ...public
                    else {
                        lmInternalCommand("carriedMenu", (string)lmID + "|" + carrierName, NULL_KEY);
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
                //
                // SECURITY: Show this button to Dolly and to External Controllers.
                // Show to Dolly only if they are not posed.
                //
                if (isDoll) {

                    // Give Dolly options only if not posed
                    if (poseAnimation == ANIMATION_NONE) menuButtons += (list)"Options...";
                }
                else {
                    // Give controllers access to options
                    if (isController) menuButtons += "Options...";
                }

                //--------------------
                // Help Button
                //
                // SECURITY: None
                //
                menuButtons += "Help...";

                // Standard Main Menu
                //
                // This menu is only shown if the Doll is not collapsed
                //
                if (!collapsed) {

                    //--------------------
                    // Visible Button
                    //
                    // SECURITY: Only for Doll
                    //
                    if (isDoll) menuButtons += "Visible";

                    //====================
                    // RLV BUTTONS

                    if (rlvOk) {

                        //--------------------
                        // Lock/Unlock Button
                        //
                        // SECURITY: Only show to a Controller (including Dolly if they
                        // have no others) and make it a one-way option for Dolly if
                        // Dolly has External Controllers: Dolly can lock but
                        // not unlock.
                        //
                        // Public and Carrier do not see this button.
                        //
                        if (isController) {
                            if (keyLocked) menuButtons += "Unlock";
                            else menuButtons += "Lock";
                        }
                        else {
                            // Dolly is not a controller here: one-way option
                            if (isDoll) {
                                if (!keyLocked) menuButtons += "Lock";
                            }
                        }

                        //--------------------
                        // Outfits Button

                        // Can the doll be dressed? Add menu button
                        //
                        // SECURITY: Dolly can change her outfits if they are allowed to
                        // self-dress. The public (or a carrier) can change her outfits if
                        // public access is allowed. A controller has full control at all
                        // times.

                        if (outfitMasterPath != "") {
                            if (isDoll) {
                                if (canDressSelf) menuButtons += "Outfits...";
                            }
                            else {
                                if (allowDress || isController) menuButtons += "Outfits...";
                            }
                        }
#ifdef DEVELOPER_MODE
                        else {
                            llSay(DEBUG_CHANNEL, "Outfits folder is unset!");
                        }
#endif

#ifdef ADULT_MODE
                        //--------------------
                        // Strip Button
                        //
                        // SECURITY: THIS FEATURE IS FOR ADULT MODE ONLY.
                        // The feature is only available in Mature and Adult sims.
                        // This feature is fully dependent on Dress options:
                        // if public dressing is not allowed, neither is public
                        // undressing. (This dependency is best expressed in the setting
                        // of options).
                        //
                        // For Dolly, show this option if Doll Type is Slut or if
                        // stripping is allowed (but only if Dolly can dress themselves).
                        //
                        // For controllers, show this option if Doll Type is Slut
                        // or if stripping is allowed.
                        // 
                        // For all, show this button only if Doll Type is Slut
                        // (or similar) or stripping is allowed.
                        //
                        // By testing for Slut Doll type here, we make the stripping
                        // option moot.
                        //
                        // Also, with hardcore mode, stripping is allowed.

                        if (simRating == "MATURE" || simRating == "ADULT") {

                            if (isController) {
                                if ((dollType == "Slut") || allowStrip) {
                                    menuButtons += "Strip";
                                }
                            }
                            else if (isDoll) {
                                if (canDressSelf && ((dollType == "Slut") || allowStrip)) {
                                    menuButtons += "Strip";
                                }
                            }
                            else {
                                if ((dollType == "Slut") || allowStrip) {
                                    menuButtons += "Strip";
                                }
                            }
                        }
                    } // END OF RLV BUTTONS
#endif
                    //--------------------
                    // Unwind Button
                    //
                    // SECURITY: This feature available to all except Dolly.
                    // (Letting Dolly unwind themselves makes no sense.)
                    //
                    if (!isDoll) {

                        // Toucher is not Doll.... could be anyone
                        menuMessage =  dollName + " is a doll and likes to be treated like a doll. So feel free to use these options. ";
                        menuButtons += "Unwind";
                    }

                    //--------------------
                    // Types Button
                    //
                    // SECURITY: If types are allowed, show them to everyone only IF
                    // Dolly is not posed. Show this feature to Dolly ONLY if they are
                    // not locked into a type.
                    //
                    if (allowTypes) {

                        if (poseAnimation == ANIMATION_NONE) {

                            // Only present the Types button if Dolly is not posed

                            if (isDoll) {
                                if (typeLockExpire == 0) menuButtons += "Types...";
                            }
                            else menuButtons += "Types...";
                        }
                    }

#define isDollySitting (llGetAgentInfo(llGetOwner()) & AGENT_SITTING)
#define isDollSelfPosed (poserID == dollID)

                    //--------------------
                    // Poses and Unpose Buttons
                    //
                    // SECURITY: Dont provide these options if Dolly is
                    // sitting, and don't provide them if no poses are
                    // available.
                    //
                    // If Dolly is posed...
                    //
                    // ...then provide Dolly with Pose and Unpose
                    // buttons only if Dolly is SELF-posed.
                    //
                    // ...provide Controllers with Pose and Unpose buttons.
                    //
                    // ...provide the public with Unpose button IF they
                    // are allowed to manipulate poses.
                    //
                    // If Dolly is NOT currently posed...
                    //
                    // ...provide Poses button to Dolly and to Controllers, but to
                    // public ONLY if allowed.
                    //
                    if (isDollySitting == FALSE) { // Agent not sitting
                        // if dolly is sitting, dont allow poses

                        if (arePosesPresent()) {
                            if (poseAnimation != ANIMATION_NONE) {
                                menuMessage += "Doll is currently posed. ";

                                // If accessor is Dolly... allow Dolly to pose and unpose,
                                // but NOT when posed by someone else.

                                if (isDoll) {
                                    if (isDollSelfPosed) menuButtons += [ "Poses...", "Unpose" ];
                                }

                                // If accessor is NOT Dolly... allow the public access if
                                // permitted by Dolly, and allow access to all Controllers
                                // (NOT Dolly by virtue of ruling out Doll previously).
                                // Also allow anyone to Unpose Dolly if Dolly self posed.

                                else {
                                    if (isController)
                                        menuButtons += [ "Poses...", "Unpose" ];
                                    else if (isDollSelfPosed)
                                        menuButtons += [ "Unpose" ];
                                }
                            }
                            else {
                                // Notice again: Carrier can only pose Dolly if permitted.
                                if ((!isDoll && allowPose) || isDoll || isController) menuButtons += "Poses...";
                            }
                        }
                    }

                    //--------------------
                    // Carry Button
                    //
                    // SECURITY: Present the Carry button to all *except* Dolly.
                    //
                    // Show the button if Dolly does not have a carrier...
                    //
                    // ...to Controllers at all times.
                    //
                    // ...to Public if allowed to Carry Dolly.
                    //
                    if (!isDoll) {

                        // Dolly has no carrier
                        if (!hasCarrier) {

                            // Dolly can be carried if allowed, and Controller can at any time
                            if (allowCarry || isController) {
                                menuMessage += "Carry option picks up " + dollName + " and temporarily makes the Dolly exclusively yours. ";
                                menuButtons += "Carry";
                            }
                        }
                    }
                } // END OF UNCOLLAPSED MENU

                // At this point, we have no assumptions about
                // whether Dolly is collapsed, carried, or whatnot.

                //--------------------
                // Wind Button
                //
                // SECURITY: If winding would be effective (30s or more) then
                // make the button available to all other than Dolly.
                //
                // Only make the button available to Dolly if self-wind is allowed,
                // and optionally only if Dolly did not wind previously.
                //
                // Show the option to a member of the public only if they did not
                // wind previously (if Repeat Wind is disabled), or any time if Repeat
                // Wind is enabled.
                //
                // This option should result in a button no matter what, but a
                // WIND button only shows if criteria are met.
                //
                if (isDoll) {

                    if (allowSelfWind) {
                        if (keyLimit - timeLeftOnKey > 30) {
#ifdef SINGLE_SELF_WIND
                            if (lastWinderID != dollID)
#endif
                                menuButtons += [ "Wind" ];
                        }
                        else menuButtons += [ "-" ];
                    }
                }
                else {
                    if (isController) {
                        if (keyLimit - timeLeftOnKey > 30) menuButtons += [ "Wind" ];
                        else menuButtons += [ "-" ];
                    }
                    else {
                        if (allowRepeatWind || (lastWinderID != lmID)) {
                            if (keyLimit - timeLeftOnKey > 30) menuButtons += [ "Wind" ];
                            else menuButtons += [ "-" ];
                        }
                        else menuButtons += [ "-" ];
                    }
                }

                //--------------------
                // END OF BUTTONS

#ifdef DEVELOPER_MODE
                if (rlvOk == UNSET) menuMessage += "Still checking for RLV support some features unavailable. ";
                else
#endif
                if (rlvOk != TRUE) {
                    menuMessage += "No RLV detected; therefore, some features are unavailable. ";
                }

                menuMessage += infoPage
#ifdef DEVELOPER_MODE
                + "(Key is in Developer Mode.) "
                + "\n\nCurrent region FPS is " + formatFloat(llGetRegionFPS(),1) + " FPS and time dilation is " + formatFloat(llGetRegionTimeDilation(),3) + "."
#endif
                ;

                if (isDoll) {
                    menuMessage += "\n\nCurrently listening on channel " + (string)chatChannel + " with prefix " + chatPrefix;
                }

                //menuButtons = llListSort(menuButtons, 1, 1);

                // This is needed because we want to sort by name;
                // this section puts the checkmark marker on both
                // keys by replacing them within the list - and thus
                // not disturbing the alphabetic order

                if (~(i = llListFindList(menuButtons, (list)"Visible")))
                    menuButtons = llListReplaceList(menuButtons, cdGetButton("Visible", lmID, isVisible, 0), i, i);

                menuMessage = timeLeftMsg + menuMessage;
                timeLeftMsg = "";

#ifdef DEVELOPER_MODE
                if (llGetListLength(menuButtons) > 12)
                    llSay(DEBUG_CHANNEL,"Menu appears to have overfilled with buttons (" + (string)(llGetListLength(menuButtons)));
#endif

                llDialog(lmID, menuMessage, dialogSort(menuButtons), dialogChannel);
                llSetTimerEvent(MENU_TIMEOUT); // set (listener) timeout for main menu
            }
        }
        else if (code == MENU_SELECTION) {
            string name = (string)split[0];

            if (name == "Options...") {
                lmInternalCommand("optionsMenu", llGetDisplayName(lmID), lmID);
            }
        }
        else if (code == RLV_RESET) {
            rlvOk = (integer)split[0];
        }
        else if (code < 200) {
            if (code == INIT_STAGE2) {
                if (lmData == "Start") configured = 1;
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

    // Timer is solely for listener timeouts:
    //   * blacklistHandle
    //   * controllerHandle
    //   * dialogHandle
    //
    // This will never fire - UNLESS the dialog times out
    // due to inactivity or Ignore
    //
    timer() {
        debugSay(4,"DEBUG-MENU","MenuHandler Timer fired.");
        llSetTimerEvent(0.0);

        // FIXME: Note that if ANY of these are set, when timer trips, ALL are cleared...
        // This is very probably NOT what we want, though it probably does not
        // present problems in practice... PROBABLY.
        //
         blacklistHandle = listenerTimeout( blacklistHandle);
        controllerHandle = listenerTimeout(controllerHandle);
            dialogHandle = listenerTimeout(    dialogHandle);

        dialogKeys = [];
        dialogButtons = [];
        dialogNames = [];

        menuName = "";
        menuID = NULL_KEY;
    }

    //----------------------------------------
    // SENSOR
    //----------------------------------------
    sensor(integer avatarCount) {

        // We found avatars within 20m of us

        integer listChannel;
        string listType;
        list listCurrent;

        key foundKey;
        string foundName;

        dialogKeys = [];
        dialogNames = [];
        dialogButtons = [];

        if (controllerHandle) {
            listChannel = controllerChannel;
            listCurrent = controllerList;
#ifdef ADULT_MODE
            listType = "controller list";
#else
            listType = "parent list";
#endif
        }
        else {
            listChannel = blacklistChannel;
            listCurrent = blacklistList;
            listType = "blacklist";
        }

        // note that avatarCount and llDetected* are 1-indexed
        integer index = avatarCount;

        // The "working backwards" allows us to use the index to count down
        // while still going through the list forwards: this is done because
        // the avatars in the list (max 16 entries!) are from nearest to furthest
        // away.
        //
        // This way, the ending dialog lists will all be in nearest-to-furthest
        // order.
        //
        while (index--) {
            foundKey = llDetectedKey(avatarCount - index);

            if (!cdFindInList(listCurrent, (string)foundKey)) { // Don't list existing users

                foundName = llDetectedName(index);

                dialogKeys += foundKey;
                dialogNames += foundName;
                dialogButtons += llGetSubString(foundName, 0, 23);
            }
        }

        // Only 11 buttons allowed - leave room for "Back" button
        dialogButtons = llList2List(dialogButtons, 0, 10);
          dialogNames = llList2List(dialogNames,   0, 10);
           dialogKeys = llList2List(dialogKeys,    0, 10);

        lmDialogListen();
        llDialog(dollID, "Select the avatar to be added to the " + listType + ".", dialogSort(dialogButtons + "Back..."), listChannel);
    }

    //----------------------------------------
    // NO SENSOR
    //----------------------------------------
    no_sensor() {
        dialogKeys = [];
        dialogNames = [];
        dialogButtons = [];

        lmDialogListen();
        llDialog(dollID, "No avatars detected within chat range", [ "Back..." ], dialogChannel);
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer listenChannel, string listenName, key listenID, string listenMessage) {
        // channel = chat channel to listen on
        //    name = filter by prim name
        //     key = filter by avatar key
        //  choice = filter by specific message

        string name;

        // Cache access test results
        integer hasCarrier      = cdCarried();
        integer isCarrier       = cdIsCarrier(listenID);
        integer isController    = cdIsController(listenID);
        integer isDoll          = cdIsDoll(listenID);
        integer numControllers  = cdControllerCount();

        list split = llParseStringKeepNulls(listenMessage, [ " " ], []);

        name = llGetDisplayName(listenID); // "listenID" can be assumed present due to them using the menu dialogs...

        integer space = llSubStringIndex(listenMessage, " ");

        menuID = listenID;
        menuName = name;

        debugSay(4,"DEBUG-MENU","Listener activated on channel " + (string)listenChannel);

        // Answer to one of these channels:
        //    * dialogChannel
        //    * blacklistChannel
        //    * controllerChannel

        if (listenChannel == dialogChannel) {
            // This is what starts the Menu process: a reply sent out
            // via Link Message to be responded to by the appropriate script
            llSetTimerEvent(0.0);
            lmMenuReply(listenMessage, name, listenID);

            if (space == NOT_FOUND) {
                // no space was found in the Menu button selection
                     if (listenMessage == "Accept") lmInternalCommand("addController", (string)listenID + "|" + name, listenID);
                else if (listenMessage == "Decline") ; // do nothing
            }
            else {
                // A space WAS found in the Menu button selection
                if (listenMessage == "Drop Control") {
                    integer index;

                    if (~(index = llListFindList(controllerList, (list)((string)listenID)))) {
                        controllerList = llDeleteSubList(controllerList, index, index + 1);
                        lmSendConfig("controllers", cdList2String(controllerList));

                        cdSayTo("You are no longer a controller of this Dolly.", listenID);
                        llOwnerSay("Your controller " + name + " has relinquished control.");
                        lmInternalCommand("reloadExceptions", script, NULL_KEY);
                    }
#ifdef DEVELOPER_MODE
                    else {
                        llSay(DEBUG_CHANNEL,"listenID " + (string)listenID + " not found in Controllers List: " + llDumpList2String(controllerList,",") +
                            " - index= = " + (string)index +
                            " - search = " + (string)(cdFindInList(controllerList, listenID)));
                    }
#endif
                    return;
                }
#ifdef TP_HOME
                else if (listenMessage == "TP Home") {

                    // This menu selection only happens when user selects TP Home button...
                    //
                    // Homing beacon bypasses the menu

                    lmInternalCommand("teleport", LANDMARK_HOME, listenID);
                    return;
                }
#endif
                else if (listenMessage == "RLV") {
                    lmInternalCommand("startRlvCheck","",listenID);
                    return;
                }

                string beforeSpace = llStringTrim(llGetSubString(listenMessage, 0, space),STRING_TRIM);
                string afterSpace = llDeleteSubString(listenMessage, 0, space);

                // Space Found in Menu Selection
                if (beforeSpace == CROSS || beforeSpace == CHECK) {
                    // It's an option with a Check or Cross in it - and is in one of the Options menus
                    // This code depends on knowledge of which menu has which option; the only reason we
                    // care at all is because we want to redisplay the menu in which the option occurs

                    string s;

                    if (afterSpace == "Visible") {

                        // Note there is no interaction with ghost Keys here:
                        // either the Key is visible, or it isnt. The messages are
                        // also suitably generic.
                        if (isVisible) s = "You watch as the Key fades away...";
                        else s = "The Key magically reappears, and takes on the expected form.";

                        lmSendConfig("isVisible", (string)(isVisible = (beforeSpace == CROSS)));
                        cdSayToAgentPlusDoll(s,listenID);

                        lmMenuReply(MAIN, name, listenID);
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
                        if (!isX || !isDoll || isController) {
                            // if X is false - these values can be changed -OR-
                            // if is not Doll - these values can be changed -OR-
                            // if isController - these values can be changed
                            //
                            // However! if X is true and isDoll and is NOT Controller - then skip to next...
                            //
                            // Note that with no other controllers, Dolly qualifies as a controller.
                            // Note, too, that if Dolly HAS a controller, then Dolly will not see
                            // the restrictions menu in that case anyway.
                                 if (afterSpace == "Self TP")      lmSendConfig("canSelfTP",     (string)(canSelfTP = isX));
                            else if (afterSpace == "Self Dress")   lmSendConfig("canDressSelf",  (string)(canDressSelf = isX));
                            else if (afterSpace == "Talk in Pose") lmSendConfig("canTalkInPose", (string)(canTalkInPose = isX));
                            else if (afterSpace == "Flying")       lmSendConfig("canFly",        (string)isX);
                            else if (afterSpace == "Reject TP")    lmSendConfig("canRejectTP",   (string)isX);
                            else isRestriction = 0;
                        }
                        else if (isX && isDoll) {
                            // Dolly (accessor) is trying to enable: reject
                                 if (afterSpace == "Self TP")      llOwnerSay("The Self TP option cannot be re-enabled by you.");
                            else if (afterSpace == "Self Dress")   llOwnerSay("The Self Dress option cannot be re-enabled by you.");
                            else if (afterSpace == "Flying")       llOwnerSay("The Flying option cannot be re-enabled by you.");
                            else if (afterSpace == "Reject TP")    llOwnerSay("The Reject TP option cannot be re-enabled by you.");
                            else if (afterSpace == "Talk in Pose") llOwnerSay("The Talk in Pose option cannot be re-enabled by you.");
                            else isRestriction = 0;
                        }

                        if (isRestriction) {
                            lmMenuReply("Restrictions...",llGetDisplayName(listenID),listenID);
                            return;
                        }
                        else {
                            //----------------------------------------
                            // Operations
                                 if (afterSpace == "Type Hovertext")     lmSendConfig("typeHovertext",   (string)isX);
#ifdef HOMING_BEACON
                            // Automatic return home after collapse (once time is up)
                            else if (afterSpace == "Homing Beacon") lmSendConfig("homingBeacon",  (string)isX);
#endif
#ifdef OPTIONAL_RLV
                            else if (afterSpace == "RLV") {
                                // we don't deal with rlvSupport here, as if rlvSupport is FALSE,
                                // this choice is never made.
                                lmSendConfig("rlvOk", (string)isX);
                                lmRlvReport(rlvOk,"",isX);
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
                            lmMenuReply("Operation...",llGetDisplayName(listenID),listenID);
                            return;
                        }
                        else {
                            // Public access and abilities
                                 if (afterSpace == "Carryable")  lmSendConfig("allowCarry",    (string)(allowCarry = isX));
                            else if (afterSpace == "Outfitable") lmSendConfig("allowDress",    (string)(allowDress = isX));
                            else if (afterSpace == "Poseable")   lmSendConfig("allowPose",     (string)(allowPose = isX));
                            else if (afterSpace == "Types")      lmSendConfig("allowTypes",    (string)(allowTypes = isX));
#ifdef ADULT_MODE
                            else if (afterSpace == "Strippable") lmSendConfig("allowStrip", (string)(allowStrip = isX));
#endif
                            else isPublic = 0;
                        }

                        if (isPublic) {
                            lmMenuReply("Public...",llGetDisplayName(listenID),listenID);
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
                        if (controllerHandle) {
                            listenerClose(controllerHandle);
                            controllerHandle = NO_HANDLE;
                        }

                        activeChannel = blacklistChannel;
                        msg = "blacklist";
                        if (blacklistList != []) {
                            dialogKeys  = cdList2ListStrided(blacklistList, 0, -1, 2);
                            dialogNames = cdList2ListStrided(blacklistList, 1, -1, 2);
                        }
                        else {
                            dialogKeys  = [];
                            dialogNames = [];
                            blacklistList   = []; // an attempt to free memory
                        }
                        blacklistHandle = cdListenUser(blacklistChannel, listenID);
                    }
                    else {
                        if (blacklistHandle) {
                            listenerClose(blacklistHandle);
                            blacklistHandle = NO_HANDLE;
                        }

                        activeChannel = controllerChannel;
#ifdef ADULT_MODE
                        msg = "controller list";
#else
                        msg = "parent list";
#endif
                        if (controllerList != []) {
                            dialogKeys  = cdList2ListStrided(controllerList, 0, -1, 2);
                            dialogNames = cdList2ListStrided(controllerList, 1, -1, 2);
                        }
                        else {
                            dialogKeys  = [];
                            dialogNames = [];
                            controllerList = []; // an attempt to free memory
                        }
                        controllerHandle = cdListenUser(controllerChannel, listenID);
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
                            llRegionSayTo(listenID, 0, msg);
                        }
                    }
                    else if (beforeSpace == CIRCLE_MINUS) {
                        if (dialogKeys == []) {
                            msg = "Your " + msg + " is empty.";
                            llRegionSayTo(listenID, 0, msg);
                            return;
                        }
                        else {
                            if (cdIsDoll(listenID)) msg = "Choose a person to remove from your " + msg;
                            else msg = "Choose a person to remove from Dolly's " + msg;
                        }

                        lmDialogListen();
                        llDialog(listenID, msg, dialogSort(llListSort(dialogButtons, 1, 1) + MAIN), activeChannel);
                        llSetTimerEvent(MENU_TIMEOUT); // set (listener) timeout for blacklist/controller menu
                    }
                    else if (beforeSpace == "List") {
                        if (dialogNames == []) {

                            if (cdIsDoll(listenID)) msg = "Your " + msg + " is empty.";
                            else msg = "Doll's " + msg + " is empty.";
                        }
                        else {
                            debugSay(4,"DEBUG-MENU","Controller list: " + llDumpList2String(controllerList,"|"));
                            debugSay(4,"DEBUG-MENU","DialogKeys: " + llDumpList2String(dialogKeys,"|"));
                            debugSay(4,"DEBUG-MENU","DialogNames: " + llDumpList2String(dialogNames,"|"));
                            if (cdIsDoll(listenID)) msg = "Current " + msg + ":";
                            else msg = "Doll's current " + msg + ":";

                            i = n;
                            string idX;
                            while (i--) {
                                idX = (string)dialogKeys[n - i - 2];
                                msg += "\n" + (string)(n - i) + ". " +
                                       "secondlife:///app/agent/" + idX + "/about";
                            }
                        }
                        llRegionSayTo(listenID, 0, msg);
                        lmMenuReply("Access...",llGetDisplayName(listenID),listenID);
                    }
                }
            }
        }
        else if ((listenChannel == blacklistChannel) || (listenChannel == controllerChannel)) {
            // This is what starts the Menu process: a reply sent out
            // via Link Message to be responded to by the appropriate script
            //lmMenuReply(listenMessage, name, listenID);

            if (listenMessage == MAIN) {
                llSetTimerEvent(MENU_TIMEOUT); // set (listener) timer for main menu from blacklist/controller menu
                lmMenuReply(MAIN, name, listenID);
                return;
            }

            string button = listenMessage;
            integer i = cdFindInList(dialogButtons, (list)listenMessage);
            string name = (string)dialogNames[i];
            string uuid = (string)dialogKeys[i];

            if (listenChannel == blacklistChannel) {

                // shutdown the listener
                listenerClose(blacklistHandle);
                blacklistHandle = NO_HANDLE;

                if (~llListFindList(blacklistList,[uuid,name]))
                    lmInternalCommand("remBlacklist", (string)uuid + "|" + name, listenID);
                else
                    lmInternalCommand("addBlacklist", (string)uuid + "|" + name, listenID);
            }
            else {

                // shutdown the listener
                listenerClose(controllerHandle);
                controllerHandle = NO_HANDLE;

                if (~llListFindList(controllerList,[uuid,name])) {
                    if (cdIsController(listenID)) lmInternalCommand("remController", (string)uuid + "|" + name, listenID);
                }
                else {
                    msg = "Dolly " + dollName + " has presented you with the power to control her Key. With this power comes great responsibility. Do you wish to accept this power?";
                    lmDialogListen();
                    llDialog((key)uuid, msg, [ "Accept", "Decline" ], dialogChannel);
                }
            }
        }
    }
}

//========== MENUHANDLER ==========
