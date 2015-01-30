/* FILE: config.h */

//========================================
// COMPILE CONFIGURATION
//========================================

/* Fake out not having RLV */
// #define FAKE_NORLV 1

/* Are we able to hold Dolly's Key? */
// #define JAMMABLE 1

/* Is primGlow a selectable option? */
// #define PRIMGLOW_OPT 1

/* Confirm items fully removed */
// #define CONFIRM_UNWEAR 1

/* Confirm items fully worn */
// #define CONFIRM_WEAR 1

/* adds a homing beacon: an automatic TP home for collapsed dollies */
// #define HOMING_BEACON 1

/* make the outfits paging rollover from end to beginning and vice versa - or stop */
#define ROLLOVER 1

/* Defines the Default wind amount */
#define WIND_DEFAULT 1800.0

/* adds slowed walking during AFK */
#define SLOW_WALK 1

/* enable the inclusion of adult features such as stripping and slut doll in
   the key */
#define ADULT_MODE 1

/* enable the start up introduction/hypno text provided that the required
   "Intro Text" notecard is also present */
// #define INTRO_STARTUP 1

/* enable a test mode with minimal code changes in which RLV support always
   fails effectively disable the listener for the check reply */
// #define DEBUG_BADRLV 1

/* enable developer support features such as not using RLV locks which would
   prevent editing the scripts or notecards, collection and reporting of
   performance statistics etc */
#define DEVELOPER_MODE 1

/* Does the developer key "lock on" ? */
#ifdef DEVELOPER_MODE
// #define LOCKON 1
#else
// Non-dev key should ALWAYS lock on
#define LOCKON 1
#endif

#ifdef DEVELOPER_MODE
/* enable additional debugging messages up to specified threshold.
   the debug level can be changed at the chat line or in prefs */
#define DEBUG_LEVEL 0
#endif

//========================================
// PACKAGE DATA
//========================================

/* Define to the address where bug reports for this package should be sent. */
#define PACKAGE_BUGREPORT "https://github.com/emmamei/cdkey/issues"

/* Define to the full name of this package. */
#define PACKAGE_NAME "Community Doll Key"

/* Define to the full name and version of this package. */
#define PACKAGE_STRING "Community Doll Key (Beta) 10-Nov-2014"

/* Define to the one symbol short name of this package. */
#define PACKAGE_TARNAME "cdkey-beta"

/* Define to the home page for this package. */
#define PACKAGE_URL "https://github.com/emmamei/cdkey"

/* Define to the version of this package. */
#define PACKAGE_VERSION "20-Nov-14"

/* Define to the numeric version of this package. */
#define PACKAGE_VERNUM 141120

