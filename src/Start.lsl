//========================================
// Start.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 25 February 2014

#include "include/Json.lsl"
#include "include/GlobalDefines.lsl"
#define sendMsg(id,msg) lmSendToAgent(msg, id);

#define RUNNING 1
#define NOT_RUNNING 0
#define YES 1
#define NO 0
#define NOT_FOUND -1
#define UNSET -1
// End of configuration token
#define EOC "<END-OF-CONFIGURATION>"
// Next read line token
#define NLS "<NEXT-READ-LINE>"
#define NLR "+"
#define NLE "</NEXT-READ-LINE>"

#define cdRunScript(a) llSetScriptState(a, RUNNING);
#define cdStopScript(a) llSetScriptState(a, NOT_RUNNING);
#define cdResetSelf() llResetScript()
#define cdResetScript(a) llResetOtherScript(a) 

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

string objName;
string dollName;
string dollyName;
string appearanceData;

#define APPEARANCE_NC "DataAppearance"
#define NC_ATTACHLIST "DataAttachments"
key ncPrefsKey;
key ncPrefsLoadedUUID = NULL_KEY;
key ncIntroKey;
key ncResetAttach;
key ncRequestAppearance;

float timeLeftOnKey = UNSET;
integer ncLine;

float ncStart;
integer lastAttachPoint;
key lastAttachAvatar;

list MistressList;
list blacklist;
list recentDilation;
list windTimes;
list coreScripts = CORE_SCRIPTS;
list nameRequests;

integer quiet = NO;
integer newAttach = YES;
integer autoTP = NO;
integer canFly = YES;
integer canSit = YES;
integer canStand = YES;
integer canDress = YES;
integer detachable = YES;
integer busyIsAway = NO;
integer offlineMode = NO;
integer visible = YES;
integer primGlow = YES;
integer primLight = UNSET;
integer prefsReread = NO;

vector gemColour;

string barefeet;
string dollType;
string attachName;
string saveAttachment = "{\"chest\":[\"<0.000000, 0.184040, -0.279770>\",\"<1.000000, 0.000000, 0.000000, 0.000000>\"],\"spine\":[\"<0.000000, -0.200000, 0.000000>\",\"<0.000000, 0.000000, 0.000000, 1.000000>\"]}";
string userAfkRLVcmd;
string userBaseRLVcmd;
string userCollapseRLVcmd;
string userPoseRLVcmd;
string dollGender = "Female";
string pronounHerDoll = "Her";
string pronounSheDoll = "She";
//string nameOverride;
integer startup;
integer initState = 104;
integer introLine;
integer introLines;
integer reset;
integer rlvWait;
integer RLVok = UNSET;
integer databaseFinished;
integer databaseOnline;

float keyLimit;

#ifdef SIM_FRIENDLY
integer afk;
integer lowScriptMode;
#endif

doVisibility() {
    if (llGetInventoryType(APPEARANCE_NC) == INVENTORY_NOTECARD) {
        if (!visible || !primGlow) {
            llSetLinkPrimitiveParamsFast(LINK_SET, [ PRIM_GLOW, ALL_SIDES, 0.0 ]);
        }
        else {
            integer i; integer type;
            list types = [ "Light", 23, "Glow", 25 ];
            for (type = 0; type < (llGetListLength(types)/2); type++) {
                for (i = 1; i < llGetNumberOfPrims(); i++) {
                    string name = llGetLinkName(i); string typeName = llList2String(types, type * 2);
                    if (cdGetElementType(appearanceData,([name,typeName])) != JSON_INVALID) {
                        integer j;
                        while(cdGetElementType(appearanceData,([name,typeName,j])) != JSON_INVALID) {
                            list params = llJson2List(cdGetValue(appearanceData,([name,typeName,j++])));
                            if (typeName == "Light") {
                                if (primLight == UNSET) primLight = llList2Integer(params,0);
                                vector colour = gemColour;
                                if (colour == ZERO_VECTOR) colour = (vector)llList2String(llGetLinkPrimitiveParams(i,[PRIM_DESC]),0);
                                if (colour == ZERO_VECTOR) colour = (vector)llList2String(params,1);
                                params = llListReplaceList(params, [primLight,colour], 0, 1);
                            }
                            llSetLinkPrimitiveParamsFast(i, llList2List(types, type * 2 + 1, type * 2 + 1) + params);
                        }
                    }
                }
            }
        }
    }
}

