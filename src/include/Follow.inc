//========================================
// FOLLOW
//========================================
//
// Because of the importance of these, and the possibility of different methods
// of performing these functions, these have been separated out.
//
// Functions:
//     * startFollow(id)
//     * keepFollow(id)
//     * stopFollow(id)
//     * drunkardsWalk()
//     * dropCarrier(id)

vector carrierPos;
vector carrierPosNew;

#ifdef TURN_TOWARDS
vector pointTo; // here for speed
#endif

#define FACE_ITERATION_FACTOR 50
integer turnTo = FACE_ITERATION_FACTOR;

#define STUCK_LIMIT 6
integer stuckFollowLimit = STUCK_LIMIT;

startFollow(key id) {
    llSetTimerEvent(timerRate = adjustTimer());

    keepFollow(id);
}

keepFollow(key id) {
    // if Dolly is posed, stop moving
    if (poseAnimation != ANIMATION_NONE) {
        // Note we are still being carried - but being in a pose, we're
        // not going anywhere.
        llStopMoveToTarget();
        return;
    }

    // We are not posed...

    list objectDetails = llGetObjectDetails(id, [OBJECT_POS]);
    carrierPosNew = (vector)objectDetails[0];

    if (carrierPosNew) {

        // Bump timer
        lmSendConfig("carryExpire", (string)(carryExpire = llGetUnixTime() + CARRY_TIMEOUT));

        if (llVecDist(carrierPosNew,llGetPos()) <= 2.0) {
            carrierPos = carrierPosNew;

            //stopFollow(); stopFollow() doesnt do what we want
            //if (timerRate != 2.0) {
            //    timerRate = 2.0;
            //    llSetTimerEvent(timerRate); // the usual follow timer is too tight... back off until carrier moves away
            //    llStopMoveToTarget();
            //}
            nearCarrier = TRUE;
            llSetTimerEvent(timerRate = 2.0); // the usual follow timer is too tight... back off until carrier moves away
            llStopMoveToTarget();

            return;
        }
        else if (nearCarrier == TRUE) {
            nearCarrier = FALSE;
            llSetTimerEvent(timerRate = adjustTimer()); // crank the timer back up
        }

        // Note that keepFollow() keeps running... just in case the carrier DOES move...
        // This also means that as long as the carrier doesn't move more than 2m away,
        // we won't move.

#ifdef DRUNKARDS_WALK
       if (carrierPos == carrierPosNew) {
            stuckFollowLimit--;
            if (struckFollowLimit == 0) {
                // Try to get unstuck
                drunkardsWalk();
                stuckFollowLimit = STUCK_LIMIT;
            }
        }
        else {
            stuckFollowLimit = STUCK_LIMIT;
        }
#endif

#ifdef DEVELOPER_MODE
        // See if carrier has moved...
        if (carrierPos != carrierPosNew) {
            debugSay(6,"DEBUG-FOLLOW","Carrier moved to " + (string)(carrierPos));
        }
#endif

        carrierPos = carrierPosNew;

#ifdef TURN_TOWARDS
        // This just turns us to face toward the carrier
        // FIXME: Do we want this?
        pointTo = carrierPos - llGetPos();
        lmRunRLV("setrot:" + (string)(llAtan2(pointTo.x, pointTo.y)) + "=force");
#endif

        //debugSay(6,"DEBUG-FOLLOW","Moving toward carrier at " + (string)(carrierPos));

        // Do actual move
        llMoveToTarget(carrierPos, 0.7);
    }
    else {
        llOwnerSay("Your carrier has disappeared, and seems to have dropped you.");
        dropCarrier(id);
    }
}

stopFollow(key id) {
    // Stop going towards target
    llStopMoveToTarget();
    llSetTimerEvent(timerRate = adjustTimer());
}

#ifdef DRUNKARDS_WALK
drunkardsWalk() {
    vector randomPos;
    float randomAngle;
    integer x = 5; // Iterations

#define RANDOM_RANGE 2

    // We seem to be stuck somehow
    //
    // 1. Pick random point 2 meters away
    // 2. Move there
    // 3. Do this again several times
    // 4. Return
    //
    // Let not_at_target call this if we haven't moved in
    // so many repeats
    //
    // Note we don't change the target for at_target: no need

    do {
        randomAngle = llFrand(TWO_PI);
        randomPos.x = RANDOM_RANGE * llCos(randomAngle);
        randomPos.y = RANDOM_RANGE * llSin(randomAngle);
        llMoveToTarget(randomPos, 0.7);
    }
    while (x--);
}
#endif

dropCarrier(key id) {
    // Dolly is at Target

    // Full stop: avatar comes to stop
    carrierPos = ZERO_VECTOR;
    carrierID = NULL_KEY;
    carrierName = "";
    carryExpire = 0;
    hasCarrier = FALSE;

    stopFollow(id);

    // Could use Uncarry, but that is orient towards a user drop
    lmSendConfig("carrierID", (string)carrierID);
    lmSendConfig("carrierName", carrierName);
    lmSendConfig("carryExpire", (string)carryExpire);
}

setCarrier(key carrierIDNew) {
    // This is only to set a proper carrier, NOT to drop one
    if (carrierIDNew == NULL_KEY) return;

    // This only happens when Dolly is first carried...
    // If Dolly is posed, then it still needs to be activated

    hasCarrier = TRUE;
    carrierID = carrierIDNew;
    carrierName = llGetDisplayName(carrierID);

    lmSendConfig("carrierID", (string)carrierID);
    lmSendConfig("carrierName", carrierName);
    lmSendConfig("carryExpire", (string)(carryExpire = llGetUnixTime() + CARRY_TIMEOUT));
}

