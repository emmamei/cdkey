//========================================
// ChatHandler.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

#include "include/GlobalDefines.lsl"
#define cdMenuInject(a,b,c) lmMenuReply(a,b,c)

#define GNAME 1
#define RUNNING 1
#define NOT_RUNNING 0
#define UNSET -1
#define USER_NAME_QUERY_TIMEOUT 15
#define cdStopScript(a) llSetScriptState(a, NOT_RUNNING)
#define cdRunScript(a) llSetScriptState(a, RUNNING)
#define cdResetKey() llResetOtherScript("Start")

#define cdCapability(c,p,u) { s += p; if (!(c)) { s += " not"; }; s += " " + u + ".\n"; }
#define cdListenerActivate(a) llListenControl(a, 1)
#define cdListenerDeactivate(a) llListenControl(a, 0)
#define cdProfileURL(i) "secondlife:///app/agent/"+(string)(i)+"/about"
#define cdList2String(a) llDumpList2String(a,"|")

key lastWinderID;

string msg;
integer chatEnable           = TRUE;
string rlvAPIversion;

integer chatHandle          = 0;
key accessorID;
string accessorName;
integer accessorIsDoll;
integer accessorIsController;
integer accessorIsCarrier;
integer poseExpire;

key blacklistQueryID;
key controllerQueryID;
key blacklistQueryUUID;
key controllerQueryUUID;
string queryUUID;

doStats() {
#ifdef ADULT_MODE
    if (!hardcore)
#endif
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

        cdSayTo("Current pose: " + poseAnimation, accessorID);

#ifdef ADULT_MODE
#define poseDoesExpire (dollType != "Display" && !hardcore)
#else
#define poseDoesExpire (dollType != "Display")
#endif

        if (poseDoesExpire)
            cdSayTo("Pose time remaining: " + (string)((poseExpire - llGetUnixTime()) / SECS_PER_MIN) + " minutes.", accessorID);
    }

    lmMemReport(1.0,accessorID);
}

doXstats() {
    string s = "Extended stats:\n\nDoll is " +
#ifdef ADULT_MODE
    "an Adult " +
#else
    "a Child " +
#endif
#ifdef DEVELOPER_MODE
    "Developer " +
#endif
    "Doll (" + dollType + " type).\nWind amount: " +
               (string)llFloor(windNormal / SECS_PER_MIN) + " (mins)\nKey Limit: " +
               (string)(keyLimit / SECS_PER_MIN) + " mins\nEmergency Winder Recharge Time: " +
               (string)(EMERGENCY_LIMIT_TIME / 60 / (integer)SECS_PER_MIN) + " hours\nEmergency Winder: ";

    float windEmergency;
    windEmergency = keyLimit * 0.2;
#ifdef ADULT_MODE
    if (hardcore) { if (windEmergency > 120) windEmergency = 120; }
    else
#endif
        if (windEmergency > 600) windEmergency = 600;

    s += (string)((integer)(windEmergency / SECS_PER_MIN)) + " mins\n";

#ifdef EMERGENCY_TP
    cdCapability(autoTP,           "Doll can", "be force teleported");
#endif
    cdCapability(canFly,           "Doll can", "fly");
    cdCapability(allowRepeatWind,  "Doll can", "be multiply wound");
    cdCapability(wearLock,         "Doll's clothing is",  "currently locked on");
    cdCapability(lowScriptMode,    "Doll is",  "currently in powersave mode");
#ifdef ADULT_MODE
    cdCapability(allowStrip,       "Doll is", "strippable");
    cdCapability(hardcore,         "Doll is", "currently in hardcore mode");
#endif
    cdCapability(safeMode,         "Doll is", "currently in safe mode");

    // These settings (and more) all are affected by hardcore
    cdCapability(allowPose,      "Doll can", "be posed by the public");
    cdCapability(allowDress,     "Doll can", "be dressed by the public");
    cdCapability(allowCarry,     "Doll can", "be carried by the public");
    cdCapability(canDressSelf,  "Doll can", "dress by " + pronounHerDoll + "self");
    cdCapability(poseSilence,    "Doll is",  "silenced while posing");

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
}

