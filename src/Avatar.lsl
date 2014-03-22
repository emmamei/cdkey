//========================================
// Avatar.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 28 February 2014

#include "include/GlobalDefines.lsl"
#include "include/Json.lsl"

//#define DEBUG_BADRLV

key carrierID = NULL_KEY;

key rlvTPrequest;
key requestLoadData;
key keyAnimationID;
key lastAttachedID;

list rlvSources;
list rlvStatus;

float baseWindRate;
float afkSlowWalkSpeed = 5;
float animRefreshRate = 8.0;

float nextRLVcheck;
float nextAnimRefresh;

vector carrierPos;
vector lockPos;

string barefeet;
string carrierName;
string keyAnimation;
string myPath;
string pronounHerDoll = "Her";
string pronounSheDoll = "She";
string rlvAPIversion;
string redirchan;
string userBaseRLVcmd;

integer afk;
integer carryMoved;
integer rlvChannel;
integer clearAnim = 1;
integer collapsed;
integer confgured;
integer dialogChannel;
integer haveControls;
integer listenHandle;
integer locked;
integer lowScriptMode;
integer poseSilence;
integer refreshControls;
integer RLVck = 0;
integer RLVrecheck;
integer RLVok;
integer RLVstarted;
integer startup = 1;
integer targetHandle;
integer ticks;
integer timerOn;
integer wearLock;
integer newAttach = 1;
integer creatorNoteDone;
integer chatChannel = 75;

integer dollState;
#define cdXorSet(a,b,c)         a = ((a ^ (a & b)) | (c))
#define cdXorSetDollState(a,b)  cdXorSet(dollState,a,b)
#define cdSetDollState(a)       cdXorSetDollState(a,a)
#define cdUnsetDollState(a)     cdXorSetDollState(a,0)
#define cdSetDollStateIf(a,b)   cdXorSet(dollState,a,a*((b)!=0))
#define DOLL_AFK                0x01
#define DOLL_ANIMATED           0x02
#define DOLL_CARRIED            0x04
#define DOLL_COLLAPSED          0x08
#define DOLL_POSED              0x10
#define DOLL_POSER_IS_SELF      0x20

//========================================
// FUNCTIONS
//========================================
key animStart(string animation) {
    if ((llGetPermissionsKey() != dollID) || ((llGetPermissions() & PERMISSION_TRIGGER_ANIMATION) == 0)) return NULL_KEY;

    while (llGetListLength(llGetAnimationList(dollID))) llStopAnimation(llList2Key(llGetAnimationList(dollID), 0));

    integer i; key animID = llGetInventoryKey(animation);
    list oldList = llGetAnimationList(dollID);
    llStartAnimation(animation);
    list newList = llGetAnimationList(dollID);

    while (llGetListLength(oldList)) {
        key animKey = llList2Key(oldList, 0); integer index;
        while ((index = llListFindList(newList, [ animKey ])) != -1) newList = llDeleteSubList(newList, index, index);

        oldList = llDeleteSubList(oldList, 0, 0);
    }

    if (animID) return animID;
    else if (llGetListLength(newList) == 1) return llList2Key(newList, 0);
    else return NULL_KEY;
}
//----------------------------------------
// RLV Initialization Functions
//----------------------------------------
checkRLV()
{ // Run RLV viewer check
    locked = 0;
    
    if (!dialogChannel) {
        cdLinkMessage(LINK_THIS, 0, 303, "dialogChannel", llGetKey());
        return;
    }
    
#ifdef DEVELOPER_MODE
    RLVok = ((rlvAPIversion != "") && (myPath != ""));
#else
    RLVok = (rlvAPIversion != "");
#endif
    
    if ((RLVok != 1) && (RLVck < 5)) {
        // Setting the above debug flag causes the listener to not be open for the check
        // In effect the same as the viewer having no RLV support as no reply will be heard
        // all other code works as normal.
#ifdef DEBUG_BADRLV
#define LISTEN_OPEN 0
#else
#define LISTEN_OPEN 1
#endif
        if (RLVck <= 0) {
            RLVck = 1;
            cdWakeScript("StatusRLV");
            cdWakeScript("Transform");
        }
        else RLVck++;
        
        llListenControl(listenHandle, LISTEN_OPEN);
        if (rlvAPIversion == "") llOwnerSay("@versionnew=" + (string)rlvChannel);
#ifdef DEVELOPER_MODE
        else if (myPath == "") llOwnerSay("@getpathnew=" + (string)rlvChannel);
#endif
        llSetTimerEvent(20.0);
        nextRLVcheck = llGetTime() + 20.0;
    }
    else {
        if (!RLVstarted && !RLVrecheck) {
            if (RLVok) llOwnerSay("Reattached Community Doll Key with " + rlvAPIversion + " active...");
            else if (cdAttached() && !RLVok) llOwnerSay("Did not detect an RLV capable viewer, RLV features disabled.");
        }
    
#ifdef DEVELOPER_MODE
        if ((rlvAPIversion != "") && (myPath == "")) { // Dont enable RLV on devs if @getpath is returning no usable result to avoid lockouts.
            llSay(DEBUG_CHANNEL, "WARNING: Sanity check failure developer key not found in #RLV see README.dev for more information.");
            return;
        }
#endif

        if (cdAttached()) cdLoadData(RLV_NC, RLV_BASE_RESTRICTIONS);
    }
}

