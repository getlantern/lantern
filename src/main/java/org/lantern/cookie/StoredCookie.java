package org.lantern.cookie;

import java.net.URI;
import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.DefaultCookie;

/** 
 * A Cookie with some extra details associated with 
 * storage and matching.
 *
 */
public class StoredCookie extends DefaultCookie {

    // the host-only flag indicates that the 
    // domain setting is exact-match only.
    private boolean isHostOnly;

    // whether this cookie is intended to be saved
    // beyond the current "session"
    private boolean isPersistent; 

    // creation time of this cookie in 
    // milliseconds since the epoch.
    private long creationTimestamp;

    // last access time of this cookie
    private long accessTimestamp;
 
    // the URI that this cookie was received from.
    private URI originUri;

    public StoredCookie(final String name, final String value) {
        super(name, value);
        isHostOnly = false;
        isPersistent = false;
        originUri = null;
        long now = System.currentTimeMillis();
        this.creationTimestamp = now; 
        this.accessTimestamp = now;
    }


    /** 
     * Create a normalized clone of the given parsed Set-Cookie by carrying out  
     * post-parsing steps advised by RFC 6265 Sections 5.2 and 5.3.
     * 
     * Rejections are postponed and delegated to the storage policy of the 
     * container, but relevant information for use in the policy is retained.
     *
     */ 
    public static StoredCookie fromSetCookie(final Cookie cookie, final URI originUri) {

        final StoredCookie outCookie = new StoredCookie(cookie.getName(), cookie.getValue());
        outCookie.setOriginUri(originUri);

        // RFC 6265 Section 5.2.4
        outCookie.setPath(CookieUtils.normalizedSetCookiePath(cookie.getPath(), originUri));

        // TODO these values are just carried along untouched currently, there are sections about them.
        outCookie.setVersion(cookie.getVersion());
        outCookie.setDiscard(cookie.isDiscard());
        outCookie.setHttpOnly(cookie.isHttpOnly());
        outCookie.setSecure(cookie.isSecure());
        outCookie.setPorts(cookie.getPorts());
        outCookie.setComment(cookie.getComment());
        outCookie.setCommentUrl(cookie.getCommentUrl());


        // Roughly RFC 6265 Section 5.3.3
        //
        // netty collapses maxAge and Expires in a slightly 
        // non-compliant way prior to us seeing it (It does not 
        // proritize maxAge over all Expires headers)
        //
        // It will also convert all negative maxAge values to 0, 
        // and reserves the special value -1 to inidcate that 
        // nothing was specified either way. It is expected that
        // any generated Cookie also respects this convention. 
        // 
        // The cookie is set to persistent if anything was 
        // specified, and non-persistent ontherwise as 
        // dictated by the spec. 
        outCookie.setMaxAge(cookie.getMaxAge());
        if (cookie.getMaxAge() == -1) {
            outCookie.setPersistent(false);
        }
        else {
            outCookie.setPersistent(true);
        }

        // RFC 6265 Sections 5.2.3
        String domainAttribute = CookieUtils.normalizedSetCookieDomain(cookie.getDomain()); 
        String canonicalHost = CookieUtils.canonicalizeHost(originUri.getHost());
        
        
        
        // Partially, RFC 6265 Section 5.3.5 and 5.3.6 
        //
        // rejection checks are deferred to the storage policy which can utilize the 
        // value of the host-only flag to carry out the remainder.  The host-only
        // flag indicates both an exact match and that the "domain-attribute"
        // was empty or otherwise discarded by the processing steps. 
        //
        
        // 5.   If the user agent is configured to reject "public suffixes" and
        //      the domain-attribute is a public suffix:
        // 
        //         If the domain-attribute is identical to the canonicalized
        //         request-host:
        // 
        //            Let the domain-attribute be the empty string.
        //
        //         Otherwise:
        // 
        //            Ignore the cookie entirely and abort these steps.
        //
        if (domainAttribute != null && CookieUtils.isPublicSuffix(domainAttribute)) {
            if (domainAttribute.equals(canonicalHost)) {
                domainAttribute = null;
            }
            // rejection is condition deferred.
        }
        
    
        // 6.   If the domain-attribute is non-empty:
        // 
        //         If the canonicalized request-host does not domain-match the
        //         domain-attribute:
        // 
        //            Ignore the cookie entirely and abort these steps.
        // 
        //         Otherwise:
        // 
        //            Set the cookie's host-only-flag to false.
        // 
        //            Set the cookie's domain to the domain-attribute.
        // 
        if (domainAttribute != null && !domainAttribute.equals("")) {
            // rejection condition is deferred.
            outCookie.setDomain(domainAttribute);
            outCookie.setHostOnly(false);
        }

        //      Otherwise:
        // 
        //         Set the cookie's host-only-flag to true.
        // 
        //         Set the cookie's domain to the canonicalized request-host.
        //
        else {
            outCookie.setDomain(canonicalHost);
            outCookie.setHostOnly(true);
        }

        return outCookie;
    }



