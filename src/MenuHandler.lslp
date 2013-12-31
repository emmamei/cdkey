// MenuHandler.lsl
//
// vim:sw=4 et nowrap:
//
// DATE: 10 December 2013
#include "include/GlobalDefines.lsl"

// Current Controller - or Mistress
//key MistressID = NULL_KEY;
key carrierID = NULL_KEY;
key poserID = NULL_KEY;
key dollID = NULL_KEY;

key mistressQuery;
integer mistressQueryIndex;

float timeLeftOnKey;
float windRate = 1.0;

integer afk;
integer autoAFK = 1;
integer autoTP;
integer canAFK = 1;
integer canCarry = 1;
integer canDress = 1;
integer canFly = 1;
integer canSit = 1;
integer canStand = 1;
//integer canWear;
//integer canUnwear;
integer carryMoved;
integer clearAnim;
integer collapsed;
integer configured;
integer demoMode;
integer detachable = 1;
integer doWarnings;
integer helpless;
integer pleasureDoll;
integer isTransformingKey;
integer visible = 1;
integer quiet;
integer RLVok;
integer signOn;
integer takeoverAllowed;
integer warned;

integer dialogChannel;
integer dialogHandle;
string dollName;
string dollType = "Regular";

string carrierName;
string mistressName;
#ifdef ADULT_MODE
string simRating;
#endif
string keyAnimation;

doMainMenu(key id) {
    string msg;
    list menu =  ["Wind"];

    // Compute "time remaining" message
    string timeleft;
    // Manual page
    string manpage;

    float displayWindRate = setWindRate();
    integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));
    
    if (minsLeft > 0) {
        timeleft = "Dolly has " + (string)minsLeft + " minutes remaining.\n";

        timeleft += "Key is ";
        if (windRate == 0.0) {
            timeleft += "not ";
        }
        timeleft += "winding down";
        
        if (windRate == 0.0) timeleft += ".";
        else timeleft += " at " + formatFloat(displayWindRate, 1) + "x rate.";

        timeleft += ". ";
    }
    else {
        timeleft = "Dolly has no time left.";
    }
    timeleft += "\n";

    // Can the doll be dressed? Add menu button
    if (canDress) {
        menu += "Dress";
    }

    // Can the doll be transformed? Add menu button
    if (isTransformingKey) {
        menu += "Type of Doll";
    }

    // Is the doll being carried? ...and who clicked?
    if (hasCarrier) {
        // Three possibles:
        //   1. Doll
        //   2. Carrier
        //   3. Someone else

        // Doll being carried clicked on key
        if (id == dollID) {
            msg = "You are being carried by " + carrierName + ".";
            menu = ["OK"];

            // Allows user to permit current carrier to take over and become Mistress
            if ((numControllers < MAX_USER_CONTROLLERS) && !takeoverAllowed) {
                menu += "Allow Takeover";
            }
        }

        // Doll's carrier clicked on key
        else if (id == carrierID) {
            msg = "Place Down frees " + dollName + " when you are done with her";
            menu += ["Place Down","Poses"];
            if (keyAnimation != "") {
                menu += "Unpose";
            }

            if ((numControllers < MAX_USER_CONTROLLERS) && takeoverAllowed) {
                menu += "Be Controller";
            }

#ifdef ADULT_MODE
            // Is doll strippable?
            if ((pleasureDoll || dollType == "Slut") && RLVok && (simRating == "MATURE" || simRating == "ADULT")) {
                menu += "Strip";
            }
#endif
        }

        // Someone else clicked on key
        else {
            msg = dollName + " is currently being carried by " + carrierName + ". They have full control over this doll.\n";
            menu = ["OK"];
        }
    }
    else if (collapsed) {
        if (id == dollID) {
            msg = "You need winding.";
            menu = ["OK"];
        }
    }
    else {    //not  being carried, not collapsed - normal in other words
        // Toucher could be...
        //   1. Doll
        //   2. Someone else

        // Is toucher the Doll?
        if (id == dollID) {
            manpage = "dollkeyselfinfo.htm";
            
            menu = ["Dress","Options"];
#ifdef TESTER_MODE
#ifdef ADULT_MODE
            menu += "Strip";
#endif
            menu += "Wind";
#endif

            if (canAFK) {
                menu += "Toggle AFK";
            }

            if (detachable) {
                menu += "Detach";
            }

            if (visible) {
                menu += "Invisible";
            }
            else {
                menu += "Visible";
            }
            
            if (llGetInventoryType(LANDMARK_HOME) == INVENTORY_LANDMARK) {
               menu += "TP Home";
            }

            if (isTransformingKey) {
                menu += "Type of Doll";
            }
        }
        else {
            manpage = "communitydoll.htm";
        
            // Toucher is not Doll.... could be anyone
            msg =  dollName + " is a doll and likes to be treated like " +
                   "a doll. So feel free to use these options.\n";
        }
               
        menu += "Help/Support";

        // Hide the general "Carry" option for all but Mistress when one exists
        if (isMistress(id) || (numControllers == 0)) {
            if (canCarry) {
                msg =  msg +
                       "Carry option picks up " + dollName + " and temporarily" +
                       " makes the Dolly exclusively yours.\n";

                menu += "Carry";
            }
        }

        if (keyAnimation != "") {
            //msg += "Doll is currently in the " + currentAnimation + " pose. ";
            msg += "Doll is currently posed.\n";
        }

        if (keyAnimation != "" && (id != dollID || poserID == dollID)) menu += "Unpose";

        if (keyAnimation == "" || (id != dollID || poserID == dollID)) menu += "Poses";
    }

    // If toucher is Mistress and NOT self...
    //
    // That is, you can't be your OWN Mistress...
    if (isMistress(id) && (id != dollID)) {
        menu += "Use Control";
        
        if (llGetInventoryType(LANDMARK_HOME) == INVENTORY_LANDMARK) {
            menu += "TP Home";
        }
    }
    
    llListenControl(dialogHandle, 1);
    llSetTimerEvent(60.0);
    
    msg += "See " + WEB_DOMAIN + manpage + " for more information." ;
    llDialog(id, timeleft + msg, menu, dialogChannel);
}

