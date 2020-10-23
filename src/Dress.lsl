//========================================
// Dress.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

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
#define dressViaMenu() listInventoryOn(menuDressChannel)
#define dressViaRandom() listInventoryOn(randomDressChannel)
#ifdef CONFIRM_WEAR
#define checkWornItems(c) rlvRequest("getinvworn:" + (c) + "=", confirmWearChannel)
#endif
#ifdef CONFIRM_UNWEAR
#define checkRemovedItems(c) rlvRequest("getinvworn:" + (c) + "=", confirmUnwearChannel)
#endif

//========================================
// VARIABLES
//========================================

//string bigsubfolder = "dressup"; //name of subfolder in RLV to always use if available. But also checks for outfits.

// FIXME: This should be in a notecard so it can be changed without mangling the scripts.
string outfitsURL = "outfits.htm";
string outfitsMessage;
string msg;

string prefix;

integer tempDressingLock = FALSE;  // allow only one dressing going on at a time

#ifdef NOT_USED
integer dressingSteps;             // are all attempts to dress complete?
#endif

//key setupID = NULL_KEY;

string newOutfitName;
string newOutfitFolder;
string newOutfitPath;

string oldOutfitName;
string oldOutfitFolder;
string oldOutfitPath;

// New simple listener setup we only
// listen to rlvChannel directly the
// other we use MenuHandlers link 500's
integer rlvBaseChannel;
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
string normalselfFolder = "~normalself"; // This is the ~normalself we are using
string nudeFolder = "~nude"; // This is the ~nude we are using

integer randomDressHandle;
integer randomDressChannel;
integer menuDressHandle;
integer menuDressChannel;
#ifdef CONFIRM_WEAR
integer confirmWearHandle;
integer confirmWearChannel;
#endif
#ifdef CONFIRM_UNWEAR
integer confirmUnwearHandle;
integer confirmUnwearChannel;
#endif

//integer fallbackFolder;

//integer startup = 1;
integer dressingFailures;

integer outfitPage; // zero-indexed

//string oldattachmentpoints;
//string oldclothespoints;
//integer newOutfitWordEnd;

#define OUTFIT_PAGE_SIZE 9

//========================================
// FUNCTIONS
//========================================
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
    dressViaRandom(); // recursion
}

rlvRequest(string rlv, integer channel) {

    if (channel < 2670) {
        llSay(DEBUG_CHANNEL,"rlvRequest called with old channel numbers");
             if (channel == 2665)   randomDressHandle = cdListenMine(  randomDressChannel);
        else if (channel == 2666)     menuDressHandle =  cdListenAll(    menuDressChannel);
#ifdef CONFIRM_WEAR
        else if (channel == 2668)   confirmWearHandle = cdListenMine(  confirmWearChannel);
#endif
#ifdef CONFIRM_UNWEAR
        else if (channel == 2669) confirmUnwearHandle = cdListenMine(confirmUnwearChannel);
#endif

        lmRunRLV(rlv + (string)(rlvBaseChannel + channel));
    }
    else {
             if (channel ==   randomDressChannel)   randomDressHandle = cdListenMine(  randomDressChannel);
        else if (channel ==     menuDressChannel)     menuDressHandle =  cdListenAll(    menuDressChannel);
#ifdef CONFIRM_WEAR
        else if (channel ==   confirmWearChannel)   confirmWearHandle = cdListenMine(  confirmWearChannel);
#endif
#ifdef CONFIRM_UNWEAR
        else if (channel == confirmUnwearChannel) confirmUnwearHandle = cdListenMine(confirmUnwearChannel);
#endif

        lmRunRLV(rlv + (string)channel);
    }

    llSetTimerEvent(30.0);
}

