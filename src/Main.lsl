//========================================
// Main.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl

#include "include/GlobalDefines.lsl"

#define cdNullList(a) (llGetListLength(a)==0)
#define cdListMin(a) llListStatistics(LIST_STAT_MIN,a)
#define cdTimeSet(a) (a!=0)
#define cdResetKey() llResetOtherScript("Start")
#define cdLockMeisterCmd(a) llWhisper(LOCKMEISTER_CHANNEL,(string)dollID+a)
#define cdAOoff() llWhisper(LOCKMEISTER_CHANNEL,(string)dollID+"bootoff")
#define cdAOon()  llWhisper(LOCKMEISTER_CHANNEL,(string)dollID+"booton")
#define requestPermToCollapse() llRequestPermissions(dollID, PERMISSION_MASK)
#define ALL_CONTROLS (CONTROL_FWD|CONTROL_BACK|CONTROL_LEFT|CONTROL_RIGHT|CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT|CONTROL_UP|CONTROL_DOWN|CONTROL_LBUTTON|CONTROL_ML_LBUTTON)
#define disableMovementControl() llTakeControls(ALL_CONTROLS, TRUE, FALSE)
#define enableMovementControl() llTakeControls(ALL_CONTROLS, FALSE, TRUE)
#define keyDetached(id) (id == NULL_KEY)
#define rlvLockKey()    lmRunRLV("detach=n")
#define rlvUnlockKey()  lmRunRLV("detach=y")

#define UNSET -1

#define KEYLIMIT_MAX 14400 // 4 hours
#define KEYLIMIT_MIN 900 // 15 minutes

// Note that some doll types are special....
//    - Regular: used for standard Dolls, including non-transformable
//    - Slut: can be stripped (like Pleasure Dolls)
//    - Display: poses dont time out
//    - Domme: messages shift focus slightly

//========================================
// VARIABLES
//========================================

string msg;
float windRateFactor = 1.0;

integer currentTime;
float timeSpan;
integer permMask;

key lastWinderID = NULL_KEY;

#define LOWSCRIPT_TIMEOUT 600
integer lowScriptTimer;
integer lowScriptModeSpan;
integer lastLowScriptTime;
integer lowScriptExpire;

integer wearLockExpire;
integer carryExpire;
integer poseExpire;
integer transformLockExpire;

key simRatingQuery;
integer keyLocked = FALSE;

//========================================
// FUNCTIONS
//========================================
doWinding(string winderName, key winderID) {
    // Four steps:
    //   1. Can we wind up at all?
    //   2. Calculate wind time
    //   3. Send out new timeLeftOnKey
    //   4. React to wind (including unCollapse)

    integer windAmount;

#ifdef SINGLE_SELF_WIND
    // Test and reject repeat windings from Dolly - no matter who Dolly is or what the settings are
    if (allowSelfWind) { // is self-wind allowed?
        if (winderID == dollID) { // is winder Dolly?
            if (winderID == lastWinderID) { // is last winder also Dolly?
                llOwnerSay("You have wound yourself once already; you must be wound by someone else before being able to wind again.");
                            return;
            }
        }
    }
#endif
    // Test and reject repeat winding as appropriate - Controllers and Carriers are not limited
    // (odd sequence helps with short-circuiting and speed)
    if (!allowRepeatWind) {
        if (!cdIsController(winderID)) {
            if (!cdIsCarrier(winderID)) {
                if (winderID == lastWinderID) {
                    cdSayTo("Dolly needs to be wound by someone else before you can wind " + pronounHerDoll + " again.", winderID);
                    return;
                }
            }
        }
    }

    // Here, dolly may be collapsed or not...

    // Rather than clip afterwards, we clip the windAmount beforehand:
    // this lets us correctly report how many minutes were wound
    if (timeLeftOnKey + windNormal > keyLimit) windAmount = keyLimit - timeLeftOnKey;
    else windAmount = windNormal;

    // At this point, the winding amount could be minimal - that is,
    // the Key is already fully wound. However - at this point who really cares?

    // The "winding" takes place here. Note that while timeLeftOnKey might
    // be set - collapse is set a short time later - thus, timeLeftOnKey is greater
    // than zero, but collapse is still true.
    lmSendConfig("timeLeftOnKey", (string)(timeLeftOnKey += windAmount));
    if (lastWinderID != winderID) lmSendConfig("lastWinderID", (string)(lastWinderID = winderID));

    lmInternalCommand("windMsg", (string)windAmount + "|" + winderName, winderID);

    if (collapsed) unCollapse();
}

