//========================================
// Main.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 28 February 2014

#define MAIN_LSL
#include "include/GlobalDefines.lsl"

// Note that some doll types are special....
//    - regular: used for standard Dolls, including non-transformable
//    - slut: can be stripped (like Pleasure Dolls)
//    - Display: poses dont time out
//    - Key: doesnt wind down - Doll can be worn by other Dolly as Key
//    - Builder: doesnt wind down

//========================================
// VARIABLES
//========================================

// Transforming Keys:
//
// A TransformingKey is - or was - set by the presence of a
// Transform.lsl script in the Key. It makes a call into this
// script, thus:
//
//     llMessageLinked(LINK_THIS, 18, "here");
//
// and triggers a setting of the following variable,
// making this a transforming key:
//
// All other settings of this variable have been removed,
// including the SetDefaults and the NCPrefs.

integer minsLeft;
//integer canPose;

float lastEmergencyTime;
#define EMERGENCY_LIMIT_TIME 43200.0 // 12 (RL) Hours = 43200 Seconds

string rlvAPIversion;

// Current Controller - or Mistress
key winderID = NULL_KEY;
key dollID = NULL_KEY;
key keyHandler = NULL_KEY;

list windTimesInput;

integer dialogChannel;
integer chatChannel = 75;
integer chatHandle;
integer targetHandle;
#ifdef SIM_FRIENDLY
integer lowScriptMode;
#endif
integer busyIsAway;
integer ticks;
integer broadcastOn = -1873418555;
integer broadcastHandle;

integer afk;
integer autoAFK = 1;
//integer autoTP;
integer canAFK = 1;
//integer canCarry = 1;
//integer canDress = 1;
//integer canFly = 1;
//integer canSit = 1;
//integer canStand = 1;
//integer canRepeat = 1;
//integer canWear;
//integer canUnwear;
integer clearAnim;
integer collapsed;
integer configured;
integer demoMode;
//integer detachable = 1;
//integer doWarnings;
//integer helpless;
//integer pleasureDoll;
integer isTransformingKey;
//integer visible = 1;
integer quiet;
integer RLVok;
integer RLVck = 1;
integer signOn;
//integer takeoverAllowed;
//integer timerStarted;
integer warned;
integer wearLock;
integer timeReporting = 1;

integer debugLevel = DEBUG_LEVEL;

// If the key is a Transforming Key - one that can transform from one
// type of Doll to another - this tracks the current type of doll.
string dollType = "Regular";

float winderRechargeTime;
float wearLockExpire;
float lastRandomTime;
float menuSleep;
float lastTickTime;
float timeToJamRepair;
float windamount      = 1800.0; // 30 * SEC_TO_MIN;    // 30 minutes
float keyLimit        = 10800.0;
float effectiveLimit  = keyLimit;
float timeLeftOnKey   = windamount;
float windRate        = 1.0;
float baseWindRate    = windRate;
float displayWindRate = windRate;
integer HTTPinterval  = 60;
integer HTTPthrottle  = 10;
integer lastPostTimestamp;
integer lastSendTimestamp;
float collapseTime;
list windTimes        = [ 30 ];
list blacklist;

string keyAnimation;
string dollName;
string mistressName;
string pronounHerDoll = "Her";
string pronounSheDoll = "She";
key mistressQuery;

key simRatingQuery;

//========================================
// FUNCTIONS
//========================================
string cannoizeName(string name) {
    // Many new SL users fail to undersand the meaning of "Legacy Name" the name format of the DB
    // and many older SL residents confuse usernames and legasy names.  This function checks for
    // the presence of features inidcating we have been supplied with an invalid name which seems tp
    // be encoded in username format and makes the converstion to the valid legacy name.
    integer index;

    if ((index = llSubStringIndex(name, ".")) != -1)
        name = llInsertString(llDeleteSubString(name, index, index), index, " ");
    else if (llSubStringIndex(name, " ") == -1) name += " resident";

    return llToLower(name);
}

float windKey() {
    float windLimit = effectiveLimit - timeLeftOnKey;
    float wound;

    // Return if winding is irrelevant
    if (windLimit <= 0) return 0;

    // Return windamount if less than remaining capacity
    else if (windLimit >= (windamount + 60.0)) { // Avoid creating a 0 minute wind situation by treating less than a minute from full as
                                                 // a full wind.
        timeLeftOnKey += windamount;
        wound = windamount;
    }

    // Eles return limit - timeleft
    else {
        // Inform doll of full wind
        llOwnerSay("You have been fully wound - " + (string)llRound(effectiveLimit / (SEC_TO_MIN * setWindRate())) + " minutes remaining.");
        timeLeftOnKey += windLimit;
        wound = windLimit;
    }

    return wound;
}