listInventoryOn(integer channel) {

    if (outfitsFolder == "") {
        llOwnerSay("No suitable outfits folder found, so unfortunately you will not be able to be dressed");
        return;
    }

    // activeFolder is the folder (full path) we are looking at with our Menu
    // outfitsFolder is where all outfits are stored, including
    //     ~normalself, ~nude, and all the type folders
    // clothingFolder is the current folder for clothing, relative
    //     to the outfitsFolder

    activeFolder = outfitsFolder;
    if (clothingFolder != "") activeFolder += "/" + clothingFolder;

#ifdef DEVELOPER_MODE
    //llSay(DEBUG_CHANNEL,"listing inventory on " + (string)channel + " with active folder " + activeFolder);
    debugSay(4, "DEBUG-DRESS", "Setting activeFolder (in listInventory) to " + activeFolder);
#endif
    lmSendConfig("activeFolder", activeFolder);

    rlvRequest("getinv:" + activeFolder + "=", channel);
}

integer isDresser(key id) {
    if (dresserID == NULL_KEY || llGetAgentSize(dresserID) == ZERO_VECTOR) {
        // No dresser currently: set it to id

        // check if id is something other than an avatar: and fake up TRUE val if so
        if (llGetAgentSize(id) == ZERO_VECTOR) return TRUE;

        dresserID = id;
        dresserName = llGetDisplayName(dresserID);

        if (!cdIsDoll(dresserID))
            if (!hardcore)
                llOwnerSay("secondlife:///app/agent/" + (string)dresserID + "/about is looking at your dress menu");
    }
    else if (dresserID != id) {
        cdSayTo("You go to look in Dolly's closet for clothes, and find that " + dresserName + " is already there looking", id);
        return FALSE;
    }

    // dresserID == id .... therefore, id IS the dresser...
    return TRUE;
}

changeComplete(integer success) {
    // And remove the temp locks we used
#ifdef DEVELOPER_MODE
    llOwnerSay("Your key is now unlocked again as you are a developer.");
    lmRunRLV("clear");
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

    dresserID = NULL_KEY;
    dresserName = "";
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
        ; //startup = 2;
    }


#ifdef NOT_USED
    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
        // This is triggered when a dressing times out
        llSay(DEBUG_CHANNEL,"Dress timer tripped: failed to change to " + newOutfitName);

        llListenRemove(randomDressHandle);
        llListenRemove(menuDressHandle);
#ifdef CONFIRM_WEAR
        llListenRemove(confirmWearHandle);
#endif
#ifdef CONFIRM_UNWEAR
        llListenRemove(confirmUnwearHandle);
#endif
        changeComplete(FALSE);
    }
