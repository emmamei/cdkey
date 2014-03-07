#include "include/GlobalDefines.lsl"

key keyHandler              = NULL_KEY;

float windRate              = 1.0;
float displayWindRate       = 1.0;
float collapseTime          = 0.0;
float currentLimit          = 10800.0;
float wearLockExpire        = 0.0;

string dollGender           = "Female";

integer autoAFK             = 1;
integer broadcastOn         = -1873418555;
integer broadcastHandle     = 0;
integer busyIsAway          = 0;
integer chatChannel         = 75;
integer chatHandle          = 0;
#ifdef DEVELOPER_MODE
integer timeReporting       = 0;
integer debugLevel          = DEBUG_LEVEL;
#endif

default
{
    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        broadcastHandle = llListen(broadcastOn, "", "", "");
        chatHandle = llListen(chatChannel, "", dollID, "");
    }
    
    link_message(integer source, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);
        string script = llList2String(split, 0);
        split = llDeleteSubList(split, 0, 0);

        if (code == 135) {
            float delay = llList2Float(split, 0);
            scaleMem();
            memReport(delay);
        }

        else if (code == 300) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);
            split = llDeleteSubList(split, 0, 0);

                 if (name == "afk")                               afk = (integer)value;
            else if (name == "autoAFK")                       autoAFK = (integer)value;
            else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "canAFK")                         canAFK = (integer)value;
            else if (name == "canCarry")                     canCarry = (integer)value;
            else if (name == "canDress")                     canDress = (integer)value;
            else if (name == "canFly")                         canFly = (integer)value;
            else if (name == "canSit")                         canSit = (integer)value;
            else if (name == "canStand")                     canStand = (integer)value;
            else if (name == "canRepeat")                   canRepeat = (integer)value;
            else if (name == "configured")                 configured = (integer)value;
            else if (name == "detachable")                 detachable = (integer)value;
            else if (name == "helpless")                     helpless = (integer)value;
            else if (name == "pleasureDoll")             pleasureDoll = (integer)value;
            else if (name == "isVisible")                     visible = (integer)value;
            else if (name == "busyIsAway")                 busyIsAway = (integer)value;
            else if (name == "quiet")                           quiet = (integer)value;
            else if (name == "wearLockExpire")         wearLockExpire = (float)value;
            else if (name == "windRate")                     windRate = (float)value;
            else if (name == "displayWindRate")       displayWindRate = (float)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
            else if (name == "collapseTime")             collapseTime = (float)value;
            else if (name == "keyAnimation")             keyAnimation = value;
            else if (name == "dollType")                     dollType = value;
            else if (name == "dollGender")                 dollGender = value;
            else if (name == "poserID")                       poserID = (key)value;
            else if (name == "poserName")                   poserName = value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                 debugLevel = (integer)value;
            else if (name == "timeReporting")           timeReporting = (integer)value;
#endif
            else if ((name == "timeLeftOnKey") || (name == "collapsed")) {
                if (name == "timeLeftOnKey")            timeLeftOnKey = (float)value;
                if (name == "collapsed")                    collapsed = (integer)value;
            }
            else if (name == "keyHandler") {
                keyHandler = (key)value;
            }
            else if (name == "keyLimit") {
                keyLimit = (float)value;
                if (!demoMode) currentLimit = keyLimit;
            }
            else if (name == "demoMode") {
                demoMode = (integer)value;
                if (!demoMode) currentLimit = keyLimit;
                else currentLimit = DEMO_LIMIT;
            }
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
                    string mode = "normally";
                    if (demoMode) {
                        mode = "demo mode";
                        if (timeLeftOnKey > DEMO_LIMIT) timeLeftOnKey = DEMO_LIMIT;
                    }
                    llOwnerSay("Key set to run " + mode + ": time limit set to " + (string)llRound(currentLimit / SEC_TO_MIN) + " minutes.");
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
                    llOwnerSay("Wind amount: " + (string)llRound(windamount / (SEC_TO_MIN * displayWindRate)) + " minutes.");

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
                    float t1 = timeLeftOnKey / (SEC_TO_MIN * displayWindRate);
                    float t2 = currentLimit / (SEC_TO_MIN * displayWindRate);
                    float p = t1 * 100.0 / t2;

                    string s = "Time: " + (string)llRound(t1) + "/" +
                                (string)llRound(t2) + " min (" + formatFloat(p, 2) + "% capacity)";
                    if (afk) {
                        s += " (current wind rate " + formatFloat(displayWindRate, 1) + "x)";
                    }
                    llOwnerSay(s);
                }
                else if (choice == "stats") {
                    displayWindRate;
                    llOwnerSay("Time remaining: " + (string)llRound(timeLeftOnKey / (SEC_TO_MIN * displayWindRate)) + " minutes of " +
                                (string)llRound(currentLimit / (SEC_TO_MIN * displayWindRate)) + " minutes.");
                    string msg = "Key is";
                    if (windRate == 0.0) msg += " stopped.";
                    else {
                        msg = "Key is unwinding at a";
                        if (windRate < 1.0) msg += " slowed rate";
                        else if (windRate == 1.0) msg += " normal rate";
                        else msg += " accelerated rate";
                        msg += " of " + formatFloat(windRate, 1) + "x.";
                    }
                    llOwnerSay(msg);

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
                            chatHandle = llListen(ch, "", llGetOwner(), "");
                        }
                    }
                }
                else if (choice == "controller") {
                    lmInternalCommand("getMistressKey", param, NULL_KEY);
                }
                else if (choice == "blacklist") {
                    lmInternalCommand("getBlacklistKey", param, NULL_KEY);
                }
                else if (choice == "unblacklist") {
                    lmInternalCommand("getBlacklistKey", param, NULL_KEY);
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
}
