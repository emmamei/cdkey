//========================================
// Main.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

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

//========================================
// VARIABLES
//========================================

string msg;
integer minsLeft;
float windRateFactor = 1.0;

// #ifdef DEVELOPER_MODE
// integer thisTimerEvent;
// integer timerInterval;
// #endif
integer timerMark;
integer lastTimerMark;
integer timeSpan;
integer lowScriptModeSpan;
integer isAttached;

key lastWinderID;

integer lowScriptTimer;
integer lastLowScriptTime;
integer warned;
integer wearLockExpire;
integer carryExpire;
integer poseExpire;
// Note that unlike the others, we do not maintain
// transformLockExpire in this script
integer transformLockExpire;

integer effectiveLimit;
integer effectiveWindTime = 30;

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

float setWindRate() {
    float newWindRate;

    debugSay(4,"DEBUG-MAIN","setWindRate() running");

    // if AFK then unwinding slows...
         if (afk)       newWindRate = 0.5; // 50% speed
    else if (collapsed) newWindRate = 0.0; // 0% speed
    else                newWindRate = 1.0; // 100% speed

    if (newWindRate != windRate) {
        lmSendConfig("windRate", (string)(windRate = newWindRate));         // current rate
        lmSendConfig("windingDown", (string)(windingDown = (windRate > 0.0)));   // boolean

	debugSay(2,"DEBUG-MAIN","windRate now set to " + (string)windRate);
	debugSay(6,"DEBUG-MAIN","collapsed is currently " + (string)collapsed);
	debugSay(6,"DEBUG-MAIN","windingDown is currently " + (string)windingDown);

	// llTargetOmega: With a normalized vector (first parameter), the spin rate
	// is in radians per second - 2𝜋 radians equals 1 full rotation.
	//
	// The specified rate is 2𝜋 radians divided by 8 - so as coded one entire key
	// rotation takes 8 seconds. Rotation is about the Z axis, scaled according
	// to the wind rate.
	//
	// The windRate variable allows the changing of the key's rotation speed based
	// on external factors.

        // Only need to do this when windingDown changes
	if (windRate == 0.0) {
	    debugSay(4,"DEBUG-MAIN","setting spin to zero...");
	    llTargetOmega(ZERO_VECTOR, 0.0, 0.0);
	}
	else {
	    debugSay(4,"DEBUG-MAIN","setting spin to " + (string)windRate + "...");
	    llTargetOmega(<0.0, 0.0, 1.0>, windRate * TWO_PI / 8.0, 1.0);
	}
    }

    return windRate;
}

uncollapse() {
    // Revive dolly back from being collapsed
    //string primText = llList2String(llGetPrimitiveParams([ PRIM_TEXT ]), 0);
    //cdSetHovertext("",INFO); // uses primText
    key id = llGetKey();

    lmSendConfig("collapseTime", (string)(collapseTime = 0));
    lmSendConfig("collapsed", (string)(collapsed = 0));
    lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
    lmInternalCommand("getTimeUpdates", "", id);
    lmInternalCommand("setHovertext", "", id);

    setWindRate();
}

collapse(integer newCollapseState) {
    // Dolly is in a new collapse state: collapsed, or not

    // The following code makes "uncollapse()" and "collapse(0)" equivalent...
    // Both uncollapse() and collapse(0) are used; the latter is most useful
    // when the state is unknown (though could be zero); the former is useful
    // when collapse(NO_TIME) or collapse(0) is given directly.

    if (newCollapseState == NOT_COLLAPSED) {
        uncollapse();
        return;
    }

    // If we are already collapsed, then there is nothing to do here
    if (collapsed == NOT_COLLAPSED) {

        collapseTime = llGetUnixTime();
        lmSendConfig("collapseTime", (string)collapseTime);
        lmSendConfig("collapsed", (string)(collapsed = newCollapseState));

        // when dolly collapses, anyone can rescue
        lmSendConfig("lastWinderID", (string)(lastWinderID = NULL_KEY));
        lmSendConfig("timeLeftOnKey", (string)(timeLeftOnKey = 0));

        lmInternalCommand("getTimeUpdates", "", llGetKey());

        // Among other things, this will set the Key's turn rate
        setWindRate();

        //string primText = llList2String(llGetPrimitiveParams([ PRIM_TEXT ]), 0);
        //cdSetHovertext("Disabled Dolly!",CRITICAL); // uses primText
        lmInternalCommand("setHovertext", "", llGetKey());
    }
}

//========================================
// STATES
//========================================

