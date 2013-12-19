// 1 "MenuHandler.lslp"
// 1 "<built-in>"
// 1 "<command-line>"
// 1 "MenuHandler.lslp"
// MenuHandler.lsl
//
// vim:sw=4 et nowrap:
//
// DATE: 10 December 2013
// 1 "include/GlobalDefines.lsl" 1
// include/GlobalDefines.lsl
//
// Global preprocessor and variable definitions for the key
//
// 35 "include/GlobalDefines.lsl"
// Link messages
// 44 "include/GlobalDefines.lsl"
// Keys of important people in life of the Key:





// 1 "include/Utility.lsl" 1
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

string bits2nybbles(integer bits)
{
    string nybbles = "";
    do
    {
        integer lsn = bits & 0xF; // least significant nybble
        nybbles = llGetSubString("0123456789ABCDEF", lsn, lsn) + nybbles;
    } while (bits = (0xfffFFFF & (bits >> 4)));
    return nybbles;
}

string formatFloat(float val, integer dp)
{
    string out = "ERROR";
    if (dp == 0) {
        out = (string)llRound(val);
    } else if (dp > 0 && dp <= 6) {
        val = llRound(val * llPow(10.0, dp)) / llPow(10.0, dp);
        out = llGetSubString((string)val, 0, -7 + dp);
    }
    return out;
}

memReport() {
    float free_memory = (float)llGetFreeMemory();
    float used_memory = (float)llGetUsedMemory();

    llOwnerSay(llGetScriptName() + ": Memory " + formatFloat(used_memory/1024.0, 2) + "/" + (string)llRound((used_memory + free_memory)/1024.0) + "kB, " + formatFloat(free_memory/1024.0, 2) + " kB free");
}
// 51 "include/GlobalDefines.lsl" 2
// 1 "include/KeySharedFuncs.lsl" 1
//-----------------------------------
// Internal Shared Functions
//-----------------------------------

float lastTimerEvent;

float setWindRate() {
    float newWindRate;
    vector agentPos = llList2Vector(llGetObjectDetails(dollID, [ OBJECT_POS ]), 0);
    integer agentInfo = llGetAgentInfo(dollID);
    integer windDown = (llGetAttached() == ATTACH_BACK) && !collapsed && dollType != "Builder" && dollType != "Key";

    newWindRate = 1.0;
    if (afk) newWindRate *= 0.5;

    if (windRate != newWindRate * windDown) {
        windRate = newWindRate * windDown;

        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "windRate" + "|" + (string)windRate,NULL_KEY);
    }

    // llTargetOmega: With normalized vector spinrate is equal to radians per second
    // 2𝜋 radians per rotation.  This sets a normal rotation rate of 4 rpm about the
    // Z axis multiplied by the wind rate this way the key will visually run faster as
    // the dolly begins using their time faster.
    llTargetOmega(llVecNorm(<0.0, 0.0, 1.0>), windRate * (TWO_PI / 15.0), 1);

    return newWindRate;
}

integer setFlags(integer clear, integer set) {
    integer oldFlags = globalFlags;
    globalFlags = (globalFlags & ~clear) | set;
    if (globalFlags != oldFlags) {
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "globalFlags" + "|" + "0x" + bits2nybbles(globalFlags),NULL_KEY);
        return 1;
    }
    else return 0;
}
// 52 "include/GlobalDefines.lsl" 2
// 7 "MenuHandler.lslp" 2

// Current Controller - or Mistress
key MistressID = NULL_KEY;
key carrierID = NULL_KEY;
key poserID = NULL_KEY;
key dollID = NULL_KEY;

key mistressQuery;

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

string simRating;

string keyAnimation;

