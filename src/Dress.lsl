//========================================
// Dress.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

// HISTORY:
//   Oct. 1   Adds everything in ~normalself folder, if oldOutfit begins with a +.
//            Adds channel dialog or id to screen listen
//   Nov. 17  moves listen to cd2667 so it gets turned off
//   Nov. 25  puts in dress menu
//   Aug 1    redoes closing

#include "include/GlobalDefines.lsl"

#define NO_FILTER ""
#define cdListenMine(a) llListen(a, NO_FILTER, dollID, NO_FILTER)
#define isKnownTypeFolder(a) (llListFindList(typeFolders, [ a ]) != NOT_FOUND)

#define nothingWorn(c,d) ((c) != "0") && ((c) != "1") && ((d) != "0") && ((d) != "1")
#define dressVia(a) listInventoryOn(a)
#define clearDresser() dresserID = NULL_KEY

//========================================
// VARIABLES
//========================================

// FIXME: This should be in a notecard so it can be changed without mangling the scripts.
string outfitsURL = "outfits.htm";
string outfitsMessage;
string msg;

string prefix;

integer tempDressingLock = FALSE;  // allow only one dressing going on at a time

string newOutfitName;
string newOutfitFolder;
string newOutfitPath;

// New simple listener setup we only
// listen to rlvChannel directly the
// other we use MenuHandlers link 500's
#define RLV_BASE_CHANNEL 1
#ifdef RLV_BASE_CHANNEL
integer rlvBaseChannel;
#endif
integer outfitsChannel;
integer outfitsHandle;
integer change;
integer pushRandom;

// These are the paths of the outfits relative to #RLV
//string lastFolder;
string newOutfit;
string oldOutfit;
string wearFolder;
string unwearFolder;

list outfitsList;
integer useTypeFolder;

string clothingFolder; // This contains clothing to be worn
string outfitsFolder;  // This contains folders of clothing to be worn
string activeFolder; // This is the lookup folder to search
string typeFolder; // This is the folder we want for our doll type
string normalselfFolder; // This is the ~normalself we are using
string normaloutfitFolder; // This is the ~normaloutfit we are using
string nudeFolder; // This is the ~nude we are using

integer menuDressHandle;
integer menuDressChannel;

integer dressingFailures;

integer outfitPage; // zero-indexed

#define OUTFIT_PAGE_SIZE 9

//========================================
// FUNCTIONS
//========================================
integer uSubStringLastIndex(string hay, string pin) {

    integer index2 = -1;
    integer index;

    if (pin == "") return 0;

    while (~index) {
        index = llSubStringIndex( llGetSubString(hay, ++index2, -1), pin);
        index2 += index;
    }

    return index2;
}

list outfitsPage(list outfitList) {
    integer newOutfitCount = llGetListLength(outfitList) - 1;
    integer currentIndex = (outfitPage - 1) * OUTFIT_PAGE_SIZE;
    integer tmpEnd;

    // Print the page contents - note that this happens even before
    // any dialog is put up
    integer n;
    integer x;
    string chat;
    list output;
    string outfitName;
    list tmpList;

    tmpList = llList2List(outfitsList, currentIndex, currentIndex + 8);
    n = llGetListLength(tmpList);
    tmpEnd = n - 1;

    while (n--) {
        x = tmpEnd - n;

        // The first number (shown to user) has to not only
        // be one indexed, but be offset by the page.
        //
        // x ................ current list index (0 - max)
        // +1 ............... convert to 1-index
        // +currentIndex .... offset by currentPage index
        outfitName = (string)(currentIndex + x + 1) + ". " + cdListElement(tmpList, x);

        chat += "\n" + outfitName;
        output += (list)llGetSubString(outfitName, 0, 23);
    }

    llRegionSayTo(dresserID, 0, chat);

    return llListSort(output,1,1);
}

retryDirSearch() {

    // Nowhere to retry to
    if (clothingFolder == "") return;

    // Retry at Outfits top level
    lmSendConfig("clothingFolder", (clothingFolder = ""));
    dressVia(randomDressChannel); // recursion
}

