package org.lantern;

import org.lantern.events.MessageEvent;

import com.google.common.eventbus.Subscribe;

public interface MessageService {

    void showMessage(String title, String message);

    int askQuestion(String title, String message, int typeFlag);
    
    @Subscribe
    void onMessageEvent(MessageEvent me);

}
