//========================================
// Aux.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

#define DEBUG_HANDLER 1
#include "include/GlobalDefines.lsl"
// #include "include/Json.lsl"

#define WARN_MEM 6144
#define NO_FILTER ""
#define cdListenUser(a,b) llListen(a, NO_FILTER,         b, NO_FILTER)
#define cdResetKey() llResetOtherScript("Start")
#define UNSET -1

#define GEM_COLOR_TEXTBOX 1
#define DOLL_NAME_TEXTBOX 2

#define HIPPO_UPDATE -2948813

key memReportID;
key lmRequest;
list memList;
float timerEvent;
float listenTime;
float memTime;
string minsLeft;
string curGemColour;
string memOutput = "Script Memory Status:";
integer maxMins;
integer ncLine;
integer memReporting;
#ifdef GEMGLOW_OPT
integer gemGlow = 1;
#endif
integer gemLight = 1;
integer textboxChannel;
integer textboxHandle;
integer textboxType;

integer i;
string msg;

// Only place gender is currently set is in the preferences
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
        //lmSendXonfig("debugLevel", (string)debugLevel);
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);

        cdInitializeSeq();
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        configured = 0;
    }

//  //----------------------------------------
//  // CHANGED
//  //----------------------------------------
//  changed(integer change) {
//      if (change & CHANGED_TELEPORT) {
//          ;
//      }
//  }

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

        scaleMem();

        if (code == CONFIG) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);

            split = llDeleteSubList(split, 0, 0);

                 if (name == "controllers") {
                    if (split == [""]) controllers = [];
                    else controllers = split;
            }
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                 debugLevel = (integer)value;
#endif
            else if (name == "keyAnimation")             keyAnimation = value;
            else if (name == "poserID")                       poserID = (key)value;
            //else if (name == "normalGemColour")           normalGemColour = (vector)value;
            else if (name == "keyLimit")                      maxMins = llRound((float)value / 60.0);
            else if (name == "winderRechargeTime") winderRechargeTime = (integer)value;
            else if (name == "backMenu")                     backMenu = value;
            else if (name == "quiet")                           quiet = (integer)value;
#ifdef HOMING_BEACON
            else if (name == "homingBeacon")             homingBeacon = (integer)value;
#endif
            else if (name == "collapseTime")             collapseTime = (float)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
            else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "showPhrases")               showPhrases = (integer)value;
            else if (name == "canAFK")                         canAFK = (integer)value;
            else if (name == "afk")                               afk = (integer)value;
            else if (name == "allowCarry")                 allowCarry = (integer)value;
            else if (name == "allowDress")                 allowDress = (integer)value;
            else if (name == "allowPose")                   allowPose = (integer)value;
            else if (name == "canDressSelf")             canDressSelf = (integer)value;
            else if (name == "canFly")                         canFly = (integer)value;
            else if (name == "canSit")                         canSit = (integer)value;
            else if (name == "canStand")                     canStand = (integer)value;
            else if (name == "allowRepeatWind")       allowRepeatWind = (integer)value;
            else if (name == "dollDisplayName")       dollDisplayName = value;
            else if (name == "doWarnings")                 doWarnings = (integer)value;
            else if (name == "hardcore")                     hardcore = (integer)value;
            else if (name == "poseSilence")               poseSilence = (integer)value;
            else if (name == "detachable")                 detachable = (integer)value;
            else if (name == "canSelfTP")                   canSelfTP = (integer)value;
#ifdef ADULT_MODE
            else if (name == "allowStrip")             allowStrip = (integer)value;
#endif
            else if (name == "wearLock")                     wearLock = (integer)value;
            else if (name == "gemLight")                   gemLight = (integer)value;
#ifdef GEMGLOW_OPT
            else if (name == "gemGlow")                     gemGlow = (integer)value;
