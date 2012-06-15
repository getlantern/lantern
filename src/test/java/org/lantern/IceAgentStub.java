package org.lantern;

import java.io.IOException;
import java.net.InetAddress;
import java.net.Socket;
import java.util.Collection;
import java.util.Queue;

import org.littleshoot.mina.common.ByteBuffer;
import org.lastbamboo.common.ice.IceAgent;
import org.lastbamboo.common.ice.IceMediaStream;
import org.lastbamboo.common.ice.IceState;
import org.lastbamboo.common.ice.IceTieBreaker;
import org.lastbamboo.common.ice.candidate.IceCandidate;
import org.lastbamboo.common.ice.candidate.IceCandidatePair;
import org.lastbamboo.common.offer.answer.OfferAnswerListener;
import org.lastbamboo.common.offer.answer.OfferAnswerMediaListener;

/**
 * Stun class for an ICE agent.
 */
public class IceAgentStub implements IceAgent {

    public IceTieBreaker getTieBreaker() {
        return new IceTieBreaker();
    }

    public boolean isControlling() {
        // TODO Auto-generated method stub
        return false;
    }

    public long calculateDelay(int Ta_i) {
        // TODO Auto-generated method stub
        return 0;
    }

    public void onUnfreezeCheckLists(IceMediaStream mediaStream) {
        // TODO Auto-generated method stub

    }

    public void checkValidPairsForAllComponents(IceMediaStream mediaStream) {
        // TODO Auto-generated method stub

    }

    public void setControlling(boolean controlling) {
        // TODO Auto-generated method stub

    }

    public Socket connect(ByteBuffer answer) throws IOException {
        // TODO Auto-generated method stub
        return null;
    }

    public Collection<IceCandidate> gatherCandidates() {
        // TODO Auto-generated method stub
        return null;
    }

    public Socket createSocket(ByteBuffer answer) throws IOException {
        // TODO Auto-generated method stub
        return null;
    }

    public byte[] generateAnswer() {
        // TODO Auto-generated method stub
        return null;
    }

    public byte[] generateOffer() {
        // TODO Auto-generated method stub
        return null;
    }

    public void recomputePairPriorities() {
        // TODO Auto-generated method stub

    }

    public Collection<IceMediaStream> getMediaStreams() {
        // TODO Auto-generated method stub
        return null;
    }

    public void processOffer(ByteBuffer offer) {
        // TODO Auto-generated method stub

    }

    public IceState getIceState() {
        // TODO Auto-generated method stub
        return null;
    }

    public void onNominatedPair(IceCandidatePair pair,
            IceMediaStream iceMediaStream) {
        // TODO Auto-generated method stub

    }

    public Queue<IceCandidatePair> getNominatedPairs() {
        // TODO Auto-generated method stub
        return null;
    }

    public void processAnswer(ByteBuffer answer) {
        // TODO Auto-generated method stub

    }

    public void onValidPairs(IceMediaStream mediaStream) {
        // TODO Auto-generated method stub

    }

    public Socket createSocket() {
        // TODO Auto-generated method stub
        return null;
    }

    public void processAnswer(ByteBuffer answer,
            OfferAnswerListener offerAnswerListener) {
        // TODO Auto-generated method stub

    }

    public void processOffer(ByteBuffer offer,
            OfferAnswerListener offerAnswerListener) {
        // TODO Auto-generated method stub

    }

    public void listen() {
        // TODO Auto-generated method stub

    }

    public void startMedia(OfferAnswerMediaListener mediaListener) {
        // TODO Auto-generated method stub

    }

    public void close() {
        // TODO Auto-generated method stub

    }

    public void onNoMorePairs() {
        // TODO Auto-generated method stub

    }

    public void closeTcp() {
        // TODO Auto-generated method stub

    }

    public void closeUdp() {
        // TODO Auto-generated method stub

    }

    public InetAddress getPublicAdress() {
        // TODO Auto-generated method stub
        return null;
    }

    public void useRelay() {
        // TODO Auto-generated method stub

    }

    public boolean isClosed() {
        // TODO Auto-generated method stub
        return false;
    }

}
