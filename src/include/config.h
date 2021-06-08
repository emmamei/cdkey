/* FILE: config.h */

//========================================
// COMPILE CONFIGURATION
//========================================

//----------------------------------------
// KEY TYPE & MODE
//----------------------------------------

/* enable developer support features */
#define DEVELOPER_MODE 1

/* enable the inclusion of adult features such as stripping and slut doll */
#define ADULT_MODE 1

/* enable adding user RLV commands to base collapse and pose RLV commands */
#define USER_RLV 1

//----------------------------------------
// DEFAULTS
//----------------------------------------

/* Defines the Default wind amount */
#define WIND_DEFAULT 1800.0

//----------------------------------------
// SETTINGS
//----------------------------------------

/* requires someone to wind dolly before dolly can self-wind a second time */
// #define SINGLE_SELF_WIND 1

/* preserves the directory between calls to the Outfits menu */
#define PRESERVE_DIRECTORY 1

/* make the outfits paging rollover from end to beginning and vice versa - or stop */
#define ROLLOVER 1

/* enable the start up introduction/hypno text provided that the required
   "Intro Text" notecard is also present */
// #define INTRO_STARTUP 1

/* enable a test mode with minimal code changes in which RLV support always
   fails effectively disable the listener for the check reply */
// #define DEBUG_BADRLV 1

/* enable optional emergency TP after collapse */
// #define EMERGENCY_TP 1

/* adds a homing beacon: an automatic TP home for collapsed dollies */
#ifdef EMERGENCY_TP
#define HOMING_BEACON 1
#endif

/* enable optional RLV: dolly can enable and disable it */
// #define OPTIONAL_RLV

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