//---------------------------------------
// Configuration Functions
//---------------------------------------
// This code assumes a human-generated config file
processConfiguration(string name, string value) {
    //----------------------------------------
    // Assign values to program variables

         if (value == "yes" || value == "on")  value = "1";
    else if (value == "no"  || value == "off") value = "0";

    integer i; integer error;
    list firstWord = [ "barefeet path", "helpless dolly", "quiet key" ];
    list capSubsiquent = [ "busy is away", "can afk", "can fly", "can pose", "can sit", "can stand", "can wear", "detachable", "doll type", "pleasure doll", "pose silence" ];
    list rlv = [ "afk rlv", "base rlv ", "collapse rlv", "pose rlv" ];

    if ( ( i = llListFindList(firstWord, [name]) ) != -1) {
        lmSendConfig(llDeleteSubString(name, llSubStringIndex(name," "), -1), value);
    }
    else if ( ( i = llListFindList(rlv, [name]) ) != -1) {
        name = "user" + name = llToUpper(llGetSubString(name, 0, 0)) + llGetSubString(name, 1, -5) + "RLVcmd";
        lmSendConfig(name, value);
    }
    else if ( ( i = llListFindList(capSubsiquent, [name]) ) != -1) {
        integer j;
        while( ( j = llSubStringIndex(name, " ") ) != -1) {
            name = llInsertString(llDeleteSubString(name, j, j + 1), j, llToUpper(llGetSubString(name, j + 1, j + 1)));
            llOwnerSay(name);
        }
        lmSendConfig(name, value);
    }
    else if (name == "initial time") {
        if (!prefsReread) lmSendConfig("timeLeftOnKey", (string)((float)value * SEC_TO_MIN));
    }
    else if (llGetSubString(name, 0, 8) == "wind time") {
        lmInternalCommand("setWindTimes", value, NULL_KEY);
    }
    else if (name == "max time") {
        lmSendConfig("keyLimit", (string)((float)value * SEC_TO_MIN));
    }
    else if (name == "doll gender") {
        setGender(value);
    }
    else if (name == "auto tp")           { lmSendConfig("autoTP",             value); }
    else if (name == "outfitable")        { lmSendConfig("canDress",           value); }

     else if (name == "blacklist") {
        if (llListFindList(blacklist, [ value ]) == NOT_FOUND) {
            nameRequests = llListSort(nameRequests + [ llGetUnixTime(), llRequestAgentData((key)value, DATA_NAME) ], 3, 1);
        }
     }
     else if (name == "controller") {
        if (llListFindList(MistressList, [ value ]) == NOT_FOUND) {
            nameRequests = llListSort(nameRequests + [ llGetUnixTime(), llRequestAgentData((key)value, DATA_NAME) ], 3, 1);
        }
    } 
    else if (name == "blacklist name") {
        lmInternalCommand("getBlacklistName", value, NULL_KEY);
    }
    else if (name == "controller name") {
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
        if (llGetSubString(name, -3, -1) == "rlv") {
            
            if (llListFindList(llJson2List("[\"base\",\"collapse\",\"pose\",\"afk\"]"),[name]) != -1) {
                lmSendConfig("user" + name + "RLVcmd", value);
                return;
            }
        }
        llOwnerSay("Unknown configuration value: " + name + " on line " + (string)(ncLine + 1));
    }
}

setGender(string gender) {
    if (gender == "male") {
        lmSendConfig("dollGender",     (dollGender     = "Male"));
        lmSendConfig("pronounHerDoll", (pronounHerDoll = "His"));
        lmSendConfig("pronounSheDoll", (pronounSheDoll = "He"));
        return;
    } else {
        if (gender == "sissy") {
            lmSendConfig("dollGender", (dollGender = "Sissy"));
        } else {
            lmSendConfig("dollGender", (dollGender = "Female"));
        }

        lmSendConfig("pronounHerDoll", (pronounHerDoll = "Her"));
        lmSendConfig("pronounSheDoll", (pronounSheDoll = "She"));
    }
}

