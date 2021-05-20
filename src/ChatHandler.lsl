//========================================
// ChatHandler.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

#include "include/GlobalDefines.lsl"
#define cdMenuInject(a,b,c) lmMenuReply(a,b,c)

#define RUNNING 1
#define NOT_RUNNING 0
#define UNSET -1
#define cdStopScript(a) llSetScriptState(a, NOT_RUNNING)
#define cdRunScript(a) llSetScriptState(a, RUNNING)
#define cdResetKey() llResetOtherScript("Start")

#define cdCapability(c,p,u) { s += p; if (!(c)) { s += " not"; }; s += " " + u + ".\n"; }
#define cdListenerActivate(a) llListenControl(a, 1)
#define cdListenerDeactivate(a) llListenControl(a, 0)
#define cdProfileURL(i) "secondlife:///app/agent/"+(string)(i)+"/about"

key lastWinderID;

string msg;
integer chatEnable           = TRUE;
//key chatFilter;
string rlvAPIversion;

integer chatHandle          = 0;

default {
    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        dollID = llGetOwner();
        keyID = llGetKey();
        dollName = dollyName();
        myName = llGetScriptName();

        // Beware listener is now available to users other than the doll
        // make sure to take this into account within all handlers.
        chatHandle = llListen(chatChannel, "", "", "");
        cdInitializeSeq();
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer source, integer i, string data, key id) {

        // Parse link message header information
        split             =     cdSplitArgs(data);
        script            =     (string)split[0];
        remoteSeq         =     (i & 0xFFFF0000) >> 16;
        optHeader         =     (i & 0x00000C00) >> 10;
        code              =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        if (code == SEND_CONFIG) {
            string name = (string)split[0];
            string value = (string)split[1];
            string c = cdGetFirstChar(name); // for speedup
            split = llDeleteSubList(split,0,0);

                 if (name == "timeLeftOnKey")     timeLeftOnKey = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "timeReporting")     timeReporting = (integer)value;
#endif
            else if (name == "hardcore")               hardcore = (integer)value;
            else if (name == "RLVok")                     RLVok = (integer)value;
            else if (name == "blacklist") {
                if (split == [""]) blacklist = [];
                else blacklist = split;
            }

            //----------------------------------------
            // Shortcut: a
            else if (c == "a") {
                     if (name == "allowRepeatWind")   allowRepeatWind = (integer)value;
#ifdef EMERGENCY_TP
                else if (name == "autoTP")                     autoTP = (integer)value;
#endif
#ifdef ADULT_MODE
                else if (name == "allowStrip")             allowStrip = (integer)value;
#endif
                else if (name == "allowCarry")             allowCarry = (integer)value;
                else if (name == "allowDress")             allowDress = (integer)value;
                else if (name == "allowPose")               allowPose = (integer)value;
            }

            //----------------------------------------
            // Shortcut: c
            else if (c == "c") {
                     if (name == "collapsed")               collapsed = (integer)value;
                else if (name == "canDressSelf")         canDressSelf = (integer)value;
                else if (name == "canFly")                     canFly = (integer)value;
                else if (name == "canSit")                     canSit = (integer)value;
                else if (name == "canStand")                 canStand = (integer)value;
                else if (name == "canSelfTP")               canSelfTP = (integer)value;
                else if (name == "carrierID")               carrierID = (key)value;
                else if (name == "carrierName")           carrierName = value;
                else if (name == "configured")             configured = (integer)value;
                else if (name == "collapseTime")         collapseTime = (integer)value;
                else if (name == "controllers") {
                    if (split == [""]) controllers = [];
                    else controllers = split;
                }
            }

            //----------------------------------------
            // Shortcut: d
            else if (c == "d") {
                     //if (name == "detachable")             detachable = (integer)value;
                     if (name == "dollType")                 dollType = value;
                else if (name == "dollGender")             dollGender = value;
                else if (name == "dollDisplayName")   dollDisplayName = value;
#ifdef DEVELOPER_MODE
                else if (name == "debugLevel")             debugLevel = (integer)value;
#endif
            }
            else if (name == "lastWinderID")         lastWinderID = (key)value;

            //----------------------------------------
            // Shortcut: p
            else if (c == "p") {
                     if (name == "poseSilence")           poseSilence = (integer)value;
                else if (name == "poseAnimation")       poseAnimation = value;
                else if (name == "poserID")                   poserID = (key)value;
                else if (name == "poserName")               poserName = value;
                else if (name == "pronounHerDoll")     pronounHerDoll = value;
                else if (name == "pronounSheDoll")     pronounSheDoll = value;
            }

            else if (name == "keyLimit")             keyLimit = (integer)value;

            //----------------------------------------
            // Shortcut: w
            else if (c == "w") {
                     if (name == "wearLock")                 wearLock = (integer)value;
                else if (name == "windRate")                 windRate = (float)value;
                else if (name == "windNormal")             windNormal = (integer)value;
            }
        }
        else if (code == SET_CONFIG) {
            string setName = (string)split[0];
            string value = (string)split[1];

            if (setName == "chatChannel") {
                // Change listening chat channel

                // if the current chatChannel is zero it cannot be changed
                if (chatChannel == 0) return;

                integer newChatChannel = (integer)value;

                // Time saver
                if (newChatChannel == chatChannel) return;

                if (newChatChannel != DEBUG_CHANNEL) {
                    // Note that setting the chat channel to 0 (PUBLIC) is valid:
                    // it isn't used as a channel, but as a flag for a disabled channel
                    chatChannel = newChatChannel;

#ifdef DEVELOPER_MODE
                    debugSay(5,"DEBUG-CHATHANDLER","Changed chat channel to " + (string)(chatChannel));
#endif

                    // Reset chat channel with new channel number
                    llListenRemove(chatHandle);
                    chatHandle = llListen(chatChannel, "", "", "");
                    lmSendConfig("chatChannel",(string)chatChannel);
                }
                else {
                    llSay(DEBUG_CHANNEL,"Attempted to set channel to invalid value!");
                }
            }
        }
        else if (code == INTERNAL_CMD) {
            string cmd = (string)split[0];

            if ((cmd == "addController") ||
                (cmd == "addBlacklist")) {

                string uuid = (string)split[1];
                string name = (string)split[2];
                string nameURI = "secondlife:///app/agent/" + uuid + "/displayname";

                debugSay(5,"DEBUG-ADDMISTRESS","Blacklist = " + llDumpList2String(blacklist,"|") + " (" + (string)llGetListLength(blacklist) + ")");
                if (name == "") {
                    llSay(DEBUG_CHANNEL,"No name alloted with this user.");
                    name == (string)(uuid);
                }

                integer type;
                string typeString;
                string barString;
                list tmpList;

                // we don't want controllers to be added to the blacklist;
                // likewise, we don't want to allow those on the blacklist to
                // be controllers. barlist represents the "contra" list
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
                    cdSayTo("You can't select Dolly for this list.",(key)uuid);
                    return;
                }

                //----------------------------------------
                // VALIDATION
                //
                // #1a: Cannot add UUID as controller if found in blacklist
                // #1b: Cannot blacklist UUID if found in controllers list
                //
                if (llListFindList(barList, [ uuid ]) != NOT_FOUND) {

                    if (cmd != "addBlacklist") msg = nameURI + " is blacklisted; you must first remove them from the blacklist before adding them as a controller.";
                    else msg = nameURI + " is one of your controllers; until they remove themselves from being your controller, you cannot add them to the blacklist.";

                    cdSayTo(msg, id);
                    return;
                }

                // #2: Check if UUID exists already in the list (and add if not)
                //
                string s;

                if (llListFindList(tmpList, [ uuid ]) == NOT_FOUND) {
                    s = "Adding " + nameURI + " as " + typeString;
                    cdSayToAgentPlusDoll(s, id);
                    tmpList += [ uuid, name ];

                    if (cmd == "addBlacklist") {
                        blacklist = tmpList;
                    }
                    else {
                        controllers = tmpList;
                        // Controllers get added to the exceptions
                        llOwnerSay("@tplure:"    + uuid + "=add," +
                                    "accepttp:"  + uuid + "=add," +
                                    "sendim:"    + uuid + "=add," +
                                    "recvim:"    + uuid + "=add," +
                                    "recvchat:"  + uuid + "=add," +
                                    "recvemote:" + uuid + "=add");
                    }
                }
                // Report already found
                else {
                    cdSayTo(nameURI + " is already found listed as " + typeString, id);
                }

                // we may or may not have changed either of these - but this code
                // forces a refresh in any case
                lmSetConfig("blacklist",   llDumpList2String(blacklist,   "|") );
                lmSetConfig("controllers", llDumpList2String(controllers, "|") );

                debugSay(5,"DEBUG-ADDMISTRESS",   "blacklist >> " + llDumpList2String(blacklist,   ",") + " (" + (string)llGetListLength(blacklist  ) + ")");
                debugSay(5,"DEBUG-ADDMISTRESS", "controllers >> " + llDumpList2String(controllers, ",") + " (" + (string)llGetListLength(controllers) + ")");
            }
            else if ((cmd == "remController") ||
                     (cmd == "remBlacklist")) {

                string uuid = (string)split[1];
                string name = (string)split[2];

                if (name == "") {
                    llSay(DEBUG_CHANNEL,"No name alloted with this user.");
                    name == (string)(uuid);
                }

                integer type;
                string typeString;
                string barString;
                list tmpList;
                string nameURI = "secondlife:///app/agent/" + uuid + "/displayname";

                // Initial settings
                if (cmd != "remBlacklist") {
                    typeString = "controller";
                    tmpList = controllers;
                }
                else {
                    typeString = "blacklist";
                    tmpList = blacklist;
                }

                // Test for presence of uuid in list: if it's not there, we can't remove it
                string s;
                if ((i = llListFindList(tmpList, [ uuid ])) != NOT_FOUND) {

                    s = "Removing key " + nameURI + " from list as " + typeString + ".";
                    cdSayToAgentPlusDoll(s, id);

                    tmpList = llDeleteSubList(tmpList, i, i + 1);
                }
                else {
                    cdSayTo("Key " + uuid + " is not listed as " + typeString, id);
                }

                if (cmd == "remBlacklist") {
                    blacklist = tmpList;
                }
                else {
                    controllers = tmpList;
                    // because we cant remove by UUID, a complete redo of
                    // exceptions is necessary
                    lmInternalCommand("reloadExceptions",script,NULL_KEY);
                }

                // we may or may not have changed either of these - but this code
                // forces a refresh in any case
                lmSetConfig("blacklist",   llDumpList2String(blacklist,   "|") );
                lmSetConfig("controllers", llDumpList2String(controllers, "|") );
            }
        }
        else if (code == RLV_RESET) {
            RLVok = (integer)split[0];
            rlvAPIversion = (string)split[1];
        }
        else if (code < 200) {
            if (code == INIT_STAGE5) {
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
#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                memReport(myName,(float)split[0]);
            }
#endif
            else if (code == CONFIG_REPORT) {

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
        //  chatCommand = filter by specific message

        // This makes chat commands work correctly and be properly identified and tracked
        // back to an actual agent even if an intermediary is used. this prevents such as
        // blacklist circumvention and saves a more complex ifAvatar test being needed.
        //
        // Accepting commands in this way also offers several potential advantages:
        // - Works in the presense of renamers or other scripted chat redirection.
        // - Keeps open the potential ability to extend functionality with other objects
        //   a basic HUD for doll showing basic status info and with quick access menu buttons
        //   for example (Makes a note to github that thought).

        //----------------------------------------
        // CHAT COMMAND CHANNEL
        //----------------------------------------

        if (channel == chatChannel) {
            key accessorID = id;
            string accessorName = llGetDisplayName(id); // get name of person sending chat command
            integer accessorIsDoll = cdIsDoll(id);
            integer accessorIsController = cdIsController(id);

            // Deny access to the menus when the command was recieved from blacklisted avatar
            if (!accessorIsDoll && (llListFindList(blacklist, [ (string)id ]) != NOT_FOUND)) {
                llOwnerSay("SECURITY WARNING! Attempted chat channel access by blacklisted user " + accessorName);
                return;
            }

            debugSay(5,"DEBUG-CHAT",("Got a chat channel message: " + accessorName + "/" + (string)id + "/" + msg));
            string prefix = cdGetFirstChar(msg);

            // Before we proceed first verify that the command is for us.
            //
            // Check prefix:
            //   * All dollies ('*') - respond
            //   * All dollies except us ('#') - respond if we didn't send it
            //   * Prefix ('xx') - respond
            //   * Nothing - assume its ours and complain

            if (prefix == "*") {
                // *prefix is global, strip from chatCommand and continue
                msg = llGetSubString(msg,1,-1);
            }
            else if (prefix == "#") {
                // if Dolly gives a #cmd ignore it...
                // if someone else gives it - they are being ignored themselves,
                //    but we act on it.
                if (accessorIsDoll) return;
                else {
                    // #prefix is an all others prefix like with OC etc
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

            // Choice is a command, not a pose
            integer space = llSubStringIndex(msg, " ");
            string chatCommand = msg;

            if (!PARAMETERS_EXIST) { // Commands without parameters handled first
                chatCommand = llToLower(chatCommand);

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
                if (chatCommand == "help") {
                    // First: anyone can do these commands
                    string help = "Commands:
    Commands need to be prefixed with the prefix, which is currently " + llToLower(chatPrefix) + "

    help ........... this list of commands
    menu ........... show main menu
    stat ........... concise current status";
                    string help2;

                    if (accessorIsDoll || accessorIsController) {
                        help += "
    build .......... list build configurations
    detach ......... detach key if possible
    stats .......... selected statistics and settings
    xstats ......... extended statistics and settings
    hide ........... make key invisible
    unhide ......... make key visible
    show ........... make key visible
    visible ........ make key visible
    ghost .......... make key visible and ghostly
    release ........ stop the current pose if possible
    unpose ......... stop the current pose if possible
    [posename] ..... activate the named pose if possible
    listposes ...... list all poses
    channel ## ..... change channel
    prefix XX ...... change chat command prefix
    controller NN .. add controller";

                        //----------------------------------------
                        // Dolly Help
                        if (accessorIsDoll) {
                            help2 += "Commands (page2):

    blacklist NN ... add to blacklist
    unblacklist NN . remove from blacklist";

#ifdef EMERGENCY_WIND
                            if (!hardcore) help += "
    wind ........... trigger emergency autowind";
#endif
                        }

                        //----------------------------------------
                        // Controller Help
                        else {
                            help2 += "Commands (page2):

    carry .......... carry dolly
    uncarry ........ put down dolly
    wind ........... wind key";
                        }
                    }

                    //----------------------------------------
                    // Public Help
                    else {
                        help += "
    wind ........... wind key";

                        if (allowPose || hardcore) {
                            help += "
    listposes ...... list all poses
    release ........ stop the current pose if possible
    unpose ......... stop the current pose if possible
    [posename] ..... activate the named pose if possible";
                        }

                        if (allowCarry || hardcore) {
                            help += "
    carry .......... carry dolly
    uncarry ........ put down dolly";
                        }
                    }

                    cdSayTo(help + "\n", accessorID);
                    if (help2 != "") cdSayTo(help2 + "\n", accessorID);

#ifdef DEVELOPER_MODE
                    if (accessorIsDoll) {
                        help = "
    Debugging commands:

    debug # ........ set the debugging message verbosity 0-9
    timereporting .. set timereporting \"on\" or \"off\"
    inject x#x#x ... inject a link message with \"code#data#key\"
    powersave ...... trigger a powersave event
    collapse ....... perform an immediate collapse (out of time)";
                        cdSayTo(help + "\n", accessorID);
                    }
#endif
                    return;
                }

                //----------------------------------------
                // DOLL & CONTROLLER COMMANDS
                //
                // Commands only for Doll or Controllers
                //   * build
                //   * detach
                //   * xstats
                //   * update
                //   * stat
                //   * stats
                //   * release/unpose
                //   * hardcore (ADULT_MODE)
                //   * collapse (DEVELOPER_MODE)
                //   * powersave (DEVELOPER_MODE)
                //   * hide
                //   * unhide / show / visible
                //   * ghost
                //
                if (accessorIsDoll || accessorIsController) {
                    if (chatCommand == "build") {
                        lmConfigReport();
                        return;
                    }
                    else if (chatCommand == "update") {

                        //llSay(PUBLIC_CHANNEL,"Update starting...");
                        lmSendConfig("update", "1");
                        return;
                    }
                    else if (chatCommand == "xstats") {
                        if (accessorIsDoll && hardcore) return;
                        string s = "Extended stats:\n\nDoll is a " + dollType + " Doll.\nWind amount: " +
                                   (string)llFloor(windNormal / SECS_PER_MIN) + " (mins)\nKey Limit: " +
                                   (string)(keyLimit / SECS_PER_MIN) + " mins\nEmergency Winder Recharge Time: " +
                                   (string)(EMERGENCY_LIMIT_TIME / 60 / (integer)SECS_PER_MIN) + " hours\nEmergency Winder: ";

                        float windEmergency;
                        windEmergency = keyLimit * 0.2;
                        if (hardcore) { if (windEmergency > 120) windEmergency = 120; }
                        else { if (windEmergency > 600) windEmergency = 600; }

                        s += (string)((integer)(windEmergency / SECS_PER_MIN)) + " mins\n";

#ifdef EMERGENCY_TP
                        cdCapability(autoTP,           "Doll can", "be force teleported");
#endif
                        cdCapability(canFly,           "Doll can", "fly");
                        cdCapability(canSit,           "Doll can", "sit");
                        cdCapability(canStand,         "Doll can", "stand");
                        cdCapability(allowRepeatWind,  "Doll can", "be multiply wound");
                        cdCapability(wearLock,         "Doll's clothing is",  "currently locked on");
                        cdCapability(lowScriptMode,    "Doll is",  "currently in powersave mode");

                        cdCapability(hardcore,         "Doll is", "currently in hardcore mode");

                        // These settings all are affected by hardcore
                        //cdCapability((detachable && !hardcore),    "Doll can", "detach " + pronounHerDoll + " key");
                        cdCapability((allowPose || hardcore),      "Doll can", "be posed by the public");
                        cdCapability((allowDress || hardcore),     "Doll can", "be dressed by the public");
                        cdCapability((allowCarry || hardcore),     "Doll can", "be carried by the public");
                        cdCapability((canDressSelf && !hardcore),  "Doll can", "dress by " + pronounHerDoll + "self");
                        cdCapability((poseSilence || hardcore),    "Doll is",  "silenced while posing");

                        if (windRate > 0) s += "\nCurrent wind rate is " + formatFloat(windRate,2) + ".\n";
                        else s += "Key is not winding down.\n";

                        if (RLVok == UNSET) s += "RLV status is unknown.\n";
                        else if (RLVok == TRUE) s += "RLV is active.\nRLV version: " + rlvAPIversion;
                        else s += "RLV is not active.\n";

                        if (lastWinderID) {
                            s += "\nLast winder was " + cdProfileURL(lastWinderID);
#ifdef SELF_WIND
                            s += " (someone else will have to wind next)";
#endif
                        }
                        if (allowCarry) {
                            if (carrierID) {
                                s += "\nDolly is currently being carried by " + cdProfileURL(carrierID);
                            }
                            else {
                                s += "\nDolly is not currently being carried.";
                            }
                        }
                        s += "\n";

                        s += "\nChat channel = " + (string)chatChannel;
                        s += "\nChat prefix = " + chatPrefix;

                        cdSayTo(s, accessorID);
                        return;
                    }
                    else if (chatCommand == "stats") {
                        if (accessorIsDoll && hardcore) return;
                        cdSayTo("Time remaining: " + (string)llRound(timeLeftOnKey / (SECS_PER_MIN * windRate)) + " minutes of " +
                                    (string)llRound(keyLimit / (SECS_PER_MIN * windRate)) + " minutes.", accessorID);

                        string msg;

                        if (windRate == 0) msg = "Key is stopped.";
                        else {
                            msg = "Key is unwinding at a ";

                            if (windRate == 1.0) msg += "normal rate.";
                            else {
                                if (windRate < 1.0) msg += "slowed rate of ";
                                else if (windRate > 1.0) msg += "accelerated rate of ";

                                msg += " of " + formatFloat(windRate, 1) + "x.";
                            }

                        }

                        cdSayTo(msg, accessorID);

                        if (poseAnimation != ANIMATION_NONE) {
                        //    llOwnerSay(dollID, "Current pose: " + currentAnimation);
                        //    llOwnerSay(dollID, "Pose time remaining: " + (string)(poseTime / SECS_PER_MIN) + " minutes.");
                            llOwnerSay("Doll is posed.");
                        }

                        lmMemReport(1.0,accessorID);
                        return;
                    }
#ifdef ADULT_MODE
                    else if (chatCommand == "hardcore") {

                        // if hardcore is set, only a controller other than
                        // Dolly can clear it. If hardcore is clear - only
                        // Dolly can set it.

                        if (hardcore) {
                            if (accessorIsController && !accessorIsDoll) {
                                lmSendConfig("hardcore",(string)(hardcore = 0));
                                cdSayTo("Doll's hardcore mode has been disabled. The sound of a lock unlocking is heard.",accessorID);
                            }
                        }
                        else {
                            if (accessorIsDoll) {
                                lmSendConfig("hardcore",(string)(hardcore = 1));
                                cdSayTo("Doll's hardcore mode has been enabled. The sound of a lock closing is heard.",accessorID);
                            }
                            else {
                                cdSayTo("You rattle the lock, but it is securely fastened: you cannot disable hardcore mode.",accessorID);
                            }
                        }
                        return;
                    }

#endif
#ifdef DEVELOPER_MODE
                    else if (chatCommand == "collapse") {
                        if (accessorIsDoll) {
                            //lmSetConfig("timeLeftOnKey","10");
                            llOwnerSay("Immediate collapse triggered...");
                            lmInternalCommand("collapse", (string)TRUE, accessorID);
                        }
                        return;
                    }
                    else if (chatCommand == "powersave") {
                        if (accessorIsDoll) {
                            lmSetConfig("lowScriptMode","1");
                            llOwnerSay("Power-save mode initiated");
                        }
                        return;
                    }
#endif
                    // Could potentially combine the next three into one
                    // block but the code to account for the differences
                    // may not be worth it.
                    //
                    else if (chatCommand == "hide") {
                        visible = FALSE;

                        cdSayTo("The key shimmers, then fades from view.",accessorID);
                        llSetLinkAlpha(LINK_SET, 0.0, ALL_SIDES);
                        lmSendConfig("isVisible", (string)visible);
                        return;
                    }
                    else if (chatCommand == "unhide" || chatCommand == "show" || chatCommand == "visible") {
                        visible = TRUE;

                        cdSayTo("A bright light appears where the key should be, then disappears slowly, revealing a spotless key.",accessorID);
                        llSetLinkAlpha(LINK_SET, (float)visibility, ALL_SIDES);
                        lmSendConfig("isVisible", (string)visible);
                        return;
                    }
                    else if (chatCommand == "ghost") {
                        visible = TRUE;

                        // This toggles ghostliness
                        if (visibility != 1.0) {
                            visibility = 1.0;
                            cdSayTo("You see the key sparkle slightly, then fade back into full view.",accessorID);
                        }
                        else {
                            visibility = GHOST_VISIBILITY;
                            cdSayTo("A cloud of sparkles forms around the key, and it fades to a ghostly presence.",accessorID);
                        }

                        llSetLinkAlpha(LINK_SET, (float)visibility, ALL_SIDES);
                        lmSendConfig("visibility", (string)visibility);
                        lmSendConfig("isVisible", (string)visible);
                        return;
                    }
                }

                //----------------------------------------
                // PUBLIC COMMANDS
                //
                // These are the commands that anyone can give:
                //   * wind
                //   * stat
                //   * listposes
                //   * carry
                //   * uncarry
                //
                // And menu shortcuts:
                //   * outfits
                //   * types
                //   * options
                //   * poses
                //   * menu
                //
                if (chatCommand == "wind") {
                    // A Normal Wind

#ifdef EMERGENCY_WIND
                    // This implements an emergency wind - but should be a different name
                    // than "wind" (see issue #631)
                    if (accessorIsDoll) {
                        if (hardcore) return;
                        if (collapsed) {
                            if ((llGetUnixTime() - collapseTime) > TIME_BEFORE_EMGWIND) {
                                cdMenuInject("Wind Emg", dollName, dollID);
                            }
                            else {
#ifdef DEVELOPER_MODE
                                cdSayTo("Emergency detection circuits detect developer access override; safety protocols removed and emergency winder activated",accessorID);
                                cdMenuInject("Wind Emg", dollName, dollID);
#else
                                cdSayTo("Emergency not detected; emergency winder is currently disengaged",accessorID);
#endif
                            }
                        }
                        else {
                            cdSayTo("Dolly is not collapsed; emergency winder is currently disengaged",accessorID);
                        }
                    }
#endif
                    if (collapsed) {
                        if (!accessorIsDoll) {
                            lmInternalCommand("winding", "|" + accessorName, accessorID);
                        }
                    }
                    else {
                        lmInternalCommand("winding", "|" + accessorName, accessorID);
                    }

                    return;
                }
                else if (chatCommand == "stat") {
                    if (accessorIsDoll && hardcore) return;
                    string msg = "Key is ";

                    if (windRate > 0) {
                        msg += "unwinding at a ";

                        if (windRate == 1.0) msg += "normal rate.";
                        else {
                            if (windRate < 1.0) msg += "slowed rate of ";
                            else if (windRate > 1.0) msg += "accelerated rate of ";

                            msg += " of " + formatFloat(windRate, 1) + "x.";
                        }

                        float t1 = timeLeftOnKey / (SECS_PER_MIN * windRate);
                        float t2 = keyLimit / (SECS_PER_MIN * windRate);
                        float p = t1 * 100.0 / t2;

                        msg += " Time remaining: " + (string)llRound(t1) + "/" +
                            (string)llRound(t2) + " min (" + formatFloat(p, 2) + "% capacity).";

                    } else msg += "currently stopped.";

                    cdSayTo(msg, accessorID);
                    return;
                }
                else if (chatCommand == "outfits") {
                    cdMenuInject("Outfits...", accessorName, accessorID);
                    return;
                }
                else if (chatCommand == "types") {
                    cdMenuInject("Types...", accessorName, accessorID);
                    return;
                }
                else if (chatCommand == "poses") {
                    if (arePosesPresent() == FALSE) {
                        cdSayTo("No poses present.",accessorID);
                        return;
                    }

                    cdMenuInject("Poses...", accessorName, accessorID);
                    return;
                }
                else if (chatCommand == "options") {
                    cdMenuInject("Options...", accessorName, accessorID);
                    return;
                }
                else if (chatCommand == "menu") {

                    // if this is Dolly... show dolly other menu as appropriate
                    if (accessorIsDoll) {

                        // Collapse has precedence over having a carrier...
                        if (collapsed) lmInternalCommand("collapsedMenu", "", NULL_KEY);
                        else if (cdCarried()) lmInternalCommand("carriedMenu", (string)accessorID + "|" + carrierName, NULL_KEY);
                        else cdMenuInject(MAIN, accessorName, accessorID);
                        return;
                    }
                    else {
                        cdMenuInject(MAIN, accessorName, accessorID);
                        return;
                    }
                }
                else if (chatCommand == "listposes") {
                    if (arePosesPresent() == FALSE) {
                        cdSayTo("No poses present.",accessorID);
                        return;
                    }

                    integer n = llGetInventoryNumber(INVENTORY_ANIMATION);
                    string poseCurrent;

                    while(n) {
                        poseCurrent = llGetInventoryName(INVENTORY_ANIMATION, --n);

                        // Collapsed animation is special: skip it
                        if (poseCurrent != ANIMATION_COLLAPSED) {

                            if (poseAnimation == poseCurrent) cdSayTo("\t*\t" + poseCurrent, accessorID);
                            else cdSayTo("\t\t" + poseCurrent, accessorID);
                        }
                    }
                    return;
                }
                else if (chatCommand == "release" || chatCommand == "unpose") {
                    if (accessorIsDoll && hardcore) return;

                    if (poseAnimation == "")
                        cdSayTo("Dolly is not posed.",accessorID);

                    else if (accessorIsDoll) {
                        if (poserID != dollID) {
                            llOwnerSay("Dolly tries to wrest control of " + pronounHerDoll +
                                " body from the pose but " + pronounSheDoll +
                                " is no longer in control of " + pronounHerDoll + " form.");
                        }
                    }

                    else {
                        cdSayTo("Dolly feels her pose release, and stretches her limbs, so long frozen.",accessorID);
                        lmMenuReply("Unpose", dollName, dollID);
                    }

                    return;
                }
                else if (chatCommand == "carry") {
                    // Dolly can't carry herself... duh!
                    if (!accessorIsDoll && (allowCarry || hardcore)) cdMenuInject("Carry", accessorName, accessorID);
                    return;
                }
                else if (chatCommand == "uncarry") {
                    if (!accessorIsDoll && (accessorIsController || cdIsCarrier(accessorID))) cdMenuInject("Uncarry", accessorName, accessorID);
                    return;
                }
            }
            else {
                // Command has secondary parameter
                string param =           llStringTrim(llGetSubString(chatCommand, space + 1, STRING_END), STRING_TRIM);
                chatCommand       = llToLower(llStringTrim(llGetSubString(   msg,         0,  space - 1), STRING_TRIM));

                //----------------------------------------
                // DOLL & EMBEDDED CONTROLLER COMMANDS (with parameter)
                //
                // Access to these commands for Doll and embedded controllers only:
                //   * channel 999
                //   * controller AAA
                //   * blacklist AAA
                //   * unblacklist AAA
                //   * prefix ZZZ
                //
                if (accessorIsDoll) {
                    if (chatCommand == "blacklist") {
                        lmInternalCommand("addBlacklist", param, accessorID);
                        return;
                    }
                    else if (chatCommand == "unblacklist") {
                        lmInternalCommand("remBlacklist", param, accessorID);
                        return;
                    }
                }

                if (accessorIsDoll || accessorIsController) {
                    if (chatCommand == "channel") {
                        string c = param;

                        if ((string) ((integer) c) == c) {
                            integer ch = (integer) c;

                            if (ch == PUBLIC_CHANNEL || ch == DEBUG_CHANNEL) {
                                cdSayTo("Invalid channel (" + (string)ch + ") ignored",accessorID);
                            }
                            else {
                                lmSetConfig("chatChannel",(string)(ch));
                                cdSayTo("Dolly communications link reset with new parameters on channel " + (string)ch,accessorID);
#ifdef DEVELOPER_MODE
                                llSay(DEBUG_CHANNEL,"chat channel changed from cmd line to using channel " + (string)ch);
#endif
                            }
                        }
                        return;
                    }
                    else if (chatCommand == "controller") {
                        lmInternalCommand("addController", param, accessorID);
                        return;
                    }
                    else if (chatCommand == "prefix") {
                        string newPrefix = param;
                        string c1 = llGetSubString(newPrefix,0,0);
                        string msg = "The prefix you entered is not valid, the prefix must ";
                        integer n = llStringLength(newPrefix);

                        // * must be greater than two characters and less than ten characters

                        if (n < 2 || n > 10) {
                            // Why? Two character user prefixes are standard and familiar; too much false positives with
                            // just 1 letter (~4%) with letter + letter/digit it's (~0.1%)
                            cdSayTo(msg + "be between two and ten characters long.", accessorID);
                        }

                        // * contain numbers and letters only

                        else if (newPrefix != llEscapeURL(newPrefix)) {
                            // Why? Stick to simple ascii compatible alphanumerics that are compatible with
                            // all keyboards and with mobile devices with limited input capabilities etc.
                            cdSayTo(msg + "only contain letters and numbers.", accessorID);
                        }

                        // * start with a letter

                        else if (((integer)c1) || (c1 == "0")) {
                            // Why? This one is needed to prevent the first char of prefix being merged into
                            // the channel # when commands are typed without the use of the optional space.
                            cdSayTo(msg + "start with a letter.", accessorID);
                        }

                        // All is good

                        else {
                            chatPrefix = newPrefix;
                            string s = "Chat prefix has been changed to " + llToLower(chatPrefix) + " the new prefix should now be used for all commands.";
                            cdSayToAgentPlusDoll(s, accessorID);
                            lmSetConfig("chatPrefix",(string)(chatPrefix));
                        }
                        return;
                    }
                }

                //----------------------------------------
                // DOLL COMMANDS (with parameter)
                //
                // These commands are for dolly ONLY
                //   * gname
                //   * debug (DEVELOPER_MODE)
                //   * inject (DEVELOPER_MODE)
                //   * timereporting (DEVELOPER_MODE)
                //   * collapse (DEVELOPER_MODE)
                //
                if (accessorIsDoll) {
                    if (chatCommand == "gname") {
                        // gname outputs a string with a symbol-based border
                        //
                        // Yes, this is a frivolous command... so what? *grins*
                        string doubledSymbols = "♬♬♪♪♩♩♭♭♪♪♦♦◊◊☢☢✎✎♂♂♀♀₪₪♋♋☯☯☆☆★★◇◇◆◆✈✈☉☉☊☊☋☋∆∆☀☀✵✵██▓▓▒▒░░❂❂××××⊹⊹××⊙⊙웃웃⚛⚛☠☠░░♡♡♫♫♬♬♀♀❤❤☮☮ﭚﭚ☆☆※※✴✴❇❇ﭕﭕةةثث¨¨ϟϟღღ⁂⁂٩٩۶۶✣✣✱✱✧✧✦✦❦❦⌘⌘ѽѽ☄☄✰✰++₪₪קק¤¤øøღღ°°♫♫✿✿▫▫▪▪♬♬♩♩♪♪♬♬°°ººةة==--++^^**˜˜¤¤øø☊☊☩☩´´⇝⇝⁘⁘⁙⁙⁚⁚⁛⁛↑↑↓↓☆☆★★··❤❤";
                        string pairedSymbols = "☜☞▶◀▷◁⊰⊱«»☾☽<>()[]{}\\/";
                        string allSymbols;

                        integer n;
                        string c1;
                        string c2;
                        string cLeft;
                        integer len;
                        integer j;
                        integer lenAllSymbols;

                        string oldName = llGetObjectName();
                        
                        // Change name so it will seem to come from us directly
                        cdSetKeyName(dollDisplayName);

                        allSymbols = doubledSymbols + pairedSymbols;
                        lenAllSymbols = llStringLength(allSymbols);
                        param = " " + param + " ";

                        len = (integer)llFrand(6) + 4;

                        while (len--) {
                            // Get a random character
                            n = (integer)(llFrand(lenAllSymbols));
                            c1 = llGetSubString(allSymbols,n,n);

                            // Get the chosen character's alternate
                            n = n ^ 1;
                            c2 = llGetSubString(allSymbols,n,n);

                            // Use multiple characters %50 of the time
                            if ((integer)(llFrand(2)) == 0) {
                                j = (integer)llFrand(3) + 1;
                                while (j--) param = c1 + param + c2;
                            }
                            else param = c1 + param + c2;
                        }
                        llSay(PUBLIC_CHANNEL,param);

                        // Restore to proper key name
                        cdSetKeyName(oldName);
                        return;
                    }
#ifdef DEVELOPER_MODE
                    else if (chatCommand == "debug") {
                        lmSendConfig("debugLevel", (string)(debugLevel = (integer)param));
                        if (debugLevel > 0) llOwnerSay("Debug level set to " + (string)debugLevel);
                        else llOwnerSay("Debug messages turned off.");

                        if (debugLevel == 0) {
                            lmSendConfig("timeReporting", (string)(timeReporting = 0));
                            llOwnerSay("Time reporting turned off.");
                        }

                        return;
                    }
                    else if (chatCommand == "inject") {
                        list params = llParseString2List(param, ["#"], []);
                        key paramKey = (key)params[2]; // NULL_KEY if not valid
                        string paramData = "ChatHandler|" + (string)params[1];
                        integer paramCode = (integer)params[0];
                        string s;

                        llOwnerSay("Injected link message code " + (string)paramCode + " with data " + (string)paramData + " and key " + (string)paramKey);
                        llMessageLinked(LINK_THIS, paramCode, paramData, paramKey);
                        return;
                    }
                    else if (chatCommand == "timereporting") {
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
                // Poses have "secondary" parameters when the name contains spaces
            }

            // The chat message is not a known command, so try to find an animation (pose)
            // Commands with secondary parameters bypass this sequence

            if (msg != ANIMATION_COLLAPSED) {
                if (!(llGetAgentInfo(llGetOwner()) & AGENT_SITTING)) { // Agent not sitting
                    if (llGetInventoryType(msg) == INVENTORY_ANIMATION) {
                        // We don't have to do any testing for poses here: if the specified pose exists, we use it
                        lmPoseReply(msg, accessorName, accessorID);
                    }
#ifdef DEVELOPER_MODE
                    else {
                        llSay(DEBUG_CHANNEL,"No pose or command recognized: " + msg);
                    }
#endif
                }
            }
        }
    }
}

//========== CHATHANDLER ==========
