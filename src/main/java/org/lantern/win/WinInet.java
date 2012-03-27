package org.lantern.win;

import java.util.HashMap;
import java.util.Map;
import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.Structure;
import com.sun.jna.Union;
import com.sun.jna.WString;
import com.sun.jna.platform.win32.WinBase.FILETIME;
import com.sun.jna.platform.win32.WinDef.DWORD;
import com.sun.jna.ptr.IntByReference;
import com.sun.jna.win32.StdCallLibrary;
import com.sun.jna.win32.W32APIFunctionMapper;
import com.sun.jna.win32.W32APITypeMapper;


/**
 * Adapted from:
 * 
 * http://stackoverflow.com/questions/5501787/invoke-wininet-functions-used-java-jna
 * 
 * http://source.winehq.org/source/include/wininet.h
 */
public interface WinInet extends StdCallLibrary {
    final static Map<String, Object> WIN32API_OPTIONS = new HashMap<String, Object>() {
        private static final long serialVersionUID = 1L;
        {
            put(Library.OPTION_FUNCTION_MAPPER, W32APIFunctionMapper.UNICODE);
            put(Library.OPTION_TYPE_MAPPER, W32APITypeMapper.UNICODE);
        }
    };

    public WinInet INSTANCE = (WinInet) Native.loadLibrary("Wininet", WinInet.class, WIN32API_OPTIONS);

    public static final DWORD INTERNET_PER_CONN_FLAGS                        = new DWORD(1);
    public static final DWORD INTERNET_PER_CONN_PROXY_SERVER                 = new DWORD(2);
    public static final DWORD INTERNET_PER_CONN_PROXY_BYPASS                 = new DWORD(3);
    public static final DWORD INTERNET_PER_CONN_AUTOCONFIG_URL               = new DWORD(4);
    public static final DWORD INTERNET_PER_CONN_AUTODISCOVERY_FLAGS          = new DWORD(5);
    public static final DWORD INTERNET_PER_CONN_AUTOCONFIG_SECONDARY_URL     = new DWORD(6);
    public static final DWORD INTERNET_PER_CONN_AUTOCONFIG_RELOAD_DELAY_MINS = new DWORD(7);
    public static final DWORD INTERNET_PER_CONN_AUTOCONFIG_LAST_DETECT_TIME  = new DWORD(8);
    public static final DWORD INTERNET_PER_CONN_AUTOCONFIG_LAST_DETECT_URL   = new DWORD(9); 

    /* Values for INTERNET_PER_CONN_FLAGS */
    public static final DWORD PROXY_TYPE_DIRECT                              = new DWORD(0x00000001);
    public static final DWORD PROXY_TYPE_PROXY                               = new DWORD(0x00000002);
    public static final DWORD PROXY_TYPE_AUTO_PROXY_URL                      = new DWORD(0x00000004);
    public static final DWORD PROXY_TYPE_AUTO_DETECT                         = new DWORD(0x00000008);

    public static final DWORD INTERNET_OPTION_REFRESH                 = new DWORD(37);
    public static final DWORD INTERNET_OPTION_SETTINGS_CHANGED        = new DWORD(39);
    public static final DWORD INTERNET_OPTION_VERSION                 = new DWORD(40);
    public static final DWORD INTERNET_OPTION_USER_AGENT              = new DWORD(41);
    public static final DWORD INTERNET_OPTION_PER_CONNECTION_OPTION   = new DWORD(75);
    public static final DWORD INTERNET_OPTION_PROXY_SETTINGS_CHANGED  = new DWORD(95);

    /*
        typedef struct {
            DWORD dwMajorVersion;
            DWORD dwMinorVersion;
        } INTERNET_VERSION_INFO,* LPINTERNET_VERSION_INFO;
     */     
    public class INTERNET_VERSION_INFO extends Structure {
        public DWORD dwMajorVersion;
        public DWORD dwMinorVersion;
        public INTERNET_VERSION_INFO() {
            super();
            initFieldOrder();
        }
        protected void initFieldOrder() {
            setFieldOrder(new java.lang.String[]{"dwMajorVersion", "dwMinorVersion"});
        }
        public INTERNET_VERSION_INFO(DWORD dwMajorVersion, DWORD dwMinorVersion) {
            super();
            this.dwMajorVersion = dwMajorVersion;
            this.dwMinorVersion = dwMinorVersion;
            initFieldOrder();
        }
        public static class ByReference extends INTERNET_VERSION_INFO implements Structure.ByReference {

        };
        public static class ByValue extends INTERNET_VERSION_INFO implements Structure.ByValue {

        };
    }   

