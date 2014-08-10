package org.lantern;

import org.lantern.event.MessageEvent;

import com.google.common.eventbus.Subscribe;

public interface MessageService {

    void showMessage(String title, String message);

    boolean askQuestion(String title, String message);

    boolean okCancel(String title, String message);
    
    @Subscribe
    void onMessageEvent(MessageEvent me);


}
