package org.lantern.model;

 
        /*if (success) {
            onSuccess();
        } else {                   
            if (noNetworkConnection) {
                Utils.showErrorDialog(activity, 
                        activity.getResources().getString(R.string.no_internet_connection));

            } else {
                onError();
            }
        }*/ 
/**
 * 
 */
public interface ProResponse
{
    void onResult(boolean success);
}
