// Main.lsl
//
// vim:sw=4 et nowrap:
//
// DATE: 22 March 2013
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
integer isTransformingKey = 0;
//
// All other settings of this variable have been removed,
// including the SetDefaults and the NCPrefs.

integer configured;

integer visible = 1;
integer signOn;
integer detachable = 1;
integer autoTP;
integer pleasureDoll;
integer helpless;
integer canFly = 1;
integer hasController;
integer windDown = 1;
integer afk;
integer autoAFK = 1;
integer warned;
integer doWarnings;
integer canSit = 1;
integer canAFK = 1;
integer canStand = 1;
integer canCarry = 1;
integer canDress = 1;
integer takeoverAllowed;
integer quiet;
integer minsLeft;
integer clearAnims;
//integer canPose;
float lastEmergencyTime;
integer emergencyLimitHours = 12;
integer emergencyLimitTime = 43200; // (60 * 60 * emergencyLimitHours) // measured in seconds
integer RLVok;
integer RLVck;
integer demoMode;

// This variable is used to set the home landmark
string LANDMARK_HOME = "Home";
// This variable is used to set the collapse animation - and documentation
string ANIMATION_COLLAPSED = "collapse";
// This is the permissions the script will seek
integer PERMISSION_MASK = 0x8034;
// This mask will capture all of the dolls controls
integer CONTROL_ALL = 0x5000033f;
// This mask just grabs the basic movement keys
integer CONTROL_MOVE = 0x335;
// This is the distance away the doll will be carried
float CARRY_RANGE = 1.5;

string rlvAPIversion;

// Keys of important people in life of the Key:
key MasterBuilder = "42c7aaec-38bc-4b0c-94dd-ae562eb67e6d";   // Christina Halpin
key  MasterWinder = "64d26535-f390-4dc4-a371-a712b946daf8";   // GreigHighland
key        DevOne = "c5e11d0a-694f-46cc-864b-e42340890934";   // MayStone
key        DevTwo = "2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9";   // Silky Mesmeriser

// Current Controller - or Mistress
key MistressID = MasterBuilder;

key dollID;
key carrierID;
key dresserID;

string httpstart = "http://communitydolls.com/";
integer dialogChannel;
integer chatChannel = 75;
integer chatHandle;
integer targetHandle;

// If the key is a Transforming Key - one that can transform from one
// type of Doll to another - this tracks the current type of doll.
string dollType = "Regular";

// these are measured in timer tics - not minutes or seconds
// assuming a clock interval of 10 seconds -
// so multiply by 6 for factors
float windamount   = 1800.0; // 30 * ticks;    // 30 minutes
float defLimit     = 7200.0; // 180 * ticks;   // 180 minutes - worksafe (3h)
float keyLimit     = defLimit;
//integer posedlimit    = 30;     // 5 minutes
float hackLimit    = 720.0; // 6 * 60 * ticks;   // 6 hours
float demoLimit    = 300.0; // 5 minutes

float RATE_STANDARD = 1.0;
float RATE_AFK = 0.5;
float windRate;
float timeLeftOnKey = windamount;
integer ticks;
//integer posedtime;
integer posed;
integer carried;
integer collapsed;
integer carryMoved;
vector carrierPos;
string keyAnimation;
string currentAnimation;
string newAnimation;
string dollName;
string carrierName;
string mistressName;
key mistressQuery;
string simRating;
key simRatingQuery;
string newState;

//========================================
// FUNCTIONS
//========================================

//----------------------------------------
// Utility Functions
//----------------------------------------
string wwGetSLUrl() {
    string region = llGetRegionName();
    vector pos = llGetPos();
    string posx = (string)llRound(pos.x);
    string posy = (string)llRound(pos.y);
    string posz = (string)llRound(pos.z);

    return ("secondlife://" + llEscapeURL(region) +"/" + posx + "/" + posy + "/" + posz);
}

