//========================================
// ChatHandler.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

#include "include/GlobalDefines.lsl"
#define cdMenuInject(a,b,c) lmMenuReply(a,b,c)

#define UNSET -1

// FIXME: Depends on a variable s
#define cdCapability(c,p,u) { s += p; if (!(c)) { s += " not"; }; s += " " + u + ".\n"; }

#ifdef KEY_HANDLER
key keyHandler              = NULL_KEY;
#endif
//key listID                  = NULL_KEY;

integer windMins = 30;

float collapseTime          = 0.0;
float effectiveLimit          = 10800.0;
//float wearLockExpire;
integer wearLock;

string dollGender           = "Female";
string chatPrefix           = "";
string RLVver               = "";
string pronounHerDoll       = "Her";
string pronounSheDoll       = "She";
string dollName             = "";
string msg;

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
#endif
#ifdef DEBUG_MODE
integer debugLevel          = DEBUG_LEVEL;
#endif
integer RLVok               = UNSET;

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

                 if (name == "timeLeftOnKey")           timeLeftOnKey = (float)value;
            else if (name == "collapseTime")             collapseTime = (float)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "timeReporting")           timeReporting = (integer)value;
#endif

            else if (name == "afk")                               afk = (integer)value;
            else if (name == "autoAFK")                       autoAFK = (integer)value;
            else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "blacklist")                   blacklist = split;
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
                else if (name == "controllers")           controllers = split;
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
                    if (demoMode) effectiveLimit = DEMO_LIMIT;
                    else effectiveLimit = keyLimit;
                }
#ifdef DEBUG_MODE
                else if (name == "debugLevel")             debugLevel = (integer)value;
