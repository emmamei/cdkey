//========================================
// Main.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

#include "include/GlobalDefines.lsl"

#define cdNullList(a) (llGetListLength(a)==0)
#define cdListMin(a) llListStatistics(LIST_STAT_MIN,a)
#define cdKeyStopped() (!windingDown)
#define cdTimeSet(a) (a!=0)
#define cdResetKey() llResetOtherScript("Start")
#define UNSET -1
#define lmCollapse(a) lmInternalCommand("collapse",(string)(a),NULL_KEY)
#define lmUncollapse() lmInternalCommand("collapse","0",NULL_KEY)

// Note that some doll types are special....
//    - regular: used for standard Dolls, including non-transformable
//    - slut: can be stripped (like Pleasure Dolls)
//    - Display: poses dont time out
//    - Key: doesnt wind down - Doll can be worn by other Dolly as Key
//    - Builder: doesnt wind down

//========================================
// VARIABLES
//========================================

string msg;
integer minsLeft;

float lastEmergencyTime;

// EMERGENCY_LIMIT_TIME needs to be an even number of hours (in seconds)
#define EMERGENCY_LIMIT_TIME 43200 // 12 (RL) Hours = 43200 Seconds

string rlvAPIversion;
#ifdef DEVELOPER_MODE
float thisTimerEvent;
float lastTimerEvent;
float timerInterval;
#endif
integer timerMark;
integer lastTimerMark;
integer timeSpan;

key lastWinderID = NULL_KEY;

integer targetHandle;
integer lowScriptTimer;
integer lastLowScriptTime;

integer clearAnim;
integer RLVck = 1;
integer warned;

integer wearLockExpire;
integer carryExpire;
#ifdef JAMMABLE
integer jamExpire;
#endif
integer poseExpire;
// Note that unlike the others, we do not maintain
// transformLockExpire in this script
integer transformLockExpire;

float effectiveLimit  = keyLimit;
integer windMins = 30;
float effectiveWindTime = 30.0;

string mistressName;

key simRatingQuery;

//========================================
// FUNCTIONS
//========================================
#ifdef LOCKON
ifPermissions() {
    key grantor = llGetPermissionsKey();
    integer perm = llGetPermissions();

    if (grantor != NULL_KEY && grantor != dollID) {
        cdResetKey();
        llSleep(10);
    }

    if ((perm & PERMISSION_MASK) != PERMISSION_MASK) {
        llRequestPermissions(dollID, PERMISSION_MASK);
        return;
    }
}
#endif

setAfk(integer setting) {
    // afk setting 2 is special: means we automatically set AFK, in
    // contrast to the user setting AFK otherwise

    setWindRate();

    if (setting != 2) {
        // setting is either 0 (FALSE) or 1 (TRUE)
        integer dollAway = ((llGetAgentInfo(dollID) & (AGENT_AWAY | (AGENT_BUSY * busyIsAway))) != 0);

        if (dollAway != afk) autoAFK = 0;
        else autoAFK = 1;
    }

    // The odd code for setting AFK folds values 1 and 2 into
    // a single value
    lmSendConfig("afk", (string)(afk = (setting != 0)));
    lmSendConfig("autoAFK", (string)autoAFK);
}

uncollapse() {
    string primText = llList2String(llGetPrimitiveParams([ PRIM_TEXT ]), 0);
    cdSetHovertext("",INFO); // uses primText

    lmSendConfig("collapseTime", (string)(collapseTime = 0));

    // This configuration triggers RLV release
    lmSendConfig("collapsed", (string)(collapsed = 0));

    lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);

    // queued up: broadcast new times
    lmInternalCommand("getTimeUpdates", "", llGetKey());

    // Set hovertext
    lmInternalCommand("setHovertext", "", llGetKey());

#ifdef JAMMABLE
    lmSendConfig("jamExpire", (string)(jamExpire = 0));
#endif

    // Among other things, this will set the Key's turn rate
    setWindRate();
}