doMainMenu(key id) {
    string msg;
    list menu = ["Wind"];

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
    if ((carrierID != NULL_KEY)) {
        // Three possibles:
        //   1. Doll
        //   2. Carrier
        //   3. Someone else

        // Doll being carried clicked on key
        if (id == dollID) {
            msg = "You are being carried by " + carrierName + ".";
            menu = ["OK"];

            // Allows user to permit current carrier to take over and become Mistress
            if (!(MistressID != NULL_KEY) && !takeoverAllowed) {
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

            if (!(MistressID != NULL_KEY) && takeoverAllowed) {
                menu += "Be Controller";
            }


            // Is doll strippable?
            if ((pleasureDoll || dollType == "Slut") && RLVok && (simRating == "MATURE" || simRating == "ADULT")) {
                menu += "Strip";
            }

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
    else { //not  being carried, not collapsed - normal in other words
        // Toucher could be...
        //   1. Doll
        //   2. Someone else

        // Is toucher the Doll?
        if (id == dollID) {
            manpage = "dollkeyselfinfo.htm";

            menu = ["Dress","Options"];


            menu += "Strip";

            menu += "Wind";


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

            if (llGetInventoryType("Home") == INVENTORY_LANDMARK) {
               menu += "TP Home";
            }

            if (isTransformingKey) {
                menu += "Type of Doll";
            }
        }
        else {
            manpage = "communitydoll.htm";

            // Toucher is not Doll.... could be anyone
            msg = dollName + " is a doll and likes to be treated like " +
                   "a doll. So feel free to use these options.\n";
        }

        menu += "Help/Support";

        // Hide the general "Carry" option for all but Mistress when one exists
        if (((id == MistressID) || !(MistressID != NULL_KEY)) && id != dollID) {
            if (canCarry) {
                msg = msg +
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
    if ((id == MistressID) && (id != dollID)) {
        menu += "Use Control";

        if (llGetInventoryType("Home") == INVENTORY_LANDMARK) {
            menu += "TP Home";
        }
    }

    msg += "See " + "http://communitydolls.com/" + manpage + " for more information." ;
    llDialog(id, timeleft + msg, menu, dialogChannel);
}

doHelpMenu(key id) {
    string msg = "Here you can find various options to get help with your " +
                "key and to connect with the community.";
    list menu = [ "Join Group", "Visit CD Room", "Reset Scripts", "Issue Tracker" ];
    if (llGetInventoryType("Community Dolls Key Help and Manual") == INVENTORY_NOTECARD) menu += "Help Notecard";

    llDialog(id, msg, menu, dialogChannel);
}

doOptionsMenu(key id) {
    integer isController;
    if ((id == MistressID) && (id != dollID)) isController = 1;

    string msg = "See " + "http://communitydolls.com/" + "keychoices.htm for explanation. (" + "19/Dec/13" + " version)";
    list pluslist;

    if (isController) {
        msg = "See " + "http://communitydolls.com/" + "controller.htm. Choose what you want to happen. (" + "19/Dec/13" + " version)";
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


    if (pleasureDoll) pluslist += "No Pleasure";
    else pluslist += "Pleasure Doll";


    if (!(MistressID != NULL_KEY)) {
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

    for (i = 0; i < poseCount; i++) {
        string poseName = llGetInventoryName(20, i);
        if (poseName != "collapse" &&
            llGetSubString(poseName, 0, 0) != ".") {
            if (poseName != keyAnimation) poseList += poseName;
            else poseList += "* " + poseName;
        }
    }
    poseCount = llGetListLength(poseList);
    if (poseCount > 12) {
        poseList = llList2List(poseList, page * 9 - 1, (page + 1) * 9 - 1);
        integer prevPage = page - 1;
        integer nextPage = page + 1;
        if (prevPage = 0) prevPage = llCeil((float)poseCount / 9.0);
        if (nextPage > llCeil((float)poseCount / 9.0)) nextPage = 1;
        poseList += [ "Poses " + (string)prevPage, "Main Menu", "Poses " + (string)nextPage ];
    }

    llDialog(id, "Select the pose to put the doll into", poseList, dialogChannel);
}

handlemenuchoices(string choice, string name, key id) {
    integer doll = (id == dollID);
    integer carrier = (id == carrierID && !doll);
    integer controller = (id == MistressID && !doll);

    llMessageLinked(LINK_SET, 500, choice + "|" + name, id);

    if (!(carrierID != NULL_KEY) && !doll && choice == "Carry") {
        // Doll has been picked up...
        carrierID = id;
        carrierName = name;
        llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|" + "carry" + "|" +carrierName, carrierID);
    }
    else if (choice == "Help/Support") {
        doHelpMenu(id);
    }
    else if (choice == "Help Notecard") {
        llGiveInventory(id,"Community Dolls Key Help and Manual");
    }
    else if (choice == "Join Group") {
        llOwnerSay("Here is your link to the community dolls group profile secondlife:///app/group/0f0c0dd5-a611-2529-d5c7-1284fb719003/about");
        llDialog(id, "To join the community dolls group open your chat history (CTRL+H) and click the group link there.  Just click the Join Group button when the group profile opens.", [ "OK" ], 9999);
    }
    else if (choice == "Visit CD Room") {
        if (id == dollID) llMessageLinked(LINK_SET, 305, llGetScriptName() + "|TP|" + "Community Dolls Room", id);
        else llGiveInventory(id, "Community Dolls Room");
    }
    else if (choice == "Report Bug" || choice == "Ask Question" || choice == "Suggestions") {
        llLoadURL(id, "Visit our issues page to report bugs, ask questions or post any suggestions you may have.", "https://github.com/emmamei/cdkey/issues");
    }
    else if ((carrierID != NULL_KEY) && carrier && choice == "Place Down") {
        // Doll has been placed down...
        llMessageLinked(LINK_SET, 305, llGetScriptName() + "|uncarry|" + carrierName, carrierID);
        carrierID = NULL_KEY;
        carrierName = "";
    }
    else if (choice == "Type of Doll") {
        llMessageLinked(LINK_SET, 17, name, id);
    }
    else if ((keyAnimation == "" || (!doll || poserID == dollID)) && llGetSubString(choice, 0, 4) == "Poses") {
        integer page = 1; integer len = llStringLength(choice);
        if (len > 5) page = (integer)llGetSubString(choice, 6 - len, -1);
        doPosesMenu(id, page);
    }
    else if ((!doll || poserID == dollID) && choice == "Unpose") {
        keyAnimation = "";
        llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|" + "doUnpose" + "|" +"", id);
    }
    else if (doll && choice == "Allow Takeover") {
        llOwnerSay("Anyone carrying you may now choose to be your controller.");
        if ((carrierID != NULL_KEY)) {
            llMessageLinked(LINK_THIS, 11,dollName + " seems willing to let you take permanant control of her key now. " + "Maybe you could claim " + dollName + " as your own? (Be Controller from the menu).",carrierID)
                                                                                                                            ;
        }
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "takeoverAllowed" + "|" + (string)1,id);
    }
    else if (choice == "Dress") {
        if (!doll) llOwnerSay(name + " is looking at your dress menu");
    }

    else if ((dollType == "Slut" || pleasureDoll) && choice == "Strip") {
        llDialog(id, "Take off:",
            ["Top", "Bra", "Bottom", "Panties", "Shoes"],
            dialogChannel);
    }

    else if (carrier && takeoverAllowed && choice == "Be Controller") {
        newController(id);
    }
    else if (carrier && !takeoverAllowed && choice == "Request Control") {
        if (id) {
            llMessageLinked(LINK_THIS, 11,"You have asked " + dollName + " to grant you permanant contol of her key. " + "If she accepts this dolly will become yours, please wait for her response.\n\n" + "Place the doll down before she accepts to cancel your request.",id)

                                                                                               ;
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
            llMessageLinked(LINK_THIS, 11,"The dolly " + dollName + " refuses to allow you to take permanant control of her. ",carrierID);
        }
    }
    else if (choice == "Use Control" || choice == "Options") {
        doOptionsMenu(id);
    }
    else if (choice == "Detach")
        llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|" + "detach" + "|" +"", id);
    else if (choice == "Invisible") {
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "visible" + "|" + (string)0,id);
        llSetLinkAlpha(LINK_SET, 0, ALL_SIDES);
        llOwnerSay("Your key fades from view...");
        //doFade(LINK_SET, 1.0, 0.0, ALL_SIDES, 0.1);
    }
    else if (choice == "Visible") {
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "visible" + "|" + (string)1,id);
        llSetLinkAlpha(LINK_SET, 1, ALL_SIDES);
        llOwnerSay("Your key appears magically.");
        //doFade(LINK_SET, 0.0, 1.0, ALL_SIDES, 0.1);
    }
    else if (choice == "Reload Config") {
        llResetOtherScript("Start");
    }
    else if (choice == "TP Home") {
        llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|" + "TP" + "|" +"Home", id);
    }
    else if (choice == "Toggle AFK") {
        afk = !afk;
        float displayWindRate = setWindRate();
        integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));
        llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|" + "setAFK" + "|" +(string)afk + "|0|" + formatFloat(windRate, 1) + "|" + (string)minsLeft, id);
    }
    else if (choice == "No Detaching")
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "detachable" + "|" + (string)0,id);
    else if (controller && choice == "Detachable")
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "detachable" + "|" + (string)1,id);
    else if (choice == "Auto TP")
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "autoTP" + "|" + (string)0,id);
    else if (controller && choice == "No Auto TP")
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "autoTP" + "|" + (string)1,id);

    else if (choice == "Pleasure Poll") {
        llOwnerSay("You are now a pleasure doll.");
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "pleasureDoll" + "|" + (string)0,id);
    }
    else if (choice == "No Pleasure") {
        llOwnerSay("You are no longer a pleasure doll.");
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "pleasureDoll" + "|" + (string)1,id);
    }

    else if (choice == "No Self TP")
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "helpless" + "|" + (string)1,id);
    else if (controller && choice == "Self TP")
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "helpless" + "|" + (string)0,id);
    else if (choice == "Can Carry") {
        llOwnerSay("Other people can now carry you.");
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "canCarry" + "|" + (string)1,id);
    }
    else if (choice == "No Carry") {
        llOwnerSay("Other people can no longer carry you.");
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "canCarry" + "|" + (string)0,id);
    }
    else if (choice == "Can Outfit") {
        llOwnerSay("Other people can now outfit you.");
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "canDress" + "|" + (string)1,id);
    }
    else if (choice == "No Outfitting") {
        llOwnerSay("Other people can no longer outfit you.");
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "canDress" + "|" + (string)0,id);
    }
    else if (choice == "Allow Takeover") {
        llOwnerSay("Anyone carrying you may now choose to be your controller.");
        if ((carrierID != NULL_KEY)) {
            llMessageLinked(LINK_THIS, 11,dollName + " seems willing to let you take permanant control of her key now. " + "Maybe you could claim " + dollName + " as your own? (Be Controller from the menu).",carrierID)
                                                                                                                            ;
        }
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "takeoverAllowed" + "|" + (string)1,id);
    }
    else if (choice == "No Takeover") {
        llOwnerSay("There is now no way for someone to become your controller.");
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "takeoverAllowed" + "|" + (string)0,id);
    }
    else if (choice == "No Warnings") {
        llOwnerSay("No warnings will be given when time remaining is low.");
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "doWarnings" + "|" + (string)0,id);
    }
    else if (choice == "Warnings") {
        llOwnerSay("Warnings will now be given when time remaining is low.");
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "doWarnings" + "|" + (string)1,id);
    }
    else if (choice == "No Flying")
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "canFly" + "|" + (string)0,id);
    else if (controller && choice == "Can Fly")
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "canFly" + "|" + (string)1,id);
    else if (choice == "Turn Off Sign")
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "signOn" + "|" + (string)0,id);
    else if (choice == "Turn On Sign")
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "signOn" + "|" + (string)1,id);
    else if (choice == "No AFK")
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "canAFK" + "|" + (string)0,id);
    else if (controller && choice == "Can AFK")
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "canAFK" + "|" + (string)1,id);
    else if (controller && choice == "Drop Control") {
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "MistressID" + "|" + (string)NULL_KEY,id);
        llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "mistressName" + "|" + "",id);
    }
    else if (doll && choice == "Reload Config") llResetOtherScript("Start");

    if ((keyAnimation == "" || (!doll || poserID == dollID)) && llGetInventoryType(choice) == 20) {
        keyAnimation = choice;
        llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|" + "setPose" + "|" +choice, id);
        poserID = id;
    }
    else if ((keyAnimation == "" || (!doll || poserID == dollID)) && llGetInventoryType(llGetSubString(choice, 2, -1)) == 20) {
        keyAnimation = llGetSubString(choice, 2, -1);
        llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|" + "setPose" + "|" +llGetSubString(choice, 2, -1), id);
        poserID = id;
    }


    // Strip items... only for Pleasure Doll and Slut Doll Types...
    if (id == carrierID || id == dollID || ((MistressID != NULL_KEY) && id == MistressID)) {
        if (choice == "Top") {
            llMessageLinked(LINK_SET, 305, llGetScriptName() + "|stripTop", id);
        }
        else if (choice == "Bra") {
            llMessageLinked(LINK_SET, 305, llGetScriptName() + "|stripBra", id);
        }
        else if (choice == "Bottom") {
            llMessageLinked(LINK_SET, 305, llGetScriptName() + "|stripBottom", id);
        }
        else if (choice == "Panties") {
            llMessageLinked(LINK_SET, 305, llGetScriptName() + "|stripPanties", id);
        }
        else if (choice == "Shoes") {
            llMessageLinked(LINK_SET, 305, llGetScriptName() + "|stripShoes", id);
        }

        if (llListFindList(["Top", "Bra", "Bottom", "Panties", "Shoes", "Strip"], [ choice ]) != -1)
            // Do strip menu
            llDialog(id, "Take off:",
                ["Top", "Bra", "Bottom", "Panties", "Shoes"],
                dialogChannel);
    }

}