doHelpMenu(key id) {
    string msg = "Here you can find various options to get help with your " +
                "key and to connect with the community.";
    list menu = [ "Join Group", "Visit CD Room", "Reset Scripts", "Issue Tracker" ];
    if (llGetInventoryType(NOTECARD_HELP) == INVENTORY_NOTECARD) menu += "Help Notecard";
    
    llListenControl(dialogHandle, 1);
    llSetTimerEvent(60.0);
    
    llDialog(id, msg, menu, dialogChannel);
}

doOptionsMenu(key id) {    
    string msg = "See " + WEB_DOMAIN + "keychoices.htm for explanation. (" + OPTION_DATE + " version)";
    list pluslist;
    
    llListenControl(dialogHandle, 1);
    llSetTimerEvent(60.0);
    
    if (isController) {
        msg = "See " + WEB_DOMAIN + "controller.htm. Choose what you want to happen. (" + OPTION_DATE + " version)";
        pluslist += "drop control";
    }
    
    if (!canDress) pluslist += "Can Outfit";
    else pluslist += "No Outfitting";

    if (!canCarry) pluslist += "Can Carry";
    else pluslist += "No Carry";

    // One-way option
    if (detachable) pluslist += "No Detaching";
    else if (isController) pluslist += "Detachable";

    if (doWarnings) pluslist += "No Warnings";
    else pluslist += "Warnings";

    // One-way option
    if (canSit) pluslist += "No Sitting";
    else if (isController) pluslist += "Can Sit";
    
    // One-way option
    if (canStand) pluslist += "No Standing";
    else if (isController) pluslist += "Can Stand";

    // One-way option
    if (!autoTP) pluslist += "Auto TP";
    else if (isController) pluslist += "No Auto TP";

    // One-way option
    if (!helpless) pluslist += "No Self TP";
    else if (isController) pluslist += "Self TP";

    // One-way option
    if (canFly) pluslist += "No Flying";
    else if (isController) pluslist += "Can Fly";

#ifdef ADULT_MODE
    if (pleasureDoll) pluslist += "No Pleasure";
    else pluslist += "Pleasure Doll";
#endif

    if (numControllers < MAX_USER_CONTROLLERS) {
        if (takeoverAllowed) pluslist += "No Takeover";
        else pluslist += "Allow Takeover";
    }

    if (isTransformingKey) {
        if (signOn) pluslist += "Turn Off Sign";
        else pluslist += "Turn On Sign";
    }

    llDialog(id, msg, pluslist, dialogChannel);
}

