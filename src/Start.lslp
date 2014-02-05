// Start.lsl
//
// DATE: 18 December 2012
//
#include "include/GlobalDefines.lsl"

//#define HYPNO_START   // Enable hypno messages on startup
//
// This is the initial hypnotic suggestion and RolePlay
// called from Main.lsl.  The text is sent to the Key
// owner over the space of about three minutes when the
// Key is first used.
//
// As of 30 October 2013, this script is unused.

float delayTime = 15.0; // in seconds
float nextIntro;
float initTimer;
float nextLagCheck;

key dollID = NULL_KEY;
key MistressID = NULL_KEY;

string dollName;

key ncPrefsKey;
key ncPrefsLoadedUUID = NULL_KEY;
key ncIntroKey;
float timeLeftOnKey = -1;
integer ncLine;

float ncStart;
integer lastAttachPoint;
key lastAttachAvatar;

list knownScripts;
list readyScripts;
list MistressList;
list blacklist;
list recentDilation;
list windTimes;
integer quiet;
integer newAttach = 1;
integer autoTP;
integer canFly = 1;
integer canSit = 1;
integer canStand = 1;
integer canDress = 1;
integer detachable = 1;
integer busyIsAway;
integer offlineMode;
string barefeet;
string dollType;
string userBaseRLVcmd;
string userCollapseRLVcmd;
string dollGender = "Female";
string pronounHerDoll = "Her";
string pronounSheDoll = "She";
integer startup;
integer initState = 103;
integer introLine;
integer introLines;
integer reset;
integer rlvWait;
integer RLVok = -1;
integer databaseOnline;

float keyLimit;
#ifdef SIM_FRIENDLY
integer afk;
integer lowScriptMode;
#endif

