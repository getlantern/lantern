package org.lantern.win;

import com.sun.jna.Pointer;
import com.sun.jna.WString;
import com.sun.jna.platform.win32.WinDef.DWORD;
import com.sun.jna.ptr.IntByReference;

/**
 * Adapted from:
 * 
 * http://stackoverflow.com/questions/5501787/invoke-wininet-functions-used-java-jna
 */
public class WindowsProxy {

    public static void setProxySettings() {

        Pointer hInternet = null;
        IntByReference len = new IntByReference();

        System.out.println("Get version...");

        WinInet.INTERNET_VERSION_INFO versionInfo = null;

        if (!WinInet.INSTANCE.InternetQueryOption(hInternet,WinInet.INTERNET_OPTION_VERSION, versionInfo, len)){
        /*
            ERROR_INSUFFICIENT_BUFFER
            122 (0x7A)
            The data area passed to a system call is too small.     
        */
            System.out.println("InternetQueryOption failed!:" + Kernel32.INSTANCE.GetLastError());
        }

        versionInfo = new WinInet.INTERNET_VERSION_INFO();

        if (!WinInet.INSTANCE.InternetQueryOption(hInternet,WinInet.INTERNET_OPTION_VERSION, versionInfo, len)){
            System.out.println("InternetQueryOption failed!:" + Kernel32.INSTANCE.GetLastError());
        }
        System.out.println("Version:" + versionInfo.dwMajorVersion + "." + versionInfo.dwMinorVersion); //IE5+ = 1.2

        System.out.println("Set proxy...");

        WinInet.INTERNET_PER_CONN_OPTION_LISTW optionlist2 = new WinInet.INTERNET_PER_CONN_OPTION_LISTW();

        WinInet.INTERNET_PER_CONN_OPTIONW.ByReference ref2 = new WinInet.INTERNET_PER_CONN_OPTIONW.ByReference();
        WinInet.INTERNET_PER_CONN_OPTIONW[] option2 = (WinInet.INTERNET_PER_CONN_OPTIONW[])ref2.toArray(3);

        option2[0].dwOption = WinInet.INTERNET_PER_CONN_PROXY_SERVER;
        option2[0].Value.pszValue = new WString("http=http://localhost:8080");

        option2[1].dwOption = WinInet.INTERNET_PER_CONN_FLAGS; 
        option2[1].Value.dwValue = new DWORD(WinInet.PROXY_TYPE_PROXY.byteValue() | WinInet.PROXY_TYPE_DIRECT.byteValue());

        option2[2].dwOption = WinInet.INTERNET_PER_CONN_PROXY_BYPASS; 
        option2[2].Value.pszValue = new WString("<local>"); 

        optionlist2.pszConnection = null;
        optionlist2.dwOptionCount = new DWORD(3);
        optionlist2.dwOptionError = new DWORD(0);
        optionlist2.pOptions = ref2;

        if (!WinInet.INSTANCE.InternetSetOption(hInternet,WinInet.INTERNET_OPTION_PER_CONNECTION_OPTION, optionlist2, len)){
            System.out.println("InternetSetOption failed!:" + Kernel32.INSTANCE.GetLastError());
        }

//      System.out.println("Set changed...");
//      
//      if (!WinInet.INSTANCE.InternetSetOption(hInternet,WinInet.INTERNET_OPTION_SETTINGS_CHANGED, (Pointer)null, len)){
//          System.out.println("InternetSetOption failed!:" + Kernel32.INSTANCE.GetLastError());
//      }

        System.out.println("Set refreshed...");

        if (!WinInet.INSTANCE.InternetSetOption(hInternet,WinInet.INTERNET_OPTION_REFRESH, (Pointer)null, len)){
            System.out.println("InternetSetOption failed!:" + Kernel32.INSTANCE.GetLastError());
        }


        System.out.println("Get options...");

        WinInet.INTERNET_PER_CONN_OPTION_LISTW optionlist = new WinInet.INTERNET_PER_CONN_OPTION_LISTW();

        WinInet.INTERNET_PER_CONN_OPTIONW.ByReference ref = new WinInet.INTERNET_PER_CONN_OPTIONW.ByReference();
        WinInet.INTERNET_PER_CONN_OPTIONW[] option = (WinInet.INTERNET_PER_CONN_OPTIONW[])ref.toArray(5);

        option[0].dwOption = WinInet.INTERNET_PER_CONN_AUTOCONFIG_URL;
        option[1].dwOption = WinInet.INTERNET_PER_CONN_AUTODISCOVERY_FLAGS;
        option[2].dwOption = WinInet.INTERNET_PER_CONN_FLAGS;
        option[3].dwOption = WinInet.INTERNET_PER_CONN_PROXY_BYPASS;
        option[4].dwOption = WinInet.INTERNET_PER_CONN_PROXY_SERVER;

        optionlist.pszConnection = null;
        optionlist.dwOptionCount = new DWORD(5);
        optionlist.dwOptionError = new DWORD(0);
        optionlist.pOptions = ref;
        optionlist.dwSize = new DWORD(optionlist.size());

        if (!WinInet.INSTANCE.InternetQueryOption(hInternet,WinInet.INTERNET_OPTION_PER_CONNECTION_OPTION, optionlist, len)){
        /*
            ERROR_INTERNET_BAD_OPTION_LENGTH
            12010
            The length of an option supplied to InternetQueryOption or InternetSetOption is incorrect for the type of option specified. 
        */

            System.out.println("InternetQueryOption failed!:" + Kernel32.INSTANCE.GetLastError());
        }

        if(option[0].Value.pszValue != null)
            System.out.println(option[0].Value.pszValue);

        if((option[2].Value.dwValue.byteValue() & WinInet.PROXY_TYPE_AUTO_PROXY_URL.byteValue()) == WinInet.PROXY_TYPE_AUTO_PROXY_URL.byteValue())
            System.out.println("PROXY_TYPE_AUTO_PROXY_URL");

        if((option[2].Value.dwValue.byteValue() & WinInet.PROXY_TYPE_AUTO_DETECT.byteValue()) == WinInet.PROXY_TYPE_AUTO_DETECT.byteValue())
            System.out.println("PROXY_TYPE_AUTO_DETECT");    

    }

    public static void main(String[] args) {
        setProxySettings();
    }
}