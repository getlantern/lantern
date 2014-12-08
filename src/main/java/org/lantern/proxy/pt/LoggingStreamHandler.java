package org.lantern.proxy.pt;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;

import org.apache.commons.exec.ExecuteException;
import org.apache.commons.exec.ExecuteStreamHandler;
import org.apache.commons.exec.Executor;
import org.apache.commons.exec.InputStreamPumper;
import org.apache.commons.exec.PumpStreamHandler;
import org.apache.commons.exec.StreamPumper;
import org.apache.commons.exec.util.DebugUtils;
import org.slf4j.Logger;

/**
 * <p>
 * Copies standard output and error of sub-processes to log at DEBUG and ERROR
 * of a configured {@link Logger}.
 * </p>
 * 
 * <p>
 * Based on {@link PumpStreamHandler}.
 * </p>
 */
public class LoggingStreamHandler implements ExecuteStreamHandler {

    private static final long STOP_TIMEOUT_ADDITION = 2000L;

    private Thread outputThread;

    private Thread errorThread;

    private Thread inputThread;

    private final Logger log;

    private final InputStream input;

    private InputStreamPumper inputStreamPumper;

    /**
     * the timeout in ms the implementation waits when stopping the pumper
     * threads
     */
    private long stopTimeout;

    /** the last exception being caught */
    private IOException caught = null;

    public LoggingStreamHandler(Logger log, InputStream input) {
        this.log = log;
        this.input = input;
    }

    /**
     * Set maximum time to wait until output streams are exchausted when
     * {@link #stop()} was called.
     * 
     * @param timeout
     *            timeout in milliseconds or zero to wait forever (default)
     */
    public void setStopTimeout(final long timeout) {
        this.stopTimeout = timeout;
    }

    /**
     * Set the <CODE>InputStream</CODE> from which to read the standard output
     * of the process.
     * 
     * @param is
     *            the <CODE>InputStream</CODE>.
     */
    public void setProcessOutputStream(final InputStream is) {
        outputThread = createLoggingThread(is, false);
    }

    /**
     * Set the <CODE>InputStream</CODE> from which to read the standard error of
     * the process.
     * 
     * @param is
     *            the <CODE>InputStream</CODE>.
     */
    public void setProcessErrorStream(final InputStream is) {
        errorThread = createLoggingThread(is, true);
    }

    private Thread createLoggingThread(InputStream is, final boolean logToError) {
        final BufferedReader reader = new BufferedReader(new InputStreamReader(
                is));
        return new Thread(new Runnable() {
            @Override
            public void run() {
                String line = null;
                StringBuilder panicTrace = null;
                try {
                    while ((line = reader.readLine()) != null) {
                        if (line.startsWith("panic: ")) {
                            // Go program panicked, combine final output into one message
                            panicTrace = new StringBuilder();
                        }
                        if (panicTrace != null) {
                            panicTrace.append(line);
                            panicTrace.append("\n");
                            continue;
                        }
                        handleLine(line, logToError);
                    }
                } catch (IOException ioe) {
                    log.error("Unable to read line from pipe: {}",
                            ioe.getMessage(), ioe);
                }
                if (panicTrace != null) {
                    log.error(panicTrace.toString());
                }
            }
        }, "LoggingStreamHandler-error-"+logToError);
    }
    
    protected void handleLine(String line, boolean logToError) {
        if (logToError) {
            log.error(line);
        } else {
            log.debug(line);
        }
    }

    /**
     * Set the <CODE>OutputStream</CODE> by means of which input can be sent to
     * the process.
     * 
     * @param os
     *            the <CODE>OutputStream</CODE>.
     */
    public void setProcessInputStream(final OutputStream os) {
        if (input != null) {
            if (input == System.in) {
                inputThread = createSystemInPump(input, os);
            } else {
                inputThread = createPump(input, os, true);
            }
        } else {
            try {
                os.close();
            } catch (final IOException e) {
                final String msg = "Got exception while closing output stream";
                DebugUtils.handleException(msg, e);
            }
        }
    }

    /**
     * Start the <CODE>Thread</CODE>s.
     */
    public void start() {
        if (outputThread != null) {
            outputThread.start();
        }
        if (errorThread != null) {
            errorThread.start();
        }
        if (inputThread != null) {
            inputThread.start();
        }
    }

    /**
     * Stop pumping the streams. When a timeout is specified it it is not
     * guaranteed that the pumper threads are cleanly terminated.
     */
    public void stop() throws IOException {

        if (inputStreamPumper != null) {
            inputStreamPumper.stopProcessing();
        }

        stopThread(outputThread, stopTimeout);
        stopThread(errorThread, stopTimeout);
        stopThread(inputThread, stopTimeout);

        if (caught != null) {
            throw caught;
        }
    }

    /**
     * Creates a stream pumper to copy the given input stream to the given
     * output stream.
     * 
     * @param is
     *            the input stream to copy from
     * @param os
     *            the output stream to copy into
     * @param closeWhenExhausted
     *            close the output stream when the input stream is exhausted
     * @return the stream pumper thread
     */
    protected Thread createPump(final InputStream is, final OutputStream os,
            final boolean closeWhenExhausted) {
        final Thread result = new Thread(new StreamPumper(is, os,
                closeWhenExhausted), "Exec Stream Pumper");
        result.setDaemon(true);
        return result;
    }

    /**
     * Stopping a pumper thread. The implementation actually waits longer than
     * specified in 'timeout' to detect if the timeout was indeed exceeded. If
     * the timeout was exceeded an IOException is created to be thrown to the
     * caller.
     * 
     * @param thread
     *            the thread to be stopped
     * @param timeout
     *            the time in ms to wait to join
     */
    protected void stopThread(final Thread thread, final long timeout) {

        if (thread != null) {
            try {
                if (timeout == 0) {
                    thread.join();
                } else {
                    final long timeToWait = timeout + STOP_TIMEOUT_ADDITION;
                    final long startTime = System.currentTimeMillis();
                    thread.join(timeToWait);
                    if (!(System.currentTimeMillis() < startTime + timeToWait)) {
                        final String msg = "The stop timeout of " + timeout
                                + " ms was exceeded";
                        caught = new ExecuteException(msg,
                                Executor.INVALID_EXITVALUE);
                    }
                }
            } catch (final InterruptedException e) {
                thread.interrupt();
            }
        }
    }

    /**
     * Creates a stream pumper to copy the given input stream to the given
     * output stream.
     * 
     * @param is
     *            the System.in input stream to copy from
     * @param os
     *            the output stream to copy into
     * @return the stream pumper thread
     */
    private Thread createSystemInPump(final InputStream is,
            final OutputStream os) {
        inputStreamPumper = new InputStreamPumper(is, os);
        final Thread result = new Thread(inputStreamPumper,
                "Exec Input Stream Pumper");
        result.setDaemon(true);
        return result;
    }
}
