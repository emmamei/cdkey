//========================================
// ChatHandler.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 7 March 2014

#include "include/GlobalDefines.lsl"
#define cdGetFirstChar(a) llGetSubString(a,0,0)
#define NOT_FOUND -1
#define STRING_END -1
#define cdMenuInject(a,b,c) lmMenuReply(a,b,c)

#define TESTING
// FIXME: Depends on a variable s
#define cdCapability(c,p,u) { s += p; if ((c)) { s += " not"; }; s += " " + u + ".\n"; }

key keyHandler              = NULL_KEY;

list windTimes;

float collapseTime          = 0.0;
float currentLimit          = 10800.0;
float wearLockExpire        = 0.0;

string dollGender           = "Female";
string RLVver               = "";
string pronounHerDoll       = "Her";

integer autoAFK             = 1;
integer broadcastOn         = -1873418555;
integer broadcastHandle     = 0;
integer busyIsAway          = 0;
integer chatChannel         = 75;
integer chatHandle          = 0;
#ifdef DEVELOPER_MODE
integer timeReporting       = 0;
integer debugLevel          = DEBUG_LEVEL;
#endif
integer RLVok               = -1;

default
{
    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        dollID = llGetOwner();
        chatHandle = llListen(chatChannel, "", dollID, "");
        broadcastHandle = llListen(broadcastOn, "", "", "");
        
        cdInitializeSeq();
    }
    
    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer source, integer i, string data, key id) {
        
        // Parse link message header information
        list split        =     cdSplitArgs(data);
        string script     =     cdListElement(split, 0);
        integer remoteSeq =     (i & 0xFFFF0000) >> 16;
        integer optHeader =     (i & 0x00000C00) >> 10;
        integer code      =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        if (code == 135) {
            float delay = llList2Float(split, 0);
            scaleMem();
            memReport(cdMyScriptName(),delay);
        }
        
        cdConfigReport();

        else if (code == 300) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);
            split = llDeleteSubList(split, 0, 0);

                 if (name == "afk")                               afk = (integer)value;
            else if (name == "autoAFK")                       autoAFK = (integer)value;
            else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "canAFK")                         canAFK = (integer)value;
            else if (name == "canCarry")                     canCarry = (integer)value;
            else if (name == "canDress")                     canDress = (integer)value;
            else if (name == "canPose")                       canPose = (integer)value;
            else if (name == "canWear")                       canWear = (integer)value;
            else if (name == "poseSilence")               poseSilence = (integer)value;
            else if (name == "canFly")                         canFly = (integer)value;
            else if (name == "canSit")                         canSit = (integer)value;
            else if (name == "canStand")                     canStand = (integer)value;
            else if (name == "canRepeat")                   canRepeat = (integer)value;
            else if (name == "configured")                 configured = (integer)value;
            else if (name == "detachable")                 detachable = (integer)value;
            else if (name == "helpless")                     helpless = (integer)value;
            else if (name == "pleasureDoll")             pleasureDoll = (integer)value;
            else if (name == "isVisible")                     visible = (integer)value;
            else if (name == "busyIsAway")                 busyIsAway = (integer)value;
            else if (name == "quiet")                           quiet = (integer)value;
            else if (name == "offlineMode")               offlineMode = (integer)value;
            else if (name == "wearLockExpire")         wearLockExpire = (float)value;
            else if (name == "windRate")                     windRate = (float)value;
            else if (name == "displayWindRate")       displayWindRate = (float)value;
            else if (name == "keyLimit")                     keyLimit = (float)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
            else if (name == "collapseTime")             collapseTime = (float)value;
            else if (name == "pronounHerDoll")         pronounHerDoll = value;
            else if (name == "keyAnimation")             keyAnimation = value;
            else if (name == "dollType")                     dollType = value;
            else if (name == "dollGender")                 dollGender = value;
            else if (name == "poserID")                       poserID = (key)value;
            else if (name == "poserName")                   poserName = value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                 debugLevel = (integer)value;
            else if (name == "timeReporting")           timeReporting = (integer)value;
