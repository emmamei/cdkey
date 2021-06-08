//========================================
// ChatHandler.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

#include "include/GlobalDefines.lsl"
#define cdMenuInject(a,b,c) lmMenuReply(a,b,c)

//#define GNAME 1
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
#define cdList2String(a) llDumpList2String(a,"|")

#define setKeyVisibility(a) llSetLinkAlpha(LINK_SET, (a), ALL_SIDES);

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

            msg += " of " + formatFloat1(windRate) + "x.";
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

    //lmMemReport(1.0,accessorID);
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

    if (windRate > 0) s += "\nCurrent wind rate is " + formatFloat2(windRate) + ".\n";
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

//list addList(list workingList, string uuid, key id) {
//}

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

// Change key visibility - from ghostly to solid and back,
// but in a gradual way instead of *snap*
//
// Note that this code *requires* that vStart and vEnd be
// no more decimal places than the increment listed below
// Otherwise, this will fail.
//
#define FADE_INCREMENT 0.05

float keyFade(float vStart, float vEnd) {

    // This take the start and end and convert them to
    // integers; this avoides float comparisons and loops
    //
    integer vCurrent = (integer)(vStart * 100.0);
    integer vCurrentEnd = (integer)(vEnd * 100.0);
    integer vIncrement = (integer)(FADE_INCREMENT * 100.0);

    debugSay(5,"DEBUG-CHATHANDLER","Key fade: From " + (string)vStart + " to " + (string)vEnd);

    if (vEnd > vStart)  vIncrement = (integer)(FADE_INCREMENT *  100.0);
    else                vIncrement = (integer)(FADE_INCREMENT * -100.0);

    if (vStart == vEnd) {
        llSay(DEBUG_CHANNEL,"Error: improper parameters to keyFade: " + (string)vStart + " / " + (string)vEnd);
        return vEnd;
    }

    debugSay(5,"DEBUG-CHATHANDLER","Key fade: Adjusted: From " + (string)vCurrent + " to " + (string)vCurrentEnd + " by " + (string)vIncrement);

    // Counting down
    do {

        setKeyVisibility((float)vCurrent / 100.0);
        vCurrent += vIncrement; // could be incr or decr
        llSleep(0.7);
    }
    while (vCurrent != vCurrentEnd); // this assumes that at some point, these two WILL be equal

    setKeyVisibility(vEnd);
    return vEnd;
}

