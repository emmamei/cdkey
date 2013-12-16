// Start.lsl
//
// DATE: 18 December 2012
//
// This is the initial hypnotic suggestion and RolePlay
// called from Main.lsl.  The text is sent to the Key
// owner over the space of about three minutes when the
// Key is first used.
//
// As of 30 October 2013, this script is unused.

string optiondate = "15/Dec/13";

float delayTime = 15.0; // in seconds

// Keys of important people in life of the Key:
key MasterBuilder = "42c7aaec-38bc-4b0c-94dd-ae562eb67e6d";   // Christina Halpin
key  MasterWinder = "64d26535-f390-4dc4-a371-a712b946daf8";   // GreigHighland
key        DevOne = "c5e11d0a-694f-46cc-864b-e42340890934";   // MayStone
key        DevTwo = "2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9";   // Silky Mesmeriser

list rescuerList = [ MasterBuilder, MasterWinder ];
list developerList = [ DevOne, DevTwo ];

key dollID;

key ncPrefsKey;
key ncPrefsLoadedUUID = NULL_KEY;
string ncName = "Preferences";
integer ncLine;
integer replyHandle;

float ncStart;
integer quiet;
integer lastAttachPoint;
key lastAttachAvatar;

list knownScripts;
list readyScripts;
integer startup = 1;
integer reset;

msg (string s) {
    sendMsg(dollID, s);
    llSleep(delayTime);
}

memReport() {
    float free_memory = (float)llGetFreeMemory();
    float used_memory = (float)llGetUsedMemory();
    
    if (devKey()) llOwnerSay(llGetScriptName() + ": Memory " + FormatFloat(used_memory/1024.0, 2) + "/" + (string)llRound((used_memory + free_memory)/1024.0) + "kB, " + FormatFloat(free_memory/1024.0, 2) + " kB free");
}

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

integer devKey() {
    if (dollID != llGetOwner()) dollID = llGetOwner();
    return llListFindList(developerList, [ dollID ]) != -1;
}

string FormatFloat(float val, integer dp)
{
    string out = "ERROR";
    if (dp == 0) {
        out = (string)llRound(val);
    } else if (dp > 0 && dp <= 6) {
        val = llRound(val * llPow(10.0, dp)) / llPow(10.0, dp);
        out = llGetSubString((string)val, 0, -7 + dp);
    }
    return out;
}

initConfiguration() {
    sendMsg(dollID, "Loading preferences notecard");
    ncStart = llGetTime();
    
    // Check to see if the file exists and is a notecard
    if (llGetInventoryType(ncName) == INVENTORY_NOTECARD) {

        // Start reading from first line (which is 0)
        ncLine = 0;
        ncPrefsKey = llGetNotecardLine(ncName, ncLine);

    } else {

        // File missing - report for debugging only
        sendMsg(dollID, "No configuration found (" + ncName + ")");
    }
}

doneConfiguration() {
    if (startup) {
        ncPrefsLoadedUUID = llGetInventoryKey(ncName);
        //sendMsg(dollID, (string)ncPrefsLoadedUUID);
        llMessageLinked(LINK_SET, 102, "", NULL_KEY);
        startup = 0;
        if (devKey()) sendMsg(dollID, "Preferences read in " + FormatFloat(llGetTime() - ncStart, 2) + "s");
    }
    
    llSleep(1);
    
    string msg = "Initialization completed";
    if (devKey()) msg += " in " + FormatFloat(llGetTime(), 2) + "s";
    msg += " key ready";
    sendMsg(dollID, msg);
    if (!quiet && llGetAttached() == ATTACH_BACK)
        llSay(0, llGetDisplayName(llGetOwner()) + " is now a dolly - anyone may play with their Key.");
    
    if (devKey()) llMessageLinked(LINK_SET, 135, llGetScriptName(), NULL_KEY);
}

