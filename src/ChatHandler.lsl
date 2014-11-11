//========================================
// ChatHandler.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

#include "include/GlobalDefines.lsl"
#define cdMenuInject(a,b,c) lmMenuReply(a,b,c)

#define cdRefreshVars() cdLinkMessage(LINK_THIS, 0, 301, "", NULL_KEY)
#define cdDumpState()   cdLinkMessage(LINK_THIS, 0, 302, "", NULL_KEY);

#define UNSET -1

// FIXME: Depends on a variable s
#define cdCapability(c,p,u) { s += p; if (!(c)) { s += " not"; }; s += " " + u + ".\n"; }

#ifdef KEY_HANDLER
key keyHandler              = NULL_KEY;
#endif
key listID                  = NULL_KEY;

list windTimes              = [30];

float collapseTime          = 0.0;
float currentLimit          = 10800.0;
float wearLockExpire;
integer wearLock;

string dollGender           = "Female";
string chatPrefix           = "";
string RLVver               = "";
string pronounHerDoll       = "Her";
string pronounSheDoll       = "She";
string dollName             = "";
string blockedControlName   = "";
string blockedControlUUID   = "";

integer autoAFK             = 1;
#ifdef KEY_HANDLER
integer broadcastOn         = -1873418555;
integer broadcastHandle     = 0;
#endif
integer busyIsAway          = 0;
integer chatChannel         = 75;
integer chatHandle          = 0;
#ifdef DEVELOPER_MODE
integer timeReporting       = 0;
integer debugLevel          = DEBUG_LEVEL;
#endif
integer RLVok               = UNSET;
integer blockedControlTime  = 0;
integer blacklistMode       = 0;

default
{
    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);

        // Beware listener is now available to users other than the doll
        // make sure to take this into account within all handlers.
        chatHandle = cdListenAll(chatChannel);
#ifdef KEY_HANDLER
        broadcastHandle = cdListenAll(broadcastOn);
#endif

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

        scaleMem();

        if (code == 110) {
            if (chatPrefix == "") {
                // If chat prefix is not configured by DB or prefs we initialize the default prefix
                // using the initials of the dolly's name in legacy name format.
                string key2Name = llKey2Name(dollID);
                integer i = llSubStringIndex(key2Name, " ") + 1;

                chatPrefix = llToLower(llGetSubString(key2Name,0,0) + llGetSubString(key2Name,i,i));
                lmSendConfig("chatPrefix", chatPrefix);
            }

            llOwnerSay("Setting up chat commands on channel " + (string)chatChannel + " with prefix \"" + llToLower(chatPrefix) + "\"");
        }
        else if (code == 135) {
            memReport(cdMyScriptName(),llList2Float(split, 0));
        } else

        cdConfigReport();

        else if (code == 300) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);
            string c = cdGetFirstChar(name); // for speedup

            if (value == RECORD_DELETE) {
                value = "";
                split = [];
            } else {
                split = llDeleteSubList(split, 0, 0);
            }

                 if (name == "timeLeftOnKey")           timeLeftOnKey = (float)value;
            else if (name == "collapseTime")             collapseTime = (float)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "timeReporting")           timeReporting = (integer)value;
