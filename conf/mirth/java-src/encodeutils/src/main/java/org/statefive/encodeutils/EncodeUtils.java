/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package org.statefive.encodeutils;

/**
 * MD5 encoding utilities.
 * 
 * @author rich
 */
public class EncodeUtils {

    /**
     * Inspired and adapted from:
     * 
     * http://stackoverflow.com/questions/415953/generate-md5-hash-in-java
     * 
     * 
     * @param md5 a non-{@code null} string to turn in to a hash.
     * 
     * @return an encoded hash string.
     * 
     * @throws Exception if the MD5 implementation is not available on
     * the host platform.
     */
    public String md5(String md5) throws Exception {

        String s = null;
        try {
            java.security.MessageDigest md =
                    java.security.MessageDigest.getInstance("MD5");
            byte[] array = md.digest(md5.getBytes());
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < array.length; ++i) {
                sb.append(Integer.toHexString((array[i] & 0xFF)
                        | 0x100).substring(1, 3));
            }
            s = sb.toString();
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new Exception(e);
        }
        return s;
    }
}
