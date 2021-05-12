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
integer maxMins;
integer ncLine;
integer memReporting;
integer isDoll;

integer textboxChannel;
integer textboxHandle;
integer textboxType;

integer i;
string msg;

// Gender is set in the preferences and the option menu
setGender(string gender) {

    if (gender == "male") {
        dollGender     = "male";
        pronounHerDoll = "his";
        pronounSheDoll = "he";
    }
    else {
        dollGender     = "female";
        pronounHerDoll = "her";
        pronounSheDoll = "she";
    }

    lmSendConfig("dollGender",     dollGender);
    lmSendConfig("pronounHerDoll", pronounHerDoll);
    lmSendConfig("pronounSheDoll", pronounSheDoll);
}

default {
    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        dollID = llGetOwner();
        keyID = llGetKey();
        dollName = lmMyDisplayName(dollID);
        isDoll = cdIsDoll(dollID);
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
    link_message(integer source, integer i, string data, key id) {

        // Parse link message header information
        split     = cdSplitArgs(data);
        script    = cdListElement(split, 0);
        remoteSeq = (i & 0xFFFF0000) >> 16;
        optHeader = (i & 0x00000C00) >> 10;
        code      =  i & 0x000003FF;
        split     = llDeleteSubList(split, 0, 0 + optHeader);

        if (code == SEND_CONFIG) {
            string name = (string)split[0];
            string value = (string)split[1];

            split = llDeleteSubList(split, 0, 0);

                 if (name == "controllers") {
                    if (split == [""]) controllers = [];
                    else controllers = split;
            }
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                 debugLevel = (integer)value;
#endif
            else if (name == "poserID")                       poserID = (key)value;
            else if (name == "keyLimit")                      maxMins = llRound((float)value / 60.0);
            else if (name == "winderRechargeTime") winderRechargeTime = (integer)value;
            else if (name == "backMenu")                     backMenu = value;
#ifdef HOMING_BEACON
            else if (name == "homingBeacon")             homingBeacon = (integer)value;
#endif
            else if (name == "collapseTime")             collapseTime = (integer)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
            else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "showPhrases")               showPhrases = (integer)value;
            else if (name == "RLVsupport")                 RLVsupport = (integer)value;
            else if (name == "RLVok")                           RLVok = (integer)value;
            else if (name == "allowCarry")                 allowCarry = (integer)value;
            else if (name == "allowDress")                 allowDress = (integer)value;
            else if (name == "allowPose")                   allowPose = (integer)value;
            else if (name == "canDressSelf")             canDressSelf = (integer)value;
            else if (name == "canFly")                         canFly = (integer)value;
            else if (name == "canSit")                         canSit = (integer)value;
            else if (name == "canStand")                     canStand = (integer)value;
            else if (name == "allowRepeatWind")       allowRepeatWind = (integer)value;
            else if (name == "allowSelfWind")           allowSelfWind = (integer)value;
            else if (name == "dollDisplayName")       dollDisplayName = value;
            else if (name == "poseAnimation")           poseAnimation = value;
//          else if (name == "doWarnings")                 doWarnings = (integer)value;
            else if (name == "hardcore")                     hardcore = (integer)value;
            else if (name == "poseSilence")               poseSilence = (integer)value;
            else if (name == "detachable")                 detachable = (integer)value;
            else if (name == "canSelfTP")                   canSelfTP = (integer)value;
#ifdef ADULT_MODE
            else if (name == "allowStrip")             allowStrip = (integer)value;
#endif
            else if (name == "wearLock")                     wearLock = (integer)value;
            else if (name == "blacklist") {
                if (split == [""]) blacklist = [];
                else blacklist = split;
            }
            else if (name == "dialogChannel") {
                dialogChannel = (integer)value;
                textboxChannel = dialogChannel - 1111;
            }
        }
        else if (code == SET_CONFIG) {
                string name = (string)split[0];
                string value = (string)split[1];

                split = llDeleteSubList(split, 0, 0);

                if (name == "dollGender") setGender(value);
        }
        else if (code == INTERNAL_CMD) {
            string cmd = (string)split[0];
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "collapsedMenu") {
                // this is only called for Dolly - so...
                string timeLeft = (string)split[0];
                list menu = [ "Ok" ];

                // is it possible to be collapsed but collapseTime be equal to 0.0?
                if (collapsed) {
                    msg = "You need winding. ";
                    integer timeCollapsed = llGetUnixTime() - collapseTime;

#ifdef DEVELOPER_MODE
                    msg += "You have been collapsed for " + (string)llFloor(timeCollapsed / SEC_TO_MIN) + " minutes (" + (string)timeCollapsed + " seconds). ";
                    msg += "\n\nTime before TP: " + (string)TIME_BEFORE_TP + "\nTime before Emg Wind: " + (string)TIME_BEFORE_EMGWIND + "\nTime elapsed: " + (string)timeCollapsed + "\n";
#endif

                    // Only present the TP home option for the doll if they have been collapsed
                    // for at least 900 seconds (15 minutes) - Suggested by Christina

                    if (timeCollapsed > TIME_BEFORE_TP) {
#ifdef HOMING_BEACON
                        if (!homingBeacon)
#endif
                            if (llGetInventoryType(LANDMARK_HOME) == INVENTORY_LANDMARK)
                                menu += ["TP Home"];

                        // If the doll is still down after 1800 seconds (30 minutes) and their
                        // emergency winder is recharged; add a button for it

                        if (!hardcore) {
                            if (timeCollapsed > TIME_BEFORE_EMGWIND) {
                                if (winderRechargeTime <= llGetUnixTime())
                                    menu += ["Wind Emg"];
                            }
                        }
                    }

                    cdDialogListen();
                    llDialog(dollID, msg, menu, dialogChannel);
                }
            }
#ifdef ADULT_MODE
            else if (cmd == "strip") {
                // llToLower() may be superfluous here
                string part = llToLower((string)split[0]);

                if (id != dollID) {

                    // if Dolly is stripped by someone else, Dolly cannot
                    // dress for a time: wearLock is activated

                    lmSetConfig("wearLock", "1");

                    llOwnerSay("You have been stripped and may not redress for " + (string)llRound(WEAR_LOCK_TIMEOUT / 60.0) + " minutes.");
                }
                else llOwnerSay("You have stripped off your clothes.");
                lmInternalCommand("stripAll", "", id);
            }
#endif
        }
        else if (code == RLV_RESET) {
            RLVok = (integer)split[0];
            debugSay(4,"DEBUG-AUX","RLVok set to " + (string)RLVok);
        }
        else if (code == MENU_SELECTION) {
            string choice = (string)split[0];
            string avatar = (string)split[1];

#define isObjectPresent(o) (llGetInventoryType(o) == INVENTORY_OBJECT)
#define isLandmarkPresent(a) (llGetInventoryType(a) == INVENTORY_LANDMARK)
#define notPosed() (poseAnimation == ANIMATION_NONE)

            if (choice == "Help...") {
                msg = "Here you can find various options to get help with your key and to connect with the community.";
                list helpMenuList = [ "Join Group", "Visit Website", "Visit Blog", "Visit Development" ];

                if (isNotecardPresent(NOTECARD_HELP))
                    helpMenuList += [ "Help Notecard" ];

                if (isLandmarkPresent(LANDMARK_CDHOME))
                    helpMenuList += [ "Visit Dollhouse" ];

                // Note - to do this Key handout properly, we'd need an infinite Key:
                // a Key which contains a Key which contains a Key which contains a Key...
                // Like a never-ending matrushka doll.
                //

                if (cdIsDoll(id)) {
                    if (!collapsed) if (notPosed())

                        // This is to totally reset Dolly's worn body,
                        // using the ~normalself, ~normaloutfit,  and ~nude folders
                        //
                        // Note that Dolly cannot be posed and cannot be collapsed to access these
                        //
                        helpMenuList += [ "Reset Body", "Reset Key", "Update" ];
                        //if (detachable) menu += [ "Detach" ];
                }
                else {
                    if (isObjectPresent(OBJECT_KEY))
                        helpMenuList += [ "Get Key" ];

                    if (cdIsController(id)) helpMenuList += "Reset Key";
                }

                cdDialogListen();
                llDialog(id, msg, [ "Back..." ] + dialogSort(helpMenuList), dialogChannel);
            }
            else if (choice == "Reset Body") {
                lmInternalCommand("resetBody","",id);
            }
            else if (choice == "Help Notecard") {
                llGiveInventory(id,NOTECARD_HELP);
            }
            else if (choice == "Get Key") {
                llGiveInventory(id,OBJECT_KEY);
            }
            else if (choice == "Visit Dollhouse") {
                // If is Dolly, whisk Dolly away to Location of Landmark
                // If is someone else, give Landmark to them
                if (cdIsDoll(id))
                    lmInternalCommand("teleport", LANDMARK_CDHOME, id);
                else llGiveInventory(id, LANDMARK_CDHOME);
            }
            else if (choice == "Visit Development")
                cdSayTo("Here is your link to the Community Doll Key development: " + WEB_DEV, id);
            else if (choice == "Visit Website")
                cdSayTo("Here is your link to the Community Dolls blog: " + WEB_BLOG, id);
            else if (choice == "Visit Blog")
                cdSayTo("Here is your link to the Community Dolls website: " + WEB_DOMAIN, id);
            else if (choice == "Join Group")
                cdSayTo("Here is your link to the Community Dolls group profile: " + WEB_GROUP, id);
            else if (choice == "Update") {
                //llSay(PUBLIC_CHANNEL,"Update starting....");
                lmSendConfig("update","1");
            }

            else if (choice == "Access...") {
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
                if ((cdIsController(id)) && (cdControllerCount() > 0)) plusList = [ "⊖ Controller" ];
#else
                if ((cdIsController(id)) && (cdControllerCount() > 0)) plusList = [ "⊖ Parent" ];
#endif

                if (cdIsDoll(id)) {
                    plusList += [ "⊕ Blacklist", "List Blacklist" ];

                    if (llGetListLength(blacklist)) plusList += [ "⊖ Blacklist" ];
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
                cdDialogListen();
                llDialog(id, msg, dialogSort(plusList + "Back..."), dialogChannel);
            }
            else if (choice == "Restrictions...") {
                msg = "";
                list plusList;

                // The following options require RLV to work
                if (RLVok == TRUE) {
                    msg = "See the help file for explanations of these options. ";

                    // One-way options
                    if (!hardcore) {
                        plusList += cdGetButton("Detachable", id, detachable, 1);
                        plusList += cdGetButton("Silent Pose", id, poseSilence, 1);
                        plusList += cdGetButton("Self Dress", id, canDressSelf, 1);
                    }
                    lmSendConfig("backMenu",(backMenu = "Options..."));

                    plusList += cdGetButton("Flying", id, canFly, 1);
                    plusList += cdGetButton("Sitting", id, canSit, 1);
                    plusList += cdGetButton("Standing", id, canStand, 1);
                    plusList += cdGetButton("Self TP", id, canSelfTP, 1);
                    plusList += cdGetButton("Force TP", id, autoTP, 1);
                    plusList += "Back...";
                }
                else {
                    string p = pronounHerDoll;
                    string s = pronounSheDoll;

                    msg += "Either Dolly does not have an RLV capable viewer, or " + s + " has RLV turned off in " + p + " viewer settings.  There are no usable options available.";

                    plusList = [ "OK" ];
                }

                cdDialogListen();
                llDialog(id, msg, dialogSort(plusList), dialogChannel);
            }
            else if (choice == "Public...") {
                msg = "These are options for controlling what a member of the public can do with Dolly.";
                list plusList = [];

                if (dollType != "Display" && !hardcore) {
                    plusList += cdGetButton("Poseable", id, allowPose, 0);
                }

                if (!hardcore) {
                    plusList += cdGetButton("Carryable", id, allowCarry, 0);
                    if (RLVok == TRUE) {
                        plusList += cdGetButton("Outfitable", id, allowDress, 0);
#ifdef ADULT_MODE
                        plusList += cdGetButton("Strippable", id, allowStrip, 0);
#endif
                    }
                }
                lmSendConfig("backMenu",(backMenu = "Options..."));
                cdDialogListen();
                llDialog(id, msg, dialogSort(plusList + "Back..."), dialogChannel);
            }
            else if (choice == "Operation...") {
                msg = "See the helpfile for explanations.";
                list plusList = [];

                plusList += cdGetButton("Type Text", id, hovertextOn, 0);
//              plusList += cdGetButton("Warnings", id, doWarnings, 0);
                plusList += cdGetButton("Phrases", id, showPhrases, 0);
#ifdef HOMING_BEACON
                plusList += cdGetButton("Homing Beacon", id, homingBeacon, 0);
#endif
                if (RLVsupport == TRUE) {
                    if (!hardcore) plusList += cdGetButton("RLV", id, RLVok, 0);
                }

                // One-way options
                if (cdIsController(id)) {
                    plusList = llListInsertList(plusList, cdGetButton("Rpt Wind", id, allowRepeatWind, 1), 6);
                }

                lmSendConfig("backMenu",(backMenu = "Options..."));
                cdDialogListen();
                llDialog(id, msg, dialogSort(plusList + "Back..."), dialogChannel);
            }
            else if (choice == "Back...") {
                lmMenuReply(backMenu, llGetDisplayName(id), id);
                lmSendConfig("backMenu",(backMenu = MAIN));
            }
            else if (choice == "Key...") {

                list plusList = ["Dolly Name...","Gender:" + dollGender];

                lmSendConfig("backMenu",(backMenu = "Options..."));
                if (cdIsController(id)) plusList += [ "Max Time...", "Wind Time..." ];
                cdDialogListen();
                llDialog(id, "Here you can set various general key settings.", dialogSort(llListSort(plusList, 1, 1) + "Back..."), dialogChannel);
            }
            else if (llGetSubString(choice,0,6) == "Gender:") {
                string s = llGetSubString(choice,7,-1);
                debugSay(4,"DEBUG-AUX","Gender selected: " + s);

                // Whatever the current element is - set gender
                // to the next in a circular loop

                     if (s == "male")   setGender("female");
                else if (s == "female") setGender("male");

                llOwnerSay("Gender is now set to " + dollGender);
                lmMenuReply("Key...", llGetDisplayName(id), id);
            }

            // Textbox generating menus
            else if (choice == "Dolly Name...") {
                if (choice == "Dolly Name...") {
                    textboxType = DOLL_NAME_TEXTBOX;
                    llTextBox(id, "Here you can change your dolly name from " + dollDisplayName + " to a name of your choice.", textboxChannel);
                }

                if (textboxHandle) llListenRemove(textboxHandle);
                textboxHandle = cdListenUser(textboxChannel, id);
                listenTime = llGetTime() + 60.0;
                llSetTimerEvent(60.0);
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
                integer n = llGetListLength(cdList2ListStrided(controllers, 0, -1, 2));

                while (n--) {
                    targetKey = (key)controllers[(n << 1]);

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
                memReportID = id;
                memReport("Aux",1.0);
            }
            else if (code == MEM_REPLY) {
                memReporting = 1;
                llSetTimerEvent(5.0); // when timer goes off, we assume completion
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

            else if (code == SIM_RATING_CHG) {
                simRating = (string)split[0];
            }
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {

        name = llGetDisplayName(id);

        if (channel == textboxChannel) {
            llListenRemove(textboxHandle);
            textboxHandle = 0;
            listenTime = 0.0;
            string origChoice = choice;

            // Text box input - 1 types
            //   1: Dolly Name

            // This test is not really needed - but in the interest of
            // expansion, this allows more text box types to be created later
            if (textboxType == DOLL_NAME_TEXTBOX) {
                lmSendConfig("dollDisplayName", choice);
                lmMenuReply("Key...", name, id);
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

                if (script != "Aux" && (llListFindList(memList,(list)script) == NOT_FOUND)) {
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
