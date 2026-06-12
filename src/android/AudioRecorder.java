package com.mljsgto222.CordovaPluginAudioRecorder;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;

import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.IOException;

/**
 * This class echoes a string called from JavaScript.
 */
public class AudioRecorder extends CordovaPlugin implements MediaPlayer.OnCompletionListener, MediaPlayer.OnErrorListener {
    private static final String TAG = AudioRecorder.class.getName();

    private static final String ACTION_START_RECORD = "startRecord";
    private static final String ACTION_STOP_RECORD = "stopRecord";
    private static final String ACTION_HAS_PERMISSION = "hasPermission";
    private static final String ACTION_REQUEST_PERMISSION = "requestPermission";
    private static final String ACTION_OPEN_APP_SETTINGS = "openAppSettings";
    private static final String ACTION_PLAY_SOUND = "playSound";
    private static final String ACTION_STOP_SOUND = "stopSound";

    private static final int PERMISSION_REQUEST_CODE_START_RECORD = 100;
    private static final int PERMISSION_REQUEST_CODE_ONLY = 101;

    private static final String ERROR_PERMISSION_DENIED_FIRST_TIME = "PERMISSION_DENIED_FIRST_TIME";
    private static final String ERROR_PERMISSION_DENIED_NEED_SETTINGS = "PERMISSION_DENIED_NEED_SETTINGS";
    private static final String ERROR_OPEN_SETTINGS_FAILED = "OPEN_SETTINGS_FAILED";

    private static final String OUT_SAMPLING_RATE = "outSamplingRate";
    private static final String OUT_BIT_RATE = "outBitRate";
    private static final String IS_CHAT_MODE = "isChatMode";
    private static final String IS_SAVE = "isSave";

    private static final String STATUS_START = "start";
    private static final String STATUS_FINISH = "finish";
    private static final String STATUS_STOP = "stop";