#ifdef RLV_BASE_CHANNEL
// FUNCTION: rlvRequest - used in only one location
//
// FIXME: can the rlvRequest function be removed or reworked?
rlvRequest(string rlv, integer channel) {

    if (channel < 2670) {

        // FIXME: this should not happen

        if (channel == 0) {
            llSay(DEBUG_CHANNEL,"rlvRequest called with channel zero");
            return;
        }

        llSay(DEBUG_CHANNEL,"rlvRequest called with old channel numbers");
        if (channel == 2666) menuDressHandle = cdListenAll(menuDressChannel);

        lmRunRLV(rlv + (string)(rlvBaseChannel + channel));
    }
    else {

        // FIXME: this block should be executed all the time

        if (channel == menuDressChannel) menuDressHandle = cdListenAll(menuDressChannel);
        lmRunRLV(rlv + (string)channel);
    }

    llSetTimerEvent(30.0);
}
#endif

listInventoryOn(integer channel) {

    if (outfitsFolder == "") {
        llOwnerSay("No suitable outfits folder found, so unfortunately you will not be able to be dressed");
        return;
    }

    // activeFolder is the folder (full path) we are looking at with our Menu
    // outfitsFolder is where all outfits are stored, including
    //     ~normalself, ~normaloutfit, ~nude, and all the type folders
    // clothingFolder is the current folder for clothing, relative
    //     to the outfitsFolder

    activeFolder = outfitsFolder;
    if (clothingFolder != "") activeFolder += "/" + clothingFolder;

#ifdef DEVELOPER_MODE
    //llSay(DEBUG_CHANNEL,"listing inventory on " + (string)channel + " with active folder " + activeFolder);
    debugSay(4, "DEBUG-DRESS", "Setting activeFolder (in listInventory) to " + activeFolder);
#endif
    lmSendConfig("activeFolder", activeFolder);

    if (channel == menuDressChannel) {
        menuDressHandle =  cdListenAll(menuDressChannel);
        lmRunRLV("getinv:" + activeFolder + "=" + (string)(channel));

        llSetTimerEvent(30.0);
    }
    else {
        llSay(DEBUG_CHANNEL,"Erroneous inventory channel requested! (" + (string)(channel) + ")");
    }
}

// This function serves as a lock of sorts
//
// If there is already a dresser in progress, then
// it returns false. If not, then the dresser is assigned
// and the function returns TRUE.
//
// This also presumes that the dresser is cleared when
// necessary, and all exits from dressing must be accounted
// for. Use the clearDresser() macro to reset the lock.
//
integer isDresser(key id) {
    if (dresserID == NULL_KEY) {
        dresserID = id;
        return TRUE;
    }
    else return (dresserID == id);
}

changeComplete(integer success) {
    // And remove the temp locks we used

#ifdef DEVELOPER_MODE
    llOwnerSay("Your key is now unlocked again as you are a developer.");
    if (RLVok == TRUE) lmRunRLV("clear=attach,clear=detach");
#else
    // if we used "detach" as the pattern then the Key would be unlocked
    lmRunRLV("clear=attach,clear=detachall");
#endif

    if (success) {
        if (change) {
            string s = "Change to new outfit " + newOutfitName + " complete.";

            cdSayToAgentPlusDoll(s,dresserID);
        }

        // Note: if wearLock is already set, it STAYS set with this setting
        //
        // This triggers Main and sets wearLockExpire
        //
        // This setting is thus: if dresser is anyone except Dolly, wearLock is set.
        // If wearLock is already set, it stays set..
        wearLock = (wearLock || ((dresserID != NULL_KEY) && (dresserID != dollID)));
    }
    else {
        if (dressingFailures > MAX_DRESS_FAILURES)
            llOwnerSay("Too many dressing failures.");

        string s = "Change to new outfit " + newOutfitName + " unsuccessful.";

        cdSayToAgentPlusDoll(s,dresserID);

        wearLock = 0;
    }

    lmSetConfig("wearLock", (string)wearLock);

    change = 0;

    tempDressingLock = FALSE;
    llSetTimerEvent(0.0);
}

#ifdef DEVELOPER_MODE
string folderStatus() {
    string typeFolderExists;

    if (useTypeFolder) typeFolderExists = typeFolder + " (being used)";
    else typeFolderExists = typeFolder + " (not being used)";

    if (typeFolder == "") typeFolderExists = "";

    return "Outfits Folder: " + outfitsFolder +
           "\nCurrent Folder: " + activeFolder +
           "\nType Folder: " + typeFolderExists +
           "\nUse ~normalself: " + normalselfFolder +
           "\nUse ~normaloutfit: " + normaloutfitFolder +
           "\nUse ~nude: " + nudeFolder;
}
#else
string folderStatus() {
    string typeFolderExists;

    if (useTypeFolder) typeFolderExists = typeFolder;
    else typeFolderExists = typeFolder + " (not found)";

    if (typeFolder == "") typeFolderExists = "n/a";

    return "Outfits Folder: " + outfitsFolder +
           "\nType Folder: " + typeFolderExists;
}
#endif

