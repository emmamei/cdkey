#ifndef CONFIG_LSL
#define CONFIG_LSL

//========================================
// BUILD REPORT
//========================================

float Config_version=1.0;

#ifdef EMERGENCY_TP
#define OPT_TP ["EmergencyTP"]
#else
#define OPT_TP []
#endif

#ifdef HOMING_BEACON
#define OPT_HOMING ["HomingBeacon"]
#else
#define OPT_HOMING []
#endif

#ifdef SINGLE_SELF_WIND
#define OPT_SINGLEWIND ["SingleSelfWind"]
#else
#define OPT_SINGLEWIND []
#endif

#ifdef PRESERVE_DIRECTORY
#define OPT_PRESERVE_DIRECTORY ["PreserveDirectory"]
#else
#define OPT_PRESERVE_DIRECTORY []
#endif

#ifdef ROLLOVER
#define OPT_ROLLOVER ["RollOver"]
#else
#define OPT_ROLLOVER []
#endif

#define OPT_WIND ["DefaultWind=" + (string)llFloor(WIND_DEFAULT / 60.0)]

#ifdef ADULT_MODE
#define OPT_ADULT ["Adult"]
#else
#define OPT_ADULT ["Child"]
#endif

#ifdef DEVELOPER_MODE
#define OPT_KEY_MODE ["Mode=Developer"]
#else
#define OPT_KEY_MODE ["Mode=Normal"]
#endif

#define BUILD_REPORT (OPT_ADULT + OPT_KEY_MODE + OPT_ROLLOVER + OPT_SINGLEWIND + OPT_HOMING + OPT_TP + OPT_PRESERVE_DIRECTORY + OPT_WIND )

#define lmConfigReport() llMessageLinked(LINK_THIS, 142, myName, NULL_KEY)

//#define cdConfigReport() if (code == 142) llOwnerSay(__SHORTFILE__ + ":" + (string)__LINE__ + "\t\t\t\tCompiled  by " + __AGENTNAME__ + "\t" +  __DATE__ + " " + __TIME__ + "\nWith: " + llList2CSV(BUILD_REPORT))
#define cdConfigureReport() llOwnerSay(__SHORTFILE__ + ": Compiled  by " + __AGENTNAME__ + " on " +  __DATE__ + " at " + __TIME__ + " Options: " + llList2CSV(BUILD_REPORT))

#endif //CONFIG_LSL
