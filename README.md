# CordovaPluginAudioRecorder

This is a cordova plugin for audio recording. And the record will be compressed into MP3 format by [LAME](http://lame.sourceforge.net/index.php).

## Supported Platforms

- iOS >= 6.0
- Android >= 4.0

## Usage

### Constants

- `AudioRecorder.AUDIO_SAMPLINGS.MAX`     = 44100
- `AudioRecorder.AUDIO_SAMPLINGS.NORMAL`  = 22050
- `AudioRecorder.AUDIO_SAMPLINGS.LOW`     = 8000

__NOTE__: The transformation of mp3 files by LAME may fail when using other samplingrates.

### Has Permission

```
AudioRecorder.hasPermission(success, error);
```

- __success__: hasPermission success callback.
    - `hasPermission`: has audio recorder permission. (_boolean_)
    - Current return value is a boolean directly.
    - Example: `true` means microphone permission is already granted.

- __error__:hasPermission error callback

### Request Permission

```
AudioRecorder.requestPermission(success, error);
```

- __success__: requestPermission success callback when permission is granted.

- __error__: requestPermission error callback.
    - Returns a structured object: `{ code, message }`.
    - Possible `code` values:
        - `PERMISSION_DENIED_FIRST_TIME`: user denied the permission request.
        - `PERMISSION_DENIED_NEED_SETTINGS`: permission is denied and app should guide user to system settings.
        - `PERMISSION_STATE_UNRESOLVED`: iOS only, unexpected permission state.

### Open App Settings

```
AudioRecorder.openAppSettings(success, error);
```

- __success__: openAppSettings success callback when settings page is opened.

- __error__: openAppSettings error callback.
    - Returns a structured object: `{ code, message }`.
    - Possible `code` values:
        - `OPEN_SETTINGS_FAILED`

### Start Record

```
AudioRecorder.startRecord(options, success, error); // auto request permission
```

- __options__: recorder settings
    - `outSamplingRate`: Set sampling rate for output mp3. default: 44100(_number_)
    - `outBitRate`: Set bit rate for output mp3. default: 16(_number_)
    - `isChatMode`: If true then set AVAudioSessionModeVoiceChat in iOS and use NoiseSuppressor in Android. default: false(_boolean_)
    - `isSave`: If true then save mp3 file into device storage. default: false(_boolean_)

- __success__: startRecord success callback.
    - No payload is returned by `startRecord`.
    - MP3 file info is returned by `stopRecord`.

- __error__: startRecord error callback.
    - Permission errors return `{ code, message }`.
    - Other errors may return an error string.

### Stop Record

```
AudioRecorder.stopRecord(success, error)
```

- __success__: stopRecord success callback.
    - `file`: output mp3 file object
        - `name`: mp3 file's name.(_string_)
        - `type`: `'audio/mpeg'`(_string_)
        - `uri`: file local uri(_string_)
        - `duration`: duration in seconds(_number_ or _string_, platform dependent)

- __error__: stopRecord error callback.
    - `errorMessage`: a string about error(_string_)


### Play Sound

```
AudioRecorder.playSound(path, success, error)
```

- __path__: path for play local and remote file-base media.

- __success__: play sound success callback.(keep callback)
    - `status`: play status(start、finish、stop). (_string_)

- __error__: playSound error callback.
    - `errorMessage`: a string about error(_string_)


### Stop Sound

```
AudioRecorder.stopSound(success, error)
```

- __success__: stopSound success callback.

- __error__: stopSound error callback.

## Permission Error Example

```javascript
AudioRecorder.requestPermission(
    function () {
        console.log('permission granted');
    },
    function (err) {
        if (err && err.code === 'PERMISSION_DENIED_NEED_SETTINGS') {
            AudioRecorder.openAppSettings();
            return;
        }
        console.error('permission error', err);
    }
);
```


## TODO LIST

- Set duration for audio recording. 
- ~~Save record in device storage~~.
- ~~Play audio on device or Internet~~.

## Reference

[AndroidMp3Recorder](https://github.com/telescreen/AndroidMp3Recorder)

[cordova-plugin-media](https://cordova.apache.org/docs/en/latest/reference/cordova-plugin-media/)