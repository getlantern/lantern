package org.lantern;

import static org.junit.Assert.assertEquals;

import java.io.File;
import java.io.IOException;

import org.apache.commons.io.FileUtils;
import org.junit.Test;

public class S3ConfigTest {

    @Test public void testConfig() throws Exception {
        final String inputString = testFileToString("s3.json");
        final String expectedString = testFileToString("s3.json");
        
        // We just make sure that the serialization and deserialization process
        // doesn't create a different file.
        final S3Config temp = configObject(inputString);
        final String json = JsonUtils.jsonify(temp);
        final S3Config roundTripped = configObject(json);
        final S3Config expected = configObject(expectedString);
        
        assertEquals("Different confs\n:"+expected+"\n"+roundTripped+"\n\n\n\n", expected, roundTripped);
    }
    
    private S3Config configObject(String cfgStr) {
        try {
            return JsonUtils.OBJECT_MAPPER.readValue(cfgStr, S3Config.class);
        } catch (final Exception e) {
            throw new RuntimeException("Could not parse config", e);
        }
    }
    
    private static String testFileToString(String fileName) throws IOException {
        final File file = FileUtils.toFile(
            Thread.currentThread().getContextClassLoader().getResource(fileName)
        );
        return FileUtils.readFileToString(file);
    }

}
