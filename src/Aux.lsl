//========================================
// Aux.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 25 February 2014

#define DEBUG_HANDLER 1
#include "include/GlobalDefines.lsl"
#include "include/Json.lsl"

#define APPEARANCE_NC "DataAppearance"

key ncRequest;
key carrierID = NULL_KEY;
float rezTime;
float memTime;
string carrierName;
string pronounHerDoll = "Her";
string pronounSheDoll = "She";
integer configured;
integer initState = 104;
integer ncLine;
integer visible;
integer memCollecting;
integer quiet;
integer wearLock;
integer rezzed;
list MistressList;
list BuiltinControllers = BUILTIN_CONTROLLERS;
list glowSettings;
string memData;

sendMsg(key target, string msg) {
    if (target) {
        if (llGetSubString(msg, 0, 0) == "%" && llGetSubString(msg, -1, -1) == "%") {
            msg = findString(msg);
        }

        if (target == dollID) llOwnerSay(msg);
        else if (llGetAgentSize(target)) llRegionSayTo(target, 0, msg);
        else llInstantMessage(target, msg);
    }
}

string findString(string msg) {
    if (msg == "%TEXT_HELP%") return "Commands:\n\n
    detach ......... detach key if possible\n
    stat ........... concise current status\n
    stats .......... selected statistics and settings\n
    xstats ......... extended statistics and settings\n
    poses .......... list all poses\n
    help ........... this list of commands\n
    wind ........... trigger emergency autowind\n
    demo ........... toggle demo mode\n
    channel ........ change channel\n\n";
    else return "";
}

doVisibility(integer setVisible) {
    if (llGetInventoryType(APPEARANCE_NC) == INVENTORY_NOTECARD) {
        if (setVisible != -1) visible = setVisible;

        if (visible == 0) {
            llSetLinkPrimitiveParamsFast(LINK_SET, [ PRIM_GLOW, 0, 0.0, PRIM_GLOW, 1, 0.0, PRIM_GLOW, 2, 0.0, PRIM_GLOW, 3, 0.0, PRIM_GLOW, 4, 0.0, PRIM_GLOW, 5, 0.0, PRIM_GLOW, 6, 0.0, PRIM_GLOW, 7, 0.0 ]);
        }
        else {
            llSetLinkPrimitiveParamsFast(1, glowSettings);
        }
    }
}