ifPermissions() {
    if (cdAttached()) {
        key grantorID = llGetPermissionsKey();
        integer permMask = llGetPermissions();

        if (grantorID != NULL_KEY && grantorID != dollID) {
            llResetOtherScript("Start");
            llSleep(10.0);
        }

        if ((permMask & PERMISSION_MASK) != PERMISSION_MASK)
            llRequestPermissions(dollID, PERMISSION_MASK);

        if (grantorID == dollID) {
            if ((permMask & PERMISSION_TRIGGER_ANIMATION) != 0) {
                key curAnim = llList2Key(llGetAnimationList(dollID), 0);
                
                if (!clearAnim && !cdNoAnim()) {
                    llWhisper(LOCKMEISTER_CHANNEL, (string)dollID + "bootoff");

                    list animList; integer i; integer animCount;
                    key animKey = keyAnimationID;
                    if (animKey == NULL_KEY) animKey = llGetInventoryKey(keyAnimation);
                    if (animKey) {
                        while ((animList = llGetAnimationList(dollID)) != [ animKey ]) {
                            animCount = llGetListLength(animList);
                            for (i = 0; i < animCount; i++) {
                                if (llList2Key(animList, i) != animKey) llStopAnimation(llList2Key(animList, i));
                            }
                            llStartAnimation(keyAnimation);
                        }
                    }
                    else animKey = animStart(keyAnimation);
                    if ((keyAnimationID == NULL_KEY) && (animKey != NULL_KEY)) lmSendConfig("keyAnimationID", (string)(keyAnimationID = animKey));
                    
                    if (keyAnimationID) {
                        debugSay(7, "DEBUG", "animID=" + (string)keyAnimationID + " curAnim=" + (string)curAnim + " animRefreshRate=" + (string)animRefreshRate);
                        if (keyAnimationID == NULL_KEY) animRefreshRate = 4.0;          // In case anim is no mod use default 4 sec
                        else if (curAnim == keyAnimationID) {
                            animRefreshRate += (1.0/llGetRegionFPS());                  // +1 Frame
                            if (animRefreshRate > 30.0) animRefreshRate = 30.0;             // 30 Second limit
                        }
                        else if (curAnim != keyAnimationID) {
                            animRefreshRate /= 2.0;                                     // -50%
                            if (animRefreshRate < 0.022) animRefreshRate = 0.022;           // Limit once per frame
                        }
                    }
                    else if (keyAnimation != "") animRefreshRate = 4.0;
                } else if (clearAnim) {
                    list animList = llGetAnimationList(dollID);
                    integer i; integer animCount = llGetListLength(animList);
                    keyAnimation = "";
                    lmSendConfig("keyAnimationID", (string)(keyAnimationID = NULL_KEY));
                    for (i = 0; i < animCount; i++) {
                        key animKey = llList2Key(animList, i);
                        if (animKey != NULL_KEY) llStopAnimation(animKey);
                    }
                    llStartAnimation("Stand");
                    animRefreshRate = 0.0;
                    clearAnim = 0;
                    llWhisper(LOCKMEISTER_CHANNEL, (string)dollID + "booton");
                }
                
                if (animRefreshRate) nextAnimRefresh = llGetTime() + animRefreshRate;
            }

            if (permMask & PERMISSION_TAKE_CONTROLS) {
                if (!haveControls && ((dollState & (DOLL_AFK | DOLL_COLLAPSED | DOLL_POSED)) == 0)) {
                    // No reason for us to be locking the controls and we do not allready have them
                    // This just serves to get us treated as a vehicle to run on no script land
                    llTakeControls(-1, 0, 1);   // Controls is a bitmask not a comparison so -1 is a quick shortcut for all
                                                // on a big endian host.
                }
                else if ((dollState & DOLL_ANIMATED) != 0) {
                    // When collapsed or posed the doll should not be able to move at all so the key will
                    // accept their controls instead no need to pass on.
                    llTakeControls(-1, 1, 0);
                    haveControls = 1;
                }
                else if ((dollState & DOLL_AFK) != 0) {
                    // To slow movement during AFK we do not want to lock the dolls controlls completely we
                    // want to instead instead respond the input so we need ACCEPT=TRUE, PASS_ON=TRUE
                    llTakeControls(-1, 1, 1);
                    haveControls = 1;
                }
                else if (haveControls) {
                    // We don't need to grab the dolls controls but we already have them I have grounds to
                    // suspect there may be a second life bug where taking controls and then trying to let
                    // go to do ACCEPT=FALSE, PASS_ON=TRUE may not allways work reliably release and regrab
                    
                    refreshControls = 1;
                    
                    if ((llGetParcelFlags(llGetPos()) & PARCEL_FLAG_ALLOW_SCRIPTS) != 0) {
                        // We do not want try and llReleaseControls if the land is no script it is not a safe op
                        llReleaseControls();
                        haveControls = 0;
                        refreshControls = 0;
                        llRequestPermissions(dollID, PERMISSION_MASK);  // Releasing controls drops the permissions
                                                                        // get them baack.
                    }
                    else llTakeControls(-1, 0, 1);
                }
            }

            if ((dollState & DOLL_ANIMATED) != 0) {
                if (lockPos == ZERO_VECTOR) lmSendConfig("lockPos", (string)(lockPos = llGetPos()));
                llTargetRemove(targetHandle);
                targetHandle = llTarget(lockPos, 1.0);
                llMoveToTarget(lockPos, 0.7);
            }
            else if ((dollState & DOLL_CARRIED) != 0) {
                if (lockPos != ZERO_VECTOR) lmSendConfig("lockPos", (string)(lockPos = ZERO_VECTOR));
                llTargetRemove(targetHandle);
                llStopMoveToTarget();
                vector carrierPos = llList2Vector(llGetObjectDetails(carrierID, [ OBJECT_POS ]), 0);
                if (carrierPos != ZERO_VECTOR) targetHandle = llTarget(carrierPos, CARRY_RANGE);
            }
            else {
                llTargetRemove(targetHandle);
                llStopMoveToTarget();
            }
        }
    }
}

