package net.rimoto.intlphoneinput;

public class Country {
    /**
     * Name of country
     */
    private String name;
    /**
     * ISO2 of country
     */
    private String iso;
    /**
     * Dial code prefix of country
     */
    private int dialCode;


    /**
     * Constructor
     *
     * @param name     String
     * @param iso      String of ISO2
     * @param dialCode int
     */
    public Country(String name, String iso, int dialCode) {
        setName(name);
        setIso(iso);
        setDialCode(dialCode);
    }

    /**
     * Get name of country
     *
     * @return String
     */
    public String getName() {
        return name;
    }

    /**
     * Set name of country
     *
     * @param name String
     */
    public void setName(String name) {
        this.name = name;
    }

    /**
     * Get ISO2 of country
     *
     * @return String
     */
    public String getIso() {
        return iso;
    }

    /**
     * Set ISO2 of country
     *
     * @param iso String
     */
    public void setIso(String iso) {
        this.iso = iso.toUpperCase();
    }

    /**
     * Get dial code prefix of country (like +1)
     *
     * @return int
     */
    public int getDialCode() {
        return dialCode;
    }

    /**
     * Set dial code prefix of country (like +1)
     *
     * @param dialCode int (without + prefix!)
     */
    public void setDialCode(int dialCode) {
        this.dialCode = dialCode;
    }

    /**
     * Check if equals
     *
     * @param o Object to compare
     * @return boolean
     */
    @Override
    public boolean equals(Object o) {
        return (o instanceof Country) && (((Country) o).getIso().toUpperCase().equals(this.getIso().toUpperCase()));
    }
}
