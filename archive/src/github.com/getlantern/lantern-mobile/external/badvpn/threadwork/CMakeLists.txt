set(BADVPN_THREADWORK_EXTRA_LIBS)
if (BADVPN_THREADWORK_USE_PTHREAD)
    list(APPEND BADVPN_THREADWORK_EXTRA_LIBS pthread)
endif ()

badvpn_add_library(threadwork "system" "${BADVPN_THREADWORK_EXTRA_LIBS}" BThreadWork.c)