#endif

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

        scaleMem();

        if (code == CONFIG) {
            string name = cdListElement(split, 0);
            string value = cdListElement(split, 1);
            string c = cdGetFirstChar(name);

            if (llListFindList([ "a", "R", "h", "p", "c", "d", "n", "t", "w", "o", "u" ], (list)c) == NOT_FOUND) return;

            if (name == "dialogChannel") {
                dialogChannel = (integer)value;
                rlvBaseChannel = dialogChannel ^ 0x80000000; // Xor with the sign bit forcing the positive channel needed by RLV spec.
                outfitsChannel = dialogChannel + 15; // arbitrary offset

                randomDressChannel = rlvBaseChannel + 2665;
                  menuDressChannel = rlvBaseChannel + 2666;
#ifdef CONFIRM_WEAR
                confirmWearChannel = rlvBaseChannel + 2668;
#endif
#ifdef CONFIRM_UNWEAR
              confirmUnwearChannel = rlvBaseChannel + 2669;
#endif
            }
            else if (name == "afk")                                  afk = (integer)value;
            else if (name == "RLVok")                              RLVok = (integer)value;
            else if (name == "hovertextOn")                  hovertextOn = (integer)value;
            else if (name == "dollType")                        dollType = value;
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
                else if (name == "nudeFolder")                    nudeFolder = value;
//              else if (name == "newOutfitName")              newOutfitName = value;
//              else if (name == "newOutfitFolder")          newOutfitFolder = value;
//              else if (name == "newOutfitPath")              newOutfitPath = value;
//              else if (name == "newOutfit")                      newOutfit = value;
            }

            else if (c == "o") {
                     if (name == "outfitsFolder")              outfitsFolder = value;
                else if (name == "oldOutfitFolder")          oldOutfitFolder = value;
                else if (name == "oldOutfitPath")              oldOutfitPath = value;
                else if (name == "oldOutfitName")              oldOutfitName = value;
                else if (name == "oldOutfit")                      oldOutfit = value;
            }

            else if (name == "typeFolder")                    typeFolder = value;
            else if (name == "useTypeFolder")              useTypeFolder = (integer)value;
            else if (name == "wearLock")                        wearLock = (integer)value;
            else if (name == "hardcore")                        hardcore = (integer)value;
        }
        else if (code == INTERNAL_CMD) {
            string cmd = cdListElement(split, 0);
            split = llDeleteSubList(split, 0, 0);

            // Choose an (appropriate) random outfit and put it on
            //
            if (cmd == "randomDress") {
                // this makes it easier, and we don't have to be "afraid" to call the
                // randomDress function.
#ifdef DEVELOPER_MODE
                llSay(DEBUG_CHANNEL,"randomDress executing");
#endif
                if (RLVok == FALSE) {
#ifdef DEVELOPER_MODE
                    llSay(DEBUG_CHANNEL,"randomDress rejected: no RLV set");
#endif
                    return;
                }

                debugSay(6, "DEBUG-DRESS", "Random dress outfit chosen automatically");

                if (tempDressingLock) {
                    llRegionSayTo(dresserID, 0, "Dolly cannot be dressed right now; " + pronounSheDoll + " is already dressing");
                }
                else {
                    if (useTypeFolder) clothingFolder = typeFolder;
                    else clothingFolder = "";

                    lmSendConfig("clothingFolder", clothingFolder);
                    dressViaRandom();
                }
            }
            else if (cmd == "wearOutfit") {
                // Overriting a script global here... not kosher, but works.
                // Note that the value may or may NOT come from this script:
                // ergo, the reason this overwrite is here.
                newOutfitName = cdListElement(split, 0);

                if (newOutfitName == "") {
                    llSay(DEBUG_CHANNEL, "No outfit chosen to wear!");
                    return;
                }

                if (outfitsFolder != "") {
#ifdef DEVELOPER_MODE
                    // If we are in developer mode we are in danger of the key being ripped
                    // off here.  We therefore will use a temporary @detach=n restriction.
                    llOwnerSay("Developer key locked in place to prevent accidental detachment during dressing.");
                    lmRunRLV("attachthis=y,detachthis=n,detach=n,touchall=n,showinv=n");

#else
                    // This locks down a (Normal) Dolly's touch and inventory - but
                    // there is no restore from this setting
//                  lmRunRLV("touchall=n,showinv=n");
#endif
                    tempDressingLock = TRUE;

#ifdef NOT_USED
                    // dressingSteps is used to track whether all listener code paths
                    // for dressing have been done: that is, normalself attached,
                    // new outfit attached, and old outfit removed. (It does NOT include
                    // nude folder.)
                    dressingSteps = 0;
#endif

                    dressingFailures = 0;
                    change = 1;

                    // Send a message to ourself, generate an event, and save the
                    // previous values of newOutfit* into oldOutfit* - can we do
                    // this without using a link message?
                    //
                    // *OutfitName       choice           - name of outfit
                    // *OutfitFolder     outfitsFolder    - name of main outfits folder
                    // *OutfitPath       clothingFolder   - name of folder with outfit, relative to outfitsFolder
                    // *Outfit           -new-            - full path of outfit (outfitsFolder + "/" + clothingFolder + "/" + choice)

                    lmSendConfig("oldOutfitName",   (  oldOutfitName = newOutfitName));
                    lmSendConfig("oldOutfitFolder", (oldOutfitFolder = newOutfitFolder));
                    lmSendConfig("oldOutfitPath",   (  oldOutfitPath = newOutfitPath));
                    lmSendConfig("oldOutfit",       (      oldOutfit = newOutfit));

                    // Build the newOutfit* variables - but do they get used?

                    //  newOutfitName = choice;
                    newOutfitFolder = outfitsFolder;
                      newOutfitPath = clothingFolder;

                    newOutfit = newOutfitFolder + "/";
                    if (clothingFolder != "")
                        newOutfit += clothingFolder + "/";
                    newOutfit += newOutfitName;

//                  lmSendConfig("newOutfitName",   (newOutfitName));
//                  lmSendConfig("newOutfitFolder", (newOutfitFolder));
//                  lmSendConfig("newOutfitPath",   (newOutfitPath));
//                  lmSendConfig("newOutfit",       (newOutfit));
                }

                //newOutfitWordEnd = llStringLength(newOutfit)  - 1;

                //llOwnerSay("newOutfit is: " + newOutfit);
                //llOwnerSay("newOutfitName is: " + newOutfitName);
                //llOwnerSay("choice is: " + choice);
                //llOwnerSay("clothingFolder is: " + clothingFolder);

                //----------------------------------------
                // DRESSING
                //----------------------------------------

                // Steps to dressing avi:
                //
                // Overview: Attach everything we need, and lock them afterwards. Next, detach the old outfit - then detach
                // the entire outfitsFolder just in case (everything we want should be locked on). Next, go through all
                // clothing parts and detach them if possible. Finally, Attach everything in the outfitsFolder just in case.
                //
                // Attach and Lock:
                //
                // 1) Attach everything in the normalselfFolder (using @attachallover:=force followed by @detachallthis:=n )
                // 2) Attach everything in the nudeFolder (using @attachallover:=force followed by @detachallthis:=n )
                // 3) Attach everything in the newOutfitFolder (using @attachallover:=force followed by @detachallthis:=n )
                // 4) Attach everything in the newOutfitFolder a second time (using @attachallover:=force followed by @detachallthis:=n )
                //
                // Force Detach:
                //
                // 5) Detach oldOutfitFolder (using @detachall:=force )
                // 6) Detach entire outfitsFolder (using @detachall:=force )
                // 7) Go through clothing parts and detach (using @detachallthis:=force on each part)
                //
                // Attach outfit again:
                //
                // 8) Attach everything in the newOutfitFolder a third time (using @attachallover:=force followed by @detachallthis:=n )

                llOwnerSay("New outfit chosen: " + newOutfitName);

                // Restore our usual look from the ~normalself folder...
#define cdAttachAndLock(a) lmRunRLV("attachallover:"+(a)+"=force,detachallthis:"+(a)+"=n")

                // This attaches ~normalself and locks it
                cdAttachAndLock(normalselfFolder);

                if (nudeFolder != "") {
                    // this attaches the ~nude folder
                    cdAttachAndLock(nudeFolder);
                }
#ifdef DEVELOPER_MODE
                else {
                    llSay(DEBUG_CHANNEL,"nudeFolder is empty! (no nude folder attached)");
                }
#endif
                    
                // attach the new folder and lock it down - and prevent nude
                debugSay(2, "DEBUG-DRESS", "Attaching outfit from " + newOutfit);
                cdAttachAndLock(newOutfit);
                llSleep(5.0);

                // repeat for good measure
                debugSay(2, "DEBUG-DRESS", "Attaching outfit again from " + newOutfit);
                cdAttachAndLock(newOutfit);

                // At this point, all of ~normalself, ~nude, and newOutfit have been added and locked
                // We should be fully clothed and set with every thing we need - BUT we have to
                // remove the old...

                // Remove rest of old outfit (using saved path)
                if (oldOutfitPath != "") {
                    lmRunRLV("detachall:" + oldOutfitPath + "=force");
                    oldOutfitPath = "";
                }
#ifdef DEVELOPER_MODE
                //else llSay(DEBUG_CHANNEL,"no old outfit path!");
#endif
                // Now remove everything in the outfits folder (typeically "> Outfits")
                // which is not locked down - and then attach everything in the new outfit
                // again
                lmRunRLV("detachall:" + outfitsFolder + "=force");

                // And now send an attempt to clean up any remaining stray pieces: remove rest of
                // clothing not otherwise locked
                list parts = [ "gloves","jacket","pants","shirt",
                               "shoes","skirt","socks","underpants",
                               "undershirt","alpha","pelvis","left foot",
                               "right foot","r lower leg","l lower leg",
                               "r forearm","l forearm","r upper arm",
                               "l upper arm","r upper leg","l upper leg" ];

                lmRunRLV("detachallthis:" + llDumpList2String(parts, "=force,detachallthis:") + "=force");

                // Attach everything one last time - in case we knocked something off we need
                lmRunRLV("attachall:" + newOutfit + "=force");

#ifdef CONFIRM_WEAR
                // check to see that everything in the ~normalself folder is
                // actually worn
                wearFolder = normalselfFolder;
                checkWornItems(wearFolder);

#endif
#ifdef CONFIRM_UNWEAR
                // check to see that everything in the old Outfit folder is
                // actually removed
                unwearFolder = oldOutfitPath;
                if (unwearFolder != "") checkRemovedItems(unwearFolder);
                else dressingSteps += 2;
#endif
                //llSetTimerEvent(15.0);

                llListenRemove(randomDressHandle);
                llListenRemove(menuDressHandle);

                changeComplete(TRUE);
            }
            else if (cmd == "stripAll") {
                if (nudeFolder)
                    lmRunRLV("detachthis:" + nudeFolder + "=n");
                if (normalselfFolder)
                    lmRunRLV("detachthis:" + normalselfFolder + "=n");

                lmRunRLV("detachall:" + outfitsFolder + "=force");

                if (nudeFolder)
                    lmRunRLV("detachthis:" + nudeFolder + "=y,attachall:" + nudeFolder + "=force");
                if (normalselfFolder)
                    lmRunRLV("detachthis:" + normalselfFolder + "=y,attachall:" + normalselfFolder + "=force");
            }
            else if (cmd == "setHovertext") {
                string primText = llList2String(llGetPrimitiveParams([ PRIM_TEXT ]), 0);

                     if (collapsed)   { cdSetHovertext("Disabled Dolly!",        ( RED    )); }
                else if (afk)         { cdSetHovertext(dollType + " Doll (AFK)", ( YELLOW )); }
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
            RLVok = (cdListIntegerElement(split, 0) == 1);
        }
        // Choice #500: (From Main Menu) Dress Dolly
        else if (code == MENU_SELECTION)  {
            string choice = cdListElement(split, 0);
            string name = cdListElement(split, 1);

            if (choice == "Outfits..." && !tempDressingLock) {
                if (id) {
                    if (!isDresser(id)) return;
                }

                if (wearLock) {
                    cdDialogListen();
                    llDialog(dresserID, "Clothing was just changed; cannot change right now.", ["OK"], dialogChannel);
                    return;
                }

                if (outfitsFolder != "") {
                    if (useTypeFolder) clothingFolder = typeFolder;
                    else clothingFolder = "";

                    lmSendConfig("clothingFolder", clothingFolder);
                    dressViaMenu();
                }
                else {
                    cdDialogListen();
                    llDialog(dresserID, "No outfits in this directory.", [ "OK", "Options...", MAIN ], dialogChannel);
                    //llDialog(dresserID, "You look in " + pronounHerDoll + " closet, and see no outfits for Dolly to wear.", ["OK"], dialogChannel);
                    return;
                }
            }
        }
        else if (code < 200) {
            //if (code == 102) {
            //    ;
            //}

            // else if (code == 104) {
            //     if (script != "Start") return;
            //     startup = 1;
            // }
            // else if (code == 105) {
            //     if (script != "Start") return;
            //     startup = 2;
            // }
            // else if (code == 110) {
            //     initState = 105;
            // }

                 if (code == MEM_REPORT) {
                memReport(cdMyScriptName(),cdListFloatElement(split, 0));
            }
            else if (code == CONFIG_REPORT) {

                cdConfigureReport();

            }
            else if (code == SIM_RATING_CHG) {
                simRating = cdListElement(split, 0);
                integer outfitRating = cdOutfitRating(newOutfitName);
                integer regionRating = cdRating2Integer(simRating);

                debugSay(3, "DEBUG-DRESS", "Region rating " + simRating + " outfit " + newOutfitName + " outfitRating: " + (string)outfitRating +
                            " regionRating: " + (string)regionRating);

                if (RLVok == TRUE) {
                    if (outfitRating > regionRating) {
                        pushRandom = 1;
                        clothingFolder = newOutfitPath;
                        dressViaRandom();
                    }
                }
            }
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {
        // We have our answer so now we can turn the listener off until our next request

        // Request max memory to avoid constant having to bump things up and down
        llSetMemoryLimit(65536);

        if (channel == outfitsChannel) {
            // The first menu is generated by listener2666 (randome outfits
            // are done by listener2665); we get here after the first menu
            // sends back a response.
            //
            // We just got a selected Outfit or new folder to go into

            //outfitsMessage = "You may choose any outfit for " + pronounHerDoll + " to wear. ";
            //if (dresserID == dollID) outfitsMessage += "See " + WEB_DOMAIN + outfitsURL + " for more information on outfits. ";
            //outfitsMessage += "\n\n" + folderStatus();

            // Build outfit menu: note it is using the number before the period here
            integer select = (integer)llGetSubString(choice, 0, llSubStringIndex(choice, ".") - 1);
            if (select != 0) choice = cdListElement(outfitsList, select - 1);
            // else we have a normal selection, not a numeric one

            debugSay(6, "DEBUG-DRESS", "Secondary outfits menu: choice = " + choice + "; select = " + (string)select);

            if (llGetSubString(choice, 0, 6) == "Outfits") {
                // Choice was one of:
                //
                // Outfits Next
                // Outfits Prev
                // Outfits Parent

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

                list dialogItems = [ "Outfits Prev", "Outfits Next" ];
                backMenu = MAIN;
                dialogItems += "Back...";

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
                lmSendConfig("backMenu",(backMenu = MAIN));
            }
            else if (choice == MAIN) {
                outfitsList = [];
                lmMenuReply(MAIN,"",id);
            }
            else if (cdListElementP(outfitsList, choice) != NOT_FOUND) {
                // This is the actual processing of an Outfit Menu entry -
                // either a folder or a single outfit item.
                //
                // This could be entered via a menu injection by a random dress choice
                // No standard user should be entering this way anyway
                //if (!isDresser(id)) return;

                outfitsList = [];
                if (isParentFolder(cdGetFirstChar(choice))) {

                    // if a Folder was chosen, we have to descend into it by
                    // adding the choice to the currently active folder

                    if (clothingFolder == "") clothingFolder = choice;
                    else clothingFolder += ("/" + choice);

                    lmSendConfig("clothingFolder", clothingFolder);
                    dressViaMenu(); // recursion: put up a new Primary menu

                    llSetTimerEvent(60.0);
                    return;
                }

                debugSay(3, "DEBUG-DRESS", "Calling wearOutfit with " + choice + " in the active folder " + activeFolder);
                lmInternalCommand("wearOutfit", choice, NULL_KEY);
            }
        }

        // channels:
        //
        // 2665: choose outfit at Random
        // 2666: choose outfit Manually (by user)
        // 2668:
        // 2669:

        //----------------------------------------
        // Channel: 2665
        //
        // Switched doll types: grab a new (appropriate) outfit at random and change to it
        //
        else if (channel == randomDressChannel) {

            llListenRemove(randomDressHandle);
            outfitsList = llParseString2List(choice, [","], []);
            debugSay(6, "DEBUG-CLOTHING", "Choosing random outfit (from: " + choice + ")");
#ifdef DEVELOPER_MODE
            llSay(DEBUG_CHANNEL,"Choosing random outfit from " + choice);
#endif

            integer n;

            // May never occur: other directories, hidden directories and files,
            // and hidden UNIX files all take up space here.

            if (outfitsList == []) {   // folder is bereft of files, switching to regular folder

                // No files found; leave the prefix alone and don't change
                llOwnerSay("There are no outfits in your " + activeFolder + " folder.");

                // Didnt find any outfits in the standard folder, try the
                // "extended" folder containing (we hope) outfits....

                if (outfitsFolder != "" && clothingFolder != "") {
                    retryDirSearch();
                    return;
                }
            }
            else {
                // Outfits (theoretically) found: change to one
                //
                // This is where the actual chosing of a random outfit takes place

                string itemName;
                string prefix;
                integer simrating = cdRating2Integer(simRating);
                list tmpList;

                // Filter directory contents
                //
                // Rule out the following:
                //     ~item - Hidden item (including ~nude and ~normalself)
                //     *item - Clothing for transformed doll of a particular type
                //     #item - Group items
                //     {x}item - Rated item: filter by rating
                //
                n = llGetListLength(outfitsList);
                while (n--) {
                    itemName = cdListElement(outfitsList, n);
                    prefix = llGetSubString(itemName,0,0);

                    // skip hidden files/directories and skip
                    // Doll Type (Transformation) folders...
                    //
                    // Note this skips *Regular too
                    //
                    // This (sort of) odd sequence imposes short-cut operations

                    if (!isHiddenItem(prefix)) {            // ~foo
                        if (!isTransformingItem(prefix)) { // *foo
                            if (!isGroupItem(prefix)) {    // #foo
                                if (isRated(prefix)) {     // {x}foo -- this test avoids function call
                                    if (!(cdOutfitRating(itemName) > simrating)) {
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
                tmpList = []; // free memory

                // check the filtered list...
                if (outfitsList == []) {
                    // Nothing received (total == 0); try another
                    // folder, if any; note that the total includes
                    // "marked" folders (with ">") as well as "normal"
                    // folders (containing clothing)

                    outfitsList = []; // make sure to remove ref and clear memory
                    if (pushRandom && clothingFolder != "") {
                        retryDirSearch();
                    }
                    else pushRandom = 0;
                    return;
                }

                // Pick outfit (or directory) at random
                string randomOutfitName;

                randomOutfitName = cdListElement(outfitsList, (integer)llFrand(llGetListLength(outfitsList)));

                // Folders are NOT filtered out; this is so we can descend into sub-directories
                // and select items within them. Directories are marked with an initial ">" character
                if (llGetSubString(randomOutfitName, 0, 0) != ">") {

                    // Here.....
                    outfitsHandle = cdListenAll(outfitsChannel);
                    debugSay(3, "DEBUG-DRESS", "Calling wearOutfit with random outfit " + randomOutfitName + " in the active folder " + activeFolder);
                    lmInternalCommand("wearOutfit", randomOutfitName, NULL_KEY);

                    llOwnerSay("You are being dressed in this outfit: " + randomOutfitName);
                }
                else {
                    clothingFolder += "/" + randomOutfitName;
                    dressViaRandom(); // recursion
                }

                pushRandom = 0;
            }
        }

        //----------------------------------------
        // Channel: 2666
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
                //llDialog(dresserID, "You gaze into " + pronounHerDoll + " closet, and see no outfits for Dolly to wear.", ["OK"], dialogChannel);
                llDialog(dresserID, "No outfits to wear in this directory.", [ "OK", MAIN ], dialogChannel);
                return;
            }

            //fallbackFolder = 0;
            outfitsList = llParseString2List(choice, [","], []);

            integer n;
            string itemName;
            string prefix;
            list tmpList;
            integer totalOutfits;

            // Filter list of outfits (directories) to choose
            n = llGetListLength(outfitsList);
            while (n--) {
                itemName = cdListElement(outfitsList, n);
                prefix = cdGetFirstChar(itemName);

                if (itemName != newOutfitName) {
                    if (!isHiddenItem(prefix) &&
                        !isGroupItem(prefix) &&
                        !isTransformingItem(prefix)) {

                        if (isRated(prefix)) {
                            if (cdOutfitRating(itemName) <= cdRating2Integer(simRating)) {
                                tmpList += itemName;
                            }
                        }
                        else {
                            if (!isParentFolder(prefix)) totalOutfits++;
                            tmpList += itemName;
                        }
                    }
                }
            }

            outfitsList = tmpList;
            tmpList = [];

            // we've gone through and cleaned up the list - but is anything left?
            if (outfitsList == []) {
                outfitsList = []; // free memory
                cdDialogListen();
                llDialog(dresserID, "No wearable outfits in this directory.", [ "OK", MAIN, "Outfits..." ], dialogChannel);
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

            if (dresserID == dollID) outfitsMessage = "You may choose any outfit to wear. ";
            else outfitsMessage = "You may choose any outfit for dolly to wear. ";

            //if (totalOutfits > 0) outfitsMessage += ("There are " + (string)totalOutfits + " outfits to choose from. ");
#ifdef DEVELOPER_MODE
            //else llSay(DEBUG_CHANNEL,"No outfits in this directory?");
#endif
            if (dresserID == dollID) outfitsMessage += "See " + WEB_DOMAIN + outfitsURL + " for more detailed information on outfits. ";
            outfitsMessage += "\n\n" + folderStatus();

            // Provide a dialog to user to choose new outfit
            cdListenAll(outfitsChannel);
            lmSendConfig("backMenu",(backMenu = MAIN));
            llDialog(dresserID, outfitsMessage, dialogSort(newOutfitsList), outfitsChannel);

            llSetTimerEvent(60.0);
            newOutfitsList = [];
        }

#ifdef CONFIRM_WEAR
        //----------------------------------------
        // Channel: 2668
        //
        // Check to see if all items are fully worn; if not, try again
        //
        else if (channel == confirmWearChannel) {

            llListenRemove(confirmWearHandle);

            debugSay(6, "DEBUG-DRESS", "Checking for fully worn: " + wearFolder);

            string c1 = llGetSubString(choice,1,1);
            string c2 = llGetSubString(choice,2,2);

            if (((c1 != "0" && c1 != "3") ||
                 (c2 != "0" && c2 != "3")) &&
                ++dressingFailures <= MAX_DRESS_FAILURES) {

                // Try to attach again
                string rlvCmd = "detachallthis:" + outfitsFolder + "=n,attachallover:" + wearFolder + "=force";
                if (!canDressSelf || hardcore || afk || collapsed || wearLock) rlvCmd = "attachallthis:=y," + rlvCmd + ",attachallthis:=n";
                lmRunRLV(rlvCmd);

                checkWornItems(wearFolder);
                canDressTimeout++;
            }
            else if (dressingFailures > MAX_DRESS_FAILURES) {
                llSay(DEBUG_CHANNEL,"Some things in " + wearFolder + " failed to attach");
                changeComplete(FALSE);
            }
            else {
                // Everything was attached successfully...
                dressingSteps++;

                // If we just attached all our normalself, then attach all of our
                // new outfit
                if (wearFolder == normalselfFolder && newOutfitPath != "") wearFolder = newOutfit;
                else wearFolder = "";

                // Do the new outfit folder (with full path)
                if (wearFolder != "") checkWornItems(wearFolder);
                else if (dressingSteps >= 3) changeComplete(TRUE);
            }
            debugSay(6, "DEBUG", "canDressTimeout = " + (string)canDressTimeout + ", dressingSteps = " + (string)dressingSteps);
        }

#endif
#ifdef CONFIRM_UNWEAR
        //----------------------------------------
        // Channel: 2669
        //
        // Check to see if all items are fully removed; if not, try again
        //
        else if (channel == confirmUnwearChannel) {
            string c1 = llGetSubString(choice,1,1);
            string c2 = llGetSubString(choice,2,2);

            llListenRemove(confirmUnwearHandle);

            debugSay(6, "DEBUG-DRESS", "Checking for fully removed: " + unwearFolder);


            // @getinv worn returns a coded message: test to see that
            // nothing in the folder or any subfolders is being worn:
            // that is, ALL have been removed...

            if (((c1 != "0" && c1 != "1") ||
                 (c2 != "0" && c2 != "1")) &&
                ++dressingFailures <= MAX_DRESS_FAILURES) {

                string rlvCmd = "attachallthis:" + outfitsFolder + "=n,detachall:" + unwearFolder + "=force";
                // Try again: attach stuff in the outfitsFolder, and remove things in unwearFolder
                if (!canDressSelf || hardcore || afk || collapsed || wearLock) rlvCmd = "detachallthis:=y," + rlvCmd + "detachallthis:=n";
                lmRunRLV(rlvCmd);

                checkRemovedItems(unwearFolder);
                canDressTimeout++;
            }
            else if (dressingFailures > MAX_DRESS_FAILURES) {
                llSay(DEBUG_CHANNEL,"Some things in " + unwearFolder + " failed to remove");
                changeComplete(FALSE);
            }
            else {
                // all items successfully removed
                dressingSteps++;
                if (dressingSteps >= 3) changeComplete(TRUE);
            }

            debugSay(6, "DEBUG-DRESS", "canDressTimeout = " + (string)canDressTimeout + ", dressingSteps = " + (string)dressingSteps);
        }
#endif

        scaleMem();
    }
}

//========== DRESS ==========