doWind(string name, key id) {
    if (!canRepeat && (id == winderID) && !((id == NULL_KEY) || cdIsDoll(id) || cdIsController(id))) {
        lmSendToAgent("Dolly needs to be wound by someone else before you can wind her again.", id);
        return;
    }

    float wound = windKey();
    integer winding = llFloor(wound / SEC_TO_MIN);

    if (winding > 0) {
        lmSendToAgent("You have given " + dollName + " " + (string)winding + " more minutes of life.", id);

        lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
        if (collapsed == 1) uncollapse(1);

        if (timeLeftOnKey == effectiveLimit) {
            if (!quiet) llSay(0, dollName + " has been fully wound by " + name + ".");
            else lmSendToAgent(dollName + " is now fully wound.", id);
        } else {
            lmInternalCommand("windMenu", name, id);
            lmSendToAgent("Doll is now at " + formatFloat((float)timeLeftOnKey * 100.0 / (float)effectiveLimit, 2) + "% of capacity.", id);
        }

        llSleep(1.0); // Make sure that the uncollapse RLV runs before sending the message containing winder name.
        // Is this too spammy?
        llOwnerSay("Have you remembered to thank " + name + " for winding you?");

        winderID = id;
    }
}

#ifndef DEVELOPER_MODE
ifPermissions() {
    key grantor = llGetPermissionsKey();
    integer perm = llGetPermissions();

    if (grantor != NULL_KEY && grantor != dollID) {
        llResetOtherScript("Start");
        llSleep(10);
    }

    if (!((perm & PERMISSION_MASK) == PERMISSION_MASK))
        llRequestPermissions(dollID, PERMISSION_MASK);

    if (perm & PERMISSION_ATTACH && !cdAttached()) llAttachToAvatar(ATTACH_BACK);
    else if (!cdAttached() && llGetTime() > 120.0) {
        llOwnerSay("@acceptpermission=add");
        llRequestPermissions(dollID, PERMISSION_ATTACH);
    }
}
#endif

//========================================
// STATES
//========================================

// default state should be changed to normal state

