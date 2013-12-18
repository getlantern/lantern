import java.awt.Desktop;
import java.net.URI;
import java.net.URLEncoder;

public class TestMailto {
    public static void main(String[] args) throws Exception {
        String recipient = "ox@getlantern.org";
        String subject = URLEncoder
                .encode("Join the Lantern Network to Circumvent Censorship");
        StringBuilder longBody = new StringBuilder();
        for (int i = 0; i < 60000; i++) {
            longBody.append("Hello");
        }
        String body = URLEncoder
                .encode("Here's my log");
        String attachment = URLEncoder
                .encode("/Users/ox.to.a.cart/Documents/eclipse_workspace/lantern/log.txt");
        Desktop.getDesktop().mail(
                new URI(String.format(
                        "mailto:%1$s?subject=%2$s&body=%3$s&attachment=%4$s",
                        recipient, subject,
                        body, attachment)));
    }
}
