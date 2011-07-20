package org.lantern.xmpp;

/*******************************************************************************
 * Copyright (c) 2009 Nuwan Samarasekera, and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *    Nuwan Sam <nuwansam@gmail.com> - initial API and implementation
 ******************************************************************************/

import org.jivesoftware.smack.packet.IQ;
import org.jivesoftware.smack.provider.IQProvider;
import org.xmlpull.v1.XmlPullParser;

public class GenericIQProvider implements IQProvider {

    public IQ parseIQ(XmlPullParser parser) throws Exception {

        final StringBuilder buf = new StringBuilder();

        int eventType;// = parser.getEventType();
        String namespace = parser.getNamespace();
        String name = parser.getName();
        String prefix = parser.getPrefix() == null ? "" : parser.getPrefix()
                + ":";
        String txt = "";
        int numStartTags = 0, numEndTags = 0;
        do {
            txt = parser.getText();
            if (parser.getEventType() == XmlPullParser.TEXT) {
                txt = clearControlCharacters(txt);
            }
            for (int i = 0; i < txt.length(); i++) {
                if (txt.charAt(i) == '<')
                    numStartTags++;
                if (txt.charAt(i) == '>')
                    numEndTags++;
            }
            buf.append(txt);
            eventType = parser.next();
        } while (!(eventType == XmlPullParser.END_TAG && parser.getName()
                .equals(name)));

        // according to the requirements of the IQProvider specification, it is
        // necessary to keep the parser pointed at the last tag.Thus the closing
        // tag must be manually added ex:</query>. however, when there is only 1
        // childXMLElement in the IQ stanza there is no need for inserting
        // </xxx>. ex : <new-mail newmailnotification />. in this case the
        // number of opening tags (and the closing tags) found in the text
        // should be exactly 1. in all other instances the ending tag must be
        // manually inserted
        if (!(numStartTags == 1 && numEndTags == 1))
            buf.append("</" + prefix + name + ">");// end the query tag

        IQ iq = new IQ() {

            @Override
            public String getChildElementXML() {
                return buf.toString();
            }

        };
        IQ.Type Type = null;

        /*
         * if (type.equals("get")) { Type = IQ.Type.GET; } else if
         * (type.equals("set")) { Type = IQ.Type.SET;
         * 
         * } else if (type.equals("result")) { Type = IQ.Type.RESULT;
         * 
         * } else if (type.equals("error")) { Type = IQ.Type.ERROR;
         * 
         * } iq.setPacketID(id); iq.setFrom(from); iq.setTo(to);
         * iq.setType(Type);
         */return iq;
    }

    public static String clearControlCharacters(String txt) {
        txt = txt.replaceAll("&", "&amp;");
        txt = txt.replaceAll("\"", "&quot;");
        txt = txt.replaceAll("'", "&apos;");
        txt = txt.replaceAll("<", "&lt;");
        txt = txt.replaceAll(">", "&gt;");
        return txt;
    }

    public static String convertToRawText(String txt) {
        txt = txt.replaceAll("&amp;", "&");
        txt = txt.replaceAll("&quot;", "\"");
        txt = txt.replaceAll("&apos;", "'");
        txt = txt.replaceAll("&lt;", "<");
        txt = txt.replaceAll("&gt;", ">");
        return txt;
    }
}