    private MP3Recorder recorder;
    private CallbackContext pendingPermissionCallback;
    private CallbackContext pendingStartRecordCallback;
    private CallbackContext playSoundCallback;
    private MediaPlayer mediaPlayer;

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) {
        Log.d(TAG, "execute entered: " + action);
        if (ACTION_START_RECORD.equals(action)) {
            startRecord(args, callbackContext);
            return true;
        } else if (ACTION_STOP_RECORD.equals(action)) {
            stopRecord(callbackContext);
            return true;
        } else if (ACTION_HAS_PERMISSION.equals(action)) {
            hasPermission(callbackContext);
            return true;
        } else if (ACTION_REQUEST_PERMISSION.equals(action)) {
            requestPermission(callbackContext);
            return true;
        } else if (ACTION_OPEN_APP_SETTINGS.equals(action)) {
            openAppSettings(callbackContext);
            return true;
        } else if (ACTION_PLAY_SOUND.equals(action)) {
            playSound(args, callbackContext);
            return true;
        } else if (ACTION_STOP_SOUND.equals(action)) {
            stopSound(callbackContext);
            return true;
        }

        return false;
    }

    private boolean hasRecordPermission() {
        return Build.VERSION.SDK_INT < 23 || cordova.hasPermission(Manifest.permission.RECORD_AUDIO);
    }

    private boolean shouldPromptToOpenSettings() {
        if (Build.VERSION.SDK_INT < 23) {
            return false;
        }
        return !cordova.getActivity().shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO);
    }

    private void sendDeniedResult(CallbackContext callbackContext, boolean hasGrantResult) {
        if (!hasGrantResult) {
            sendPermissionError(callbackContext,
                    ERROR_PERMISSION_DENIED_FIRST_TIME,
                    "Microphone permission request dismissed");
        } else if (shouldPromptToOpenSettings()) {
            sendPermissionError(callbackContext,
                    ERROR_PERMISSION_DENIED_NEED_SETTINGS,
                    "Microphone permission denied. Change your setting > this app > Microphone enable");
        } else {
            sendPermissionError(callbackContext,
                    ERROR_PERMISSION_DENIED_FIRST_TIME,
                    "Microphone permission denied");
        }
    }

    private void sendPermissionError(CallbackContext callbackContext, String code, String message) {
        JSONObject payload = new JSONObject();
        try {
            payload.put("code", code);
            payload.put("message", message);
            callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, payload));
        } catch (JSONException e) {
            callbackContext.error(code);
        }
    }

    private void requestRecordPermission(int requestCode) {
        cordova.requestPermission(this, requestCode, Manifest.permission.RECORD_AUDIO);
    }

    private void startRecorderAndSendResult(CallbackContext callbackContext) {
        try {
            recorder.startRecord();
            callbackContext.success();
        } catch (IOException ex) {
            Log.e(TAG, ex.getMessage());
            callbackContext.error(ex.getMessage());
        }
    }

    @Override
    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults) throws JSONException {
        boolean hasGrantResult = grantResults != null && grantResults.length > 0;
        boolean granted = hasGrantResult && grantResults[0] == PackageManager.PERMISSION_GRANTED;

        if (requestCode == PERMISSION_REQUEST_CODE_START_RECORD) {
            CallbackContext callbackContext = pendingStartRecordCallback;
            pendingStartRecordCallback = null;

            if (callbackContext == null) {
                return;
            }

            if (granted) {
                startRecorderAndSendResult(callbackContext);
            } else {
                sendDeniedResult(callbackContext, hasGrantResult);
            }
            return;
        }

        if (requestCode == PERMISSION_REQUEST_CODE_ONLY) {
            CallbackContext callbackContext = pendingPermissionCallback;
            pendingPermissionCallback = null;

            if (callbackContext == null) {
                return;
            }

            if (granted) {
                callbackContext.success();
            } else {
                sendDeniedResult(callbackContext, hasGrantResult);
            }
        }
    }

    private void startRecord(JSONArray args, CallbackContext callbackContext){
        if(recorder == null || !recorder.isRecording()){

            recorder = new MP3Recorder(this.cordova.getActivity());
            if(!args.isNull(0)){
                try{
                    JSONObject options = args.getJSONObject(0);
                    if(options.has(OUT_SAMPLING_RATE)){
                        recorder.setSamplingRate(options.getInt(OUT_SAMPLING_RATE));
                    }
                    if(options.has(OUT_BIT_RATE)){
                        recorder.setBitRate(options.getInt(OUT_BIT_RATE));
                    }
                    if(options.has(IS_CHAT_MODE)) {
                        recorder.setIsChatMode(options.getBoolean(IS_CHAT_MODE));
                    }
                    if(options.has(IS_SAVE)){
                        recorder.setIsSave(options.getBoolean(IS_SAVE));
                    }
                }catch (JSONException ex){
                    Log.e(TAG, ex.getMessage());
                }
            }
            if (hasRecordPermission()) {
                startRecorderAndSendResult(callbackContext);
            } else {
                pendingStartRecordCallback = callbackContext;
                requestRecordPermission(PERMISSION_REQUEST_CODE_START_RECORD);
            }
        }else if(recorder.isRecording()){
            callbackContext.success();
        }
    }

    private void stopRecord(CallbackContext callbackContext){
        if(recorder != null){
            recorder.stopRecord();
            File file = recorder.getFile();
            if(file != null){
                Uri uri = Uri.fromFile(file);
                JSONObject fileJson = new JSONObject();
                try{
                    fileJson.put("name", file.getName());
                    fileJson.put("type", "audio/mpeg");
                    fileJson.put("uri", uri.toString());
                    fileJson.put("duration", recorder.getDuration());

                }catch(JSONException ex){
                    Log.e(TAG, ex.getMessage());
                }

                callbackContext.success(fileJson);
            }else{
                callbackContext.error("record file not found");
            }
        } else {
            callbackContext.error("AudioRecorder has not recorded yet");
        }
    }

    private void hasPermission(CallbackContext callbackContext) {
        callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, hasRecordPermission()));
    }

    private void requestPermission(CallbackContext callbackContext) {
        if (!hasRecordPermission()) {
            pendingPermissionCallback = callbackContext;
            requestRecordPermission(PERMISSION_REQUEST_CODE_ONLY);
        } else {
            callbackContext.success();
        }
    }

    private void openAppSettings(CallbackContext callbackContext) {
        Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
        Uri uri = Uri.fromParts("package", cordova.getActivity().getPackageName(), null);
        intent.setData(uri);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

        try {
            cordova.getActivity().startActivity(intent);
            callbackContext.success();
        } catch (Exception e) {
            sendPermissionError(callbackContext, ERROR_OPEN_SETTINGS_FAILED, "Could not open app settings.");
        }
    }

    private void playSound(JSONArray args, CallbackContext callbackContext) {
        String path = null;
        try {
            path = args.getString(0);
        } catch (JSONException ex) {
            callbackContext.error(ex.getMessage());
        }
        if (mediaPlayer != null && mediaPlayer.isPlaying()) {
            mediaPlayer.stop();
            if (this.playSoundCallback != null) {
                this.playSoundCallback.success(STATUS_STOP);
                this.playSoundCallback = null;
            }
        }

        mediaPlayer = new MediaPlayer();
        mediaPlayer.setOnCompletionListener(this);
        mediaPlayer.setOnErrorListener(this);
        try {
            mediaPlayer.setDataSource(path);
            mediaPlayer.prepare();
            mediaPlayer.start();
        } catch (IOException ex) {
            callbackContext.error(ex.getMessage());
            return;
        }
        this.playSoundCallback = callbackContext;
        PluginResult result = new PluginResult(PluginResult.Status.OK, STATUS_START);
        result.setKeepCallback(true);
        callbackContext.sendPluginResult(result);


    }

    @Override
    public void onCompletion(MediaPlayer mediaPlayer) {
        if (this.playSoundCallback != null) {
            this.playSoundCallback.success(STATUS_FINISH);
        }
    }

    @Override
    public boolean onError(MediaPlayer mediaPlayer, int i, int i1) {
        if(this.playSoundCallback != null) {
            String errorMessage;
            switch (i) {
                case MediaPlayer.MEDIA_ERROR_UNKNOWN:
                    errorMessage = "unknown message";
                    break;
                default:
                    switch (i1) {
                        case MediaPlayer.MEDIA_ERROR_IO:
                            errorMessage = "io error";
                            break;
                        case MediaPlayer.MEDIA_ERROR_TIMED_OUT:
                            errorMessage = "timeout";
                            break;
                        case MediaPlayer.MEDIA_ERROR_UNSUPPORTED:
                            errorMessage = "unsupported format";
                            break;
                        case MediaPlayer.MEDIA_ERROR_MALFORMED:
                            errorMessage = "bit error";
                            break;
                        default:
                            errorMessage = "other error";
                            break;
                    }
            }
            this.playSoundCallback.error(errorMessage);
        }
        return false;
    }

    private void stopSound(CallbackContext callbackContext) {
        if (mediaPlayer != null) {
            mediaPlayer.stop();
            mediaPlayer = null;

        }
        if (playSoundCallback != null) {
            playSoundCallback.success(STATUS_STOP);
            playSoundCallback = null;
        }
        callbackContext.success();
    }

}
