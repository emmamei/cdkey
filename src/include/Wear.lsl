//========================================
// Wear.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl

#define rlvLockKey()    lmRunRlv("detach=n")
#define rlvUnlockKey()  lmRunRlv("detach=y")

#define cdLock(a)        lmRunRlv("detachallthis:"+(a)+"=n")
#define cdUnlock(a)      lmRunRlv("detachallthis:"+(a)+"=y")
#define cdAttach(a)      lmRunRlv("attachallover:"+(a)+"=force") 
#define cdWear(a)        lmRunRlv("attach:"+(a)+"=force") 
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

wearCompleteAvatar(string newAvatar) {
    // newOutfit uses full path relative to #RLV

    rlvLockKey();

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

    cdWear(newAvatar);
    cdAttach(newAvatar);

    // All of the new outfit should be attached - and having replaced
    // anything that was in the way. Nothing is locked.

    //----------------------------------------
    // STEP #2

    cdLock(newAvatar);

    debugSay(2,"DEBUG-DRESS","*** STEP 2 ***");
    // Detach everything other than the locked newOutfit
    debugSay(2, "DEBUG-DRESS", "Removing all other clothing worn from " + outfitMasterPath);

    cdForceDetach(outfitMasterPath);
    cdUnlock(newAvatar);
    if (!keyLocked) rlvUnlockKey();
}

wearStandardOutfit(string newOutfit) {
    // newOutfit uses full path relative to #RLV

    rlvLockKey();

    // Steps to dressing avi:
    //
    // Overview: Attach everything we need, and lock them afterwards.
    // Next, detach the old outfit - then detach the entire outfitMasterPath
    // just in case (everything we want should be locked on).
    //
    // Attach and Lock (New Outfit):
    //
    // 1) Attach everything in the newOutfitFolder
    //       (using @attachallover:=force followed by @detachallthis:=n )
    //
    // Force Detach:
    //
    // 2) Detach oldOutfitFolder, or entire outfitMasterPath
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

    debugSay(2, "DEBUG-DRESS", "Attaching outfit from " + newOutfit);

    cdAttach(newOutfit);

    // At this point, all standard equipment should be attached,
    // and all of the new outfit should be attached. Nothing is locked.

    //----------------------------------------
    // STEP #2

    // Remove rest of old outfit (using saved folder)

    // Lock standard items so they don't get thrown off
    if (normalselfPath != "") { cdLock(normalselfPath); }
    if (      nudePath != "") { cdLock(      nudePath); }

    // Lock new outfit
    cdLock(newOutfit);

    // We don't want anything in these folders to be popped off

    // Step 2: Remove oldOutfit or alternately entire Outfits folder
    if (oldOutfit != "") {
        debugSay(2, "DEBUG-DRESS", "Removing old outfit from " + oldOutfit);
        cdForceDetach(oldOutfit);
    }
    else {
        // If no oldOutfitFolder, then just detach everything
        // outside of the newFolder and ~normalself and ~nude
        debugSay(2, "DEBUG-DRESS", "Removing all other outfits from " + outfitMasterPath);
        cdForceDetach(outfitMasterPath);
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

    // FIXME: It is strongly possible that this step literally removes all and reattaches all

    // Attach new outfit again
    debugSay(2, "DEBUG-DRESS", "Attaching outfit again from " + newOutfit);
    cdAttach(newOutfit);

    //----------------------------------------
    // STEP #4

    // Unlock folders previously locked

    if (normalselfPath != "") { cdUnlock(normalselfPath); }
    if (      nudePath != "") { cdUnlock(      nudePath); }

    cdUnlock(newOutfit);
    if (!keyLocked) rlvUnlockKey();
}

wearNewAvi(string newOutfit) {
    // This puts on a new avatar, contained fully in one directory
    wearCompleteAvatar(newOutfit);
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
    newOutfit = topPath + "/";
    if (currentOutfitFolder != "") newOutfit += currentOutfitFolder + "/";
    newOutfit += newOutfitName;

    //----------------------------------------
    // DRESSING
    //----------------------------------------

    if (isAvatarFolder(cdGetFirstChar(newOutfitName))) {

        // if the new outfit is an avatar, do what needs doing...
        wearNewAvi(newOutfit);

        llOwnerSay("New avatar chosen: " + cdButFirstChar(newOutfitName));

        outfitAvatar = TRUE; // New outfit is an avatar; mark it
    }
    else {

        // This new outfit is NOT an avatar...

        // if the new outfit is replacing an avatar, then adjust for that
        if (outfitAvatar) resetBodyWithOutfit(newOutfit);
        else wearStandardOutfit(newOutfit);

        llOwnerSay("New outfit chosen: " + newOutfitName);

        outfitAvatar = FALSE; // New outfit is NOT an avatar: mark it
    }

    llSleep(1.0);

    debugSay(2,"DEBUG-DRESS","*** END DRESSING SEQUENCE ***");

    oldOutfit = newOutfit;

    llListenRemove(dressMenuHandle);
    llListenRemove(dressRandomHandle);
}

#define resetBodyCore() resetBody()

resetBody() {
    if (normaloutfitPath == "") {
        llSay(DEBUG_CHANNEL,"ERROR: Cannot reset body form without ~normaloutfit present.");
    }
    else {
        resetBodyWithOutfit(normaloutfitPath);
    }
}

resetBodyWithOutfit(string wearOutfitPath) {
    // wearOutfit is full path relative to #RLV
    if (wearOutfitPath == "") {
        llSay(DEBUG_CHANNEL,"ERROR: Cannot reset body form without outfit path.");
        return;
    }

    wearCompleteAvatar(normalselfPath);

    if (nudePath) cdAttach(nudePath);
                  cdAttach(wearOutfitPath);

    // Set outfit settings
    newOutfit = "";
    oldOutfit = wearOutfitPath;
}

#ifdef ADULT_MODE
stripCore() {
    if (!keyLocked) rlvLockKey(); // Lock key if not already locked

    if (nudePath)       lmRunRlv("detachthis:" + nudePath       + "=n");
    if (normalselfPath) lmRunRlv("detachthis:" + normalselfPath + "=n");

    lmRunRlv("detachall:" + outfitMasterPath + "=force");

    if (nudePath)       lmRunRlv("detachthis:" + nudePath       + "=y,attachall:" + nudePath       + "=force");
    if (normalselfPath) lmRunRlv("detachthis:" + normalselfPath + "=y,attachall:" + normalselfPath + "=force");

    if (!keyLocked) rlvUnlockKey(); // Unlock key if it's not supposed to be locked
}
#endif