default {

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    // This should set up generic defaults
    // not specific to owner
    state_entry() {
        dollID = llGetOwner();
        if (llGetAttached()) llRequestPermissions(dollID, PERMISSION_MASK);
    }

    on_rez(integer start) {
        llSetTimerEvent(0.0);
        timerStarted = 0;
        configured = 0;
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key query_id, string data) {
        if (query_id == mistressQuery) {
            mistressName = data;
            llOwnerSay("Your Mistress is " + mistressName);
        }

        if (query_id == simRatingQuery) {
            simRating = data;
            lmRating(simRating);

            string msg = "Entered " + llGetRegionName() + " rating is " + llToLower(simRating);
#ifdef ADULT_MODE
            if (pleasureDoll || (dollType == "Slut")) {
                if (cdRating2Integer(simRating) < 2) msg += " stripping disabled.";
                else msg += " stripping enabled.";
            }
#endif
            llOwnerSay(msg);
        }
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & CHANGED_REGION) {
            simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);
            lmSendConfig("keyHandler", (string)(keyHandler = NULL_KEY));
        }
        if (change & CHANGED_OWNER) {
            llSleep(60);
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {   // called every timeinterval (tick)
        // Doing the following every tick:
        //    1. Are we checking for RLV? Reset...
        //    2. Carrier still present (in region)?
        //    3. Is Doll away?
        //    4. Wind down
        //    5. How far away is carrier? ("follow")
        displayWindRate = setWindRate();
        float timerInterval;
        if (cdAttached()) timerInterval = llGetAndResetTime();

        // Increment a counter
        ticks++;

        //debugSay(5, "afk=" + (string)afk + " velocity=" + (string)llGetVel() + " speed=" + formatFloat(llVecMag(llGetVel()), 2) + "m/s (llVecMag(llGetVel()))");

        timeLeftOnKey -= timerInterval * windRate;
        if (timeLeftOnKey < 0) timeLeftOnKey = 0.0;

        if (collapsed) collapseTime += timerInterval;
        if (wearLock) wearLockExpire -= timerInterval;

        // False collapse? Collapsed = 1 while timeLeftOnKey is positive is an invalid condition
        if (collapsed == 1 && timeLeftOnKey > 0.0) {
            uncollapse(0);
        }

        if (ticks % 2 == 0) {
#ifndef DEVELOPER_MODE
                ifPermissions();
#endif

            if (canAFK) {
                integer dollAway = ((llGetAgentInfo(dollID) & (AGENT_AWAY | (AGENT_BUSY * busyIsAway))) != 0);
                // When Dolly is "away" - enter AFK
                // Also set away when
                if (autoAFK && (afk != dollAway)) {
                    afk = dollAway;
                    lmSendConfig("afk", (string)afk);
                    displayWindRate = setWindRate();
                    lmInternalCommand("setAFK", (string)afk + "|1|" + formatFloat(windRate, 1) + "|" + (string)llRound(timeLeftOnKey / (SEC_TO_MIN * displayWindRate)), NULL_KEY);
                }
            }

            // Update sign if appropriate
            string primText = llList2String(llGetPrimitiveParams([ PRIM_TEXT ]), 0);
            if (collapsed && primText != "Disabled Dolly!") llSetText("Disabled Dolly!", <1.0, 0.0, 0.0>, 1.0);
            else if (afk && primText != dollType + " Doll (AFK)") llSetText(dollType + " Doll (AFK)", <1.0, 1.0, 0.0>, 1.0);
            else if (signOn && primText != dollType + " Doll") llSetText(dollType + " Doll", <1.0, 1.0, 1.0>, 1.0);
            else if (!signOn && !afk && !collapsed && primText != "") llSetText("", <1.0, 1.0, 1.0>, 1.0);

          /*--------------------------------
            WINDING DOWN.....
            --------------------------------
            A specific test for collapsed status is no longer required here
            as being collapsed is one of several conditions which forces the
            wind rate to be 0.
            Others which cause this effect are not being attached to spine
            and being doll type Builder or Key*/

            if (ticks % 10 == 0) {
                // Check post interval
                if (((lastPostTimestamp + (HTTPinterval - HTTPthrottle)) < llGetUnixTime()) && (lastSendTimestamp <= lastPostTimestamp)) {
                    // Check wearlock timer
                    if (wearLock) {
                        if (wearLockExpire <= 0.0) {
                            wearLockExpire = 0.0;
                            lmInternalCommand("wearLock", (string)(wearLock = 0), NULL_KEY);
                        }
                    }
    
                    lmInternalCommand("getTimeUpdates", "", NULL_KEY);
                }
            }

            if (ticks % 30 == 0) {
                if (windRate != 0.0) {
                    minsLeft = llRound(timeLeftOnKey / (SEC_TO_MIN * displayWindRate));

                    if (doWarnings && (minsLeft == 30 || minsLeft == 15 || minsLeft == 10 || minsLeft ==  5 || minsLeft ==  2) && !warned) {
                        // FIXME: This can be seen as a spammy message - especially if there are too many warnings
                        // FIXME: What do we think about this being gated by the quiet key option?  Should we just leave it without as
                        // it has it's own option, though quiet version still warns the doll so perhaps still of use to some?
                        if (!quiet) llSay(0, dollName + " has " + (string)minsLeft + " minutes left before they run down!");
                        else llOwnerSay("You have " + (string)minsLeft + " minutes left before winding down!");
                        warned = 1; // have warned now: dont repeat same warning
                    }
                    else warned = 0;

                    // Dolly is DONE! Go down... and yell for help.
                    if (!collapsed && timeLeftOnKey <= 0.0) {
                        // This message is intentionally excluded from the quiet key setting as it is not good for
                        // dolls to simply go down silently.
                        llSay(0, "Oh dear. The pretty Dolly " + dollName + " has run out of energy. Now if someone were to wind them... (Click on their key.)");
                        // Must update time before executing collapse
                        lmSendConfig("timeLeftOnKey", (string)(timeLeftOnKey = 0.0));
                        lmSendConfig("collapseTime", (string)(collapseTime = 0.0));
                        lmInternalCommand("collapse", "1", NULL_KEY);
                    }
                }

#ifdef DEVELOPER_MODE
                if (timeReporting) llOwnerSay("Script Time: " + formatFloat(llList2Float(llGetObjectDetails(llGetKey(), [ OBJECT_SCRIPT_TIME ]), 0) * 1000000, 2) + "µs");
#endif

                scaleMem();
            }
        }
    }

    //----------------------------------------
    // RECEIVED A LINK MESSAGE
    //----------------------------------------
    // For Transforming Key operations
    link_message(integer source, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);
        string script = llList2String(split, 0);

        if (code == 102) {
            if (llList2String(split, 0) == "ServiceReceiver") {
                if (timeLeftOnKey > effectiveLimit) timeLeftOnKey = effectiveLimit;

                float displayRate = setWindRate();
                llOwnerSay("You have " + (string)llRound(timeLeftOnKey / 60.0 / displayRate) + " minutes of life remaning.");
                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
            }
            
            configured = 1;
            
            llSetTimerEvent(STD_RATE);
            if (lowScriptMode) llSetTimerEvent(LOW_RATE);
            timerStarted = 1;

            if (!cdAttached()) llSetTimerEvent(60.0);
        }

        else if (code == 104) {
            if (script != "Start") return;
            dollID = llGetOwner();
            dollName = llGetDisplayName(dollID);

            broadcastHandle = llListen(broadcastOn, "", "", "");
            chatHandle = llListen(chatChannel, "", dollID, "");

            clearAnim = 1;
        }

        else if (code == 105) {
            if (script != "Start") return;
            clearAnim = 1;

            llSetTimerEvent(STD_RATE);
            if (lowScriptMode) llSetTimerEvent(LOW_RATE);
            timerStarted = 1;

            if (!cdAttached()) llSetTimerEvent(60.0);
        }

        else if (code == 135) {
            float delay = llList2Float(split, 1);
            scaleMem();
            memReport(delay);
        }

        else if (code == 300) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);
            split = llDeleteSubList(split, 0, 1);

                 if (name == "afk")                               afk = (integer)value;
            else if (name == "autoAFK")                       autoAFK = (integer)value;
            //else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "canAFK") {
                canAFK = (integer)value;
                if (afk) { // If doll is already AFK bring them out of it so they are not stuck
                    lmSendConfig("afk", (string)afk);
                    displayWindRate = setWindRate();
                    lmInternalCommand("setAFK", (string)afk + "|1|" + formatFloat(windRate, 1) + "|" + (string)llRound(timeLeftOnKey / (SEC_TO_MIN * displayWindRate)), NULL_KEY);
                }
            }
            //else if (name == "canCarry")                     canCarry = (integer)value;
            //else if (name == "canDress")                     canDress = (integer)value;
            //else if (name == "canFly")                         canFly = (integer)value;
            //else if (name == "canSit")                         canSit = (integer)value;
            //else if (name == "canStand")                     canStand = (integer)value;
            else if (name == "canRepeat")                   canRepeat = (integer)value;
            else if (name == "collapsed") {
                collapsed = (integer)value;
                setWindRate();
            }
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                 debugLevel = (integer)value;
#endif
            else if (name == "configured")                 configured = (integer)value;
            //else if (name == "detachable")                 detachable = (integer)value;
            //else if (name == "helpless")                     helpless = (integer)value;
            //else if (name == "pleasureDoll")             pleasureDoll = (integer)value;
            //else if (name == "isTransformingKey")   isTransformingKey = (integer)value;
            //else if (name == "isVisible")                     visible = (integer)value;
            else if (name == "busyIsAway")                 busyIsAway = (integer)value;
            else if (name == "quiet")                           quiet = (integer)value;
            //else if (name == "RLVok")                           RLVok = (integer)value;
            //else if (name == "signOn")                         signOn = (integer)value;
            else if (name == "timeLeftOnKey")           timeLeftOnKey = (float)value;
            else if (name == "windamount")                 windamount = (float)value;
            else if (name == "wearLockExpire")         wearLockExpire = (float)value;
            else if (name == "baseWindRate")             baseWindRate = (float)value;
            else if (name == "displayWindRate")       displayWindRate = (float)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
            else if (name == "collapseTime")             collapseTime = (float)value;
            //else if (name == "poserID")                       poserID = (key)value;
            else if (name == "keyAnimation")             keyAnimation = value;
            //else if (name == "mistressName")             mistressName = value;
            else if (name == "dollType")                     dollType = value;
            else if (name == "pronounHerDoll")         pronounHerDoll = value;
            else if (name == "pronounSheDoll")         pronounSheDoll = value;
            else if (name == "blacklist")                   blacklist = split;
            else if (name == "dialogChannel")           dialogChannel = (integer)value;
            else if (name == "debugLevel")                 debugLevel = (integer)value;
            else if (name == "keyHandler") {
                keyHandler = (key)value;
            }
            else if (name == "demoMode") {
                demoMode = (integer)value;
                if (demoMode) {
                    effectiveLimit = DEMO_LIMIT;
                }
                else {
                    effectiveLimit = keyLimit;
                }
                if (configured) lmInternalCommand("setWindTimes", llDumpList2String(windTimesInput, "|"), NULL_KEY);
            }
            else if (name == "keyLimit") {
                keyLimit = (float)value;
                if (demoMode) effectiveLimit = DEMO_LIMIT;
                else effectiveLimit = keyLimit;

                if (timeLeftOnKey > effectiveLimit) lmSendConfig("timeLeftOnKey", (string)(timeLeftOnKey = effectiveLimit));
                if (configured) lmInternalCommand("setWindTimes", llDumpList2String(windTimesInput, "|"), NULL_KEY);
            }
