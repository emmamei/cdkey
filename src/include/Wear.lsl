//========================================
// Wear.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl

#define rlvLockKey()    lmRunRlv("detach=n")
#define rlvUnlockKey()  lmRunRlv("detach=y")

#define cdLock(a)   lmRunRlv("detachallthis:"+(a)+"=n")
#define cdUnlock(a) lmRunRlv("detachallthis:"+(a)+"=y")
#define cdAttach(a) lmRunRlv("attachallover:"+(a)+"=force") 
#define cdWear(a) lmRunRlv("attach:"+(a)+"=force") 
#define cdForceDetach(a) lmRunRlv("detachall:"+(a)+"=force");

//========================================
// VARIABLES
//========================================

string newOutfitName;
string newOutfit;
string oldOutfit;

//========================================
// FUNCTIONS
//========================================

wearStandardOutfit(string newOutfit) {
    // newOutfit uses full path relative to #RLV

    outfitAvatar = FALSE;

    // Steps to dressing avi:
    //
    // Overview: Attach everything we need, and lock them afterwards.
    // Next, detach the old outfit - then detach the entire outfitMasterFolder
    // just in case (everything we want should be locked on).
    //
    // Attach and Lock (New Outfit):
    //
    // 1) Attach everything in the newOutfitFolder
    //       (using @attachallover:=force followed by @detachallthis:=n )
    //
    // Force Detach:
    //
    // 2) Detach oldOutfitFolder, or entire outfitMasterFolder
    //       (using @detachall:=force )
    //
    // Attach outfit again:
    //
    // 3) Attach everything in the newOutfitFolder a third time
    //       (using @attachallover:=force followed by @detachallthis:=n )
    //
    // 4) Undo all locks...

    //----------------------------------------
    // STEP #1

    // Attach the new folder

    debugSay(2,"DEBUG-DRESS","*** STEP 1 ***");
    debugSay(2, "DEBUG-DRESS", "Attaching outfit from " + newOutfit);
    cdAttach(newOutfit);

    // At this point, all standard equipment should be attached,
    // and all of the new outfit should be attached. Nothing is locked.

    //----------------------------------------
    // STEP #2

    // Remove rest of old outfit (using saved folder)

    debugSay(2,"DEBUG-DRESS","*** STEP 2 ***");

    // Lock items so they don't get thrown off
    if (normalselfFolder != "") { cdLock(normalselfFolder); }
    if (      nudeFolder != "") { cdLock(      nudeFolder); }

    cdLock(newOutfit);

    debugSay(2,"DEBUG-DRESS","oldOutfit == \"" + oldOutfit + "\"");

    // We don't want anything in these folders to be popped off

    // Step 2: Remove oldOutfit or alternately entire Outfits folder
    if (oldOutfit != "") {
        debugSay(2, "DEBUG-DRESS", "Removing old outfit from " + oldOutfit);
        cdForceDetach(oldOutfit);
    }
    else {
        // If no oldOutfitFolder, then just detach everything
        // outside of the newFolder and ~normalself and ~nude
        debugSay(2, "DEBUG-DRESS", "Removing all other outfits from " + outfitMasterFolder);
        cdForceDetach(outfitMasterFolder);
    }

    //----------------------------------------
    // STEP #3
    //
    // Thought here is that there could be another outfit with much of the
    // current one included; thus, this reattaches all that may have "slipped off"
    //
    // It may be that this interaction between two outfits needs to be forbidden,
    // and it may also be that if we lock something elsewhere, we don't have to
    // worry about this...
    //
    debugSay(2,"DEBUG-DRESS","*** STEP 3 ***");

    // Attach new outfit again
    debugSay(2, "DEBUG-DRESS", "Attaching outfit again from " + newOutfit);
    cdAttach(newOutfit);

    //----------------------------------------
    // STEP #4

    debugSay(2,"DEBUG-DRESS","*** STEP 4 ***");

    // Unlock folders previously locked

    debugSay(2, "DEBUG-DRESS", "Unlocking three folders of new outfit...");

    if (normalselfFolder != "") { cdUnlock(normalselfFolder); }
    if (      nudeFolder != "") { cdUnlock(      nudeFolder); }

    cdUnlock(newOutfit);

}

wearNewAvi(string newOutfit) {
    // newOutfit uses full path relative to #RLV

    outfitAvatar = TRUE;

    // Steps to dressing AS a new Avatar:
    //
    // Load new outfit:
    //
    // 1) Attach and lock everything in the newOutfitFolder
    //       (using @attach)
    //
    // Strip all previous items except the key:
    //
    // 2) Remove everything from >Outfits
    //       (using @detachall:=force)
    // 3) Unlock all
    //
    // Hide key, since random avi might not be suitable for key:
    //
    // 4) Hide key: using internal commands

    //----------------------------------------
    // STEP #1

    // Attach the new folder

    debugSay(2,"DEBUG-DRESS","*** STEP 1 ***");
    debugSay(2, "DEBUG-DRESS", "Attaching outfit from " + newOutfit);
    cdWear(newOutfit);

    // All of the new outfit should be attached - and having replaced
    // anything that was in the way. Nothing is locked.

    //----------------------------------------
    // STEP #2

    cdLock(newOutfit);

    debugSay(2,"DEBUG-DRESS","*** STEP 2 ***");
    // Detach everything other than the locked newOutfit
    debugSay(2, "DEBUG-DRESS", "Removing all other clothing worn from " + outfitMasterFolder);
    cdForceDetach(outfitMasterFolder);

    cdUnlock(newOutfit);

    //llOwnerSay("Your key fades from view as your new avatar persona takes shape...");
    //lmSendConfig("isVisible", (string)isVisible);
}

