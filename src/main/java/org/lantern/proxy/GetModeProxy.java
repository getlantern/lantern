package org.lantern.proxy;

import io.netty.handler.codec.http.HttpRequest;

import org.lantern.ClientStats;
import org.lantern.LanternConstants;
import org.lantern.ProxyHolder;
import org.littleshoot.proxy.ActivityTrackerAdapter;
import org.littleshoot.proxy.ChainedProxyManager;
import org.littleshoot.proxy.FullFlowContext;
import org.littleshoot.proxy.impl.DefaultHttpProxyServer;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * HTTP proxy server for local requests from the browser to Lantern (i.e. in Get
 * Mode).
 */
@Singleton
public class GetModeProxy extends AbstractHttpProxyServerAdapter {
    @Inject
    public GetModeProxy(
            final ClientStats stats,
            ChainedProxyManager chainedProxyManager) {
        super(DefaultHttpProxyServer
                .bootstrap()
                .withName("GetModeProxy")
                .withPort(LanternConstants.LANTERN_LOCALHOST_HTTP_PORT)
                .withAllowLocalOnly(true)
                .withListenOnAllAddresses(false)
                .withChainProxyManager(chainedProxyManager)

                // Keep stats up to date
                .plusActivityTracker(new ActivityTrackerAdapter() {
                    @Override
                    public void requestSentToServer(
                            FullFlowContext flowContext,
                            HttpRequest httpRequest) {
                        if (flowContext.getChainedProxy() != null) {
                            stats.incrementProxiedRequests();
                        }
                    }

                    @Override
                    public void bytesSentToServer(FullFlowContext flowContext,
                            int numberOfBytes) {
                        ProxyHolder chainedProxy = (ProxyHolder) flowContext
                                .getChainedProxy();
                        if (chainedProxy != null) {
                            stats.addUpBytesViaProxies(numberOfBytes);
                            stats.addBytesProxied(numberOfBytes,
                                    flowContext.getClientAddress());
                            chainedProxy.getPeer().addBytesUp(numberOfBytes);
                        } else {
                            stats.addDirectBytes(numberOfBytes);
                        }
                    }

                    @Override
                    public void bytesReceivedFromServer(
                            FullFlowContext flowContext,
                            int numberOfBytes) {
                        ProxyHolder chainedProxy = (ProxyHolder) flowContext
                                .getChainedProxy();
                        if (chainedProxy != null) {
                            stats.addDownBytesViaProxies(numberOfBytes);
                            stats.addBytesProxied(numberOfBytes,
                                    flowContext.getClientAddress());
                            chainedProxy.getPeer().addBytesDn(numberOfBytes);
                        } else {
                            stats.addDirectBytes(numberOfBytes);
                        }
                    }
                }));
    }
}