newController(key id) {
    if (carrierID) {
        llMessageLinked(LINK_SET, 300, "takeoverAllowed|" + (string)0, id);
        llMessageLinked(LINK_SET, 300, "hasController|" + (string)1, id);
        llMessageLinked(LINK_SET, 300, "MistressID|" + (string)(MistressID = carrierID), id);
        llMessageLinked(LINK_SET, 300, "mistressName|" + (string)(mistressName = carrierName), id);
        if (id == carrierID) {
            llOwnerSay("Your carrier, " + mistressName + ", has become your controller.");
        } else if (id == dollID) {
            llOwnerSay("You have accepted your carrier " + mistressName + " as you controller, they now " +
                       "have complete control over dolly.");
            llMessageLinked(LINK_THIS, 11,"The dolly " + dollName + " has fully accepted your control of them.",MistressID);
        }

        if (!quiet) llSay(0, mistressName + " has become controller of the doll " + dollName + ".");

        // Note that the response goes to 9999 - a nonsense channel
        string msg = "You are now controller of " + dollName + ". See " + "http://communitydolls.com/" + "controller.htm for more information.";
        llDialog(carrierID, msg, ["OK"], 9999);
    } else {
        llOwnerSay("Unable to accept new controller as you are not currently being carried, your new Mistress needs to " +
                   "be carrying you when the request is accepted for this to work.");
    }
}

