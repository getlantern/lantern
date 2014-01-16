package org.lantern.monitoring;

import java.beans.PropertyDescriptor;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryMXBean;
import java.lang.management.OperatingSystemMXBean;
import java.lang.reflect.Method;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.TimeUnit;

import org.apache.commons.beanutils.PropertyUtils;
import org.lantern.ClientStats;
import org.lantern.LanternService;
import org.lantern.LanternUtils;
import org.lantern.state.Model;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.codahale.metrics.Gauge;
import com.codahale.metrics.MetricRegistry;
import com.google.inject.Inject;
import com.librato.metrics.LibratoReporter;

/**
 * <p>
 * This class reports statistics to our centralized statistics registry
 * (currently Librato).
 * </p>
 * 
 * <p>
 * Thanks to
 * http://stackoverflow.com/questions/10999076/programmatically-print-the
 * -heap-usage-that-is-typically-printed-on-jvm-exit-when and
 * http://neopatel.blogspot.com/2011/05/java-count-open-file-handles.html for
 * tips on getting at the necessary data.
 * </p>
 */
@SuppressWarnings("unchecked")
public class StatsReporter implements LanternService {
    private static final Logger LOG = LoggerFactory
            .getLogger(StatsReporter.class);

    private static final String LIBRATO_USER_NAME = "ox@getlantern.org";
    // Note - this token only has access to record/view stats and can't do any
    // admin stuff
    private static final String LIBRATO_API_TOKEN = "7c10ebf9e817e301cc578141658284bfa9f4a15bf938143b386142f854be0afe";

    private static final int LIBRATO_REPORTING_INTERVAL = 600;

    private final Model model;
    private final ClientStats stats;

    private final MemoryMXBean memoryMXBean = ManagementFactory
            .getMemoryMXBean();
    private final OperatingSystemMXBean osStats = ManagementFactory
            .getOperatingSystemMXBean();

    private final MetricRegistry perInstanceMetrics = new MetricRegistry();
    private final MetricRegistry globalMetrics = new MetricRegistry();

    @Inject
    public StatsReporter(Model model, ClientStats stats) {
        this.model = model;
        this.stats = stats;
        initializeSystemMetrics();
        initializeLanternMetrics();
    }

    @Override
    public void start() {
        startReportingMetricsToLibrato();
    }

    @Override
    public void stop() {
        // do nothing
    }

    private void startReportingMetricsToLibrato() {
        LOG.debug("Starting to report metrics to Librato every {} seconds",
                LIBRATO_REPORTING_INTERVAL);
        LibratoReporter
                .enable(
                        LibratoReporter
                                .builder(
                                        perInstanceMetrics,
                                        LIBRATO_USER_NAME,
                                        LIBRATO_API_TOKEN,
                                        "Proxy-" + model.getInstanceId()),
                        LIBRATO_REPORTING_INTERVAL,
                        TimeUnit.SECONDS);
        LibratoReporter
                .enable(
                        LibratoReporter
                                .builder(
                                        globalMetrics,
                                        LIBRATO_USER_NAME,
                                        LIBRATO_API_TOKEN,
                                        LanternUtils.isFallbackProxy() ? "Fallbacks"
                                                : "Peers"),
                        LIBRATO_REPORTING_INTERVAL,
                        TimeUnit.SECONDS);
    }

    /**
     * Add metrics for system monitoring.
     */
    private void initializeSystemMetrics() {
        perInstanceMetrics.register("SystemStat_Process_CPU_Usage",
                new Gauge<Double>() {
                    @Override
                    public Double getValue() {
                        return (Double) getSystemStat("getProcessCpuLoad");
                    }
                });
        perInstanceMetrics.register("SystemStat_System_CPU_Usage",
                new Gauge<Double>() {
                    @Override
                    public Double getValue() {
                        return (Double) getSystemStat("getSystemCpuLoad");
                    }
                });
        perInstanceMetrics.register("SystemStat_System_Load_Average",
                new Gauge<Double>() {
                    @Override
                    public Double getValue() {
                        return (Double) osStats.getSystemLoadAverage();
                    }
                });
        perInstanceMetrics.register("SystemStat_Process_Memory_Usage",
                new Gauge<Double>() {
                    @Override
                    public Double getValue() {
                        return (double) memoryMXBean.getHeapMemoryUsage()
                                .getCommitted() +
                                memoryMXBean.getNonHeapMemoryUsage()
                                        .getCommitted();
                    }
                });
        perInstanceMetrics.register(
                "SystemStat_Process_Number_of_Open_File_Descriptors",
                new Gauge<Long>() {
                    @Override
                    public Long getValue() {
                        return (Long) getSystemStat("getOpenFileDescriptorCount");
                    }
                });
    }

    private <T extends Number> T getSystemStat(final String name) {
        if (!isOnUnix()) {
            return (T) (Double) 0.0;
        } else {
            try {
                final Method method = osStats.getClass()
                        .getDeclaredMethod(name);
                method.setAccessible(true);
                return (T) method.invoke(osStats);
            } catch (final Exception e) {
                LOG.debug("Unable to get system stat: {}", name, e);
                return (T) (Double) 0.0;
            }
        }
    }

    private boolean isOnUnix() {
        return osStats.getClass().getName()
                .equals("com.sun.management.UnixOperatingSystem");
    }

    /**
     * Add gauges for Lantern-specific statistics
     */
    private void initializeLanternMetrics() {
        perInstanceMetrics.register(
                "LanternStat_countOfDistinctProxiedClientAddresses",
                new Gauge<Long>() {
                    @Override
                    public Long getValue() {
                        return stats.getCountOfDistinctProxiedClientAddresses();
                    }
                });
        initializeMetrics(perInstanceMetrics,
                "bytesProxiedForIran",
                "bytesProxiedForChina");
        initializeMetrics(globalMetrics,
                "globalBytesProxiedForIran",
                "globalBytesProxiedForChina");
    }

    private void initializeMetrics(MetricRegistry registry,
            String... includeMetrics) {
        Set<String> include = new HashSet<String>();
        for (String metric : includeMetrics) {
            include.add(metric);
        }
        for (PropertyDescriptor property : PropertyUtils
                .getPropertyDescriptors(ClientStats.class)) {
            Class<?> type = property.getPropertyType();
            boolean isNumeric = Number.class.isAssignableFrom(type)
                    || Long.TYPE.equals(type)
                    || Integer.TYPE.equals(type)
                    || Double.TYPE.equals(type)
                    || Float.TYPE.equals(type);
            final String name = property.getName();
            boolean shouldInclude = isNumeric && include.isEmpty()
                    || include.contains(name);
            if (shouldInclude) {
                final Method getter = property.getReadMethod();
                LOG.debug("Adding metric for statistic {}", name);
                registry.register("LanternStat_" + name,
                        new Gauge<Number>() {
                            @Override
                            public Number getValue() {
                                try {
                                    return (Number) getter.invoke(stats);
                                } catch (Exception e) {
                                    LOG.warn("Unable to get metric {}", name);
                                    return 0;
                                }
                            }
                        });
            }
        }
    }
}