default {
    state_entry() {
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);
        
        cdInitializeSeq();

        llRequestPermissions(dollID, PERMISSION_MASK);
    }

    on_rez(integer start) {
        RLVck = 0;
        rlvAPIversion = "";
        myPath = "";
        
        RLVstarted = 0;

        llStopMoveToTarget();
        llTargetRemove(targetHandle);
        
        ifPermissions();
    }

    changed(integer change) {
        if (change & (CHANGED_REGION | CHANGED_TELEPORT)) {
            llStopMoveToTarget();
            llTargetRemove(targetHandle);
            
            ifPermissions();
        }
        if (change & CHANGED_OWNER) {
            llStopMoveToTarget();
            llTargetRemove(targetHandle);
            
            llResetScript();
        }
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan == rlvChannel) {
            if (llGetSubString(msg, 0, 13) == "RestrainedLove") {
                if (rlvAPIversion == "") debugSay(2, "DEBUG-RLV", "RLV Version: " + msg);
                rlvAPIversion = msg;
            }
            else {
                if (myPath == "") debugSay(2, "DEBUG-RLV", "RLV Key Path: " + msg);
                myPath = msg;
            }
            checkRLV();
        }
    }

    attach(key id) {
        if (id == NULL_KEY && !detachable && !locked) {
            // Undetachable key with controller is detached while RLV lock
            // is not available inform any key controllers.
            // We send no message if the key is RLV locked as RLV will reattach
            // automatically this prevents neusance messages when defaultwear is
            // permitted.
            // Q: Should that be changed? Not sure the message serves much purpose with *verified* RLV and known lock.
            lmSendToController(dollName + " has bypassed the key attachment lock and removed " + llToLower(pronounHerDoll) + " key. Appropriate authorities have been notified of this breach of security.");
        }

        locked = 0;


        llStopMoveToTarget();
        llTargetRemove(targetHandle);

        if (id) {
            ifPermissions();
            RLVck = 0;
            rlvAPIversion = "";
            myPath = "";
        }

        newAttach = (lastAttachedID != dollID);
        lastAttachedID = id;
    }

    link_message(integer sender, integer i, string data, key id) {
        
        // Parse link message header information
        list split        =     cdSplitArgs(data);
        string script     =     cdListElement(split, 0);
        integer remoteSeq =     (i & 0xFFFF0000) >> 16;
        integer optHeader =     (i & 0x00000C00) >> 10;
        integer code      =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);
        
        scaleMem();

        if (code == 110) {
            configured = 1;
            checkRLV();
            ifPermissions();
            return;
        }
        else if (code == 135) {
            float delay = llList2Float(split, 0);
            memReport(cdMyScriptName(),delay);
            return;
        }
        
        cdConfigReport();
        
        else if (code == 300) {
            string name = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);
            string value = llList2String(split, 0);
            
            if (value == RECORD_DELETE) {
                value = "";
                split = [];
            }