#endif
            else if (name == "blacklist") {
                if (split == [""]) blacklist = [];
                else blacklist = split;
            }
            else if (name == "dollType") {
                dollType = value;

                // if:   * Key is configured
                //       * Dolly is posed
                //       * Dolly is not collapsed
                //       * Poser is not Dolly
                //
                // This only occurs when Dolly is posed when transformed by someone else; if that happens,
                // put out a message, and reissue the pose
                //
                // This is necessary because of the Display Doll: if a posed Dolly is transformed, then
                // the pose timer needs to be reset and eliminated
                //
                if (!hardcore) { // if hardcore, there IS no timer
                    if (keyAnimation != "") {
                        if (keyAnimation != ANIMATION_COLLAPSED) {
                            if (poserID != dollID) {
                                if (configured) {

                                    if (dollType == "Display")
                                        llOwnerSay("As you feel yourself become a " + dollType + " Doll you feel a sense of helplessness knowing you will remain posed until released.");
                                    else
                                        llOwnerSay("You feel yourself transform into a " + dollType + " Doll and know you will soon be free of your pose when the timer ends.");

                                    lmInternalCommand("setPose", keyAnimation, NULL_KEY);
                                }
                            }
                        }
                    }
                }
            }
            else if (name == "dialogChannel") {
                dialogChannel = (integer)value;
                textboxChannel = dialogChannel - 1111;
            }
        }
        else if (code == SET_CONFIG) {
                string name = llList2String(split, 0);
                string value = llList2String(split, 1);

                split = llDeleteSubList(split, 0, 0);

                if (name == "dollGender") setGender(value);
        }
        else if (code == INTERNAL_CMD) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "setGemColour") {
                // This command does NOT set normalGemColour - which is as it
                // should be. This allows us to set the gemColour without
                // losing the colour we "normally" use.
                vector newColour = (vector)llList2String(split, 0);

                //if (newColour == gemColour) return;
                if (newColour == <0.0,0.0,0.0>) {
                    llSay(DEBUG_CHANNEL,"Script " + script + " tried to set gem color to Black!");
                    return;
                }
                debugSay(4,"DEBUG-AUX","Setting gem color to " + (string)gemColour);

                integer j; integer shaded; list params; list colourParams;
                integer n; integer m;
                integer index;
                integer index2;
                vector shade;

                n = llGetNumberOfPrims();
                i = n;
                while (i--) {
                    index = n - i - 1;

                    if (llGetSubString(llGetLinkName(index), 0, 4) == "Heart") {
                        params += [ PRIM_LINK_TARGET, index ];

                        if (!shaded) {
                            m = llGetLinkNumberOfSides(index);
                            j = m;
                            while (j--) {
                                // Add noise to color
                                shade = <llFrand(0.2) - 0.1 + newColour.x,
                                         llFrand(0.2) - 0.1 + newColour.y,
                                         llFrand(0.2) - 0.1 + newColour.z>  * (0.9 + llFrand(0.2));
                                //                                            (1.0 + (llFrand(0.2) - 0.1))

                                // make sure we're in bounds
                                if (shade.x < 0.0) shade.x = 0.0;
                                if (shade.y < 0.0) shade.y = 0.0;
                                if (shade.z < 0.0) shade.z = 0.0;

                                if (shade.x > 1.0) shade.x = 1.0;
                                if (shade.y > 1.0) shade.y = 1.0;
                                if (shade.z > 1.0) shade.z = 1.0;

                                colourParams += [ PRIM_COLOR, m - j - 1, shade, 1.0 ];
                            }
                            shaded = TRUE;
                        }
                        params += colourParams;
                    }
                }

                // params was just built up: so now use it to set colors
                llSetLinkPrimitiveParamsFast(0, params);
                lmSendConfig("gemColour", (string)(gemColour = newColour));
            }
            else if (cmd == "setNormalGemColour") {
                string choice = llList2String(split,0);
                lmInternalCommand("setGemColour", choice, id);

                normalGemColour = (vector)choice;
                //lmSendConfig("normalGemColour",choice);
            }
            else if (cmd == "resetGemColour") {
                lmInternalCommand("setGemColour", (string)normalGemColour, id);
            }
#ifdef ADULT_MODE
            else if (cmd == "strip") {
                // llToLower() may be superfluous here
                string part = llToLower(llList2String(split, 0));

                if (id != dollID) {

                    // if Dolly is stripped by someone else, Dolly cannot
                    // dress for a time: wearLock is activated

                    //lmInternalCommand("wearLock", (string)(wearLock = 1), NULL_KEY);
                    //lmSendConfig("wearLock", (string)(wearLock = 1));
                    lmSetConfig("wearLock", "1");

                    if (!quiet) llSay(0, "The dolly " + dollName + " has stripped and may not redress for " + (string)llRound(WEAR_LOCK_TIMEOUT / 60.0) + " minutes.");
                    else llOwnerSay("You have been stripped and may not redress for " + (string)llRound(WEAR_LOCK_TIMEOUT / 60.0) + " minutes.");
                }
                else llOwnerSay("You have stripped off your clothes.");
                lmInternalCommand("stripAll", "", id);
            }
