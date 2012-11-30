package org.lantern;

public interface MessageService {

    void showMessage(String title, String message);

    int askQuestion(String title, String message, int typeFlag);

}