#endif

            else if (name == "afk")                               afk = (integer)value;
            else if (name == "autoAFK")                       autoAFK = (integer)value;
            else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "blacklistMode")           blacklistMode = (integer)value;
            else if (name == "blacklist")                   blacklist = llListSort(split, 2, 1);
            else if (name == "busyIsAway")                 busyIsAway = (integer)value;

            // Shortcut: c
            else if (c == "c") {
                     if (name == "canAFK")                     canAFK = (integer)value;
                else if (name == "canCarry")                 canCarry = (integer)value;
                else if (name == "canDress")                 canDress = (integer)value;
                else if (name == "canPose")                   canPose = (integer)value;
                else if (name == "canDressSelf")         canDressSelf = (integer)value;
                else if (name == "canFly")                     canFly = (integer)value;
                else if (name == "canSit")                     canSit = (integer)value;
                else if (name == "canStand")                 canStand = (integer)value;
                else if (name == "canRepeat")               canRepeat = (integer)value;
                else if (name == "configured")             configured = (integer)value;
                else if (name == "controllers")           controllers = llListSort(split, 2, 1);
                else if (name == "chatChannel") {
                    chatChannel = (integer)value;
                    dollID = llGetOwner();
                    llListenRemove(chatHandle);
                    chatHandle = llListen(chatChannel, NO_FILTER, dollID, NO_FILTER);
                }
            }

            // Shortcut: d
            else if (c == "d") {
                     if (name == "detachable")             detachable = (integer)value;
                else if (name == "displayWindRate")   displayWindRate = (float)value;
                else if (name == "dollType")                 dollType = value;
                else if (name == "dollGender")             dollGender = value;
                else if (name == "demoMode") {
                    demoMode = (integer)value;
                    if (!demoMode) currentLimit = keyLimit;
                    else currentLimit = DEMO_LIMIT;
                }
#ifdef DEVELOPER_MODE
                else if (name == "debugLevel")             debugLevel = (integer)value;
#endif
            }
            else if (name == "isVisible")                     visible = (integer)value;
            else if (name == "listID")                         listID = (key)value;

            // Shortcut: p
            else if (c == "p") {
                     if (name == "poseSilence")           poseSilence = (integer)value;
                else if (name == "pleasureDoll")         pleasureDoll = (integer)value;
                else if (name == "poserID")                   poserID = (key)value;
                else if (name == "poserName")               poserName = value;
                else if (name == "pronounHerDoll")     pronounHerDoll = value;
                else if (name == "pronounSheDoll")     pronounSheDoll = value;
            }
            else if (name == "quiet")                           quiet = (integer)value;
