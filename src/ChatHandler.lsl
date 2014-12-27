//========================================
// ChatHandler.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

#define POSES_CMD 1
#include "include/GlobalDefines.lsl"
#define cdMenuInject(a,b,c) lmMenuReply(a,b,c)

#define UNSET -1

#define cdCapability(c,p,u) { s += p; if (!(c)) { s += " not"; }; s += " " + u + ".\n"; }
#define cdListenerActivate(a) llListenControl(a, 1)
#define cdListenerDeactivate(a) llListenControl(a, 0)
#define cdProfileURL(i) "secondlife:///app/agent/"+(string)(i)+"/about"

//key listID                  = NULL_KEY;

integer windMins = 30;
key lastWinderID;
string lastWinderName;

float effectiveLimit          = 10800.0;
//float wearLockExpire;
//flaot winderLockExpire;

string msg;
integer chatEnable           = TRUE;
string chatFilter           = "";
string rlvAPIversion;

integer chatChannel         = 75;
integer chatHandle          = 0;

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
        chatHandle = llListen(chatChannel, "", chatFilter, "");
        cdInitializeSeq();
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer source, integer i, string data, key id) {

        // Parse link message header information
        split             =     cdSplitArgs(data);
        script            =     cdListElement(split, 0);
        remoteSeq         =     (i & 0xFFFF0000) >> 16;
        optHeader         =     (i & 0x00000C00) >> 10;
        code              =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        scaleMem();

        if (code == CONFIG) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);
            string c = cdGetFirstChar(name); // for speedup
            split = llDeleteSubList(split,0,0);

                 if (name == "timeLeftOnKey")           timeLeftOnKey = (float)value;
            else if (name == "collapseTime")             collapseTime = llGetUnixTime() + (float)value;
            else if (name == "windingDown")               windingDown = (integer)value;
            else if (name == "lastWinderID")             lastWinderID = (key)value;
            else if (name == "lastWinderName")         lastWinderName = value;
            else if (name == "collapsed")                   collapsed = (integer)value;
            else if (name == "hardcore")                     hardcore = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "timeReporting")           timeReporting = (integer)value;
