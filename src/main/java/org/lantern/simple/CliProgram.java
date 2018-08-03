package org.lantern.simple;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.PosixParser;

public abstract class CliProgram {
    protected final Options options = new Options();
    protected CommandLine cmd;

    protected CliProgram(String[] args) {
        initializeCliOptions();
        CommandLineParser parser = new PosixParser();
        try {
            cmd = parser.parse(options, args);
            if (cmd.getArgs().length > 0) {
                showUsageAndExit("Too many arguments provided");
            }
        } catch (ParseException pe) {
            showUsageAndExit(pe.getMessage());
        }
    }

    protected abstract void initializeCliOptions();

    protected void addOption(Option option, boolean required) {
        option.setRequired(required);
        options.addOption(option);
    }

    protected void showUsageAndExit(String errorMessage) {
        if (errorMessage != null) {
            System.err.println(errorMessage);
        }

        final HelpFormatter formatter = new HelpFormatter();
        formatter.printHelp(String.format("./launch %1$s [options]", this
                .getClass().getName()),
                options);

        System.exit(1);
    }

}