wearOutfitCore(string newOutfitName) {

    // newOutfitName is the folder name alone

    // Overriting a script global here... not kosher, but works.
    // Note that the value may or may NOT come from this script:
    // ergo, the reason this overwrite is here.

    // Abort if no outfit...

    if (newOutfitName == "") {
        llSay(DEBUG_CHANNEL, "No outfit chosen to wear!");
        return;
    }

    // Key could be ripped off here, so lock it on no matter
    // whether it is generally locked or not
    rlvLockKey();
    tempDressingLock = TRUE;

    // newOutfit is relative to #RLV
    newOutfit = topFolder + "/";
    if (clothingFolder != "") newOutfit += clothingFolder + "/";
    newOutfit += newOutfitName;

    //----------------------------------------
    // DRESSING
    //----------------------------------------

    if (isAvatarFolder(cdGetFirstChar(newOutfitName))) {
        wearNewAvi(newOutfit);
        llOwnerSay("New avatar chosen: " + cdButFirstChar(newOutfitName));
    }
    else {
        if (outfitAvatar) resetBody(newOutfit);
        else wearStandardOutfit(newOutfit);
        llOwnerSay("New outfit chosen: " + newOutfitName);
    }

    llSleep(1.0);

    debugSay(2,"DEBUG-DRESS","*** END DRESSING SEQUENCE ***");

    oldOutfit = newOutfit;

    llListenRemove(dressMenuHandle);
    llListenRemove(dressRandomHandle);
}

#define rlvLockFolderRecursive(a)   ("detachallthis:" + (a) + "=n")
#define rlvUnlockFolderRecursive(a) ("detachallthis:" + (a) + "=y")
#define rlvAttachFolderRecursive(a) (    "attachall:" + (a) + "=force")
#define rlvDetachAllRecursive(a)    (    "detachall:" + (a) + "=force")

resetBodyCore() {
    if (normaloutfitFolder == "") {
        llOwnerSay("ERROR: Cannot reset body form without ~normaloutfit present.");
    }
    else {
        resetBody(normaloutfitFolder);
    }
}

resetBody(string wearOutfit) {
    // wearOutfit is full path relative to #RLV

    // Clear old outfit settings
    oldOutfit = "";
    newOutfit = "";

    // LOCK the key in place
    rlvLockKey();

    // Force attach nude elements
    if (nudeFolder)         lmRunRlv(rlvUnlockFolderRecursive(nudeFolder)       + "," + rlvAttachFolderRecursive(nudeFolder));
    if (normalselfFolder)   lmRunRlv(rlvUnlockFolderRecursive(normalselfFolder) + "," + rlvAttachFolderRecursive(normalselfFolder));
    if (wearOutfit)         lmRunRlv(rlvUnlockFolderRecursive(wearOutfit)       + "," + rlvAttachFolderRecursive(wearOutfit));

    // Lock default body
    if (nudeFolder)         lmRunRlv(rlvLockFolderRecursive(nudeFolder));
    if (wearOutfit)         lmRunRlv(rlvLockFolderRecursive(wearOutfit));

    // Remove all else from the top, outfits and all the rest
    lmRunRlv(rlvDetachAllRecursive(outfitMasterFolder));

    // Clear locks
    if (nudeFolder)         lmRunRlv(rlvUnlockFolderRecursive(nudeFolder));
    if (normalselfFolder)   lmRunRlv(rlvUnlockFolderRecursive(normalselfFolder));
    if (wearOutfit)         lmRunRlv(rlvUnlockFolderRecursive(wearOutfit));
}

#ifdef ADULT_MODE
stripCore() {
    if (!keyLocked) rlvLockKey(); // Lock key if not already locked

    if (nudeFolder)       lmRunRlv("detachthis:" + nudeFolder       + "=n");
    if (normalselfFolder) lmRunRlv("detachthis:" + normalselfFolder + "=n");

    lmRunRlv("detachall:" + outfitMasterFolder + "=force");

    if (nudeFolder)       lmRunRlv("detachthis:" + nudeFolder       + "=y,attachall:" + nudeFolder       + "=force");
    if (normalselfFolder) lmRunRlv("detachthis:" + normalselfFolder + "=y,attachall:" + normalselfFolder + "=force");

    if (!keyLocked) rlvUnlockKey(); // Unlock key if it's not supposed to be locked
}
#endif

