//========================================
// Aux.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

#define DEBUG_HANDLER 1
#include "include/GlobalDefines.lsl"

#define RUNNING 1
#define NOT_RUNNING 0
#define cdStopScript(a) llSetScriptState(a, NOT_RUNNING)
#define cdRunScript(a) llSetScriptState(a, RUNNING)
#define cdResetKey() llResetOtherScript("Start")

#define WARN_MEM 6144
#define NO_FILTER ""
#define cdListenUser(a,b) llListen(a, NO_FILTER,         b, NO_FILTER)
#define UNSET -1

#define GEM_COLOR_TEXTBOX 1
#define DOLL_NAME_TEXTBOX 2

#define HIPPO_UPDATE -2948813

key memReportID;
key lmRequest;
list memList;
float listenTime;
float memTime;
string memOutput = "Script Memory Status:";
integer ncLine;
integer memReporting;
integer isDoll;
integer mustAgreeToType;
integer keyLocked;

integer textboxChannel;
integer textboxHandle;
integer textboxType;

integer i;
string msg;

// Gender is set in the preferences and the option menu
setGender(string gender) {

    switch(gender) {

        case "male": {

            dollGender     = "male";
            pronounHerDoll = "his";
            pronounSheDoll = "he";
            break;
        }

        case "female": {

            dollGender      = "female";
            pronounHerDoll  = "her";
            pronounHersDoll = "hers";
            pronounSheDoll  = "she";
            break;
        }

        case "agender": {

            dollGender      = "agender";
            pronounHerDoll  = "their";
            pronounHersDoll = "theirs";
            pronounSheDoll  = "they";
            break;
        }
    }

    lmSendConfig("dollGender",      dollGender);
    lmSendConfig("pronounHerDoll",  pronounHerDoll);
    lmSendConfig("pronounHersDoll", pronounHersDoll);
    lmSendConfig("pronounSheDoll",  pronounSheDoll);
}

