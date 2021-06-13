//========================================
// Wear.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl

wearOutfitCore(string newOutfitName) {

    string newOutfitFolder;
    string newOutfitPath;

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

    dressingFailures = 0;
    change = 1;

    // Send a message to ourself, generate an event, and save the
    // previous values of newOutfit* into oldOutfit* - can we do
    // this without using a link message?
    //
    // *OutfitName       newOutfitName    - name of outfit
    // *OutfitFolder     outfitFolder    - name of main outfits folder
    // *OutfitPath       clothingFolder   - name of folder with outfit, relative to outfitFolder
    // *Outfit           -new-            - full path of outfit (outfitFolder + "/" + clothingFolder + "/" + newOutfitName)

    // Build the newOutfit* variables - but do they get used?

    newOutfitFolder = outfitFolder;
      newOutfitPath = clothingFolder;

    newOutfit = newOutfitFolder + "/";
    if (clothingFolder != "")
        newOutfit += clothingFolder + "/";
    newOutfit += newOutfitName;

    //----------------------------------------
    // DRESSING
    //----------------------------------------

    // Steps to dressing avi:
    //
    // Overview: Attach everything we need, and lock them afterwards.
    // Next, detach the old outfit - then detach the entire outfitFolder
    // just in case (everything we want should be locked on). Next,
    // go through all clothing parts and detach them if possible.
    // Finally, Attach everything in the outfitFolder just in case.
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
    // 6) Detach entire outfitFolder
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
    //
    // NOTE that this may not be what is wanted, especially if Dolly has changed
    // the standard (or current) look outside of the Key's mechanisms. Not all
    // things in ~normalself and ~nude may necessarily be worn at outfit change time.
    //
    // On top of that, this does not attach ~nude as written...

#define cdLock(a)   lmRunRLV("detachallthis:"+(a)+"=n")
#define cdUnlock(a) lmRunRLV("detachallthis:"+(a)+"=y")
#define cdAttach(a) lmRunRLV("attachallover:"+(a)+"=force") 
#define cdForceDetach(a) lmRunRLV("detachall:"+(a)+"=force");

    // This attaches ~normalself
    //debugSay(2,"DEBUG-DRESS","*** STEP 1 ***");
    //debugSay(2,"DEBUG-DRESS","attach normalself folder: " + normalselfFolder);
    //cdAttach(normalselfFolder);

    //----------------------------------------
    // STEP #3

    // attach the new folder

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
    //if (normalselfFolder != "") { cdUnlock(normalselfFolder); }
    //if (      nudeFolder != "") { cdUnlock(      nudeFolder); }

    //cdUnlock(newOutfit);
    //llSleep(1.0);

    // Step 4b: Lock items so they don't get thrown off
    if (normalselfFolder != "") { cdLock(normalselfFolder); }
    if (      nudeFolder != "") { cdLock(      nudeFolder); }

    cdLock(newOutfit);

    debugSay(2,"DEBUG-DRESS","*** STEP 4C ***");
    debugSay(2,"DEBUG-DRESS","oldOutfit == \"" + oldOutfit + "\"");

    // We don't want anything in these directories to be popped off

    // Step 4c: Remove oldOutfit or alternately entire Outfits dir
    if (oldOutfit != "") {
        debugSay(2, "DEBUG-DRESS", "Removing old outfit from " + oldOutfit);
        cdForceDetach(oldOutfit);
    }
    else {
        // If no oldOutfitFolder, then just detach everything
        // outside of the newFolder and ~normalself and ~nude
        debugSay(2, "DEBUG-DRESS", "Removing all other outfits from " + outfitFolder);
        cdForceDetach(outfitFolder);
    }

    //----------------------------------------
    // STEP #5
    //
    // Thought here is that there could be another outfit with much of the
    // current one included; thus, this reattaches all that may have "slipped off"
    //
    // It may be that this interaction between two outfits needs to be verbotten
    //
    debugSay(2,"DEBUG-DRESS","*** STEP 5 ***");

    // Attach new outfit again
    debugSay(2, "DEBUG-DRESS", "Attaching outfit again from " + newOutfit);
    cdAttach(newOutfit);

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

    oldOutfit = newOutfit;

    llListenRemove(menuDressHandle);

}

resetBodyCore() {
    if (normaloutfitFolder == "") {
        llOwnerSay("ERROR: Cannot reset body form without ~normaloutfit present.");
        return;
    }

    // Clear old outfit settings
    oldOutfit = "";
    newOutfit = "";

#define rlvLockFolderRecursive(a)   ("detachallthis:" + (a) + "=n")
#define rlvUnlockFolderRecursive(a) ("detachallthis:" + (a) + "=y")
#define rlvAttachFolderRecursive(a) (    "attachall:" + (a) + "=force")
#define rlvDetachAllRecursive(a)    (    "detachall:" + (a) + "=force")

    // LOCK the key in place
    rlvLockKey();

    // Force attach nude elements
    if (nudeFolder)         lmRunRLV(rlvUnlockFolderRecursive(nudeFolder)         + "," + rlvAttachFolderRecursive(nudeFolder));
    if (normalselfFolder)   lmRunRLV(rlvUnlockFolderRecursive(normalselfFolder)   + "," + rlvAttachFolderRecursive(normalselfFolder));
    if (normaloutfitFolder) lmRunRLV(rlvUnlockFolderRecursive(normaloutfitFolder) + "," + rlvAttachFolderRecursive(normaloutfitFolder));

    // Lock default body
    if (nudeFolder)         lmRunRLV(rlvLockFolderRecursive(nudeFolder));
    if (normalselfFolder)   lmRunRLV(rlvLockFolderRecursive(normalselfFolder));
    if (normaloutfitFolder) lmRunRLV(rlvLockFolderRecursive(normaloutfitFolder));

    // Remove all else from the top, outfits and all the rest
    lmRunRLV(rlvDetachAllRecursive(outfitFolder));

    // Clear locks and force attach
    //if (nudeFolder)         lmRunRLV(rlvLockFolderRecursive(nudeFolder) + "attachall:" + nudeFolder         + "=force");
    //if (normalselfFolder)   lmRunRLV(rlvLockFolderRecursive(nudeFolder) + "attachall:" + normalselfFolder   + "=force");
    //if (normaloutfitFolder) lmRunRLV(rlvLockFolderRecursive(nudeFolder) + "attachall:" + normaloutfitFolder + "=force");

    // Clear locks
    if (nudeFolder)         lmRunRLV(rlvUnlockFolderRecursive(nudeFolder));
    if (normalselfFolder)   lmRunRLV(rlvUnlockFolderRecursive(normalselfFolder));
    if (normaloutfitFolder) lmRunRLV(rlvUnlockFolderRecursive(normaloutfitFolder));
}

#ifdef ADULT_MODE
stripCore() {
    oldOutfit = "";
    newOutfit = "";

    if (nudeFolder)       lmRunRLV("detachthis:" + nudeFolder       + "=n");
    if (normalselfFolder) lmRunRLV("detachthis:" + normalselfFolder + "=n");

    lmRunRLV("detachall:" + outfitFolder + "=force");

    if (nudeFolder)       lmRunRLV("detachthis:" + nudeFolder       + "=y,attachall:" + nudeFolder       + "=force");
    if (normalselfFolder) lmRunRLV("detachthis:" + normalselfFolder + "=y,attachall:" + normalselfFolder + "=force");
}
#endif