initConfiguration() {
    // Check to see if the file exists and is a notecard
    if (llGetInventoryType(NOTECARD_PREFERENCES) == INVENTORY_NOTECARD) {
        if ((databaseOnline && (offlineMode || (ncPrefsLoadedUUID == NULL_KEY) || (ncPrefsLoadedUUID != llGetInventoryKey(NOTECARD_PREFERENCES)))) || prefsReread) {
            sendMsg(dollID, "Loading preferences notecard");
            ncStart = llGetTime();

            // Start reading from first line (which is 0)
            ncPrefsKey = llGetNotecardLine(NOTECARD_PREFERENCES, (ncLine = 0));
        }
        else {
            debugSay(7, "DEBUG", "Skipping preferences notecard as it is unchanged");
            doneConfiguration(0);
        }
    } else {
        // File missing - report for debugging only
        debugSay(1, "DEBUG", "No configuration found (" + NOTECARD_PREFERENCES + ")");
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
    if (reset) {
        llSleep(7.5);
        cdResetSelf();
    }
    reset = 0;
    lmInitState(102);
    lmInitState(105);
    startup = 2;
    
    initializationCompleted();
}

initializationCompleted() {
    if (newAttach && !quiet && cdAttached())
        llSay(0, llGetDisplayName(llGetOwner()) + " is now a dolly - anyone may play with their Key.");

    initTimer = llGetTime() * 1000;
    

    if (dollyName == "") {
        string name = dollName;
        integer space = llSubStringIndex(name, " ");

        if (space != NOT_FOUND) name = llGetSubString(name, 0, space -1);

        //llOwnerSay("INIT1: dollyName = " + dollyName + " (send to 300)");
        lmSendConfig("dollyName", (dollyName = "Dolly " + name));
    }
    //llOwnerSay("INIT1: dollyName = " + dollyName + " (setting)");
    if (cdAttached()) llSetObjectName(dollyName + "'s Key");
    string msg = "Initialization completed";
#ifdef DEVELOPER_MODE
    msg += " in " + formatFloat(initTimer, 2) + "ms";
#endif
    msg += " key ready";

    sendMsg(dollID, msg);

    startup = 0;
    
    lmInitState(110);

    if (llGetInventoryType(APPEARANCE_NC) == INVENTORY_NOTECARD) {
        ncLine = 0;
        ncRequestAppearance = llGetNotecardLine(APPEARANCE_NC, ncLine++);
    }
    llSetTimerEvent(1.0);
}

#ifdef SIM_FRIENDLY
wakeMenu() {
#ifdef DEVELOPER_MODE
    llOwnerSay("Waking menu scripts");
#endif
    cdRunScript("MenuHandler.lsl");
    cdRunScript("Transform.lsl");
    cdRunScript("Dress.lsl");
}

sleepMenu() {
#ifdef DEVELOPER_MODE
    llOwnerSay("Sleeping menu scripts");
#endif
    cdStopScript("MenuHandler.lsl");
    cdStopScript("Transform.lsl");
    cdStopScript("Dress.lsl");
}
#endif

do_Restart() {
    integer i;

    llOwnerSay("Resetting scripts");
    
    // NEW RESET POLICY
    // In Short: Keep to our own.
    // Policy: The key must only reset our own scrips and which it knows about, and thus knows that such an operation is safe.
    // Rationale: Resetting unknown scripts we have at best limited knowledge of their purpose, functions or data handling. We
    // may trigger adverse effects including data loss or otherwise disrupting the operation of those scripts in a negative way.
    // Action: Do not reset, send a link message to the link set any other script can hook into and take their own actions.

    for (i = 0; i < llGetListLength(coreScripts); i++) {
        string script = cdListElement(coreScripts, i);
        if (script != cdMyScriptName()) {
            cdRunScript(script);
            cdResetScript(script);
        }
    }

    reset = 0;

    ncResetAttach = llGetNotecardLine(NC_ATTACHLIST, cdAttached() - 1);
}

default {
    link_message(integer source, integer code, string data, key id) {
        cdReadLinkHeader();

        scaleMem();

        if (code == 102) {
            if (script != "ServiceReceiver.lsl") return;
            databaseFinished = 1;
            initConfiguration();
        }
        else if ((code == 104) || (code == 105)) {

        }
        else if (code == 135) {
            if (script== cdMyScriptName()) return;
            float delay = llList2Float(split, 0);
            memReport(cdMyScriptName(),delay);
        }
        
        cdConfigReport();
        
        else if (code == 300) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);
            split = llDeleteSubList(split,0,0);

            //debugXay(5, "From " + script + ": " + name + "=" + value);

                 if (name == "timeLeftOnKey")            timeLeftOnKey = (float)value;
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
            else if (name == "collapsed")                    collapsed = (integer)value;
            else if (name == "afk")                                afk = (integer)value;
            else if (name == "keyAnimation")              keyAnimation = value;
            else if (name == "detachable")                  detachable = (integer)value;
            else if (name == "keyLimit")                      keyLimit = (float)value;
            else if (name == "helpless")                      helpless = (integer)value;
            else if (name == "pleasureDoll")              pleasureDoll = (integer)value;
            else if (name == "quiet")                            quiet = (integer)value;
            else if (name == "lowScriptMode")            lowScriptMode = (integer)value;
            else if (name == "dialogChannel")            dialogChannel = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                  debugLevel = (integer)value;
#endif
            else if (name == "userBaseRLVcmd")          userBaseRLVcmd = value;
            else if (name == "userCollapseRLVcmd")  userCollapseRLVcmd = value;
            else if (name == "userPoseRLVcmd")          userPoseRLVcmd = value;
            else if (name == "userAfkRLVcmd")            userAfkRLVcmd = value;
            else if (name == "windTimes")                    windTimes = split;
            else if (name == "dollType")                      dollType = value;
            else if (name == "MistressList")              MistressList = llListSort(split, 2, 1);
            else if (name == "blacklist")                    blacklist = llListSort(split, 2, 1);
            else if (name == "primLight")                    primLight = (integer)value;
            else if (name == "gemColour") {
                gemColour = (vector)value;
                if (configured) doVisibility();
            }

            else if (name == "primGlow") {
                primGlow = (integer)value;
                if (configured) doVisibility();
            }
            else if (name == "isVisible") {
                visible = (integer)value;
                if (configured) doVisibility();
            }

            else if (name == "dollyName") {

                dollyName = value;

                if (dollyName == "") {
                    string name = dollName;
                    integer space = llSubStringIndex(name, " ");

                    if (space != NOT_FOUND) name = llGetSubString(name, 0, space -1);
                    //llOwnerSay("INIT:300: dollyName = " + dollyName + " (send to 300)");

                    lmSendConfig("dollyName", (dollyName = "Dolly " + name));
                }
                //llOwnerSay("INIT:300: dollyName = " + dollyName + " (setting)");
                if (cdAttached()) llSetObjectName(dollyName + "'s Key");
            }
            
            if ((name == "collapsed") && (userCollapseRLVcmd != "")) {
                if (collapsed) lmRunRLVas("UserCollapse", userCollapseRLVcmd);
                else lmRunRLVas("UserCollapse", "clear");
            }
            else if ((name == "afk") && (userAfkRLVcmd != "")) {
                if (collapsed) lmRunRLVas("UserAfk", userAfkRLVcmd);
                else lmRunRLVas("UserAfk", "clear");
            }
            else if ((name == "keyAnimation") && (userPoseRLVcmd != "")) {
                if (!cdNoAnim() && !cdCollapsedAnim()) lmRunRLVas("UserPose", userPoseRLVcmd);
                else lmRunRLVas("UserPose", "clear");
            }
        }

        else if (code == 305) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "addRemBlacklist") {
                string uuid = llList2String(split, 0);
                string name = llList2String(split, 1);

                integer index = llListFindList(blacklist, [ uuid ]);

                if (index == -1) {
                    lmSendToAgentPlusDoll("Adding " + name + " to blacklist", id);
                    if ((llGetListLength(blacklist) % 2) == 1) blacklist = llDeleteSubList(blacklist, 0, 0);
                    blacklist = llListSort(blacklist + [ uuid, name ], 2, 1);
                }
                else {
                    lmSendToAgentPlusDoll("Removing " + name + " from blacklist.", id);
                    if ((llGetListLength(blacklist) % 2) == 1) blacklist = llDeleteSubList(blacklist, 0, 0);
                    blacklist = llDeleteSubList(blacklist, index, ++index);
                    
                }
                
                lmSendConfig("blacklist", llDumpList2String(blacklist,"|") );
            }
            else if ((cmd == "addMistress") || (cmd == "remMistress")) {
                string uuid = llList2String(split, 0);
                string name = llList2String(split, 1);

                integer index = llListFindList(MistressList, [ uuid ]);

                if  ((cmd == "addMistress") && (index == -1)) {
                    lmSendToAgentPlusDoll("Adding " + name + " to controller list.", id);
                    if ((llGetListLength(MistressList) % 2) == 1) MistressList = llDeleteSubList(MistressList, 0, 0);
                    MistressList = llListSort(MistressList + [ uuid, name ], 2, 1);
                }
                else if ((cmd == "remMistress") && cdIsBuiltinController(id)) {
                    lmSendToAgentPlusDoll("Removing " + name + " from controller list.", id);
                    if ((llGetListLength(MistressList) % 2) == 1) MistressList = llDeleteSubList(MistressList, 0, 0);
                    MistressList = llDeleteSubList(MistressList, index, ++index);
                    
                    list exceptions = ["tplure","recvchat","recvemote","recvim","sendim","startim"]; integer i;
                    for (i = 0; i < 6; i++) lmRunRLVas("Base",llList2String(exceptions, i) + ":" + uuid + "=rem");
                }
                
                lmSendConfig("MistressList", llDumpList2String(MistressList,"|") );
            }