//========================================
// STATES
//========================================
default {

    //----------------------------------------
    // STATE_ENTRY
    //----------------------------------------
    state_entry() {
        dollID = llGetOwner();

        cdInitializeSeq();
    }

    //----------------------------------------
    // ON_REZ
    //----------------------------------------
    on_rez(integer start) {
        clearDresser();
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    // Used for time-outs on menu selections
    timer() {
        llSetTimerEvent(0.0);
        clearDresser();
    }

    //----------------------------------------
    // LINK_MESSAGE
    //----------------------------------------
    link_message(integer source, integer i, string data, key id) {

        // Parse link message header information
        split             =     cdSplitArgs(data);
        script            =     cdListElement(split, 0);
        remoteSeq         =     (i & 0xFFFF0000) >> 16;
        optHeader         =     (i & 0x00000C00) >> 10;
        code              =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        //scaleMem();

        if (code == SEND_CONFIG) {

            // Configuration settings

            string name = cdListElement(split, 0);
            string value = cdListElement(split, 1);
            string c = cdGetFirstChar(name);

            if (llListFindList([ "a", "R", "h", "p", "c", "d", "n", "t", "w", "o", "u" ], (list)c) == NOT_FOUND) return;
            //debugSay(6, "DEBUG-DRESS", "Link message: CONFIG name = " + name);

            if (name == "dialogChannel") {
                dialogChannel = (integer)value;
#ifdef RLV_BASE_CHANNEL
                rlvBaseChannel = dialogChannel ^ 0x80000000; // Xor with the sign bit forcing the positive channel needed by RLV spec.
#endif
                menuDressChannel = (dialogChannel ^ 0x80000000) + 2666; // Xor with the sign bit forcing the positive channel needed by RLV spec.
                outfitsChannel = dialogChannel + 15; // arbitrary offset
                debugSay(6, "DEBUG-DRESS", "outfits Channel set to " + (string)outfitsChannel);

            }
            else if (name == "isAFK")                              isAFK = (integer)value;
            else if (name == "RLVok")                              RLVok = (integer)value;
            else if (name == "hovertextOn")                  hovertextOn = (integer)value;
            else if (name == "dollType") {
                if (value == "") dollType = "Regular";
                else dollType = value;
            }
            else if (name == "pronounHerDoll")            pronounHerDoll = value;
            else if (name == "pronounSheDoll")            pronounSheDoll = value;
            else if (c == "c") {
                     if (name == "canDressSelf")                canDressSelf = (integer)value;
                else if (name == "collapsed")                      collapsed = (integer)value;
                else if (name == "clothingFolder")            clothingFolder = value;
            }

#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                        debugLevel = (integer)value;
#endif
            else if (c == "n") {
                     if (name == "normalselfFolder")        normalselfFolder = value;
                else if (name == "normaloutfitFolder")    normaloutfitFolder = value;
                else if (name == "nudeFolder")                    nudeFolder = value;
            }

            else if (c == "o") {
                     if (name == "outfitsFolder") {
                         outfitsFolder = value;
                         normalselfFolder   = outfitsFolder + "/~normalself";
                         normaloutfitFolder = outfitsFolder + "/~normaloutfit";
                         nudeFolder         = outfitsFolder + "/~nude";
                         lmSendConfig("normalselfFolder", normalselfFolder);
                         lmSendConfig("normaloutfitFolder", normaloutfitFolder);
                         lmSendConfig("nudeFolder", nudeFolder);
                }
            }

            else if (name == "typeFolder")                    typeFolder = value;
            else if (name == "useTypeFolder")              useTypeFolder = (integer)value;
            else if (name == "wearLock")                        wearLock = (integer)value;
            else if (name == "hardcore")                        hardcore = (integer)value;
        }
        else if (code == INTERNAL_CMD) {

            // Internal command - one of:
            //
            // * wearOutfit
            // * stripAll
            // * setHovertext
            // * carriedMenu

            string cmd = cdListElement(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "wearOutfit") {

                // Overriting a script global here... not kosher, but works.
                // Note that the value may or may NOT come from this script:
                // ergo, the reason this overwrite is here.

                newOutfitName = cdListElement(split, 0);

                // Abort if no outfit...

                if (newOutfitName == "") {
                    llSay(DEBUG_CHANNEL, "No outfit chosen to wear!");
                    return;
                }

                if (outfitsFolder != "") {
#ifdef DEVELOPER_MODE
                    // If we are in developer mode we are in danger of the key being ripped
                    // off here.  We therefore will use a temporary @detach=n restriction.
                    llOwnerSay("Developer key locked in place to prevent accidental detachment during dressing.");
                    //lmRunRLV("attachthis=y,detachthis=n,detach=n,touchall=n,showinv=n");
                    lmRunRLV("detach=n");

#else
                    // This locks down a (Normal) Dolly's touch and inventory - but
                    // there is no restore from this setting
//                  lmRunRLV("touchall=n,showinv=n");
#endif
                    tempDressingLock = TRUE;

                    dressingFailures = 0;
                    change = 1;

                    // Send a message to ourself, generate an event, and save the
                    // previous values of newOutfit* into oldOutfit* - can we do
                    // this without using a link message?
                    //
                    // *OutfitName       newOutfitName    - name of outfit
                    // *OutfitFolder     outfitsFolder    - name of main outfits folder
                    // *OutfitPath       clothingFolder   - name of folder with outfit, relative to outfitsFolder
                    // *Outfit           -new-            - full path of outfit (outfitsFolder + "/" + clothingFolder + "/" + newOutfitName)

                    // Build the newOutfit* variables - but do they get used?

                    newOutfitFolder = outfitsFolder;
                      newOutfitPath = clothingFolder;

                    newOutfit = newOutfitFolder + "/";
                    if (clothingFolder != "")
                        newOutfit += clothingFolder + "/";
                    newOutfit += newOutfitName;
                }

                //debugSay(5,"DEBUG-DRESS","newOutfit is: " + newOutfit);
                //debugSay(5,"DEBUG-DRESS","newOutfitName is: " + newOutfitName);
                //debugSay(5,"DEBUG-DRESS","newOutfitFolder is: " + newOutfitFolder);
                //debugSay(5,"DEBUG-DRESS","newOutfitPath is: " + newOutfitPath);
                //debugSay(5,"DEBUG-DRESS","clothingFolder is: " + clothingFolder);

                //----------------------------------------
                // DRESSING
                //----------------------------------------

                // Steps to dressing avi:
                //
                // Overview: Attach everything we need, and lock them afterwards.
                // Next, detach the old outfit - then detach the entire outfitsFolder
                // just in case (everything we want should be locked on). Next,
                // go through all clothing parts and detach them if possible.
                // Finally, Attach everything in the outfitsFolder just in case.
                //
                // Attach and Lock (Base):
                //
                // 1) Attach everything in the normalselfFolder
                //       (using @attachallover:=force followed by @detachallthis:=n )
                // 2) Attach everything in the nudeFolder
                //       (using @attachallover:=force followed by @detachallthis:=n )
                //
                // Attach and Lock (New Outfit):
                //
                // 3) Attach everything in the newOutfitFolder
                //       (using @attachallover:=force followed by @detachallthis:=n )
                // 4) Attach everything in the newOutfitFolder a second time
                //       (using @attachallover:=force followed by @detachallthis:=n )
                //
                // Force Detach:
                //
                // 5) Detach oldOutfitFolder
                //       (using @detachall:=force )
                // 6) Detach entire outfitsFolder
                //       (using @detachall:=force )
                // 7) Go through clothing parts and detach
                //       (using @detachallthis:=force on each part)
                //
                // Attach outfit again:
                //
                // 8) Attach everything in the newOutfitFolder a third time
                //       (using @attachallover:=force followed by @detachallthis:=n )

                // COMMENTS:
                //
                // Duplication between Step #3 and Step #4 is probably not
                // needed, and skipping Step #5 saves having to save the
                // oldOutfitFolder.  Skipping oldOutfitFolder also makes things
                // work for when the oldOutfitFolder is unknown.  Step #7 seems
                // to be overkill, as does Step #8.

                llOwnerSay("New outfit chosen: " + newOutfitName);

                //----------------------------------------
                // STEP #1

                // Restore our usual look from the ~normalself folder...

#define cdLock(a)   lmRunRLV("detachallthis:"+(a)+"=n")
#define cdUnlock(a) lmRunRLV("detachallthis:"+(a)+"=y")
#define cdAttach(a) lmRunRLV("attachallover:"+(a)+"=force") 
#define cdForceDetach(a) lmRunRLV("detachall:"+(a)+"=force");

                // This attaches ~normalself and locks it
                debugSay(2,"DEBUG-DRESS","*** STEP 1 ***");
                debugSay(2,"DEBUG-DRESS","attach and lock for normal self folder: " + normalselfFolder);
                cdAttach(normalselfFolder);

                //----------------------------------------
                // STEP #3

                // attach the new folder and lock it down - and prevent nude

                debugSay(2,"DEBUG-DRESS","*** STEP 3 ***");
                debugSay(2, "DEBUG-DRESS", "Attaching outfit from " + newOutfit);
                cdAttach(newOutfit);

                // At this point, all standard equipment should be attached,
                // and all of the new outfit should be attached. Nothing is locked.

                //----------------------------------------
                // STEP #4

                // Remove rest of old outfit (using saved folder)

                debugSay(2,"DEBUG-DRESS","*** STEP 4 ***");

                // We don't want anything in these directories to be popped off

                // Step 4a: Unlock previous locks
                if (normalselfFolder != "") { cdUnlock(normalselfFolder); }
                if (      nudeFolder != "") { cdUnlock(      nudeFolder); }

                cdUnlock(newOutfit);
                llSleep(1.0);

                // Step 4b: Lock items so they don't get thrown off
                if (normalselfFolder != "") { cdLock(normalselfFolder); }
                if (      nudeFolder != "") { cdLock(      nudeFolder); }

                cdLock(newOutfit);
                llSleep(5.0);

                // Step 4c: Remove oldOutfit or alternately entire Outfits dir
                if (oldOutfit != "") {
                    debugSay(2, "DEBUG-DRESS", "Removing old outfit from " + oldOutfit);
                    cdForceDetach(oldOutfit);
                }
                else {
                    // If no oldOutfitFolder, then just detach everything
                    // outside of the newFolder and ~normalself and ~nude
                    debugSay(2, "DEBUG-DRESS", "Removing all other outfits from " + outfitsFolder);
                    cdForceDetach(outfitsFolder);
                }
                llSleep(1.0);

                //----------------------------------------
                // STEP #5

                debugSay(2,"DEBUG-DRESS","*** STEP 5 ***");

                // Attach new outfit again
                debugSay(2, "DEBUG-DRESS", "Attaching outfit again from " + newOutfit);
                cdAttach(newOutfit);
                llSleep(1.0);

                //----------------------------------------
                // STEP #6

                debugSay(2,"DEBUG-DRESS","*** STEP 6 ***");

                // Unlock folders previously locked

                debugSay(2, "DEBUG-DRESS", "Unlocking three folders of new outfit...");

                if (normalselfFolder != "") { cdUnlock(normalselfFolder); }
                if (      nudeFolder != "") { cdUnlock(      nudeFolder); }

                cdUnlock(newOutfit);

                llSleep(1.0);

                debugSay(2,"DEBUG-DRESS","*** END DRESSING SEQUENCE ***");

                //----------------------------------------
                // STEP #7

                // Attach everything one last time - in case we knocked something off we need
                //debugSay(2, "DEBUG-DRESS", "Reattach new outfit: " + newOutfit);
                //lmRunRLV("attachall:" + newOutfit + "=force");

                oldOutfit = newOutfit;

                llListenRemove(menuDressHandle);

                changeComplete(TRUE);
                clearDresser();
            }
            else if (cmd == "resetBody") {

#ifndef ADULT_MODE
                if (normaloutfitFolder == "") return;
#endif
                // Clear old outfit settings
                oldOutfit = "";
                newOutfit = "";

                // Force attach nude elements
                if (nudeFolder)         lmRunRLV("detachthis:" + nudeFolder         + "=y,attachall:" + nudeFolder         + "=force");
                if (normalselfFolder)   lmRunRLV("detachthis:" + normalselfFolder   + "=y,attachall:" + normalselfFolder   + "=force");
                if (normaloutfitFolder) lmRunRLV("detachthis:" + normaloutfitFolder + "=y,attachall:" + normaloutfitFolder + "=force");

                // Lock default body
                if (nudeFolder)         lmRunRLV("detachthis:" + nudeFolder         + "=n");
                if (normalselfFolder)   lmRunRLV("detachthis:" + normalselfFolder   + "=n");
                if (normaloutfitFolder) lmRunRLV("detachthis:" + normaloutfitFolder + "=n");

                // Remove all else from the top, outfits and all the rest
                lmRunRLV("detachall:=force");

                // Clear locks and force attach
                if (nudeFolder)         lmRunRLV("detachthis:" + nudeFolder         + "=y,attachall:" + nudeFolder         + "=force");
                if (normalselfFolder)   lmRunRLV("detachthis:" + normalselfFolder   + "=y,attachall:" + normalselfFolder   + "=force");
                if (normaloutfitFolder) lmRunRLV("detachthis:" + normaloutfitFolder + "=y,attachall:" + normaloutfitFolder + "=force");
            }
#ifdef ADULT_MODE
            else if (cmd == "stripAll") {
                oldOutfit = "";
                newOutfit = "";

                if (nudeFolder)       lmRunRLV("detachthis:" + nudeFolder       + "=n");
                if (normalselfFolder) lmRunRLV("detachthis:" + normalselfFolder + "=n");

                lmRunRLV("detachall:" + outfitsFolder + "=force");

                if (nudeFolder)       lmRunRLV("detachthis:" + nudeFolder       + "=y,attachall:" + nudeFolder       + "=force");
                if (normalselfFolder) lmRunRLV("detachthis:" + normalselfFolder + "=y,attachall:" + normalselfFolder + "=force");
            }
#endif
            else if (cmd == "setHovertext") {
                string primText = llList2String(llGetPrimitiveParams([ PRIM_TEXT ]), 0);

                     if (collapsed)   { cdSetHovertext("Disabled Dolly!",        ( RED    )); }
                else if (isAFK)       { cdSetHovertext(dollType + " Doll (AFK)", ( YELLOW )); }
                else if (hovertextOn) { cdSetHovertext(dollType + " Doll",       ( WHITE  )); }
                else                  { cdSetHovertext("",                       ( WHITE  )); }
            }
            else if (cmd == "carriedMenu") {
                string carrierName = llList2String(split, 0);

                if (cdIsDoll(id)) {
                    msg = "You are being carried by " + carrierName + ". ";
                    if (collapsed) msg += "You need winding, too. ";
                }
                else msg = dollName + " is currently being carried by " + carrierName + ". They have full control over this doll. ";

                cdDialogListen();
                llDialog(id, msg, [ "OK" ], dialogChannel);
            }
        }
        else if (code == RLV_RESET) {

            // RLV check is resetting values

            RLVok = llList2Integer(split, 0);
        }
        else if (code == MENU_SELECTION)  {

            // Selection from menu

            string choice = cdListElement(split, 0);
            string name = cdListElement(split, 1);

            if (choice == "Outfits..." && !tempDressingLock) {
                if (!isDresser(id)) {
                    cdSayTo("You go to look in Dolly's closet for clothes, and find that " + llGetDisplayName(dresserID) + " is already there looking", id);
                    return;
                }

                debugSay(2, "DEBUG-DRESS", "Outfit menu; outfit Folder = " + outfitsFolder);
                if (wearLock) {
                    clearDresser();
                    cdDialogListen();
                    llDialog(dresserID, "Clothing was just changed; cannot change right now.", ["OK"], dialogChannel);
                    return;
                }

                if (outfitsFolder != "") {
                    debugSay(2, "DEBUG-DRESS", "Outfit menu; outfit Folder is not empty");
                    if (useTypeFolder) clothingFolder = typeFolder;
                    else clothingFolder = "";

                    lmSendConfig("clothingFolder", clothingFolder);
                    dressVia(menuDressChannel);
                }
                else {
                    clearDresser();
                    if (RLVok == TRUE) llSay(DEBUG_CHANNEL,"outfitsFolder is unset.");
                    else llSay(DEBUG_CHANNEL,"You cannot be dressed without RLV active.");
                    return;
                }
            }
            else if (choice == UPMENU) {
                // When we get here, using the Menu Reply to MAIN
                // makes no sense - it's too late for that.
                //
                // Strip out last element from slash forward
                integer lastElement;

                outfitsList = [];
                debugSay(6, "DEBUG-DRESS", "Up Menu: clothingFolder = \"" + clothingFolder + "\"");

                lastElement = uSubStringLastIndex(clothingFolder,"/");

                if (lastElement != -1) {
                    debugSay(6, "DEBUG-DRESS", "Up Menu: found separator");
                    lmSendConfig("clothingFolder", (clothingFolder = llGetSubString(clothingFolder,0,lastElement - 1)));
                }
                else {
                    // At this point, either clothingFolder has ONE item in it, or it is null.
                    // It should not be null - because that needs to go up to MAIN menu, not UPMENU.
                    //
                    // Since having one single item means no "/" we need to adjust clothingFolder manually
                    //
                    debugSay(6, "DEBUG-DRESS", "Up Menu: found no separator");
                    lmSendConfig("clothingFolder", (clothingFolder = ""));
                }

                dressVia(menuDressChannel); // recursion: put up a new Primary menu
                llSetTimerEvent(60.0);
            }
        }
        else if (code < 200) {
            if (code == SIM_RATING_CHG) {
                simRating = cdListElement(split, 0);
                integer outfitRating = cdOutfitRating(newOutfitName);
                integer regionRating = cdRating2Integer(simRating);

                debugSay(3, "DEBUG-DRESS", "Region rating " + simRating + " outfit " + newOutfitName + " outfitRating: " + (string)outfitRating +
                            " regionRating: " + (string)regionRating);
            }
            else if (code == CONFIG_REPORT) {
                cdConfigureReport();
            }
#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                memReport(cdMyScriptName(),cdListFloatElement(split, 0));
            }
#endif
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {
        // We have our answer so now we can turn the listener off until our next request

        // Request max memory to avoid constant having to bump things up and down
        //llSetMemoryLimit(65536);

        debugSay(6, "DEBUG-DRESS", "Listener called[" + (string)channel + "]: " + name + "|" + choice);

        //----------------------------------------
        // CHANNELS

        if (channel == outfitsChannel) {
            // This channel handles the responses from the Outfits menus,
            // including all outfits, Next, Prev, and Back...
            // are done by listener2665); we get here after the first menu
            // sends back a response.
            //
            // We just got a selected Outfit or new folder to go into

            // Build outfit menu: note it is using the number before the period here
            integer select = (integer)llGetSubString(choice, 0, llSubStringIndex(choice, ".") - 1);
            if (select != 0) choice = cdListElement(outfitsList, select - 1);
            // else we have a normal selection, not a numeric one

            debugSay(6, "DEBUG-DRESS", "Secondary outfits menu: choice = " + choice + "; select = " + (string)select);

            if (llGetSubString(choice, 0, 6) == "Outfits") {

                // Choice was one of:
                //
                // - Outfits Next
                // - Outfits Prev

                if (!isDresser(id)) {
                    outfitsList = [];
                    return;
                }

                if (choice == "Outfits Next") {
#ifdef ROLLOVER
                    outfitPage++;
                    if ((outfitPage - 1) * OUTFIT_PAGE_SIZE > llGetListLength(outfitsList))
                        outfitPage = 1;
#else
                    if (outfitPage * OUTFIT_PAGE_SIZE < llGetListLength(outfitsList))
                        outfitPage++;
#endif
                }
                else if (choice == "Outfits Prev") {
#ifdef ROLLOVER
                    outfitPage--;
                    if (outfitPage < 1)
                        outfitPage = llFloor((llGetListLength(outfitsList) + (OUTFIT_PAGE_SIZE / 2)) / (float)OUTFIT_PAGE_SIZE);
#else
                    if (outfitPage != 1)
                        outfitPage--;
#endif
                }

                list dialogItems = [ "Outfits Prev", "Outfits Next", "Back..." ];

                // Setting backMenu in this way is not proper: we don't know if
                // going back to the Main menu or one directory up is appropriate
                //
                //backMenu = MAIN;
                //lmSendConfig("backMenu",(backMenu = MAIN));
                //dialogItems += "Back...";

                // We only get here if we are wandering about in the same directory...
                cdDialogListen();
                outfitsHandle = cdListenAll(outfitsChannel);
                // outfitsMessage was built by the initial call to listener2666
                llDialog(dresserID, outfitsMessage, dialogSort(outfitsPage(outfitsList) + dialogItems), outfitsChannel);
                llSetTimerEvent(60.0);

            }
            else if (choice == "Back...") {
                outfitsList = [];
                lmMenuReply(backMenu, llGetDisplayName(id), id);

                // Reset to Main Menu
                //lmSendConfig("backMenu",(backMenu = MAIN));
            }
#ifdef NOT_USED
            else if (choice == MAIN) {
                outfitsList = [];
                lmMenuReply(MAIN,"",id);
            }
#endif
            else if (cdListElementP(outfitsList, choice) != NOT_FOUND) {
                // This is the actual processing of an Outfit Menu entry -
                // either a folder or a single outfit item.
                //
                // This could be entered via a menu injection by a random dress choice
                // No standard user should be entering this way anyway
                //if (!isDresser(id)) return;

                outfitsList = [];
                if ((cdGetFirstChar(choice) == ">") || (cdGetFirstChar(choice) == "*")) {

                    // if a Folder was chosen, we have to descend into it by
                    // adding the choice to the currently active folder

                    if (clothingFolder == "") clothingFolder = choice;
                    else clothingFolder += ("/" + choice);

                    debugSay(6, "DEBUG-DRESS", "Generating new list of outfits...");
                    lmSendConfig("clothingFolder", clothingFolder); // this is current folder relative to outfitsFolder
                    lmSendConfig("backMenu",(backMenu = UPMENU));
                    dressVia(menuDressChannel); // recursion: put up a new Primary menu

                    llSetTimerEvent(60.0);
                }
                else {
                    debugSay(3, "DEBUG-DRESS", "Calling wearOutfit with " + choice + " in the active folder " + activeFolder);
                    lmInternalCommand("wearOutfit", choice, NULL_KEY);
                }
            }
        }

        //----------------------------------------
        // Channel: menuDressChannel
        //
        // Choosing a new outfit normally and manually: create a paged dialog with an
        // alphabetical list of available outfits, and let the user choose one
        //
        else if (channel == menuDressChannel) {

            // Choose an outfit
            //
            // This is the first menu presented upon the activation
            // of a new folder to choose outfits from.

            llListenRemove(menuDressHandle);

            // Did we get anything at all?
            if (choice == "") {
                cdDialogListen();
                llDialog(dresserID, "No outfits to wear in this directory.", [ "OK" ], dialogChannel);
                return;
            }

            //fallbackFolder = 0;
            outfitsList = llParseString2List(choice, [","], []);

            integer n;
            string itemName;
            string prefix;
            list tmpList;

            debugSay(6, "DEBUG-DRESS", "Filtering outfit data");
            // Filter list of outfits (directories) to choose
            n = llGetListLength(outfitsList);
            while (n--) {
                itemName = cdListElement(outfitsList, n);
                prefix = cdGetFirstChar(itemName);

                if (itemName != newOutfitName) {
                    if (!isHiddenItem(prefix) && !isGroupItem(prefix)) {
                        if (!isTransformingItem(prefix) || dollType == "Regular") {
                            if (isRated(prefix)) {
                                if (cdOutfitRating(itemName) <= cdRating2Integer(simRating)) {
                                    tmpList += itemName;
                                }
                            }
                            else {
                                tmpList += itemName;
                            }
                        }
                    }
                }
            }

            outfitsList = tmpList;
            tmpList = [];

            debugSay(6, "DEBUG-DRESS", "Filtered list = " + llDumpList2String(outfitsList,","));
            // we've gone through and cleaned up the list - but is anything left?
            if (outfitsList == []) {
                outfitsList = []; // free memory
                cdDialogListen();
                llDialog(dresserID, "No wearable outfits in this directory.", [ "OK" ], dialogChannel);
                return;
            }

            // Sort: slow bubble sort
            outfitsList = llListSort(outfitsList, 1, TRUE);

            // Now create appropriate menu page from full outfits list
            outfitPage = 1;

            list newOutfitsList = outfitsPage(outfitsList);

            if (llGetListLength(outfitsList) < 10) newOutfitsList += [ "-", "-" ];
            else newOutfitsList += [ "Outfits Prev", "Outfits Next" ];
            newOutfitsList += [ "Back..." ];

            if (dresserID == dollID) outfitsMessage = "You may choose any outfit to wear. See the help file for more detailed information on outfits.";
            else outfitsMessage = "You may choose any outfit for dolly to wear. ";

            outfitsMessage += "\n\n" + folderStatus();

            // Provide a dialog to user to choose new outfit
            cdDialogListen();
            //outfitsHandle = cdListenAll(outfitsChannel);
            cdListenAll(outfitsChannel);

            if (clothingFolder == "") lmSendConfig("backMenu",(backMenu = MAIN));
            else lmSendConfig("backMenu",(backMenu = UPMENU));

            llDialog(dresserID, outfitsMessage, dialogSort(newOutfitsList), outfitsChannel);

            llSetTimerEvent(60.0);
            newOutfitsList = [];
        }

        //scaleMem();
    }
}

//========== DRESS ==========