#endif
            else if (name == "blacklist")                   blacklist = llListSort(split, 2, 1);
            else if (name == "MistressList")             MistressList = llListSort(split, 2, 1);
            else if (name == "windTimes")                   windTimes = llJson2List(value);
            else if (name == "chatChannel") {
                chatChannel = (integer)value;
                dollID = llGetOwner();
                llListenRemove(chatHandle);
                chatHandle = llListen(chatChannel, "", dollID, "");
            }
            else if ((name == "timeLeftOnKey") || (name == "collapsed")) {
                if (name == "timeLeftOnKey")            timeLeftOnKey = llGetTime() + (float)value;
                if (name == "collapsed")                    collapsed = (integer)value;
            }
            else if (name == "keyHandler") {
                keyHandler = (key)value;
            }
            else if (name == "keyLimit") {
                keyLimit = (float)value;
                if (!demoMode) currentLimit = keyLimit;
            }
            else if (name == "demoMode") {
                demoMode = (integer)value;
                if (!demoMode) currentLimit = keyLimit;
                else currentLimit = DEMO_LIMIT;
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
        }
        else if (code == 350) {
            RLVok = llList2Integer(split, 0);
            RLVver = llList2String(split, 1);
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {
        // channel = chat channel to listen on
        //    name = filter by prim name
        //     key = filter by avatar key
        //  choice = filter by specific message

        // Text commands
        if (channel == chatChannel) {

            string firstChar = cdGetFirstChar(choice);
            integer choiceType = llGetInventoryType(choice);

            // Is "choice" actually a Pose to activate?
            if (choiceType == INVENTORY_ANIMATION || firstChar == "." || firstChar == "!") {
                if (choiceType != INVENTORY_ANIMATION) choice = llGetSubString(choice, 1, STRING_END);
                if (cdNoAnim() || (!cdCollapsedAnim() && cdSelfPosed())) {
                    lmInternalCommand("setPose", choice, dollID);
                    llOwnerSay("You set your pose to: " + choice);
                }
                else llOwnerSay("You try to regain control over your body in an effort to set your own pose but even that is beyond doll's control.");
                return;
            }

#define PARAMETERS_EXIST (space == NOT_FOUND)

            // Choice is a command, not a pose
            integer space = llSubStringIndex(choice, " ");
            if (PARAMETERS_EXIST) {
                // Normal user commands
                if (choice == "detach") {
                    if (detachable) {
                        lmInternalCommand("detach", "", NULL_KEY);
                    }
                    else {
                        llOwnerSay("Key can't be detached...");
                    }
                }
                else if (choice == "help") {
                    string help = "Commands:
    detach ......... detach key if possible
    stat ........... concise current status
    stats .......... selected statistics and settings
    xstats ......... extended statistics and settings
    poses .......... list all poses
    wind ........... trigger emergency autowind
    demo ........... toggle demo mode
    [posename] ..... activate the named pose if possible
    release ........ stop the current pose if possible
    channel # ...... change channel
    help ........... this list of commands
    dumpstate ...... dump all key state to chat history
    build .......... list build configurations
    listhelp ....... list controller/blacklist commands
    recoveryhelp ... some commands that may rescue a key having issues";
                    llOwnerSay(help);

#ifdef DEVELOPER_MODE
                    llOwnerSay("    devhelp ........ list of developer commands");
                }
                else if (choice == "devhelp") {
                    string help = "Developer Commands:
    timereporting .. periodic reporting of script time usage
    debug # ........ set the debugging message verbosity 0-9
    inject ......... inject an aribtary link message the format is
                     inte#str#key with all but the first optional.";
                     llOwnerSay(help);
#endif
                }

                else if (choice == "listhelp") {
                    string help = "Access Commands:
                     The following commands must be followed by the desired
                     user's username, not display name.
    controller ..... add the username to the controller list
    blacklist ...... blacklist the username if not blacklisted
    unblacklist .... unblacklist the username if they are blacklisted";
                    llOwnerSay(help);
                }
                else if (choice == "recoveryhelp") {
                    string help = "Recovery Commandss:
                     These commnds may help to recover a key without a script
                     reset in some cases.
    wakescript ..... followed by the name of a key script if the named script
                     is not running this will attempt to restart it.
    refreshvars .... try to refresh all variables from the internal db
    httpreload ..... reinitialize the services scripts and fully reload all 
                     data from the off world backup storage (OnlineMode only)
    rlvinit ........ try RLV initialization again";
                    llOwnerSay(help);
                }
                // Do an internal resresh of all local variables from local db
                else if (choice == "refreshvars") {
                    cdLinkMessage(LINK_THIS, 0, 301, "", NULL_KEY);
                }
                // Request verbose full key state dump to chat
                else if (choice == "dumpstate") {
                    cdLinkMessage(LINK_THIS, 0, 302, "", NULL_KEY);
                }
                // Service reinitialization and remote restore
                else if (choice == "httpreload") {
                    if (!offlineMode) {
                        llResetOtherScript("ServiceReceiver");
                        llSleep(1.0);
                        llResetOtherScript("ServiceRequester");
                        llSleep(2.0);
                    }
                }
                // Try a hard RLV reinitialzation
                else if (choice == "rlvinit") {
                    llSetScriptState("StatusRLV", 1);
                    llResetOtherScript("StatusRLV");
                    llResetOtherScript("Avatar");
                    llSleep(1.0);
                    cdLinkMessage(LINK_THIS, 0, 301, "", NULL_KEY);
                    llSleep(5.0);
                    // Inject menu click
                    cdMenuInject("*RLV On*",llGetDisplayName(dollID), id);
                }
                // Demo: short time span
                else if (choice == "demo") {
                    lmSendConfig("demoMode", (string)(demoMode = !demoMode));
                    string mode = "normally";
                    if (demoMode) {
                        mode = "demo mode";
                        if (timeLeftOnKey > DEMO_LIMIT) timeLeftOnKey = DEMO_LIMIT;
                    }
                    llOwnerSay("Key set to run " + mode + ": time limit set to " + (string)llRound(currentLimit / SEC_TO_MIN) + " minutes.");
                }
                else if (choice == "poses") {
                    integer  n = llGetInventoryNumber(INVENTORY_ANIMATION);

                    while(n) {
                        string thisPose = llGetInventoryName(INVENTORY_ANIMATION, --n);

                        if (!(thisPose == ANIMATION_COLLAPSED || llGetSubString(thisPose,1,1) == ".")) {
                            if (keyAnimation == thisPose) {
                                llOwnerSay("\t*\t" + thisPose);
                            }
                            else {
                                llOwnerSay("\t\t" + thisPose);
                            }
                        }
                    }
                }
                else if (choice == "wind") {
                    // inject a fake Menu click
                    cdMenuInject("Wind Emg", dollName, dollID);
                }
                else if (choice == "xstats") {
                    string s = "Extended stats:\n";
                    s += "AFK time factor: " + formatFloat(RATE_AFK, 1) + "x\n";
                    s += "Configured wind times: " + llList2CSV(windTimes) + " mins\n";
                    if (demoMode) {
                        s += "Demo mode is enabled; times are: 1";
                        if (llGetListLength(windTimes) > 1) s += ", 2";
                        s += " mins.\n";
                    }
                    
                    // Which is the upper bound on the wind times currently? Depeding on the values this could be keyLimit/2 or windLimit
                    s += "Current wind menu: ";

                    integer timeLeft = llFloor((timeLeftOnKey - llGetTime()) / 60.0);
                    float windLimit = currentLimit - (timeLeftOnKey - llGetTime());
                    integer timesLimit = llFloor(windLimit / SEC_TO_MIN);
                    integer time; list avail; integer i; integer n = llGetListLength(windTimes);
                    integer maxTime = llRound(currentLimit / 60.0 / 2);

                    while ((i <= n) && ( ( time = llList2Integer(windTimes, i++) ) < timesLimit) && (time <= maxTime)) {
                        avail += ["Wind " + (string)time];
                    } 
                    if ((i <= n) && (timesLimit <= maxTime)) {
                        avail += ["Wind Full"];
                        s += " (" + (string)timeLeft  + " of " + (string)maxTime + " minutes left " + (string)timesLimit + " from max)";
                    }

                    s += llList2CSV(avail);
                    if (windLimit < (keyLimit / 2)) s += " (Times limited to half max time)";
                    s += "\n";

                    string p = llToLower(pronounHerDoll);
#ifdef TESTING
                    cdCapability(autoTP,      "Doll can", "be force teleported");
                    cdCapability(detachable,  "Doll can", "detach " + p + " key");
                    cdCapability(canDress,    "Doll can", "be dressed by the public");
                    cdCapability(canCarry,    "Doll can", "be carried by the public");
                    cdCapability(canAFK,      "Doll can", "go AFK");
                    cdCapability(canFly,      "Doll can", "fly");
                    cdCapability(canPose,     "Doll can", "be posed by the public");
                    cdCapability(canSit,      "Doll can", "sit");
                    cdCapability(canStand,    "Doll can", "stand");
                    cdCapability(canRepeat,   "Doll can", "multiply wound");
                    cdCapability(canWear,     "Doll can", "dress by " + p + "self");
                    cdCapability(poseSilence, "Doll is",  "silenced while posing");
#else
                    list items = [
                        autoTP,             "Doll can? be force teleported",
                        detachable,         "Doll can? detach " + p + " key",
                        canDress,           "Doll can? be dressed by others",
                        canFly,             "Doll can? fly",
                        canPose,            "Doll can? be posed by others",
                        canSit,             "Doll can? sit",
                        canStand,           "Doll can? stand",
                        canWear,            "Doll can? dress by " + p + "self",
                        poseSilence,        "Doll is? silenced while posing"
                    ];

                    i=0; n = llGetListLength(items);

                    while (i++ < n) {
                        string in = llList2String(items, i--);
                        integer index = llSubStringIndex(in, "?");

                        in = llDeleteSubString(in, index, index);
                        if (!llList2Integer(items, i+=2)) in = llInsertString(in, index, " not");
                        s += in + "\n";
                    }

#endif
                    if (windRate == 0.0) { s += "Key is not winding down.\n"; }
                    else { s += "Current wind rate is " + formatFloat(windRate,2) + ".\n"; }

                    if (RLVok == -1) { s += "RLV status is unknown.\n"; }
                    else if (RLVok == 1) { s += "RLV is active.\n"; } 
                    else s += "RLV is not active.\n";

                    llOwnerSay(s);
                }
                else if (choice == "stat") {
                    float t1 = timeLeftOnKey / (SEC_TO_MIN * displayWindRate);
                    float t2 = currentLimit / (SEC_TO_MIN * displayWindRate);
                    float p = t1 * 100.0 / t2;

                    string s = "Time: " + (string)llRound(t1) + "/" +
                                (string)llRound(t2) + " min (" + formatFloat(p, 2) + "% capacity)";
                    if (afk) {
                        s += " (current wind rate " + formatFloat(displayWindRate, 1) + "x)";
                    }
                    llOwnerSay(s);
                }
                else if (choice == "stats") {
                    displayWindRate;
                    llOwnerSay("Time remaining: " + (string)llRound(timeLeftOnKey / (SEC_TO_MIN * displayWindRate)) + " minutes of " +
                                (string)llRound(currentLimit / (SEC_TO_MIN * displayWindRate)) + " minutes.");
                    string msg = "Key is";
                    if (windRate == 0.0) msg += " stopped.";
                    else {
                        msg = "Key is unwinding at a";
                        if (windRate < 1.0) msg += " slowed rate";
                        else if (windRate == 1.0) msg += " normal rate";
                        else msg += " accelerated rate";
                        msg += " of " + formatFloat(windRate, 1) + "x.";
                    }
                    llOwnerSay(msg);

                    if (!cdCollapsedAnim() && !cdNoAnim()) {
                    //    llOwnerSay(dollID, "Current pose: " + currentAnimation);
                    //    llOwnerSay(dollID, "Pose time remaining: " + (string)(poseTime / SEC_TO_MIN) + " minutes.");
                        llOwnerSay("Doll is posed.");
                    }

                    lmMemReport(1.0, 1);
                }
                else if (choice == "build") {
                    lmConfigReport();
                }
                else if (choice == "release") {
                    if (poserID != dollID) llOwnerSay("Dolly tries to wrest control of her body from the pose but she is no longer in control of her form.");
                    else lmInternalCommand("doUnpose", "", dollID);
                }
            }
            else {
                // Command has secondary parameter
                string param = llStringTrim(llGetSubString(choice, space + 1, STRING_END), STRING_TRIM);
                choice       = llStringTrim(llGetSubString(choice,         0,  space - 1), STRING_TRIM);

                if (choice == "channel") {
                    string c = param;

                    if ((string) ((integer) c) == c) {
                        integer ch = (integer) c;

                        if (ch != 0 && ch != DEBUG_CHANNEL) { // FIXME: Sanity checking should be extended
                            chatChannel = ch;
                            llListenRemove(chatHandle);
                            chatHandle = llListen(ch, "", llGetOwner(), "");
                        }
                    }
                }
                else if (choice == "controller") { lmInternalCommand("getMistressKey", param, NULL_KEY); }
                else if (choice == "blacklist") { lmInternalCommand("getBlacklistKey", param, NULL_KEY); }
                else if (choice == "unblacklist") { lmInternalCommand("getBlacklistKey", param, NULL_KEY); }
                else if (choice == "wakescript") {
                    string script;

                    if (llGetInventoryType(param) == INVENTORY_SCRIPT) script = param;
                    else {
                        integer i; for (i = 0; i < llGetInventoryNumber(INVENTORY_SCRIPT); i++) {
                            if (llToLower(llGetInventoryName(INVENTORY_SCRIPT, i)) == llToLower(param)) script = param;
                        }
                    }
                    if (llGetScriptState(script)) llOwnerSay("The '" + script + "' script is already in a running state");
                    else if ((RLVok != 1) && (script == "StatusRLV")) 
                        llOwnerSay("StatusRLV will not run until RLV is enabled, this is by design.  Try the rlvinit command instead.");
                    else {
                        string msg = "Trying to wake '" + script + "'";

                        llOwnerSay(msg);
                        llResetOtherScript(script);
                        llSetScriptState(script, 1);
                        llSleep(5.0);
                        cdLinkMessage(LINK_THIS, 0, 301, "", NULL_KEY);
                        llSleep(5.0);
                        msg = "Script '" + script + "'";
                        if (llGetScriptState(script)) msg += " seems to be running now.";
                        else msg += " appears to have stopped running again after being restarted.  If you are not getting script errors this may be intentional.";
                        llOwnerSay(msg);
                    }
                }
#ifdef DEVELOPER_MODE
                else if (choice == "debug") {
                    lmSendConfig("debugLevel", (string)(debugLevel = (integer)param));
                    llOwnerSay("DEBUG_LEVEL = " + (string)debugLevel);
                }
                else if (choice == "inject") {
                    list params = llParseString2List(param, ["#"], []);
                    llOwnerSay("INJECT LINK:\nLink Code: " + (string)llList2Integer(params, 0) + "\n" +
                               "Data: " + cdMyScriptName() + "|" + llList2String(params, 1) + "\n" +
                               "Key: " + (string)llList2Key(params, 2));
                    llMessageLinked(LINK_THIS, llList2Integer(params, 0), cdMyScriptName() + "|" + llList2String(params, 1), llList2Key(params, 2));
                }
                else if (choice == "timereporting") {
                    lmSendConfig("timeReporting", (string)(timeReporting = (integer)param));
                }
#else
#ifdef TESTER_MODE
                else if (choice == "debug") {
                    lmSendConfig("debugLevel", (string)(debugLevel = (integer)param));
                    llOwnerSay("DEBUG_LEVEL = " + (string)debugLevel);
                }
#endif
#endif
                else llOwnerSay("Unrecognised command '" + choice + "' recieved on channel " + (string)chatChannel);
            }
        }
        else if (channel == broadcastOn) {
            if (llGetSubString(choice, 0, 4) == "keys ") {
                string subcommand = llGetSubString(choice, 5, STRING_END);
                debugSay(9, "BROADCAST-DEBUG", "Broadcast recv: From: " + name + " (" + (string)id + ") Owner: " + llGetDisplayName(llGetOwnerKey(id)) + " (" + (string)llGetOwnerKey(id) +  ") " + choice);
                if (subcommand == "claimed") {
                    if (keyHandler == llGetKey()) {
                        llRegionSay(broadcastOn, "keys released");
                        debugSay(9, "BROADCAST-DEBUG", "Broadcast sent: keys released");
                    }
                    lmSendConfig("keyHandler", (string)(keyHandler = id));
                }
                else if ((subcommand == "released") && (keyHandler == id)) {
                    lmSendConfig("keyHandler", (string)(keyHandler = NULL_KEY));
                }
            }
        }
    }
}