//---------------------------------------
// Configuration Functions
//---------------------------------------
// This code assumes a human-generated config file
processConfiguration(string name, list values) {
    //----------------------------------------
    // Assign values to program variables

    string value = llList2String(values,0);
    
    if (value == "yes" || value == "on") value = "1";
    else if (value == "no" || value == "off") value = "0";
    
    if (name == "initial time") {
        lmSendConfig("timeLeftOnKey", (string)((float)value * SEC_TO_MIN));
    }
    else if (name == "wind time") {
        if (llListSort(windTimes, 1, 1) != llListSort(values, 1, 1)) lmSendConfig("windTimes", llDumpList2String(values, "|"));
    }
    else if (name == "max time") {
        if (keyLimit != ((float)value * SEC_TO_MIN)) lmSendConfig("keyLimit", (string)((float)value * SEC_TO_MIN));
    }
    else if (name == "barefeet path") {
        if (barefeet != value) lmSendConfig("barefeet", value);
    }
    else if (name == "doll type") {
        if (dollType != value) lmSendConfig("dollType", value);
    }
    else if (name == "doll gender") {
        if (dollGender != "Male" && value == "male") {
            if (value == "male") lmSendConfig("dollGender", (dollGender = "Male"));
            lmSendConfig("pronounHerDoll", (pronounHerDoll = "His"));
            lmSendConfig("pronounSheDoll", (pronounSheDoll = "He"));
        } else if (dollGender != "Female" && dollGender != "Sissy") {
            if (dollGender != "Sissy" && value == "sissy") lmSendConfig("dollGender", (dollGender = "Sissy"));
            else if (dollGender != "Female") lmSendConfig("dollGender", (dollGender = "Female"));
            lmSendConfig("pronounHerDoll", (pronounHerDoll = "Her"));
            lmSendConfig("pronounSheDoll", (pronounSheDoll = "She"));
        }
    }
    else if (name == "user startup rlv") {
        if (userBaseRLVcmd != value) lmSendConfig("userBaseRLVcmd", value);
    }
    else if (name == "user collapse rlv") {
        if (userCollapseRLVcmd != value) lmSendConfig("userCollapseRLVcmd", value);
    }
    else if (name == "helpless dolly") {
        lmSendConfig("helpless", value);
    }
    else if (name == "auto tp") {
        lmSendConfig("autoTP", value);
    }
    else if (name == "pleasure doll") {
        lmSendConfig("pleasureDoll", value);
    }
    else if (name == "detachable") {
        lmSendConfig("detachable", value);
    }
    else if (name == "outfitable") {
        lmSendConfig("canDress", value);
    }
    else if (name == "can fly") {
        lmSendConfig("canFly", value);
    }
    else if (name == "can sit") {
        lmSendConfig("canSit", value);
    }
    else if (name == "can stand") {
        lmSendConfig("canStand", value);
    }
    else if (name == "busy is away") {
        if (busyIsAway != (integer)value) lmSendConfig("busyIsAway", value);
    }
    else if (name == "quiet key") {
        quiet = (integer)value;
        if (quiet != (integer)value) lmSendConfig("quiet", value);
    }
    else if (name == "blacklist") {
        if (llListFindList(blacklist, [ value ]) == -1)
            lmSendConfig("blacklist", llDumpList2String((blacklist = llListSort(blacklist + [ value, llRequestAgentData((key)value, DATA_NAME) ], 2, 1)), "|"));
    }
    else if (name == "controller") {
        if (llListFindList(MistressList, [ value ]) == -1)
            lmSendConfig("MistressList", llDumpList2String((MistressList = llListSort(MistressList + [ value, llRequestAgentData((key)value, DATA_NAME) ], 2, 1)), "|"));
    }
    else if (name == "blacklist name") {
        debugSay(5, "getBlacklistName: " + value);
        lmInternalCommand("getBlacklistName", value, NULL_KEY);
    }
    else if (name == "controller name") {
        debugSay(5, "getMistressName: " + value);
        lmInternalCommand("getMistressName", value, NULL_KEY);
    }
    //--------------------------------------------------------------------------
    // Disabled for future use, allows for extention scripts to add support for
    // their own peferences by using names starting with the prefix 'ext'. These
    // are sent with a different link code to prevent clashes with built in names
    //--------------------------------------------------------------------------
    //else if (llGetSubString(name, 0, 2) == "ext") {
    //    string param = "|" + llDumpList2String(values, "|");
    //    llMessageLinked(LINK_SET, 101, name + param, NULL_KEY);
    //}
    else {
        llOwnerSay("Unknown configuration value: " + name + " on line " + (string)(ncLine + 1));
    }
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

initConfiguration() {
    reset = 1;
    // Check to see if the file exists and is a notecard
    if (llGetInventoryType(NOTECARD_PREFERENCES) == INVENTORY_NOTECARD) {
        if (databaseOnline && (offlineMode || (ncPrefsLoadedUUID == NULL_KEY) || (ncPrefsLoadedUUID != llGetInventoryKey(NOTECARD_PREFERENCES)))) {
            sendMsg(dollID, "Loading preferences notecard");
            ncStart = llGetTime();
            
            // Start reading from first line (which is 0)
            ncLine = 0;
            ncPrefsKey = llGetNotecardLine(NOTECARD_PREFERENCES, ncLine);
        }
        else {
            debugSay(5, "Skipping preferences notecard as it is unchanged");
            doneConfiguration(0);
        }
    } else {
        // File missing - report for debugging only
        debugSay(5, "No configuration found (" + NOTECARD_PREFERENCES + ")");
        doneConfiguration(0);
    }
}

doneConfiguration(integer read) {
    if (startup == 1 && read) {
        ncPrefsLoadedUUID = llGetInventoryKey(NOTECARD_PREFERENCES);
        lmSendConfig("ncPrefsLoadedUUID", (string)ncPrefsLoadedUUID);
        #ifdef DEVELOPER_MODE
        sendMsg(dollID, "Preferences read in " + formatFloat(llGetTime() - ncStart, 2) + "s");
        #endif
    }
    reset = 1;
    readyScripts = [];
    llMessageLinked(LINK_THIS, 102, llGetScriptName(), NULL_KEY);
    startup = 2;
    if (initState == 104) lmInitState(++initState);
}

initializationCompleted() {
    if (newAttach && !quiet && isAttached)
        llSay(0, llGetDisplayName(llGetOwner()) + " is now a dolly - anyone may play with their Key.");
    newAttach = 0;
    
    llMessageLinked(LINK_THIS, 110, "Start", NULL_KEY);

    initTimer = llGetTime() * 1000;

    memReport(2.0);
    lmMemReport(0.0);
    
    llSleep(0.5);

    string msg = "Initialization completed";
    #ifdef DEVELOPER_MODE
    msg += " in " + formatFloat(initTimer, 2) + "ms";
    #endif
    msg += " key ready";
    sendMsg(dollID, msg);
    
    startup = 3;
    
    llSetTimerEvent(1.0);
    
    initState = 104;
}

list notReady() {
    list waiting; integer loop;
    for (loop = 0; loop < llGetListLength(knownScripts); loop++) {
        string script = llList2String(knownScripts, loop);
        if (llListFindList(readyScripts, [ script ]) == -1 && llGetScriptState(script)) waiting += script;
    }
    return waiting;
}

#ifdef SIM_FRIENDLY
wakeMenu() {
    #ifdef DEVELOPER_MODE
    llOwnerSay("Waking menu scripts");
    #endif
    llSetScriptState("MenuHandler", 1);
    llSetScriptState("Transform", 1);
    llSetScriptState("Dress", 1);
    llSetScriptState("Taker", 1);
}

sleepMenu() {
    #ifdef DEVELOPER_MODE
    llOwnerSay("Sleeping menu scripts");
    #endif
    llSetScriptState("MenuHandler", 0);
    llSetScriptState("Transform", 0);
    llSetScriptState("Dress", 0);
    llSetScriptState("Taker", 0);
}
#endif

do_Restart() {
    integer loop; string me = llGetScriptName();
    reset = 0;
    
    #ifdef SIM_FRIENDLY
    wakeMenu();
    #endif
    
    llOwnerSay("Resetting scripts");
        
    for (loop = 0; loop < llGetInventoryNumber(INVENTORY_SCRIPT); loop++) {
        string script = llGetInventoryName(INVENTORY_SCRIPT, loop);
        knownScripts += script;
        if (script != me) {
            llResetOtherScript(script);
        }
    }
    
    if (isAttached) {
        string name = dollName;
        integer space = llSubStringIndex(name, " ");
        if (space != -1) name = llGetSubString(name, 0, space -1);
        llSetObjectName("Dolly " + name + "'s Key");
    }
    
    reset = 0;
    
    llSetTimerEvent(0.1);
}

default {
    link_message(integer source, integer code, string data, key id) {
        list split = llParseStringKeepNulls(data, [ "|" ], []);
        
        scaleMem();

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
        else if (code == 104) {
            if (llListFindList(readyScripts, [ llList2String(split,0) ]) == -1) {
                readyScripts += llList2String(split,0);
                //debugSay(5, "State 104\nReady: " + llList2CSV(readyScripts) + "\nNot Ready: " + llList2CSV(notReady()));
                if (notReady() == []) {
                    initConfiguration();
                }
            }
            else debugSay(1, "WARNING: Script " + llList2String(split,0) + " is sending excessive signal 104");
        }
        else if (code == 105) {
            if (llListFindList(readyScripts, [ llList2String(split,0) ]) == -1) {
                readyScripts += llList2String(split,0);
                //debugSay(5, "State 105\nReady: " + llList2CSV(readyScripts) + "\nNot Ready: " + llList2CSV(notReady()));
                if (notReady() == []) initializationCompleted();
            }
            else debugSay(1, "WARNING: Script " + llList2String(split,0) + " is sending excessive signal 105");
        }
        else if (code == 135) {
            if (llList2String(split, 0) == llGetScriptName()) return;
            float delay = llList2Float(split, 1);
            memReport(delay);
        }
        else if (code == 300) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);
            
            //debugSay(5, "From " + script + ": " + name + "=" + value);
            
            if (name == "timeLeftOnKey") {
                timeLeftOnKey = (float)value;
            }
            else if (name == "ncPrefsLoadedUUID")    ncPrefsLoadedUUID = (key)value;
            else if (name == "offlineMode")                offlineMode = (integer)value;
            else if (name == "databaseOnline")          databaseOnline = (integer)value;
            else if (name == "autoTP")                          autoTP = (integer)value;
            else if (name == "barefeet")                      barefeet = value;
            else if (name == "busyIsAway")                  busyIsAway = (integer)value;
            else if (name == "canAFK")                          canAFK = (integer)value;
            else if (name == "canDress")                      canDress = (integer)value;
            else if (name == "canFly")                          canFly = (integer)value;
            else if (name == "canSit")                          canSit = (integer)value;
            else if (name == "canStand")                      canStand = (integer)value;
            else if (name == "detachable")                  detachable = (integer)value;
            else if (name == "keyLimit")                      keyLimit = (float)value;
            else if (name == "helpless")                      helpless = (integer)value;
            else if (name == "pleasureDoll")              pleasureDoll = (integer)value;
            else if (name == "quiet")                            quiet = (integer)value;
            else if (name == "lowScriptMode")            lowScriptMode = (integer)value;
            else if (name == "userBaseRLVcmd")          userBaseRLVcmd = value;
            else if (name == "userCollapseRLVcmd")  userCollapseRLVcmd = value;
            else if (name == "windTimes")                    windTimes = llList2List(split, 2, -1);
            else if (name == "dollType")                      dollType = value;
            else if (name == "MistressList") {
                list newList = llListSort(llList2List(split, 2, -1), 2, 1);
                if (MistressList != newList) MistressList = newList;
            }
            else if (name == "blacklist") {
                list newList = llListSort(llList2List(split, 2, -1), 2, 1);
                if (blacklist != newList) blacklist = newList;
            }
/*                 if (name == "afk")                           afk = (integer)value;
            else if (name == "autoTP")                       autoTP = (integer)value;
            else if (name == "canAFK")                       canAFK = (integer)value;
            else if (name == "canCarry")                   canCarry = (integer)value;
            else if (name == "canDress")                   canDress = (integer)value;
            else if (name == "canFly")                       canFly = (integer)value;
            else if (name == "canSit")                       canSit = (integer)value;
            else if (name == "canStand")                   canStand = (integer)value;
            else if (name == "isCollapsed")               collapsed = (integer)value;
            else if (name == "isConfigured")             configured = (integer)value;
            else if (name == "detachable")               detachable = (integer)value;
            else if (name == "helpless")                   helpless = (integer)value;
            else if (name == "pleasureDoll")           pleasureDoll = (integer)value;
            else if (name == "isTransformingKey")   transformingKey = (integer)value;
            else if (name == "visible")                     visible = (integer)value;
            else if (name == "quiet")                         quiet = (integer)value;
            else if (name == "RLVok")                         RLVok = (integer)value;
            else if (name == "signOn")                       signOn = (integer)value;
            else if (name == "takeoverAllowed")     takeoverAllowed = (integer)value;*/
        }
        
        else if (code == 305) {
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llList2List(split, 2, -1);
            
            if (cmd == "addRemBlacklist") {
                string uuid = llList2String(split, 0);
                string name = llList2String(split, 1);
                integer index = llListFindList(blacklist, [ uuid ]);
                
                if (index == -1) {
                    llOwnerSay("Adding " + name + " to blacklist");
                    lmSendConfig("blacklist", llDumpList2String((blacklist = llListSort(blacklist + [ uuid, name ], 2, 1)), "|"));
                }
                else {
                    llOwnerSay("Removing " + name + " from blacklist");
                    lmSendConfig("blacklist", llDumpList2String((blacklist = llDeleteSubList(blacklist, index, index + 1)), "|"));
                }
            }
            else if (cmd == "addMistress") {
                string uuid = llList2String(split, 0);
                string name = llList2String(split, 1);
                
                if (llListFindList(MistressList, [ uuid ]) == -1) {
                    lmSendConfig("MistressList", llDumpList2String((MistressList = llListSort(MistressList + [ uuid, name ], 2, 1)), "|"));
                }
            }
            #ifdef SIM_FRIENDLY
            else if (cmd == "setAFK") afk = llList2Integer(split, 2);
            #endif
        }
        
        else if (code == 350) {
            RLVok = llList2Integer(split, 0);
            rlvWait = 0;
            
            llSleep(2.0);
            memReport(0.0);
            
            string msg = dollName + " has logged in with";
            if (!RLVok) msg += "out";
            msg += " RLV at " + wwGetSLUrl();
            llMessageLinked(LINK_THIS, 15, msg, NULL_KEY);
            
            llSetTimerEvent(0.0);
        }
        else if (code == 500) {
            string selection = llList2String(split, 0);
            
            if (selection == "Reset Scripts" && id == dollID) {
                if (RLVok)
                    llOwnerSay("Unable to reset scripts while running with RLV enabled, please relog without RLV disabled or " +
                                "you can use login a Linden Lab viewer to perform a script reset.");
                else if (RLVok == -1 && (llGetTime() < 180.0))
                    llOwnerSay("Key is currently still checking your RLV status please wait until the check completes and then try again.");
                else llResetScript();
            }
            nextLagCheck = llGetTime() + SEC_TO_MIN;
        }
        else if (code == 999 && reset == 1) {
            llResetScript();
        }
    }
    
    state_entry() {
        rlvWait = 1;
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);
        
        llTargetOmega(<0,0,0>,0,0);
        llSetObjectName(PACKAGE_STRING);
        
        if (lastAttachPoint = llGetAttached()) lastAttachAvatar = llGetOwner();
        else lastAttachAvatar = NULL_KEY;
        
        reset = 2;
        if (isAttached) llRequestPermissions(dollID, PERMISSION_MASK);
        else do_Restart();
    }
    
    //----------------------------------------
    // TOUCHED
    //----------------------------------------
    touch_start(integer num) {
        if (isAttached) llRequestPermissions(dollID, PERMISSION_MASK);
        integer i;
        #ifdef SIM_FRIENDLY
        if (!llGetScriptState("MenuHandler")) wakeMenu();
        nextLagCheck = llGetTime() + SEC_TO_MIN;
        #endif
    }
    
    on_rez(integer start) {
        databaseOnline = 0;
        if (isAttached) llRequestPermissions(dollID, PERMISSION_MASK);
        rlvWait = 1;
        RLVok = -1;
        if (startup != 0) llResetScript();
        readyScripts = [];
        startup = 2;
        #ifdef SIM_FRIENDLY
        wakeMenu();
        #endif
        
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
        
        if (initState == 104) lmInitState(++initState);
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
            
            string name = dollName;
            integer space = llSubStringIndex(name, " ");
            if (space != -1) name = llGetSubString(name, 0, space -1);
            llSetObjectName("Dolly " + name + "'s Key");
            
            if (llGetPermissionsKey() == llGetOwner() && (llGetPermissions() & PERMISSION_TAKE_CONTROLS) != 0) llTakeControls(CONTROL_MOVE, 1, 1);
            else llRequestPermissions(dollID, PERMISSION_MASK);
            
            if (!isAttached) {
                llOwnerSay("Your key stubbornly refuses to attach itself, and you " +
                           "belatedly realize that it must be attached to your spine.");
                llOwnerSay("@clear,detachme=force");
                
                llSleep(2.0);
                llDetachFromAvatar();
            }
            if (lastAttachAvatar == NULL_KEY) newAttach = 1;
        }
        
        lastAttachPoint = llGetAttached();
        lastAttachAvatar = id;
    }
    
    dataserver(key query_id, string data) {
        if (query_id == ncPrefsKey) {
            if (data == EOF) {
                doneConfiguration(1);
            }
            else {
                if (data != "" && llGetSubString(data, 0, 0) != "#") {
                    integer index = llSubStringIndex(data, "=");
                    string name = llGetSubString(data, 0, index - 1);
                    string value = llGetSubString(data, index + 1, -1);
                    name = llStringTrim(llToLower(name), STRING_TRIM);
                    value = llStringTrim(value, STRING_TRIM);
                    list split = llParseStringKeepNulls(value, [ "|" ], []);
                    processConfiguration(name, split);
                }
                ncPrefsKey = llGetNotecardLine(NOTECARD_PREFERENCES, ++ncLine);
            }
        }
        else {
            integer index = llListFindList(blacklist, [ query_id ]);
            if (index != -1) {
                lmSendConfig("blacklist", llDumpList2String((blacklist = llListReplaceList(blacklist, [ data ], index, index)), "|"));
            }
            else {
                index = llListFindList(MistressList, [ query_id ]);
                if (index != -1) {
                    lmSendConfig("MistressList", llDumpList2String((MistressList = llListReplaceList(MistressList, [ data ], index, index)), "|"));
                }
            }
        }
    }
    
    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            if (llGetInventoryType(NOTECARD_PREFERENCES) != INVENTORY_NOTECARD) {
                key ncKey = llGetInventoryKey(NOTECARD_PREFERENCES);
                if (ncPrefsLoadedUUID != NULL_KEY && ncKey != NULL_KEY && ncKey != ncPrefsLoadedUUID) {
                    wakeMenu();
                    integer channel = 0x80000000 | (integer)("0x" + llGetSubString((string)llGetLinkKey(2), -8, -1));
                    
                    nextLagCheck = llGetTime() + SEC_TO_MIN;
                    llDialog(llGetOwner(), "Detected a change in your Preferences notecard, would you like to load the new settings?\n\n" +
                      "WARNING: All current data will be lost!", [ "Reload Config", "Keep Settings" ], channel);
                    lmInternalCommand("dialogListen", "", scriptkey);
                }
            }
        }
        if (change & CHANGED_OWNER) {
            llOwnerSay("Deleting old preferences notecard on owner change.");
            llOwnerSay("Look at PreferencesExample to see how to make yours.");
            while (llGetInventoryType(NOTECARD_PREFERENCES) != INVENTORY_NONE) llRemoveInventory(NOTECARD_PREFERENCES);
            llResetScript();
        }
    }
    
    timer() {
        llSetTimerEvent(0.0);
        
        if (startup == 0) {
            llOwnerSay("Starting initialization");
            lowScriptMode = 0;
            startup = 1;
            if (initState == 103) lmInitState(++initState);
            llSetTimerEvent(90.0 - llGetTime());
        }
        else if (startup != 3 && RLVok != -1 && llGetTime() >= 90.0) {
            lowScriptMode = 0;
            sendMsg(dollID, "Startup failure detected one or more scripts may have crashed, resetting");

            #ifdef DEVELOPER_MODE
            sendMsg(dollID, "The following scripts did not report: " + llList2CSV(notReady()));
            #endif
            
            llResetScript();
        }
    }
    
    run_time_permissions(integer perm) {
        if (perm & PERMISSION_TAKE_CONTROLS) {
            llTakeControls(CONTROL_MOVE, 1, 1);
            if (reset == 2) do_Restart();
        }
    }
}

