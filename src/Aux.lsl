//========================================
// Aux.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

#define DEBUG_HANDLER 1
#include "include/GlobalDefines.lsl"
#include "include/Json.lsl"

#define NO_FILTER ""
#define cdListenUser(a,b) llListen(a, NO_FILTER,         b, NO_FILTER)
#define cdResetKey() llResetOtherScript("Start")
#define UNSET -1

#define HIPPO_UPDATE -2948813

key lmRequest;
list memWait;
float rezTime;
float timerEvent;
float listenTime;
float memTime;
string memData;
string minsLeft;
//string windRate;
integer windMins;
string dollDisplayName;
string curGemColour;
integer maxMins;
integer ncLine;
integer memCollecting;
integer memRequested;
integer rezzed;
integer primGlow = 1;
integer primLight = 1;
integer textboxChannel;
integer textboxHandle;
integer textboxType;

integer i;
string msg;

// Only place gender is currently set is in the preferences
setGender(string gender) {

    if (gender == "male") {
        lmSendConfig("dollGender",     (dollGender     = "Male"));
        lmSendConfig("pronounHerDoll", (pronounHerDoll = "His"));
        lmSendConfig("pronounSheDoll", (pronounSheDoll = "He"));
    }
    else {
        lmSendConfig("dollGender", (dollGender = "Female"));
        lmSendConfig("pronounHerDoll", (pronounHerDoll = "Her"));
        lmSendConfig("pronounSheDoll", (pronounSheDoll = "She"));
    }
}

