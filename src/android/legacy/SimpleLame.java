package com.mljsgto222.cordova.plugin.audiorecorder;

/**
 * JNI bridge for legacy native symbol package naming.
 */
public class SimpleLame {
    public native static void close();

    public native static int encode(short[] buffer_l, short[] buffer_r, int samples, byte[] mp3buf);

    public native static int flush(byte[] mp3buf);

    public static int init(int inSamplerate, int outChannel, int outSamplerate, int outBitrate) {
        return init(inSamplerate, outChannel, outSamplerate, outBitrate, 10);
    }

    public native static int init(int inSamplerate, int outChannel, int outSamplerate, int outBitrate, int quality);

    static {
        System.loadLibrary("mp3lame");
    }
}
