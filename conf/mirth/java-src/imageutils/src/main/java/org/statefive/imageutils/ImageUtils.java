package org.statefive.imageutils;

import java.awt.*;
import java.awt.geom.*;
import java.awt.image.*;
import java.io.*;
import javax.imageio.*;

/**
 * Utility class for image operations.
 * 
 * @author rich
 */
public class ImageUtils {

    /**
     * Resizes the specified source image with the given width and height,
     * writing it to the specified non-existent file.
     * 
     * <p>
     * Taken from
     * <a href="http://www.velocityreviews.com/forums/t148931-how-to-resize-a-jpg-image-file.html"
     * \>here</href>.
     * </p>
     * 
     * @param src a pre-existing non-{code null} image file.
     * 
     * @param destWidth the new (positive, non-negative) width.
     * 
     * @param destHeight the new (positive, non-negative) height.
     * 
     * @param dest a non-existing image file; the file's directory
     * must be existent and writable by the process that invoked this
     * code.
     * 
     * @throws FileNotFoundException if the source file does not exist
     * or the directory to write the destination file does not exist.
     * 
     * @throws IOException if there is an issue using the graphics libraries
     * in resizing the image, or the destination file already exists.
     */
    public static void scale(String src, int destWidth, int destHeight,
            String dest) throws FileNotFoundException, IOException {
        File srcFile = new File(src);
        if (!srcFile.exists()) {
            throw new FileNotFoundException("File '" + src + "' not found.");
        }
        File destFile = new File(dest);
        if (!destFile.getParentFile().exists()) {
            throw new FileNotFoundException("Destination '"
                    + destFile.getParent() + "' not found.");
        }
        if (destFile.exists()) {
            throw new IOException("Destination '"
                    + src + "' already exists.");
        }
        try {
            // source file and destination directory exists - now resize the image:
            BufferedImage bufSrc = ImageIO.read(srcFile);
            BufferedImage bufDest = new BufferedImage(destWidth, destHeight,
                    BufferedImage.TYPE_INT_RGB);
            Graphics2D g = bufDest.createGraphics();
            AffineTransform at = AffineTransform.getScaleInstance(
                    (double) destWidth / bufSrc.getWidth(),
                    (double) destHeight / bufSrc.getHeight());
            g.drawRenderedImage(bufSrc, at);
            ImageIO.write(bufDest, "JPG", destFile);
        } catch(IOException ioex) {
            throw new IOException("Could not resize image: "
                    + ioex.getMessage());
        }
    }
    
    /**
     * Take a sub image from an image and write it to a new file.
     * 
     * From the specified image's x,y coordinates, create a new sub image of
     * the specified height and width and write the image to the new file.
     * 
     * @param src the full path to the source image.
     * 
     * @param x the x location to take the sub image from.
     * 
     * @param y the y location to take the sub image from.
     * 
     * @param height how many pixels tall the new image should be (from the
     * y location).
     * 
     * @param width how many pixels wide the new image should be (from the x
     * location).
     * 
     * @param dest the destination image to write the information to.
     * 
     * @throws FileNotFoundException if the source image does not exist.
     * 
     * @throws IOException of there are any security issues (read/write access)
     * with any of the operations, or the image libraries could not cope
     * with the conversion, or the destination file already exists.
     */
    public static void subImage(String src, int x, int y, int height, int width,
            String dest) throws FileNotFoundException, IOException {
        
        File srcFile = new File(src);
        if (!srcFile.exists()) {
            throw new FileNotFoundException("File '" + src + "' not found.");
        }
        File destFile = new File(dest);
        if (!destFile.getParentFile().exists()) {
            throw new FileNotFoundException("Destination '"
                    + destFile.getParent() + "' not found.");
        }
        if (destFile.exists()) {
            throw new IOException("Destination '"
                    + src + "' already exists.");
        }
        try {
            // source file and destination directory exists - now resize the image:
            BufferedImage bufSrc = ImageIO.read(srcFile);
            BufferedImage bufDest = bufSrc.getSubimage(x, y, width, height);
            ImageIO.write(bufDest, "TIF", destFile);
        } catch(IOException ioex) {
            throw new IOException("Could not resize image: "
                    + ioex.getMessage(), ioex);
        }
    }
    
    /**
     * 
     * @param args
     * @throws Exception 
     */
    public static void main(String[] args) throws Exception {
        if (args.length != 2) {
            System.out.println("Usage: [originalimage] [subimageFile]");
            return;
        }
        new ImageUtils().subImage(args[0],
              1302, 520, 925, 834, args[1]);
    }
}
