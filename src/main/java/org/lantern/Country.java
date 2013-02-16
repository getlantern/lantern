package org.lantern;

import java.util.ArrayList;
import java.util.List;

import org.lantern.state.NPeers;
import org.lantern.state.NUsers;

public class Country {

    private String code;
    private String name;
    private boolean censoring;

    private long bps;
    private long bytesEver;

    private NUsers nusers = new NUsers();
    private NPeers npeers = new NPeers();

    private static String[] countryTable = {
        "AD", "ANDORRA",
        "AE", "UNITED ARAB EMIRATES",
        "AF", "AFGHANISTAN",
        "AG", "ANTIGUA AND BARBUDA",
        "AI", "ANGUILLA",
        "AL", "ALBANIA",
        "AM", "ARMENIA",
        "AO", "ANGOLA",
        "AQ", "ANTARCTICA",
        "AR", "ARGENTINA",
        "AS", "AMERICAN SAMOA",
        "AT", "AUSTRIA",
        "AU", "AUSTRALIA",
        "AW", "ARUBA",
        "AX", "ÅLAND ISLANDS",
        "AZ", "AZERBAIJAN",
        "BA", "BOSNIA AND HERZEGOVINA",
        "BB", "BARBADOS",
        "BD", "BANGLADESH",
        "BE", "BELGIUM",
        "BF", "BURKINA FASO",
        "BG", "BULGARIA",
        "BH", "BAHRAIN",
        "BI", "BURUNDI",
        "BJ", "BENIN",
        "BL", "SAINT BARTHÉLEMY",
        "BM", "BERMUDA",
        "BN", "BRUNEI DARUSSALAM",
        "BO", "BOLIVIA",
        "BQ", "BONAIRE, SINT EUSTATIUS AND SABA",
        "BR", "BRAZIL",
        "BS", "BAHAMAS",
        "BT", "BHUTAN",
        "BV", "BOUVET ISLAND",
        "BW", "BOTSWANA",
        "BY", "BELARUS",
        "BZ", "BELIZE",
        "CA", "CANADA",
        "CC", "COCOS (KEELING) ISLANDS",
        "CD", "THE DEMOCRATIC REPUBLIC OF THE CONGO",
        "CF", "CENTRAL AFRICAN REPUBLIC",
        "CG", "CONGO",
        "CH", "SWITZERLAND",
        "CI", "CÔTE D'IVOIRE",
        "CK", "COOK ISLANDS",
        "CL", "CHILE",
        "CM", "CAMEROON",
        "CN", "CHINA",
        "CO", "COLOMBIA",
        "CR", "COSTA RICA",
        "CU", "CUBA",
        "CV", "CAPE VERDE",
        "CW", "CURAÇAO",
        "CX", "CHRISTMAS ISLAND",
        "CY", "CYPRUS",
        "CZ", "CZECH REPUBLIC",
        "DE", "GERMANY",
        "DJ", "DJIBOUTI",
        "DK", "DENMARK",
        "DM", "DOMINICA",
        "DO", "DOMINICAN REPUBLIC",
        "DZ", "ALGERIA",
        "EC", "ECUADOR",
        "EE", "ESTONIA",
        "EG", "EGYPT",
        "EH", "WESTERN SAHARA",
        "ER", "ERITREA",
        "ES", "SPAIN",
        "ET", "ETHIOPIA",
        "FI", "FINLAND",
        "FJ", "FIJI",
        "FK", "FALKLAND ISLANDS (MALVINAS)",
        "FM", "FEDERATED STATES OF MICRONESIA",
        "FO", "FAROE ISLANDS",
        "FR", "FRANCE",
        "GA", "GABON",
        "GB", "UNITED KINGDOM",
        "GD", "GRENADA",
        "GE", "GEORGIA",
        "GF", "FRENCH GUIANA",
        "GG", "GUERNSEY",
        "GH", "GHANA",
        "GI", "GIBRALTAR",
        "GL", "GREENLAND",
        "GM", "GAMBIA",
        "GN", "GUINEA",
        "GP", "GUADELOUPE",
        "GQ", "EQUATORIAL GUINEA",
        "GR", "GREECE",
        "GS", "SOUTH GEORGIA AND THE SOUTH SANDWICH ISLANDS",
        "GT", "GUATEMALA",
        "GU", "GUAM",
        "GW", "GUINEA-BISSAU",
        "GY", "GUYANA",
        "HK", "HONG KONG",
        "HM", "HEARD ISLAND AND MCDONALD ISLANDS",
        "HN", "HONDURAS",
        "HR", "CROATIA",
        "HT", "HAITI",
        "HU", "HUNGARY",
        "ID", "INDONESIA",
        "IE", "IRELAND",
        "IL", "ISRAEL",
        "IM", "ISLE OF MAN",
        "IN", "INDIA",
        "IO", "BRITISH INDIAN OCEAN TERRITORY",
        "IQ", "IRAQ",
        "IR", "ISLAMIC REPUBLIC OF IRAN",
        "IS", "ICELAND",
        "IT", "ITALY",
        "JE", "JERSEY",
        "JM", "JAMAICA",
        "JO", "JORDAN",
        "JP", "JAPAN",
        "KE", "KENYA",
        "KG", "KYRGYZSTAN",
        "KH", "CAMBODIA",
        "KI", "KIRIBATI",
        "KM", "COMOROS",
        "KN", "SAINT KITTS AND NEVIS",
        "KP", "DEMOCRATIC PEOPLE'S REPUBLIC OF KOREA",
        "KR", "REPUBLIC OF KOREA",
        "KW", "KUWAIT",
        "KY", "CAYMAN ISLANDS",
        "KZ", "KAZAKHSTAN",
        "LA", "LAO PEOPLE'S DEMOCRATIC REPUBLIC",
        "LB", "LEBANON",
        "LC", "SAINT LUCIA",
        "LI", "LIECHTENSTEIN",
        "LK", "SRI LANKA",
        "LR", "LIBERIA",
        "LS", "LESOTHO",
        "LT", "LITHUANIA",
        "LU", "LUXEMBOURG",
        "LV", "LATVIA",
        "LY", "LIBYA",
        "MA", "MOROCCO",
        "MC", "MONACO",
        "MD", "REPUBLIC OF MOLDOVA",
        "ME", "MONTENEGRO",
        "MF", "SAINT MARTIN (FRENCH PART)",
        "MG", "MADAGASCAR",
        "MH", "MARSHALL ISLANDS",
        "MK", "MACEDONIA",
        "ML", "MALI",
        "MM", "MYANMAR",
        "MN", "MONGOLIA",
        "MO", "MACAO",
        "MP", "NORTHERN MARIANA ISLANDS",
        "MQ", "MARTINIQUE",
        "MR", "MAURITANIA",
        "MS", "MONTSERRAT",
        "MT", "MALTA",
        "MU", "MAURITIUS",
        "MV", "MALDIVES",
        "MW", "MALAWI",
        "MX", "MEXICO",
        "MY", "MALAYSIA",
        "MZ", "MOZAMBIQUE",
        "NA", "NAMIBIA",
        "NC", "NEW CALEDONIA",
        "NE", "NIGER",
        "NF", "NORFOLK ISLAND",
        "NG", "NIGERIA",
        "NI", "NICARAGUA",
        "NL", "NETHERLANDS",
        "NO", "NORWAY",
        "NP", "NEPAL",
        "NR", "NAURU",
        "NU", "NIUE",
        "NZ", "NEW ZEALAND",
        "OM", "OMAN",
        "PA", "PANAMA",
        "PE", "PERU",
        "PF", "FRENCH POLYNESIA",
        "PG", "PAPUA NEW GUINEA",
        "PH", "PHILIPPINES",
        "PK", "PAKISTAN",
        "PL", "POLAND",
        "PM", "SAINT PIERRE AND MIQUELON",
        "PN", "PITCAIRN",
        "PR", "PUERTO RICO",
        "PS", "PALESTINIAN TERRITORY, OCCUPIED",
        "PT", "PORTUGAL",
        "PW", "PALAU",
        "PY", "PARAGUAY",
        "QA", "QATAR",
        "RE", "RÉUNION",
        "RO", "ROMANIA",
        "RS", "SERBIA",
        "RU", "RUSSIAN FEDERATION",
        "RW", "RWANDA",
        "SA", "SAUDI ARABIA",
        "SB", "SOLOMON ISLANDS",
        "SC", "SEYCHELLES",
        "SD", "SUDAN",
        "SE", "SWEDEN",
        "SG", "SINGAPORE",
        "SH", "SAINT HELENA, ASCENSION AND TRISTAN DA CUNHA",
        "SI", "SLOVENIA",
        "SJ", "SVALBARD AND JAN MAYEN",
        "SK", "SLOVAKIA",
        "SL", "SIERRA LEONE",
        "SM", "SAN MARINO",
        "SN", "SENEGAL",
        "SO", "SOMALIA",
        "SR", "SURINAME",
        "SS", "SOUTH SUDAN",
        "ST", "SAO TOME AND PRINCIPE",
        "SV", "EL SALVADOR",
        "SX", "SINT MAARTEN (DUTCH PART)",
        "SY", "SYRIAN ARAB REPUBLIC",
        "SZ", "SWAZILAND",
        "TC", "TURKS AND CAICOS ISLANDS",
        "TD", "CHAD",
        "TF", "FRENCH SOUTHERN TERRITORIES",
        "TG", "TOGO",
        "TH", "THAILAND",
        "TJ", "TAJIKISTAN",
        "TK", "TOKELAU",
        "TL", "TIMOR-LESTE",
        "TM", "TURKMENISTAN",
        "TN", "TUNISIA",
        "TO", "TONGA",
        "TR", "TURKEY",
        "TT", "TRINIDAD AND TOBAGO",
        "TV", "TUVALU",
        "TW", "TAIWAN",
        "TZ", "UNITED REPUBLIC OF TANZANIA",
        "UA", "UKRAINE",
        "UG", "UGANDA",
        "UM", "UNITED STATES MINOR OUTLYING ISLANDS",
        "US", "UNITED STATES",
        "UY", "URUGUAY",
        "UZ", "UZBEKISTAN",
        "VA", "VATICAN CITY",
        "VC", "SAINT VINCENT AND THE GRENADINES",
        "VE", "VENEZUELA, BOLIVARIAN REPUBLIC",
        "VG", "VIRGIN ISLANDS, BRITISH",
        "VI", "VIRGIN ISLANDS, U.S.",
        "VN", "VIET NAM",
        "VU", "VANUATU",
        "WF", "WALLIS AND FUTUNA",
        "WS", "SAMOA",
        "YE", "YEMEN",
        "YT", "MAYOTTE",
        "ZA", "SOUTH AFRICA",
        "ZM", "ZAMBIA",
        "ZW", "ZIMBABWE",
    };