default {
    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        dollID = llGetOwner();
        keyID = llGetKey();
        dollName = dollyName();
        isDoll = cdIsDoll(dollID);
        myName = llGetScriptName();
        cdInitializeSeq();
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        configured = 0;
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer lmSource, integer lmInteger, string lmData, key lmID) {

        parseLinkHeader(lmData,lmInteger);

        if (code == SEND_CONFIG) {
            string name = (string)split[0];
            list cmdList = [

                            "controllers",
#ifdef DEVELOPER_MODE
                            "debugLevel",
#endif
                            "poserID",
                            "keyLimit",
                            "windNormal",
                            "winderRechargeTime",
                            "backMenu",
#ifdef HOMING_BEACON
                            "homingBeacon",
#endif
                            "mustAgreeToType",
                            "collapseTime",
                            "collapsed",
                            "showPhrases",
                            "rlvSupport",
                            "rlvOk",
                            "dollDisplayName",
                            "poseAnimation",

                            "allowCarry",
                            "allowDress",
                            "allowTypes",
                            "allowPose",
                            "allowRepeatWind",
                            "allowSelfWind",

                            "canTalkInPose",
                            "canDressSelf",
                            "canFly",
                            "canSelfTP",
                            "canRejectTP",
#ifdef ADULT_MODE
                            "allowStrip",
                            "hardcore",
#endif
                            "blacklist",
                            "dialogChannel"
            ];

            // Commands need to be in the list cmdList in order to be
            // recognized, before testing down below
            //
            if (!cdFindInList(cmdList, name))
                return;

            string value = (string)split[1];

            split = llDeleteSubList(split, 0, 0);

                 if (name == "controllers") {
                    if (split == [""]) controllerList = [];
                    else controllerList = split;
            }
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                 debugLevel = (integer)value;
#endif
            else if (name == "poserID")                       poserID = (key)value;
            else if (name == "keyLimit")                     keyLimit = (integer)value;
            else if (name == "windNormal")                 windNormal = (integer)value;
            else if (name == "winderRechargeTime") winderRechargeTime = (integer)value;
            else if (name == "backMenu")                     backMenu = value;
#ifdef HOMING_BEACON
            else if (name == "homingBeacon")             homingBeacon = (integer)value;
#endif
            else if (name == "mustAgreeToType")       mustAgreeToType = (integer)value;
            else if (name == "collapseTime")             collapseTime = (integer)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
            else if (name == "showPhrases")               showPhrases = (integer)value;
            else if (name == "rlvSupport")                 rlvSupport = (integer)value;
            else if (name == "rlvOk")                           rlvOk = (integer)value;

            else if (name == "allowCarry")                 allowCarry = (integer)value;
            else if (name == "allowDress")                 allowDress = (integer)value;
            else if (name == "allowTypes")                 allowTypes = (integer)value;
            else if (name == "allowPose")                   allowPose = (integer)value;
            else if (name == "allowRepeatWind")       allowRepeatWind = (integer)value;
            else if (name == "allowSelfWind")           allowSelfWind = (integer)value;

            else if (name == "canSelfTP")                   canSelfTP = (integer)value;
            else if (name == "canRejectTP")               canRejectTP = (integer)value;
            else if (name == "canDressSelf")             canDressSelf = (integer)value;
            else if (name == "canFly")                         canFly = (integer)value;

            else if (name == "dollDisplayName")       dollDisplayName = value;
            else if (name == "poseAnimation")           poseAnimation = value;
            else if (name == "canTalkInPose")           canTalkInPose = (integer)value;
#ifdef ADULT_MODE
            else if (name == "allowStrip")                 allowStrip = (integer)value;
            else if (name == "hardcore")                     hardcore = (integer)value;
#endif
            else if (name == "blacklist") {
                if (split == [""]) blacklistList = [];
                else blacklistList = split;
            }
            else if (name == "dialogChannel") {
                dialogChannel = (integer)value;
                textboxChannel = dialogChannel - 1111;
            }
        }
        else if (code == SET_CONFIG) {
            string configName = (string)split[0];
            string configValue = (string)split[1];

            split = llDeleteSubList(split, 0, 0);

            switch (configName): {

                case "dollGender": {
                    setGender(configValue);
                    break;
                }
#ifdef ADULT_MODE
                case "hardcore": {
                    hardcore = (integer)configValue;

                    lmSendConfig("hardcore", (string)hardcore);

                    // FIXME: do some of these require lmSetConfig?

                    // This is a hack: this allows us to use the var hardcore to set
                    // these settings appropriately, no matter what hardcore is set to

                    // These are disabled during hardcore mode
                    lmSendConfig("canTalkInPose",   (string)(  canTalkInPose = !hardcore));
                    lmSendConfig("canDressSelf",    (string)(   canDressSelf = !hardcore));
                    lmSendConfig("canFly",          (string)(         canFly = !hardcore));
                    lmSendConfig("canSelfTP",       (string)(      canSelfTP = !hardcore));
                    lmSendConfig("mustAgreeToType", (string)(mustAgreeToType = !hardcore));
                    lmSendConfig("allowSelfWind",   (string)(  allowSelfWind = !hardcore));
                    lmSendConfig("allowRepeatWind", (string)(allowRepeatWind = !hardcore));

                    // These are enabled during hardcore mode
                    lmSendConfig("allowStrip",      (string)(     allowStrip =  hardcore));
                    lmSetConfig( "keyLocked",       (string)(      keyLocked =  hardcore));

                    // Rather than locking dolly down, these open her up: thus, the
                    // setting of these is not set then reset; rather after setting,
                    // they will not change on reset.
                    lmSendConfig("allowPose",       (string)(      allowPose = TRUE));
                    lmSendConfig("allowCarry",      (string)(     allowCarry = TRUE));
                    lmSendConfig("allowDress",      (string)(     allowDress = TRUE));
                    lmSendConfig("allowTypes",      (string)(     allowTypes = TRUE));

                    break;
                }
#endif
                case "safemode": {
                    safeMode = (integer)configValue;


                    // If we turn on safe mode, we close to public access, and open up our
                    // own. If we disable safeMode, then nothing changes except stripping and
                    // hardcore are allowed.
                    //
                    // Most of these are just a collection of settings; the user can change them
                    // after safemode is enabled.
                    //
                    if (safeMode) {
#ifdef ADULT_MODE
                        lmSendConfig("hardcore",        (string)(       hardcore = FALSE));
                        lmSendConfig("allowStrip",      (string)(     allowStrip = FALSE));
#endif
                        lmSendConfig("allowPose",       (string)(      allowPose = FALSE));
                        lmSendConfig("allowCarry",      (string)(     allowCarry = FALSE));
                        lmSendConfig("allowDress",      (string)(     allowDress = FALSE));
                        lmSendConfig("allowTypes",      (string)(     allowTypes = FALSE));
                        lmSendConfig("allowSelfWind",   (string)(  allowSelfWind = TRUE));
                        lmSendConfig("allowRepeatWind", (string)(allowRepeatWind = TRUE));

                        lmSetConfig( "keyLocked",       (string)(      keyLocked = FALSE));

                        lmSendConfig("canTalkInPose",   (string)(  canTalkInPose = TRUE));
                        lmSendConfig("canDressSelf",    (string)(   canDressSelf = TRUE));
                        lmSendConfig("canFly",          (string)(         canFly = TRUE));
                        lmSendConfig("canSelfTP",       (string)(      canSelfTP = TRUE));

                        lmSendConfig("mustAgreeToType", (string)(mustAgreeToType = TRUE));

                    }

                    break;
                }
            }
        }
        else if (code == INTERNAL_CMD) {
            string cmd = (string)split[0];
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "collapsedMenu") {
                // this is only called for Dolly - so...
                list menu = [ "Ok" ];

                // is it possible to be collapsed but collapseTime be equal to 0.0?
                if (collapsed) {
                    msg = "You need winding. You have been collapsed for ";
                    integer timeCollapsed = llGetUnixTime() - collapseTime;

                    integer minutesCollapsed = llFloor(timeCollapsed / SEC_TO_MIN);

                    if (minutesCollapsed > 1) msg += (string)minutesCollapsed + " minutes. ";
                    else msg += (string)timeCollapsed + " seconds.";

#ifdef DEVELOPER_MODE
                    // Status messages for developers
                    msg += "\n\nTime before Emg Wind: " + (string)TIME_BEFORE_EMGWIND + "\nTime elapsed: " + (string)timeCollapsed + "\n";
                    msg += "\nTime before TP: " + (string)TIME_BEFORE_TP;
#endif

                    // Only present the TP home option for the doll if they have been collapsed
                    // for at least 900 seconds (15 minutes) - Suggested by Christina

#ifdef ADULT_MODE
                    if (!hardcore) {
#endif
#ifdef TP_HOME
                        if (rlvOk) {
                            if (timeCollapsed > TIME_BEFORE_TP) {
#ifdef HOMING_BEACON
                                // if Homing Beacon is activated, then the only TP is automated
                                if (!homingBeacon)
#endif
                                    if (llGetInventoryType(LANDMARK_HOME) == INVENTORY_LANDMARK)
                                        menu += ["TP Home"];
                            }
                        }
#endif

                        // If the doll is still down after 1800 seconds (30 minutes) and their
                        // emergency winder is recharged; add a button for it

                        if (timeCollapsed > TIME_BEFORE_EMGWIND) {
                            if (winderRechargeTime <= llGetUnixTime())
                                menu += ["Wind Emg"];
                        }
#ifdef ADULT_MODE
                    }
#endif

                    lmDialogListen();
                    llDialog(dollID, msg, menu, dialogChannel);
                }
            }
            else if (cmd == "chatHelp") {

#define accessorID           (key)split[0]

#define accessorIsDoll       (cdIsDoll(accessorID))
#define accessorIsController (cdIsController(accessorID))
#define accessorIsCarrier    (cdIsCarrier(accessorID))

                // First: anyone can do these commands
                string help = "Commands:
    Commands need to be prefixed with the prefix, which is currently " + llToLower(chatPrefix) + "

    help ........... this list of commands
    menu ........... show main menu
    stat ........... concise current status
    wind ........... wind key";

                string help2;

                string posingHelp = "
    release ........ stop the current pose if possible
    unpose ......... stop the current pose if possible
    [posename] ..... activate the named pose if possible
    pose XXX ....... activate the named pose if possible
    listposes ...... list all poses";

                string carryHelp = "
    carry .......... carry dolly
    uncarry ........ put down dolly";

                // Only Dolly or Controller or Carrier can do these commands
                if (accessorIsDoll || accessorIsController || accessorIsCarrier) {
                    help += "
    stats .......... selected statistics and settings
    xstats ......... extended statistics and settings" +
                    posingHelp +
                    carryHelp;

                    // Only Dolly can do these
                    if (accessorIsDoll) {
                        help2 += "Commands (page2):

    hide ........... make key invisible
    unhide ......... make key visible
    show ........... make key visible
    visible ........ make key visible
    ghost .......... make key visible and ghostly
    prefix XX ...... change chat command prefix
    controller NN .. add controller
    channel ## ..... change channel
    blacklist NN ... add to blacklist
    unblacklist NN . remove from blacklist";
                    }
                }

                // Anyone other than Controllers / Carriers / Dolly
                else {

                    // Only if poses are allowed
                    if (allowPose) help += posingHelp;

                    // Only if carry is allowed
                    if (allowCarry) help += carryHelp;
                }

                cdSayTo(help + "\n", accessorID);
                if (help2 != "") cdSayTo(help2 + "\n", accessorID);

#ifdef DEVELOPER_MODE
                // Developer Dolly commands...
                if (accessorIsDoll) {
                    help = "
    Debugging commands:

    build .......... list build configurations
    debug # ........ set the debugging message verbosity 0-9
    inject x#x#x ... inject a link message with \"code#data#key\"
    collapse ....... perform an immediate collapse (out of time)";
                    cdSayTo(help + "\n", accessorID);
                }
#endif
            }
#ifdef ADULT_MODE
            else if (cmd == "strip") {
                // llToLower() may be superfluous here
                string part = llToLower((string)split[0]);

                if (lmID != dollID) {

                    // if Dolly is stripped by someone else, Dolly cannot
                    // dress for a time: wearLock is activated

                    lmInternalCommand("wearLock", (string)TRUE, NULL_KEY);

                    llOwnerSay("You have been stripped and may not redress for " + (string)llRound(WEAR_LOCK_TIMEOUT / 60.0) + " minutes.");
                }
                else llOwnerSay("You have stripped off your clothes.");
                lmInternalCommand("stripAll", "", lmID);
            }
#endif
        }
        else if (code == RLV_RESET) {
            rlvOk = (integer)split[0];
            debugSay(4,"DEBUG-AUX","rlvOk set to " + (string)rlvOk);
        }
        else if (code == MENU_SELECTION) {
            string menuChoice = (string)split[0];
            string avatar = (string)split[1];

#define isObjectPresent(o) (llGetInventoryType(o) == INVENTORY_OBJECT)
#define isLandmarkPresent(a) (llGetInventoryType(a) == INVENTORY_LANDMARK)
#define notPosed() (poseAnimation == ANIMATION_NONE)

            if (menuChoice == "Help...") {
                msg = "Here you can find various options to get help with your key and to connect with the community.";
                list helpMenuButtons = [ "Join Group", "Visit Website", "Visit Blog", "Visit Development" ];

                if (isNotecardPresent(NOTECARD_HELP))
                    helpMenuButtons += "Help Notecard";

                if (isLandmarkPresent(LANDMARK_CDHOME))
                    helpMenuButtons += "Visit Dollhouse";

                if (isObjectPresent(OBJECT_KEY))
                    helpMenuButtons += "Get Key";

                // Note - to do this Key handout properly, we'd need an infinite Key:
                // a Key which contains a Key which contains a Key which contains a Key...
                // Like a never-ending matrushka doll.
                //

                if (cdIsDoll(lmID)) {
#ifdef OPTIONAL_RLV
                    if (rlvOk == FALSE) {
                        helpMenuButtons += "RLV"; // To be able to enable RLV when checker fails: one-way button
                    }
#endif
                    if (!collapsed) if (notPosed()) {

                        // This is to totally reset Dolly's worn body,
                        // using the ~normalself, ~normaloutfit,  and ~nude folders
                        //
                        // Note that Dolly cannot be posed and cannot be collapsed to access these
                        //
                        if (!cdHasControllers()) {
                            if (rlvOk) helpMenuButtons += "Reset Body";
                            helpMenuButtons += [ "Reset Key", "Update" ];
                        }
                    }
                }
                else {
                    if (cdIsController(lmID)) {
                        if (rlvOk) helpMenuButtons += "Reset Body";
                        helpMenuButtons += "Reset Key";
                    }
                }

                lmDialogListen();
                llDialog(lmID, msg, [ "Back..." ] + dialogSort(helpMenuButtons), dialogChannel);
            }
            else if (menuChoice == "Reset Body") {
                lmInternalCommand("resetBody","",lmID);
            }
            else if (menuChoice == "Help Notecard") {
                llGiveInventory(lmID,NOTECARD_HELP);
            }
            else if (menuChoice == "Get Key") {
                llGiveInventory(lmID,OBJECT_KEY);
            }
            else if (menuChoice == "Visit Dollhouse") {
                // If is Dolly, whisk Dolly away to Location of Landmark
                // If is someone else, give Landmark to them
#ifdef TP_HOME
                if (cdIsDoll(lmID)) {
                    if (rlvOk) {
                        lmInternalCommand("teleport", LANDMARK_CDHOME, lmID);
                    }
                    else
                        llGiveInventory(lmID, LANDMARK_CDHOME);
                }
#else
                llGiveInventory(lmID, LANDMARK_CDHOME);
#endif
            }
            else if (menuChoice == "Visit Development")
                cdSayTo("Here is your link to the Community Doll Key development: " + WEB_DEV, lmID);
            else if (menuChoice == "Visit Website")
                cdSayTo("Here is your link to the Community Dolls blog: " + WEB_BLOG, lmID);
            else if (menuChoice == "Visit Blog")
                cdSayTo("Here is your link to the Community Dolls website: " + WEB_DOMAIN, lmID);
            else if (menuChoice == "Join Group")
                cdSayTo("Here is your link to the Community Dolls group profile: " + WEB_GROUP, lmID);
            else if (menuChoice == "Update") {
                //llSay(PUBLIC_CHANNEL,"Update starting....");
                lmSendConfig("update","1");
            }

            else if (menuChoice == "Access...") {
                msg =
#ifdef ADULT_MODE
                      "Key Access Menu.\n\nThese are powerful options allowing you to give someone total control of your key or to block someone from touching or even winding your key. Good dollies should read their key help before adjusting these options.
                             
Blacklist - Block a person from using the key entirely (even winding!)
Controller - Take care choosing your controllers; they have great control over Dolly and cannot be removed by you";
#else
                      "Key Access Menu.\n\nThese are powerful options allowing you to give someone total parental control of your key or block someone from touching or even winding your key. Good dollies should read their key help before adjusting these options.
                             
Blacklist - Block a person from using the key entirely (even winding!)
Parent - Take care choosing your parents; they have great control over Dolly and cannot be removed by you";
#endif
                list plusList;

                // This complicated setup really isnt: it follows these rules:
                //
                //  * If there's no blacklist entries, you can't remove (but can still list)
                //  * If there's no controller entries, you can't remove (but can still list)
                //  * If you are controller, you can remove controllers
                //  * If you are Dolly, you can manipulate the blacklist
                //  * If you are Dolly, you can add controllers
                //  * If you are controller OR Dolly, you can list Controllers
                //
                // Why allow listing an empty list? It is a way of confirming status to the
                // viewer, with the appropriate message (already provided for)
                //
#ifdef ADULT_MODE
                if ((cdIsController(lmID)) && (cdControllerCount() > 0)) plusList = [ "⊖ Controller" ];
#else
                if ((cdIsController(lmID)) && (cdControllerCount() > 0)) plusList = [ "⊖ Parent" ];
#endif

                if (cdIsDoll(lmID)) {
                    plusList += [ "⊕ Blacklist", "List Blacklist" ];

                    if (llGetListLength(blacklistList)) plusList += [ "⊖ Blacklist" ];
#ifdef ADULT_MODE
                    plusList += [ "⊕ Controller" ];
#else
                    plusList += [ "⊕ Parent" ];
#endif
                }

#ifdef ADULT_MODE
                plusList +=  "List Controller";
#else
                plusList +=  "List Parent";
#endif

                lmSendConfig("backMenu",(backMenu = "Options..."));
                lmDialogListen();
                llDialog(lmID, msg, dialogSort(plusList + "Back..."), dialogChannel);
            }
            else if (menuChoice == "Restrictions...") {
                msg = "";
                list plusList;

                // The following options require RLV to work
                if (rlvOk == TRUE) {
                    msg = "See the help file for explanations of these options. ";
                    lmSendConfig("backMenu",(backMenu = "Options..."));

                    // One-way options
#ifdef ADULT_MODE
                    if (!hardcore) {
#endif
                        plusList += cdGetButton("Talk In Pose", lmID, canTalkInPose, 1);
                        plusList += cdGetButton("Self Dress",   lmID, canDressSelf, 1);
                        plusList += cdGetButton("Flying",       lmID, canFly, 1);
                        plusList += cdGetButton("Self TP",      lmID, canSelfTP, 1);
#ifdef ADULT_MODE
                    }
#endif
                    // I could add "Reject TP" to hardcore but with an option that extreme...
                    // Dolly needs to actively enable it.
                    plusList += cdGetButton("Reject TP", lmID, canRejectTP, 1);
                    plusList += "Back...";
                }
                else {

#define _Her_ pronounHerDoll
#define _She_ pronounSheDoll

                    msg += "Either Dolly does not have an RLV capable viewer, or " + _She_ + " has RLV turned off in " + _Her_ + " viewer settings.  There are no usable options available.";

                    plusList = [ "OK" ];
                }

                lmDialogListen();
                llDialog(lmID, msg, dialogSort(plusList), dialogChannel);
            }
            else if (menuChoice == "Public...") {
                // This menu should not activate for hardcore Dollies
                msg = "These are options for controlling what a member of the public can do with Dolly.";
                list plusList = [];

                if (dollType != "Display") {
                    plusList += cdGetButton("Poseable", lmID, allowPose, 0);
                }

                plusList += cdGetButton("Carryable", lmID, allowCarry, 0);
                if (rlvOk == TRUE) {
                    plusList += cdGetButton("Outfitable", lmID, allowDress, 0);
                    plusList += cdGetButton("Types",      lmID, allowTypes, 0);
#ifdef ADULT_MODE
                    if (!safeMode) {
                        plusList += cdGetButton("Strippable", lmID, allowStrip, 0);
                    }
#endif
                }
                lmSendConfig("backMenu",(backMenu = "Options..."));
                lmDialogListen();
                llDialog(lmID, msg, dialogSort(plusList + "Back..."), dialogChannel);
            }
            else if (menuChoice == "Operation...") {
                msg = "See the helpfile for explanations.";
                list plusList = [];

                // Only items in Operation menu are:
                //
                // * Homing Beacon (optional)
                // * RLV (optional)
                // * Rpt Wind
                //
                // Perhaps should be in other menu?

#ifdef HOMING_BEACON
                if (rlvOk)
                    plusList += cdGetButton("Homing Beacon", lmID, homingBeacon, 0);
#endif
#ifdef OPTIONAL_RLV
                if (rlvSupport == TRUE) {
#ifdef ADULT_MODE
                    if (!hardcore)
#endif
                        plusList += cdGetButton("RLV", lmID, rlvOk, 0);
                }
#endif

                // One-way options
                if (cdIsController(lmID)) {
#ifdef ADULT_MODE
                    if (!hardcore)
#endif
                        plusList = llListInsertList(plusList, cdGetButton("Rpt Wind", lmID, allowRepeatWind, 1), 6);
                }

                lmSendConfig("backMenu",(backMenu = "Options..."));
                lmDialogListen();
                llDialog(lmID, msg, dialogSort(plusList + "Back..."), dialogChannel);
            }
            else if (menuChoice == "Back...") {
                lmMenuReply(backMenu, llGetDisplayName(lmID), lmID);
                lmSendConfig("backMenu",(backMenu = MAIN));
            }
            else if (menuChoice == "Key...") {

                list plusList = ["Dolly Name...","Gender:" + dollGender];
                string msg = "Here you can set various general key settings.\n\n" +
                             "Dolly Name: " + dollDisplayName + "\n" +
                             "Doll Gender: " + dollGender + "\n" +
                             "Wind Time: " + (string)(windNormal / SECS_PER_MIN) + "\n" +
                             "Max Time: " + (string)(keyLimit / SECS_PER_MIN);

                lmSendConfig("backMenu",(backMenu = "Options..."));
                if (cdIsController(lmID)) plusList += [ "Max Time...", "Wind Time..." ];
                lmDialogListen();
                llDialog(lmID, msg, dialogSort(llListSort(plusList, 1, 1) + "Back..."), dialogChannel);
            }
            else if (llGetSubString(menuChoice,0,6) == "Gender:") {
                string s = llGetSubString(menuChoice,7,-1);
                debugSay(4,"DEBUG-AUX","Gender selected: " + s);

                // Whatever the current element is - set gender
                // to the next in a circular loop

                     if (s == "male")    setGender("female");
                else if (s == "female")  setGender("agender");
                else if (s == "agender") setGender("male");

                llOwnerSay("Gender is now set to " + dollGender);
                lmMenuReply("Key...", llGetDisplayName(lmID), lmID);
            }

            // Textbox generating menus
            else if (menuChoice == "Dolly Name...") {
                if (menuChoice == "Dolly Name...") {
                    textboxType = DOLL_NAME_TEXTBOX;
                    llTextBox(lmID, "Here you can change your dolly name from " + dollDisplayName + " to a name of your choice.", textboxChannel);
                }

                if (textboxHandle) llListenRemove(textboxHandle);
                textboxHandle = cdListenUser(textboxChannel, lmID);
                listenTime = llGetTime() + 60.0;
                llSetTimerEvent(60.0);
            }

            // Note that Max Times are "m" and Wind Times are "min" - this is on purpose to
            // keep the two separate
            else if (menuChoice == "Max Time...") {
#ifdef ADULT_MODE
                list maxList = [ "45m", "60m", "75m", "90m", "120m" ];
                if (!hardcore) maxList += [ "150m", "180m", "240m" ];
#else
                list maxList = [ "45m", "60m", "75m", "90m", "120m", "150m", "180m", "240m" ];
#endif
                maxList += MAIN;

                // If the Max Times available are changed, be sure to change the next choice also
                lmDialogListen();
                llDialog(lmID, "You can set the maximum available time here.  Dolly cannot be wound beyond this amount of time.\nDolly currently has " + (string)llFloor(timeLeftOnKey / SECS_PER_MIN) + " mins left of " + (string)llFloor(keyLimit / SECS_PER_MIN) + ". If you lower the maximum, Dolly will lose any extra time entirely.",
                    dialogSort(maxList), dialogChannel);
            }

            // This is setting the windNormal; we don't have to check to see if
            // it is too large: this is done during the menu creation phase
            //
            else if ((menuChoice ==  "15min") ||
                     (menuChoice ==  "30min") ||
                     (menuChoice ==  "45min") ||
                     (menuChoice ==  "60min") ||
                     (menuChoice ==  "90min") ||
                     (menuChoice == "120min")) {

                windNormal = (integer)menuChoice * (integer)SECS_PER_MIN;
                lmSetConfig("windNormal", (string)windNormal);

                cdSayTo("Winding now set to " + (string)(windNormal / (integer)SECS_PER_MIN) + " minutes",lmID);
                lmMenuReply("Key...","",lmID);
            }

            // This is setting the keyLimit; windNormal is adjusted if necessary
            //
            else if ((menuChoice ==  "45m") ||
                     (menuChoice ==  "60m") ||
                     (menuChoice ==  "75m") ||
                     (menuChoice ==  "90m") ||
                     (menuChoice == "120m") ||
                     (menuChoice == "150m") ||
                     (menuChoice == "180m") ||
                     (menuChoice == "240m")) {

                keyLimit = (integer)menuChoice * SECS_PER_MIN;
                lmSetConfig("keyLimit", (string)keyLimit);

                cdSayTo("Key limit now set to " + (string)llFloor(keyLimit / SECS_PER_MIN) + " minutes",lmID);

                lmMenuReply("Key...","",lmID);
            }
            else if (menuChoice == "Wind Time...") {
                list windChoices;

                // Build up the allowed winding times based on the KeyLimit
                if (keyLimit >=  30) windChoices +=  "15min";
                if (keyLimit >=  60) windChoices +=  "30min";
                if (keyLimit >=  90) windChoices +=  "45min";
                if (keyLimit >= 120) windChoices +=  "60min";
                if (keyLimit >= 180) windChoices +=  "90min";
                if (keyLimit >= 240) windChoices += "120min";

                lmDialogListen();
                llDialog(lmID, "You can set the amount of time in each wind.\nDolly currently winds " + (string)(windNormal / (integer)SECS_PER_MIN) + " mins.",
                    dialogSort(windChoices + [ MAIN ]), dialogChannel);
            }
        }

        // 15: lmSendToController
        //
        else if (code < 200) {
            if (code == 15) {

                //----------------------------------------
                // lmSendToController
                msg = (string)split[0];
                key targetKey;
                integer n = llGetListLength(cdList2ListStrided(controllerList, 0, -1, 2));

                while (n--) {
                    targetKey = (key)controllerList[(n << 1]);

                    lmInternalCommand("instantMessage", msg, targetKey);
                }
            }
            else if (code == INIT_STAGE2) {
                configured = 1;
            }
#ifdef DEVELOPER_MODE
            // Generate memory report on startup
            else if (code == INIT_STAGE5) {
                llSleep(5.0);
                lmMemReport(0.5, dollID);
            }
#endif
            else if (code == MEM_REPORT) {
                float delay  = (float)split[0];
                memReportID = lmID;
                memReport("Aux",1.0);
            }
            else if (code == MEM_REPLY) {
                memReporting = 1;
                llSetTimerEvent(0.5); // when timer goes off, we assume completion
                float usedMemory  = (float)split[0];
                float memoryLimit = (float)split[1];
                float freeMemory  = (float)split[2];
                float availMemory = (float)split[3];

#ifdef DEVELOPER_MODE
                // In Developer Keys we want to see the works: all the details
                memList += "\n" + script + ": " +
                    formatFloat(usedMemory / 1024.0, 2) + "kB used (" +
                    formatFloat(freeMemory / 1024.0, 2) + "kB free)";
#else
                // The user only cares about free memory when things are going south
                if (availMemory < WARN_MEM) {
                    memList += "\n" + script + ": " +
                        formatFloat(availMemory / 1024.0, 2) + "kB available";
                }
#endif
            }
            else if (code == CONFIG_REPORT) {
                cdConfigureReport();
            }
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer listenChannel, string listenName, key listenID, string listenMessage) {

        if (listenChannel == textboxChannel) {
            llListenRemove(textboxHandle);
            textboxHandle = 0;
            listenTime = 0.0;
            string origChoice = listenMessage;

            // Text box input - 1 types
            //   1: Dolly Name

            // This test is not really needed - but in the interest of
            // expansion, this allows more text box types to be created later
            if (textboxType == DOLL_NAME_TEXTBOX) {
                lmSendConfig("dollDisplayName", listenMessage);
                lmMenuReply("Key...", llGetDisplayName(listenID), listenID);
            }
#ifdef DEVELOPER_MODE
            else llSay(DEBUG_CHANNEL,"Unknown textbox type! (" + (string)textboxType + ")");
#endif
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
        if (memReporting) {

            integer i = llGetInventoryNumber(INVENTORY_SCRIPT);
            string script;

            while (i--) {
                script = llGetInventoryName(INVENTORY_SCRIPT, i);

                if (script != "Aux" && (!cdFindInList(memList,script))) {
                    if (!llGetScriptState(script))
                        memList += "\n" + script + ":\t" + "---- script not running! ----";
                }
            }

#ifndef DEVELOPER_MODE
            if (memList == []) {
                memList = (list)"No problems to report.";
            }
            else
#endif
            memList = llListSort(memList,1,1);

            cdSayTo(memOutput + llDumpList2String(memList,""),memReportID);

            memOutput = "Script Memory Status:";
            memReporting = 0;
            memList = [];
            memReportID = NULL_KEY;
        }
        else if (textboxHandle) {
            if (listenTime < llGetTime()) {
                llListenRemove(textboxHandle);
                textboxHandle = 0;
            }
        }
        else llSetTimerEvent(0.0);
    }
}

//========== AUX ==========
