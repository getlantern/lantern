/*******************************************************************************
 *                                                                             *
 *  Copyright (C) 2019 by Max Lv <max.c.lv@gmail.com>                          *
 *  Copyright (C) 2019 by Mygod Studio <contact-shadowsocks-android@mygod.be>  *
 *                                                                             *
 *  This program is free software: you can redistribute it and/or modify       *
 *  it under the terms of the GNU General Public License as published by       *
 *  the Free Software Foundation, either version 3 of the License, or          *
 *  (at your option) any later version.                                        *
 *                                                                             *
 *  This program is distributed in the hope that it will be useful,            *
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of             *
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              *
 *  GNU General Public License for more details.                               *
 *                                                                             *
 *  You should have received a copy of the GNU General Public License          *
 *  along with this program. If not, see <http://www.gnu.org/licenses/>.       *
 *                                                                             *
 *******************************************************************************/

package org.getlantern.lantern.service

import android.annotation.TargetApi
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.ObsoleteCoroutinesApi
import kotlinx.coroutines.channels.actor
import kotlinx.coroutines.runBlocking
import org.getlantern.lantern.LanternApp
import org.getlantern.lantern.utils.AppLogger

object DefaultNetworkListener {
    private sealed class NetworkMessage {
        class Start(val key: Any, val listener: (Network?) -> Unit) : NetworkMessage()
        class Get : NetworkMessage() {
            val response = CompletableDeferred<Network>()
        }

        class Stop(val key: Any) : NetworkMessage()

        class Put(val network: Network) : NetworkMessage()
        class Update(val network: Network) : NetworkMessage()
        class Lost(val network: Network) : NetworkMessage()
    }

    @OptIn(DelicateCoroutinesApi::class, ObsoleteCoroutinesApi::class)
    private val networkActor = GlobalScope.actor<NetworkMessage>(Dispatchers.Unconfined) {
        val listeners = mutableMapOf<Any, (Network?) -> Unit>()
        var network: Network? = null
        val pendingRequests = arrayListOf<NetworkMessage.Get>()
        // Handle each message under a guard. This actor runs on GlobalScope, which
        // has no CoroutineExceptionHandler, so anything thrown here would reach the
        // thread's default handler and kill the process — and take the channel with
        // it, breaking every later network query. Several branches can throw: the
        // check() below, register()'s ConnectivityManager calls, and the listener
        // lambdas, which are caller-supplied. A failed Get is completed
        // exceptionally so its caller sees the error at await() instead of hanging
        // on a Deferred nothing will ever complete.
        for (message in channel) try {
            when (message) {
                is NetworkMessage.Start -> {
                    if (listeners.isEmpty()) register()
                    listeners[message.key] = message.listener
                    if (network != null) notify(message.listener, network)
                }

                is NetworkMessage.Get -> {
                    check(listeners.isNotEmpty()) { "Getting network without any listeners is not supported" }
                    if (network == null) pendingRequests += message else message.response.complete(
                        network
                    )
                }

                is NetworkMessage.Stop -> if (listeners.isNotEmpty() && // was not empty
                    listeners.remove(message.key) != null && listeners.isEmpty()
                ) {
                    network = null
                    unregister()
                }

                is NetworkMessage.Put -> {
                    network = message.network
                    pendingRequests.forEach { it.response.complete(message.network) }
                    pendingRequests.clear()
                    listeners.values.forEach { notify(it, network) }
                }

                is NetworkMessage.Update -> if (network == message.network) {
                    listeners.values.forEach { notify(it, network) }
                }

                is NetworkMessage.Lost -> if (network == message.network) {
                    network = null
                    listeners.values.forEach { notify(it, null) }
                }
            }
        } catch (e: Throwable) {
            AppLogger.e("DefaultNetworkListener", "Failed handling ${message.javaClass.simpleName}", e)
            if (message is NetworkMessage.Get && message.response.isActive) {
                message.response.completeExceptionally(e)
            }
        }
    }

    // Invokes one listener in isolation. Listeners are caller-supplied, and the
    // fan-outs above iterate every registered one: letting a throw escape would
    // abort the loop, so a single bad listener would silently deprive all the
    // others of the event — and stay registered to do it again on the next one.
    private fun notify(listener: (Network?) -> Unit, network: Network?) {
        try {
            listener(network)
        } catch (e: Throwable) {
            AppLogger.e("DefaultNetworkListener", "Network listener threw; continuing", e)
        }
    }

    suspend fun start(key: Any, listener: (Network?) -> Unit) = networkActor.send(
        NetworkMessage.Start(
            key,
            listener
        )
    )

    suspend fun get() = if (fallback) @TargetApi(23) {
        LanternApp.connectivity.activeNetwork
            ?: error("missing default network") // failed to listen, return current if available
    } else NetworkMessage.Get().run {
        networkActor.send(this)
        response.await()
    }

    suspend fun stop(key: Any) = networkActor.send(NetworkMessage.Stop(key))

    // NB: this runs in ConnectivityThread, and this behavior cannot be changed until API 26
    private object Callback : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = runBlocking {
            networkActor.send(
                NetworkMessage.Put(
                    network
                )
            )
        }

        override fun onCapabilitiesChanged(
            network: Network,
            networkCapabilities: NetworkCapabilities
        ) {
            // it's a good idea to refresh capabilities
            runBlocking { networkActor.send(NetworkMessage.Update(network)) }
        }

        override fun onLost(network: Network) = runBlocking {
            networkActor.send(
                NetworkMessage.Lost(
                    network
                )
            )
        }
    }

    private var fallback = false
    private val request = NetworkRequest.Builder().apply {
        addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
        if (Build.VERSION.SDK_INT == 23) {  // workarounds for OEM bugs
            removeCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            removeCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL)
        }
    }.build()
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * On API 28+ registerDefaultNetworkCallback() may report the VPN as the default.
     *   We do NOT call requestNetwork() here just to discover the underlying transport,
     *   because that can keep radios awake and costs battery.
     *
     *   Instead we passively listen and translate the default
     *   to the physical network via: ConnectivityManager.getLinkProperties(default).underlyingNetworks
    */
    private fun register() {
        when (Build.VERSION.SDK_INT) {
            in 31..Int.MAX_VALUE -> {
                LanternApp.connectivity.registerBestMatchingNetworkCallback(
                    request,
                    Callback,
                    mainHandler
                )
            }
            in 26..30 -> {
                LanternApp.connectivity.registerDefaultNetworkCallback(Callback, mainHandler)
            }
            // Handler overload was added in API 26; API 24-25 only have the one-arg version.
            in 24..25 -> {
                LanternApp.connectivity.registerDefaultNetworkCallback(Callback)
            }
            else -> try {
                fallback = false
                LanternApp.connectivity.registerDefaultNetworkCallback(Callback)
            } catch (e: RuntimeException) {
                // known bug on API 23: https://stackoverflow.com/a/33509180/2245107
                fallback = true
            }
        }
    }

    private fun unregister() {
        runCatching {
            LanternApp.connectivity.unregisterNetworkCallback(Callback)
        }
    }
}