// This is an ingenious function:
//
// If the id belongs to Dolly, then llOwnerSay
// If the id belongs to an avi nearby, then llRegionSayTo
// If neither of the above, then llInstantMessage
//
sendMsg(key id, string msg) {
    if (id) {
        if cdIsDoll(id) llOwnerSay(msg);
        else if (llGetAgentSize(id)) llRegionSayTo(id, 0, msg);
        else llInstantMessage(id, msg);
    }
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
        //lmSendXonfig("debugLevel", (string)debugLevel);
        rezTime = llGetTime();
        configured = 0;
        rezzed = 1;
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
            else if (name == "keyLimit")                      maxMins = llRound((float)value / 60.0);
            else if (name == "backMenu")                     backMenu = value;
            else if (name == "quiet")                           quiet = (integer)value;
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
            else if (name == "windMins")                     windMins = (integer)value;
            else if (name == "wearLock")                     wearLock = (integer)value;
            else if (name == "primLight")                   primLight = (integer)value;
            else if (name == "primGlow")                     primGlow = (integer)value;
            else if (name == "isVisible")                     visible = (integer)value;
            else if (name == "gemColour")                curGemColour = value;
            else if (name == "blacklist") {
                if (split == [""]) blacklist = [];
                else blacklist = split;
            }
            else if (name == "dollType") {
                if (configured && (keyAnimation != "") && (keyAnimation != ANIMATION_COLLAPSED) && (poserID != dollID)) {
                    if (value == "Display" || hardcore)
                        llOwnerSay("You feel yourself transform and know you will soon be free of your pose when the timer ends.");
                    else if (dollType == "Display")
                        llOwnerSay("As you feel yourself become a display doll you feel a sense of helplessness knowing you will remain posed until released.");

                    dollType = value;
                    lmInternalCommand("setPose", keyAnimation, NULL_KEY);
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

                 if (name == "dollGender")
                     lmSendConfig("dollGender",(dollGender = value));
            else if (name == "pronounHerDoll")
                     lmSendConfig("pronounHerDoll",(pronounHerDoll = value));
            else if (name == "pronounSheDoll")
                     lmSendConfig("pronounSheDoll",(pronounSheDoll = value));
        }
        else if (code == INTERNAL_CMD) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            // Note that this section will be empty except in Adult Mode...
#ifdef ADULT_MODE
            if (cmd == "strip") {
                string part = llList2String(split, 0);

                if (id != dollID) {

                    // if Dolly is stripped by someone else, Dolly cannot
                    // dress for a time: wearLock is activated

                    //lmInternalCommand("wearLock", (string)(wearLock = 1), NULL_KEY);
                    //lmSendConfig("wearLock", (string)(wearLock = 1));
                    lmSetConfig("wearLock", "1");

                    if (!quiet) llSay(0, "The dolly " + dollName + " has " + llToLower(pronounHerDoll) + " " + llToLower(part) + " stripped off " + llToLower(pronounHerDoll) + " and may not redress for " + (string)llRound(WEAR_LOCK_TIME / 60.0) + " minutes.");
                    else llOwnerSay("You have had your " + llToLower(part) + " stripped off you and may not redress for " + (string)llRound(WEAR_LOCK_TIME / 60.0) + " minutes");
                }
                else llOwnerSay("You have stripped off your own " + llToLower(part) + ".");
            }
#endif
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
                if (llGetInventoryType(OBJECT_KEY) == INVENTORY_OBJECT)
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
                lmSendToAgent("Here is your link to the Community Doll Key development: " + WEB_DEV, id);
            else if (choice == "Visit Website")
                lmSendToAgent("Here is your link to the Community Dolls blog: " + WEB_BLOG, id);
            else if (choice == "Visit Blog")
                lmSendToAgent("Here is your link to the Community Dolls website: " + WEB_DOMAIN, id);
            else if (choice == "Join Group")
                lmSendToAgent("Here is your link to the Community Dolls group profile: " + WEB_GROUP, id);

            else if (choice == "Access...") {
                msg = "Key Access Menu.\n\n" +
                             "These are powerful options allowing you to give someone total control of your key or block someone from touch or even winding your key. Good dollies should read their key help before adjusting these options. You have " + (string)cdControllerCount() + " and " + (string)llGetListLength(blacklist) + " people on the blacklist.
                             
Blacklist - Block a person from using the key entirely (even winding!)
Controller - Take care choosing your controllers; they have great control over Dolly and cannot be removed by you";

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
                if ((cdIsController(id)) && (cdControllerCount() > 0)) plusList = [ "⊖ Controller" ];

                if (cdIsDoll(id)) {
                    plusList += [ "⊕ Blacklist", "List Blacklist" ];

                    if (llGetListLength(blacklist)) plusList += [ "⊖ Blacklist" ];
#ifdef DEVELOPER_MODE
                    debugSay(5,"DEBUG-AUX","Blacklist length: " + (string)llGetListLength(blacklist) + " >> " + llDumpList2String(blacklist,","));
#endif

                    plusList += [ "⊕ Controller" ];
                }

                plusList +=  "List Controller";

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
                    }
                    lmSendConfig("backMenu",(backMenu = "Options..."));

                    plusList += cdGetButton("Flying", id, canFly, 1);
                    plusList += cdGetButton("Sitting", id, canSit, 1);
                    plusList += cdGetButton("Standing", id, canStand, 1);
                    plusList += cdGetButton("Self Dress", id, canDressSelf, 1);
                    plusList += cdGetButton("Self TP", id, canSelfTP, 1);
                    plusList += cdGetButton("Force TP", id, autoTP, 1);
                    plusList += "Back...";
                }
                else {
                    string p = llToLower(pronounHerDoll);
                    string s = llToLower(pronounSheDoll);

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

                plusList += cdGetButton("Type Text", id, hoverTextOn, 0);
                plusList += cdGetButton("Warnings", id, doWarnings, 0);
                plusList += cdGetButton("Phrases", id, showPhrases, 0);

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
                llDialog(id, "Here you can set various general key settings.", dialogSort(llListSort(plusList, 1, 1) + cdGetButton("Key Glow", id, primGlow, 0) + cdGetButton("Gem Light", id, primLight, 0) + "Back..."), dialogChannel);
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

                lmInternalCommand("setGemColour", choice, id);
                lmMenuReply("Gem Colour...", llGetDisplayName(id), id);
            }

            // Textbox generating menus
            else if (choice == "Custom..." || choice == "Dolly Name..." ) {
                if (choice == "Custom...") {
                    textboxType = 1;
                    llTextBox(id, "Here you can input a custom colour value\n\nCurrent colour: " + curGemColour + "\n\nEnter vector eg <0.900, 0.500, 0.000>\nOr Hex eg #A4B355\nOr RGB eg 240, 120, 10", textboxChannel);
                }
                else if (choice == "Dolly Name...") {
                    textboxType = 2;
                    llTextBox(id, "Here you can change your dolly name from " + dollDisplayName + " to a name of your choice.", textboxChannel);
                }

                if (textboxHandle) llListenRemove(textboxHandle);
                textboxHandle = cdListenUser(textboxChannel, id);
                listenTime = llGetTime() + 60.0;
                llSetTimerEvent(60.0);
            }
        }

        // 11: lmSendToAgent
        // 12: lmSendToAgentPlusDoll
        // 15: lmSendToController
        //
        else if (code < 200) {
            if ((code == 11) || (code == 12)) {
                msg = llList2String(split, 0);

                sendMsg(id, msg);

                if (code == 12)
                    // Don't send to Dolly if we just DID send to Dolly
                    if (!cdIsDoll(id)) sendMsg(dollID, msg);
            }
            else if (code == 15) {
                msg = llList2String(split, 0);
                i = 0;
                string targetName;
                key targetKey;
                integer n = llGetListLength(cdList2ListStrided(controllers, 0, -1, 2));

                while (n--) {
                    targetName = llList2String(controllers, (n << 1) + 1);
                    targetKey = llList2Key(controllers, n << 1);

                    sendMsg(targetKey, msg);
                }
            }
            else if (code == 102) {
                configured = 1;
                scaleMem();
            }
            else if (code == 110) {
                if (script != "Start") return;
                llSleep(5.0);
                lmMemReport(0.5, 0);
            }
            else if ((code == 135) || (code == 136)) {

                // This is the bulk of 136/135 message processing
                //
                if ((code == 135) && (!memCollecting)) {
                    i = llGetInventoryNumber(INVENTORY_SCRIPT);
                    string script;

                    while (i--) {
                        script = llGetInventoryName(INVENTORY_SCRIPT, i);

                        if (script != "Aux") {
                            if (llGetScriptState(script)) memWait += script;
                        }
                    }
                    memCollecting = 1;
                    memData = "";
                    memTime = llGetTime() + 5.0;
                    llSetTimerEvent(4.0);
#ifdef DEVELOPER_MODE
                    memRequested = 1;
#else
                    memRequested = llList2Integer(split, 1);
#endif
                }
                else if ((code == 136) || ((memTime < llGetTime()) && (code == 135))) {
                    string json = llList2String(split, 0);

                    if ((json != "") && (json != JSON_INVALID)) {

                        memData = cdSetValue(memData, [script], json);
                        i = llListFindList(memWait, [script]);

                        if ((i != -1) || ((memTime < llGetTime()) && (code == 135))) {
                            memWait = llDeleteSubList(memWait, i, i);

                            if (!llGetListLength(memWait) || ((memTime < llGetTime()) && (code == 135))) {
                                llSetTimerEvent(0.0);

                                float memory_limit = (float)llGetMemoryLimit();
                                float free_memory = (float)llGetFreeMemory();
                                float used_memory = (float)llGetUsedMemory();
                                float available_memory = free_memory + (65536 - memory_limit);

                                if (((used_memory + free_memory) > (memory_limit * 1.05)) && (memory_limit <= 16384)) { // LSL2 compiled script
                                   memory_limit = 16384;
                                   used_memory = 16384 - free_memory;
                                   available_memory = free_memory;
                                }

                                memData = cdSetValue(memData,["Aux"],llList2Json(JSON_ARRAY, [used_memory, memory_limit, free_memory, available_memory]));

                                float totUsed; float totLimit; float totFree; float totAvail; integer warnFlag;
                                i = 0; string scriptName; list statList;
                                string output = "Script Memory Status:";
                                string type;

                                integer numScripts;
                                numScripts = llGetInventoryNumber(INVENTORY_SCRIPT);

                                i = numScripts;
                                while (i--) {

                                    scriptName = llGetInventoryName(INVENTORY_SCRIPT, i);

                                    if (( type = cdGetElementType(memData, ([scriptName]))) != JSON_INVALID) {

                                        totUsed  += used_memory      = (float)cdGetValue(memData, ([scriptName,0]));
                                        totLimit += memory_limit     = (float)cdGetValue(memData, ([scriptName,1]));
                                        totFree  += free_memory      = (float)cdGetValue(memData, ([scriptName,2]));
                                        totAvail += available_memory = (float)cdGetValue(memData, ([scriptName,3]));

#define WARN_MEM 6144
                                        if (memRequested || (available_memory < WARN_MEM)) {
                                            if (!memRequested && !warnFlag) {
                                                output += "\nOnly showing individual scripts with less than " + (string)llRound(WARN_MEM / 1024.0) + "kB available.";
                                                warnFlag = 1;
                                            }
                                            output += "\n" + scriptName + ":\t" + formatFloat(used_memory / 1024.0, 2) + "/" + (string)llRound(memory_limit / 1024.0) + "kB (" +
                                                      formatFloat(free_memory / 1024.0, 2) + "kB free, " + formatFloat(available_memory / 1024.0, 2) + "kB available)";
                                        }
                                    }
                                    else {
                                        if (memRequested) {
                                            output += "\n" + scriptName + ":\tNo report available";

                                            if (!llGetScriptState(scriptName)) {
                                                output += " (seems to have stopped)";
                                            }
                                        }
                                    }
                                }

                                output += "\nTotal memory usage: " + formatFloat(totUsed / 1024.0, 2) + "kB out of a total possible of " + (string)llRound(totLimit / 1024.0) + "kB (" +
                                           formatFloat(totUsed * 100.0 / totLimit, 2) + "%) - " + (string)numScripts  + " scripts total";

                                if (warnFlag) output += "\nYou have some scripts with very low memory, you may begin to suffer script crashes if memory runs out.  ";
                                                        "Please see the manual for tips how to keep memory usage low.";

                                llOwnerSay(output);
                                memCollecting = 0;
                                memRequested = 0;
                                memTime = 0.0;
                            }
                        }
                    }
                }
            }

            else if (code == 142) {
                cdConfigureReport();
            }

            else if (code == 150) {
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
        // Deny access to the key when the command was recieved from blacklisted avatar
        if (llListFindList(blacklist, [ (string)id ]) != NOT_FOUND) {
            //lmSendToAgent("You are not permitted to access this key.", id);
            return;
        }

        name = llGetDisplayName(id);

        //llOwnerSay((string)channel + "=" + (string)textboxChannel + "? " + (string)textboxType + " " + choice);

        if (channel == textboxChannel) {
            llListenRemove(textboxHandle);
            textboxHandle = 0;
            listenTime = 0.0;

            // Text box input - 4 types
            //   1: Gem Color
            //   2: Dolly Name

            // Type 1 = Custom Gem Color
            if (textboxType == 1) {
                string first = llGetSubString(choice, 0, 0);

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

                lmInternalCommand("setGemColour", choice, id);
            }

            // Type 2 = New Dolly Name
            else if (textboxType == 2) lmSendConfig("dollDisplayName", choice);

            // After processing the choice, what menu do we give back?
            //
            // For all types except #1 (Gem Color) give back the "Key..."
            // Menu...
            //
            if (textboxType == 1) lmMenuReply("Gem Colour...", name, id);
            else lmMenuReply("Key...", name, id);
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
        if (memCollecting) lmMemReport(0.0, memRequested);
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
