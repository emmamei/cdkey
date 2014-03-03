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
#define MESSAGE_NC "DataMessages"
#define DISPLAY_DOLL 0
#define SELF_DRESS 2
#define CAN_FLY 4
#define CAN_REPEAT 6
#define CAN_POSE 8
#define CAN_CARRY 10
#define DO_WARNINGS 12
#define OFFLINE 14
#define VISIBLE 16
#define POSE_SILENCE 18
#define PLEASURE_DOLL 20
#define SET_AFK 22

key ncRequestAppearance;
key ncRequestDollMessage;
key lmRequest;
key carrierID = NULL_KEY;
float rezTime;
float memTime;
string minsLeft;
string windRate;
string carrierName;
string pronounHerDoll = "Her";
string pronounSheDoll = "She";
integer configured;
integer ncLine;
integer visible;
integer memCollecting;
integer quiet;
integer wearLock;
integer rezzed;
integer visitDollhouse;
integer targetHandle;
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
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);
    }

    on_rez(integer start) {
        //lmSendXonfig("debugLevel", (string)debugLevel);
        rezTime = llGetTime();
        configured = 0;
        rezzed = 1;
    }
    
    changed(integer change) {
        if (change & CHANGED_TELEPORT) {
            visitDollhouse = 0;
            lmRequest = llRequestInventoryData(LANDMARK_CDROOM);
        }
    }

    link_message(integer source, integer code, string data, key id) {
        list split = llParseString2List(data, ["|"], []);
        string script = llList2String(split, 0);
        
        integer dollMessageCode; integer dollMessageVariant;

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
        else if (code == 102) {
            configured = 1;
            scaleMem();
        }
        else if (code == 110) {
            if (script != "Start") return;

            if (llGetInventoryType(APPEARANCE_NC) == INVENTORY_NOTECARD) {
                ncRequestAppearance = llGetNotecardLine(APPEARANCE_NC, ncLine++);
            }
        }
        else if (code == 135) {
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
                        ncRequestDollMessage = llGetNotecardLine(MESSAGE_NC, DISPLAY_DOLL + 1);
                    else if (dollType == "Display")
                        ncRequestDollMessage = llGetNotecardLine(MESSAGE_NC, DISPLAY_DOLL);
                    dollType = value;
                    lmInternalCommand("setPose", keyAnimation, NULL_KEY);
                }
            }

            // Only MenuHandler script can activate these selections...
            if (script != "MenuHandler") return;

            if (name == "canDress") {
                string msg;
                if (value == "1") msg = "Other people can now outfit you, but you remain ";
                else msg = "Other people can no longer outfit you, but you remain ";
                if (wearLock || !canWear) msg += "un";
                llOwnerSay(msg + "able to dress yourself.");
            }
            
            if (name == "canWear")              dollMessageCode = SELF_DRESS;
            else if (name == "canFly")          dollMessageCode = CAN_FLY;
            else if (name == "canRepeat")       dollMessageCode = CAN_REPEAT;
            else if (name == "canPose")         dollMessageCode = CAN_POSE;
            else if (name == "canCarry")        dollMessageCode = CAN_CARRY;
            else if (name == "doWarnings")      dollMessageCode = DO_WARNINGS;
            else if (name == "offlineMode")     dollMessageCode = OFFLINE;
            else if (name == "isVisible")       dollMessageCode = VISIBLE;
            else if (name == "poseSilence")     dollMessageCode = POSE_SILENCE;
#ifdef ADULT_MODE
            else if (name == "pleasureDoll")    dollMessageCode = PLEASURE_DOLL;