    /**
     * Set the Host-Only flag which controls whether
     * the Domain parameter is matched exactly or 
     * via domain matching.
     */
    public void setHostOnly(boolean isHostOnly) {
        this.isHostOnly = isHostOnly; 
    }

    /**
     * returns the value of the Host-Only flag. 
     * If this flag is true, the domain paramter
     * is matched exactly during cookie matching. 
     * Otherwise, domain-matching is used.
     */ 
    public boolean isHostOnly() {
        return this.isHostOnly;
    }
    
    /**
     * returns the creation time of this Cookie 
     * in millisseconds since the epoch. 
     */ 
    public long getCreationTimestamp() {
        return creationTimestamp;
    }
    
    /** 
     * set the creation time of this Cookie in 
     * seconds since the epoch.
     */ 
    public void setCreationTimestamp(long timestamp) {
        this.creationTimestamp = timestamp;
    }
    
    /**
     * gets the last access time of this Cookie in 
     * milliseconds since the epoch.
     */ 
    public long getAccessTimestamp() {
        return accessTimestamp;
    }
    
    /**
     * sets the access time of this Cookie in 
     * milliseconds since the epoch.
     */
    public void setAccessTimestamp(long accessTimestamp) {
        this.accessTimestamp = accessTimestamp;
    }
    
    /**
     * @return true if this cookie is no longer valid 
     * according to the value of its maximumAge attribute. 
     * 
     * if maximum age is >= 0, this returns true if and only if 
     * the difference between the current time and the creation 
     * timestamp of this cookie is greater than the maximum age 
     * of the cookie. 
     * 
     * if the value of maxAge is -1 (KEEP_UNTIL_SESSION_ENDS)
     * this function always return false, but the cookie 
     * is expected to be non-persistent.
     *
     * N.B. The netty CookieDecoder always converts maxAge below 0 to 0 
     * and uses the special value -1 to indicate that maxAge was not 
     * specified. It is expected that other portions of the system 
     * that may generate Cookies will respect this convention.
     */ 
    public boolean isExpired() {
        long maxAge = getMaxAge();
        
        if (maxAge == -1) {
            return false;
        }
        long now = System.currentTimeMillis() / 1000; 
        long age = now - creationTimestamp; 
        if (age > maxAge) {
            return true;
        }
        return false;
    }
    
    /** 
     * @return true if and only if this cookie is intended 
     *         to be stored beyond the current session.
     *
     */ 
    public boolean isPersistent() {
        return isPersistent; 
    }
    
    /**
     * set whether this Cookie is intended to be 
     * stored beyond the current session. 
     */
    public void setPersistent(boolean isPersistent) {
        this.isPersistent = isPersistent;
    }

    /**
     * sets the URI that was requested to receive this cookie.
     */ 
    public void setOriginUri(final URI originUri) {
        this.originUri = originUri;
    }
    
    /**
     * @return the URI that was requested to receive this cookie.
     *
     */
    public URI getOriginUri() {
        return originUri;
    }


}