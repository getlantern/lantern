package org.lantern;

import static org.junit.Assert.assertEquals;

import java.io.File;
import java.io.IOException;

import org.apache.commons.io.FileUtils;
import org.junit.Test;

public class S3ConfigTest {

    @Test public void testConfig() throws Exception {
        final String config1 = testFileToString("s3config1.txt");
        final String config2 = testFileToString("s3config2.txt");
        
        // This is the key. The above raw string represent the file coming in
        // over the network. We need to generate an object, serialize it, and
        // regenerate the object to simulate storing to disk and restarting.
        final S3Config temp = configObject(config1);
        final String json = JsonUtils.jsonify(temp);
        final S3Config conf1 = configObject(json);
        final S3Config conf2 = configObject(config2);
        
        assertEquals("Different confs\n:"+conf1+"\n"+conf2+"\n\n\n\n", conf1, conf2);
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