integer commandsDollyOnly(string chatCommand, string param) {

    switch (chatCommand) {

        case "build": {
            lmConfigReport();
            break;
        }

        case "update": {

            lmSendConfig("update", "1");
            break;
        }

        case "safemode": {
#ifdef ADULT_MODE
            if (!hardcore)
#endif
                lmSetConfig("safemode", (string)(safeMode = !safeMode));
            break;
        }
        // Could potentially combine the next three into one
        // block but the code to account for the differences
        // may not be worth it.
        //
        case "hide": {

            cdSayTo("The key shimmers, then fades from view.",accessorID);
            visible = FALSE;

            keyFade(visibility, 0.0);

            lmSendConfig("isVisible", (string)visible);
            break;
        }

        case "unhide":
        case "show":
        case "visible": {

            if (visible == TRUE) break; // Already visible

            visible = TRUE;

            if (visibility == GHOST_VISIBILITY) cdSayTo("The key shimmers, and slowly seems to solidify into a physical form.",accessorID);
            else cdSayTo("A bright light appears where the key should be, then disappears slowly, revealing a spotless key.",accessorID);

            keyFade(0.0, visibility);

            lmSendConfig("isVisible", (string)visible);
            break;
        }

        case "ghost": {

            // This toggles ghostliness
            switch (visibility): {
                case 1.0: {
                    cdSayTo("A cloud of sparkles forms around the key, and it fades to a ghostly presence.",accessorID);
                    visibility = keyFade(1.0, GHOST_VISIBILITY);
                    break;
                }

                case GHOST_VISIBILITY: {
                    cdSayTo("You see the key sparkle slightly, then slowly take on solid form again.",accessorID);
                    visibility = keyFade(GHOST_VISIBILITY, 1.0);
                    break;
                }

                case 0.0: {
                    cdSayTo("A smoky cloud appears, and the ghostly key materializes where it should be.",accessorID);
                    visibility = keyFade(0.0, GHOST_VISIBILITY);
                    break;
                }
            }

            visible = TRUE;

            lmSendConfig("visibility", (string)visibility);
            lmSendConfig("isVisible", (string)visible);
            break;
        }

        case "blacklist": {
            lmInternalCommand("addBlacklist", param, accessorID);
            break;
        }

        case "unblacklist": {
            lmInternalCommand("remBlacklist", param, accessorID);
            break;
        }

        case "channel": {

            // This strange double-typecast is to see if the parameter
            // is a integer complete and whole
            //
            if ((string) ((integer) param) == param) {

                if ((integer)param == PUBLIC_CHANNEL || (integer)param == DEBUG_CHANNEL) {
                    cdSayTo("Invalid channel (" + param + ") ignored",accessorID);
                }
                else {
                    lmSetConfig("chatChannel",param);
                    cdSayTo("Dolly communications link reset with new parameters on channel " + param,accessorID);
#ifdef DEVELOPER_MODE
                    llSay(DEBUG_CHANNEL,"chat channel changed from cmd line to using channel " + param);
#endif
                }
            }
            else {
                llSay(DEBUG_CHANNEL, "Invalid channel number! (" + param + ")");
            }
            break;
        }

        case "controller": {
            lmInternalCommand("addController", param, accessorID);
            break;
        }

        case "prefix": {
            doPrefix(param);
            break;
        }

#ifdef GNAME
        case "gname": {
                // gname outputs a string with a symbol-based border
                //
                // Yes, this is a frivolous command... so what? *grins*
                doGname(param);
                break;
            }
        }
#endif
#ifdef DEVELOPER_MODE
        case "collapse": {

            //lmSetConfig("timeLeftOnKey","10");
            llOwnerSay("Immediate collapse triggered...");
            lmInternalCommand("collapse", (string)TRUE, accessorID);

            break;
        }

        case "debug": {
            lmSetConfig("debugLevel", (string)(debugLevel = (integer)param));

            if (debugLevel) llOwnerSay("Debug level set.");
            else llOwnerSay("Debug messages turned off.");

            break;
        }

        case "inject": {
            list params = llParseString2List(param, ["#"], []);
            key paramKey = (key)params[2]; // NULL_KEY if not valid
            string s;

#define paramData ("ChatHandler|" + (string)params[1])
#define paramCode ((integer)params[0])

            llOwnerSay("Injected link message code " + (string)paramCode + " with data " + (string)paramData + " and key " + (string)paramKey);
            llMessageLinked(LINK_THIS, paramCode, paramData, paramKey);
            break;
        }
#endif
        default: {
            return FALSE;
        }
    }
    return TRUE;
}

integer commandsDollyAndController(string chatCommand) {

    switch (chatCommand) {

        case "xstats": {

            doXstats();
            break;
        }

        case "stats": {

            doStats();
            break;
        }

#ifdef ADULT_MODE
        case "hardcore": {

            doHardcore();
            break;
        }
#endif

        default: {
            return FALSE;
        }
    }
    return TRUE;
}