string formatFloat(float val, integer dp) {
    string out = "ERROR";
    if (dp == 0) {
        out = (string)llRound(val);
    } else if (dp > 0 && dp <= 6) {
        val = llRound(val * llPow(10.0, dp)) / llPow(10.0, dp);
        out = llGetSubString((string)val, 0, -7 + dp);
    }
    return out;
}

integer devKey() {
    list developerList = [ DevOne, DevTwo ];
    if (dollID != llGetOwner()) dollID = llGetOwner();
    return llListFindList(developerList, [ dollID ]) != -1;
}

memReport() {
    float free_memory = (float)llGetFreeMemory();
    float used_memory = (float)llGetUsedMemory();

    if (devKey()) llOwnerSay(llGetScriptName() + ": Memory " + formatFloat(used_memory/1024.0, 2) + "/" +
                     (string)llRound((used_memory + free_memory)/1024.0) + "kB, " + formatFloat(free_memory/1024.0, 2) + " kB free");
}

//---------------------------------------
// Configuration Functions
//---------------------------------------
// This code assumes a human-generated config file
processConfiguration(string name, list values) {
    //----------------------------------------
    // Assign values to program variables

    //if (name == "doll type") {
        // Ensure proper capitalization for matching or display
        //setDollType(llList2String(values, 0));
    //}
    if (name == "initial time") {
        timeLeftOnKey = ((llList2Float(values, 0))*60);
        if ((timeLeftOnKey<=0)) {
            collapsed = 1;
            keyAnimation = ANIMATION_COLLAPSED;
            llMessageLinked(LINK_SET, 305, llGetScriptName() + "|collapse|" + wwGetSLUrl(), NULL_KEY);
        }
        llMessageLinked(LINK_SET, 300, "timeLeftOnKey|" + (string)timeLeftOnKey, NULL_KEY);
    }
    else if (name == "wind time") {
        windamount = ((llList2Float(values, 0))*60);
    }
    else if (name == "max time") {
        defLimit = ((llList2Float(values, 0))*60);
        keyLimit = defLimit;
    }
    else if (name == "helpless dolly") {
        helpless = llList2Integer(values, 0);
    }
    else if (name == "controller") {
        MistressID = llList2Key(values, 0);
        llMessageLinked(LINK_SET, 300, "MistressID", MistressID);
        hasController = 1;
        takeoverAllowed = 0; // there is a Mistress; takeover is irrelevant
        mistressQuery = llRequestAgentData(MistressID, DATA_NAME);
    }
    else if (name == "auto tp") {
        autoTP = llList2Integer(values, 0);
    }
    else if (name == "pleasure doll") {
        pleasureDoll = llList2Integer(values, 0);
    }
    else if (name == "detachable") {
        detachable = llList2Integer(values, 0);
    }
    else if (name == "outfitable") {
        integer oldSetting = canDress;
        canDress = llList2Integer(values, 0);
        if (RLVok && oldSetting && !canDress) llOwnerSay("Other people cannot outfit you.");
    }
    else if (name == "can fly") {
        canFly = llList2Integer(values, 0);
    }
    else if (name == "can sit") {
        canSit = llList2Integer(values, 0);
    }
    else if (name == "can stand") {
        canStand = llList2Integer(values, 0);
    }
    else if (name == "quiet key") {
        quiet = llList2Integer(values, 0);
    }
}

setDollType(string choice) {
    // Pre-conversion... restore settings as needed

    // change to new Doll Type
    dollType = llGetSubString(llToUpper(choice), 0, 0) + llGetSubString(llToLower(choice), 1, -1);

    // Update sign if appropriate
    if (collapsed)   llSetText("Disabled Dolly!",        <1.0, 0.0, 0.0>, 1.0);
    else if (afk)    llSetText(dollType + " Doll (AFK)", <1.0, 1.0, 0.0>, 1.0);
    else if (signOn) llSetText(dollType + " Doll",       <1.0, 1.0, 1.0>, 1.0);
    else             llSetText("",                       <1.0, 1.0, 1.0>, 1.0);

    // new type is slut Doll
    if (dollType == "Slut") {
        llOwnerSay("As a slut Doll, you can be stripped.");
    }

    // new type is builder or key doll
    if (dollType == "Builder" || dollType == "Key")
        llOwnerSay("You are a " + llToLower(dollType) + " doll so you do not wind down");
}

