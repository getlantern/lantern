package org.lantern.monitoring;

import java.util.Map;

public class StatsResponse {
    private Stats detail;
    private Rollups rollups;
    
    public StatsResponse() {
    }

    public Stats getDetail() {
        return detail;
    }

    public void setDetail(Stats detail) {
        this.detail = detail;
    }
    
    public Rollups getRollups() {
        return rollups;
    }
    
    public void setRollups(Rollups rollups) {
        this.rollups = rollups;
    }

    public static class Rollups {
        private Stats global;
        private Map<String, Stats> perCountry;

        public Stats getGlobal() {
            return global;
        }

        public void setGlobal(Stats global) {
            this.global = global;
        }

        public Map<String, Stats> getPerCountry() {
            return perCountry;
        }

        public void setPerCountry(Map<String, Stats> perCountry) {
            this.perCountry = perCountry;
        }
    }
    
    

}