#endif
            }
            else if (name == "isVisible")                     visible = (integer)value;
            //else if (name == "listID")                         listID = (key)value;

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
                    if (!demoMode) effectiveLimit = keyLimit;
                }
            }
            else if (name == "tpLureOnly")                 tpLureOnly = (integer)value;
            else if (name == "windMins")                     windMins = (integer)value;
            //else if (name == "wearLockExpire")         wearLockExpire = (float)value;
            else if (name == "wearLock")                     wearLock = (integer)value;
            else if (name == "windRate")                     windRate = (float)value;
        }

        else if (code == 305) {
            string cmd = llList2String(split, 0);

            if ((cmd == "addMistress") ||
                (cmd == "addBlacklist")) {

                string uuid = llList2String(split, 1);
                string name = llList2String(split, 2);

                integer type;
                string typeString;
                string barString;
                list tmpList;

                // we don't want controllers to be added to the blacklist;
                // likewise, we don't want to allow those on the blacklist
                // to be controllers. barlist represents the "contra" list
                // opposing the added-to list.
                //
                list barList;

                // Initial settings
                if (cmd != "addBlacklist") {
                    typeString = "controller";
                    tmpList = controllers;
                    barList = blacklist;
                }
                else {
                    typeString = "blacklist";
                    tmpList = blacklist;
                    barList = controllers;
                }

                //----------------------------------------
                // VALIDATION
                //
                // #1: Cannot add UUID if prohibited by (found in) barList
                //
                if (llListFindList(barList, [ uuid ]) != NOT_FOUND) {

                    if (cmd != "addBlacklist") msg = name + " is blacklisted; you must first remove them from the blacklist before adding them as a controller.";
                    else msg = name + " is one of your controllers; until they remove themselves from being your controller, you cannot add them to the blacklist.";

                    lmSendToAgentPlusDoll(msg, id);
                    return;
                }

                // #2: Check if UUID exists already in the list (and add if not)
                //
                if (llListFindList(tmpList, [ uuid ]) == NOT_FOUND) {
                    lmSendToAgentPlusDoll("Adding " + name + " as " + typeString, id);
                    tmpList += [ uuid, name ];

                    if (cmd != "addBlacklist") controllers = tmpList;
                    else blacklist = tmpList;
                }
                // Report already found
                else {
                    lmSendToAgentPlusDoll(name + " is already found listed as " + typeString, id);
                }

                // we may or may not have changed either of these - but this code
                // forces a refresh in any case
                lmSendConfig("blacklist",   llDumpList2String(blacklist,   "|") );
                lmSendConfig("controllers", llDumpList2String(controllers, "|") );
            }
            else if ((cmd == "remMistress") ||
                     (cmd == "remBlacklist")) {

                string uuid = llList2String(split, 1);
                string name = llList2String(split, 2);

                integer type;
                string typeString;
                string barString;
                list tmpList;

                // Initial settings
                if (cmd != "remBlacklist") {
                    typeString = "controller";
                    tmpList = controllers;
                }
                else {
                    typeString = "blacklist";
                    tmpList = blacklist;
                }

                if (split = []) {
                    lmSendToAgentPlusDoll("The " + typeString + " list is empty!", id);
                    lmSendConfig("blacklist",   llDumpList2String(blacklist,   "|") );
                    lmSendConfig("controllers", llDumpList2String(controllers, "|") );
                    return;
                }

                // Test for the presence of the UUID in the existing list
                //
                // we are assuming that the uuid/name exists as a valid pair and in that order
                if ((i = llListFindList(tmpList, [ uuid ])) != NOT_FOUND) {

                    lmSendToAgentPlusDoll("Removing key " + name + " from list as " + typeString + ".", id);
                    tmpList = llDeleteSubList(tmpList, i, i + 1);
                }
                else {
                    lmSendToAgentPlusDoll("Key " + uuid + " is not listed as " + typeString, id);
                }

                if (cmd != "remBlacklist") controllers = tmpList;
                else blacklist = tmpList;

                // we may or may not have changed either of these - but this code
                // forces a refresh in any case
                lmSendConfig("blacklist",   llDumpList2String(blacklist,   "|") );
                lmSendConfig("controllers", llDumpList2String(controllers, "|") );
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

        //----------------------------------------
        // CHAT COMMAND CHANNEL
        //----------------------------------------

        if (channel == chatChannel) {
            debugSay(5,"CHAT-DEBUG",("Got a message: " + name + "/" + (string)id + "/" + msg));
            // Deny access to the menus when the command was recieved from blacklisted avatar
            if (!isDoll && (llListFindList(blacklist, [ (string)id ]) != NOT_FOUND)) {
                lmSendToAgent("You are not permitted to access this key.", id);
                return;
            }

            lmInternalCommand("getTimeUpdates","",NULL_KEY);
            llSleep(2);
            debugSay(5,"CHAT-DEBUG",("Got a chat channel message: " + name + "/" + (string)id + "/" + msg));
            string prefix = cdGetFirstChar(msg);

            // Before we proceed first verify that the command is for us.
            //
            // Check prefix:
            //   * All dollies ('*') - respond
            //   * All dollies except us ('#') - respond if we didn't send it
            //   * Prefix ('xx') - respond
            //   * Nothing - assume its ours and complain

            if (prefix == "*") {
                // *prefix is global, strip from choice and continue
                //prefix = llGetSubString(msg,0,0);
                msg = llGetSubString(msg,1,-1);
            }
            else if (prefix == "#") {
                // if Dolly gives a #cmd ignore it...
                // if someone else gives it - they are being ignored themselves,
                //    but we act on it.
                if (isDoll) return;
                else {
                    // #prefix is an all others prefix like with OC etc
                    //prefix = llGetSubString(msg,0,0);
                    msg = llGetSubString(msg,1,-1);
                }
            }
            else if (chatPrefix) {
                integer n = llStringLength(chatPrefix);
                if (llToLower(llGetSubString(msg, 0, n - 1)) == chatPrefix) {
                    prefix = llGetSubString(msg, 0, n - 1);
                    msg = llGetSubString(msg, n, -1);
                }
            }

            // If we got here, it means that the prefix is not "*" or "#" or the chatPrefix...
            // Therefore, if Doll issued the command, Doll needs to be notified of need for prefix
            else if (isDoll) {
                llOwnerSay("Use of chat commands without a prefix is depreciated and will be removed in a future release.");
            }

            // If we got here, it means that the prefix is not "*" or "#" or the chatPrefix...
            // AND it means that the command was issued by someone other than Doll
            // So ignore it
            else return; // For some other doll? noise? matters not it's someone elses problem.

            //debugSay(2, "CHAT-DEBUG", "On #" + (string)channel + " secondlife:///app/agent/" + (string)id + "/about: pre:" + prefix + "(ok) cmd:" + msg + " id:" + (string)id);

            // If we get here, we know this:
            //
            //   * If Doll, they've been warned about the Prefix if needed
            //   * If not Doll, they used the prefix
            //   * If the prefix is '#' someone else used it, not Dolly
            //   * If the prefix is '*' could have been used by anyone

            // Trim message in case there are spaces
            msg = llStringTrim(msg,STRING_TRIM);

            // Is the "msg" an animation?
            if (llGetInventoryType(msg) == INVENTORY_ANIMATION) {
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
                    // It's a pose but from a member of the public
                    if (canPose) cdMenuInject(msg, name, id);
                }
                return;
            }

#define PARAMETERS_EXIST (space != NOT_FOUND)

            //if (isDoll || (!isDoll && canCarry)) { }
            // Choice is a command, not a pose
            integer space = llSubStringIndex(msg, " ");
            string choice = msg;

            if (!PARAMETERS_EXIST) { // Commands without parameters handled first
                choice = llToLower(choice);

                //----------------------------------------
                // PUBLIC COMMAND (help)
                //
                // The help commands should be handled here, as
                // they are adjusted differently for each kind of user
                //   * help
                //
                // Biggest problem in the help commands is that the
                // validation of the user's status has to be replicated in
                // both the help function and in the function itself; if there
                // was a way to combine the help with the functions it would be
                // much better...
                //
                if (choice == "help") {
                    // First: anyone can do these commands
                    string help = "Commands:
    Commands can be prefixed with your prefix, which is currently " + llToLower(chatPrefix) + "\n";

                    // if is Doll or Controller, can do these commands
                    if (isDoll || isController) {
                        help +=
"
    build .......... list build configurations
    detach ......... detach key if possible
    devhelp ........ list of developer commands
    stat ........... concise current status
    stats .......... selected statistics and settings
    xstats ......... extended statistics and settings
    release ........ stop the current pose if possible
    demo ........... toggle demo mode
    [posename] ..... activate the named pose if possible
    poses .......... show Poses menu
    listposes ...... list all poses
    help ........... this list of commands";

                        if (isDoll & canDressSelf) {
                            help += "
    outfits ........ show Outfits menu";
                        }
                    }
                    // Not dolly OR controller...
                    else {
                        if (canDress) {
                            help += "
    outfits ........ show Outfits menu";
                        }

                        if (canPose) {
                            help += "
    poses .......... show Poses menu
    listposes ...... list all poses
    [posename] ..... activate the named pose if possible";
                        }

                        if (canCarry) {
                            help += "
    carry .......... pick up Dolly
    uncarry ........ drop Dolly";
                        }
                    }

                    // wind command changes sense when others use it
                    if (isDoll) {
                        help +=
"
    wind ........... trigger emergency autowind";
                    }
                    else {
                        help +=
"
    carry .......... pick up Dolly
    uncarry ........ drop Dolly
    wind ........... wind key";
                    }

                    help +=
"
    menu ........... show main menu
    types .......... show Types menu";

                    if (isDoll || cdIsBuiltinController(id)) {
                        help +=
"
    channel ## ..... change channel
    prefix XX ...... change chat command prefix
    controller NN .. add controller
    blacklist NN ... add to blacklist
    unblacklist NN . remove from blacklist";
#ifdef WAKESCRIPT
                        help +=
"
    wakescript NN .. wake up script";
#endif
                    }
#ifdef DEBUG_MODE
                    if (isDoll) help +=
"
    debug # ........ set the debugging message verbosity 0-9";
#endif
                    lmSendToAgent(help, id);
                    return;
                }

                //----------------------------------------
                // DOLL & CONTROLLER COMMANDS
                //
                // Commands only for Doll or Controllers
                //   * build
                //   * detach
                //   * xstats
                //   * stat
                //   * stats
                //   * release
                //   * demo
                //
                if (isDoll || isController) {
                    if (choice == "build") {
                        lmConfigReport();
                        return;
                    }
                    else if (choice == "detach") {

                        if (detachable || isController) lmInternalCommand("detach", "", NULL_KEY);
                        else lmSendToAgent("Key can't be detached...", id);

                        return;
                    }
                    else if (choice == "xstats") {
                        string s = "Extended stats:\nDoll is a " + dollType + " Doll.\nAFK time factor: " +
                                   formatFloat(RATE_AFK, 1) + "x\nWind amount: " + (string)windMins + " (mins)\n";

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
                        cdCapability(canRepeat,    "Doll can", "be multiply wound");
                        cdCapability(canDressSelf, "Doll can", "dress by " + p + "self");
                        cdCapability(poseSilence,  "Doll is",  "silenced while posing");
                        cdCapability(wearLock,     "Doll's clothing is",  "currently locked on");

                        if (windRate) s += "Current wind rate is " + formatFloat(windRate,2) + ".\n";
                        else s += "Key is not winding down.\n";

                        if (RLVok == UNSET) s += "RLV status is unknown.\n";
                        else if (RLVok == 1) s += "RLV is active.\nRLV version: " + RLVver;
                        else s += "RLV is not active.\n";

                        lmSendToAgent(s, id);
                        return;
                    }
                    else if (choice == "stat") {
                        //debugSay(6, "DEBUG", "timeLeftOnKey = " + (string)timeLeftOnKey);
                        //debugSay(6, "DEBUG", "effectiveLimit = " + (string)effectiveLimit);
                        //debugSay(6, "DEBUG", "displayWindRate = " + (string)displayWindRate);

                        float t1 = timeLeftOnKey / (SEC_TO_MIN * displayWindRate);
                        float t2 = effectiveLimit / (SEC_TO_MIN * displayWindRate);
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
                        return;
                    }
                    else if (choice == "stats") {
                        //debugSay(6, "DEBUG", "timeLeftOnKey = " + (string)timeLeftOnKey);
                        //debugSay(6, "DEBUG", "effectiveLimit = " + (string)effectiveLimit);
                        //debugSay(6, "DEBUG", "displayWindRate = " + (string)displayWindRate);

                        //displayWindRate;

                        lmSendToAgent("Time remaining: " + (string)llRound(timeLeftOnKey / (SEC_TO_MIN * displayWindRate)) + " minutes of " +
                                    (string)llRound(effectiveLimit / (SEC_TO_MIN * displayWindRate)) + " minutes.", id);

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
                        return;
                    }
                    else if (choice == "release") {
                        string p = llToLower(pronounHerDoll);
                        string s = llToLower(pronounSheDoll);

                        if ((poserID != NULL_KEY) && (poserID != dollID)) llOwnerSay("Dolly tries to wrest control of " + p + " body from the pose but " + s + " is no longer in control of " + p + " form.");
                        else lmMenuReply("Unpose", dollName, dollID);
                        return;
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

                        //llSendToAgent(s,id);
                        llOwnerSay(s);
                        return;
                    }
                }

                //----------------------------------------
                // PUBLIC COMMANDS
                //
                // These are the commands that anyone can give:
                //   * wind
                //   * outfits
                //   * menu
                //   * types
                //   * poses
                //   * listposes
                //   * carry
                //   * uncarry
                //
                if (choice == "wind") {
                    // if Dolly gives this command, its an Emergency Winder activation.
                    // if someone else, it is a normal wind of the Doll.
                    // if a Tester - it is a normal wind (Emergency Winder not available!)

                    if (isDoll) cdMenuInject("Wind Emg", dollName, dollID);
                    else cdMenuInject("Wind", name, id);
                    return;
                }
                else if (choice == "outfits") {
                    if (isDoll) {
                        if (canDressSelf) cdMenuInject("Outfits...", name, id);
                        else lmSendToAgent("You are not allowed to dress yourself",id);
                    }
                    else {
                        if (canDress) cdMenuInject("Outfits...", name, id);
                        else lmSendToAgent("You are not allowed to dress Dolly",id);
                    }

                    return;
                }
                else if (choice == "menu") {
                    cdMenuInject(MAIN, name, id);
                    return;
                }
                else if (choice == "types") {
                    cdMenuInject("Types...", name, id);
                    return;
                }
                else if (choice == "poses") {
                    if (isDoll || isController) cdMenuInject("Poses...", name, id);
                    else {
                        if (canPose) cdMenuInject("Poses...", name, id);
                        else lmSendToAgent("You are not allowed to pose Dolly", id);
                    }
                    return;
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

                                if (keyAnimation == thisPose) lmSendToAgent("\t*\t" + thisPose, id);
                                else lmSendToAgent("\t\t" + thisPose, id);
                            }
                            else if (keyAnimation == thisPose) lmSendToAgent("\t*\t{private}", id);
                        }
                    }
                    return;
                }
                else if (choice == "carry") {
                    if (!isDoll) cdMenuInject("Carry", name, id);
                    return;
                }
                else if (choice == "uncarry") {
                    if (!isDoll) cdMenuInject("Uncarry", name, id);
                    return;
                }
            }
            else {
                // Command has secondary parameter
                string param =           llStringTrim(llGetSubString(choice, space + 1, STRING_END), STRING_TRIM);
                choice       = llToLower(llStringTrim(llGetSubString(   msg,         0,  space - 1), STRING_TRIM));

                //----------------------------------------
                // DOLL & EMBEDDED CONTROLLER COMMANDS (with parameter)
                //
                // Access to these commands for Doll and embedded controllers only:
                //   * channel 999
                //   * controller AAA
                //   * blacklist AAA
                //   * unblacklist AAA
                //   * prefix ZZZ
                //   * wakescript NNNN
                //
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
                        return;
                    }
                    else if (choice == "controller") {
                        lmInternalCommand("addMistress", param, id);
                        return;
                    }
                    else if (choice == "blacklist") {
                        lmInternalCommand("addBlacklist", param, id);
                        return;
                    }
                    else if (choice == "unblacklist") {
                        lmInternalCommand("remBlacklist", param, id);
                        return;
                    }
                    else if (choice == "prefix") {
                        string newPrefix = param;
                        string c1 = llGetSubString(newPrefix,0,0);
                        string msg = "The prefix you entered is not valid, the prefix must ";
                        integer n = llStringLength(newPrefix);

                        // * must be greater than two characters and less than ten characters

                        if (n < 2 || n > 10) {
                            // Why? Two character user prefixes are standard and familiar; too much false positives with
                            // just 1 letter (~4%) with letter + letter/digit it's (~0.1%)
                            lmSendToAgent(msg + "be between two and ten characters long.", id);
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
                            lmSendToAgentPlusDoll("Chat prefix has been changed to " + llToLower(chatPrefix) + " the new prefix should now be used for all commands.", id);
                        }
                        return;
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

                            msg = "Script '" + script + "'";
                            if (llGetScriptState(script)) msg += " seems to be running now.";
                            else msg += " appears to have stopped running again after being restarted.  If you are not getting script errors this may be intentional.";

                            llOwnerSay(msg);
                        }
                        return;
                    }
