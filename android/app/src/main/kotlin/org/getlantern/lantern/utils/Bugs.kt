package org.getlantern.lantern.utils

import android.os.Build

object Bugs {

    // TODO: remove launch after fixed
    // https://github.com/golang/go/issues/68760
    val fixAndroidStack = true ||
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && Build.VERSION.SDK_INT <= Build.VERSION_CODES.N_MR1 ||
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.P

}