doPosesMenu(key id, integer page) {
    integer poseCount = llGetInventoryNumber(20);
    list poseList; integer i;
    
    llListenControl(dialogHandle, 1);
    llSetTimerEvent(60.0);
    
    for (i = 0; i < poseCount; i++) {
        string poseName = llGetInventoryName(20, i);
        if (poseName != ANIMATION_COLLAPSED &&
            llGetSubString(poseName, 0, 0) != ".") {
            if (poseName != keyAnimation) poseList += poseName;
            else poseList += "* " + poseName;
        }
    }
    poseCount = llGetListLength(poseList);
    if (poseCount > 12) {
        poseList = llList2List(poseList, page * 9, (page + 1) * 9 - 1);
        integer prevPage = page - 1;
        integer nextPage = page + 1;
        if (prevPage == 0) prevPage = llFloor((float)poseCount / 9.0);
        if (nextPage > llFloor((float)poseCount / 9.0)) nextPage = 1;
        poseList = [ "Poses " + (string)prevPage, "Main Menu", "Poses " + (string)nextPage ] + poseList;
    }
    
    llDialog(id, "Select the pose to put the doll into", poseList, dialogChannel);
}

handlemenuchoices(string choice, string name, key id) {
    integer doll = (id == dollID);
    integer carrier = (id == carrierID && !doll);
    integer controller = isMistress(id);
    
    integer isOption; // Temporary variable used to determine if an option
                      // from the options menu was clicked that way we can
                      // restore it.
    
    llMessageLinked(LINK_THIS, 500, choice + "|" + name, id);
    
    if (!hasCarrier && !doll && choice == "Carry") {
        // Doll has been picked up...
        carrierID = id;
        carrierName = name;
        lmInternalCommand("carry", carrierName, carrierID);
    }
    else if (choice == "Help/Support") {
        doHelpMenu(id);
    }
    else if (choice == "Help Notecard") {
        llGiveInventory(id,NOTECARD_HELP);
    }
    else if (choice == "Join Group") {
        llOwnerSay("Here is your link to the community dolls group profile secondlife:///app/group/0f0c0dd5-a6LI-2529-d5c7-1284fb719003/about");
        llDialog(id, "To join the community dolls group open your chat history (CTRL+H) and click the group link there.  Just click the Join Group button when the group profile opens.", [ "OK" ], 9999);
    }
    else if (choice == "Visit CD Room") {
        if (id == dollID) llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|TP|" + LANDMARK_CDROOM, id);
        else llGiveInventory(id, LANDMARK_CDROOM);
    }
    else if (choice == "Report Bug" || choice == "Ask Question" || choice == "Suggestions") {
        llLoadURL(id, "Visit our issues page to report bugs, ask questions or post any suggestions you may have.", "https://github.com/emmamei/cdkey/issues");
    }
    else if (choice == "Place Down" && carrier) {
        // Doll has been placed down...
        llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|uncarry|" + carrierName, carrierID);
        carrierID = NULL_KEY;
        carrierName = "";
    }
    else if (choice == "Type of Doll") {
        llMessageLinked(LINK_THIS, 17, name, id);
    }
    else if ((keyAnimation == "" || (!doll || poserID == dollID)) && llGetSubString(choice, 0, 4) == "Poses") {
        integer page = 1; integer len = llStringLength(choice);
        if (len > 5) page = (integer)llGetSubString(choice, 6 - len, -1);
        doPosesMenu(id, page);
    }
    else if ((!doll || poserID == dollID) && choice == "Unpose") {
        keyAnimation = "";
        lmInternalCommand("doUnpose", "", id);
    }
    else if (doll && choice == "Allow Takeover") {
        llOwnerSay("Anyone carrying you may now choose to be your controller.");
        if (hasCarrier) {
            lmSendToAgent(dollName + " seems willing to let you take permanant control of her key now. " +
                            "Maybe you could claim " + dollName + " as your own? (Be Controller from the menu).", carrierID);
        }
        lmSendConfig("takeoverAllowed", (string)1);
    }
    else if (choice == "Dress") {
        if (!doll) llOwnerSay(name + " is looking at your dress menu");
    }
#ifdef ADULT_MODE
    else if ((dollType == "Slut" || pleasureDoll) && choice == "Strip") {
        llDialog(id, "Take off:",
            ["Top", "Bra", "Bottom", "Panties", "Shoes"],
            dialogChannel);
    }
#endif
    else if (carrier && takeoverAllowed && choice == "Be Controller") {
        newController(id);
    }
    else if (carrier && !takeoverAllowed && choice == "Request Control") {
        if (id) {
            lmSendToAgent("You have asked " + dollName + " to grant you permanant contol of her key. " +
                          "If she accepts this dolly will become yours, please wait for her response.\n\n" +
                          "Place the doll down before she accepts to cancel your request.", id);
            llDialog(dollID, name + " has requested to take permanant control of your key. " +
                     "If you accept then you will not be able to remove them yourself, become " + name + "'s dolly?",
                     [ "Accept Control", "Refuse Control" ], dialogChannel);
        }
    }
    else if (doll && choice == "Accept Control") {
        newController(id);
    }
    else if (doll && choice == "Refuse Control") {
        if (carrierID) {
            lmSendToAgent("The dolly " + dollName + " refuses to allow you to take permanant control of her. ", carrierID);
        }
    }
    else if (choice == "Use Control" || choice == "Options") {
        doOptionsMenu(id);
    }
    else if (choice == "Detach")
        lmInternalCommand("detach", "", id);
    else if (choice == "Invisible") {
        lmSendConfig("visible", (string)0);
        llSetLinkAlpha(LINK_THIS, 0, ALL_SIDES);
        llOwnerSay("Your key fades from view...");
        //doFade(LINK_THIS, 1.0, 0.0, ALL_SIDES, 0.1);
    }
    else if (choice == "Visible") {
        lmSendConfig("visible", (string)1);
        llSetLinkAlpha(LINK_THIS, 1, ALL_SIDES);
        llOwnerSay("Your key appears magically.");
        //doFade(LINK_THIS, 0.0, 1.0, ALL_SIDES, 0.1);
    }
    else if (choice == "Reload Config") {
        llResetOtherScript("Start");
    }
    else if (choice == "TP Home") {
        lmInternalCommand("TP", LANDMARK_HOME, id);
    }
    else if (choice == "Toggle AFK") {
        afk = !afk;
        float displayWindRate = setWindRate();
        integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));
        lmInternalCommand("setAFK", (string)afk + "|0|" + formatFloat(windRate, 1) + "|" + (string)minsLeft, id);
    }
    
    // Entering options menu section
    isOption = 1;
    if (choice == "No Detaching")
        lmSendConfig("detachable", (string)(detachable = 0));
    else if (controller && choice == "Detachable") 
        lmSendConfig("detachable", (string)(detachable = 1));
    else if (choice == "Auto TP")
        lmSendConfig("autoTP", (string)(autoTP = 0));
    else if (controller && choice == "No Auto TP")
        lmSendConfig("autoTP", (string)(autoTP = 1));
    #ifdef ADULT_MODE
    else if (choice == "Pleasure Poll") {
        llOwnerSay("You are now a pleasure doll.");
        lmSendConfig("pleasureDoll", (string)(pleasureDoll = 0));
    }
    else if (choice == "No Pleasure") {
        llOwnerSay("You are no longer a pleasure doll.");
        lmSendConfig("pleasureDoll", (string)(pleasureDoll = 1));
    }
    #endif
    else if (choice == "No Self TP")
        lmSendConfig("helpless", (string)1);
    else if (controller && choice == "Self TP")
        lmSendConfig("helpless", (string)(helpless = 0));
    else if (choice == "Can Carry") {
        llOwnerSay("Other people can now carry you.");
        lmSendConfig("canCarry", (string)(canCarry = 1));
    }
    else if (choice == "No Carry") {
        llOwnerSay("Other people can no longer carry you.");
        lmSendConfig("canCarry", (string)(canCarry = 0));
    }
    else if (choice == "Can Outfit") {
        llOwnerSay("Other people can now outfit you.");
        lmSendConfig("canDress", (string)(canDress = 1));
    }
    else if (choice == "No Outfitting") {
        llOwnerSay("Other people can no longer outfit you.");
        lmSendConfig("canDress", (string)(canDress = 0));
    }
    else if (choice == "Allow Takeover") {
        llOwnerSay("Anyone carrying you may now choose to be your controller.");
        if (hasCarrier) {
            lmSendToAgent(dollName + " seems willing to let you take permanant control of her key now. " +
                            "Maybe you could claim " + dollName + " as your own? (Be Controller from the menu).", carrierID);
        }
        lmSendConfig("takeoverAllowed", (string)(takeoverAllowed = 1));
    }
    else if (choice == "No Takeover") {
        llOwnerSay("There is now no way for someone to become your controller.");
        lmSendConfig("takeoverAllowed", (string)(takeoverAllowed = 0));
    }
    else if (choice == "No Warnings") {
        llOwnerSay("No warnings will be given when time remaining is low.");
        lmSendConfig("doWarnings", (string)(doWarnings = 0));
    }
    else if (choice == "Warnings") {
        llOwnerSay("Warnings will now be given when time remaining is low.");
        lmSendConfig("doWarnings", (string)(doWarnings = 1));
    }
    else if (choice == "No Flying")
        lmSendConfig("canFly", (string)0);
    else if (controller && choice == "Can Fly")
        lmSendConfig("canFly", (string)(canFly = 1));
    else if (choice == "Turn Off Sign")
        lmSendConfig("signOn", (string)(signOn = 0));
    else if (choice == "Turn On Sign")
        lmSendConfig("signOn", (string)(signOn = 1));
    else if (choice == "No AFK")
        lmSendConfig("canAFK", (string)(canAFK = 0));
    else if (controller && choice == "Can AFK")
        lmSendConfig("canAFK", (string)(canAFK = 1));
    else
        isOption = 0; // Not an options menu item after all
        
    if (isOption) doOptionsMenu(id);
    
    if (controller && choice == "Drop Control") {
        integer index = llListFindList(MistressList, [ id ]);
        if (index != -1) {
            MistressList = llDeleteSubList(MistressList, index, index);
            MistressNameList = llDeleteSubList(MistressList, index, index);
        }
    }
    
    if ((keyAnimation == "" || (!doll || poserID == dollID)) && llGetInventoryType(choice) == 20) {
        keyAnimation = choice;
        lmInternalCommand("setPose", choice, id);
        poserID = id;
    }
    else if ((keyAnimation == "" || (!doll || poserID == dollID)) && llGetInventoryType(llGetSubString(choice, 2, -1)) == 20) {
        keyAnimation = llGetSubString(choice, 2, -1);
        lmInternalCommand("setPose", llGetSubString(choice, 2, -1), id);
        poserID = id;
    }
    