// CHANGED_OTHER bit used to indicate changes of RLV status that
// would not normally be reflected as a doll state.
#define CHANGED_OTHER 0x80000000

            integer oldState = dollState;              // Used to determine if a refresh of RLV state is needed

            if (name == "autoTP") {
                if (autoTP != (integer)value) {
                     autoTP = (integer)value;
                     oldState = oldState | CHANGED_OTHER;
                }
            }
            else if (name == "carrierID") {
                carrierID = (key)value;
                cdSetDollStateIf(DOLL_CARRIED, (carrierID != NULL_KEY));
            }
            else if (name == "afk") {
                afk = (integer)value;
                cdSetDollStateIf(DOLL_AFK, afk);
            }
            else if (name == "canFly") {
                if (canFly != (integer)value) {
                    canFly = (integer)value;
                    oldState = oldState | CHANGED_OTHER;
                }
            }
            else if (name == "canSit") {
                if (canSit != (integer)value) {
                    canSit = (integer)value;
                    oldState = oldState | CHANGED_OTHER;
                }
            }
            else if (name == "canStand") {
                if (canStand != (integer)value) {
                    canStand = (integer)value;
                    oldState = oldState | CHANGED_OTHER;
                }
            }
            else if (name == "canDressSelf") {
                if (canDressSelf != (integer)value) {
                    canDressSelf = (integer)value;
                    oldState = oldState | CHANGED_OTHER;
                }
            }
            else if (name == "collapsed") {
                    collapsed = (integer)value;
                    cdSetDollStateIf(DOLL_COLLAPSED, collapsed);
                    if (collapsed) lmSendConfig("keyAnimation", (keyAnimation = ANIMATION_COLLAPSED));
                    else if (cdCollapsedAnim()) lmSendConfig("keyAnimation", (keyAnimation = ""));
            }
            else if (name == "tpLureOnly") {
                if (tpLureOnly != (integer)value) {
                    tpLureOnly = (integer)value;
                    oldState = oldState | CHANGED_OTHER;
                }
            }
            else if (name == "poseSilence") {
                if (poseSilence != (integer)value) {
                    poseSilence = (integer)value;
                    oldState = oldState | CHANGED_OTHER;
                }
            }
            else if (name == "userBaseRLVcmd") {
                if (userBaseRLVcmd == "") userBaseRLVcmd = value;
                else userBaseRLVcmd += "," +value;
            }
            else if (name == "keyAnimation") {
                string oldanim = keyAnimation;
                keyAnimation = value;
                if (cdCollapsedAnim() && ((dollState & DOLL_COLLAPSED) == 0)) {
                    lmSendConfig("keyAnimation", "");
                }
                
                cdSetDollStateIf(DOLL_ANIMATED, (keyAnimation != ""));
                cdSetDollStateIf(DOLL_POSED, ((dollState & (DOLL_COLLAPSED | DOLL_ANIMATED)) == DOLL_ANIMATED));
                cdSetDollStateIf(DOLL_POSER_IS_SELF, (((dollState & DOLL_POSED) == 1) && (poserID == dollID)));

                if          cdNoAnim()                                          clearAnim = 1;
                else if     ((oldanim != "") && (keyAnimation != oldanim)) {    // Issue #139 Moving directly from one animation to another make certain keyAnimationID does not holdover to the new animation.
                                                                                keyAnimationID = NULL_KEY;
                                                                                lmSendConfig("keyAnimationID",      (string)(keyAnimationID = animStart(keyAnimation)));
                }
                else                                                            lmSendConfig("keyAnimationID",      (string)(keyAnimationID = animStart(keyAnimation)));
            }
            else if (name == "poserID") {
                poserID = (key)value;
                cdSetDollStateIf(DOLL_POSER_IS_SELF, (((dollState & DOLL_POSED) == 1) && (poserID == dollID)));
            }
            else {
                     if (name == "detachable")               detachable = (integer)value;
#ifdef DEVELOPER_MODE
                else if (name == "debugLevel")               debugLevel = (integer)value;
#endif
                else if (name == "lowScriptMode")         lowScriptMode = (integer)value;
                else if (name == "quiet")                         quiet = (integer)value;
                else if (name == "chatChannel")             chatChannel = (integer)value;
                else if (name == "canPose")                     canPose = (integer)value;
                else if (name == "barefeet")                   barefeet = value;
                else if (name == "dollType")                   dollType = value;
                else if (name == "controllers")           controllers = split;
                else if (name == "pronounHerDoll")       pronounHerDoll = value;
                else if (name == "pronounSheDoll")       pronounSheDoll = value;
                else if (name == "dialogChannel") {
                    dialogChannel = (integer)value;
                    llListenRemove(listenHandle);
                    // Calculate positive (RLV compatible) rlvChannel
                    rlvChannel = ~dialogChannel + 1;
                    listenHandle = llListen(rlvChannel, "", "", "");
                    llListenControl(listenHandle, 0);
                }
                else if (name == "keyAnimationID") {
                    keyAnimationID = (key)value;
                }
                
                return;
            }
            
            if (dollState != oldState) {
                ifPermissions();
                if (RLVstarted) cdLoadData(RLV_NC, RLV_BASE_RESTRICTIONS);
            }
        }
        else if (code == 305) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "detach") {
                if (RLVok || RLVstarted) llOwnerSay("@clear,detachme=force");
                else llDetachFromAvatar();
                return;
            }
            else if (cmd == "TP") {
                string lm = llList2String(split, 0);
                llRegionSayTo(id, 0, "Teleporting dolly " + dollName + " to  landmark " + lm + ".");
                rlvTPrequest = llRequestInventoryData(lm);
                return;
            }
            else if (cmd == "wearLock") lmSendConfig("wearLock", (string)(wearLock = llList2Integer(split, 0)));
            else return;
        }
        else if (code == 500) {
            string choice = llList2String(split, 0);
            string name = llList2String(split, 1);
            
            if (choice == "*RLV On*") {
                llOwnerSay("Trying to enable RLV, you must have a compatible viewer and the RLV setting enabled for this to work.");
                checkRLV();
            }
#ifdef ADULT_MODE
            else if ((llGetSubString(choice,0,4) == "Strip") || (choice == "Strip ALL")) {
                if (choice == "Strip...") {
                    list buttons = llListSort(["Strip Top", "Strip Bra", "Strip Bottom", "Strip Panties", "Strip Shoes", "Strip ALL"], 1, 1);
                    llDialog(id, "Take off:", dialogSort(buttons + MAIN), dialogChannel); // Do strip menu
                    return;
                }
                
                string part = llGetSubString(choice,6,-1);
                list parts = [
                    "Top",      RLV_STRIP_TOP,
                    "Bra",      RLV_STRIP_BRA,
                    "Bottom",   RLV_STRIP_BOTTOM,
                    "panties",  RLV_STRIP_PANTIES,
                    "Shoes",    RLV_STRIP_SHOES
                ];
                integer i;
                if ( ( i = llListFindList(parts, [part]) ) != -1) {
                    cdLoadData(RLV_NC, llList2Integer(parts, i));
                } else if (part = "*ALL*") {
                    for (i = 0; i < 10; i++) {
                        cdLoadData(RLV_NC, llList2Integer(parts, i++));
                    }
                }
                if ((part == "Shoes") || (choice == "Strip ALL")) {
                    if (barefeet != "") lmRunRLVas("Dress","attachallover:" + barefeet + "=force");
                }
            }
#endif
            else if (choice == "Carry") {
                if (!collapsed && !cdIsDoll(id) && (cdControllerCount() || cdIsController(id))) {
                    lmSendConfig("carrierID", (string)(carrierID = id));
                    lmSendConfig("carrierName", (carrierName = name));
                    if (!quiet) llSay(0, "The doll " + dollName + " has been picked up by " + carrierName);
                    else {
                        llOwnerSay("You have been picked up by " + carrierName);
                        llRegionSayTo(carrierID, 0, "You have picked up the doll " + dollName);
                    }
                }
            }
            else if (choice == "Uncarry") {
                if (cdIsCarrier(id)) {
                    if (quiet) lmSendToAgent("You were carrying " + dollName + " and have now placed them down.", carrierID);
                    else llSay(0, "Dolly " + dollName + " has been placed down by " + carrierName);
                    lmSendConfig("carrierID", (string)(carrierID = NULL_KEY));
                    lmSendConfig("carrierName", (carrierName = ""));
                }
            }
            else if (((!cdIsDoll(id) && canPose) || cdSelfPosed()) && choice == "Unpose") {
                lmSendConfig("keyAnimation", (string)(keyAnimation = ""));
                lmSendConfig("poserID", (string)(poserID = NULL_KEY));
            }
            else if ((keyAnimation == "" || ((!cdIsDoll(id) && canPose) || cdSelfPosed())) && llGetInventoryType(choice) == 20) {
                lmSendConfig("keyAnimation", (string)(keyAnimation = choice));
                lmSendConfig("poserID", (string)(poserID = id));
            }
            else if ((keyAnimation == "" || ((!cdIsDoll(id) && canPose) || cdSelfPosed())) && llGetInventoryType(llGetSubString(choice, 2, -1)) == 20) {
                lmSendConfig("keyAnimation", (string)(keyAnimation = llGetSubString(choice, 2, -1)));
                lmSendConfig("poserID", (string)(poserID = id));
            }
            else if (llGetSubString(choice, 0, 4) == "Poses" && (keyAnimation == ""  || ((!cdIsDoll(id) && canPose) || poserID == dollID))) {
                poserID = id;
                integer page = (integer)llStringTrim(llGetSubString(choice, 5, -1), STRING_TRIM);
                if (!page) {
                    page = 1;
                    llOwnerSay("secondlife:///app/agent/" + (string)id + "/about is looking at your poses menu.");
                }
                integer poseCount = llGetInventoryNumber(20);
                list poseList; integer i;

                for (i = 0; i < poseCount; i++) {
                    string poseName = llGetInventoryName(20, i);
                    if (poseName != ANIMATION_COLLAPSED &&
                        ((cdIsDoll(id) || cdIsController(id)) || llGetSubString(poseName, 0, 0) != "!") &&
                        (cdIsDoll(id) || llGetSubString(poseName, 0, 0) != ".")) {
                        if (poseName != keyAnimation) poseList += poseName;
                        else poseList += [ "* " + poseName ];
                    }
                }
                poseCount = llGetListLength(poseList);
                integer pages = 1;
                if (poseCount > 11) pages = llCeil((float)poseCount / 9.0);
                if (poseCount > 11) {
                    poseList = llList2List(poseList, (page - 1) * 9, page * 9 - 1);
                    integer prevPage = page - 1;
                    integer nextPage = page + 1;
                    if (prevPage == 0) prevPage = 1;
                    if (nextPage > pages) nextPage = pages;
                    poseList = [ "Poses " + (string)prevPage, "Poses " + (string)nextPage, MAIN ] + poseList;
                }
                else poseList = dialogSort(poseList + [ MAIN ]);

                llDialog(id, "Select the pose to put the doll into", poseList, dialogChannel);
            }
        }
        else return;
        
        ifPermissions();
    }

    timer() {
        if ((nextRLVcheck != 0.0) && (nextRLVcheck < llGetTime())) {
            checkRLV();
        }
        
        ifPermissions();
        
        list possibleEvents =       [60.0];
        if (nextRLVcheck > 0.0)     possibleEvents += nextRLVcheck - llGetTime();
        if (nextAnimRefresh > 0.0)  possibleEvents += nextAnimRefresh - llGetTime();
        llSetTimerEvent(llListStatistics(LIST_STAT_MIN,possibleEvents) + 0.022); // Not 0
    }

    //----------------------------------------
    // AT FOLLOW/MOVELOCK TARGET
    //----------------------------------------
    at_target(integer num, vector target, vector me) {
        // Clear old targets to ensure there is only one
        llTargetRemove(targetHandle);
        llStopMoveToTarget();

        if (cdCarried()) {
            if (keyAnimation == "") {
                // Get updated position and set target
                carrierPos = llList2Vector(llGetObjectDetails(carrierID, [OBJECT_POS]), 0);
                targetHandle = llTarget(carrierPos, CARRY_RANGE);
            }
            else {
                if (lockPos != ZERO_VECTOR) lockPos = llGetPos();
                targetHandle = llTarget(lockPos, 0.5);
            }
        }

        if (carryMoved) {
            vector pointTo = target - llGetPos();
            float  turnAngle = llAtan2(pointTo.x, pointTo.y);
            lmRunRLV("setrot:" + (string)(turnAngle) + "=force");
            carryMoved = 0;
        }
    }

    //----------------------------------------
    // NOT AT FOLLOW/MOVELOCK TARGET
    //----------------------------------------
    not_at_target() {
        if (cdNoAnim() && cdCarried()) {
            vector newCarrierPos = llList2Vector(llGetObjectDetails(carrierID,[OBJECT_POS]),0);
            llStopMoveToTarget();

            if (carrierPos != newCarrierPos) {
                llTargetRemove(targetHandle);
                carrierPos = newCarrierPos;
                targetHandle = llTarget(carrierPos, CARRY_RANGE);
            }
            if (carrierPos != ZERO_VECTOR) {
                llMoveToTarget(carrierPos, 0.7);
                carryMoved = 1;
            }
        }
        else if (!cdNoAnim()) {
            llMoveToTarget(lockPos, 0.7);
        }
    }

    //----------------------------------------
    // CONTROL
    //----------------------------------------
    // Control event allows us to respond to control inputs made by the
    // avatar which has granted the script PERMISSION_TAKE_CONTROLS.
    //
    // In our case it is used here with physics calls to slow movement for
    // a doll when in AFK mode.  This will work regardless of whether the
    // doll is in RLV or not though RLV is a bonus as it allows preventing
    // running.
    control(key id, integer level, integer edge) { // Event params are key avatar id, integer level representing keys currently held and integer edge
                                                   // representing keys which have been pressed or released in this period (Since last control event).
        if (!(llGetAgentInfo(llGetOwner())&AGENT_WALKING)) {
            llApplyImpulse(<0, 0, 0>, TRUE);
        }
        else {
            if (afk && (keyAnimation == "")  && (id == dollID)) {
                if (level & ~edge & CONTROL_FWD) llApplyImpulse(<-1, 0, 0> * afkSlowWalkSpeed, TRUE);
                if (level & ~edge & CONTROL_BACK) llApplyImpulse(<1, 0, 0> * afkSlowWalkSpeed, TRUE);
            }
        }
    }

    dataserver(key request, string data) {
        if (request == rlvTPrequest) {
            vector global = llGetRegionCorner() + (vector)data;

            string locx = (string)llFloor(global.x);
            string locy = (string)llFloor(global.y);
            string locz = (string)llFloor(global.z);

            llOwnerSay("Dolly is now teleporting.");

            lmRunRLVas("TP", "tpto:" + locx + "/" + locy + "/" + locz + "=force");
        }
        if (request == requestLoadData) {
            integer dataType = (integer)cdGetValue(data, [0]);

            if (dataType == RLV_STRIP) {
                string part = cdGetValue(data, [1]);
                string value; integer i;
                while ( ( value = cdGetValue(data, ([2,"attachments",i++])) ) != JSON_INVALID ) lmRunRLV("remattach:" + value + "=force");
                i = 0;
                while ( ( value = cdGetValue(data, ([2,"layers",i++])) ) != JSON_INVALID ) lmRunRLV("remoutfit:" + value + "=force");

                if (RLVstarted) cdLoadData(RLV_NC, RLV_BASE_RESTRICTIONS);
            }
            else if (dataType == RLV_RESTRICT) {
                string restrictions;
                integer group = -1; integer setState;
                integer posed = (cdPosed() && (poserID != dollID));
                list states = [ 
                    autoTP,
                    ((dollState & (DOLL_AFK | DOLL_COLLAPSED)) != 0) || !canFly || posed,
                    ((dollState & DOLL_COLLAPSED) != 0),
                    ((dollState & DOLL_COLLAPSED) != 0) || !canSit || posed,
                    ((dollState & DOLL_COLLAPSED) != 0) || !canStand || posed,
                    ((dollState & DOLL_COLLAPSED) != 0) || (posed && poseSilence),
                    ((dollState & (DOLL_AFK | DOLL_CARRIED | DOLL_COLLAPSED)) != 0) || tpLureOnly || posed,
                    ((dollState & (DOLL_AFK | DOLL_CARRIED | DOLL_COLLAPSED)) != 0) || posed,
                    (((dollState & (DOLL_AFK | DOLL_COLLAPSED)) != 0) || !canDressSelf || wearLock) * (~(llGetInventoryCreator("Main") == dollID) + 1)
                ];
                integer index;

                while ( ( index = llSubStringIndex(data, "$C") ) != -1) {
                    if (redirchan == "") redirchan = (string)llRound(llFrand(0x7fffffff));
                    data = llInsertString(llDeleteSubString(data, index, index + 1), index, redirchan);
                }
                
                if (!RLVstarted && RLVok) llOwnerSay("@clear");
                string baseRLV;
                // if Doll is one of the developers... dont lock:
                // prevents inadvertent lock-in during development
#ifndef DEVELOPER_MODE
                // We lock the key on here - but in the menu system, it appears
                // unlocked and detachable: this is because it can be detached
                // via the menu. To make the key truly "undetachable", we get
                // rid of the menu item to unlock it
                if (llGetInventoryCreator("Main") != dollID) {
                    lmRunRLVas("Base", "detach=n,permissive=n");  //locks key
                
                    locked = 1; // Note the locked variable also remains false for developer mode keys
                                // This way controllers are still informed of unauthorized detaching so developer dolls are still accountable
                                // With this is the implicit assumption that controllers of developer dolls will be understanding and accepting of
                                // the occasional necessity of detaching during active development if this proves false we may need to fudge this
                                // in the section below.
                }
                else if (RLVok && !RLVstarted) llSay(DEBUG_CHANNEL, "Backup protection mechanism activated not locking on creator");
#else
                if (RLVok && !RLVstarted) {
                    if (!quiet) llSay(0, "Developer Key not locked.");
                    else llOwnerSay("Developer key not locked.");
                    baseRLV += "attachallthis_except:" + myPath + "=add,detachallthis_except:" + myPath + "=add,";
                }
#endif
    
                if (!RLVstarted) {
                    if (RLVok) llOwnerSay("Enabling RLV mode");
                    else llSetScriptState("StatusRLV", 0);
                    
                    llListenControl(listenHandle, 0);
                    lmRLVreport(RLVok, rlvAPIversion, 0);
                }
            
                if (userBaseRLVcmd != "") lmRunRLVas("User:Base", userBaseRLVcmd);

                //cdRlvSay("@clear=redir");
                string restrictionList;
                while (cdGetElementType(data, ([1,++group])) != JSON_INVALID) {
                    setState = llList2Integer(states, group);
                    cdSetRestrictionsList(data,setState);
                }
                lmRunRLVas("Core", baseRLV + restrictionList + "sendchannel:" + (string)chatChannel + "=rem");
                
                RLVstarted = (RLVstarted | RLVok);

#ifndef DEVELOPER_MODE
                if (llGetInventoryCreator("Main") == dollID) lmRunRLVas("Base", "clear=unshared,clear=achallthis");
#endif
            }
        }
    }

    run_time_permissions(integer perm) {
        ifPermissions();
    }
}