float setWindRate() {
    float newWindRate = 1.0;
    integer windDown = !(!(llGetAttached() == ATTACH_BACK) || collapsed || (dollType == "Builder" || dollType == "Key"));
    if (afk) newWindRate *= 0.5;

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
        llMessageLinked(LINK_THIS, 999, llGetScriptName(), NULL_KEY);
    }

    link_message(integer sender, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);

        if (code == 101) {
            string name = llList2String(split, 0);
            split = llList2List(split, 1, -1);

            if (!configured) {
                if (name == "controller") {
                    MistressID == llList2String(split, 0);
                    mistressQuery = llRequestDisplayName(MistressID);
                }
            }
        }
        else if (code == 104 || code == 105) {
            if (llList2String(split, 0) != "Start") return;

            dialogChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)llGetLinkKey(2), -9, -1));
            llListenRemove(dialogHandle);
            dialogHandle = llListen(dialogChannel, "", "", "");

            llMessageLinked(LINK_THIS, code, llGetScriptName(), NULL_KEY);
        }
        else if (code == 106) {

        }
        else if (code == 135) memReport();
        else if (code == 300) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);

            if (script != llGetScriptName()) {
                     if (name == "timeLeftOnKey") timeLeftOnKey = (float)value;
                else if (name == "keyAnimation") keyAnimation = value;
                else if (name == "afk") afk = (integer)value;
                else if (name == "autoTP") autoTP = (integer)value;
                else if (name == "canAFK") canAFK = (integer)value;
                else if (name == "canCarry") canCarry = (integer)value;
                else if (name == "canDress") canDress = (integer)value;
                else if (name == "canFly") canFly = (integer)value;
                else if (name == "canSit") canSit = (integer)value;
                else if (name == "canStand") canStand = (integer)value;
                else if (name == "configured") configured = (integer)value;
                else if (name == "detachable") detachable = (integer)value;
                else if (name == "helpless") helpless = (integer)value;
                else if (name == "pleasureDoll") pleasureDoll = (integer)value;
                else if (name == "isTransformingKey") isTransformingKey = (integer)value;
                else if (name == "isVisible") visible = (integer)value;
                else if (name == "quiet") quiet = (integer)value;
                else if (name == "RLVok") RLVok = (integer)value;
                else if (name == "signOn") signOn = (integer)value;
                else if (name == "takeoverAllowed") takeoverAllowed = (integer)value;
                else if (name == "dollType")
                    dollType = llGetSubString(llToUpper(value), 0, 0) + llGetSubString(llToLower(value), 1, -1);
                else if (name == "MistressID") {
                    MistressID = (key)value;
                    mistressQuery = llRequestDisplayName(MistressID);
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
        string displayName = llGetDisplayName(id);
        if (displayName != "") name = displayName;

        handlemenuchoices(choice, name, id);
    }

    dataserver(key query_id, string data) {
        if (query_id == mistressQuery) {
            mistressName = data;
            llMessageLinked(LINK_THIS, 300, llGetScriptName() + "|" + "mistressName" + "|" + mistressName,NULL_KEY);
        }
    }
}