#endif

            else if (name == "afk")                               afk = (integer)value;
            else if (name == "autoAFK")                       autoAFK = (integer)value;
            else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "blacklist") {
                if (split == [""]) blacklist = [];
                else blacklist = split;
            }
            else if (name == "busyIsAway")                 busyIsAway = (integer)value;

            // Shortcut: c
            else if (c == "c") {
                     if (name == "canAFK")                     canAFK = (integer)value;
                else if (name == "allowCarry")                 allowCarry = (integer)value;
                else if (name == "allowDress")                 allowDress = (integer)value;
                else if (name == "allowPose")                   allowPose = (integer)value;
                else if (name == "canDressSelf")         canDressSelf = (integer)value;
                else if (name == "canFly")                     canFly = (integer)value;
                else if (name == "canSit")                     canSit = (integer)value;
                else if (name == "canStand")                 canStand = (integer)value;
                else if (name == "allowRepeatWind")       allowRepeatWind = (integer)value;
                else if (name == "configured")             configured = (integer)value;
                else if (name == "controllers") {
                    if (split == [""]) controllers = [];
                    else controllers = split;
                }
                else if (name == "chatEnable") {
                    chatEnable = (integer)value;
                    if (chatEnable) cdListenerActivate(chatHandle);
                    else cdListenerDeactivate(chatHandle);
                }
                else if (name == "chatFilter") {
                    chatFilter = value;
                    llListenRemove(chatHandle);
                    chatHandle = llListen(chatChannel, "", chatFilter, "");
                }
                else if (name == "chatChannel") {
                    chatChannel = (integer)value;
                    dollID = llGetOwner();
                    llListenRemove(chatHandle);
                    chatHandle = llListen(chatChannel, "", chatFilter, "");
                }
            }

            // Shortcut: d
            else if (c == "d") {
                     if (name == "detachable")             detachable = (integer)value;
                else if (name == "dollType")                 dollType = value;
                else if (name == "dollGender")             dollGender = value;
                else if (name == "demoMode") {
                    demoMode = (integer)value;
                    if (demoMode) effectiveLimit = DEMO_LIMIT;
                    else effectiveLimit = keyLimit;
                }
#ifdef DEVELOPER_MODE
                else if (name == "debugLevel")             debugLevel = (integer)value;
#endif
            }
            else if (name == "isVisible")                     visible = (integer)value;
            //else if (name == "listID")                         listID = (key)value;

            // Shortcut: p
            else if (c == "p") {
                     if (name == "poseSilence")           poseSilence = (integer)value;
#ifdef ADULT_MODE
                else if (name == "allowStrip")             allowStrip = (integer)value;
#endif
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
                else if (name == "keyLimit") {
                    keyLimit = (float)value;
                    if (!demoMode) effectiveLimit = keyLimit;
                    else effectiveLimit = DEMO_LIMIT;
                }
            }
            else if (name == "canSelfTP")                   canSelfTP = (integer)value;
            else if (name == "windMins")                     windMins = (integer)value;
            //else if (name == "wearLockExpire")         wearLockExpire = (float)value;
            else if (name == "wearLock")                     wearLock = (integer)value;
            else if (name == "windRate")                     windRate = (float)value;
        }

        else if (code == INTERNAL_CMD) {
            string cmd = llList2String(split, 0);

            if ((cmd == "addMistress") ||
                (cmd == "addBlacklist")) {

                string uuid = llList2String(split, 1);
                string name = llList2String(split, 2);
                debugSay(5,"DEBUG-ADDMISTRESS","Blacklist = " + llDumpList2String(blacklist,"|") + " (" + (string)llGetListLength(blacklist) + ")");

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

                // Dolly can NOT be added to either list
                if (cdIsDoll((key)uuid)) {
                    lmSendToAgent("You can't select Dolly for this list.",(key)uuid);
                    return;
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
                debugSay(5,"DEBUG-ADDMISTRESS","Blacklist = " + llDumpList2String(blacklist,"|") + " (" + (string)llGetListLength(blacklist) + ")");
                lmSetConfig("blacklist",   llDumpList2String(blacklist,   "|") );
                debugSay(5,"DEBUG-ADDMISTRESS","Blacklist = " + llDumpList2String(blacklist,"|") + " (" + (string)llGetListLength(blacklist) + ")");
                lmSetConfig("controllers", llDumpList2String(controllers, "|") );

                debugSay(5,"DEBUG-ADDMISTRESS",   "blacklist >> " + llDumpList2String(blacklist,   ",") + " (" + (string)llGetListLength(blacklist  ) + ")");
                debugSay(5,"DEBUG-ADDMISTRESS", "controllers >> " + llDumpList2String(controllers, ",") + " (" + (string)llGetListLength(controllers) + ")");
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

                //if (split = []) {
                //    lmSendToAgentPlusDoll("The " + typeString + " list is empty!", id);
                //    lmSetConfig("blacklist",   llDumpList2String(blacklist,   "|") );
                //    lmSetConfig("controllers", llDumpList2String(controllers, "|") );
                //    return;
                //}

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
                lmSetConfig("blacklist",   llDumpList2String(blacklist,   "|") );
                lmSetConfig("controllers", llDumpList2String(controllers, "|") );
            }
        }
        else if (code == RLV_RESET) {
            RLVok = llList2Integer(split, 0);
            rlvAPIversion = llList2String(split, 1);
        }
        else if (code < 200) {
            if (code == 110) {
                if (chatPrefix == "") {
                    // If chat prefix is not configured elsewhere, we default to
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
            }
            else if (code == 142) {

                cdConfigureReport();
            }
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
            // Deny access to the menus when the command was recieved from blacklisted avatar
            if (!isDoll && (llListFindList(blacklist, [ (string)id ]) != NOT_FOUND)) {
                //lmSendToAgent("You are not permitted to access this key.", id);
                return;
            }

            lmInternalCommand("getTimeUpdates","",NULL_KEY);
            debugSay(5,"DEBUG-CHAT",("Got a chat channel message: " + name + "/" + (string)id + "/" + msg));
            //msg = llToLower(msg);
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
            else {
                integer n = llStringLength(chatPrefix);
                if (llToLower(llGetSubString(msg, 0, n - 1)) == chatPrefix) {
                    prefix = llGetSubString(msg, 0, n - 1);
                    msg = llGetSubString(msg, n, -1);
                }
                else
                    // we didn't get a valid prefix - so exit. Either it's
                    // for another dolly, or it was invalid. If we act on a general
                    // command - then every dolly in range with this key will respond.
                    // Can't have that...

                    return;

            }

            // If we get here, we know this:
            //
            //   * If Doll, they've been warned about the Prefix if needed
            //   * If not Doll, they used the prefix
            //   * If the prefix is '#' someone else used it, not Dolly
            //   * If the prefix is '*' could have been used by anyone

            // Trim message in case there are spaces
            msg = llStringTrim(msg,STRING_TRIM);

#define PARAMETERS_EXIST (space != NOT_FOUND)

            //if (isDoll || (!isDoll && allowCarry)) { }
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
    Commands can be prefixed with your prefix, which is currently " + llToLower(chatPrefix) + "
    help ........... this list of commands";
                    string menus = "Menu Commands:

    Use these commands to trigger menus:\n";

                    // if is Doll or Controller, can do these commands
                    if (isDoll || isController) {
                        help +=
"
    build .......... list build configurations
    detach ......... detach key if possible
    stat ........... concise current status
    stats .......... selected statistics and settings
    xstats ......... extended statistics and settings
    release ........ stop the current pose if possible
    demo ........... toggle demo mode
    [posename] ..... activate the named pose if possible
    listposes ...... list all poses";
                        menus +=
"
    poses .......... show Poses menu";

                        // accessor is either Doll or controller so...
                        if (isDoll) {
                            if (canDressSelf)
                                menus += "
    outfits ........ show Outfits menu";
                        }
                        // is Controller, but NOT Doll
                        else
                            menus += "
    outfits ........ show Outfits menu";
                    }
                    // Not dolly OR controller...
                    else {
                        if (allowDress) {
                            menus += "
    outfits ........ show Outfits menu";
                        }

                        if (allowPose) {
                            menus +=
"
    poses .......... show Poses menu";
                            help += "
    listposes ...... list all poses
    [posename] ..... activate the named pose if possible";
                        }

                        if (allowCarry) {
                            help += "
    carry .......... pick up Dolly
    uncarry ........ drop Dolly";
                        }
                    }

                    // wind command changes sense when others use it
                    if (isDoll) {
                        if (!hardcore)
                            help +=
"
    wind ........... trigger emergency autowind";
                    }
                    else {
                        help +=
"
    wind ........... wind key";
                    }

                    menus +=
"
    menu ........... show main menu
    types .......... show Types menu
    options ........ show Options menu";

                    if (isDoll || cdIsBuiltinController(id)) {
                        help +=
"
    channel ## ..... change channel
    prefix XX ...... change chat command prefix
    controller NN .. add controller
    blacklist NN ... add to blacklist
    unblacklist NN . remove from blacklist";
                    }
                    lmSendToAgent(help + "\n", id);
                    lmSendToAgent(menus + "\n", id);

#ifdef DEVELOPER_MODE
                    if (isDoll) help =
"
    Debugging commands:

    debug # ........ set the debugging message verbosity 0-9
    timereporting .. set timereporting \"on\" or \"off\"
    powersave ...... turn on powersave mode
    inject x#x#x ... inject a link message with \"code#data#key\"
    collapse ....... perform an immediate collapse (out of time)";
#endif
                    lmSendToAgent(help + "\n", id);
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
                        string s = "Extended stats:\n\nDoll is a " + dollType + " Doll.\nAFK time factor: " +
                                   formatFloat(RATE_AFK, 1) + "x\nWind amount: " + (string)windMins + " (mins)\n";

                        if (demoMode) s += "Demo mode is enabled";

                        string p = llToLower(pronounHerDoll);

                        cdCapability(autoTP,         "Doll can", "be force teleported");
                        cdCapability(detachable,     "Doll can", "detach " + p + " key");
                        cdCapability(allowPose,        "Doll can", "be posed by the public");
                        cdCapability(allowDress,       "Doll can", "be dressed by the public");
                        cdCapability(allowCarry,       "Doll can", "be carried by the public");
                        cdCapability(canAFK,         "Doll can", "go AFK");
                        cdCapability(canFly,         "Doll can", "fly");
                        cdCapability(canSit,         "Doll can", "sit");
                        cdCapability(canStand,       "Doll can", "stand");
                        cdCapability(allowRepeatWind,  "Doll can", "be multiply wound");
                        cdCapability(canDressSelf,   "Doll can", "dress by " + p + "self");
                        cdCapability(poseSilence,    "Doll is",  "silenced while posing");
                        cdCapability(wearLock,       "Doll's clothing is",  "currently locked on");
                        cdCapability(lowScriptMode,  "Doll is",  "currently in powersave mode");

                        if (windingDown) s += "\nCurrent wind rate is " + formatFloat(windRate,2) + ".\n";
                        else s += "Key is not winding down.\n";

                        if (RLVok == UNSET) s += "RLV status is unknown.\n";
                        else if (RLVok == 1) s += "RLV is active.\nRLV version: " + rlvAPIversion;
                        else s += "RLV is not active.\n";

                        if (lastWinderID) s += "Last winder was " + cdProfileURL(lastWinderID);
                        if (lastWinderName) s += " (" + lastWinderName + ")";
                        s += "\n";

                        lmSendToAgent(s, id);
                        return;
                    }
                    else if (choice == "stat") {
                        float t1 = timeLeftOnKey / (SEC_TO_MIN * windRate);
                        float t2 = effectiveLimit / (SEC_TO_MIN * windRate);
                        float p = t1 * 100.0 / t2;

                        string msg = "Time: " + (string)llRound(t1) + "/" +
                                    (string)llRound(t2) + " min (" + formatFloat(p, 2) + "% capacity)";

                        if (windingDown) {
                            msg += " unwinding at a ";

                            if (windRate == 1.0) msg += "normal rate.";
                            else {
                                if (windRate < 1.0) msg += "slowed rate of ";
                                else if (windRate > 1.0) msg += "accelerated rate of ";

                                msg += " of " + formatFloat(windRate, 1) + "x.";
                            }

                        } else msg += " and key is currently stopped.";
                        if (demoMode) msg += " (Demo mode active.)";

                        lmSendToAgent(msg, id);
                        return;
                    }
                    else if (choice == "stats") {
                        lmSendToAgent("Time remaining: " + (string)llRound(timeLeftOnKey / (SEC_TO_MIN * windRate)) + " minutes of " +
                                    (string)llRound(effectiveLimit / (SEC_TO_MIN * windRate)) + " minutes.", id);

                        string msg;

                        if (!windingDown) msg = "Key is stopped.";
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

                        if (!cdCollapsedAnim() && cdAnimated()) {
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
                            if (timeLeftOnKey > DEMO_LIMIT) lmSetConfig("timeLeftOnKey", (string)(timeLeftOnKey = DEMO_LIMIT));
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
#ifdef ADULT_MODE
                    else if (choice == "hardcore") {

                        // if hardcore is set, only a controller other than
                        // Dolly can clear it. If hardcore is clear - only
                        // Dolly can set it.

                        if (hardcore) {
                            if (isController && !isDoll)
                                lmSendConfig("hardcore",(string)(hardcore = 0));
                        }
                        else {
                            if (isDoll)
                                lmSendConfig("hardcore",(string)(hardcore = 1));
                        }
                    }

#endif
#ifdef DEVELOPER_MODE
                    else if (choice == "collapse" && isDoll) {
                        lmSetConfig("timeLeftOnKey","10");
                        llOwnerSay("Immediate collapse triggered: ten seconds to collapse");
                        return;
                    }
                    else if (choice == "powersave" && isDoll) {
                        lmSetConfig("lowScriptMode","1");
                        llOwnerSay("Power-save mode initiated");
                        return;
                    }
#endif
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

                    if (isDoll) {
                        if (hardcore) return;
                        if (collapsed) {
                            if ((llGetUnixTime() - collapseTime) > TIME_BEFORE_EMGWIND) {
                                cdMenuInject("Wind Emg", dollName, dollID);
                            }
                            else {
#ifdef DEVELOPER_MODE
                                lmSendToAgentPlusDoll("Emergency detection circuits detect developer access override; emergency winder activated",id);
                                cdMenuInject("Wind Emg", dollName, dollID);
#else
                                lmSendToAgent("Emergency not detected; emergency winder is inactive",id);
#endif
                            }
                        }
                        else {
                            lmSendToAgent("Dolly is not collapsed; emergency winder is inactive",id);
                        }
                    }
                    else cdMenuInject("Wind", name, id);
                    return;
                }
                else if (choice == "outfits") {
                    if (isDoll) {
                        if (canDressSelf) cdMenuInject("Outfits...", name, id);
                        else lmSendToAgent("You are not allowed to dress yourself",id);
                    }
                    else {
                        if (allowDress) cdMenuInject("Outfits...", name, id);
                        else lmSendToAgent("You are not allowed to dress Dolly",id);
                    }

                    return;
                }
                else if (choice == "menu") {
                    cdMenuInject(MAIN, name, id);
                    return;
                }
                else if (choice == "options") {
                    cdMenuInject("Options...", name, id);
                    return;
                }
                else if (choice == "types") {
                    cdMenuInject("Types...", name, id);
                    return;
                }
                else if (choice == "poses") {
                    if (isDoll || isController) cdMenuInject("Poses...", name, id);
                    else {
                        if (allowPose) cdMenuInject("Poses...", name, id);
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
                    if (!isDoll && allowCarry) cdMenuInject("Carry", name, id);
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

                            if (ch > 0) lmSendConfig("chatChannel",(string)ch);
                            else lmSendToAgent("Invalid channel (" + (string)ch + ") ignored",id);
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
                }

                //----------------------------------------
                // DOLL COMMANDS (with parameter)
                //
                // These commands are for dolly ONLY
                //   * debug
                //   * inject
                //   * timereporting
                //   * collapse
                //
                if (isDoll) {
                    if (choice == "gname") {
                        string doubledSymbols = "❦❦⌘⌘ѽѽ☄☄✰✰++₪₪קק¤¤øøღღ°°♫♫✿✿▫▫▪▪♬♬♩♩♪♪♬♬‘‘°°ººةة..,,==--++^^**˜˜••..  ¤¤øø””ﺴﺴ☊☊☩☩´´⇝⇝⁘⁘⁙⁙⁚⁚⁛⁛↑↑↓↓☆☆★★··..¸¸❤❤";
                        string pairedSymbols = "<>()[]{}?؟\/";
                        string allSymbols;
                        string s1;
                        string s2;
                        integer n;
                        string c;
                        integer i;

                        allSymbols = doubledSymbols + pairedSymbols;
                        i = 8;
                        while (i--) {
                            n = (integer)(llFrand(llStringLength(allSymbols)));
                            s1 = s1 + llGetSubString(allSymbols,n,n);

                            n = n ^ 1;
                            s2 = llGetSubString(allSymbols,n,n) + s2;
                        }
                        llSay(PUBLIC_CHANNEL,s1 + " " + param + " " + s2);
                    }
#ifdef DEVELOPER_MODE
                    else if (choice == "debug") {
                        lmSendConfig("debugLevel", (string)(debugLevel = (integer)param));
                        llOwnerSay("Debug level set to " + (string)debugLevel);
                        return;
                    }
                    else if (choice == "inject") {
                        list params = llParseString2List(param, ["#"], []);
                        key paramKey = llList2Key(params,2); // NULL_KEY if not valid
                        string paramData = "ChatHandler|" + llList2String(params,1);
                        integer paramCode = llList2Integer(params,0);
                        string s;

                        llOwnerSay("Injected link message code " + (string)paramCode + " with data " + (string)paramData + " and key " + (string)paramKey);
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

#ifdef POSES_CMD
            // Is the "msg" an animation? (and skip the "collapse" animation entirely)
            if (msg != "collapse") {
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
                        if (allowPose) cdMenuInject(msg, name, id);
                    }
                    return;
                }
            }
#endif
        }
    }
}

//========== CHATHANDLER ==========