#ifdef ADULT_MODE
doHardcore() {

    if (safeMode) {
        llOwnerSay("You must disable safe mode first.");
        return;
    }

    // if hardcore is set, only a controller other than
    // Dolly can clear it. If hardcore is clear - only
    // Dolly can set it.

    if (hardcore) {
        // Note: if Dolly has no external controllers, let Dolly unlock it
        if (cdIsController(accessorID)) {
            lmSetConfig("hardcore",(string)(hardcore = FALSE));
            cdSayTo("Hardcore mode has been disabled. The sound of a lock unlocking is heard.",accessorID);
        }
        else {
            cdSayTo("You rattle the lock, but it is securely fastened: you cannot disable hardcore mode.",accessorID);
        }
    }
    else {
        if (accessorIsDoll) {
            lmSetConfig("hardcore",(string)(hardcore = TRUE));
            cdSayTo("Doll's hardcore mode has been enabled. The sound of a lock closing is heard.",accessorID);
        }
    }
}
#endif

doPrefix(string param) {
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
}

#ifdef GNAME
doGname(string param) {
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
}
#endif

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
#ifdef ADULT_MODE
            else if (name == "hardcore")               hardcore = (integer)value;
#endif
            else if (name == "RLVok")                     RLVok = (integer)value;
            else if (name == "blacklist") {
                if (split == [""]) blacklistList = [];
                else blacklistList = split;
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
                else if (name == "canSelfTP")               canSelfTP = (integer)value;
                else if (name == "carrierID")               carrierID = (key)value;
                else if (name == "carrierName")           carrierName = value;
                else if (name == "configured")             configured = (integer)value;
                else if (name == "collapseTime")         collapseTime = (integer)value;
                else if (name == "controllers") {
                    if (split == [""]) controllerList = [];
                    else controllerList = split;
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
                else if (name == "poseExpire")             poseExpire = (integer)value;
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

                // Dolly can NOT be added to either list
                if (cdIsDoll((key)uuid)) {
                    cdSayTo("You can't select Dolly for this list.",(key)uuid);
                    return;
                }

                debugSay(5,"DEBUG-ADDMISTRESS","Blacklist = " + cdList2String(blacklistList) + " (" + (string)llGetListLength(blacklistList) + ")");

                string typeString; // used to construct messages
                list tmpList; // used as working area for whatever list

#define inRejectList(a) (llListFindList(rejectList, [ a ]) != NOT_FOUND)
#define inWorkingList(a) (llListFindList(tmpList, [ a ]) != NOT_FOUND)
#define noUserName (name == "")
#define queryMarker "++"

                // we don't want controllers to be added to the blacklist;
                // likewise, we don't want to allow those on the blacklist to
                // be controllers. barlist represents the "contra" list
                // opposing the added-to list.
                //
                list rejectList;

                // Initial settings
                if (cmd != "addBlacklist") {
                    typeString = "controller";
                    tmpList = controllerList;
                    rejectList = blacklistList;
                }
                else {
                    typeString = "blacklist";
                    tmpList = blacklistList;
                    rejectList = controllerList;
                }

                //----------------------------------------
                // VALIDATION
                //
                // #1a: Cannot add UUID as controller if found in blacklist
                // #1b: Cannot blacklist UUID if found in controllers list
                //
                if (inRejectList(uuid)) {

                    if (cmd != "addBlacklist") msg = nameURI + " is blacklisted; you must first remove them from the blacklist before adding them as a controller.";
                    else msg = nameURI + " is one of your controllers; until they remove themselves from being your controller, you cannot add them to the blacklist.";

                    cdSayTo(msg, id);
                    return;
                }

                // #2: Check if UUID exists already in the list
                //
                if (inWorkingList(uuid)) {

                    // Report already found
                    cdSayTo(nameURI + " is already found listed as " + typeString, id);
                    return;
                }

                // Perform actual add

                cdSayToAgentPlusDoll("Adding " + nameURI + " as " + typeString, id);

                if (cmd == "addBlacklist") {
                    blacklistList = tmpList + [ uuid ];
                }
                else {
                    controllerList = tmpList + [ uuid ];

                    // Controllers get added to the exceptions
                    llOwnerSay("@tplure:"    + uuid + "=add," +
                                "accepttp:"  + uuid + "=add," +
                                "sendim:"    + uuid + "=add," +
                                "recvim:"    + uuid + "=add," +
                                "recvchat:"  + uuid + "=add," +
                                "recvemote:" + uuid + "=add");
                }

                // Add user name - find it if need be
                //
                if (noUserName) {
                    llSay(DEBUG_CHANNEL,"No name alloted with this user.");

                    if (queryUUID != "") {
                        llSay(DEBUG_CHANNEL,"Query conflict detected!");
                        return;
                    }

                    queryUUID = uuid;

                    // This is a hack: it lets us match the UUID with the
                    // name we get back
                    //
                    if (cmd == "addBlacklist") {

                        blacklistList += queryMarker + queryUUID;
                        blacklistQueryID = llRequestDisplayName((key)uuid);
                    }
                    else {
                        controllerList += queryMarker + queryUUID;
                        controllerQueryID = llRequestDisplayName((key)uuid);
                    }

                    llSetTimerEvent(USER_NAME_QUERY_TIMEOUT);
                    return;
                }
                else {
                    // This is normal add of selected name
                    if (cmd == "addBlacklist") blacklistList += name;
                    else controllerList += name;
                }

                // we may or may not have changed either of these - but this code
                // forces a refresh in any case
                lmSetConfig("blacklist",   cdList2String(blacklistList)  );
                lmSetConfig("controllers", cdList2String(controllerList));

                debugSay(5,"DEBUG-ADDMISTRESS",   "blacklist >> " + llDumpList2String(blacklistList,   ",") + " (" + (string)llGetListLength(blacklistList  ) + ")");
                debugSay(5,"DEBUG-ADDMISTRESS", "controllers >> " + llDumpList2String(controllerList, ",") + " (" + (string)llGetListLength(controllerList) + ")");
            }
            else if ((cmd == "remController") ||
                     (cmd == "remBlacklist")) {

                string uuid = (string)split[1];
                string name = (string)split[2];

                if (name == "") {
                    llSay(DEBUG_CHANNEL,"No name alloted with this user.");
                    name == (string)(uuid);
                }

                string typeString;
                list tmpList;
                string nameURI = "secondlife:///app/agent/" + uuid + "/displayname";

                // Initial settings
                if (cmd != "remBlacklist") {
                    typeString = "controller";
                    tmpList = controllerList;
                }
                else {
                    typeString = "blacklist";
                    tmpList = blacklistList;
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
                    blacklistList = tmpList;
                }
                else {
                    controllerList = tmpList;
                    // because we cant remove by UUID, a complete redo of
                    // exceptions is necessary
                    lmInternalCommand("reloadExceptions",script,NULL_KEY);
                }

                // we may or may not have changed either of these - but this code
                // forces a refresh in any case
                lmSetConfig("blacklist",   cdList2String(blacklistList)  );
                lmSetConfig("controllers", cdList2String(controllerList));
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
            accessorID = id;
            accessorName = llGetDisplayName(id); // get name of person sending chat command
            accessorIsDoll = cdIsDoll(id);
            accessorIsController = cdIsController(id); // This includes Dolly if there are no Controllers
            accessorIsCarrier = cdIsCarrier(id);

#define blacklistedUser(a) (llListFindList(blacklistList, [ (string)(a) ]) != NOT_FOUND)

            // Deny access to the menus when the command was recieved from blacklisted avatar
            if (blacklistedUser(accessorID)) {
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

            switch (prefix) {

                case "*": {

                    // *prefix is global, strip from chatCommand and continue
                    msg = llGetSubString(msg,1,-1);
                    break;
                }

                case "#": {

                    // if Dolly gives a #cmd ignore it...
                    // if someone else gives it - they are being ignored themselves,
                    //    but we act on it.
                    if (accessorIsDoll) return;
                    else {
                        // #prefix is an all others prefix like with OC etc
                        msg = llGetSubString(msg,1,-1);
                    }
                    break;
                }


                default: {

                    integer n = llStringLength(chatPrefix);

                    if (llToLower(llGetSubString(msg, 0, n - 1)) == chatPrefix) {
                        prefix = llGetSubString(msg, 0, n - 1);
                        msg = llGetSubString(msg, n, -1);
                    }
                    else {
                        // we didn't get a valid prefix - so exit. Either it's
                        // for another dolly, or it was invalid. If we act on a general
                        // command - then every dolly in range with this key will respond.
                        // Can't have that...

                        llSay(DEBUG_CHANNEL,"Got wrong prefix from message (" + msg + ") on chat channel " + (string)chatChannel + "; wanted prefix " + chatPrefix);
                        return;
                    }
                    break;
                }
            }

            // If we get here, we know this:
            //
            //   * If Doll, they've been warned about the Prefix if needed
            //   * If not Doll, they used the prefix
            //   * If the prefix is '#' someone else used it, not Dolly
            //   * If the prefix is '*' could have been used by anyone

            // Trim message in case there are spaces
            msg = llStringTrim(msg,STRING_TRIM);

#define PARAMETERS_EXIST (spaceInMsg != NOT_FOUND)

            // Choice is a command, not a pose
            integer spaceInMsg = llSubStringIndex(msg, " ");
            string chatCommand = msg;

            debugSay(5,"DEBUG-CHAT","Got a chat message: " + chatCommand);

            // Separate commands into those With and Without Parameters...

            if (!PARAMETERS_EXIST) { // Commands without parameters handled first
                chatCommand = llToLower(chatCommand);

                // Now we separate the commands into different categories,
                // based on who is allowed...
                //
                // * Public command (help)
                // * Doll or Controller
                // * More Public commands
                //
                // These need to be more concretely divided
                //
                // Each command may further restrict what
                // can be done; these need to be documented.

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
                // The help functions also provide, in code, a short-hand way to
                // show who can do what commands... but have to very carefully make
                // sure that the help matches the commands available...
                //
                if (chatCommand == "help") {
                    // First: anyone can do these commands
                    string help = "Commands:
    Commands need to be prefixed with the prefix, which is currently " + llToLower(chatPrefix) + "

    help ........... this list of commands
    menu ........... show main menu
    stat ........... concise current status
    wind ........... wind key";
                    string help2;
                    string posingHelp = "
    release ........ stop the current pose if possible
    unpose ......... stop the current pose if possible
    [posename] ..... activate the named pose if possible
    pose XXX ....... activate the named pose if possible
    listposes ...... list all poses";
                    string carryHelp = "
    carry .......... carry dolly
    uncarry ........ put down dolly";

                    // Only Dolly or Controller or Carrier can do these commands
                    if (accessorIsDoll || accessorIsController || accessorIsCarrier) {
                        help += "
    stats .......... selected statistics and settings
    xstats ......... extended statistics and settings";

                        // These are here because none of these people are restricted
                        // by the allow* functions
                        help += posingHelp;
                        help += carryHelp;

                        // Only Dolly can do these
                        if (accessorIsDoll) {
                            help2 += "Commands (page2):

    hide ........... make key invisible
    unhide ......... make key visible
    show ........... make key visible
    visible ........ make key visible
    ghost .......... make key visible and ghostly
    prefix XX ...... change chat command prefix
    controller NN .. add controller
    channel ## ..... change channel
    blacklist NN ... add to blacklist
    unblacklist NN . remove from blacklist";
                        }
                    }

                    // Anyone other than Controllers / Carriers / Dolly
                    else {

                        // Only if poses are allowed
                        if (allowPose) {
                            help += posingHelp;
                        }

                        // Only if carry is allowed
                        if (allowCarry) {
                            help += carryHelp;
                        }
                    }

                    cdSayTo(help + "\n", accessorID);
                    if (help2 != "") cdSayTo(help2 + "\n", accessorID);

#ifdef DEVELOPER_MODE
                    // Developer Dolly commands...
                    if (accessorIsDoll) {
                        help = "
    Debugging commands:

    build .......... list build configurations
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
                //
                //   * build
                //   * update
                //   * xstats
                //   * stats
                //   * hardcore (ADULT_MODE)
                //   * collapse (DEVELOPER_MODE)
                //   * powersave (DEVELOPER_MODE)
                //   * hide
                //   * release / unpose
                //   * unhide / show / visible
                //   * ghost
                //
                if (accessorIsDoll || accessorIsController) {
                    switch (chatCommand) {

                        case "build": {
                            lmConfigReport();
                            return;
                        }

                        case "update": {

                            lmSendConfig("update", "1");
                            return;
                        }

                        case "xstats": {

                            doXstats();
                            return;
                        }

                        case "stats": {

                            doStats();
                            return;
                        }
                        case "safeMode": {
#ifdef ADULT_MODE
                            if (!hardcore)
#endif
                                lmSetConfig("safemode", (string)(safeMode = !safeMode));
                            return;
                        }
#ifdef ADULT_MODE
                        case "hardcore": {

                            doHardcore();
                            return;
                        }

#endif
#ifdef DEVELOPER_MODE
                        case "collapse": {

                            if (accessorIsDoll) {
                                //lmSetConfig("timeLeftOnKey","10");
                                llOwnerSay("Immediate collapse triggered...");
                                lmInternalCommand("collapse", (string)TRUE, accessorID);
                            }
                            return;
                        }

                        case "powersave": {

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
                        case "hide": {

                            visible = FALSE;

                            cdSayTo("The key shimmers, then fades from view.",accessorID);
                            llSetLinkAlpha(LINK_SET, 0.0, ALL_SIDES);
                            lmSendConfig("isVisible", (string)visible);
                            return;
                        }

                        case "unhide":
                        case "show":
                        case "visible": {

                            visible = TRUE;

                            cdSayTo("A bright light appears where the key should be, then disappears slowly, revealing a spotless key.",accessorID);
                            llSetLinkAlpha(LINK_SET, (float)visibility, ALL_SIDES);
                            lmSendConfig("isVisible", (string)visible);
                            return;
                        }
                        
                        case "ghost": {

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
                }

                //----------------------------------------
                // PUBLIC COMMANDS
                //
                // These are the commands that anyone can give:
                //   * wind
                //   * stat
                //
                // And menu shortcuts:
                //   * outfits
                //   * types
                //   * poses
                //   * options
                //   * menu
                //
                // And more commands:
                //   * listposes
                //   * release / unpose
                //   * carry
                //   * uncarry
                //
                if (chatCommand == "wind") {
                    // A Normal Wind
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
#ifdef ADULT_MODE
                    if (accessorIsDoll && hardcore) return;
#endif
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
                    if (poseAnimation == "")
                        cdSayTo("Dolly is not posed.",accessorID);

                    else if (accessorIsDoll) {
#ifdef ADULT_MODE
#define poseDoesNotExpire (hardcore || dollType == "Display")
#else
#define poseDoesNotExpire (dollType == "Display")
#endif
                        // If hardcore or Display Dolly, then Doll can't undo a pose
                        if (poseDoesNotExpire) return;

                        if (poserID != dollID) {
                            llOwnerSay("Dolly tries to wrest control of " + pronounHerDoll +
                                " body from the pose but " + pronounSheDoll +
                                " is no longer in control of " + pronounHerDoll + " form.");
                        }

                        else {
                            cdSayTo("Dolly feels her pose release, and stretches her limbs, so long frozen.",accessorID);
                            lmMenuReply("Unpose", dollName, dollID);
                        }
                    }
                    else if (accessorIsController || accessorIsCarrier) {
                        if (poserID == dollID) {
                            llOwnerSay("You release Dolly's body from the pose that " + pronounSheDoll + " activated.");
                            lmMenuReply("Unpose", accessorName, accessorID);
                        }
                        else if (poserID == accessorID) {
                            cdSayTo("Dolly feels her pose release, and stretches her limbs, so long frozen.",accessorID);
                            lmMenuReply("Unpose", accessorName, accessorID);
                        }

                    }

                    return;
                }
                else if (chatCommand == "carry") {
                    // Dolly can't carry herself... duh!
                    if (!accessorIsDoll && allowCarry) cdMenuInject("Carry", accessorName, accessorID);
                    return;
                }
                else if (chatCommand == "uncarry") {
                    if (!accessorIsDoll && (accessorIsController || accessorIsCarrier)) cdMenuInject("Uncarry", accessorName, accessorID);
                    return;
                }
            }
            else {
                // Command has secondary parameter
                string param =           llStringTrim(llGetSubString(chatCommand, spaceInMsg + 1, STRING_END), STRING_TRIM);
                chatCommand       = llToLower(llStringTrim(llGetSubString(   msg,         0,  spaceInMsg - 1), STRING_TRIM));

                // This section is only for commands with parameters:
                //
                // Access to these commands for Doll and embedded controllers only:
                //   * blacklist AAA
                //   * unblacklist AAA
                //   * channel 999
                //   * controller AAA
                //   * prefix ZZZ
                //
                // These commands are for dolly ONLY
                //   * gname
                //   * debug (DEVELOPER_MODE)
                //   * inject (DEVELOPER_MODE)
                //   * pose

                //----------------------------------------
                // DOLL & EMBEDDED CONTROLLER COMMANDS (with parameter)
                //
                // Access to these commands for Doll and embedded controllers only:
                //   * blacklist AAA
                //   * unblacklist AAA
                //   * channel 999
                //   * controller AAA
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
                        else {
                            llSay(DEBUG_CHANNEL, "Invalid channel number! (" + c + ")");
                        }
                        return;
                    }
                    else if (chatCommand == "controller") {
                        lmInternalCommand("addController", param, accessorID);
                        return;
                    }
                    else if (chatCommand == "prefix") {
                        doPrefix(param);
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
                //   * pose
                //
                if (accessorIsDoll) {
#ifdef GNAME
                    if (chatCommand == "gname") {
                        // gname outputs a string with a symbol-based border
                        //
                        // Yes, this is a frivolous command... so what? *grins*
                        doGname(param);
                        return;
                    }
#endif
#ifdef DEVELOPER_MODE
                    else if (chatCommand == "debug") {
                        debugLevel = (integer)param;
                        if (debugLevel > 9) debugLevel = 9;
                        lmSendConfig("debugLevel", (string)debugLevel);

                        if (debugLevel > 0) llOwnerSay("Debug level set to " + (string)debugLevel);
                        else llOwnerSay("Debug messages turned off.");

                        return;
                    }
                    else if (chatCommand == "inject") {
                        list params = llParseString2List(param, ["#"], []);
                        key paramKey = (key)params[2]; // NULL_KEY if not valid
                        string s;

#define paramData ("ChatHandler|" + (string)params[1])
#define paramCode ((integer)params[0])

                        llOwnerSay("Injected link message code " + (string)paramCode + " with data " + (string)paramData + " and key " + (string)paramKey);
                        llMessageLinked(LINK_THIS, paramCode, paramData, paramKey);
                        return;
                    }
#endif
                    ;
                }
                else if (chatCommand == "pose") {
                    string requestedAnimation = param;

                    if (requestedAnimation != ANIMATION_COLLAPSED) {
                        if (!(llGetAgentInfo(llGetOwner()) & AGENT_SITTING)) { // Agent not sitting
                            if (llGetInventoryType(requestedAnimation) == INVENTORY_ANIMATION) {
                                // We don't have to do any testing for poses here: if the specified pose exists, we use it
                                lmPoseReply(requestedAnimation, accessorName, accessorID);
                            }
                            else {
                                llSay(DEBUG_CHANNEL,"No pose by that name: " + requestedAnimation);
                            }
                        }
                    }
                    return;
                }
            }

            // The chat message is not a known command... so ignore

#ifdef DEVELOPER_MODE
            llSay(DEBUG_CHANNEL,"Chat command not recognized: " + msg);
#endif
        }
    }

#define removeLastListTerm(a) llDeleteSubList(a,-2,-1);
#define stopTimer() llSetTimerEvent(0.0)

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
        // Query timed out...

        if (blacklistQueryID != NULL_KEY) {

            queryUUID = "";
            removeLastListTerm(blacklistList);

            lmSetConfig("blacklist", cdList2String(blacklistList));

            debugSay(5,"DEBUG-ADDMISTRESS",   "blacklist >> " + llDumpList2String(blacklistList,   ",") + " (" + (string)llGetListLength(blacklistList  ) + ")");
        }
        else if (controllerQueryID != NULL_KEY) {

            queryUUID = "";
            removeLastListTerm(controllerList);

            lmSetConfig("controllers", cdList2String(controllerList));

            debugSay(5,"DEBUG-ADDMISTRESS", "controllers >> " + llDumpList2String(controllerList, ",") + " (" + (string)llGetListLength(controllerList) + ")");
        }

        stopTimer();
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key queryID, string queryData) {
        integer index;

#define userName queryData
#define isUserUUIDInList(a) llListFindList(a, [ queryMarker + (string)queryUUID ])

        switch (queryID): {

            case blacklistQueryID: {

                if ((index = isUserUUIDInList(blacklistList)) != NOT_FOUND) {
                    queryUUID = "";
                    blacklistList[ index ] = userName;
                    blacklistQueryID = NULL_KEY;
                    debugSay(5,"DEBUG-ADDMISTRESS",   "blacklist >> " + llDumpList2String(blacklistList,   ",") + " (" + (string)llGetListLength(blacklistList  ) + ")");
                    lmSetConfig("blacklist", cdList2String(blacklistList));
                }
#ifdef DEVELOPER_MODE
                else llSay(DEBUG_CHANNEL,"Couldnt find blacklist UUID:" + queryUUID);
#endif
                break;
            }

            case controllerQueryID: {

                if ((index = isUserUUIDInList(controllerList)) != NOT_FOUND) {
                    queryUUID = "";
                    controllerList[ index ] = userName;
                    controllerQueryID = NULL_KEY;
                    debugSay(5,"DEBUG-ADDMISTRESS", "controllers >> " + llDumpList2String(controllerList, ",") + " (" + (string)llGetListLength(controllerList) + ")");
                    lmSetConfig("controllers", cdList2String(controllerList));
                }
#ifdef DEVELOPER_MODE
                else llSay(DEBUG_CHANNEL,"Couldnt find controller UUID: " + queryUUID);
#endif
                break;
            }
        }
    }
}

//========== CHATHANDLER ==========