stopAnimations() {
    list anims = llGetAnimationList(dollID);
    integer n;
    string anim;
    integer animCount = llGetListLength(anims);

    for ( n = 0; n < animCount; n++ ) {
        anim = llList2String(anims, n);

        llStopAnimation(anim);
        llSleep(0.5);
    }
}

float windKey() {
    float windLimit = keyLimit - timeLeftOnKey;
    //if (demoMode) windLimit = demoLimit - timeLeftOnKey;
    
    // Return if winding is irrelevant
    if (windLimit <= 0) return 0;

    // Return windamount if less than remaining capacity
    else if (windLimit >= windamount) {
        timeLeftOnKey += windamount;
        return windamount;
    }
        
    // Else return limit - timeleft
    else {
        // Inform doll of full wind
        //llOwnerSay("You have been fully wound - " + (string)llRound(keyLimit / 60.0) + " minutes remaining.");
        timeLeftOnKey += windLimit;
        return windLimit;
    }
}

doWind(string name, key id) {
    integer winding = llFloor(windKey() / 60.0);

    if (winding > 0) {
        if (timeLeftOnKey == keyLimit) {
            llMessageLinked(LINK_SET, 11, "You have given " + dollName + " " + (string)winding + " more minutes of life.", id);

            if (!quiet) llSay(0, dollName + " has been fully wound by " + name + ".");
            else llMessageLinked(LINK_SET, 11, dollName + " is now fully wound.", id);
        } else {
            llMessageLinked(LINK_SET, 11, "You have given " + dollName + " " + (string)winding + " more minutes of life (" + formatFloat((float)timeLeftOnKey * 100.0 / (float)keyLimit, 2) + "% capacity).", id);
        }
        // Is this too spammy?
        llOwnerSay("Have you remembered to thank " + name + " for winding you?");
    }

    if (collapsed) uncollapse();
    else llMessageLinked(LINK_SET, 300, "timeLeftOnKey|" + (string)timeLeftOnKey, NULL_KEY);
}

integer isMistress(key id) {
    list mastersList = [ MistressID, MasterBuilder, MasterWinder ];
    return (llListFindList(mastersList, [ id ]) != -1);
}

initializeStart ()  {
    llSetLinkAlpha(LINK_SET, 1, ALL_SIDES);

    dollName = llGetDisplayName(dollID);

    setWindRate();

    if (configured) initFinal();
}

initFinal() {
    llOwnerSay("You have " + (string)llRound((timeLeftOnKey)/60) + " minutes of life remaning.");
    llMessageLinked(LINK_SET, 300, "timeLeftOnKey|" + (string)timeLeftOnKey, NULL_KEY);

    // When rezzed.... if currently being carried, drop..
    if (carried) uncarry();

    // When rezzed.... if collapsed... no escape!
    if (collapsed) {
        llMessageLinked(LINK_SET, 305, llGetScriptName() + "|collapse|" + wwGetSLUrl(), NULL_KEY);
    }

    if (collapsed) llSetText("Disabled Dolly!", <1,0,0>, 1);
    else if (afk) llSetText(dollType + " Doll (AFK)", <1,1,0>, 1);
    else if (signOn) llSetText(dollType + " Doll", <1,1,1>, 1);
    else llSetText("", <1,1,1>, 1);

    if (!canDress) llOwnerSay("Other people cannot outfit you.");
    if (mistressName) llOwnerSay("Your Mistress is " + mistressName);

    if (RLVok && hasController)
        llMessageLinked(LINK_SET, 11, dollName + " has logged in with RLV at " + wwGetSLUrl(), MistressID);
    else if (hasController)
        llMessageLinked(LINK_SET, 11, dollName + " has logged in without RLV at " + wwGetSLUrl(), MistressID);

    // Start clock ticks
    llSetTimerEvent(1.0);

    setWindRate();

    clearAnims = 1;
    ifPermissions();

    llMessageLinked(LINK_SET, 103, llGetScriptName(), NULL_KEY);
}