collapse(integer newCollapseState) {

    // newCollapseState describes state being entered;
    // collapsed describes current state
    //
    // We should be able to reject calls that change nothing - but
    // processing can be repeated and nothing bad should happen - and
    // that is how things acted before. Leave this code commented for now.
    //
    // We might have a situation where a collapse state needs to be refreshed:
    // so allow repeated calls
    //if (collapsed == newCollapseState) return; // Make repeated calls fast and unnecessary
    if (newCollapseState == 0) {
        uncollapse();
        return;
    }

    debugSay(3,"DEBUG-MAIN","Entering new collapse state (" + (string)newCollapseState + ") with time left of " + (string)timeLeftOnKey);

    string primText = llList2String(llGetPrimitiveParams([ PRIM_TEXT ]), 0);

    lmSendConfig("lastWinderID", (string)(lastWinderID = NULL_KEY));

    // Entering a collapsed state
    if (newCollapseState == NO_TIME) {
        lmSendConfig("timeLeftOnKey", (string)(timeLeftOnKey = 0));

        // Direct call to set Hovertext
        cdSetHovertext("Disabled Dolly!",CRITICAL); // uses primText
    }
#ifdef JAMMABLE
    else if (newCollapseState == JAMMED) {
        // Default time span (random) = 120.0 (two minutes) to 300.0 (five minutes)
        if (collapsed != JAMMED)
            jamExpire = llGetUnixTime() + JAM_TIMEOUT;
    }
#endif

    // If not already collapsed, mark the start time
    if (collapsed == NOT_COLLAPSED) {
        collapseTime = llGetUnixTime();
        lmSendConfig("collapseTime", (string)collapseTime);
    }

#ifdef JAMMABLE
    // If not jammed, reset time to Jam Repair
    if (newCollapseState != JAMMED) {
        if (jamExpire) {
            jamExpire = 0;
            lmSendConfig("jamExpire", (string)jamExpire);
        }
    }
#endif

    // The three (four) pillars of being collapsed:
    //     1. collapsed != 0
    //     2. collapseTime is non-zero
    //     3. internalCommand "collapse" generated
    //    (4. timeLeftOnKey == 0 .... normally)

    if (collapsed != newCollapseState)
        lmSendConfig("collapsed", (string)(collapsed = newCollapseState));

    // queued up: broadcast new times
    lmInternalCommand("getTimeUpdates", "", llGetKey());

    // Among other things, this will set the Key's turn rate
    setWindRate();

    // Set hovertext
    lmInternalCommand("setHovertext", "", llGetKey());
}

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
        RLVok = UNSET;
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);
        if (cdAttached()) llRequestPermissions(dollID, PERMISSION_MASK);

        cdInitializeSeq();
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        RLVok = UNSET;
        timerStarted = 1;
        configured = 1;
        lmInternalCommand("setHovertext", "", llGetKey());
        llSetTimerEvent(30.0);
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key query_id, string data) {
        if (query_id == simRatingQuery) {
            simRating = data;
            lmRating(simRating);

#ifdef ADULT_MODE
            if (allowStrip || (dollType == "Slut") || hardcore) {
                if (simRating == "PG")
                    llOwnerSay("This region is rated G - so stripping is disabled.");
            }
#endif
        }
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & CHANGED_REGION)
            simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);
    }

    //----------------------------------------
    // TOUCH START
    //----------------------------------------
    touch_start(integer num) {
        key id = llDetectedKey(0);
        string agentName = llGetDisplayName(id);

        if (RLVok == UNSET) {
            if (dollID != id) {
                lmSendToAgent(dollName + "'s key clanks and clinks.... it doesn't seem to be ready yet.",id);
                llOwnerSay(agentName + " is fiddling with your Key but the state of RLV is not yet determined.");
                return;
            }
        }

        lmMenuReply(MAIN, agentName, id);
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {

        // Doing the following every tick:
        //    1. Are we checking for RLV? Reset...
        //    2. Carrier still present (in region)?
        //    3. Is Doll away?
        //    4. Wind down
        //    5. How far away is carrier? ("follow")

        //----------------------------------------
        // TIMER INTERVAL

        timerMark = llGetUnixTime();
        timeSpan = timerMark - lastTimerMark;

        // sanity checking - esp. for relogs
        if (timeSpan > 120) {
            timeSpan = 0;
            lastTimerMark = timerMark;
        }

#ifdef DEVELOPER_MODE
        // Informative.... but not directly relevant :)
        //debugSay(2,"DEBUG-MAIN", "Unix Time as float = " + (string)((float)llGetUnixTime()) + "; UNIX Time as integer = " + (string)llGetUnixTime());

        if (timeReporting) {
            thisTimerEvent = llGetTime();
            if (thisTimerEvent - lastTimerEvent < 120)
                llOwnerSay("Main Timer fired, interval " + formatFloat(thisTimerEvent - lastTimerEvent,3) + "s.");
            lastTimerEvent = thisTimerEvent;
        }
#endif

        //----------------------------------------
        // LOW SCRIPT MODE

        // Note that this is NOT the only place where lowScriptMode
        // is set. lowScriptMode is set via Start.lsl at startup  (to 0);
        // and is set by Avatar.lsl after TP or Region change and on Attach.
        // On those situations, it is perhaps good to be able to set the value
        // directly. This is, however, the ONLY place that lastLowScriptTIme
        // is set.
        //
        if (lowScriptMode) {

            // We're in lowScriptMode.... is that still
            // relevant? Check....

            if (cdLowScriptTrigger) {
                // lowScriptMode continues...
                debugSay(2,"DEBUG-MAIN", "Low Script Mode active and bumped");
                lastLowScriptTime = llGetUnixTime();
                lmSendConfig("lowScriptMode",(string)(lowScriptMode = 1));
                //lowScriptTimer = 1;
            }
            else {
                // lowScript is no longer valid... but wait....
                // Nope - all is good again: BUT don't trigger
                // normal mode immediately - wait 10 minutes
                // to see if this good news sticks

                integer timeSpan = llGetUnixTime() - lastLowScriptTime;

                if (timeSpan > 600) {
                    debugSay(2,"DEBUG-MAIN", "Low Script Mode active but environment good - disabling");
                    lastLowScriptTime = 0;
                    llOwnerSay("Restoring Key to normal operation.");

                    lmSendConfig("lowScriptMode",(string)(lowScriptMode = 0));
                    llSetTimerEvent(STD_RATE);
                }
#ifdef DEVELOPER_MODE
                else {
                    debugSay(2,"DEBUG-MAIN", "Low Script Mode active but environment good - not yet time (time elapsed " + (string)timeSpan + "s)");
                }
#endif
            }
        }
        else {
            // We're not in lowScriptMode....should we be?
            // Test...
            //
            if (cdLowScriptTrigger) {
                // We're not in lowScriptMode, but have been triggered...
                // Go into "power saving mode", say so, and mark the time

                lastLowScriptTime = llGetUnixTime();
                llOwnerSay("Time congestion detected: Power-saving mode activated.");

                lmSendConfig("lowScriptMode",(string)(lowScriptMode = 1));
                llSetTimerEvent(LOW_RATE);
            }
            else {
                lmSendConfig("lowScriptMode",(string)(lowScriptMode = 0));
                llSetTimerEvent(STD_RATE);
            }
        }

        //----------------------------------------
        // CARRY TIMER: RUN OR RESET

        // If carried, the carry times out (expires) if the carrier is
        // not in range for the duration
        if (carryExpire > 0) {
            // carryExpire is a fixed Time in the future - so decreasing it makes no sense...
            // making it a UnixTime makes no real sense, but it doesn't hurt and that is
            // standard for these variables
            if (llGetAgentSize(carrierID) == ZERO_VECTOR)       carryExpire = llGetUnixTime() + CARRY_TIMEOUT;
        }

        //----------------------------------------
        // SET WIND RATE

        setWindRate();

        //----------------------------------------
        // TIME SAVED (TIMER INTERVAL)

        lastTimerMark = timerMark;

        //----------------------------------------
        // CHECK COLLAPSE STATE

        // False collapse? Collapsed = 1 while timeLeftOnKey is positive is an invalid condition
        if (collapsed == NO_TIME)
            if (timeLeftOnKey > 0) lmUncollapse();
#ifdef JAMMABLE
        else if (collapsed == JAMMED)
            if (jamExpire <= timerMark) lmUncollapse();
#endif

        //----------------------------------------
        // POSE TIMED OUT?

        // Did the pose expire? If so, unpose Dolly
        if (poseExpire) {
            if (poseExpire <= timerMark) {
                lmMenuReply("Unpose", "", llGetKey());
                lmSendConfig("poseExpire", (string)(poseExpire = 0));
            }
            lmSendConfig("poseExpire", (string)poseExpire);
        }

        //----------------------------------------
        // CARRY TIMED OUT?

        // Has the carry timed out? If so, drop the Dolly
        if (carryExpire) {
            if (carryExpire <= timerMark) {
                lmMenuReply("Uncarry", carrierName, carrierID);
                carryExpire = 0;
            }
            lmSendConfig("carryExpire", (string)carryExpire);
        }

        //----------------------------------------
        // WEARLOCK TIMED OUT?

        // Has the clothing lock - wear lock - run its course? If so, reset lock
        if (wearLockExpire) {
            if (wearLockExpire <= timerMark) {
                // wearLock has expired...
                lmSendConfig("wearLock", (string)(wearLock = 0));
                lmSendConfig("wearLockExpire", (string)(wearLockExpire = 0));
            }
        }

        lmInternalCommand("getTimeUpdates", "", llGetKey());

#ifdef LOCKON
        ifPermissions();
#endif
        //--------------------------------
        // WINDING DOWN.....
        //
        // A specific test for collapsed status is no longer required here
        // as being collapsed is one of several conditions which forces the
        // wind rate to be 0.
        //
        // Others which cause this effect are not being attached to spine
        // and being doll type Builder or Key
        //
        // Note too: if no time measured, then no need to check everything

        if (windingDown && (timeSpan != 0)) {
            timeLeftOnKey -= timeSpan * windRate;

            //debugSay(3,"DEBUG-MAIN","Time left on key at unwinding: " + (string)timeLeftOnKey);
            if (timeLeftOnKey > 0) {

                minsLeft = llRound(timeLeftOnKey / (SEC_TO_MIN * windRate));

                if (doWarnings && !warned) {
                    if (minsLeft == 30 || minsLeft == 15 || minsLeft == 10 || minsLeft ==  5 || minsLeft ==  2) {

                        if (!quiet) llSay(0, dollName + " has " + (string)minsLeft + " minutes left before they run down!");
                        else llOwnerSay("You have " + (string)minsLeft + " minutes left before winding down!");
                        warned = 1; // have warned now: dont repeat same warning
                    }
                }
                else warned = 0;

            }
            else {
                // Dolly is DONE! Go down... and yell for help.
                if (collapsed == NOT_COLLAPSED) {

                    // This message is intentionally excluded from the quiet key setting as it is not good for
                    // dolls to simply go down silently.

                    llSay(0, "Oh dear. The pretty Dolly " + dollName + " has run out of energy. Now if someone were to wind them... (Click on Dolly's key.)");
                    collapse(NO_TIME);
                }
            }
        }

        scaleMem();
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    // For Transforming Key operations
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
            split = llDeleteSubList(split, 0, 0);
            string c = cdGetFirstChar(name);

            if (c == "c") {
                if (name == "carrierID") {
                    carrierID = (key)value;

                    // If we get a carrierID, it means we need to start the carry timer
                    if (carrierID) {
                        // Send the carryExpire out as a relative value, then convert it
                        // internally to a fixed time value
                        lmSendConfig("carryExpire", (string)(carryExpire = llGetUnixTime() + CARRY_TIMEOUT));
                    }
                }
                else if (name == "carrierName")               carrierName = value;
                else if (name == "canAFK")                         canAFK = (integer)value;
                else if (name == "configured")                 configured = (integer)value;
                else if (name == "collapsed")                    collapsed = (integer)value;
            }
            else if (name == "allowRepeatWind")       allowRepeatWind = (integer)value;
            else if (name == "autoAFK")                       autoAFK = (integer)value;
#ifdef ADULT_MODE
            else if (name == "allowStrip")                 allowStrip = (integer)value;
#endif
            //else if (name == "autoTP")                         autoTP = (integer)value;
            else if (c == "d") {
                     if (name == "dollDisplayName")       dollDisplayName = value;
                else if (name == "dialogChannel")           dialogChannel = (integer)value;
                else if (name == "demoMode") {
                    if (demoMode = (integer)value) effectiveLimit = DEMO_LIMIT;
                    else effectiveLimit = keyLimit;
                }
                else if (name == "dollType")                     dollType = value;
#ifdef DEVELOPER_MODE
                else if (name == "debugLevel")                 debugLevel = (integer)value;
#endif
            }
            else if (name == "quiet")                           quiet = (integer)value;
            else if (name == "hardcore")                     hardcore = (integer)value;
            else if (name == "hoverTextOn")               hoverTextOn = (integer)value;
            else if (name == "busyIsAway")                 busyIsAway = (integer)value;
            else if (name == "baseWindRate")             baseWindRate = (float)value;
            else if (name == "keyAnimation")             keyAnimation = value;
            else if (name == "pronounHerDoll")         pronounHerDoll = value;
            else if (name == "pronounSheDoll")         pronounSheDoll = value;
            else if (name == "transformLockExpire")   transformLockExpire = (integer)value;

            else if (name == "windAmount")                 windAmount = (float)value;
            // This keeps the timers up to date - via a GetTimeUpdates internal command
            else if (name == "windMins") {
                //if (script != "Main") llOwnerSay("windMins LinkMessage sent by " + script + " with value " + value);
                windMins = (integer)value;
            }
#ifdef DEVELOPER_MODE
            else if (name == "timeReporting")           timeReporting = (integer)value;
#endif
        }
        else if (code == SET_CONFIG) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);
            split = llDeleteSubList(split, 0, 0);

            if (name == "keyLimit") {
                keyLimit = (float)value;

                // if limit is negative clip it at a default
                if (keyLimit < 0) keyLimit = 240 * SEC_TO_MIN;

                // if limit is less than time left on key, clip time remaining
                if (timeLeftOnKey > keyLimit) timeLeftOnKey = keyLimit;

                // if nto in demo mode set effectiveLimit
                if (!demoMode) effectiveLimit = keyLimit;
                else effectiveLimit = DEMO_LIMIT;

                lmSendConfig("keyLimit", (string)keyLimit);
                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
                //lmSendConfig("effectiveLimit", (string)effectiveLimit);
            }
            else if (name == "lastWinderID") {
                lmSendConfig("lastWinderID", (string)(lastWinderID = (key)value));
            }
            else if (name == "afk") {
                setAfk((integer)value);
            }
            else if (name == "timeLeftOnKey") {
                timeLeftOnKey = (float)value;
                if (timeLeftOnKey > effectiveLimit) timeLeftOnKey = effectiveLimit;

                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
            }
            else if (name == "wearLock") {
                // Internal command: remove?
                lmSendConfig("wearLock", (string)(wearLock = (integer)value));

                if (wearLock) wearLockExpire = llGetUnixTime() + WEAR_LOCK_TIMEOUT;
                else wearLockExpire = 0;

                lmSendConfig("wearLockExpire",(string)(wearLockExpire));
            }
            else if (name == "lowScriptMode") {
                lmSendConfig("lowScriptMode",(string)(lowScriptMode = (integer)value));
                if (lowScriptMode) lastLowScriptTime = llGetUnixTime();
                else lastLowScriptTime = 0;
            }
            else if (name == "collapseTime")     collapseTime = (integer)value;
            else if (name == "poseExpire")         poseExpire = (integer)value;
            else if (name == "carryExpire")       carryExpire = (integer)value;