#endif
            else if (cmd == "collapsedMenu") {
                // this is only called for Dolly - so...
                string timeLeft = llList2String(split, 0);
                list menu = [ "Ok" ];

                debugSay(2,"DEBUG-AUX","Building collapsedMenu...");
                // is it possible to be collapsed but collapseTime be equal to 0.0?
                if (collapsed) {
                    float timeCollapsed;

                    msg = "You need winding. ";
                    timeCollapsed = llGetUnixTime() - collapseTime;

#ifdef DEVELOPER_MODE
                    if (timeCollapsed < 0)
                        llSay(DEBUG_CHANNEL,"Time collapsed is marked as negative! (" + (string)timeCollapsed + "): " + (string)llGetUnixTime() + " - " + (string)collapseTime);
                    else
                        llSay(DEBUG_CHANNEL,"Time collapsed is marked as positive... (" + (string)timeCollapsed + "): " + (string)llGetUnixTime() + " - " + (string)collapseTime);
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
        }
        else if (code == RLV_RESET) {
            RLVok = llList2Integer(split, 0);
        }
        else if (code == MENU_SELECTION) {
            string choice = llList2String(split, 0);
            string avatar = llList2String(split, 1);

            if (choice == "Help...") {
                msg = "Here you can find various options to get help with your key and to connect with the community.";
                list plusList = [ "Join Group", "Visit Dollhouse", "Visit Website", "Visit Blog", "Visit Development", "Help Notecard" ];

                // Note - to do this Key handout properly, we'd need an infinite Key:
                // a Key which contains a Key which contains a Key which contains a Key...
                // Like a never-ending matrushka doll.
                //
                if (!cdIsDoll(id))
                    if ((llGetInventoryType(OBJECT_KEY) == INVENTORY_OBJECT))
                        plusList += [ "Get Key" ];

#ifdef DEVELOPER_MODE
                // Remember, a doll cannot be her own controller, unless there is no other
                if (cdIsController(id)) plusList += "Reset Key";
#endif

                cdDialogListen();
                llDialog(id, msg, dialogSort(plusList + MAIN), dialogChannel);
            }
            else if (choice == "Help Notecard")
                llGiveInventory(id,NOTECARD_HELP);
            else if (choice == "Get Key") {
                llGiveInventory(id,OBJECT_KEY);
            }
            else if (choice == "Visit Dollhouse") {
                // If is Dolly, whisk Dolly away to Location of Landmark
                // If is someone else, give Landmark to them
                if (cdIsDoll(id))
                    //llMessageLinked(LINK_THIS, 305, "Aux|TP|" + LANDMARK_CDHOME, id);
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
#ifdef DEVELOPER_MODE
                    debugSay(5,"DEBUG-AUX","Blacklist length: " + (string)llGetListLength(blacklist) + " >> " + llDumpList2String(blacklist,","));
#endif

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
                msg = "See " + WEB_DOMAIN + "keychoices.htm for explanation. (" + OPTION_DATE + " version)";
                list plusList;

                if (RLVok) {

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
                    if (RLVok) {
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
                msg = "See " + WEB_DOMAIN + "keychoices.htm for explanation. (" + OPTION_DATE + " version)";
                list plusList = [];

                plusList += cdGetButton("Quiet Key", id, quiet, 0);
                plusList += cdGetButton("Type Text", id, hovertextOn, 0);
                plusList += cdGetButton("Warnings", id, doWarnings, 0);
                plusList += cdGetButton("Phrases", id, showPhrases, 0);
#ifdef HOMING_BEACON
                plusList += cdGetButton("Homing Beacon", id, homingBeacon, 0);
#endif

                // One-way options
                if (cdIsController(id)) {
                    if (!afk)
                        plusList = llListInsertList(plusList, cdGetButton("Allow AFK", id, canAFK, 1), 0);

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

                list plusList = ["Dolly Name...","Gem Colour...","Gender:" + dollGender];

                lmSendConfig("backMenu",(backMenu = "Options..."));
                if (cdIsController(id)) plusList += [ "Max Time...", "Wind Time..." ];
                cdDialogListen();
#ifdef GEMGLOW_OPT
                llDialog(id, "Here you can set various general key settings.", dialogSort(llListSort(plusList, 1, 1) + cdGetButton("Key Glow", id, gemGlow, 0) + cdGetButton("Gem Light", id, gemLight, 0) + "Back..."), dialogChannel);
#else
                llDialog(id, "Here you can set various general key settings.", dialogSort(llListSort(plusList, 1, 1) + cdGetButton("Gem Light", id, gemLight, 0) + "Back..."), dialogChannel);
#endif
            }
            else if (llGetSubString(choice,0,6) == "Gender:") {
                string s = llGetSubString(choice,7,-1);

                // Whatever the current element is - set gender
                // to the next in a circular loop

                     if (s == "Male")   setGender("female");
                else if (s == "Female") setGender("male");

                llOwnerSay("Gender is now set to " + dollGender);
                lmMenuReply("Key...", llGetDisplayName(id), id);
            }
            else if (choice == "Gem Colour...") {
                msg = "Here you can choose your own gem colour.";

                cdDialogListen();
                llDialog(id, msg, dialogSort(COLOR_NAMES + "Key..."), dialogChannel);
            }
            else if (llListFindList(COLOR_NAMES, [ choice ]) != NOT_FOUND) {
                integer index = llListFindList(COLOR_NAMES, [ choice ]);
                string choice = (string)llList2Vector(COLOR_VALUE, index);

                lmInternalCommand("setNormalGemColour", choice, id);
                lmMenuReply("Gem Colour...", llGetDisplayName(id), id);
            }

            // Textbox generating menus
            else if (choice == "Custom..." || choice == "Dolly Name..." ) {
                if (choice == "Custom...") {
                    textboxType = GEM_COLOR_TEXTBOX;
                    llTextBox(id, "Here you can input a custom colour value\n\nCurrent colour: " + (string)gemColour + "\n\nEnter vector eg <0.900, 0.500, 0.000>\nOr Hex eg #A4B355\nOr RGB eg 240, 120, 10", textboxChannel);
                }
                else if (choice == "Dolly Name...") {
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
                msg = llList2String(split, 0);
                string targetName;
                key targetKey;
                integer n = llGetListLength(cdList2ListStrided(controllers, 0, -1, 2));

                while (n--) {
                    i = n << 1; // Double the index
                    targetName = llList2String(controllers, i + 1);
                    targetKey = llList2Key(controllers, i);

                    lmInternalCommand("instantMessage", msg, targetKey);
                }
            }
            else if (code == 102) {
                configured = 1;
                scaleMem();
            }
#ifdef DEVELOPER_MODE
            else if (code == 110) {
                llSleep(5.0);
                lmMemReport(0.5, dollID);
            }
#endif
            else if (code == MEM_REPORT) {
                float delay  = llList2Float(split, 0);
                memReportID = id;
                memReport("Aux",1.0);
            }

            else if (code == MEM_REPLY) {
                memReporting = 1;
                llSetTimerEvent(5.0); // when timer goes off, we assume completion
                float usedMemory  = llList2Float(split, 0);
                float memoryLimit = llList2Float(split, 1);
                float freeMemory  = llList2Float(split, 2);
                float availMemory = llList2Float(split, 3);

#ifdef DEVELOPER_MODE
                // In Developer Keys we want to see the works: all the details
                memList += "\n" + script + ":\t" +
                    formatFloat(usedMemory / 1024.0, 2) + "/" + (string)llRound(memoryLimit / 1024.0) + "kB (" +
                    formatFloat(freeMemory / 1024.0, 2) + "kB free, " + formatFloat(availMemory / 1024.0, 2) + "kB available)";
#else
                // The user only cares about free memory when things are going south
                if (availMemory < WARN_MEM) {
                    memList += "\n" + script + ":\t" +
                        formatFloat(availMemory / 1024.0, 2) + "kB available";
                }
#endif
            }
            else if (code == CONFIG_REPORT) {
                cdConfigureReport();
            }

            else if (code == SIM_RATING_CHG) {
                simRating = llList2String(split, 0);
            }
            // HippoUPDATE reply
            //else if (code == HIPPO_UPDATE) {
            //    if (data == "VERSION") llOwnerSay("Your key is already up to date");
            //}
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

            // Text box input - 4 types
            //   1: Gem Color
            //   2: Dolly Name

            // Type 1 = Custom Gem Color
            if (textboxType == GEM_COLOR_TEXTBOX) {
                string first = llGetSubString(choice, 0, 0);

                // Note that all of these go through a vector cast at least once:
                // so a bad entry will shake out as a ZERO_VECTOR or some unknown
                // vector - which changes the gem color oddly.

                if (first == "<") {                                             // User entry is vector
                    choice = (string)((vector)choice);
                }
                else {
                    vector tmp;
                    if (first == "#") tmp =
                        (vector)("<0x" + llGetSubString(choice, 1, 2) +
                                 ",0x" + llGetSubString(choice, 3, 4) +
                                 ",0x" + llGetSubString(choice, 5, 6) + ">");   // User entry is in hex
                    else tmp = (vector)("<" + choice + ">");                    // User entry is RGB
                    tmp /= 256.0;
                    choice = (string)tmp;
                }

                if (choice) {
                    lmInternalCommand("setNormalGemColour", choice, id);
                    lmMenuReply("Gem Colour...", name, id);
                }
#ifdef DEVELOPER_MODE
                else {
                    llSay(DEBUG_CHANNEL,"Bad color input! (" + origChoice + ")");
                }
#endif
            }

            // Type 2 = New Dolly Name
            else if (textboxType == DOLL_NAME_TEXTBOX) {
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