aoControl(integer on) {
    integer LockMeisterChannel = -8888;

    if (on) llWhisper(LockMeisterChannel, (string)dollID + "booton");
    else    llWhisper(LockMeisterChannel, (string)dollID + "bootoff");
}

ifPermissions() {
    key grantor = llGetPermissionsKey();
    integer perm = llGetPermissions();

    if (grantor != NULL_KEY && grantor != dollID) {
        llResetOtherScript("Start");
        llSleep(10);
    }

    if (!((perm & PERMISSION_MASK) == PERMISSION_MASK))
        llRequestPermissions(dollID, PERMISSION_MASK);

    if (grantor == dollID) {
        if (llGetAttached() == ATTACH_BACK) {
            if (perm & PERMISSION_TRIGGER_ANIMATION) {
                if (keyAnimation != "") {
                    aoControl(0); // AO off

                    list animList;
                    integer i;
                    integer animCount;
                    key animKey = llGetInventoryKey(keyAnimation);

                    // stops all animations until only keyAnimation is running
                    while ((animList = llGetAnimationList(dollID)) != [ animKey ]) {
                        animCount = llGetListLength(animList);

                        // Stops all animations except the requested keyAnimation
                        for (i = 0; i < animCount; i++) {
                            if (llList2Key(animList, i) != animKey) llStopAnimation(llList2Key(animList, i));
                        }
                        llStartAnimation(keyAnimation);
                    }
                } else if (clearAnims) {
                    list animList = llGetAnimationList(dollID);
                    integer i;
                    integer animCount = llGetInventoryNumber(20);

                    // This stops all poses, and a collapsed animation, too
                    for (i = 0; i < animCount; i++) {
                        key animKey = llGetInventoryKey(llGetInventoryName(20, i));

                        if (~llListFindList(animList, (list) animKey))
                            llStopAnimation(animKey);
                    }
                    clearAnims = 0;
                    aoControl(1); // AO on
                }
            }

            if (perm & PERMISSION_OVERRIDE_ANIMATIONS) {
                if (keyAnimation != "") {
                    llSetAnimationOverride("Standing", keyAnimation);
                }
                else llResetAnimationOverride("ALL");
            }

            if (perm & PERMISSION_TAKE_CONTROLS) {
                // if collapsed or posed doll loses ability to move
                if (collapsed || posed) llTakeControls(CONTROL_ALL,  1, 0);
                else                    llTakeControls(CONTROL_MOVE, 1, 1);
            }
        }

        if (perm & PERMISSION_ATTACH) {
            if (!devKey() && !llGetAttached())
                llAttachToAvatar(ATTACH_BACK);
        }
    }
}

float setWindRate() {
    float newWindRate = RATE_STANDARD;
    vector agentPos = llList2Vector(llGetObjectDetails(dollID, [ OBJECT_POS ]), 0);
    integer agentInfo = llGetAgentInfo(dollID);
    integer attached = llGetAttached() == ATTACH_BACK;
    integer windDown = attached && !collapsed && dollType != "Builder" && dollType != "Key";

    if (afk) newWindRate *= RATE_AFK;

    if (windRate != newWindRate * windDown) {
        windRate = newWindRate * windDown;
        llMessageLinked(LINK_SET, 300, "windRate|" + (string)windRate, NULL_KEY);
    }

    // llTargetOmega: With normalized vector spinrate is equal to radians per second
    // 2𝜋 radians per rotation.  This sets a normal rotation rate of 4 rpm about the
    // Z axis multiplied by the wind rate this way the key will visually run faster as
    // the dolly begins using their time faster.
    llTargetOmega(llVecNorm(<0.0, 0.0, 1.0>), windRate * (TWO_PI / 15.0), 1);

    return newWindRate;
}