//          else if (name == "offlineMode")               offlineMode = (integer)value;

            // Shortcut: k
            else if (c == "k") {
                     if (name == "keyAnimation")         keyAnimation = value;
#ifdef KEY_HANDLER
                else if (name == "keyHandler") {
                    keyHandler = (key)value;
                }
#endif
                else if (name == "keyLimit") {
                    keyLimit = (float)value;
                    if (!demoMode) currentLimit = keyLimit;
                }
            }
            else if (name == "tpLureOnly")                 tpLureOnly = (integer)value;
            else if (name == "windTimes")                   windTimes = llJson2List(value);
            else if (name == "wearLockExpire")         wearLockExpire = (float)value;
            else if (name == "wearLock")                     wearLock = (integer)value;
            else if (name == "windRate")                     windRate = (float)value;
        }

        else if (code == 305) {
            string cmd = llList2String(split, 0);

#define CONTROLLER_LIST 1
#define BLACKLIST_LIST 2

            if ((cmd == "addMistress") ||
                (cmd == "addRemBlacklist") ||
                (cmd == "remMistress")) {

                string uuid = llList2String(split, 1);
                string name = llList2String(split, 2);

                integer type; string typeString; string barString; integer mode;
                list tmpList; list barList; // barList represents the opposite (of blacklist or controller list) which bars adding.

                if ((id != DATABASE_ID) && (script != "MenuHandler")) id = listID;
                if (name == "") return; // fix for issue #141

                // These lists become mangled sometimes for reasons unclear creating a new handler for both here
                // with a more thorough validation process which should also be somewhat more fault tollerant in
                // the event that a list does become corrupted also.

 #define ADD_MODE 1
 #define REM_MODE -1

                if (llGetSubString(cmd, -8, STRING_END) == "Mistress") {
                    type = CONTROLLER_LIST; typeString = "controller";
                    tmpList = controllers; barList = blacklist;
                    if (llGetSubString(cmd, 0, 2) == "add") mode = ADD_MODE;
                    else mode = REM_MODE;
                }
                else {
                    type = BLACKLIST_LIST; typeString = "blacklist";
                    tmpList = blacklist; barList = controllers;
                    mode = blacklistMode;
                    blacklistMode = 0;
                }

                // First check: Test suitability of name for adding; send a message to user if not acceptable
                if (llListFindList(barList, [ uuid ]) != NOT_FOUND) {
                    string msg;

                    if (type == CONTROLLER_LIST) {
                        msg = name + " is blacklisted; you must first remove them from the blacklist before adding them as a controller.\nTo do so type /" +
                                  (string)chatChannel + " unblacklist " + name;
                        blockedControlName = name;
                        blockedControlUUID = uuid;
                        blockedControlTime = llGetUnixTime();
                    }
                    else msg = name + " is one of your controllers; until they remove themselves from being your controller, you cannot add them to the blacklist.";

                    lmSendToAgentPlusDoll(msg, id);
                    return;
                }

                // First validation: Check for empty values there should be none so delete any that are found
                while ((i = llListFindList(tmpList, [""])) != -1) tmpList = llDeleteSubList(tmpList,i,i);

                // Second validation: Test for the presence of the UUID in the existing list
                i = llListFindList(tmpList, [ uuid ]);
                integer j = llListFindList(tmpList, [ name ]);

                if (mode == ADD_MODE) {

                    integer load;

                    if (id == DATABASE_ID) {
                        load = TRUE;
                        llOwnerSay("Restoring " + name + " as " + typeString + " from database settings.");
                    }

                    if (i == NOT_FOUND) {
                        // Handle adding
                        if (!load) lmSendToAgentPlusDoll("Adding " + name + " as " + typeString, id);
                        tmpList += [ uuid, name ];
                        // Verify that the list doesn't have an uneven count before trying to presort it
                        if ((llGetListLength(tmpList) % 2) == 0) tmpList = llListSort(tmpList, 2, 1);
                    }
                    // Report already found
                    else if (!load) lmSendToAgentPlusDoll(name + " is already found listed as " + typeString, id);
                }
                else {
                    if ((i != NOT_FOUND) || (j != NOT_FOUND)) {
                        // This should be a simple uuid, name strided list but having seend SL corrupt others
                        // in various ways check uuid & name independently and make certain that neither part
                        // of an entry for this user can remain after being ordered removed!
                        lmSendToAgentPlusDoll("Removing " + name + " from list as " + typeString + ".", id);
                        if (i != NOT_FOUND) {
                            tmpList = llDeleteSubList(tmpList, i, i);
                            if ((j != NOT_FOUND) && (j > i)) j--; // The previous operation may shift one position update if applicable
                        }
                        if (j != NOT_FOUND) llDeleteSubList(tmpList, j, j);
                    }
                    else {
                        lmSendToAgentPlusDoll(name + " is not listed as " + typeString, id);
                    }
                }

                if (type == CONTROLLER_LIST) {
                    if (controllers != tmpList) {
                        controllers = tmpList;
                        lmSendConfig("controllers", llDumpList2String(controllers, "|") );
                    }
                }
                else {
                    if (blacklist != tmpList) {
                        blacklist = tmpList;
                        lmSendConfig("blacklist", llDumpList2String(blacklist, "|") );
                    }

                    if ((mode == -1) && (name == blockedControlName)) {
                        lmInternalCommand("addMistress", uuid + "|" + name, dollID);
                    }
                }
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
    listen(integer channel, string name, key id, string msg) {
        // channel = chat channel to listen on
        //    name = filter by prim name
        //     key = filter by avatar key
        //  choice = filter by specific message

        // This makes chat commands work correctly and be properly identified and tracked
        // back to an actual agent even if an intermediary is used. this prevents such as
        // blacklist circumvention and saves a more complex ifAvatar test being needed.
        //
        // Accepting commands in this way also offers several potential advantages:
        // - Works in the presense of renamers or other scripted chat redirection.
        // - Keeps open the potential ability to extend functionality with other objects
        //   a basic HUD for doll showing basic status info and with quick access menu buttons
        //   for example (Makes a note to github that thought).
        id = llGetOwnerKey(id);
        name = llGetDisplayName(id);
        integer isDoll = cdIsDoll(id);
        integer isController = cdIsController(id);

        debugSay(5,"CHAT-DEBUG",("Got a message: " + name + "/" + (string)id + "/" + msg));
        // Deny access to the menus when the command was recieved from blacklisted avatar
        if (!isDoll && (llListFindList(blacklist, [ (string)id ]) != NOT_FOUND)) {
            lmSendToAgent("You are not permitted to access this key.", id);
            return;
        }

        // Text commands
        if (channel == chatChannel) {
            lmInternalCommand("getTimeUpdates","",NULL_KEY);
            llSleep(2);
            debugSay(5,"CHAT-DEBUG",("Got a chat channel message: " + name + "/" + (string)id + "/" + msg));
            string prefix = cdGetFirstChar(msg);

            // Before we proceed first verify that the command is for us.
            if (prefix == "*") {
                // *prefix is global, strip from choice and continue
                //prefix = llGetSubString(msg,0,0);
                msg = llGetSubString(msg,1,-1);
            }
            else if ((prefix == "#") && !isDoll) {
                // #prefix is an all others prefix like with OC etc
                //prefix = llGetSubString(msg,0,0);
                msg = llGetSubString(msg,1,-1);
            }
            else if (llToLower(llGetSubString(msg,0,1)) == chatPrefix) {
                prefix = llGetSubString(msg,0,1);
                msg = llGetSubString(msg,2,-1);
            }
            else if (isDoll) {
#ifdef PREFIX_NEEDED
                llOwnerSay("Use of chat commands without a prefix is depreciated and will be removed in a future release.");
#else
                ;
#endif
            }
            else return; // For some other doll? noise? matters not it's someone elses problem.

            //debugSay(2, "CHAT-DEBUG", "On #" + (string)channel + " secondlife:///app/agent/" + (string)id + "/about: pre:" + prefix + "(ok) cmd:" + msg + " id:" + (string)id);

            // Is the "msg" an animation?
            if (llGetInventoryType(msg) == 20) {
                string firstChar = cdGetFirstChar(msg);

                // if animation starts with "." only Doll has access to it
                if (firstChar == ".") {
                    if (isDoll) { cdMenuInject(msg, name, id); }
                }
                // if animation starts with "!" only Doll and Controllers have access to it
                else if (firstChar == "!") {
                    if (isDoll || isController) { cdMenuInject(msg, name, id); }
                }
                else {
                    cdMenuInject(msg, name, id);
                }

                return;
            }

#define PARAMETERS_EXIST (space != NOT_FOUND)

            // Choice is a command, not a pose
            integer space = llSubStringIndex(msg, " ");
            string choice = msg;

            if (!PARAMETERS_EXIST) { // Commands without parameters handled first
                choice = llToLower(choice);

                // Commands only for Doll
                //    * build

                if (isDoll) {
                    if (choice == "build") {
                        lmConfigReport();
                    }
                }

                // Commands only for Doll or Built-in Controllers:
                //    * refreshvars
                //    * dumpstate
                //    * httppreload
                //    * rlvinit

                if (isDoll || cdIsBuiltinController(id)) {
#ifdef DATABASE_BACKEND
                    // Do an internal resresh of all local variables from local db
                    if (choice == "refreshvars") {
                        cdRefreshVars();
                    }
                    // Request verbose full key state dump to chat
                    else if (choice == "dumpstate") {
                        cdDumpState();
                    }
                    // Service reinitialization and remote restore
                    else if (choice == "httpreload") {
                        if (!offlineMode) {
                            llResetOtherScript("ServiceReceiver");
                            llSleep(1.0);
                            llResetOtherScript("ServiceRequester");
                            llSleep(2.0);
                        }
                    } else 
#endif
                    // Try a hard RLV reinitialzation
//                  if (choice == "rlvinit") {
//                      llSetScriptState("StatusRLV", 1);
//                      llResetOtherScript("StatusRLV");
//                      llResetOtherScript("Avatar");
//
//                      llSleep(1.0);
                        //cdRefreshVars();
                        //llSleep(5.0);
                        // Inject menu click

//                      cdMenuInject("*RLV On*",llGetDisplayName(dollID), id);
//                  }
                }

                // Commands only for Doll or Controllers
                //   * detach
                //   * help
                //   * devhelp
                //   * listhelp
                //   * xstats

                if (isDoll || isController) {
                    // Normal user commands
                    if (choice == "detach")

                        if (detachable || isController) lmInternalCommand("detach", "", NULL_KEY);
                        else lmSendToAgent("Key can't be detached...", id);

                    else if (choice == "help") {
                    string help = "Commands:
    Commands can be prefixed with your prefix, which is currently " + llToUpper(chatPrefix) + "\n
    detach ......... detach key if possible
    stat ........... concise current status
    stats .......... selected statistics and settings
    xstats ......... extended statistics and settings
    poses .......... list all poses
    wind ........... trigger emergency autowind
    demo ........... toggle demo mode
    [posename] ..... activate the named pose if possible
    release ........ stop the current pose if possible
    channel ## ..... change channel
    prefix XX ...... change chat command prefix
    help ........... this list of commands
    dumpstate ...... dump all key state to chat history
    build .......... list build configurations
    listhelp ....... list controller/blacklist commands"
#ifdef DEVELOPER_MODE
    +
"
    devhelp ........ list of developer commands"
#endif
    ;
                    lmSendToAgent(help, id);
                    }
#ifdef DEVELOPER_MODE
                    else if (choice == "devhelp") {
                    string help = "Developer Commands:\n
    timereporting .. periodic reporting of script time usage
    debug # ........ set the debugging message verbosity 0-9
    inject ......... inject an aribtary link message the format is
                     int#str#key with all but the first optional.";
                     lmSendToAgent(help, id);
                    }
#endif

                    else if (choice == "listhelp") {
                    string help = "Access Commands:
                     The following commands must be followed by the desired
                     user's username (not display name!).\n
    controller ..... add the username to the controller list
    blacklist ...... blacklist the username if not blacklisted
    unblacklist .... unblacklist the username if they are blacklisted";
                    lmSendToAgent(help, id);
                    }
                    else if (choice == "xstats") {
                        string s = "Extended stats:\nDoll is a " + dollType + " Doll.\nAFK time factor: " +
                                   formatFloat(RATE_AFK, 1) + "x\nConfigured wind times: " + llList2CSV(windTimes) + " (mins)\n";

                        if (demoMode) s += "Demo mode is enabled";

                        string p = llToLower(pronounHerDoll);

                        cdCapability(autoTP,       "Doll can", "be force teleported");
                        cdCapability(detachable,   "Doll can", "detach " + p + " key");
                        cdCapability(canDress,     "Doll can", "be dressed by the public");
                        cdCapability(canCarry,     "Doll can", "be carried by the public");
                        cdCapability(canAFK,       "Doll can", "go AFK");
                        cdCapability(canFly,       "Doll can", "fly");
                        cdCapability(canPose,      "Doll can", "be posed by the public");
                        cdCapability(canSit,       "Doll can", "sit");
                        cdCapability(canStand,     "Doll can", "stand");
                        cdCapability(canRepeat,    "Doll can", "multiply wound");
                        cdCapability(canDressSelf, "Doll can", "dress by " + p + "self");
                        cdCapability(poseSilence,  "Doll is",  "silenced while posing");
                        cdCapability(wearLock,     "Doll's clothing' is",  "currently locked on");

                        if (windRate) s += "Current wind rate is " + formatFloat(windRate,2) + ".\n";
                        else s += "Key is not winding down.\n";

                        if (RLVok == UNSET) s += "RLV status is unknown.\n";
                        else if (RLVok == 1) s += "RLV is active.\nRLV version: " + RLVver;
                        else s += "RLV is not active.\n";

                        lmSendToAgent(s, id);
                    }
                    else if (choice == "stat") {
                        //debugSay(6, "DEBUG", "timeLeftOnKey = " + (string)timeLeftOnKey);
                        //debugSay(6, "DEBUG", "currentLimit = " + (string)currentLimit);
                        //debugSay(6, "DEBUG", "displayWindRate = " + (string)displayWindRate);

                        float t1 = timeLeftOnKey / (SEC_TO_MIN * displayWindRate);
                        float t2 = currentLimit / (SEC_TO_MIN * displayWindRate);
                        float p = t1 * 100.0 / t2;

                        string msg = "Time: " + (string)llRound(t1) + "/" +
                                    (string)llRound(t2) + " min (" + formatFloat(p, 2) + "% capacity)";

                        if (windRate) {
                            msg += " unwinding at a ";

                            if (windRate == 1.0) msg += "normal rate.";
                            else {
                                if (windRate < 1.0) msg += "slowed rate of ";
                                else if (windRate > 1.0) msg += "accelerated rate of ";

                                msg += " of " + formatFloat(windRate, 1) + "x.";
                            }

                        } else msg += " and key is currently stopped.";

                        lmSendToAgent(msg, id);
                    }
                    else if (choice == "stats") {
                        //debugSay(6, "DEBUG", "timeLeftOnKey = " + (string)timeLeftOnKey);
                        //debugSay(6, "DEBUG", "currentLimit = " + (string)currentLimit);
                        //debugSay(6, "DEBUG", "displayWindRate = " + (string)displayWindRate);

                        //displayWindRate;

                        lmSendToAgent("Time remaining: " + (string)llRound(timeLeftOnKey / (SEC_TO_MIN * displayWindRate)) + " minutes of " +
                                    (string)llRound(currentLimit / (SEC_TO_MIN * displayWindRate)) + " minutes.", id);

                        string msg;

                        if (windRate == 0.0) msg = "Key is stopped.";
                        else {
                            msg = "Key is unwinding at a ";

                            if (windRate == 1.0) msg += "normal rate.";
                            else {
                                if (windRate < 1.0) msg += "slowed rate of ";
                                else if (windRate > 1.0) msg += "accelerated rate of ";

                                msg += " of " + formatFloat(windRate, 1) + "x.";
                            }

                        }

                        lmSendToAgent(msg, id);

                        if (!cdCollapsedAnim() && !cdNoAnim()) {
                        //    llOwnerSay(dollID, "Current pose: " + currentAnimation);
                        //    llOwnerSay(dollID, "Pose time remaining: " + (string)(poseTime / SEC_TO_MIN) + " minutes.");
                            llOwnerSay("Doll is posed.");
                        }

                        lmMemReport(1.0, 1);
                    }
                    else if (choice == "release") {
                        string p = llToLower(pronounHerDoll);
                        string s = llToLower(pronounSheDoll);

                        if ((poserID != NULL_KEY) && (poserID != dollID)) llOwnerSay("Dolly tries to wrest control of " + p + " body from the pose but " + s + " is no longer in control of " + p + " form.");
                        else lmMenuReply("Unpose", dollName, dollID);
                    }

                    // Demo: short time span
                    else if (choice == "demo") {
                        // Note that, unlike in the original key, demo mode is not
                        // just a 5-minute limit - but rather a TEMPORARY 5-minute limit,
                        // with previous settings saved...

                        // Toggles demo mode
                        lmSendConfig("demoMode", (string)(demoMode = !demoMode));

                        string s = "Dolly's Key is now ";
                        if (demoMode) {
                            if (timeLeftOnKey > DEMO_LIMIT) lmSendConfig("timeLeftOnKey", (string)(timeLeftOnKey = DEMO_LIMIT));
                            s += "in demo mode: " + (string)llRound(timeLeftOnKey / SEC_TO_MIN) + " of " + (string)llFloor(DEMO_LIMIT / SEC_TO_MIN) + " minutes remaining.";
                        }
                        else {
                            // Q: currentlimit not set until later; how do we tell user what it is?
                            // A: They are not in demoMode after this so the limit is going to be restored to keyLimit
                            //    only exception would be if keyLimit was invalid however there will be a follow up message
                            //    from Main stating this and giving the new value so not something we need to do here.

                            s += "running normally: " + (string)llRound(timeLeftOnKey / SEC_TO_MIN) + " of " + (string)llFloor(keyLimit / SEC_TO_MIN) + " minutes remaining.";
                        }
                        llOwnerSay(s);
                    }
                    else if (choice == "listposes") {
                        integer n = llGetInventoryNumber(INVENTORY_ANIMATION);

                        string thisPose; string thisPrefix;

                        while(n) {
                            thisPose = llGetInventoryName(INVENTORY_ANIMATION, --n);
                            thisPrefix = cdGetFirstChar(thisPose);

                            if ((thisPrefix != "!") && (thisPrefix != ".")) thisPrefix = "";

                            // Collapsed animation is special: skip it
                            if (thisPose != ANIMATION_COLLAPSED) {

                                // Doll sees all animations
                                // Controller sees only animations with a "!" prefix
                                // Animations with no prefix are seen by all
                                //
                                // -- or --
                                //
                                // Doll sees all animations regardless of prefix
                                // Controller sees animations with no prefix and a "!" prefix
                                // General public sees only those animations with no prefix
                                //
                                // -- or --
                                //
                                // "!" prefix is seen by Doll and Controller
                                // "." prefix is seen by Doll
                                // Other animations with no prefix are seen by all
                                //
                                if (isDoll ||
                                    (isController && (thisPrefix == "!")) ||
                                    (thisPrefix == "")) {

                                        if (keyAnimation == thisPose) {
                                            lmSendToAgent("\t*\t" + thisPose, id);
                                        }
                                        else {
                                            lmSendToAgent("\t\t" + thisPose, id);
                                        }
                                }
                                else if (keyAnimation == thisPose) {
                                    lmSendToAgent("\t*\t{private}", id);
                                }
                            }
                        }
                    }
                }

                if (choice == "wind") {
                    // if Dolly gives this command, its an Emergency Winder activation.
                    // if someone else, it is a normal wind of the Doll.
#ifndef TESTER_MODE
                    if (isDoll) cdMenuInject("Wind Emg", dollName, dollID);
                    else {
#endif
                        cdMenuInject("Wind", name, id);
#ifndef TESTER_MODE
                        }
#endif
                }
                else if (choice == "menu")    cdMenuInject(MAIN, name, id);
                else if (choice == "outfits") cdMenuInject("Outfits...", name, id);
                else if (choice == "types")   cdMenuInject("Types...", name, id);
                else if (choice == "poses")   cdMenuInject("Poses...", name, id);
                else if (choice == "carry")   cdMenuInject("Carry", name, id);
                else if (choice == "uncarry") cdMenuInject("Uncarry", name, id);
            }
            else {
                // Command has secondary parameter
                string param =           llStringTrim(llGetSubString(choice, space + 1, STRING_END), STRING_TRIM);
                choice       = llToLower(llStringTrim(llGetSubString(   msg,         0,  space - 1), STRING_TRIM));

                if (isDoll || cdIsBuiltinController(id)) {
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
                    else if (choice == "controller") {
                        blockedControlName = "";
                        blockedControlUUID = "";
                        blockedControlTime = 0;
                        lmInternalCommand("getMistressKey", param, id);
                    }
                    else if (choice == "blacklist") {
                        blacklistMode = 1;
                        lmInternalCommand("getBlacklistKey", param, id);
                    }
                    else if (choice == "unblacklist") {
                        if ((llToLower(blockedControlName) == llToLower(param)) && (llGetUnixTime() < (blockedControlTime + 300))) {
                            llOwnerSay("Adding previously blacklisted user " + blockedControlName + " as controller.");
                            //blacklistMode = -1;
                            lmInternalCommand("addRemBlacklist", blockedControlUUID + "|" + blockedControlName, dollID);
                        }
                        blacklistMode = -1;
                        lmInternalCommand("getBlacklistKey", param, id);
                    }
                    else if (choice == "prefix") {
                        string newPrefix = param;
                        string c1 = llGetSubString(newPrefix,0,0);
                        string msg = "The prefix you entered is not valid, the prefix must ";

                        // * must be greater than two characters

                        if (llStringLength(newPrefix) == 2) {
                            // Why? Two character user prefixes are standard and familiar; too much false positives with
                            // just 1 letter (~4%) with letter + letter/digit it's (~0.1%) - excessively long prefixes
                            // are bad for useability.
                            lmSendToAgent(msg + "be at least two characters long.", id);
                        }

                        // * contain numbers and letters only

                        else if (newPrefix != llEscapeURL(newPrefix)) {
                            // Why? Stick to simple ascii compatible alphanumerics that are compatible with
                            // all keyboards and with mobile devices with limited input capabilities etc.
                            lmSendToAgent(msg + "only contain letters and numbers.", id);
                        }

                        // * start with a letter

                        else if (((integer)c1) || (c1 == "0")) {
                            // Why? This one is needed to prevent the first char of prefix being merged into
                            // the channel # when commands are typed without the use of the optional space.
                            lmSendToAgent(msg + "start with a letter.", id);
                        }

                        // All is good

                        else {
                            chatPrefix = newPrefix;
                            lmSendToAgentPlusDoll("Chat prefix has been changed to " + llToUpper(chatPrefix) + " the new prefix should now be used for all commands.", id);
                        }
                    }
#ifdef WAKESCRIPT
                    else if (choice == "wakescript") {
                        string script;

                        // if param is script; set var - else search for it?
                        // FIXME: return if not a script at all
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
                            //llSleep(5.0);
                            //cdRefreshVars();
                            //llSleep(5.0);

                            msg = "Script '" + script + "'";
                            if (llGetScriptState(script)) msg += " seems to be running now.";
                            else msg += " appears to have stopped running again after being restarted.  If you are not getting script errors this may be intentional.";

                            llOwnerSay(msg);
                        }
                    }
#endif
                }
                if (isDoll) {
#ifdef DEVELOPER_MODE
                    if (choice == "debug") {
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
                        string s = "Time reporting turned ";

                        if (param == "0") s += "off.";
                        else if (param == "off") {
                            s += "off.";
                            param = "0";
                        }
                        else {
                            s += "on.";
                            param = "1";
                        }

                        llOwnerSay(s);
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
                }
            }
        }
#ifdef KEY_HANDLER
        else if (channel == broadcastOn) {
            if (llGetSubString(msg, 0, 4) == "keys ") {
                string subcommand = llGetSubString(msg, 5, STRING_END);
                debugSay(9, "BROADCAST-DEBUG", "Broadcast recv: From: " + name + " (" + (string)id + ") Owner: " + llGetDisplayName(llGetOwnerKey(id)) + " (" + (string)llGetOwnerKey(id) +  ") " + msg);
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
#endif
    }
}