default {
    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        RLVok = UNSET;
        dollID = llGetOwner();
        dollName = lmMyDisplayName(dollID);
        isAttached = cdAttached();
        if (isAttached) llRequestPermissions(dollID, PERMISSION_MASK);

        cdInitializeSeq();

        lmSendConfig("windingDown", (string)(windingDown = cdWindDown()));   // boolean
        //lmSendConfig("baseWindRate", (string)baseWindRate); // base rate: 1.0
        lmSendConfig("windRate", (string)(windRate = RATE_STANDARD));         // current rate
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

        isAttached = cdAttached();
        if (isAttached) llRequestPermissions(dollID, PERMISSION_MASK);

        lmSendConfig("windingDown", (string)(windingDown = cdWindDown()));   // boolean
        //lmSendConfig("baseWindRate", (string)baseWindRate); // base rate: 1.0
        lmSendConfig("windRate", (string)(windRate = RATE_STANDARD));         // current rate
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

        // Deny access to the key when the command was recieved from blacklisted avatar
        if (llListFindList(blacklist, [ (string)id ]) != NOT_FOUND) {
            llOwnerSay("SECURITY WARNING! Attempted Key access from blacklisted user " + agentName);
            return;
        }

        if (RLVok == UNSET) {
            if (dollID != id) {
                cdSayTo(dollName + "'s key clanks and clinks.... it doesn't seem to be ready yet.",id);
                llOwnerSay(agentName + " is fiddling with your Key but the state of RLV is not yet determined.");
                return;
            }
        }

        debugSay(2,"DEBUG-MAIN","Key accessed by " + agentName + " (" + (string)id + ")");
        lmMenuReply(MAIN,agentName,id);
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
        // Timer event: normally runs every 30 or 60 seconds
        //
        // This is the major timer in the Dolly; a second timer takes care of
        // other things and is in Transform; the collapsed animation relies on a timer in Avatar.

        //----------------------------------------
        // TIMER INTERVAL
        timerMark = llGetUnixTime();
        timeSpan = timerMark - lastTimerMark;

        // sanity checking of timeSpan
        //
        // If we relog, the lastTimerMark will be LONG ago....  leading to a
        // HUGE timeSpan... so stomp on it and start with a fresh timeSpan
        //
        // Same thing happens on startup with lastTimerMark = 0

        if (timeSpan > 120) {
            // Check sanity of timeSpan
            timeSpan = 0;
            lastTimerMark = timerMark;
        }

#ifdef DEVELOPER_MODE
        thisTimerEvent = llGetTime();

        if (lastTimerEvent) {
            timerInterval = thisTimerEvent - lastTimerEvent;
            if (timeReporting)
                debugSay(5,"DEBUG-MAIN","Main Timer fired, interval " + formatFloat(timerInterval,2) + "s.");
        }
        lastTimerEvent = thisTimerEvent;
#endif

        //----------------------------------------
        // LOW SCRIPT MODE

        // Note that this is NOT the only place where lowScriptMode
        // is set. lowScriptMode is set via Start.lsl at startup (to 0);
        // and is set by Avatar.lsl after TP or Region change and on Attach.
        if (lowScriptMode) {

            if (cdLowScriptTrigger) {
                // lowScriptMode continues...
                debugSay(2,"DEBUG-MAIN", "Low Script Mode active and bumped");
                lastLowScriptTime = llGetUnixTime();
                //lmSendConfig("lowScriptMode",(string)(lowScriptMode = 1));
                //lowScriptTimer = 1;
            }
            else {
                lowScriptModeSpan = llGetUnixTime() - lastLowScriptTime;

                if (lowScriptModeSpan > 600) {
                    debugSay(2,"DEBUG-MAIN", "Low Script Mode active but environment good - disabling");
                    lastLowScriptTime = 0;
                    llOwnerSay("Restoring Key to normal operation.");

                    lmSendConfig("lowScriptMode",(string)(lowScriptMode = 0));
                    llSetTimerEvent(STD_RATE);
                }
#ifdef DEVELOPER_MODE
                else {
                    debugSay(2,"DEBUG-MAIN", "Low Script Mode active but environment good - not yet time (time elapsed " + (string)lowScriptModeSpan + "s)");
                }
#endif
            }
        }
        else {
            if (cdLowScriptTrigger) {
                // We're not in lowScriptMode, but have been triggered...
                // Go into "power saving mode", say so, and mark the time

                lastLowScriptTime = llGetUnixTime();
                llOwnerSay("Time congestion detected: Power-saving mode activated.");

                lmSendConfig("lowScriptMode",(string)(lowScriptMode = 1));
                llSetTimerEvent(LOW_RATE);
            }
            else {
                //lmSendConfig("lowScriptMode",(string)(lowScriptMode = 0));
                llSetTimerEvent(STD_RATE);
            }
        }

        //----------------------------------------
        // TIME SAVED (TIMER INTERVAL)

        lastTimerMark = timerMark;

        //----------------------------------------
        // CHECK COLLAPSE STATE

        // False collapse? Collapsed = 1 while timeLeftOnKey is positive is an invalid condition
        if (collapsed == NO_TIME)
            if (timeLeftOnKey > 0) lmUncollapse();

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
        // CARRY EXPIRATION

        if (carryExpire) {
            // carry has an expiration in play
            if (carryExpire <= timerMark) {
                // carry has timed out: drop dolly
                lmMenuReply("Uncarry", carrierName, carrierID);
                carryExpire = 0;
            }
            lmSendConfig("carryExpire", (string)carryExpire);
        }
        else {
            if (carrierID) {
                // Dolly is carried and no carry expire in place
                if (llGetAgentSize(carrierID) == ZERO_VECTOR) {
                    // No carrier present: start carry timeout
                    carryExpire = llGetUnixTime() + CARRY_TIMEOUT;
                    lmSendConfig("carryExpire", (string)carryExpire);
                }
            }
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

        if (windingDown) lmInternalCommand("getTimeUpdates", "", llGetKey());

#ifdef LOCKON
        ifPermissions();
#endif
        //--------------------------------
        // WINDING DOWN.....
        //
        // A specific test for collapsed status is no longer required here as
        // being collapsed is one of several conditions which forces the wind
        // rate to be 0.

        if (windingDown) {
            if (timeSpan != 0) {
                // Key ticks down just a little further...
                timeLeftOnKey -= (integer)(timeSpan * windRate);

                // Now that we've ticked down a few - check for warnings, and check for collapse
                if (timeLeftOnKey > 0) {

                    if (doWarnings && !warned) {
                        minsLeft = llRound(timeLeftOnKey / (SECS_PER_MIN * windRate));

                        if (minsLeft == 15 || minsLeft == 10 || minsLeft ==  5) {

                            llSay(0, dollName + " has " + (string)minsLeft + " minutes left before they run down!");
                            //if (!quiet) llSay(0, dollName + " has " + (string)minsLeft + " minutes left before they run down!");
                            //else llOwnerSay("You have " + (string)minsLeft + " minutes left before winding down!");
                            warned = 1; // have warned now: dont repeat same warning
                        }
                    }
                    else warned = 0;

                }
                else {
                    // Dolly is DONE! Go down... and yell for help.
                    if (collapsed == NOT_COLLAPSED) {

                        // This message is intentionally excluded from the quiet key setting as it is not good for dolls to simply go down silently.

                        llSay(0, "Oh dear. The pretty Dolly " + dollName + " has run out of energy. Now if someone were to wind them... (Click on Dolly's key.)");
                        collapse(NO_TIME); // currently equivalent to uncollapse()
                    }
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

                    if (carrierID) lmSendConfig("carryExpire", (string)(carryExpire = llGetUnixTime() + CARRY_TIMEOUT));
                }
                else if (name == "carrierName")               carrierName = value;
                else if (name == "canAFK")                         canAFK = (integer)value;
                else if (name == "configured")                 configured = (integer)value;
                else if (name == "collapsed")                    collapsed = (integer)value;
            }
            else if (name == "allowRepeatWind")       allowRepeatWind = (integer)value;
            else if (name == "allowDress")                 allowDress = (integer)value;
            else if (name == "autoAfk")                       autoAfk = (integer)value;
#ifdef ADULT_MODE
            else if (name == "allowStrip")                 allowStrip = (integer)value;
#endif
            else if (name == "blacklist") {
                if (split == [""]) blacklist = [];
                else blacklist = split;
            }
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
            //else if (name == "quiet")                           quiet = (integer)value;
            else if (name == "hardcore")                     hardcore = (integer)value;
            else if (name == "hovertextOn")               hovertextOn = (integer)value;
            else if (name == "busyIsAway")                 busyIsAway = (integer)value;
            //else if (name == "baseWindRate")             baseWindRate = (float)value;
            else if (name == "keyAnimation")             keyAnimation = value;
            else if (name == "pronounHerDoll")         pronounHerDoll = value;
            else if (name == "pronounSheDoll")         pronounSheDoll = value;
            else if (name == "transformLockExpire")   transformLockExpire = (integer)value;

            else if (name == "windAmount")                 windAmount = (integer)value;
            else if (name == "windNormal")                 windNormal = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "timeReporting")           timeReporting = (integer)value;
#endif
        }
        else if (code == SET_CONFIG) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);
            split = llDeleteSubList(split, 0, 0);

            if (name == "keyLimit") {
                keyLimit = (integer)value;

                // if limit is negative clip it at a default
                if (keyLimit < 0) keyLimit = 10800;

                // if limit is less than time left on key, clip time remaining
                if (timeLeftOnKey > keyLimit) timeLeftOnKey = keyLimit;

                // set effectiveLimit appropriately
                if (!demoMode) effectiveLimit = keyLimit;
                else effectiveLimit = DEMO_LIMIT;

                lmSendConfig("keyLimit", (string)keyLimit);
                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
                //lmSendConfig("effectiveLimit", (string)effectiveLimit);
            }
            else if (name == "lastWinderID") {
                lmSendConfig("lastWinderID", (string)(lastWinderID = (key)value));
            }
            else if (name == "autoAfk") {
                lmSendConfig("autoAfk", (string)(autoAfk = (integer)value));
                if (autoAfk) lmSendConfig("afk", (string)(afk = TRUE));

                lmInternalCommand("setHovertext", "", llGetKey());
                setWindRate();
            }
            else if (name == "afk") {
                lmSendConfig("afk", (string)(afk = (integer)value));
                if (!afk) lmSendConfig("autoAfk", (string)(autoAfk = 0));

                lmInternalCommand("setHovertext", "", llGetKey());
                setWindRate();
            }
            else if (name == "timeLeftOnKey") {
                timeLeftOnKey = (integer)value;
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
            // We do not trigger this: this code only gets triggered from outside
            // using SET_CONFIG (code 301).
            else if (name == "lowScriptMode") {

                // Send our setting out to everyone else
                lmSendConfig("lowScriptMode",(string)(lowScriptMode = (integer)value));

                if (lowScriptMode) lastLowScriptTime = llGetUnixTime();
                else lastLowScriptTime = 0;
            }

            else if (name == "poseExpire")         poseExpire = (integer)value;
            else if (name == "carryExpire")       carryExpire = (integer)value;
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

                if (cdTimeSet(timeLeftOnKey))        lmSendConfig("timeLeftOnKey",         (string)timeLeftOnKey);
                if (cdTimeSet(wearLockExpire))       lmSendConfig("wearLockExpire",        (string)wearLockExpire);
                if (cdTimeSet(transformLockExpire))  lmSendConfig("transformLockExpire",   (string)transformLockExpire);
                if (cdTimeSet(poseExpire))           lmSendConfig("poseExpire",            (string)poseExpire);
                if (cdTimeSet(carryExpire))          lmSendConfig("carryExpire",           (string)carryExpire);
                if (cdTimeSet(collapseTime))         lmSendConfig("collapseTime",          (string)collapseTime);

                //lmSendConfig("windingDown",(string)windingDown);
            }
            else if (cmd == "setWindRate") {
                setWindRate();
            }
            else if (cmd == "collapse") {
                if (collapsed) uncollapse(); // equivalent to collapse(NO_TIME)
                else collapse(llList2Integer(split, 0));
            }
            else if (cmd == "windMsg") {
                // this overlaps a global windAmount... bad!
                integer windAmount = llList2Integer(split, 0);
                string name = llList2String(split, 1);
                string mins = (string)llFloor(windAmount / SECS_PER_MIN);
                string percent = formatFloat((float)timeLeftOnKey * 100.0 / (float)effectiveLimit, 1);

                // We're assuming that every winder has a non-null name, and every
                // auto-wind has a null name... is that really true?
                if (name != "") {

                    // We're trying to avoid having name obliterated by RLV viewers
                    // Note this makes no difference to waiting events, just other scripts
                    if (collapsed == 0) llSleep(0.5);

                    if (dollID == id) {
                        llOwnerSay("You managed to turn your key giving you " +
                            mins + " more minutes of life (" + percent + "% capacity).");
                    }
                    else {
                        if (hardcore) llOwnerSay("Your key has been cranked by " + name + ".");
                        else llOwnerSay("Your key has been turned by " + name + " giving you " +
                            mins + " more minutes of life (" + percent + "% capacity).");

                        cdSayTo("You turn " + dollDisplayName + "'s Key, and " + pronounSheDoll + " receives " +
                            mins + " more minutes of life (" + percent + "% capacity).", id);
                    }
                }
                else {
                    if (hardcore) llOwnerSay("Your key turns automatically, giving you additional minutes of life.");
                    else llOwnerSay("Your key turns automatically, giving you an additional " + mins + " minutes of life.");
                }
            }
        }
        else if (code == RLV_RESET) {
            RLVok = llList2Integer(split, 0);

            // refresh collapse state... no escape!
            collapse(collapsed);

            if (RLVok == TRUE) {
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

                        // default is 20% of max, but no more than 10 minutes
                        //
                        // Doing it this way makes the wind amount independent of the amount
                        // of time in a single wind. It is also a form of hard-coding.
                        //
                        windAmount = (integer)(effectiveLimit * 0.2);
                        if (hardcore) { if (windAmount > 120) windAmount = 120; }
                        else { if (windAmount > 600) windAmount = 600; }

                        lmSendConfig("timeLeftOnKey", (string)(timeLeftOnKey = windAmount));
                        lmSendConfig("winderRechargeTime", (string)(winderRechargeTime = (llGetUnixTime() + EMERGENCY_LIMIT_TIME)));
                        lmUncollapse();

                        string s = "With an electical sound the motor whirrs into life, ";
                        if (hardcore) llOwnerSay("and you can feel your joints reanimating as time is added.");
                        else llOwnerSay("and gives you " + (string)llRound(windAmount / SECS_PER_MIN) + " minutes of life. The emergency winder requires " + (string)llRound(EMERGENCY_LIMIT_TIME / 3600) + " hours to recharge.");
                    }
                }
                else {
                    integer rechargeMins = ((winderRechargeTime - llGetUnixTime()) / SECS_PER_MIN);
                    string s = "Emergency self-winder is not yet recharged.";

                    if (!hardcore) {
                        s += "  There remains ";

                        if (rechargeMins < 60) s += (string)rechargeMins + " minutes ";
                        else s += "over " + (string)(rechargeMins / 60) + " hours ";

                        s += "before it will be ready again.";
                    }
                    llOwnerSay(s);
                }
            }

            // Winding - pure and simple
            else if (choice == "Wind") {

                // Four steps:
                //   1. Can we wind up at all?
                //   2. Calculate wind time
                //   3. Send out new timeLeftOnKey
                //   4. React to wind (including uncollapse)

#ifdef SINGLE_SELF_WIND
                // Test and reject repeat windings from Dolly - no matter who Dolly is or what the settings are
                if (allowSelfWind) {
                    if (id == dollID) {
                        if (id == lastWinderID) {
                            llOwnerSay("You hae wound yourself once already; you must be wound by someone else before being able to wind again.");
                            return;
                        }
                    }
                }
#endif
                // Test and reject repeat winding as appropriate - Controllers and Carriers are not limited
                // (odd sequence helps with short-circuiting and speed)
                if (!allowRepeatWind) {
                    if (!cdIsController(id)) {
                        if (!cdIsCarrier(id)) {
                            if (id == lastWinderID) {
                                cdSayTo("Dolly needs to be wound by someone else before you can wind " + pronounHerDoll + " again.", id);
                                return;
                            }
                        }
                    }
                }

                // Here, dolly may be collapsed or not...
                //
                // effectiveWindTime allows us to preserve the real wind
                // even when demo mode is active
                if (demoMode) effectiveWindTime = 60;
                else effectiveWindTime = windNormal;

                // set the actual wind amount - but don't overwind
                if (timeLeftOnKey + effectiveWindTime > effectiveLimit) windAmount = effectiveLimit - timeLeftOnKey;
                else windAmount = effectiveWindTime;

                debugSay(3,"DEBUG-MAIN", "Set windAmount = " + (string)windAmount);

                // The "winding" takes place here. Note that while timeLeftOnKey might
                // be set - collapse is set a short time later - thus, timeLeftOnKey is greater
                // than zero, but collapse is still true.
                lmSendConfig("timeLeftOnKey", (string)(timeLeftOnKey += windAmount));

                if (collapsed == NO_TIME) {

                    // Just gave Dolly time: so now, uncollapse Dolly

                    // We could call the code directly - but by doing this,
                    // it's an asynchronous event, and not a function that
                    // slows down the user.

                    lmSendConfig("collapsed", (string)(collapsed = 0));
                    lmSendConfig("collapseTime", (string)(collapseTime = 0));
                    lmCollapse(0);
                }

                // Time value of 60s is somewhat arbitrary; it is however less than 1m
                // So it really would not show up in minute based calculations
                if (windAmount < 60) {

                    // note that this message might go out even if we "wound" Dolly with 30 seconds
                    // more... but in the grand scheme of things, she was fully wound: so say so
                    cdDialogListen();
                    llDialog(id, "Dolly is already fully wound.", [MAIN], dialogChannel);
                }
                else {
                    lmSendConfig("lastWinderID", (string)(lastWinderID = id));

                    if (timeLeftOnKey == effectiveLimit) { // Fully wound
                        if (id != dollID) {
                            if (hardcore) llOwnerSay("You have been fully wound by " + name + ".");
                            else llOwnerSay("You have been fully wound by " + name + " - " + (string)llRound(effectiveLimit / (SECS_PER_MIN * windRate)) + " minutes remaining.");

                            llSay(0, dollName + " has been fully wound by " + name + ". Thanks for winding Dolly!");
                            //cdSayTo(dollName + " is now fully wound. Thanks for winding Dolly!", id);
                        }
                        else {
                            llOwnerSay("You have fully wound yourself. Good going!");
                        }
                    } else {
                        lmInternalCommand("windMsg", (string)windAmount + "|" + name, id);
                        lmInternalCommand("mainMenu", "|" + name, id);
                    }
                }
            }

            // Note that Max Times are "m" and Wind Times are "min" - this is on purpose to
            // keep the two separate
            else if (choice == "Max Time...") {
                list maxList = [ "45m", "60m", "75m", "90m", "120m" ];
                if (!hardcore) maxList += [ "150m", "180m", "240m" ];
                maxList += MAIN;

                // If the Max Times available are changed, be sure to change the next choice also
                cdDialogListen();
                llDialog(id, "You can set the maximum available time here.  Dolly cannot be wound beyond this amount of time.\nDolly currently has " + (string)llFloor(timeLeftOnKey / SECS_PER_MIN) + " mins left of " + (string)llFloor(keyLimit / SECS_PER_MIN) + ". If you lower the maximum, Dolly will lose any extra time entirely.",
                    dialogSort(maxList), dialogChannel);
            }

            else if ((choice ==  "15min") ||
                     (choice ==  "30min") ||
                     (choice ==  "45min") ||
                     (choice ==  "60min") ||
                     (choice ==  "90min") ||
                     (choice == "120min")) {

                windNormal = (integer)choice * (integer)SECS_PER_MIN;

                if (windNormal > keyLimit) windNormal = llFloor(keyLimit / 6);
                lmSendConfig("windNormal", (string)windNormal);

                cdSayTo("Winding now set to " + (string)(windNormal / (integer)SECS_PER_MIN) + " minutes",id);
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

                keyLimit = (integer)choice * SECS_PER_MIN;
                cdSayTo("Key limit now set to " + (string)llFloor(keyLimit / SECS_PER_MIN) + " minutes",id);

                // if limit is less than time left on key, clip time remaining
                if (timeLeftOnKey > keyLimit) timeLeftOnKey = keyLimit;

                // if not in demo mode set effectiveLimit
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
                llDialog(id, "You can set the amount of time in each wind.\nDolly currently winds " + (string)(windNormal / (integer)SECS_PER_MIN) + " mins.",
                    dialogSort(windChoices + [ MAIN ]), dialogChannel);
            }
            else if (choice == "Unwind") {
                collapse(NO_TIME); // currently equivalent to uncollapse()
                cdSayTo("Dolly collapses, " + pronounHerDoll + " key unwound",id);
            }
        }
        // Quick shortcut...
        else if (code < 200) {
            if (code == 102) {
                configured = 1;

                     if (lowScriptMode) llSetTimerEvent(LOW_RATE);
                else if (!isAttached)   llSetTimerEvent(60.0);
                else                    llSetTimerEvent(STD_RATE);

                timerStarted = 1;
            }

            else if (code == 104) {
                dollID = llGetOwner();
                dollName = lmMyDisplayName(dollID);

                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
                setWindRate();
            }

            else if (code == 105) {

                     if (lowScriptMode) llSetTimerEvent(LOW_RATE);
                else if (!isAttached)   llSetTimerEvent(60.0);
                else                    llSetTimerEvent(STD_RATE);

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
        ifPermissions();
    }
#endif
}

//========== MAIN ==========