#endif
                }

                //----------------------------------------
                // DOLL COMMANDS (with parameter)
                //
                // These commands are for dolly ONLY
                //   * debug
                //   * inject
                //   * timereporting
                //
                if (isDoll) {
#ifdef DEBUG_MODE
                    if (choice == "debug") {
                        lmSendConfig("debugLevel", (string)(debugLevel = (integer)param));
                        llOwnerSay("DEBUG_LEVEL = " + (string)debugLevel);
                        return;
                    }
#else
                    ;
#endif
#ifdef DEVELOPER_MODE
                    else if (choice == "inject") {
                        list params = llParseString2List(param, ["#"], []);
                        key paramKey = llList2Key(params,2); // NULL_KEY if not valid
                        string paramData = cdMyScriptName() + "|" + llList2String(params,1);
                        integer paramCode = llList2Integer(params,0);

                        llOwnerSay("INJECT LINK:\nLink Code: " + (string)paramCode +
                                   "\nData: " + paramData +
                                   "\nKey: " + (string)paramKey);
                        llMessageLinked(LINK_THIS, paramCode, paramData, paramKey);
                        return;
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
                        return;
                    }
#endif
                }
            }
        }

#ifdef KEY_HANDLER
        //----------------------------------------
        // KEY HANDLER CHANNEL
        //----------------------------------------

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
