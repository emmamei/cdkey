AC_INIT([Community Doll Key Development Branch],[28-Dec-13],[https://github.com/emmamei/cdkey/issues],[cdkey-dev],[https://github.com/emmamei/cdkey])
AC_PREREQ([2.69])
AC_CONFIG_SUBDIRS([src])
AC_PREFIX([${PWD}/key])
AC_PROG_CPP
AC_PROG_MAKE_SET
AC_PROG_MKDIR_P
AC_PROG_SED

AC_ARG_ENABLE([adult], AS_HELP_STRING([--disable-adult], [disables the inclusion of adult only features like stripping and slut doll]) )
AS_IF([test "x$enable_adult" != "xno"], AC_DEFINE([ADULT_MODE], [1]) )

AC_ARG_ENABLE([intro], AS_HELP_STRING([--enable-intro], [enable the start up introduction/hypno text this feature requires a notecard with the text also be supplied, by default it looks for Intro Text as the notecard]) )
AS_IF([test "x$enable_intro" = "xyes"], AC_DEFINE([INTRO_STARTUP], [1]) )

AC_ARG_ENABLE([friendly], AS_HELP_STRING([--disable-friendly], [*NOT RECOMMENDED: disable sim friendly mode significantly increasing script time usage during high lag by disabling features intended to lower it]) )
AS_IF([test "x$enable_friendly" != "xno"], AC_DEFINE([SIM_FRIENDLY], [1]) )

AC_ARG_ENABLE([devel], AS_HELP_STRING([--enable-devel], [enable the inclusion of developer specific functions in LSL output]) )
AS_IF([test "x$enable_devel" = "xyes"], AC_DEFINE([DEVELOPER_MODE], [1]) )

AC_ARG_ENABLE([tester], AS_HELP_STRING([--enable-tester], [enable testing and debugging features and allows the doll to access normally inaccessible functions like strip and wind]) )
AS_IF([test "x$enable_tester" = "xyes"], AC_DEFINE([TESTER_MODE], [1]) )

AS_IF([test "x$enable_devel" = "xyes"], AC_DEFINE([DEBUG_LEVEL], [5]), AC_DEFINE([DEBUG_LEVEL], [0]) )
AS_IF(test "$DEBUG_LEVEL" = "0"], AC_DEFINE([DEBUG_LEVEL], [0]) )
AS_IF(test "$DEBUG_LEVEL" = "1"], AC_DEFINE([DEBUG_LEVEL], [1]) )
AS_IF(test "$DEBUG_LEVEL" = "2"], AC_DEFINE([DEBUG_LEVEL], [2]) )
AS_IF(test "$DEBUG_LEVEL" = "3"], AC_DEFINE([DEBUG_LEVEL], [3]) )
AS_IF(test "$DEBUG_LEVEL" = "4"], AC_DEFINE([DEBUG_LEVEL], [4]) )
AS_IF(test "$DEBUG_LEVEL" = "5"], AC_DEFINE([DEBUG_LEVEL], [5]) )
AS_IF(test "$DEBUG_LEVEL" = "6"], AC_DEFINE([DEBUG_LEVEL], [6]) )
AS_IF(test "$DEBUG_LEVEL" = "7"], AC_DEFINE([DEBUG_LEVEL], [7]) )
AS_IF(test "$DEBUG_LEVEL" = "8"], AC_DEFINE([DEBUG_LEVEL], [8]) )
AS_IF(test "$DEBUG_LEVEL" = "9"], AC_DEFINE([DEBUG_LEVEL], [9]) )
AS_IF([test "x$enable_devel" = "xyes"], AC_DEFINE([DEBUG_LEVEL], [5]), AC_DEFINE([DEBUG_LEVEL], [0]) )

AS_IF([test "$DEBUG_TARGET" = "DEBUG"], AC_DEFINE([DEBUG_TARGET], [2]), AC_DEFINE([DEBUG_TARGET], [1]) )

AC_ARG_VAR([DEBUG_LEVEL], [enables additional debugging messages up to threshold])
AC_ARG_VAR([DEBUG_TARGET], [sets the target for debugging messages])

AH_TEMPLATE([ADULT_MODE],     [enable the inclusion of adult features such as stripping and slut doll in the key])
AH_TEMPLATE([DEBUG_LEVEL],    [enable additional debugging messages up to threshold defaults to 0 in normal mode or 5 if developer mode is active])
AH_TEMPLATE([DEBUG_TARGET],   [sets the target for debugging messages either DEBUG to send on debug channel or OWNER to use ownersay])
AH_TEMPLATE([DEVELOPER_MODE], [enable developer support features such as not using RLV locks which would prevent editing the scripts or notecards, collection and reporting of performance statistics etc])
AH_TEMPLATE([INTRO_STARTUP],  [enable the start up introduction/hypno text provided that the required "Intro Text" notecard is also present])
AH_TEMPLATE([SIM_FRIENDLY],   [enable lag reduction mode when detecting sustained high time dilation in the local region. This slightly delays certain events and turns off non essential candy to produce a large drop in script time])
AH_TEMPLATE([TESTER_MODE],    [enable testing and debugging features and allows the doll to access normally inaccessible functions like strip and wind])

#AC_CONFIG_ITEMS([include/config.h])
AC_CONFIG_HEADERS([include/config.h:include/config.h.in])
AC_CONFIG_FILES([Makefile])

AC_OUTPUT