#endif
            dollMessageVariant = (integer)value;
        }
        else if (code == 305) {
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llList2List(split, 2, -1);

            if (cmd == "setAFK") {
                afk = llList2Integer(split, 0);
                integer auto = llList2Integer(split, 1);
                windRate = llList2String(split, 2);
                minsLeft = llList2String(split, 3);

                dollMessageCode = SET_AFK;

                if (afk) {
                    if (auto) dollMessageVariant = 0;
                    else dollMessageVariant = 1;
                }
                else dollMessageVariant = 2;
                llOwnerSay("");
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

            if (choice == "Help/Support") {
                string msg = "Here you can find various options to get help with your " +
                            "key and to connect with the community.";
                list pluslist = [ "Join Group", "Visit Dollhouse" ];
                if (llGetInventoryType(NOTECARD_HELP) == INVENTORY_NOTECARD) pluslist += [ "Help Notecard" ];
                if (isController || isDoll) pluslist += "Reset Scripts";
                if (isDoll) pluslist += ["Check Update", "Factory Reset"];

                llDialog(id, msg, dialogSort(pluslist + MAIN), dialogChannel);
            }
            else if (choice == "Help Notecard") {
                llGiveInventory(id,NOTECARD_HELP);
            }
            else if (choice == "Visit Dollhouse") {
                if (isDoll) llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|TP|" + LANDMARK_CDROOM, id);
                else llGiveInventory(id, LANDMARK_CDROOM);
            }
            else if (choice == "Dress") {
                if (!isDoll) llOwnerSay("secondlife:///app/agent/" + (string)id + "/about is looking at your dress menu");
            }
            else if (choice == "Join Group") {
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
                list pluslist;
                if (llListFindList(BuiltinControllers, [ (string)id ]) != -1) pluslist +=  "⊖ Controller";

                pluslist += [ "⊕ Blacklist", "List Blacklist", "⊖ Blacklist", "⊕ Controller", "List Controller" ];

                llDialog(id, msg, dialogSort(pluslist + MAIN), dialogChannel);
            }
            else if (choice == "Visit Dollhouse") {
                visitDollhouse += 1;
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
                if (dollType != "Display") pluslist += getButton("Poseable", id, canPose, 0);
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
        //   4: Safeword Confirm

        else if (code == 501) {
            string script = llList2String(split, 0);
            integer textboxType = llList2Integer(split, 1);
            string name = llList2String(split, 2);
            string choice = llDumpList2String(llDeleteSubList(split, 0, 2), "|");

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
            else if (textboxType == 2) {
                //llOwnerSay("AUX:TEXTBOX(2): choice = " + choice + " (to 300)");
                lmSendConfig("dollyName", choice);
            }

            // Type 3 = Wind Times
            // -- now located in Main.lsl (which handles setting those up anyway)
            
            // Type 4 = Safeword Confirm
            else if (textboxType == 4) {
                if (choice == "FACTORY RESET") {
                    lmSendToController(dollName + " has initiated a factory reset all key settings have been reset.");
                    lmSendConfig("SAFEWORD", "1");
                    llOwnerSay("You have safeworded your key will reset in 30 seconds.");
                }
                else {
                    lmMenuReply("Factory Reset", name, id);
                }
            }
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
        // HippoUPDATE reply
        else if (code == -2948813) {
            if (data == "VERSION") llOwnerSay("Your key is already up to date");
        }
        
        if (dollMessageCode) ncRequestDollMessage = llGetNotecardLine(MESSAGE_NC, dollMessageCode + (integer)dollMessageVariant);
    }

    dataserver(key request, string data) {
        if (request == ncRequestDollMessage) {
            integer i; integer index;
            list findList = [ "windRate", "minsLeft" ];
            list replaceList = [ windRate, minsLeft ];
            for (i = 0; i < 2; i++) {
                string find = "%" + llList2String(findList, i) + "%";
                string replace = llList2String(replaceList, i);
                while ( ( index = llSubStringIndex(data, find) ) != -1) {
                    data = llInsertString(llDeleteSubString(data, index, index + llStringLength(find) - 1), index, replace);
                }
            }
            llOwnerSay(data);
        }
        else if (request == ncRequestAppearance) {
            if (data == EOF) {
                doVisibility(-1);
                ncRequestAppearance = NULL_KEY;

                //llSleep(2.0);

                lmMemReport(0.0);
                
                llSetTimerEvent(5.0);
            }
            else {
                debugSay(5, "DEBUG-NOTECARDS", APPEARANCE_NC + " (" + (string)ncLine + "): " + data);
                glowSettings += llJson2List(data);

                if (!memCollecting) llSetTimerEvent(1.0);
            }
        }
        else if (request == lmRequest) {
            vector lmData = (vector)data;
            if ((lmData.x < 256) && (lmData.y < 256)) {
                targetHandle = llTarget(lmData, 1.0);
                llMoveToTarget(lmData, 0.000001);
            }
        }
    }
    
    at_target(integer target, vector targetPos, vector ourPos) {
        llTargetRemove(target);
        llStopMoveToTarget();
    }

    timer() {
        if (ncRequestAppearance != NULL_KEY) {
            ncRequestAppearance = llGetNotecardLine(APPEARANCE_NC, ncLine++);
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
                    if (scriptName != "UpdateScript") {
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

                if (ncRequestAppearance == NULL_KEY) llSetTimerEvent(0.0);
                else llSetTimerEvent(1.0);
            }
        }
    }
}
