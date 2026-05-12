package com.mljsgto222.CordovaPluginAudioRecorder;

/**
 * Created by zhengz on 16/11/24.
 */

public class SimpleLame {
    /**
     * Close LAME.
     */
    public static void close() {
        com.mljsgto222.cordova.plugin.audiorecorder.SimpleLame.close();
    }
    /**
     * Encode buffer to mp3.
     *
     * @param buffer_l PCM data for left channel.
     * @param buffer_r PCM data for right channel.
     * @param samples number of samples per channel.
     * @param mp3buf
     *            result encoded MP3 stream. You must specified
     *            "7200 + (1.25 * buffer_l.length)" length array.
     * @return number of bytes output in mp3buf. Can be 0.<br />
     *         -1: mp3buf was too small<br />
     *         -2: malloc() problem<br />
     *         -3: lame_init_params() not called<br />
     *         -4: psycho acoustic problems
     */
    public static int encode(short[] buffer_l, short[] buffer_r, int samples, byte[] mp3buf) {
        return com.mljsgto222.cordova.plugin.audiorecorder.SimpleLame.encode(buffer_l, buffer_r, samples, mp3buf);
    }

    /**
     * Flush LAME buffer.
     *
     * @param mp3buf
     *            result encoded MP3 stream. You must specified at least 7200
     *            bytes.
     * @return number of bytes output to mp3buf. Can be 0.
     */
    public static int flush(byte[] mp3buf) {
        return com.mljsgto222.cordova.plugin.audiorecorder.SimpleLame.flush(mp3buf);
    }

    /**
     * Initialize LAME.
     *
     * @param inSamplerate input sample rate in Hz.
     * @param outChannel number of channels in input stream.
     * @param outSamplerate output sample rate in Hz.
     * @param outBitrate brate compression ratio in KHz.
     */
    public static int init(int inSamplerate, int outChannel, int outSamplerate, int outBitrate) {
        return init(inSamplerate, outChannel, outSamplerate, outBitrate, 10);
    }

    /**
     * Initialize LAME.
     *
     * @param inSamplerate input sample rate in Hz.
     * @param outChannel number of channels in input stream.
     * @param outSamplerate output sample rate in Hz.
     * @param outBitrate brate compression ratio in KHz.
     * @param quality
     *            quality=0..9. 0=best (very slow). 9=worst.<br />
     *            recommended:<br />
     *            2 near-best quality, not too slow<br />
     *            5 good quality, fast<br />
     *            7 ok quality, really fast
     */
    public static int init(int inSamplerate, int outChannel, int outSamplerate, int outBitrate, int quality) {
        return com.mljsgto222.cordova.plugin.audiorecorder.SimpleLame.init(inSamplerate, outChannel, outSamplerate, outBitrate, quality);
    }

}
