/* src/include/config.h.  Generated from config.h.in by configure.  */
/* src/include/config.h.in.  Generated from configure.ac by autoheader.  */

/* enable the inclusion of adult features such as stripping and slut doll in
   the key */
#define ADULT_MODE 1

/* enable a test mode with minimal code changes in which RLV support always
   fails effectively disable the listener for the check reply */
/* #undef DEBUG_BADRLV */

#ifndef DEBUG_LEVEL
/* enable additional debugging messages up to threshold defaults to 0 in
   normal mode or 5 if developer mode is active */
//#define DEBUG_LEVEL 9
//#define DEBUG_LEVEL 7
//#define DEBUG_LEVEL 6
//#define DEBUG_LEVEL 5
//#define DEBUG_LEVEL 4
//#define DEBUG_LEVEL 3
#define DEBUG_LEVEL 1
//#define DEBUG_LEVEL 0
#endif

/* sets the target for debugging messages either DEBUG to send on debug
   channel or OWNER to use ownersay */
#define DEBUG_TARGET 1

/* enable developer support features such as not using RLV locks which would
   prevent editing the scripts or notecards, collection and reporting of
   performance statistics etc */
#define DEVELOPER_MODE 1

/* enable the start up introduction/hypno text provided that the required
   "Intro Text" notecard is also present */
/* #undef INTRO_STARTUP */

/* Define to the address where bug reports for this package should be sent. */
#define PACKAGE_BUGREPORT "https://github.com/emmamei/cdkey/issues"

/* Define to the full name of this package. */
#define PACKAGE_NAME "Community Doll Key"

/* Define to the full name and version of this package. */
#define PACKAGE_STRING "Community Doll Key (Beta) 02-Mar-14"

/* Define to the one symbol short name of this package. */
#define PACKAGE_TARNAME "cdkey-beta"

/* Define to the home page for this package. */
#define PACKAGE_URL "https://github.com/emmamei/cdkey"

/* Define to the version of this package. */
#define PACKAGE_VERSION "02-Mar-14"

/* Define to the numeric version of this package. */
#define PACKAGE_VERNUM 140302

/* enable lag reduction mode when detecting sustained high time dilation in
   the local region. This slightly delays certain events and turns off non
   essential candy to produce a large drop in script time */
#define SIM_FRIENDLY 1

/* enable testing and debugging features and allows the doll to access
   normally inaccessible functions like strip and wind */
#define TESTER_MODE 1