#ifdef DEVELOPER_MODE
            else if (llToLower(name) == "timereporting")           timeReporting = (integer)value;
#endif
#ifdef SIM_FRIENDLY
            else if (name == "lowScriptMode") {
                lowScriptMode = (integer)value;
                if (timerStarted) {
                    llSetTimerEvent(STD_RATE);
                    if (lowScriptMode) llSetTimerEvent(LOW_RATE);
                }
            }
#endif
        }

        else if (code == 305) {
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llDeleteSubList(split, 0, 1);

            if (cmd == "setAFK") {
                afk = llList2Integer(split, 0);

                integer autoSet = llList2Integer(split, 1);

                if (!autoSet) {
                    integer dollAway = ((llGetAgentInfo(dollID) & (AGENT_AWAY | (AGENT_BUSY * busyIsAway))) != 0);
                    if (dollAway == afk) autoAFK = 1;
                    else autoAFK = 0;
                }

                debugSay(5,"DEBUG", "setAFK, afk=" + (string)afk + ", autoSet=" + (string)autoSet + ", autoAFK=" + (string)autoAFK);

                lmSendConfig("afk", (string)afk);
                lmSendConfig("autoAFK", (string)autoAFK);
            }
            
            else if (cmd == "getTimeUpdates") {
                if (timeLeftOnKey != 0.0) lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
                if (wearLockExpire != 0.0) lmSendConfig("wearLockExpire", (string)wearLockExpire);
                if (collapseTime != 0.0) lmSendConfig("collapseTime", (string)(collapseTime = (collapseTime * (collapsed != 0))));
                lastSendTimestamp = llGetUnixTime();
                
                // In offline mode we update the timer locally
                if (offlineMode) lastPostTimestamp = lastSendTimestamp;
            }

            else if (cmd == "setWindTimes") {
                integer i; integer start = llGetListLength(split);

                windTimesInput = split;
                windTimes = [];

                for (i = 0; i < start; i++) {
                    integer value = (integer)llStringTrim(llList2String(split, i), STRING_TRIM);
                    if ((value > 0) && (llListFindList(windTimes, [ value ]) == -1) && (((float)value * 60.0) <= keyLimit)) windTimes += value;
                }
                
                integer l = llGetListLength(windTimes); i = 1;
                while (l > 11) windTimes = llDeleteSubList(llListSort(windTimes, l-- / ++i, 1), i, i);
                
                if (start > l) lmSendToAgent("One or more times were filtered accepted list is " + llList2CSV(windTimes), id);
                if (script != "ServiceReceiver") lmSendConfig("windTimes", llDumpList2String(windTimes, "|"));
            }

            else if (cmd == "wearLock") {
                wearLockExpire = WEAR_LOCK_TIME;
                if (llList2Integer(split, 0)) {
                    lmSendConfig("wearLockExpire", (string)(wearLockExpire - WEAR_LOCK_TIME));
                    displayWindRate = setWindRate();
                }
                else lmSendConfig("wearLockExpire", (string)(wearLockExpire = 0.0));
            }

            else if (llGetSubString(cmd,-8,-1) == "collapse") {
                displayWindRate = setWindRate();
                if ((cmd == "collapse") && ((llList2Integer(split,0) != 2) && (timeLeftOnKey > 0.0))) uncollapse(1);
                lmSendConfig("collapseTime", (string)(collapseTime = 0.0));
            }

            // Deny access to the menus when the command was recieved from blacklisted avatar
            if (llListFindList(blacklist, [ (string)id ]) != -1) {
                lmSendToAgent("You are not permitted to access this key.", id);
                return;
            }
            else if (cmd == "windMenu") {
                if (llGetListLength(windTimes) == 1) {
                    lmInternalCommand("mainMenu", "", id);;
                    return;
                }

                // Compute "time remaining" message for mainMenu/windMenu
                string timeleft;

                displayWindRate = setWindRate();
                integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));

                if (minsLeft > 0) {
                    timeleft = "Dolly has " + (string)minsLeft + " minutes remaining.\n";

                    timeleft += "Key is ";
                    if (windRate == 0.0) timeleft += "not ";
                    timeleft += "winding down";

                    if (windRate == 0.0) timeleft += ".";
                    else timeleft += " at " + formatFloat(displayWindRate, 1) + "x rate.";

                    timeleft += ". ";
                }
                else timeleft = "Dolly has no time left.";
                timeleft += "\n";

                string msg = "How many minutes would you like to wind?";

                list buttons = llListSort(windTimes, 1, 1);
                if (demoMode) {
                    buttons = [ "Wind 1", "Wind 2" ]; // If we are in demo mode make our buttons make sense
                }
                else {
                    integer i;
                    for (i = 0; i < llGetListLength(buttons); i++) {
                        if (llList2String(buttons, i) != MAIN)
                            buttons = llListReplaceList(buttons, [ "Wind " + llList2String(buttons, i) ], i, i);
                    }
                }

                llDialog(id, timeleft + msg, dialogSort(buttons + MAIN), dialogChannel);
            }
        }

        else if (code == 350) {
            string script = llList2String(split, 0);
            RLVok = llList2Integer(split, 1);
            rlvAPIversion = llList2String(split, 2);
            // When rlv confirmed....vefify collapse state... no escape!
            if (collapsed == 1 && timeLeftOnKey > 0) uncollapse(0);
            else if (!collapsed && timeLeftOnKey <= 0) lmInternalCommand("collapse", "0", NULL_KEY);

            if (!canDress) llOwnerSay("Other people cannot outfit you.");

            simRating = "";
            simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);
        }

        else if (code == 500) {
            string script = llList2String(split, 0);
            string choice = llList2String(split, 1);
            string name = llList2String(split, 2);

            if (llGetSubString(choice, 0, 3) == "Wind") {

                if (choice == "Wind Times") return; // Handled in MenuHandler

                if (timeLeftOnKey + 60.0 > effectiveLimit) {
                    llDialog(id, "Dolly is already fully wound.", [MAIN], dialogChannel);
                    return;
                }
                else if (choice == "Wind Times") return;
                else if (choice == "Wind Emg") {
                    // Give this a time limit: can only be done once
                    // in - say - 6 hours... at least maxwindtime *2 or *3.

                    if ( (winderRechargeTime == 0) || (winderRechargeTime <= llGetUnixTime()) ) {
                        if (collapsed == 1) {
                            lmSendToController(dollName + " has activated the emergency winder.");

                            windamount = llListStatistics(LIST_STAT_MEDIAN, windTimes) * SEC_TO_MIN;
                            //if (demoMode) windamount = 180.0;
                            debugSay(3, "DEBUG", "Doing emergency wind, using median wind time of " + (string)llRound(windamount / SEC_TO_MIN) + " mins.");
                            windKey();
                            lmSendConfig("winderRechargeTime", (string)(winderRechargeTime = (llGetUnixTime() + EMERGENCY_LIMIT_TIME)));

                            llOwnerSay("Emergency self-winder has been triggered by Doll.");
                            llOwnerSay("Emergency circuitry requires recharging and will be available again in " + (string)llRound(EMERGENCY_LIMIT_TIME / 3600.0) + " hours.");
                        }
                        else if (collapsed == 2) {
                            llOwnerSay("The emergency winder motor whirrs, splutters and then falls silent unable to budge your jammed mechanism.");
                        }
                        else {
                            llOwnerSay("No emergency exists - emergency self-winder deactivated.");
                        }
                    }
                    else {
                       llOwnerSay("Emergency self-winder is not yet recharged there is still " + formatFloat(winderRechargeTime / 3600.0, 2) + " hours before it will be ready again.");
                    }
                }
                else if (llStringLength(choice) > 5) {
                    windamount = (float)llGetSubString(choice, 5, -1) * SEC_TO_MIN;
                    doWind(name, id);
                }
                else if ((llGetListLength(windTimes) == 1) || ((timeLeftOnKey + (llListStatistics(LIST_STAT_MIN, windTimes) * SEC_TO_MIN)) > keyLimit)) {
                    debugSay(3, "DEBUG", "Doing minimum wind and skipping menu.");
                    windamount = llListStatistics(LIST_STAT_MIN, windTimes) * SEC_TO_MIN;
                    if (demoMode) windamount = SEC_TO_MIN;
                    doWind(name, id);
                }
                else lmInternalCommand("windMenu", "", id);
            }
        }
        
        else if (code == 501) {
            integer textboxType = llList2Integer(split, 1);
            split = llDeleteSubList(split, 0, 2);
            if (textboxType == 3) {
                split = llParseString2List(llDumpList2String(split, "|"), [" ",",","|"], []);

                lmInternalCommand("setWindTimes", llDumpList2String(split, "|"), id);
            }
        }

        else if (code == 850) {
            string type = llList2String(split, 1);
            string value = llList2String(split, 2);

                 if (type == "HTTPinterval")            HTTPinterval = (integer)value;
            else if (type == "HTTPthrottle")            HTTPthrottle = (integer)value;
            else if (type == "lastPostTimestamp")       lastPostTimestamp = (integer)value;
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

            if (llGetInventoryType(choice) == 20 || llGetSubString(choice, 0, 0) == "." | llGetSubString(choice, 0, 0) == "!") {
                if (llGetInventoryType(choice) != 20) choice = llGetSubString(choice, 1, -1);
                if (cdNoAnim() || (!cdCollapsedAnim() && cdSelfPosed())) {
                    lmInternalCommand("setPose", choice, dollID);
                }
                else llOwnerSay("You try to regain control over your body in an effort to set your own pose but even that is beyond doll's control.");
                return;
            }

            integer space = llSubStringIndex(choice, " ");
            if (space == -1) {
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
                    lmSendToAgent("%TEXT_HELP%", dollID);
                }
                // Demo: short time span
                else if (choice == "demo") {
                    lmSendConfig("demoMode", (string)(demoMode = !demoMode));
                    if (demoMode) {
                        effectiveLimit = DEMO_LIMIT;
                        if (timeLeftOnKey > effectiveLimit) timeLeftOnKey = effectiveLimit;
                        llOwnerSay("Key set to run in demo mode: time limit set to " + (string)llRound(DEMO_LIMIT / (SEC_TO_MIN * setWindRate())) + " minutes.");
                    }
                    // Note that the LIMIT is restored.... but the time left on key is unchanged
                    else {
                        effectiveLimit = keyLimit;
                        llOwnerSay("Key set to run normally: time limit set to " + (string)llRound(effectiveLimit / (SEC_TO_MIN * setWindRate())) + " minutes.");
                    }
                }
                else if (choice == "poses") {
                    integer  n = llGetInventoryNumber(20);

                    // Menu max limit of 11... report error
                    if (n > 11) {
                        llOwnerSay("Too many poses! Found " + (string)n + " poses (max is 11)");
                    }

                    while(n) {
                        string thisPose = llGetInventoryName(20, --n);

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
                    lmMenuReply("Wind Emg", dollName, dollID);
                }
                else if (choice == "xstats") {
                    llOwnerSay("AFK time factor: " + formatFloat(RATE_AFK, 1) + "x");
                    llOwnerSay("Wind amount: " + (string)llRound(windamount / (SEC_TO_MIN * setWindRate())) + " minutes.");

                    {
                        string s;

                        s = "Doll can be teleported ";
                        if (autoTP) {
                            llOwnerSay(s + "without restriction.");
                        }
                        else {
                            llOwnerSay(s + "with confirmation.");
                        }

                        s = "Key is ";
                        if (detachable) {
                            llOwnerSay(s + "detachable.");
                        }
                        else {
                            llOwnerSay(s + "not detachable.");
                        }

                        s = " be dressed by others.";
                        if (canDress) {
                            llOwnerSay("Doll can" + s);
                        }
                        else {
                            llOwnerSay("Doll cannot" + s);
                        }

                        s = "Doll can";
                        if (canFly) {
                            llOwnerSay(s + " fly.");
                        }
                        else {
                            llOwnerSay(s + "not fly.");
                        }

                        s = "RLV is ";
                        if (RLVok) {
                            llOwnerSay(s + "active.");
                        }
                        else {
                            llOwnerSay(s + "not active.");
                        }
                    }

                    if (windRate == 0.0) {
                        llOwnerSay("Key is not winding down.");
                    }

                }
                else if (choice == "stat") {
                    float t1 = timeLeftOnKey / (SEC_TO_MIN * setWindRate());
                    float t2 = effectiveLimit / (SEC_TO_MIN * setWindRate());
                    float p = t1 * 100.0 / t2;

                    string s = "Time: " + (string)llRound(t1) + "/" +
                                (string)llRound(t2) + " min (" + formatFloat(p, 2) + "% capacity)";
                    if (afk) {
                        s += " (current wind rate " + formatFloat(setWindRate(), 1) + "x)";
                    }
                    llOwnerSay(s);
                }
                else if (choice == "stats") {
                    setWindRate();
                    llOwnerSay("Time remaining: " + (string)llRound(timeLeftOnKey / (SEC_TO_MIN * setWindRate())) + " minutes of " +
                                (string)llRound(effectiveLimit / (SEC_TO_MIN * setWindRate())) + " minutes.");
                    if (windRate < 1.0) {
                        llOwnerSay("Key is unwinding at a slowed rate of " + formatFloat(windRate, 1) + "x.");
                    } else if (windRate > 1.0) {
                        llOwnerSay("Key is unwinding at an accelerated rate of " + formatFloat(windRate, 1) + "x.");
                    }

                    /*if (MistressID) {
                        llOwnerSay("Controller: " + mistressName);
                    }
                    else {
                        llOwnerSay("Controller: none");
                    }*/

                    if (!cdCollapsedAnim() && !cdNoAnim()) {
                    //    llOwnerSay(dollID, "Current pose: " + currentAnimation);
                    //    llOwnerSay(dollID, "Pose time remaining: " + (string)(poseTime / SEC_TO_MIN) + " minutes.");
                        llOwnerSay("Doll is posed.");
                    }

                    lmMemReport(2.0);
                }
            }
            else if (choice == "release") {
                if (poserID != dollID) llOwnerSay("Dolly tries to take control of her body from the pose but she is no longer in control of her form.");
                else lmInternalCommand("doUnpose", "", dollID);
            }
            else {
                string param = llStringTrim(llGetSubString(choice, space + 1, -1), STRING_TRIM);
                choice = llStringTrim(llGetSubString(choice, 0, space - 1), STRING_TRIM);

                if (choice == "channel") {
                    string c = param;
                    if ((string) ((integer) c) == c) {
                        integer ch = (integer) c;
                        if (ch != 0 && ch != DEBUG_CHANNEL) {
                            chatChannel = ch;
                            llListenRemove(chatHandle);
                            chatHandle = llListen(ch, "", "", "");
                        }
                    }
                }
                else if (choice == "controller") {
                    lmInternalCommand("getMistressKey", cannoizeName(param), NULL_KEY);
                }
                else if (choice == "blacklist") {
                    lmInternalCommand("getBlacklistKey", cannoizeName(param), NULL_KEY);
                }
                else if (choice == "unblacklist") {
                    lmInternalCommand("getBlacklistKey", cannoizeName(param), NULL_KEY);
                }
#ifdef DEVELOPER_MODE
                else if (choice == "debug") {
                    lmSendConfig("debugLevel", (string)(debugLevel = (integer)param));
                    llOwnerSay("DEBUG_LEVEL = " + (string)debugLevel);
                }
                else if (choice == "inject") {
                    list params = llParseString2List(param, ["#"], []);
                    llOwnerSay("INJECT LINK:\nLink Code: " + (string)llList2Integer(params, 0) + "\n" +
                               "Data: " + SCRIPT_NAME + "|" + llList2String(params, 1) + "\n" +
                               "Key: " + (string)llList2Key(params, 2));
                    llMessageLinked(LINK_THIS, llList2Integer(params, 0), SCRIPT_NAME + "|" + llList2String(params, 1), llList2Key(params, 2));
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
                string subcommand = llGetSubString(choice, 5, -1);
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

#ifndef DEVELOPER_MODE
    run_time_permissions(integer perm) {
        if (!llGetAttached()) llOwnerSay("@acceptpermission=rem");
        ifPermissions();
    }
#endif
}