turnToTarget(vector target) {
    vector pointTo = target - llGetPos();
    float  turnAngle = llAtan2(pointTo.x, pointTo.y);
    llMessageLinked(LINK_SET, 315, "setrot:" + (string)(turnAngle) + "=force", NULL_KEY);
}

carry(string name, key id) {
    carried = 1;
    carrierID = id;
    carrierName = name;

    // Clear old targets to ensure there is only one
    llTargetRemove(targetHandle);
    llStopMoveToTarget();

    // Set updated target
    carrierPos = llList2Vector(llGetObjectDetails(carrierID, [OBJECT_POS]), 0);
    targetHandle = llTarget(carrierPos, CARRY_RANGE);

    if (carrierPos != ZERO_VECTOR && !posed) llMoveToTarget(carrierPos, 0.7);

    if (!quiet)
        llSay(0, "The doll " + dollName + " has been picked up by " + carrierName);
    else {
        llOwnerSay("You have been picked up by " + carrierName);
        llRegionSayTo(carrierID, 0, "You have picked up the doll " + dollName);
    }
}

collapse() {
    collapsed = 1;
    keyAnimation = ANIMATION_COLLAPSED;
    setWindRate();
    llMessageLinked(LINK_SET, 305, llGetScriptName() + "|collapse|" + wwGetSLUrl(), NULL_KEY);
    ifPermissions();
    llMessageLinked(LINK_SET, 300, "timeLeftOnKey|" + (string)timeLeftOnKey, NULL_KEY);
}

uncarry() {
    carried = 0;
    carrierID = NULL_KEY;
    carrierName = "";

    // Clear old targets to ensure there is only one
    llTargetRemove(targetHandle);
    llStopMoveToTarget();
}