    /*
        typedef struct _INTERNET_PER_CONN_OPTIONW {
            DWORD dwOption;
            union {
                DWORD    dwValue;
                LPWSTR    pszValue;
                FILETIME ftValue;
            } Value;
        } INTERNET_PER_CONN_OPTIONW, *LPINTERNET_PER_CONN_OPTIONW; 
     */
    public class INTERNET_PER_CONN_OPTIONW extends Structure {
        public DWORD dwOption;
        public Value_union Value;
        public static class Value_union extends Union {
            public DWORD dwValue;
            public WString pszValue;
            public FILETIME ftValue;
            public Value_union() {
                super();
            }
            public static class ByReference extends Value_union implements Structure.ByReference {

            };
            public static class ByValue extends Value_union implements Structure.ByValue {

            };
        };
        public INTERNET_PER_CONN_OPTIONW() {
            super();
            initFieldOrder();
        }
        protected void initFieldOrder() {
            setFieldOrder(new java.lang.String[]{"dwOption", "Value"});
        }
        public INTERNET_PER_CONN_OPTIONW(DWORD dwOption, Value_union Value) {
            super();
            this.dwOption = dwOption;
            this.Value = Value;
            initFieldOrder();
        }
        public static class ByReference extends INTERNET_PER_CONN_OPTIONW implements Structure.ByReference {

        };
        public static class ByValue extends INTERNET_PER_CONN_OPTIONW implements Structure.ByValue {

        };
    }

    /*
    typedef struct _INTERNET_PER_CONN_OPTION_LISTW {
        DWORD                       dwSize;
        LPWSTR                      pszConnection;
        DWORD                       dwOptionCount;
        DWORD                       dwOptionError;
        LPINTERNET_PER_CONN_OPTIONW pOptions;
    } INTERNET_PER_CONN_OPTION_LISTW, *LPINTERNET_PER_CONN_OPTION_LISTW;    
     */
    public class INTERNET_PER_CONN_OPTION_LISTW extends Structure {
        public DWORD dwSize;
        public WString pszConnection;
        public DWORD dwOptionCount;
        public DWORD dwOptionError;
        public INTERNET_PER_CONN_OPTIONW.ByReference pOptions;
        public INTERNET_PER_CONN_OPTION_LISTW() {
            super();
            initFieldOrder();
        }
        protected void initFieldOrder() {
            setFieldOrder(new java.lang.String[]{"dwSize", "pszConnection", "dwOptionCount", "dwOptionError", "pOptions"});
        }
        public INTERNET_PER_CONN_OPTION_LISTW(DWORD dwSize, WString pszConnection, DWORD dwOptionCount, DWORD dwOptionError, INTERNET_PER_CONN_OPTIONW.ByReference pOptions) {
            super();
            this.dwSize = dwSize;
            this.pszConnection = pszConnection;
            this.dwOptionCount = dwOptionCount;
            this.dwOptionError = dwOptionError;
            this.pOptions = pOptions;
            initFieldOrder();
        }
        public static class ByReference extends INTERNET_PER_CONN_OPTION_LISTW implements Structure.ByReference {

        };
        public static class ByValue extends INTERNET_PER_CONN_OPTION_LISTW implements Structure.ByValue {

        };
    }
    /*
    BOOL InternetSetOption(
              __in  HINTERNET hInternet,
              __in  DWORD dwOption,
              __in  LPVOID lpBuffer,
              __in  DWORD dwBufferLength
            );
     */    
    public boolean InternetSetOption(
            Pointer hInternet, 
            DWORD dwOption,
            Pointer lpBuffer, 
            IntByReference dwBufferLength);

    public boolean InternetSetOption(
            Pointer hInternet, 
            DWORD dwOption,
            WinInet.INTERNET_PER_CONN_OPTION_LISTW lpBuffer, 
            IntByReference dwBufferLength);

    //BOOLAPI InternetQueryOptionW(HINTERNET ,DWORD ,LPVOID ,LPDWORD);  
    public boolean InternetQueryOption(
            Pointer hInternet,
            DWORD dwOption,
            Pointer lpBuffer,
            IntByReference len
            );
    public boolean InternetQueryOption(
            Pointer hInternet,
            DWORD dwOption,
            WinInet.INTERNET_VERSION_INFO lpBuffer,
            IntByReference len
            );
    public boolean InternetQueryOption(
            Pointer hInternet,
            DWORD dwOption,
            WinInet.INTERNET_PER_CONN_OPTION_LISTW lpBuffer,
            IntByReference len
            );


}