#ifdef SIM_FRIENDLY
            else if (cmd == "setAFK") afk = llList2Integer(split, 2);
#endif
        }

        else if (code == 350) {
            RLVok = (llList2Integer(split, 0) == 1);
            rlvWait = 0;

            if (!newAttach && cdAttached()) {
                string msg = dollName + " has logged in with";
                if (!RLVok) msg += "out";
                msg += " RLV at " + wwGetSLUrl();
                lmSendToController(msg);
            }

            newAttach = 0;
        }
        else if (code == 500) {
            string selection = llList2String(split, 0);
            string name = llList2String(split, 1);

            if (selection == "Reset Scripts") {
                if (cdIsController(id)) cdResetSelf();
                else if (id == dollID) {
                    if (RLVok == YES)
                        llOwnerSay("Unable to reset scripts while running with RLV enabled, please relog without RLV disabled or " +
                                    "you can use login a Linden Lab viewer to perform a script reset.");
                    else if (RLVok == UNSET && (llGetTime() < 300.0))
                        llOwnerSay("Key is currently still checking your RLV status please wait until the check completes and then try again.");
                    else cdResetSelf();
                }
            }

            nextLagCheck = llGetTime() + SEC_TO_MIN;
        }
//      else if (code == 999 && reset == 1) {
//          llResetScript();
//      }
    }

    state_entry() {
        dollID = llGetOwner();
        llSetObjectName(objName = PACKAGE_NAME + " " + llInsertString(llDeleteSubString(__DATE__,3,5),3,(string)((integer)(llGetSubString(__DATE__,3,5)))));
        dollName = llGetDisplayName(dollID);

        rlvWait = 1;

        reset = 2;
        if (cdAttached()) llRequestPermissions(dollID, PERMISSION_MASK);
        else do_Restart();
    }

    //----------------------------------------
    // TOUCHED
    //----------------------------------------
    touch_start(integer num) {
        if (cdAttached()) llRequestPermissions(dollID, PERMISSION_MASK);
        integer i;
#ifdef SIM_FRIENDLY
        if (!llGetScriptState("MenuHandler.lsl")) wakeMenu();
        nextLagCheck = llGetTime() + SEC_TO_MIN;
#endif
    }

    on_rez(integer start) {
        dollID = llGetOwner();
        if(!cdAttached()) llSetObjectName(objName);
        
        databaseOnline = 0;
        if (cdAttached()) llRequestPermissions(dollID, PERMISSION_MASK);
        RLVok = UNSET;
        startup = 2;
#ifdef SIM_FRIENDLY
        wakeMenu();
#endif

        //llTargetOmega(<0,0,0>,0,0);

        llResetTime();
        string me = cdMyScriptName();
        integer loop; string script;

        sendMsg(dollID, "Reattached, Initializing");

        llSleep(0.5);
        lmInitState(initState = 105);
    }

    attach(key id) {
        if (id == NULL_KEY) {
            if(!cdAttached()) llSetObjectName(objName);
            llMessageLinked(LINK_SET, 106,  cdMyScriptName() + "|" + "detached" + "|" + (string)lastAttachPoint, lastAttachAvatar);
            llOwnerSay("The key is wrenched from your back, and you double over at the unexpected pain as the tendrils are ripped out. You feel an emptiness, as if some beautiful presence has been removed.");
        } else {
            llMessageLinked(LINK_SET, 106, cdMyScriptName() + "|" + "attached" + "|" + (string)llGetAttached(), id);

            if (llGetPermissionsKey() == llGetOwner() && (llGetPermissions() & PERMISSION_TAKE_CONTROLS) != 0) llTakeControls(CONTROL_MOVE, 1, 1);
            else llRequestPermissions(dollID, PERMISSION_MASK);
            
            ncResetAttach = llGetNotecardLine(NC_ATTACHLIST, cdAttached() - 1);

            if (lastAttachAvatar == NULL_KEY) newAttach = 1;
        }

        lastAttachPoint = cdAttached();
        lastAttachAvatar = id;
    }

    dataserver(key query_id, string data) {
        integer i;
        if (query_id == ncPrefsKey) {
            if (ncLine == 0) {
                if (configured) prefsReread = 1;
                // These should be reset at the start of reading so that we do not
                // concentrate one copy ad infinitum until we run out of mem.
                lmSendConfig("userAfkRLVcmd"      , ( userAfkRLVcmd      = "" ) );
                lmSendConfig("userBaseRLVcmd"     , ( userBaseRLVcmd     = "" ) );
                lmSendConfig("userCollapseRLVcmd" , ( userCollapseRLVcmd = "" ) );
                lmSendConfig("userPoseRLVcmd"     , ( userPoseRLVcmd     = "" ) );
            }
            
            if ((data == EOF) || (data == EOC)) {
                if (prefsReread) {
                    llOwnerSay("Preferences reread restarting in 20 seconds.");
                    lmInternalCommand("getTimeUpdates","",NULL_KEY);
                    llSleep(20.0);
                    llOwnerSay("@clear");
                    cdResetSelf();
                }
            }
            else {
                // Fast tidy one line comment stripping, if no comment returns full line
                data = llGetSubString(data, 0, llSubStringIndex(data, "#") & 0xFF);
                data = llGetSubString(data, 0, llSubStringIndex(data,"//") & 0xFF);
                // Trim any whitespace
                data = llStringTrim(data,STRING_TRIM);
                
                if (data != "") { // Skip if blank else line holds (potentially) useful data, we process
                    if ( ( i = llSubStringIndex(data, "=") ) != -1) {
                        string name     =      llStringTrim( llGetSubString(data, 0, i - 1), STRING_TRIM );
                        string value    =      llStringTrim( llDeleteSubString(data, 0, i),  STRING_TRIM );
                        debugSay(3, "DEBUG-PREFS", "Line " + (string)(ncLine+1) + " parsed as " + name + "=" + value);
                        processConfiguration(name, value);
                    }
                }
                ncLine++;
            }

            debugSay(3, "DEBUG-PREFS", ": Mext line: " + (string)(ncLine + 1));
            ncPrefsKey = llGetNotecardLine(NOTECARD_PREFERENCES, ncLine);
        }
        else if (query_id == ncResetAttach) {
            data = llStringTrim(data,STRING_TRIM);
            if (cdAttached()) llSetPrimitiveParams([PRIM_POS_LOCAL, (vector)cdGetValue(saveAttachment,([data,0])), PRIM_ROT_LOCAL, (rotation)cdGetValue(saveAttachment,([data,1]))]);
            attachName = data;
            
            if (initState == 104) {
                llOwnerSay("Starting initialization");
                startup = 1;
                lmInitState(initState++);
            }
        }
        else if (query_id == ncRequestAppearance) {
            if (data == EOF) {
                doVisibility();
                configured = 1;
                ncRequestAppearance = NULL_KEY;
            }
            else {
                data = llStringTrim(data,STRING_TRIM);
                string find = "\"ALL\"";
                while ( ( i = llSubStringIndex(data, find) ) != -1) {
                    data = llInsertString(llDeleteSubString(data, i, i + llStringLength(find) - 1), i, "-1");
                }
                appearanceData += data;
                ncRequestAppearance = llGetNotecardLine(APPEARANCE_NC, ncLine++);
            }
        }
        else if ( ( i = llListFindList(nameRequests, [ query_id ]) ) != -1) {
            string name = llList2String(nameRequests, --i);
            string uuid = data;
            nameRequests = llDeleteSubList(nameRequests, i-1, ++i);
            llOwnerSay(llList2CSV(nameRequests));
        }
    }

    changed(integer change) {
        // No longer needed with no transfers keys it would only get in the way of us including a default.
        /*if (change & CHANGED_OWNER) {
            if (llGetInventoryType(NOTECARD_PREFERENCES) != INVENTORY_NONE) {
                llOwnerSay("Deleting old preferences notecard on owner change.");
                llOwnerSay("Look at PreferencesExample to see how to make yours.");
                llRemoveInventory(NOTECARD_PREFERENCES);
            }

            llSleep(5.0);

            cdResetSelf();
        }*/
        if (change & CHANGED_INVENTORY) {
            if (llGetInventoryType(NOTECARD_PREFERENCES) == INVENTORY_NOTECARD) {
                key ncKey = llGetInventoryKey(NOTECARD_PREFERENCES);
                if (ncPrefsLoadedUUID != NULL_KEY && ncKey != NULL_KEY && ncKey != ncPrefsLoadedUUID) {
                    prefsReread = YES;
                    reset = 1;

                    sendMsg(dollID, "Loading preferences notecard");
                    ncStart = llGetTime();

                    // Start reading from first line (which is 0)
                    ncPrefsKey = llGetNotecardLine(NOTECARD_PREFERENCES, ncLine = 0);

                    return;
                }
            }
            else {
                llOwnerSay("Inventory modified restarting in 20 seconds.");
                lmInternalCommand("getTimeUpdates","",NULL_KEY);
                llSleep(20.0);
                llOwnerSay("@clear");
                cdResetSelf();
            }
        }
    }

    timer() {
        float t = llGetTime();
        if (t >= 300.0) llSetTimerEvent(6-.0);
        else llSetTimerEvent(15.0);

        
        if (startup != 0) {
            integer i; integer n = llGetInventoryNumber(10);
            for (i = 0; i < n; i++) {
                string script = llGetInventoryName(10, i);

                if (!llGetScriptState(script)) {
                    if (llListFindList(coreScripts, [script]) != -1) {
                        // Core key script appears to have suffered a fatal error try restarting
                        float delay = 30.0;
#ifdef DEVELOPER_MODE
                        delay = delay * 6.0; // Increase delay for automatic restarts by a factor of 6;
                                             // this prevents rapidly looping in the event of a developer
                                             // accidently saving a script that fails to compile.
#endif

                        llSleep(delay);

                        cdRunScript(script);
                        cdResetSelf();
                    }
                }
            }
        }
        else {
            if (!cdAttached() || (attachName == "")) return;
            saveAttachment = cdSetValue(saveAttachment,([attachName,0]),(string)llGetLocalPos());
            saveAttachment = cdSetValue(saveAttachment,([attachName,1]),(string)llGetLocalRot());
        }
    }

    run_time_permissions(integer perm) {
        if (perm & PERMISSION_TAKE_CONTROLS) {
            llTakeControls(CONTROL_MOVE, 1, 1);
            if (reset == 2) do_Restart();
        }
    }
}