    public Country() {

    }

    public Country(final String code, final String name, final boolean cens) {
        this.code = code;
        this.name = name;
        this.censoring = cens;
    }

    public void setCode(final String code) {
        this.code = code;
    }

    public String getCode() {
        return code;
    }

    public void setName(final String name) {
        this.name = name;
    }

    public String getName() {
        return name;
    }

    public void setCensoring(final boolean censoring) {
        this.censoring = censoring;
    }

    public boolean isCensoring() {
        return censoring;
    }

    public static List<Country> allCountries() {
        ArrayList<Country> allCountries = new ArrayList<Country>();
        DefaultCensored censored = new DefaultCensored();
        for (int i = 0; i < countryTable.length; i += 2) {
            String countryCode = countryTable[i];
            String countryName = countryTable[i+1];
            boolean isCensored = censored.isCountryCodeCensored(countryCode);
            allCountries.add(new Country(countryCode, countryName, isCensored));
        }
        return allCountries;
    }

    public long getBps() {
        return bps;
    }

    public void setBps(long bps) {
        this.bps = bps;
    }

    public long getBytesEver() {
        return bytesEver;
    }

    public void setBytesEver(long bytesEver) {
        this.bytesEver = bytesEver;
    }

    public NUsers getNusers() {
        return nusers;
    }

    public void setNusers(NUsers nusers) {
        this.nusers = nusers;
    }

    public NPeers getNpeers() {
        return npeers;
    }

    public void setNpeers(NPeers npeers) {
        this.npeers = npeers;
    }

}