default {
    state_entry() {
        //lmSendXonfig("debugLevel", (string)debugLevel);
    }

    on_rez(integer start) {
        //lmSendXonfig("debugLevel", (string)debugLevel);
        rezTime = llGetTime();
        configured = 0;
        rezzed = 1;
    }

    link_message(integer source, integer code, string data, key id) {
        list split = llParseString2List(data, ["|"], []);
        string script = llList2String(split, 0);

        if (code != 700) linkDebug(script, code, data, id);

        if (code == 11) {
            string msg = llList2String(split, 1);
            debugSay(7, "DEBUG", "Send message to: " + (string)id + "\n" + msg);
            sendMsg(id, msg);
        }
        else if (code == 15) {
            string msg = llList2String(split, 1);
            integer i;
            for (i = 0; i < llGetListLength(llList2ListStrided(MistressList, 0, -1, 2)); i++) {
                string targetName = llList2String(MistressList, i * 2 + 1);
                key targetKey = llList2Key(MistressList, i * 2);
                debugSay(7, "DEBUG", "MistressMsg To: " + targetName + " (" + (string)targetKey + ")\n" + msg);
                sendMsg(targetKey, msg);
            }
        }
        else if (code == 102) configured = 1;
        else if ((code == 104) || (code == 105)) {
            debugSay(7, "DEBUG-STARTUP", "InitState = " + (string)code + " from '" + script + "' my state: " + (string)initState);

            if (initState == code) lmInitState(initState++);
        }
        else if (code == 110) {
            if (script != "Start") return;

            initState = 105;

            if (!rezzed && (llGetInventoryType(APPEARANCE_NC) == INVENTORY_NOTECARD)) {
                ncRequest = llGetNotecardLine(APPEARANCE_NC, ncLine++);
            }

            memCollecting = 1;
            memData = "";

            lmMemReport(0.0);

            llSetTimerEvent(5.0);
        }
        else if (code == 135) {
            if (script == SCRIPT_NAME) return;

            memCollecting = 1;
            memData = "";

            llSetTimerEvent(5.0);
        }
        else if (code == 136) {
            memData = cdSetValue(memData, [script], llList2String(split, 1));

            llSetTimerEvent(5.0);
        }
        else if (code == 150) {
            simRating = llList2String(split, 1);
        }
        else if (code == 300) {
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);
            split = llDeleteSubList(split, 0, 1);

                 if (name == "MistressList")             MistressList = split;
            else if (name == "isVisible")                  doVisibility((integer)value);
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                 debugLevel = (integer)value;
#endif
            else if (name == "keyAnimation")             keyAnimation = value;
            else if (name == "poserID")                       poserID = (key)value;
            else if (name == "dialogChannel")           dialogChannel = (integer)value;
            else if (name == "quiet")                           quiet = (integer)value;
            else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "canAFK")                         canAFK = (integer)value;
            else if (name == "canCarry")                     canCarry = (integer)value;
            else if (name == "canDress")                     canDress = (integer)value;
            else if (name == "canPose")                       canPose = (integer)value;
            else if (name == "canWear")                       canWear = (integer)value;
            else if (name == "canFly")                         canFly = (integer)value;
            else if (name == "canSit")                         canSit = (integer)value;
            else if (name == "canStand")                     canStand = (integer)value;
            else if (name == "canRepeat")                   canRepeat = (integer)value;
            else if (name == "doWarnings")                 doWarnings = (integer)value;
            else if (name == "poseSilence")               poseSilence = (integer)value;
            else if (name == "detachable")                 detachable = (integer)value;
            else if (name == "helpless")                     helpless = (integer)value;
            else if (name == "pleasureDoll")             pleasureDoll = (integer)value;
            else if (name == "signOn")                         signOn = (integer)value;
            else if (name == "pronounHerDoll")         pronounHerDoll = value;
            else if (name == "pronounSheDoll")         pronounSheDoll = value;
            else if (name == "dollType") {
                if (configured && (keyAnimation != "") && (keyAnimation != ANIMATION_COLLAPSED) && (poserID != dollID)) {
                    if (value == "Display")
                        llOwnerSay("As you feel yourself become a display doll you feel a sense of helplessness knowing you will remain posed until released.");
                    else if (dollType == "Display")
                        llOwnerSay("You feel yourself transform to a " + value + " doll and know you will soon be free of your pose when the timer ends.");
                    dollType = value;
                    lmInternalCommand("setPose", keyAnimation, NULL_KEY);
                }
            }
            //else if (isAttached && (name == "dollyName")) {
            //    string dollyName = value;
            //    llOwnerSay("AUX:300: dollyName = " + dollyName + " (setting)");
            //    llSetObjectName(dollyName + "'s Key");
            //}

            // Only MenuHandler script can activate these selections...
            if (script != "MenuHandler") return;

            if (name == "canWear") {
                if (value == "1") llOwnerSay("You are now able to change your own outfits again.");
                else llOwnerSay("You are just a dolly and can no longer dress or undress by yourself.");
            }
            else if (name == "canFly") {
                if (value == "1") llOwnerSay("You now find yourself able to fly.");
                else llOwnerSay("You are just a dolly and cannot possibly fly.");
            }
            else if (name == "canRepeat") {
                if (value == "1") llOwnerSay("You can now be wound several times by one person again.");
                else llOwnerSay("You can no longer be wound twice in a row by the same person (except controllers).");
            }
            else if (name == "canPose") {
                if (value == "1") llOwnerSay("You are a dolly and can freely be posed by anyone.");
                else {
                    llOwnerSay("You can no longer be posed by others.");

                    if ((keyAnimation != "") && (keyAnimation != ANIMATION_COLLAPSED)) { // Doll is already posed
                        if (poserID != dollID) { // Posed by another we should unpose so doll is not stuck
                            lmInternalCommand("doUnpose", "", poserID);
                        }
                    }
                }
            }
            else if (name == "canCarry") {
                if (value == "1") llOwnerSay("Other people can now carry you.");
                else llOwnerSay("Other people can no longer carry you.");
            }
            else if (name == "canDress") {
                if (value == "1") llOwnerSay("Other people can now outfit you.");
                else llOwnerSay("Other people can no longer outfit you.");
            }
            else if (name == "doWarnings") {
                if (value == "1") llOwnerSay("No warnings will be given when time remaining is low.");
                else llOwnerSay("Warnings will now be given when time remaining is low.");
            }
            else if (name == "offlineMode") {
                if (value == "1") llOwnerSay("Key now working in offline mode setting changes will no longer be backed up.");
                else llOwnerSay("Key now working in online mode settings will be backed up online and automatically shared between your keys.");
            }
            else if (name == "isVisible") {
                if (value == "1") llOwnerSay("Your key appears magically.");
                else llOwnerSay("Your key fades from view...");
            }
#ifdef ADULT_MODE
            else if (name == "pleasureDoll") {
                if (value == "1") llOwnerSay("You are now a pleasure doll.");
                else llOwnerSay("You are no longer a pleasure doll.");
            }
#endif

        }
        else if (code == 305) {
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llList2List(split, 2, -1);

            if (cmd == "setAFK") {
                afk = llList2Integer(split, 0);
                integer auto = llList2Integer(split, 1);
                string rate = llList2String(split, 2);
                string mins = llList2String(split, 3);

                if (afk) {
                    if (auto)
                        llOwnerSay("Automatically entering AFK mode. Wind down rate has slowed to " + rate + "x however and movements and abilities are restricted.");
                    else
                        llOwnerSay("You are now away from keyboard (AFK). Wind down rate has slowed to " + rate + "x however and movements and abilities are restricted.");
                } else {
                    llOwnerSay("You are now no longer away from keyboard (AFK). Movements are unrestricted and winding down proceeds at normal rate.");
                }
                llOwnerSay("You have " + mins + " minutes of life remaning.");
            }
            else if (cmd == "carry") {
                carrierID = id;
                carrierName = llList2String(split, 0);
                if (!quiet) llSay(0, "The doll " + dollName + " has been picked up by " + carrierName);
                else {
                    llOwnerSay("You have been picked up by " + carrierName);
                    llRegionSayTo(carrierID, 0, "You have picked up the doll " + dollName);
                }
            }
            else if (cmd == "strip") {
                string part = llList2String(split, 0);
                if (id != dollID) {
                    lmInternalCommand("wearLock", (string)(wearLock = 1), NULL_KEY);
                    if (!quiet) llSay(0, "The dolly " + dollName + " has " + llToLower(pronounHerDoll) + " " + llToLower(part) + " stripped off " + llToLower(pronounHerDoll) + " and may not redress for " + (string)llRound(WEAR_LOCK_TIME / 60.0) + " minutes.  (Timer will start over for dolly if " + llToLower(pronounSheDoll) + " is stripped again)");
                    else llOwnerSay("You have had your " + llToLower(part) + " stripped off you and may not redress for " + (string)llRound(WEAR_LOCK_TIME / 60.0) + " minutes, your time will restart if you are stripped again.");
                }
                else llOwnerSay("You have stripped off your own " + llToLower(part) + ".");
            }
            else if (cmd == "uncarry") {
                if (quiet) lmSendToAgent("You were carrying " + dollName + " and have now placed them down.", carrierID);
                else llSay(0, "Dolly " + dollName + " has been placed down by " + carrierName);
                carrierID = NULL_KEY;
                carrierName = "";
            }
        }
        else if (code == 350) {
            RLVok = llList2Integer(split, 1);
        }
        else if (code == 500) {
            string script = llList2String(split, 0);
            string choice = llList2String(split, 1);
            string avatar = llList2String(split, 2);

            if (choice == "Join Group") {
                llOwnerSay("Here is your link to the community dolls group profile secondlife:///app/group/0f0c0dd5-a611-2529-d5c7-1284fb719003/about");
                llDialog(id, "To join the community dolls group open your chat history (CTRL+H) and click the group link there.  Just click the Join Group button when the group profile opens.", [MAIN], 9999);
            }
            else if (choice == "Access...") {
                debugSay(5, "DEBUG-AUX", "Dialog channel: " + (string)dialogChannel);
                string msg = "Key Access Menu. (" + OPTION_DATE + " version)\n" +
                             "These are powerful options allowing you to give someone total control of your key or block someone from touch or even winding your key\n" +
                             "Good dollies should read their key help before \n" +
                             "Blacklist - Fully block this avatar from using any key option even winding\n" +
                             "Controller - Take care choosing your controllers, they have great control over their doll can only be removed by their choice";
                list pluslist = [ "⊕ Blacklist", "⊖ Blacklist", "List Blacklist", "⊕ Controller", "List Controller" ];

                if (llListFindList(BuiltinControllers, [ (string)id ]) != -1) pluslist +=  "⊖ Controller";

                llDialog(id, msg, dialogSort(llListSort(pluslist, 1, 1) + MAIN), dialogChannel);
            }
            else if (llGetSubString(choice, 0, 4) == "Pose" && (keyAnimation == ""  || (!isDoll || poserID == dollID))) {
                poserID = id;
                integer page = 1; integer len = llStringLength(choice);
                if (len > 5) {
                    page = (integer)llGetSubString(choice, 6 - len, -1);
                }
                else {
                    llOwnerSay("secondlife:///app/agent/" + (string)id + "/about is looking at your poses menu.");
                }
                integer poseCount = llGetInventoryNumber(20);
                list poseList; integer i;

                for (i = 0; i < poseCount; i++) {
                    string poseName = llGetInventoryName(20, i);
                    if (poseName != ANIMATION_COLLAPSED &&
                        ((isDoll || isController) || llGetSubString(poseName, 0, 0) != "!") &&
                        (isDoll || llGetSubString(poseName, 0, 0) != ".")) {
                        if (poseName != keyAnimation) poseList += poseName;
                        else poseList += [ "* " + poseName ];
                    }
                }
                poseCount = llGetListLength(poseList);
                integer pages = 1;
                if (poseCount > 11) pages = llCeil((float)poseCount / 9.0);
                debugSay(7, "DEBUG", "Anims: " + (string)llGetInventoryNumber(20) + " | Avail Poses: " + (string)poseCount + " | Pages: " + (string)pages +
                    "\nAvailable: " + llList2CSV(poseList) +
                    "\nThis Page (" + (string)page + "): " + llList2CSV(llList2List(poseList, (page - 1) * 9, page * 9 - 1)));
                if (poseCount > 11) {
                    poseList = llList2List(poseList, (page - 1) * 9, page * 9 - 1);
                    integer prevPage = page - 1;
                    integer nextPage = page + 1;
                    if (prevPage == 0) prevPage = 1;
                    if (nextPage > pages) nextPage = pages;
                    poseList = [ "Poses " + (string)prevPage, "Poses " + (string)nextPage, MAIN ] + poseList;
                }
                else poseList = dialogSort(poseList + [ MAIN ]);

                llDialog(id, "Select the pose to put the doll into", poseList, dialogChannel);
            }
            if (choice == "Abilities...") {
                string msg = "See " + WEB_DOMAIN + "keychoices.htm for explanation. (" + OPTION_DATE + " version)";
                list pluslist;

                if (RLVok) {
                    // One-way options
                    pluslist += getButton("Detachable", id, detachable, 1);
                    pluslist += getButton("Flying", id, canFly, 1);
                    pluslist += getButton("Sitting", id, canSit, 1);
                    pluslist += getButton("Standing", id, canStand, 1);
                    pluslist += getButton("Self Dress", id, canWear, 1);
                    pluslist += getButton("Self TP", id, !helpless, 1);
                    pluslist += getButton("Force TP", id, autoTP, 1);
                    if (canPose) { // Option to silence the doll while posed this this option is a no-op when canPose == 0
                        pluslist += getButton("Pose Silence", id, poseSilence, 1);
                    }
                }
                else {
                    msg += "\n\nDolly does not have an RLV capable viewer of has RLV turned off in her viewer settings.  There are no usable options available.";
                    pluslist = [ "OK" ];
                }

                llDialog(id, msg, dialogSort(pluslist + MAIN), dialogChannel);
            }
            else if (choice == "Features...") {
                string msg = "See " + WEB_DOMAIN + "keychoices.htm for explanation. (" + OPTION_DATE + " version)";
                list pluslist;

                if (isTransformingKey) pluslist += getButton("Type Text", id, signOn, 0);
                pluslist += getButton("Quiet Key", id, quiet, 0);
#ifdef ADULT_MODE
                pluslist += getButton("Pleasure Doll", id, pleasureDoll, 0);
#endif
                pluslist += getButton("Warnings", id, doWarnings, 0);
                pluslist += getButton("Poseable", id, canPose, 0);
                pluslist += getButton("Outfitable", id, canDress, 0);
                pluslist += getButton("Carryable", id, canCarry, 0);
                pluslist += getButton("Offline", id, offlineMode, 0);
                // One-way options
                pluslist += getButton("Allow AFK", id, canAFK, 1);
                pluslist += getButton("Rpt Wind", id, canRepeat, 1);

                llDialog(id, msg, dialogSort(pluslist + MAIN), dialogChannel);
            }
        }

        // 501 is a text box input - with three types:
        //   1: Gem Color
        //   2: Dolly Name
        //   3: Wind Times (moved to Main.lsl)

        else if (code == 501) {
            string script = llList2String(split, 0);
            integer textboxType = llList2Integer(split, 1);
            string name = llList2String(split, 2);
            string choice = llDumpList2String(llList2List(split, 3, -1), "|");

            debugSay(3, "DEBUG-MENU", "Textbox input (" + (string)textboxType + ") from " + name + ": " + choice);

            // Type 1 = Custom Gem Color
            if (textboxType == 1) {
                string first = llGetSubString(choice, 0, 0);

                if (first == "<") choice = (string)((vector)choice);
                else if (first == "#") choice = (string)(
                     (vector)("<0x" + llGetSubString(choice, 1, 2) +
                              ",0x" + llGetSubString(choice, 3, 4) +
                              ",0x" + llGetSubString(choice, 5, 6) + ">"));
                else choice = (string)((vector)("<" + choice + ">"));

                lmInternalCommand("setGemColour", choice, id);
            }

            // Type 2 = New Dolly Name
            //else if (textboxType == 2) {
            //    llOwnerSay("AUX:TEXTBOX(2): choice = " + choice + " (to 300)");
            //    lmSendConfig("dollyName", choice);
            //}

            // Type 3 = Wind Times
            // -- now located in Main.lsl (which handles setting those up anyway)
        }
        else if (code == 700) {
            string sender = llList2String(split, 0);
            integer level = llList2Integer(split, 1);
            string prefix = llList2String(split, 2);
            string msg = llDumpList2String(llList2List(split, 3, -1), "|");

            debugHandler(sender, level, prefix, msg);
        }

        string type = llList2String(llParseString2List(data, [ "|" ], []), 1);

        if (type == "MistressList" || type == "carry" || type == "uncarry" || type == "updateExceptions") {

            // Exempt builtin or user specified controllers from TP restictions

            list allow = BuiltinControllers + llList2ListStrided(MistressList, 0, -1, 2);
            integer builtin = llGetListLength(BuiltinControllers);

            // Also exempt the carrier if any provided they are not already exempted as a controller

            if ((carrierID != NULL_KEY) && (llListFindList(allow, [ (string)carrierID ]) == -1)) allow += carrierID;

            // Directly dump the list using the static parts of the RLV command as a seperator no looping

            lmRunRLVas("Base", "tplure:"    + llDumpList2String(allow, "=add,tplure:")    + "=add");
            lmRunRLVas("Base", "accepttp:"  + llDumpList2String(allow, "=add,accepttp:")  + "=add");
            lmRunRLVas("Base", "sendim:"    + llDumpList2String(allow, "=add,sendim:")    + "=add");
            lmRunRLVas("Base", "recvim:"    + llDumpList2String(allow, "=add,recvim:")    + "=add");
            lmRunRLVas("Base", "recvchat:"  + llDumpList2String(allow, "=add,recvchat:")  + "=add");
            lmRunRLVas("Base", "recvemote:" + llDumpList2String(allow, "=add,recvemote:") + "=add");

            // Apply exemptions to base RLV
        }
    }

    dataserver(key request, string data) {
        if (request == ncRequest) {
            if (data == EOF) {
                doVisibility(-1);
                ncRequest = NULL_KEY;

                if (!memCollecting) llSetTimerEvent(0.0);
            }
            else {
                debugSay(5, "DEBUG-NOTECARDS", APPEARANCE_NC + " (" + (string)ncLine + "): " + data);
                glowSettings += llJson2List(data);

                if (!memCollecting) llSetTimerEvent(1.0);
            }
        }
    }

    timer() {
        if (ncRequest != NULL_KEY) {
            ncRequest = llGetNotecardLine(APPEARANCE_NC, ncLine++);
        }
        else if (memCollecting) {
            if (memCollecting && (memTime < llGetTime())) {
                float memory_limit = (float)llGetMemoryLimit();
                float free_memory = (float)llGetFreeMemory();
                float used_memory = (float)llGetUsedMemory();
                float available_memory = free_memory + (65536 - memory_limit);
                if (((used_memory + free_memory) > (memory_limit * 1.05)) && (memory_limit <= 16384)) { // LSL2 compiled script
                   memory_limit = 16384;
                   used_memory = 16384 - free_memory;
                   available_memory = free_memory;
                }
                memData = cdSetValue(memData,[SCRIPT_NAME],llList2Json(JSON_ARRAY, [used_memory, memory_limit, free_memory, available_memory]));

                integer i; string scriptName; list statList;
                string output = "Script Memory Status:";
                for (i = 0; i < llGetInventoryNumber(10); i++) {
                    scriptName =        llGetInventoryName(10, i);
                    if (cdGetElementType(memData, ([scriptName,0])) != JSON_INVALID) {
                        used_memory =       (float)cdGetValue(memData, ([scriptName,0]));
                        memory_limit =      (float)cdGetValue(memData, ([scriptName,1]));
                        free_memory =       (float)cdGetValue(memData, ([scriptName,2]));
                        available_memory =  (float)cdGetValue(memData, ([scriptName,3]));
                        
                        statList += [ used_memory, memory_limit, free_memory, available_memory ];
    
                        output += "\n" + scriptName + ":\t" + formatFloat(used_memory / 1024.0, 2) + "/" + (string)llRound(memory_limit / 1024.0) + "kB (" +
                                  formatFloat(free_memory / 1024.0, 2) + "kB free, " + formatFloat(available_memory / 1024.0, 2) + "kB available)";
                    }
                    else {
                        output += "\n" + scriptName + ":\tNo Report";
                    }
                }
                
                scriptName =        "Totals";
                used_memory =       llListStatistics(LIST_STAT_SUM, llList2ListStrided(statList, 0, -1, 4));
                memory_limit =      llListStatistics(LIST_STAT_SUM, llList2ListStrided(llDeleteSubList(statList, 0, 0), 0, -1, 4));
                free_memory =       llListStatistics(LIST_STAT_SUM, llList2ListStrided(llDeleteSubList(statList, 0, 1), 0, -1, 4));
                available_memory =  llListStatistics(LIST_STAT_SUM, llList2ListStrided(llDeleteSubList(statList, 0, 2), 0, -1, 4));
                
                output += "\n" + scriptName + ":\t" + formatFloat(used_memory / 1024.0, 2) + "/" + (string)llRound(memory_limit / 1024.0) + "kB (" +
                           formatFloat(free_memory / 1024.0, 2) + "kB free, " + formatFloat(available_memory / 1024.0, 2) + "kB available)";

                llOwnerSay(output);

                memCollecting = 0;

                if (ncRequest == NULL_KEY) llSetTimerEvent(0.0);
                else llSetTimerEvent(1.0);
            }
        }
    }
}