integer commandsPublic(string chatCommand, string param) {

    switch (chatCommand): {

        case "wind": {

            // A Normal Wind
            if (accessorIsDoll && collapsed) break;
            lmInternalCommand("winding", "|" + accessorName, accessorID);

            break;
        }

        case "stat": {
#ifdef ADULT_MODE
            if (accessorIsDoll && hardcore) break;
#endif
            string msg = "Key is ";

            if (windRate > 0) {
                msg += "unwinding at a ";

                if (windRate == 1.0) msg += "normal rate.";
                else {
                    if (windRate < 1.0) msg += "slowed rate of ";
                    else if (windRate > 1.0) msg += "accelerated rate of ";

                    msg += " of " + formatFloat1(windRate) + "x.";
                }

                float t1 = timeLeftOnKey / (SECS_PER_MIN * windRate);
                float t2 = keyLimit / (SECS_PER_MIN * windRate);
                float p = t1 * 100.0 / t2;

                msg += " Time remaining: " + (string)llRound(t1) + "/" +
                    (string)llRound(t2) + " min (" + formatFloat2(p) + "% capacity).";

            } else msg += "currently stopped.";

            cdSayTo(msg, accessorID);
            break;
        }

        case "outfits": {
            cdMenuInject("Outfits...", accessorName, accessorID);
            break;
        }
        case "types": {
            cdMenuInject("Types...", accessorName, accessorID);
            break;
        }
        case "poses": {
            if (arePosesPresent() == FALSE) {
                cdSayTo("No poses present.",accessorID);
                break;
            }

            cdMenuInject("Poses...", accessorName, accessorID);
            break;
        }
        case "options": {
            cdMenuInject("Options...", accessorName, accessorID);
            break;
        }
        case "menu": {

            // if this is Dolly... show dolly other menu as appropriate
            if (accessorIsDoll) {

                // Collapse has precedence over having a carrier...
                if (collapsed) lmInternalCommand("collapsedMenu", "", NULL_KEY);
                else if (cdCarried()) lmInternalCommand("carriedMenu", (string)accessorID + "|" + carrierName, NULL_KEY);
                else cdMenuInject(MAIN, accessorName, accessorID);
            }
            else {
                cdMenuInject(MAIN, accessorName, accessorID);
            }
            break;
        }
        case "listposes": {
            if (arePosesPresent() == FALSE) {
                cdSayTo("No poses present.",accessorID);
                break;
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
            break;
        }
        case "release":
        case "unpose": {
            if (poseAnimation == "")
                cdSayTo("Dolly is not posed.",accessorID);

            else if (accessorIsDoll) {
#ifdef ADULT_MODE
#define poseDoesNotExpire (hardcore || dollType == "Display")
#else
#define poseDoesNotExpire (dollType == "Display")
#endif
                // If hardcore or Display Dolly, then Doll can't undo a pose
                if (poseDoesNotExpire) break;

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

            break;
        }
        case "carry": {
            // Dolly can't carry herself... duh!
            if (!accessorIsDoll && allowCarry) cdMenuInject("Carry", accessorName, accessorID);
            break;
        }
        case "uncarry": {
            if (!accessorIsDoll && (accessorIsController || accessorIsCarrier)) cdMenuInject("Uncarry", accessorName, accessorID);
            break;
        }
        case "pose": {

#define requestedAnimation param

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
            break;
        }
        default: {
            return FALSE;
        }
    }
    return TRUE;
}

//========================================
// STATES
//========================================

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

        parseLinkHeader(data,i);

        if (code == SEND_CONFIG) {
            string name = (string)split[0];

            // This could be made a global, and not be created each time -
            // but this apparently takes a lot less memory, plus it als
            // is defined where it is used, adding to comprehension and
            // maintainability.
            //
            list cmdList = [
#ifdef ADULT_MODE
                             "hardcore",
                             "allowStrip",
#endif
#ifdef DEVELOPER_MODE
                             "debugLevel",
#endif
#ifdef EMERGENCY_TP
                             "autoTP",
#endif
                             "timeLeftOnKey",
                             "RLVok",
                             "keyLimit",
                             "blacklist",
                             "allowRepeatWind",
                             "allowCarry",
                             "allowDress",
                             "allowPose",
                             "collapsed",
                             "canDressSelf",
                             "canFly",
                             "canSelfTP",
                             "carrierID",
                             "carrierName",
                             "configured",
                             "collapseTime",
                             "controllers",
                             "dollType",
                             "dollGender",
                             "dollDisplayName",
                             "poseSilence",
                             "poseAnimation",
                             "poserID",
                             "poserName",
                             "poseExpire",
                             "pronounHerDoll",
                             "pronounSheDoll",
                             "wearLock",
                             "windRate",
                             "windNormal"
                           ];

            // Commands need to be in the list cmdList in order to be
            // recognized, before testing down below
            //
            if (llListFindList(cmdList, (list)name) == NOT_FOUND)
                return;

            string value = (string)split[1];
            split = llDeleteSubList(split,0,0);

            integer integerValue = (integer)value;
            key keyValue = (key)value;

                 if (name == "timeLeftOnKey")       timeLeftOnKey = integerValue;
            else if (name == "windRate")                 windRate = (float)value;

#ifdef ADULT_MODE
            else if (name == "hardcore")                 hardcore = integerValue;
            else if (name == "allowStrip")             allowStrip = integerValue;
#endif
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")             debugLevel = integerValue;
#endif
#ifdef EMERGENCY_TP
            else if (name == "autoTP")                     autoTP = integerValue;
#endif
            else if (name == "RLVok")                       RLVok = integerValue;
            else if (name == "keyLimit")                 keyLimit = integerValue;
            else if (name == "allowRepeatWind")   allowRepeatWind = integerValue;
            else if (name == "allowCarry")             allowCarry = integerValue;
            else if (name == "allowDress")             allowDress = integerValue;
            else if (name == "allowPose")               allowPose = integerValue;
            else if (name == "poseSilence")           poseSilence = integerValue;
            else if (name == "collapsed")               collapsed = integerValue;
            else if (name == "canDressSelf")         canDressSelf = integerValue;
            else if (name == "canFly")                     canFly = integerValue;
            else if (name == "canSelfTP")               canSelfTP = integerValue;
            else if (name == "configured")             configured = integerValue;
            else if (name == "collapseTime")         collapseTime = integerValue;
            else if (name == "poseExpire")             poseExpire = integerValue;
            else if (name == "wearLock")                 wearLock = integerValue;
            else if (name == "windNormal")             windNormal = integerValue;

            else if (name == "carrierID")               carrierID = keyValue;
            else if (name == "poserID")                   poserID = keyValue;

            else if (name == "carrierName")           carrierName = value;
            else if (name == "dollType")                 dollType = value;
            else if (name == "dollGender")             dollGender = value;
            else if (name == "dollDisplayName")   dollDisplayName = value;
            else if (name == "poseAnimation")       poseAnimation = value;
            else if (name == "poserName")               poserName = value;
            else if (name == "pronounHerDoll")     pronounHerDoll = value;
            else if (name == "pronounSheDoll")     pronounSheDoll = value;

            else if (name == "controllers") {
                if (split == [""]) controllerList = [];
                else controllerList = split;
            }
            else if (name == "blacklist") {
                if (split == [""]) blacklistList = [];
                else blacklistList = split;
            }
        }
        else if (code == SET_CONFIG) {
            string setName = (string)split[0];
            string value = (string)split[1];

            if (setName == "chatChannel") {
                // Change listening chat channel

                // if the current chatChannel is zero it cannot be changed
                if (chatChannel == 0) return;
                if (chatChannel == (integer)value) return;

                if ((integer)value != DEBUG_CHANNEL) {
                    // Note that setting the chat channel to 0 (PUBLIC) is valid:
                    // it isn't used as a channel, but as a flag for a disabled channel
                    chatChannel = (integer)value;

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
//        else if (code == INTERNAL_CMD) {
//            string cmd = (string)split[0];
//        }
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
#define parametersExist (spaceInMsg != NOT_FOUND)
#define getTrailingString(a,b) llStringTrim(llGetSubString((a), (b) + 1, STRING_END), STRING_TRIM)
#define getLeadingString(a,b) llStringTrim(llGetSubString((a), 0, (b) - 1), STRING_TRIM)

            // Deny access to the menus when the command was recieved from blacklisted avatar
            if (blacklistedUser(accessorID)) {
                llOwnerSay("SECURITY WARNING! Attempted chat channel access by blacklisted user " + accessorName);
                return;
            }

            debugSay(5,"DEBUG-CHAT",("Got a chat channel message: " + accessorName + "/" + (string)id + "/" + msg));

            integer n = llStringLength(chatPrefix);

            list msgList = llParseString2List(msg,(list)" ",(list)"");

            string readPrefix = llToLower((string)msgList[0]);
            string readCommand = llToLower((string)msgList[1]);

            msgList = llDeleteSubList(msgList, 0, 1);
            string readParams = llDumpList2String(msgList," ");

            if (readPrefix != chatPrefix) {
                // We didn't get a valid prefix - so exit.

                llSay(DEBUG_CHANNEL,"Got wrong prefix from message (" + msg + ") on chat channel " + (string)chatChannel + "; wanted prefix " + chatPrefix);
                return;
            }

            string param = readParams;
            string chatCommand = readCommand;

            debugSay(5,"DEBUG-CHAT","Got a chat message: " + chatCommand);

            // At this point, we can test the chat command against a list,
            // and we no longer need to separate commands with and without parameters

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
                lmInternalCommand("chatHelp", (string)accessorID, accessorID);
                return;
            }

            //----------------------------------------
            // DOLLY ONLY COMMANDS
            //
            //   * build
            //   * update
            //   * safemode
            //   * collapse (DEVELOPER_MODE)
            //   * hide
            //   * unhide / show / visible
            //   * ghost
            //
            if (accessorIsDoll) {
                if (commandsDollyOnly(chatCommand,param) == TRUE) return;
            }

            //----------------------------------------
            // DOLL & CONTROLLER COMMANDS
            //
            // Commands only for Doll or Controllers
            //
            //   * xstats
            //   * stats
            //   * hardcore (ADULT_MODE)
            //   * release / unpose
            //
            // Note that this is Dolly OR a Controller - and NOT
            // a Controller including Dolly...
            //
            if (accessorIsDoll || accessorIsController) {
                if (commandsDollyAndController(chatCommand) == TRUE) return;
            }

            //----------------------------------------
            // PUBLIC COMMANDS
            //
            // Actually, these are "mostly" public commands,
            // but also include several commands that can be used
            // by everyone under different circumstances or with
            // differing results.
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
            if (!commandsPublic(chatCommand, param)) {
#ifdef DEVELOPER_MODE
                llOwnerSay("Command not recognized: \"" + chatCommand + "\"");
#else
                ;
#endif
            }
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
}

//========== CHATHANDLER ==========