#ifdef JAMMABLE
            else if (name == "jamExpire")           jamExpire = (integer)value;
#endif
            else if (name == "wearLockExpire") wearLockExpire = (integer)value;
        }
        else if (code == INTERNAL_CMD) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);
            integer isController = cdIsController(id);

            if (cmd == "getTimeUpdates") {

                // The time variables are set this way:
                //
                //   * timeLeftOnKey (seconds) - positive seconds remaining (adjusted elsewhere)
                //   * {wear|jam|pose|carry}Expire (time) - time of expiration
                //   * collapseTime (time) - time of collapse

#ifdef JAMMABLE
                if (cdTimeSet(jamExpire))            lmSendConfig("jamExpire",             (string)jamExpire);
#endif
                if (cdTimeSet(timeLeftOnKey))        lmSendConfig("timeLeftOnKey",         (string)timeLeftOnKey);
                if (cdTimeSet(wearLockExpire))       lmSendConfig("wearLockExpire",        (string)wearLockExpire);
                if (cdTimeSet(transformLockExpire))  lmSendConfig("transformLockExpire",   (string)transformLockExpire);
                if (cdTimeSet(poseExpire))           lmSendConfig("poseExpire",            (string)poseExpire);
                if (cdTimeSet(carryExpire))          lmSendConfig("carryExpire",           (string)carryExpire);
                if (cdTimeSet(collapseTime))         lmSendConfig("collapseTime",          (string)collapseTime);
            }
            else if (cmd == "collapse") {
                if (collapsed) uncollapse();
                else collapse(llList2Integer(split, 0));
            }
            else if (cmd == "windMsg") {
                integer windAmount = llList2Integer(split, 0);
                string name = llList2String(split, 1);
                string mins = (string)llFloor(windAmount / SEC_TO_MIN);
                string percent = formatFloat((float)timeLeftOnKey * 100.0 / (float)effectiveLimit, 1);

                // We're assuming that every winder has a non-null name, and every
                // auto-wind has a null name... is that really true?
                if (name != "") {

                    // We're trying to avoid having name obliterated by RLV viewers
                    // Note this makes no difference to waiting events, just other scripts
                    if (collapsed == 0) llSleep(0.5);

                    llOwnerSay("Your key has been turned by " + name + " giving you " +
                        mins + " more minutes of life (" + percent + "% capacity).");

#ifdef DEVELOPER_MODE
                    llSay(DEBUG_CHANNEL, "Wind: " + mins + " mins (" + percent + "%) by \"" + name + "\"");
#endif
                    lmSendToAgent("You turn " + dollDisplayName + "'s Key, and " + pronounSheDoll + " receives " +
                        mins + " more minutes of life (" + percent + "% capacity).", id);
                }
                else {
                    llOwnerSay("Your key turns automatically, ggiving you an additional " + mins + " minutes of life.");
                }
            }
        }
        else if (code == RLV_RESET) {
            RLVok = (llList2Integer(split, 0) == 1);
            rlvAPIversion = llList2String(split, 1);

            // refresh collapse state... no escape!
            collapse(collapsed);

            if (RLVok) {
                if (!allowDress && !hardcore) llOwnerSay("The public cannot dress you.");
            }
            else {
                llOwnerSay("Without RLV, you cannot be dressed in new outfits.");
            }

            simRating = "";
            simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);
        }
        else if (code == MENU_SELECTION) {
            string choice = llList2String(split, 0);
            string name = llList2String(split, 1);

            if (choice == MAIN) {
                // call actual Menu code
                lmInternalCommand("mainMenu", "|" + name, id);
            }
            else if (choice == "Wind Emg") {
                // Give this a time limit: can only be done once
                // in - say - 6 hours... at least maxwindtime *2 or *3.


                if (winderRechargeTime <= llGetUnixTime()) {
                    // Winder is recharged and usable.
                    windAmount = 0;

                    if (collapsed == NO_TIME) {
                        lmSendToController(dollName + " has activated the emergency winder.");

                        // default is 20% of max, but no more than 60 minutes
                        //
                        // Doing it this way makes the wind amount independent of the amount
                        // of time in a single wind. It is also a form of hard-coding.
                        //
                        windAmount = effectiveLimit * 0.2;
                        if (windAmount > 3600) windAmount = 3600;

                        lmSendConfig("timeLeftOnKey", (string)(timeLeftOnKey = windAmount));
                        lmSendConfig("winderRechargeTime", (string)(winderRechargeTime = (llGetUnixTime() + EMERGENCY_LIMIT_TIME)));
                        lmUncollapse();

                        llOwnerSay("With an electical sound the motor whirrs into life and gives you " + (string)llRound(windAmount / SEC_TO_MIN) + " minutes of life. The recharger requires " + (string)llRound(EMERGENCY_LIMIT_TIME / 3600) + " hours to recharge.");
                    }
#ifdef JAMMABLE
                    else {
                        if (collapsed == JAMMED) { llOwnerSay("The emergency winder motor whirrs, splutters and then falls silent, unable to budge your jammed mechanism."); }
                        else { llOwnerSay("The failsafe trigger fires with a soft click preventing the motor engaging while your mechanism is running."); }
                    }
#endif
                }
                else {
                   float rechargeMins = ((winderRechargeTime - llGetUnixTime()) / SEC_TO_MIN);
                   string s = "Emergency self-winder is not yet recharged. There remains ";

                   //llSay(DEBUG_CHANNEL,"Winder recharge: rechargeMins = " + (string)rechargeMins + " minutes");
                   if (rechargeMins < 60) s += (string)llFloor(rechargeMins) + " minutes ";
                   else s += "over " + (string)llFloor(rechargeMins / 60) + " hours ";

                   llOwnerSay(s + "before it will be ready again.");
                }

            }

            // Winding - pure and simple
            else if (choice == "Wind") {

                // Four steps:
                //   1. Can we wind up at all?
                //   2. Calculate wind time
                //   3. Send out new timeLeftOnKey
                //   4. React to wind (including uncollapse)

#ifdef JAMMABLE
                // Test and reject winding of jammed dollies
                if (collapsed == JAMMED) {
                    cdDialogListen();
                    llDialog(id, "The Dolly cannot be wound while " + pronounHerDoll + " key is being held.", ["Help...", "OK"], dialogChannel);
                    return;
                }
#endif

                // Test and reject repeat winding as appropriate - Controllers and Carriers are not limited
                if (!(cdIsController(id) || cdIsCarrier(id))) {
                    if (!allowRepeatWind && (id == lastWinderID)) {
                        lmSendToAgent("Dolly needs to be wound by someone else before you can wind " + pronounHerDoll + " again.", id);
                        return;
                    }
                }

                // Here, dolly may be collapsed or not...
                //
                // effectiveWindTime allows us to preserve the real wind
                // even when demo mode is active
                if (demoMode) effectiveWindTime = 60;
                else effectiveWindTime = (float)windMins * SEC_TO_MIN;

                if (timeLeftOnKey + effectiveWindTime > effectiveLimit) windAmount = effectiveLimit - timeLeftOnKey;
                else windAmount = effectiveWindTime;

                // The "winding" takes place here. Note that while timeLeftOnKey might
                // be set - collapse is set a short time later - thus, timeLeftOnKey is greater
                // than zero, but collapse is still true.
                lmSendConfig("timeLeftOnKey", (string)(timeLeftOnKey += windAmount));

                if (collapsed == NO_TIME) {

                    // We could call the code directly - but by doing this,
                    // it's an asynchronous event, and not a function that
                    // slows down the user.

                    lmSendConfig("collapsed", (string)(collapsed = 0));
                    lmSendConfig("collapseTime", (string)(collapseTime = 0));
                    lmCollapse(0);
                }

                // Time value of 60s is somewhat arbitrary; it is however less than 1m
                // So it really would not show up in minute based calculations
                // Note that no matter how many seconds there were left, the limit has
                // been reached and set.
                if (windAmount < 60) {

                    // note that this message might go out even if we "wound" Dolly with 30 seconds
                    // more... but in the grand scheme of things, she was fully wound: so say so

                    cdDialogListen();
                    llDialog(id, "Dolly is already fully wound.", [MAIN], dialogChannel);
                }
                else {
                    lmSendConfig("lastWinderID", (string)(lastWinderID = id));
                    lmSendConfig("lastWinderName", name);

                    if (timeLeftOnKey == effectiveLimit) { // Fully wound
                        llOwnerSay("You have been fully wound by " + name + " - " + (string)llRound(effectiveLimit / (SEC_TO_MIN * windRate)) + " minutes remaining.");

                        if (!quiet) llSay(0, dollName + " has been fully wound by " + name + ". Thanks for winding Dolly!");
                        else lmSendToAgent(dollName + " is now fully wound. Thanks for winding Dolly!", id);

                    } else {
                        // by making the wind message an internal command (event), it helps
                        // to make the (client) system stop hiding names before we use it
                        // (based on RLV settings)
                        lmInternalCommand("windMsg", (string)windAmount + "|" + name, id);
                        lmInternalCommand("mainMenu", "|" + name, id);
                    }
                }
            }

            // Note that Max Times are "m" and Wind Times are "min" - this is on purpose to
            // keep the two separate, that is a button click on "45m" sets maximum time to 45 minutes;
            // a button click on "45min" sets the wind time to 45 minutes.

            else if (choice == "Max Time...") {
                // If the Max Times available are changed, be sure to change the next choice also
                cdDialogListen();
                llDialog(id, "You can set the maximum available time here.  Dolly cannot be wound beyond this amount of time.\nDolly currently has " + (string)llFloor(timeLeftOnKey / SEC_TO_MIN) + " mins left of " + (string)llFloor(keyLimit / SEC_TO_MIN) + ". If you lower the maximum, Dolly will lose the extra time entirely.",
                    dialogSort(["45m", "60m", "75m", "90m", "120m", "150m", "180m", "240m", MAIN]), dialogChannel);
            }

            else if ((choice ==  "15min") ||
                     (choice ==  "30min") ||
                     (choice ==  "45min") ||
                     (choice ==  "60min") ||
                     (choice ==  "90min") ||
                     (choice == "120min")) {

                if (windMins * SEC_TO_MIN > keyLimit) lmSendConfig("windMins", (string)(windMins = 30));
                else lmSendConfig("windMins", (string)(windMins = (integer)choice));
                lmSendToAgent("Winding now set to " + (string)windMins + " minutes",id);
                lmMenuReply("Key...","",id);
            }

            else if ((choice ==  "45m") ||
                     (choice ==  "60m") ||
                     (choice ==  "75m") ||
                     (choice ==  "90m") ||
                     (choice == "120m") ||
                     (choice == "150m") ||
                     (choice == "180m") ||
                     (choice == "240m")) {

                keyLimit = (float)choice * SEC_TO_MIN;
                lmSendToAgent("Key limit now set to " + (string)llFloor(keyLimit / SEC_TO_MIN) + " minutes",id);

                // if limit is less than time left on key, clip time remaining
                if (timeLeftOnKey > keyLimit) timeLeftOnKey = keyLimit;

                // if nto in demo mode set effectiveLimit
                if (!demoMode) effectiveLimit = keyLimit;
                else effectiveLimit = DEMO_LIMIT;

                lmSendConfig("keyLimit", (string)keyLimit);
                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
                //lmSendConfig("effectiveLimit", (string)effectiveLimit);
                lmMenuReply("Key...","",id);
            }
            else if (choice == "Wind Time...") {
                list windChoices;

                // Build up the allowed winding times based on the KeyLimit
                if (keyLimit >=  30) windChoices +=  "15min";
                if (keyLimit >=  60) windChoices +=  "30min";
                if (keyLimit >=  90) windChoices +=  "45min";
                if (keyLimit >= 120) windChoices +=  "60min";
                if (keyLimit >= 180) windChoices +=  "90min";
                if (keyLimit >= 240) windChoices += "120min";

                cdDialogListen();
                llDialog(id, "You can set the amount of time in each wind.\nDolly currently winds " + (string)windMins + " mins.",
                    dialogSort(windChoices + [ MAIN ]), dialogChannel);
            }
#ifdef JAMMABLE
            else if (choice == "Hold") {
                collapse(JAMMED);
                lmSendToAgentPlusDoll("Dolly freezes, " + pronounHerDoll + " key kept from turning",id);
            }
#endif
            else if (choice == "Unwind") {
                collapse(NO_TIME);
                lmSendToAgentPlusDoll("Dolly collapses, " + pronounHerDoll + " key unwound",id);
            }
        }
        // Quick shortcut...
        else if (code < 200) {
            if (code == 102) {
                // Single wind for new starting dolly
                lmMenuReply("Wind", "", NULL_KEY);

                configured = 1;

                if (lowScriptMode) llSetTimerEvent(LOW_RATE);
                else if (!cdAttached()) llSetTimerEvent(60.0);
                else llSetTimerEvent(STD_RATE);

                timerStarted = 1;
            }

            else if (code == 104) {
                dollID = llGetOwner();
                dollName = llGetDisplayName(dollID);

                setWindRate();
                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
                llOwnerSay("You have " + (string)llRound(timeLeftOnKey / (SEC_TO_MIN * windRate)) + " minutes of life remaining.");

                clearAnim = 1;
            }

            else if (code == 105) {
                clearAnim = 1;

                if (lowScriptMode) llSetTimerEvent(LOW_RATE);
                else if (!cdAttached()) llSetTimerEvent(60.0);
                else llSetTimerEvent(STD_RATE);
                timerStarted = 1;
            }

            else if (code == MEM_REPORT) {
                float delay = llList2Float(split, 0);
                scaleMem();
                memReport(cdMyScriptName(),delay);
            }
            else if (code == CONFIG_REPORT) {
                cdConfigureReport();
            }
        }
    }

#ifdef LOCKON
    run_time_permissions(integer perm) {
//      if (!cdAttached()) llOwnerSay("@acceptpermission=rem");
        ifPermissions();
    }
#endif
}

//========== MAIN ==========
