#include "include/GlobalDefines.lsl"

key ncRequest;
string ncName = "Glow Settings";
integer initState = 104;
integer ncLine;
integer visible;
integer memCollecting;
list MistressList;
list glowSettings;
list memData;

sendMsg(key target, string msg) {
    if (llGetSubString(msg, 0, 0) == "%" && llGetSubString(msg, -1, -1) == "%") {
        msg = findString(msg);
    }
    
    if (target == dollID) llOwnerSay(msg);
    else if (llGetAgentSize(target)) llRegionSayTo(target, 0, msg);
    else llInstantMessage(target, msg);
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
    if (llGetInventoryType(ncName) == INVENTORY_NOTECARD) {
        if (setVisible != -1) visible = setVisible;
        
        if (visible == 0) {
            llSetLinkPrimitiveParamsFast(LINK_SET, [ PRIM_GLOW, 0, 0.0, PRIM_GLOW, 1, 0.0, PRIM_GLOW, 2, 0.0, PRIM_GLOW, 3, 0.0, PRIM_GLOW, 4, 0.0, PRIM_GLOW, 5, 0.0, PRIM_GLOW, 6, 0.0 ]);
        }
        else {
            llSetLinkPrimitiveParamsFast(1, glowSettings);
        }
    }
}

default
{
    link_message(integer sender, integer code, string data, key id) {
        list split = llParseStringKeepNulls(data, ["|"], []);
        string script = llList2String(split, 0);
        
        if (code == 11) {
            debugSay(7, "Send message to: " + (string)id + "\n" + data);
            sendMsg(id, llList2String(split,0));
        }
        else if (code == 15) {
            integer i;
            for (i = 0; i < llGetListLength(llList2ListStrided(MistressList, 0, -1, 2)); i++) {
                debugSay(7, "MistressMsg To: " + llList2String(llList2ListStrided(MistressList, 0, -1, 2), i) + "\n" + data);
                sendMsg(llList2Key(llList2ListStrided(MistressList, 0, -1, 2), i), data);
            }
        }
        if (code == 102) {
            if (llGetInventoryType(ncName) == INVENTORY_NOTECARD) {
                ncLine = 0;
                glowSettings = [];
                ncRequest = llGetNotecardLine(ncName, ncLine++);
                llSetTimerEvent(0.25);
            }
        }
        if ((code == 104) || (code == 105)) {
            if (initState == code) lmInitState(initState++);
        }
        else if (code == 110) {
            initState = 105;
        }
        else if (code == 135) {
            memData = [];
            memCollecting = 1;
            llSetTimerEvent(3.0);
        }
        else if (code == 136) {
            memData += split;
        }
        else if (code == 300) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);
            split = llList2List(split, 2, -1);
            
                 if (name == "MistressList")              MistressList = split;
            else if (name == "isVisible")                 doVisibility((integer)value);
            
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
                if (value == "1") llOwnerSay("You can now be wound several times by one person again,");
                else llOwnerSay("You can no longer be wound twice in a row by the same person (except controllers).");
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
        else if (code == 500) {
            string choice = llList2String(split, 0);
            string avatar = llList2String(split, 1);
            
            if (choice == "Join Group") {
                llOwnerSay("Here is your link to the community dolls group profile secondlife:///app/group/0f0c0dd5-a611-2529-d5c7-1284fb719003/about");
                llDialog(id, "To join the community dolls group open your chat history (CTRL+H) and click the group link there.  Just click the Join Group button when the group profile opens.", [MAIN], 9999);
            }
            else if (choice == "Access Menu") {
                string msg = "Key Access Menu. (" + OPTION_DATE + " version)\n" +
                             "These are powerful options allowing you to give someone total control of your key or block someone from touch or even winding your key\n" +
                             "Good dollies should read their key help before \n" +
                             "Blacklist - Fully block this avatar from using any key option even winding\n" +
                             "Controller - Take care choosing your controllers, they have great control over their doll can only be removed by their choice";
                list pluslist = [ "⊕ Blacklist", "⊖ Blacklist", "List Blacklist", "⊕ Controller", "List Controllers" ];
                
                if (llListFindList(BuiltinControllers, [ (string)id ]) != -1) pluslist +=  "⊖ Controller";
                
                llDialog(id, msg, dialogSort(llListSort(pluslist, 1, 1) + MAIN), dialogChannel);
            }
        }
    }
    
    dataserver(key request, string data) {
        if (request == ncRequest) {
            if (data == EOF) {
                doVisibility(-1);
                ncRequest = NULL_KEY;
            }
            else glowSettings += llJson2List(data);
        }
    }
    
    timer() {
        llSetTimerEvent(0.0);
        if (ncRequest != NULL_KEY) {
            ncRequest = llGetNotecardLine(ncName, ncLine++);
            llSetTimerEvent(0.25);
        }
        if (memCollecting) {
            float memory_limit = (float)llGetMemoryLimit();
            float free_memory = (float)llGetFreeMemory();
            float used_memory = (float)llGetUsedMemory();
            if (((used_memory + free_memory) > (memory_limit * 1.05)) && (memory_limit <= 16384)) { // LSL2 compiled script
               memory_limit = 16384;
               used_memory = 16384 - free_memory;
            }
            memData = llListSort(memData + [ SCRIPT_NAME, (string)used_memory, (string)memory_limit, (string)free_memory ], 4, 1);
            
            integer i; string scriptName;
            string output = "Script Memory Status:";
            for (i = 0; i < llGetListLength(memData); i += 4) {
                scriptName =     llList2String(memData, i);
                used_memory =    llList2Float(memData, i + 1);
                memory_limit =   llList2Float(memData, i + 2);
                free_memory =    llList2Float(memData, i + 3);
                
                output += "\n" + scriptName + ":\t" + formatFloat(used_memory / 1024.0, 2) + "/" + (string)llRound(memory_limit / 1024.0) + "kB (" +
                          formatFloat(free_memory / 1024.0, 2) + "kB free)";
            }
            
            llOwnerSay(output);

            memCollecting = 0;
        }
    }
}