#define isFlying  (agentInfo & AGENT_FLYING)
#define isSitting (agentInfo & AGENT_SITTING)

float setWindRate() {
    float newWindRate;
    integer agentInfo;

    agentInfo = llGetAgentInfo(llGetOwner());

    // Adjust winding down rate. Note that this affects the spin rate,
    // and that the AFK state is based on the CURRENT rate... so if Dolly
    // is flying, then the key will be running faster in AFK than it
    // would be if Dolly was standing, and when Sitting AFK mode would
    // be half that rate as well...
    //
         if (isAFK)     newWindRate = 0.5 * windRate; // 50% speed of CURRENT rate
    else if (collapsed) newWindRate = 0.0;            // 0% speed
    else if (isFlying)  newWindRate = 1.5;            // 150% speed
    else if (isSitting) newWindRate = 0.7;            // 70% speed
    else                newWindRate = 1.0;            // 100% speed

    if (newWindRate != windRate) {
        lmSendConfig("windRate", (string)(windRate = newWindRate));         // current rate

        debugSay(2,"DEBUG-MAIN","windRate changed to " + (string)windRate);
        //debugSay(6,"DEBUG-MAIN","collapsed is currently " + (string)collapsed);

        // llTargetOmega: With a normalized vector (first parameter), the spin rate
        // is in radians per second - 2𝜋 radians equals 1 full rotation.
        //
        // The specified rate is 2𝜋 radians divided by 8 - so as coded one entire key
        // rotation takes 8 seconds. Rotation is about the Z axis, scaled according
        // to the wind rate.
        //
        // The windRate variable allows the changing of the key's rotation speed based
        // on external factors.

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

doCollapse() {
    list oldAnimList;
    integer i;

    // Note that this command zaps the amount of time remaining:
    // if dolly is collapsed, she is by definition out of time...
    //
    if (collapseTime == 0) collapseTime = llGetUnixTime();
    lmSendConfig("collapseTime", (string)collapseTime);

    lmSendConfig("collapsed", (string)(collapsed = TRUE));
    lmSendConfig("timeLeftOnKey", (string)(timeLeftOnKey = 0));

#define notPosed (poseAnimation == ANIMATION_NONE)

    if (notPosed) {
        lmSendConfig("poseAnimation", ANIMATION_NONE);
        lmSendConfig("poserID", NULL_KEY);
        lmSetConfig("poseExpire", "0");
    }

    if (cdCarried())
        lmInternalCommand("stopFollow", (string)carrierID, keyID);

    if (RLVok == TRUE) {
        rlvLockKey();
        lmRunRLVcmd(defaultCollapseRLVcmd, "");
    }

    oldAnimList = llGetAnimationList(dollID);
    i = llGetListLength(oldAnimList);

    // Stop all animations
    while (i--)
        llStopAnimation((key)oldAnimList[i]);

    // This will trigger animation
    llStartAnimation(ANIMATION_COLLAPSED);
    disableMovementControl();

    // when dolly collapses, anyone can rescue
    lmSendConfig("lastWinderID", (string)(lastWinderID = NULL_KEY));

    // Among other things, this will set the Key's turn rate
    windRate = setWindRate();

    lmInternalCommand("setHovertext", "", keyID);
    cdAOoff();
}

unCollapse() {
    list oldAnimList;
    integer i;

    // Revive dolly back from being collapsed

    lmSendConfig("collapseTime", (string)(collapseTime = 0));
    lmSendConfig("collapsed", (string)(collapsed = FALSE));
    lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);

    lmInternalCommand("setHovertext", "", keyID);

    if (RLVok == TRUE) {
        lmRunRLVcmd("clearRLVcmd",""); // clear all collapse-related restrictions from defaultCollapseRLVcmd
        if (keyLocked == FALSE) rlvUnlockKey();
        else rlvLockKey();
    }

    oldAnimList = llGetAnimationList(dollID);
    i = llGetListLength(oldAnimList);

    // Stop all animations
    while (i--)
        llStopAnimation((key)oldAnimList[i]);

    windRate = setWindRate();
    cdAOon();

    // This will trigger animation
    llStartAnimation("Stand");
    enableMovementControl();

    if (cdCarried())
        lmInternalCommand("startFollow", (string)carrierID, keyID);
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
        keyID = llGetKey();
        dollName = dollyName();
        myName = llGetScriptName();

        cdInitializeSeq();

        lmSendConfig("windRate", (string)(windRate = 1.0)); // base rate: 100%
        lmInternalCommand("setHovertext", "", keyID);
        if (!(keyDetached(dollID))) requestPermToCollapse();
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        RLVok = UNSET;
        timerStarted = TRUE;
        configured = TRUE;

        lmInternalCommand("setHovertext", "", keyID);
        if (!(keyDetached(dollID))) requestPermToCollapse();

        llResetTime();
        llSetTimerEvent(30.0);

        lmSendConfig("windRate", (string)(windRate = RATE_STANDARD));         // current rate
    }


    //----------------------------------------
    // ATTACH
    //----------------------------------------
    // During attach, we perform:
    //
    //     * request permissions to allow collapse to function
    //
    attach(key id) {
        if (!(keyDetached(id))) requestPermToCollapse();
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key query_id, string data) {
        if (query_id == simRatingQuery) {
            simRating = data;
            lmRating(simRating);

#ifdef ADULT_MODE
            if (simRating == "PG") {
                if (allowStrip || (dollType == "Slut"))
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
        key toucherID = llDetectedKey(0);
        string toucherName = llGetDisplayName(toucherID);

        // Deny access to the key when the command was recieved from blacklisted avatar
        if (llListFindList(blacklistList, [ (string)toucherID ]) != NOT_FOUND) {
            llOwnerSay("SECURITY WARNING! Attempted Key access from blacklisted user " + toucherName);
            return;
        }

        if (RLVok == UNSET) {
            if (dollID != toucherID) {
                cdSayTo(dollName + "'s key clanks and clinks.... it doesn't seem to be ready yet.",toucherID);
                llOwnerSay(toucherName + " is fiddling with your Key but the state of RLV is not yet determined.");
                return;
            }
        }

        debugSay(2,"DEBUG-MAIN","Key accessed by " + toucherName + " (" + (string)toucherID + ")");
        lmMenuReply(MAIN,toucherName,toucherID);
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
        currentTime = llGetUnixTime();

#define isTimePast(a) (a <= currentTime)
#define bumpExpireTime(a) llGetUnixTime() + (a)

#ifdef DEVELOPER_MODE
        if (debugLevel > 0) {
            timeSpan = llGetTime();
            if (timeSpan) {
                debugSay(5,"DEBUG-MAIN","Main Timer fired, interval " + formatFloat2(timeSpan) + "s.");
            }
        }
#endif

        //----------------------------------------
        // LOW SCRIPT MODE

        if (lowScriptMode) {

            // cdLowScriptTrigger = (llGetRegionFPS() < LOW_FPS || llGetRegionTimeDilation() < LOW_DILATION)
            if (cdLowScriptTrigger) {

                // lowScriptMode continues...
                debugSay(2,"DEBUG-MAIN", "Low Script Mode active and bumped");
                lowScriptExpire = bumpExpireTime(LOWSCRIPT_TIMEOUT);
            }
            else {

                // if environment has past test long enough - then go out of powersave mode
                if (isTimePast(lowScriptExpire)) {
                    debugSay(2,"DEBUG-MAIN", "Low Script Mode active but environment good - disabling");
                    llOwnerSay("You hear the key's inner workings gear up to full power.");

                    lmSendConfig("lowScriptMode",(string)(lowScriptMode = FALSE));
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

                lowScriptExpire = bumpExpireTime(LOWSCRIPT_TIMEOUT);
                llOwnerSay("You hear your Key entering powersave mode, in order to be kind to the sim.");

                lmSendConfig("lowScriptMode",(string)(lowScriptMode = TRUE));
                llSetTimerEvent(LOW_RATE);
            }
            else {
                llSetTimerEvent(STD_RATE);
            }
        }

        //----------------------------------------
        // CHECK COLLAPSE STATE

        // False collapse? Collapsed = 1 while timeLeftOnKey is positive is an invalid condition
        if (collapsed) if (timeLeftOnKey > 0) unCollapse();

        //----------------------------------------
        // POSE TIMED OUT?

        // Did the pose expire? If so, unpose Dolly
        if (poseExpire) {
            if (isTimePast(poseExpire)) {
                lmMenuReply("Unpose", "", keyID);
                lmSendConfig("poseExpire", (string)(poseExpire = 0));
            }
            lmSendConfig("poseExpire", (string)poseExpire);
        }

        //----------------------------------------
        // CARRY EXPIRATION

        if (carryExpire) {
            debugSay(6,"DEBUG-MAIN","checking carrier presence");

            // check to see if carrier seen in the last few minutes
            if (isTimePast(carryExpire)) {

                // carrier vanished: drop dolly
                cdSayTo("You have not been seen for " + (string)(CARRY_TIMEOUT/60) + " minutes; dropping Dolly.",carrierID);
                llOwnerSay("Your carrier has not been seen for " + (string)(CARRY_TIMEOUT/60) + " minutes.");

                lmMenuReply("Uncarry", carrierName, carrierID);
                //carryExpire = 0;
            }
            else {
                // carry has not expired: check for carrier
                if (llGetAgentSize(carrierID) != ZERO_VECTOR) {

                    debugSay(6,"DEBUG-MAIN","carrier seen");

                    // No carrier present: bump carry timeout
                    carryExpire = bumpExpireTime(CARRY_TIMEOUT);
                    lmSendConfig("carryExpire", (string)carryExpire);
                }
            }
        }

        //----------------------------------------
        // WEARLOCK TIMED OUT?

        // Has the clothing lock - wear lock - run its course? If so, reset lock
        if (wearLockExpire) {
            if (isTimePast(wearLockExpire)) {
                // wearLock has expired...
                lmSetConfig("wearLock", (string)(wearLock = 0));
                //lmSendConfig("wearLockExpire", (string)(wearLockExpire = 0));
            }
        }

        //--------------------------------
        // AFK AUTO ENABLE
        //
        // Check for agent away or agent busy (afk)
        integer dollAway = ((llGetAgentInfo(dollID) & (AGENT_AWAY | (AGENT_BUSY * busyIsAway))) != 0);

        if (dollAway != isAFK) {
            isAFK = dollAway;
            lmSetConfig("isAFK", (string)isAFK);

            if (isAFK) llOwnerSay("Dolly has gone afk; Key subsystems slowing...");
            else       llOwnerSay("You hear the Key whir back to full power");

            lmInternalCommand("setWindRate","",NULL_KEY);
            lmInternalCommand("setHovertext", "", keyID);
        }

        //--------------------------------
        // WINDING DOWN.....
        //
        // The only reason Dolly's time would be zero is if they are collapsed and out of time...

        if (windRate > 0) {

            timeSpan = llGetAndResetTime();

            if (timeSpan != 0) {

                // Key ticks down just a little further...
                timeLeftOnKey -= (integer)(timeSpan * (windRate = setWindRate()));
                if (timeLeftOnKey < 0) timeLeftOnKey = 0;

                lmSendConfig("timeLeftOnKey",(string)timeLeftOnKey);

                // Now that we've ticked down a few - check for warnings, and check for collapse
                if (timeLeftOnKey == 0) {

                    // Dolly is DONE! Go down... and yell for help.
                    if (!collapsed) {
                        cdSay( "Oh dear. The pretty Dolly " + dollName + " has run out of energy. Now if someone were to wind them... (Click on Dolly's key.)");
                        doCollapse();
                    }
                }
            }
        }
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    // For Transforming Key operations
    link_message(integer source, integer i, string data, key id) {

        parseLinkHeader(data,i);

        //----------------------------------------
        // SEND_CONFIG
        if (code == SEND_CONFIG) {
            string name = (string)split[0];

            list cmdList = [
                            "carrierID",
                            "carrierName",
                            "canAFK",
                            "configured",
                            "collapsed",
                            "allowRepeatWind",
                            "allowDress",
                            "allowSelfWind",
                            "isAFK",
                            "RLVok",
#ifdef ADULT_MODE
                            "allowStrip",
                            "hardcore",
#endif
                            "blacklist",
                            "dollDisplayName",
                            "dialogChannel",
                            "dollType",
                            "defaultCollapseRLVcmd",
#ifdef DEVELOPER_MODE
                            "debugLevel",
#endif
                            "hovertextOn",
                            "pronounHerDoll",
                            "pronounSheDoll",
                            "transformLockExpire",
                            "windEmergency",
                            "windNormal"
            ];

            // Commands need to be in the list cmdList in order to be
            // recognized, before testing down below
            //
            if (llListFindList(cmdList, (list)name) == NOT_FOUND)
                return;

            string value = (string)split[1];
            split = llDeleteSubList(split, 0, 0);

            if (name == "carrierID") {
                carrierID = (key)value;

                if (cdCarried()) carryExpire = llGetUnixTime() + CARRY_TIMEOUT;
                else carryExpire = 0;
                //lmSendConfig("carryExpire", (string)carryExpire);
            }
            else if (name == "carrierName")               carrierName = value;
            else if (name == "canAFK")                         canAFK = (integer)value;
            else if (name == "configured")                 configured = (integer)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
            else if (name == "allowRepeatWind")       allowRepeatWind = (integer)value;
            else if (name == "allowDress")                 allowDress = (integer)value;
            else if (name == "allowSelfWind")           allowSelfWind = (integer)value;
            else if (name == "isAFK")                           isAFK = (integer)value;
            else if (name == "RLVok") {
                RLVok = (integer)value;

                if (RLVok) {
                    // When RLV activates for whatever reason, make sure collapse is properly set
                    if (collapsed) doCollapse();
                }
            }
#ifdef ADULT_MODE
            else if (name == "allowStrip")                 allowStrip = (integer)value;
            else if (name == "hardcore")                     hardcore = (integer)value;
#endif
            else if (name == "blacklist") {
                if (split == [""]) blacklistList = [];
                else blacklistList = split;
            }
            else if (name == "controllers") {
                if (split == [""]) controllerList = [];
                else controllerList = split;
            }
            else if (name == "dollDisplayName")             dollDisplayName = value;
            else if (name == "dialogChannel")                 dialogChannel = (integer)value;
            else if (name == "dollType")                           dollType = value;
            else if (name == "defaultCollapseRLVcmd") defaultCollapseRLVcmd = value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                   debugLevel = (integer)value;
#endif
            else if (name == "hovertextOn")                 hovertextOn = (integer)value;
            else if (name == "pronounHerDoll")           pronounHerDoll = value;
            else if (name == "pronounSheDoll")           pronounSheDoll = value;
            else if (name == "transformLockExpire") transformLockExpire = (integer)value;
            else if (name == "windEmergency")             windEmergency = (integer)value;
            else if (name == "windNormal")                   windNormal = (integer)value;
        }

        //----------------------------------------
        // SET_CONFIG
        else if (code == SET_CONFIG) {
            string name = (string)split[0];
            string value = (string)split[1];
            split = llDeleteSubList(split, 0, 0);

            if (name == "keyLimit") {
                keyLimit = (integer)value;

                // Clip keyLimit to sane value
                if (keyLimit < KEYLIMIT_MIN) keyLimit = KEYLIMIT_MIN;
                else if (keyLimit > KEYLIMIT_MAX) keyLimit = KEYLIMIT_MAX;

                // if limit is less than time left on key, clip time remaining
                if (timeLeftOnKey > keyLimit) {
                    timeLeftOnKey = keyLimit;
                    lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
                }

                // Adjust windNormal if needed
                if (windNormal > keyLimit) {

                    windNormal = keyLimit / 6;
                    lmSendConfig("windNormal", (string)windNormal);

                    cdSayTo("Winding time was too large; changed to " + (string)windNormal,id);
                }

                lmSendConfig("keyLimit", (string)keyLimit);
            }
            else if (name == "windNormal") {
                windNormal = (integer)value;

                if (windNormal > (keyLimit / 2)) {
                    windNormal = keyLimit / 6;
                    cdSayTo("Winding time was too large; changed to " + (string)windNormal,(key)split[1]);
                }

                lmSendConfig("windNormal", (string)windNormal);
            }
            else if (name == "lastWinderID") {
                lmSendConfig("lastWinderID", (string)(lastWinderID = (key)value));
            }
            else if (name == "keyLocked") {
                lmSendConfig("keyLocked", value);
                keyLocked = (integer)value;

                if (keyLocked) rlvLockKey();
                else rlvUnlockKey();
            }
            else if (name == "isAFK") {
                lmSendConfig("isAFK", (string)(isAFK = (integer)value));
                lmInternalCommand("setHovertext", "", keyID);
                setWindRate();
            }
            else if (name == "timeLeftOnKey") {
                timeLeftOnKey = (integer)value;
                if (timeLeftOnKey > keyLimit) timeLeftOnKey = keyLimit;

                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
                if (collapsed) unCollapse();
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

                if (lowScriptMode) lowScriptExpire = llGetUnixTime() + LOWSCRIPT_TIMEOUT;
                llSetTimerEvent(LOW_RATE);
            }

            else if (name == "poseExpire") {
                poseExpire = (integer)value;
                lmSendConfig("poseExpire",(string)(poseExpire));
            }
            else if (name == "wearLockExpire") {
                wearLockExpire = (integer)value;

                wearLock = (wearLockExpire != 0);
                lmSendConfig("wearLock", (string)wearLock);

                lmSendConfig("wearLockExpire",(string)(wearLockExpire));
            }
        }

        //----------------------------------------
        // INTERNAL_CMD
        else if (code == INTERNAL_CMD) {
            string cmd = (string)split[0];
            split = llDeleteSubList(split, 0, 0);
            integer isController = cdIsController(id);

            if (cmd == "setWindRate") {
                setWindRate();
            }
            else if (cmd == "collapse") {
                integer collapseState = (integer)split[0];

                // The collapse internal command...

                if (collapsed != collapseState) {
                    if (collapseState) doCollapse();
                    else unCollapse();
                }
            }
            else if (cmd == "winding") {
                // We do this in a subroutine: this allows winding to happen from THIS
                // script in a synchronous fashion: if this function is moved, this will
                // have to be changed.
                debugSay(6,"DEBUG-MAIN","received winding cmd");
                doWinding((string)split[1],id);
            }
            else if (cmd == "windMsg") {
                integer windAmount = (integer)split[0];
                string winderName = (string)split[1];

                string mins = (string)llFloor(windAmount / SECS_PER_MIN);
                string percent = formatFloat1((float)timeLeftOnKey * 100.0 / (float)keyLimit);

                // Eliminate zero minutes, and correct grammar
                if (windAmount < 120) mins = "about a minute";
                else mins = mins + " more minutes";

                // Two possible messages to go out:
                //
                //   1. Standard wind message
                //   2. Fully wound message
                //
                // We're assuming that every winder has a non-null name, and every
                // auto-wind has a null name... is that really true?
                if (winderName != "") {

                    // We're trying to avoid having name obliterated by RLV viewers
                    // Note this makes no difference to waiting events, just other scripts
                    if (collapsed == 0) llSleep(0.5);

                    // Give informational message depending on who wound us
                    if (dollID == id) {
                        llOwnerSay("You managed to turn your key giving you " +
                            mins + " of life (" + percent + "% capacity).");
                    }
                    else {
#ifdef ADULT_MODE
                        if (hardcore) llOwnerSay("Your key has been cranked by " + winderName + ".");
                        else
#endif
                            llOwnerSay("Your key has been turned by " + winderName + " giving you " +
                                mins + " of life (" + percent + "% capacity).");

                        cdSayTo("You turn " + dollDisplayName + "'s Key, and " + pronounSheDoll + " receives " +
                            mins + " of life (" + percent + "% capacity).", id);
                    }

                    // If we wound to 100% ... then Dolly has been fully wound.
                    if (timeLeftOnKey > keyLimit - 30) {

                        // Fully wound

                        if (dollID == id) {
                            llOwnerSay("You have been fully wound!");
                        }
                        else {
                            // Holler so people know and to give props to winder
                            cdSay(dollDisplayName + " has been fully wound by " + winderName + "! Thank you!");
                        }
                    }
                }
                else {
                    // This should not happen - but if it does...
#ifdef DEVELOPER_MODE
                    cdDebugMsg("No name received in Internal Command windMsg!");
#endif
#ifdef ADULT_MODE
                    if (hardcore) llOwnerSay("Your key turns automatically, giving you additional minutes of life.");
                    else
#endif
                        llOwnerSay("Your key turns automatically, giving you an additional " + mins + " minutes of life (" + percent + "% capacity).");
                }
            }
        }

        //----------------------------------------
        // RLV_RESET
        else if (code == RLV_RESET) {
            RLVok = (integer)split[0];

            // refresh collapse state... no escape!
            if (collapsed) doCollapse();

            if (RLVok == TRUE) {
                if (!allowDress) llOwnerSay("The public cannot dress you.");
            }
            else {
                llOwnerSay("Without RLV, you cannot be dressed in new outfits.");
            }

            simRating = "";
            simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);
        }

        //----------------------------------------
        // MENU_SELECTION
        else if (code == MENU_SELECTION) {
            string menuChoice = (string)split[0];
            string name = (string)split[1];

            // if this message is a MENU_SELECTION, then the link message parameter "id"
            // is the key of the person who activated the menu

            if (menuChoice == MAIN) {
                // call actual Menu code
                lmInternalCommand("mainMenu", "|" + name, id);
            }
            else if (menuChoice == "Wind Emg") {
                // Give this a time limit: can only be done once
                // in - say - 6 hours... at least maxwindtime *2 or *3.

                if (winderRechargeTime <= llGetUnixTime()) {
                    // Winder is recharged and usable.

                    if (collapsed) {

                        lmSendToController(dollName + " has activated the emergency winder.");

                        lmSendConfig("winderRechargeTime", (string)(winderRechargeTime = (llGetUnixTime() + EMERGENCY_LIMIT_TIME)));
                        lmSendConfig("lastWinderID", (string)(lastWinderID = dollID));

                        timeLeftOnKey = windEmergency;
                        unCollapse();

                        string s = "With an electical sound the motor whirrs into life, ";
#ifdef ADULT_MODE
                        if (hardcore) llOwnerSay(s + "and you can feel your joints reanimating as time is added.");
                        else
#endif
                        llOwnerSay(s + "and gives you " + (string)llRound(windEmergency / SECS_PER_MIN) + " minutes of life. The emergency winder requires " + (string)llRound(EMERGENCY_LIMIT_TIME / 3600) + " hours to recharge.");
                    }
                }
                else {
                    integer rechargeMins = ((winderRechargeTime - llGetUnixTime()) / SECS_PER_MIN);
                    string s = "Emergency self-winder is not yet recharged.";

#ifdef ADULT_MODE
                    if (!hardcore) {
#endif
                        s += "  There remains ";

                        if (rechargeMins < 60) s += (string)rechargeMins + " minutes ";
                        else s += "over " + (string)(rechargeMins / 60) + " hours ";

                        s += "before it will be ready again.";
#ifdef ADULT_MODE
                    }
#endif
                    llOwnerSay(s);
                }
            }

            else if (menuChoice == "Lock") {
                lmSendConfig("keyLocked", (string)(keyLocked = TRUE));

                if (keyLocked) rlvLockKey();
                else rlvUnlockKey();

                lmInternalCommand("mainMenu", "|" + name, id);
            }

            else if (menuChoice == "Unlock") {
                lmSendConfig("keyLocked", (string)(keyLocked = FALSE));

                if (keyLocked) rlvLockKey();
                else rlvUnlockKey();

                lmInternalCommand("mainMenu", "|" + name, id);
            }

            // Winding - pure and simple
            else if (menuChoice == "Wind") {

                // The winding process also handles messages directly
                doWinding(name,id);
                lmInternalCommand("mainMenu", "|" + name, id);
            }

            // Note that Max Times are "m" and Wind Times are "min" - this is on purpose to
            // keep the two separate
            else if (menuChoice == "Max Time...") {
#ifdef ADULT_MODE
                list maxList = [ "45m", "60m", "75m", "90m", "120m" ];
                if (!hardcore) maxList += [ "150m", "180m", "240m" ];
#else
                list maxList = [ "45m", "60m", "75m", "90m", "120m", "150m", "180m", "240m" ];
#endif
                maxList += MAIN;

                // If the Max Times available are changed, be sure to change the next choice also
                lmDialogListen();
                llDialog(id, "You can set the maximum available time here.  Dolly cannot be wound beyond this amount of time.\nDolly currently has " + (string)llFloor(timeLeftOnKey / SECS_PER_MIN) + " mins left of " + (string)llFloor(keyLimit / SECS_PER_MIN) + ". If you lower the maximum, Dolly will lose any extra time entirely.",
                    dialogSort(maxList), dialogChannel);
            }

            // This is setting the windNormal; we don't have to check to see if
            // it is too large: this is done during the menu creation phase
            //
            else if ((menuChoice ==  "15min") ||
                     (menuChoice ==  "30min") ||
                     (menuChoice ==  "45min") ||
                     (menuChoice ==  "60min") ||
                     (menuChoice ==  "90min") ||
                     (menuChoice == "120min")) {

                windNormal = (integer)menuChoice * (integer)SECS_PER_MIN;
                lmSetConfig("windNormal", (string)windNormal);

                cdSayTo("Winding now set to " + (string)(windNormal / (integer)SECS_PER_MIN) + " minutes",id);
                lmMenuReply("Key...","",id);
            }

            // This is setting the keyLimit; windNormal is adjusted if necessary
            //
            else if ((menuChoice ==  "45m") ||
                     (menuChoice ==  "60m") ||
                     (menuChoice ==  "75m") ||
                     (menuChoice ==  "90m") ||
                     (menuChoice == "120m") ||
                     (menuChoice == "150m") ||
                     (menuChoice == "180m") ||
                     (menuChoice == "240m")) {

                keyLimit = (integer)menuChoice * SECS_PER_MIN;

                cdSayTo("Key limit now set to " + (string)llFloor(keyLimit / SECS_PER_MIN) + " minutes",id);

                lmSetConfig("keyLimit", (string)keyLimit);
                lmMenuReply("Key...","",id);
            }
            else if (menuChoice == "Wind Time...") {
                list windChoices;

                // Build up the allowed winding times based on the KeyLimit
                if (keyLimit >=  30) windChoices +=  "15min";
                if (keyLimit >=  60) windChoices +=  "30min";
                if (keyLimit >=  90) windChoices +=  "45min";
                if (keyLimit >= 120) windChoices +=  "60min";
                if (keyLimit >= 180) windChoices +=  "90min";
                if (keyLimit >= 240) windChoices += "120min";

                lmDialogListen();
                llDialog(id, "You can set the amount of time in each wind.\nDolly currently winds " + (string)(windNormal / (integer)SECS_PER_MIN) + " mins.",
                    dialogSort(windChoices + [ MAIN ]), dialogChannel);
            }
            else if (menuChoice == "Unwind") {
                doCollapse();
                cdSayTo("Dolly collapses, " + pronounHerDoll + " key unwound",id);
            }
        }

        // Quick shortcut...
        else if (code < 200) {

#define UNATTACHED_RATE 60.0

            if (code == INIT_STAGE2) {
                ;
            }

            else if (code == INIT_STAGE3) {
                dollID = llGetOwner();
                dollName = dollyName();

                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
                setWindRate();
            }

            else if (code == INIT_STAGE4) {

                     if (lowScriptMode) llSetTimerEvent(LOW_RATE);
                else                    llSetTimerEvent(STD_RATE);

                timerStarted = TRUE;
            }

#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                float delay = (float)split[0];
                memReport(myName,delay);
            }
#endif
            else if (code == CONFIG_REPORT) {
                cdConfigureReport();
            }
        }
    }

    //----------------------------------------
    // RUN TIME PERMISSIONS
    //----------------------------------------
    run_time_permissions(integer perm) {
        permMask = perm;

        debugSay(2,"DEBUG-AVATAR","ifPermissions (run_time_permissions)");

        //----------------------------------------
        // PERMISSION_TRIGGER_ANIMATION

        if (permMask & PERMISSION_TRIGGER_ANIMATION) {

            if (collapsed) llStartAnimation(ANIMATION_COLLAPSED);
            else llStartAnimation("Stand");
        }

        //----------------------------------------
        // PERMISSION_TAKE_CONTROLS

        if (permMask & PERMISSION_TAKE_CONTROLS) {

            if (collapsed) {
                // Dolly is "frozen": collapsed

                // When collapsed the doll should not be able to move at all; so the key will
                // accept their attempts to move, but ignore them
                disableMovementControl();

            }
            else {
                // Dolly is not collapsed
                enableMovementControl();
            }
        }
    }
}

//========== MAIN ==========
