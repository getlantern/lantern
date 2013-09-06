package org.lantern;

/**
 * Interface for classes handling friend interaction.
 */
public interface Friender {
    
    /**
     * Adds a friend.
     * 
     * @param json The JSON containing data about the friend to add.
     */
    void addFriend(String json);

    /**
     * Removes a friend.
     * 
     * @param json The JSON containing data about the friend to remove.
     */
    void removeFriend(String json);

}