#ifdef ADULT_MODE
    // Strip items... only for Pleasure Doll and Slut Doll Types...
    if (id == carrierID || id == dollID || ((numControllers != 0) && isMistress(id))) {
        if (choice == "Top") {
            llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|stripTop", id);
        }
        else if (choice == "Bra") {
            llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|stripBra", id);
        }
        else if (choice == "Bottom") {
            llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|stripBottom", id);
        }
        else if (choice == "Panties") {
            llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|stripPanties", id);
        }
        else if (choice == "Shoes") {
            llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|stripShoes", id);
        }

        if (llListFindList(["Top", "Bra", "Bottom", "Panties", "Shoes", "Strip"], [ choice ]) != -1)
            // Do strip menu
            llDialog(id, "Take off:",
                ["Top", "Bra", "Bottom", "Panties", "Shoes"],
                dialogChannel);
    }
#endif
}

newController(key id) {
    if (carrierID) {
        if (numControllers < MAX_USER_CONTROLLERS && llListFindList(MistressList, [ carrierID ]) == -1) {
            MistressList = llListSort(MistressList + [ carrierID ], 1, 1);
            reloadMistressNames();
        }
        lmSendConfig("MistressList", llDumpList2String(MistressList, "|"));
        if (id == carrierID) {
            llOwnerSay("Your carrier, " + carrierName + ", has become your controller.");
        } else if (id == dollID) {
            llOwnerSay("You have accepted your carrier " + carrierName + " as you controller, they now " +
                       "have complete control over dolly.");
            lmSendToAgent("The dolly " + dollName + " has fully accepted your control of them.", carrierID);
        }
        reloadMistressNames();
        
        if (!quiet) llSay(0, carrierName + " has become controller of the doll " + dollName + ".");
    
        // Note that the response goes to 9999 - a nonsense channel
        string msg = "You are now controller of " + dollName + ". See " + WEB_DOMAIN + "controller.htm for more information.";
        llDialog(carrierID, msg, ["OK"], 9999);
    } else {
        llOwnerSay("Unable to accept new controller as you are not currently being carried, your new Mistress needs to " +
                   "be carrying you when the request is accepted for this to work.");
    }
}

