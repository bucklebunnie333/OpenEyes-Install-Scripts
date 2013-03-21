/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package org.statefive.encodeutils;

import org.junit.After;
import org.junit.AfterClass;
import org.junit.Before;
import org.junit.BeforeClass;
import org.junit.Test;
import static org.junit.Assert.*;

/**
 *
 * @author rich
 */
public class EncodeUtilsTest {
    
    public EncodeUtilsTest() {
    }
    
    @BeforeClass
    public static void setUpClass() {
    }
    
    @AfterClass
    public static void tearDownClass() {
    }
    
    @Before
    public void setUp() {
    }
    
    @After
    public void tearDown() {
    }

    /**
     * Test of md5 method, of class EncodeUtils.
     * 
     * To check the value of MD5 hashes, go to:
     * 
     * http://www.webtoolkit.info/demo/javascript-md5
     */
    @Test
    public void testMd5() throws Exception {
        // Here we're testing that the patient ID, '1000001', matches
        // the expected value from the MD5 checksum. To see other values
        // (or test 100001 in action) using the BASH shell, try:
        //   echo '1000001' | tr -d '\n' | md5sum
        // ... or whatever value you require in place of '1000001'.
        // (Note if you do not trim the newline at the end of the BASH call
        // you will get a different result).
        String md5 = "1000001";
        EncodeUtils instance = new EncodeUtils();
        String expResult = "59e711d152de7bec7304a8c2ecaf9f0f";
        String result = instance.md5(md5);
        assertEquals(expResult, result);
    }
}