uncollapse() {
    collapsed = 0;
    keyAnimation = "";
    clearAnims = 1;
    setWindRate();
    llMessageLinked(LINK_SET, 305, llGetScriptName() + "|restore", NULL_KEY);
    llMessageLinked(LINK_SET, 300, "timeLeftOnKey|" + (string)timeLeftOnKey, NULL_KEY);
    ifPermissions();
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
        dollID = llGetOwner();
        llMessageLinked(LINK_SET, 999, llGetScriptName(), NULL_KEY);
    }

    //----------------------------------------
    // ON_REZ
    //----------------------------------------
    on_rez(integer start) {
        llResetTime();
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
            llMessageLinked(LINK_SET, 150, simRating, NULL_KEY);

            if ((simRating == "MATURE" && simRating == "ADULT") && (pleasureDoll || dollType == "Slut")) {
                llOwnerSay("Entered " + llGetRegionName() + " rating is " + llToLower(simRating) + " stripping disabled.");
            }
        }
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & CHANGED_REGION) {
            simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);
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

        // Update sign if appropriate
        string primText = llList2String(llGetPrimitiveParams([ PRIM_TEXT ]), 0);
        if (collapsed || afk || signOn) {
            if (collapsed &&   primText != "Disabled Dolly!")          llSetText("Disabled Dolly!",        <1.0, 0.0, 0.0>, 1.0);
            else if (afk &&    primText != dollType + " Doll (AFK)")   llSetText(dollType + " Doll (AFK)", <1.0, 1.0, 0.0>, 1.0);
            else if (signOn && primText != dollType + " Doll")         llSetText(dollType + " Doll",       <1.0, 1.0, 1.0>, 1.0);
        } else if (primText != "")                                   llSetText("",                       <1.0, 1.0, 1.0>, 1.0);

        // Increment a counter
        ticks++;

        if (ticks % 60 == 0)  llMessageLinked(LINK_SET, 300, "timeLeftOnKey|" + (string)timeLeftOnKey, NULL_KEY);

        ifPermissions();

        integer agentInfo = llGetAgentInfo(dollID);
        integer newAFK;
        // When Dolly is "away" - enter AFK
        if (agentInfo & AGENT_AWAY) {
            newAFK = 1;
            autoAFK = 1;
        } else if (afk && autoAFK) {
            newAFK = 0;
            autoAFK = 0;
        }
        if (newAFK != afk) {
            setWindRate();
            integer minsLeft;
            if (windRate > 0.0) minsLeft = llRound(timeLeftOnKey / (60.0 * windRate));
            llMessageLinked(LINK_SET, 305, llGetScriptName() + "|setAFK|" + (string)(afk = newAFK) + "|" + (string)autoAFK + "|" + formatFloat(windRate, 1) + "|" + (string)minsLeft, NULL_KEY);
        }

        // A specific test for collapsed status is no longer required here
        // as being collapsed is one of several conditions which forces the
        // wind rate to be 0.
        // Others which cause this effect are not being attached to spine
        // and
        //--------------------------------
        // WINDING DOWN.....
        if (windRate != 0.0) {
            timeLeftOnKey -= (llGetAndResetTime() * windRate);
            if (timeLeftOnKey < 0.0) timeLeftOnKey = 0.0;

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
            if (!collapsed && (timeLeftOnKey<=0)) {
                collapse();

                // This message is intentionally excluded from the quiet key setting as it is not good for
                // dolls to simply go down silently.
                llSay(0, "Oh dear. The pretty Dolly " + dollName + " has run out of energy. Now if someone were to wind them... (Click on their key.)");
            }
        }
    }

    at_target(integer num, vector target, vector me) {
        // Clear old targets to ensure there is only one
        llTargetRemove(targetHandle);
        llStopMoveToTarget();

        // Set updated target
        carrierPos = llList2Vector(llGetObjectDetails(carrierID, [OBJECT_POS]), 0);
        targetHandle = llTarget(carrierPos, CARRY_RANGE);

        //if ((carrierPos != ZERO_VECTOR) && !posed) llMoveToTarget(carrierPos, 0.7);

        if(carryMoved) {
            turnToTarget(carrierPos);
            carryMoved = 0;
        }
    }

    not_at_target() {
        vector newCarrierPos = llList2Vector(llGetObjectDetails(carrierID,[OBJECT_POS]),0);
        //llStopMoveToTarget();
        if (carrierPos != newCarrierPos)
        {
            llTargetRemove(targetHandle);
            carrierPos = newCarrierPos;
            targetHandle = llTarget(carrierPos, CARRY_RANGE);
        }
        if ((carrierPos != ZERO_VECTOR) && !posed)
        {
            //only at target
            llMoveToTarget(carrierPos, 0.7);
        }
        else
        {
            llStopMoveToTarget();
        }
    }

    //----------------------------------------
    // RECEIVED A LINK MESSAGE
    //----------------------------------------
    // For Transforming Key operations
    link_message(integer source, integer num, string data, key id) {
        list parameterList = llParseString2List(data, [ "|" ], []);

        // 16: Change Key Type: transforming: choice = Doll Type
        if (num == 16) {
            setDollType(llList2String(parameterList, 0));
        }

        // 18: Convert to Transforming Key
        else if (num == 18) {
            isTransformingKey = 1;
        }

        else if (num == 101) {
            if (!configured)
                processConfiguration(llList2String(parameterList, 0), llList2List(parameterList, 1, -1));
        }

        else if (num == 102) {
            configured = 1;
            initFinal();
        }

        else if (num == 104) {
            dollID = llGetOwner();

            chatHandle = llListen(chatChannel, "", dollID, "");
            //dialogChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)llGetLinkKey(2), -9, -1));
            simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);

            llSetText("", <1,1,1>, 1);

            initializeStart();
        }

        else if (num == 105) {
            if (hasController && mistressName != "") llOwnerSay("Your Mistress is " + mistressName);
            else mistressQuery = llRequestDisplayName(MistressID);

            dialogChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)llGetLinkKey(2), -9, -1));
            simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);

            simRating = "";
            simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);

            initFinal();
        }

        else if (num == 135) memReport();

        else if (num == 300) {
            string name = llList2String(parameterList, 0);
            string value = llList2String(parameterList, 1);

                 if (name == "detachable")            detachable = (integer)value;
            else if (name == "autoTP")                    autoTP = (integer)value;
            else if (name == "pleasureDoll")        pleasureDoll = (integer)value;
            else if (name == "helpless")                helpless = (integer)value;
            else if (name == "canCarry")                canCarry = (integer)value;
            else if (name == "canDress")                canDress = (integer)value;
            else if (name == "canStand")                canStand = (integer)value;
            else if (name == "canSit")                    canSit = (integer)value;
            else if (name == "canFly")                    canFly = (integer)value;
            else if (name == "takeoverAllowed")  takeoverAllowed = (integer)value;
            else if (name == "doWarnings")            doWarnings = (integer)value;
            else if (name == "signOn")                    signOn = (integer)value;
            else if (name == "canAFK")                    canAFK = (integer)value;
            else if (name == "hasController")      hasController = (integer)value;
            else if (name == "autoAFK")                  autoAFK = (integer)value;
            else if (name == "windamount")            windamount = (float)value;
            else if (name == "keyLimit")                keyLimit = (float)value;

            else if (name == "MistressID") {
                MistressID = (key)value;
                hasController = !(MistressID == MasterBuilder);
                mistressQuery = llRequestDisplayName(MistressID);
            }
            else if (name == "afk") {
                afk = (integer)value;
                setWindRate();
            }
        }

        else if (num == 305) {
            list split = llParseString2List(data, [ "|" ], []);
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llList2List(split, 2, -1);

            if (cmd == "setAFK") {
                afk = llList2Integer(split, 0);
                integer autoSet = llList2Integer(split, 1);
                setWindRate();

                if (!autoSet) {
                    integer agentInfo = llGetAgentInfo(dollID);
                    if ((agentInfo & AGENT_AWAY) && afk) autoAFK = 1;
                    else if (!(agentInfo & AGENT_AWAY) && !afk) autoAFK = 1;
                    else autoAFK = 0;
                }

                ifPermissions();
            }
            else if (cmd == "carry") {
                string name = llList2String(split, 0);
                carry(name, id);
            }
            else if (cmd == "uncarry") {
                uncarry();
            }
        }

        else if (num == 350) {
            RLVok = llList2Integer(parameterList, 0);
            rlvAPIversion = llList2String(parameterList, 1);

            dollID == llGetOwner();
        }
        else if (num == 500) {
            string choice = llList2String(parameterList, 0);
            string name = llList2String(parameterList, 1);

            if (choice == "Wind") doWind(name, id);
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

            // Normal user commands
            if (choice == "detach") {
                if (detachable) {
                    llMessageLinked(LINK_SET, 305, llGetScriptName() + "|" + "detach", NULL_KEY);
                }
                else {
                    llOwnerSay("Key can't be detached...");
                }
            }
            else if (choice == "help") {
                llOwnerSay("%TEXT_HELP%");
            }
            else if (llGetSubString(choice,0,8) == "channel") {
                string c = llStringTrim(llGetSubString(choice,9,llStringLength(choice) - 1),STRING_TRIM);
                if ((string) ((integer) c) == c) {
                    integer ch = (integer) c;
                    if (ch != 0 && ch != DEBUG_CHANNEL) {
                        chatChannel = ch;
                        llListenRemove(chatHandle);
                        chatHandle = llListen(ch, "", llGetOwner(), "");
                    }
                }
            }
            // Demo: short time span
            else if (choice == "demo") {
                if (demoMode == 0) {
                    keyLimit = demoLimit;   // 5 minutes
                    if (timeLeftOnKey > keyLimit) timeLeftOnKey = keyLimit;
                    demoMode = 1;
                    llOwnerSay("Key set to run in demo mode: time limit set to 5 minutes.");
                } else {
                    // Note that the LIMIT is restored.... but the time left on key is unchanged
                    keyLimit = defLimit; // restore default
                    demoMode = 0;
                    llOwnerSay("Key set to run normally: time limit set to " + (string)llRound(defLimit/60) + " minutes.");
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

                    if (thisPose == ANIMATION_COLLAPSED || llGetSubString(thisPose,1,1) == ".") { // flag posed
                        // nothing
                    }
                    else {
                        if (currentAnimation == thisPose) {
                            llOwnerSay("\t*\t" + thisPose);
                        }
                        else {
                            llOwnerSay("\t\t" + thisPose);
                        }
                    }
                }
            }
            else if (choice == "wind") {
                // Give this a time limit: can only be done once
                // in - say - 6 hours... at least maxwindtime *2 or *3.

                if (lastEmergencyTime == 0 ||
                    (llGetTime() - lastEmergencyTime > emergencyLimitTime)) {

                    if (collapsed) {
                        if (hasController)
                            llMessageLinked(LINK_SET, 11, dollName + " has activated the emergency winder.", MistressID);

                        windKey();
                        lastEmergencyTime = llGetTime();

                        uncollapse();

                        llOwnerSay("Emergency self-winder has been triggered by Doll.");
                        llOwnerSay("Emergency circuitry requires recharging and will be available again in " + (string)emergencyLimitHours + " hours.");
                    } else {
                        llOwnerSay("No emergency exists - emergency self-winder deactivated.");
                    }
                } else {
                   llOwnerSay("Emergency self-winder is not yet recharged.");
                }
            }
            else if (choice == "xstats") {
                llOwnerSay("AFK time factor: " + formatFloat(0.5, 1) + "x");
                llOwnerSay("Wind amount: " + (string)llRound((windamount)/60) + " minutes.");

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

                if (!windDown) {
                    llOwnerSay("Key is not winding down.");
                }

            }
            else if (choice == "stat") {
                float p = timeLeftOnKey * 100.0 / keyLimit;

                string s = "Time: " + (string)llRound((timeLeftOnKey)/60) + "/" +
                            (string)llRound((keyLimit)/60) + " min (" + formatFloat(p, 2) + "% capacity)";
                if (afk) {
                    s += " (current wind rate " + formatFloat(setWindRate(), 1) + "x)";
                }
                llOwnerSay(s);
            }
            else if (choice == "stats") {
                setWindRate();
                llOwnerSay("Time remaining: " + (string)llRound((timeLeftOnKey)/60) + " minutes of " +
                            (string)llRound((keyLimit)/60) + " minutes.");
                if (windRate < 1.0) {
                    llOwnerSay("Key is unwinding at a slowed rate of " + formatFloat(windRate, 1) + "x.");
                } else if (windRate > 1.0) {
                    llOwnerSay("Key is unwinding at an accelerated rate of " + formatFloat(windRate, 1) + "x.");
                }

                if (hasController) {
                    llOwnerSay("Controller: " + mistressName);
                }
                else {
                    llOwnerSay("Controller: none");
                }

                if (posed) {
                //    llOwnerSay(dollID, "Current posed: " + currentAnimation);
                //    llOwnerSay(dollID, "Pose time remaining: " + (string)(posedtime / ticks) + " minutes.");
                    llOwnerSay("Doll is posed.");
                }

                llMessageLinked(LINK_SET, 135, llGetScriptName(), NULL_KEY);
            }
        }
    }

    //----------------------------------------
    // RUN_TIME_PERMISSIONS
    //----------------------------------------
    run_time_permissions(integer perm) {
        ifPermissions();
    }
}