reloadMistressNames() {
    if (numControllers != 0) {
        integer i;
        
        // Initialize list
        MistressNameList = [];
        for (i = 0; i < llGetListLength(MistressList); i++)  MistressNameList += "";
        
        mistressQueryIndex = 0;
        mistressQuery = llRequestDisplayName(llList2Key(MistressList, mistressQueryIndex));
    }
}

float setWindRate() {
    float newWindRate = RATE_STANDARD;
    integer windDown = !(!isAttached || collapsed || (dollType == "Builder" || dollType == "Key"));
    if (afk) newWindRate *= RATE_AFK;
    
    if (windRate != (newWindRate * (float)windDown)) {
        if (windRate == 0.0) llResetTime();
        windRate = newWindRate * (float)windDown;
    }
    
    return newWindRate;
}

default
{
    state_entry() {
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);
        lmScriptReset();
    }
    
    link_message(integer sender, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);
        
        if (code == 15) {
            integer i;
            for (i = 0; i < llGetListLength(MistressList); i++) {
                llMessageLinked(LINK_THIS, 11, data, llList2Key(MistressList, i));
            }
        }
        else if (code == 101) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            split = llList2List(split, 2, -1);
            
            if (!configured) {
                if (name == "controller") {
                    MistressList == split;
                    mistressQuery = llRequestDisplayName(llList2Key(split, 0));
                }
            }
        }
        else if (code == 104 || code == 105) {
            if (llList2String(split, 0) != "Start") return;
            
            dialogChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)llGetLinkKey(2), -8, -1));
            llListenRemove(dialogHandle);
            dialogHandle = llListen(dialogChannel, "", "", "");
            
            lmInitState(code);
        }
        else if (code == 106) {
            
        }
        else if (code == 135) memReport();
        else if (code == 300) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);
            
                 if (name == "timeLeftOnKey")           timeLeftOnKey = (float)value;
            else if (name == "keyAnimation")             keyAnimation = value;
            else if (name == "afk")                               afk = (integer)value;
            else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "canAFK")                         canAFK = (integer)value;
            else if (name == "canCarry")                     canCarry = (integer)value;
            else if (name == "canDress")                     canDress = (integer)value;
            else if (name == "canFly")                         canFly = (integer)value;
            else if (name == "canSit")                         canSit = (integer)value;
            else if (name == "canStand")                     canStand = (integer)value;
            else if (name == "configured")                 configured = (integer)value;
            else if (name == "detachable")                 detachable = (integer)value;
            else if (name == "helpless")                     helpless = (integer)value;
            else if (name == "pleasureDoll")             pleasureDoll = (integer)value;
            else if (name == "isTransformingKey")   isTransformingKey = (integer)value;
            else if (name == "isVisible")                     visible = (integer)value;
            else if (name == "quiet")                           quiet = (integer)value;
            else if (name == "RLVok")                           RLVok = (integer)value;
            else if (name == "signOn")                         signOn = (integer)value;
            else if (name == "takeoverAllowed")       takeoverAllowed = (integer)value;
            else if (name == "dollType")
                dollType = llGetSubString(llToUpper(value), 0, 0) + llGetSubString(llToLower(value), 1, -1);
            else if (name == "MistressID") {
                if (llListFindList(MistressList, [ value ]) == -1) {
                    MistressList = llListSort(MistressList + [ value ], 1, 1);
                    reloadMistressNames();
                }
            }
            else if (name == "MistressList") {
                list newList = llListSort(llList2List(split, 2, -1), 1, 1);
                if (MistressList != newList) {
                    MistressList = newList;
                    reloadMistressNames();
                }
            }
        }        
        else if (code == 305) {
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llList2List(split, 2, -1);
            
            if (cmd == "carry") {
                // Doll has been picked up...
                carrierID = id;
                carrierName = llList2String(split, 0);
            }
            else if (cmd == "uncarry") {
                // Doll has been placed down...
                carrierID = NULL_KEY;
                carrierName = "";
            }
            else if (cmd == "mainMenu") doMainMenu(id);
            else if (cmd == "collapse") collapsed = 1;
            else if (cmd == "restore") collapsed = 0;
            else if (cmd == "dialogListen") {
                llListenControl(dialogHandle, 1);
                llSetTimerEvent(60.0);
            }
        }
    }
    
    timer() {
        llListenControl(dialogHandle, 0);
        llSetTimerEvent(0.0);
    }
    
    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {
        // channel = chat channel to listen on
        //    name = filter by prim name
        //     key = filter by avatar key
        //  choice = filter by specific message
        string displayName = llGetDisplayName(id);
        if (displayName != "") name = displayName;

        debugSay(5, "Button clicked: " + choice);
        handlemenuchoices(choice, name, id);
        
        // Ideally the listener should be closing here and only reopened when we spawn another menu
        // other scripts also use the dialog listerner in this script.  Until they are writtent to send
        // a dialogListen command whenever they respawn a dialog we have to keep the listener open
        // at any sign of usage.
        llListenControl(dialogHandle, 1);
        llSetTimerEvent(60.0);
    }
    
    dataserver(key query_id, string data) {
        if (query_id == mistressQuery) {
            MistressNameList += llListReplaceList(MistressNameList, [ data ], mistressQueryIndex, mistressQueryIndex);
            if (++mistressQueryIndex < numControllers) {
                mistressQuery = llRequestDisplayName(llList2Key(MistressList, mistressQueryIndex));
            }
            else {
                llOwnerSay("Your controllers are now: " + llList2CSV(MistressNameList));
            }
        }
    }
}