list notReady() {
    list waiting; integer loop;
    for (loop = 0; loop < llGetListLength(knownScripts); loop++) {
        string script = llList2String(knownScripts, loop);
        if (llListFindList(readyScripts, [ script ]) == -1 && llGetScriptState(script)) waiting += script;
    }
    return waiting;
}

default {
    link_message(integer source, integer num, string choice, key id) {
        if (num == 200) { // Triggered from Main.lsl

            llOwnerSay("---- Community Doll Key loaded: Version: " + optiondate);
            llOwnerSay("---- Key: " + llKey2Name(id));

            // First minute....
            msg("You feel a key being put on your back, the weight settling in. Imagine that as vividly as you can.");
            msg("You feel a pinch as tendrils from the key sink into your back, and then a flood of cool relief as they sink in further.");
            msg("The tendrils are releasing doll hormones into your body, and you feel the rush through every pore in your body.");
            msg("The hormones are relaxing you and making you feel comfortable with being a doll. Any fears you had have slipped away and are forgotten.");

            // Second minute....
            msg("You realize how wonderful it would be to be displayed and everyone just admire you for your beauty - and you marvel that you never knew this before.");
            msg("You now realize how wonderful it is to be liked - more wonderful than you ever knew.");
            msg("You realize your dependency on the community; this will define you. You now accept and welcome this.");
            msg("You only now realize how beautiful you are. You were always beautiful - but now it becomes obvious because you are a doll.");

            // Third minute...
            msg("You realize now that other dolls are your sisters - and understand you like no one else.");
        }
        else if (num == 11) {
            sendMsg(id, choice);
        }
        else if (num == 103) {
            if (llListFindList(readyScripts, [ choice ]) == -1) {
                readyScripts += choice;
            }
            if (choice == "RLV") {
                if (startup) initConfiguration();
                else doneConfiguration();
            }
        }
        else if (num == 135) memReport();
        else if (num == 999) {
            if (reset) llResetScript();
        }
    }
    
    state_entry() {
        dollID = llGetOwner();
        
        llTargetOmega(<0,0,0>,0,0);
        
        llSetObjectName(llList2String(llGetLinkPrimitiveParams(24, [ PRIM_DESC ]), 0) + " " + optiondate);
        
        string me = llGetScriptName();
        integer loop; string script;
        
        llOwnerSay("Resetting scripts");
        
        for (loop = 0; loop < llGetInventoryNumber(INVENTORY_SCRIPT); loop++) {
            script = llGetInventoryName(INVENTORY_SCRIPT, loop);
            if (script != me) {
                knownScripts += script;
                llResetOtherScript(script);
            }
        }
        
        llMessageLinked(LINK_SET, 300, "optiondate|" + optiondate, NULL_KEY);
        
        llSetTimerEvent(2);
    }
    
    on_rez(integer start) {
        if (startup) llResetScript();
        
        llTargetOmega(<0,0,0>,0,0);
        
        llResetTime();
        string me = llGetScriptName();
        integer loop; string script;
        
        sendMsg(dollID, "Starting initialization");
        knownScripts = [];
        readyScripts = [];
        
        for (loop = 0; loop < llGetInventoryNumber(INVENTORY_SCRIPT); loop++) {
            script = llGetInventoryName(INVENTORY_SCRIPT, loop);
            if (script != me) knownScripts += script;
        }
        
        llSetTimerEvent(120);
        
        llMessageLinked(LINK_SET, 105, llGetScriptName(), NULL_KEY);
    }
    
    attach(key id) {
        if (id == NULL_KEY) {
            llMessageLinked(LINK_SET, 106, "detached|" + (string)lastAttachPoint, lastAttachAvatar);
            if (lastAttachPoint == ATTACH_BACK) {
                llOwnerSay("The key is wrenched from your back, and you double over at the " +
                           "unexpected pain as the tendrils are ripped out. You feel an emptiness, " +
                           "as if some beautiful presence has been removed.");
            }
        } else {
            llMessageLinked(LINK_SET, 106, "attached|" + (string)llGetAttached(), id);
            
            if (llGetAttached() != ATTACH_BACK) {
                llMessageLinked(LINK_SET, 311, "windDown|0", id);
                
                llOwnerSay("Your key stubbornly refuses to attach itself, and you " +
                           "belatedly realize that it must be attached to your spine.");
                llOwnerSay("@clear,detachme=force");
                
                llSleep(2);
                llDetachFromAvatar();
            }
            
            lastAttachPoint = llGetAttached();
            lastAttachAvatar = id;
        }
    }
    
    dataserver(key query_id, string data) {
        list validConfig = [ "initial time", "wind time", "max time", "doll type", "helpless dolly", "controller",
                             "auto tp", "can fly", "outfitable", "pleasure doll", "detachable", "barefeet path", 
                             "user startup rlv", "user collapse rlv", "quiet key" ];
                             
        if (query_id == ncPrefsKey) {
            if (data == EOF) {
                doneConfiguration();
            } else {
                if (data != "" && llGetSubString(data, 0, 0) != "#") {
                    integer index = llSubStringIndex(data, "=");
                    string name = llGetSubString(data, 0, index - 1);
                    string value = llGetSubString(data, index + 1, -1);
                    name = llStringTrim(llToLower(name), STRING_TRIM);
                    value = llStringTrim(value, STRING_TRIM);
                    list parameterList = llParseString2List(value, [ "|" ], []);
                    string param = "|" + llDumpList2String(parameterList, "|");
                    if (llListFindList(validConfig, [ name ]) != -1)
                        llMessageLinked(LINK_SET, 101, name + param, NULL_KEY);
                    //--------------------------------------------------------------------------
                    // Disabled for future use, allows for extention scripts to add support for
                    // their own peferences by using names starting with the prefix 'ext'. These
                    // are sent with a different link code to prevent clashes with built in names
                    //--------------------------------------------------------------------------
                    //else if (llGetSubString(name, 0, 2) == "ext")
                    //    llMessageLinked(LINK_SET, 201, name + param, NULL_KEY);
                    else
                        llOwnerSay("Unknown configuration value: " + name + " on line " + (string)(ncLine + 1));
                }
                ncPrefsKey = llGetNotecardLine(ncName, ++ncLine);
            }
        }
    }
    
    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            if (ncPrefsLoadedUUID != NULL_KEY && llGetInventoryKey(ncName) != ncPrefsLoadedUUID) {
                // Get a unique number
                integer ncd = -1 * (integer)("0x" + llGetSubString((string)llGetKey(),-7,-1));
                integer channel = ncd - 5467;
                replyHandle = llListen(channel, "", "", "");
                
                llSetTimerEvent(60);
                llDialog(llGetOwner(), "Detected a change in your Preferences notecard, would you like to load the new settings?\n\n" +
                  "WARNING: All current data will be lost!", [ "Reload Config", "Keep Settings" ], channel);
            }
        }
        if (change & CHANGED_OWNER) {
            llOwnerSay("Deleting old preferences notecard on owner change.");
            llOwnerSay("Look at PreferencesExample to see how to make yours.");
            llRemoveInventory(ncName);
            llSleep(5);
            llResetScript();
        }
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (message == "Reload Config") {
            llResetScript();
        }
    }
    
    timer() {
        llListenRemove(replyHandle);
        llSetTimerEvent(0);
        
        if (!reset) {
            llOwnerSay("Starting initialization");
            reset = 1;
            llSetTimerEvent(120);
            llMessageLinked(LINK_SET, 104, llGetScriptName(), NULL_KEY);
        }
        else if (startup) {
            sendMsg(dollID, "Startup failure detected one or more scripts may have crashed, resetting");
            
            if (devKey()) sendMsg(dollID, "The following scripts did not report: " + llList2CSV(notReady()));
        }
    }
}