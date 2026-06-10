/********* AudioRecorder.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>
#import <AVFoundation/AVFoundation.h>
#import <errno.h>
#import <string.h>

#import "AudioRecorder.h"
#import "SimpleLame.h"

#define DEFAULT_OUT_BIT_RATE 16
#define DEFAULT_OUT_SAMPLING_RATE 44100
#define IN_SAMPLING_RATE 44100
#define PCM_SIZE 8192

#define OUT_SAMPLING_RATE @"outSamplingRate"
#define OUT_BIT_RATE @"outBitRate"
#define IS_CHAT_MODE @"isChatMode"
#define IS_SAVE @"isSave"
#define TEMP_FILE_NAME @"temp"

#define STATUS_START @"start"
#define STATUS_FINISH @"finish"
#define STATUS_STOP @"stop"

static BOOL AudioRecorderMicrophoneAccessGranted(AVAudioSessionRecordPermission permission)
{
    return permission == AVAudioSessionRecordPermissionGranted;
}

static NSString * const AudioRecorderErrorPermissionDeniedFirstTime    = @"PERMISSION_DENIED_FIRST_TIME";
static NSString * const AudioRecorderErrorPermissionDeniedNeedSettings = @"PERMISSION_DENIED_NEED_SETTINGS";
static NSString * const AudioRecorderErrorPermissionStateUnresolved    = @"PERMISSION_STATE_UNRESOLVED";
static NSString * const AudioRecorderErrorOpenSettingsFailed           = @"OPEN_SETTINGS_FAILED";

static CDVPluginResult *AudioRecorderPermissionErrorResult(NSString *code, NSString *message)
{
    NSDictionary *payload = @{ @"code": code, @"message": message };
    return [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:payload];
}


@implementation AudioRecorder

@synthesize setting, avSession, recorder, resourcePath, mp3FilePath, outBitRate, outSamplingRate, isSave, isRecording, isChatMode, playSoundCallbackId;

- (void) pluginInitialize{
    outSamplingRate = DEFAULT_OUT_SAMPLING_RATE;
    outBitRate = DEFAULT_OUT_BIT_RATE;
    isChatMode = NO;
    setting = [NSDictionary dictionaryWithObjectsAndKeys:
               [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
               [NSNumber numberWithInt:IN_SAMPLING_RATE], AVSampleRateKey,
               [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
               [NSNumber numberWithInt:2], AVNumberOfChannelsKey,
               [NSNumber numberWithInt:kAudioConverterQuality_Max], AVEncoderAudioQualityKey,
               nil];
    
}

- (void) hasPermission:(CDVInvokedUrlCommand *)command {
    [self hasAvSession]; // ensure avSession is initialized
    AVAudioSessionRecordPermission permission = [self.avSession recordPermission];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                        messageAsBool:AudioRecorderMicrophoneAccessGranted(permission)];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) requestPermission:(CDVInvokedUrlCommand *)command {
    [self hasAvSession]; // ensure avSession is initialized
    AVAudioSessionRecordPermission permission = [self.avSession recordPermission];

    if (AudioRecorderMicrophoneAccessGranted(permission)) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

    } else if (permission == AVAudioSessionRecordPermissionDenied) {
        NSString *message = @"Microphone access has been denied. Go to Settings > this app > Microphone to enable.";
        NSLog(@"%@", message);
        CDVPluginResult *pluginResult = AudioRecorderPermissionErrorResult(AudioRecorderErrorPermissionDeniedNeedSettings, message);
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

    } else if (permission == AVAudioSessionRecordPermissionUndetermined) {
        [self.avSession requestRecordPermission:^(BOOL granted) {
            CDVPluginResult *pluginResult = nil;
            if (granted) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            } else {
                pluginResult = AudioRecorderPermissionErrorResult(AudioRecorderErrorPermissionDeniedFirstTime,
                                                                  @"Microphone access has been denied.");
            }
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];

    } else {
        NSString *message = @"Microphone permission state could not be resolved.";
        CDVPluginResult *pluginResult = AudioRecorderPermissionErrorResult(AudioRecorderErrorPermissionStateUnresolved, message);
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void) openAppSettings:(CDVInvokedUrlCommand *)command {
    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if (url == nil) {
        CDVPluginResult *pluginResult = AudioRecorderPermissionErrorResult(AudioRecorderErrorOpenSettingsFailed,
                                                                           @"Could not build app settings URL.");
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        CDVPluginResult *pluginResult = success
            ? [CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
            : AudioRecorderPermissionErrorResult(AudioRecorderErrorOpenSettingsFailed, @"Could not open app settings.");
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void) startRecord:(CDVInvokedUrlCommand *)command {
    if([recorder isRecording]){
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    NSDictionary *options = [command.arguments objectAtIndex:0];
    if(options != nil){
        if([options valueForKey:OUT_SAMPLING_RATE] != nil){
            outSamplingRate = [[options valueForKey:OUT_SAMPLING_RATE] intValue];
        }
        if([options valueForKey: OUT_BIT_RATE] != nil){
            outBitRate = [[options valueForKey:OUT_BIT_RATE] intValue];
        }
        if([options valueForKey:IS_CHAT_MODE] != nil){
            isChatMode = [[options valueForKey:IS_CHAT_MODE] boolValue];
        }
        if([options valueForKey:IS_SAVE] != nil){
            isSave = [[options valueForKey:IS_SAVE] boolValue];
        }
    }
    
    __weak AudioRecorder* recorderSelf = self;
    __weak NSString* weakCallbackId = [command callbackId];
    
    void (^startRecording)(void) = ^{
        __strong  AudioRecorder* audioRecorder = recorderSelf;
        __strong NSString* callbackId = weakCallbackId;
        CDVPluginResult *pluginResult = nil;
        NSError* __autoreleasing error = nil;
        
        if(audioRecorder.recorder != nil){
            [audioRecorder.recorder stop];
            audioRecorder.recorder = nil;
        }
        
        if([audioRecorder hasAvSession]){
            if(![audioRecorder.avSession.category isEqualToString:AVAudioSessionCategoryPlayAndRecord]){
                [audioRecorder.avSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
            }
            
            if(audioRecorder.isChatMode){
                [audioRecorder.avSession setMode:AVAudioSessionModeVoiceChat error:nil];
            }
            
            if(![audioRecorder.avSession setActive:YES error:&error]){
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: [NSString stringWithFormat:@"Unable to record audio: %@", [[error userInfo] description]]];
                [audioRecorder.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
                return;
            }
        }
        
        audioRecorder.resourcePath = [NSTemporaryDirectory() stringByAppendingFormat:@"%@.pcm", TEMP_FILE_NAME];
        NSURL *url = [NSURL URLWithString:audioRecorder.resourcePath];
        audioRecorder.recorder = [[AVAudioRecorder alloc] initWithURL:url settings:audioRecorder.setting error:&error];
        
        bool recordingSuccess = NO;
        if (error == nil){
            audioRecorder.recorder.delegate = audioRecorder;
            audioRecorder.recorder.meteringEnabled = YES;
            recordingSuccess = [audioRecorder.recorder record];
            
            if(recordingSuccess){
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                [audioRecorder.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
                isRecording = YES;
                startRecordTime = CACurrentMediaTime();
                [NSTimer scheduledTimerWithTimeInterval:.2 target:self selector:@selector(convertMp3) userInfo:nil repeats:NO];
                return;
            }
        }
        
        if(error != nil || !recordingSuccess){
            if(error != nil){
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: [NSString stringWithFormat: @"Failed to initialize AvAudioRecorder: %@", [[error userInfo] description]]];
            }else{
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Failed to start recording"];
            }
            audioRecorder.recorder = nil;
            if([audioRecorder hasAvSession]){
                [audioRecorder.avSession setActive:NO error:nil];
            }
            [audioRecorder.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
            return;
        }
    };
    
    [self hasAvSession]; // ensure avSession is initialized
    AVAudioSessionRecordPermission permission = [self.avSession recordPermission];

    if (permission == AVAudioSessionRecordPermissionUndetermined) {
        [self.avSession requestRecordPermission:^(BOOL granted) {
            if (granted) {
                startRecording();
            } else {
                CDVPluginResult *pluginResult = AudioRecorderPermissionErrorResult(
                    AudioRecorderErrorPermissionDeniedFirstTime,
                    @"Microphone access has been denied.");
                [recorderSelf.commandDelegate sendPluginResult:pluginResult callbackId:weakCallbackId];
            }
        }];
    } else if (AudioRecorderMicrophoneAccessGranted(permission)) {
        startRecording();
    } else {
        NSString *code = (permission == AVAudioSessionRecordPermissionDenied)
            ? AudioRecorderErrorPermissionDeniedNeedSettings
            : AudioRecorderErrorPermissionStateUnresolved;
        NSString *message = (permission == AVAudioSessionRecordPermissionDenied)
            ? @"Microphone access has been denied. Go to Settings > this app > Microphone to enable."
            : @"Microphone permission state could not be resolved.";
        CDVPluginResult *pluginResult = AudioRecorderPermissionErrorResult(code, message);
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }

}

- (void) stopRecord:(CDVInvokedUrlCommand *)command
{
    stopRecordCallbackId = command.callbackId;
    if(recorder != nil){
        [recorder stop];
        recorder = nil;
    }
}

- (void) audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    if(flag){
        
    }else{
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Failed to encoding audio"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:stopRecordCallbackId];
    }
    
    if([self hasAvSession]){
        if(![avSession.category isEqualToString:AVAudioSessionCategoryAmbient]){
            [self.avSession setCategory:AVAudioSessionCategoryAmbient error:nil];
            [self.avSession setMode:AVAudioSessionModeDefault error:nil];
        }
        [self.avSession setActive:NO error: nil];
    }
    isRecording = NO;
    endRecordTime = CACurrentMediaTime();
}

- (NSString*)getDocumentPath{
    if([[UIDevice currentDevice].systemVersion compare:@"8.0" options:NSNumericSearch] == NSOrderedAscending){
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *basePath = paths.firstObject;
        return basePath;
    }else{
        return [[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject] relativePath];
    }
}

- (void)setMp3FilePath{
    long timestamp = [[NSDate date] timeIntervalSince1970];
    if(isSave){
        mp3FilePath = [[self getDocumentPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld.mp3", timestamp]];
    }else{
        mp3FilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%ld.mp3", TEMP_FILE_NAME, timestamp]];
    }
    
}

- (void)convertMp3
{
    __weak AudioRecorder* weakRecorder = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        __strong AudioRecorder* audioRecorder = weakRecorder;
        if(audioRecorder){
            [audioRecorder setMp3FilePath];
            BOOL convertMp3Success = NO;
            @try{
                int read, write;
                FILE *mp3File = fopen([audioRecorder.mp3FilePath cStringUsingEncoding:1], "wb");
                FILE *pcmFile = fopen([audioRecorder.resourcePath cStringUsingEncoding:1], "rb");
                
                short int pcmBuffer[PCM_SIZE *2];
                unsigned char mp3Buffer[PCM_SIZE];
                
                float scale = audioRecorder.isChatMode? 2.0: 1.0;
                [SimpleLame init:IN_SAMPLING_RATE outSamplerate:audioRecorder.outSamplingRate outChannel:1 outBitrate:audioRecorder.outBitRate scale:scale];
                
                long curPos;
                BOOL hasSkipHeader = NO;
                
                do{
                    curPos = ftell(pcmFile);
                    long startPos = ftell(pcmFile);
                    
                    fseek(pcmFile, 0, SEEK_END);
                    long endPos = ftell(pcmFile);
                    
                    long length = endPos - startPos;
                    fseek(pcmFile, curPos, SEEK_SET);
                    
                    if(length > PCM_SIZE * 2 * sizeof(short int)){
                        if(!hasSkipHeader){
                            fseek(pcmFile, 4 * 1024, SEEK_SET);
                            hasSkipHeader = YES;
                        }
                        
                        read = fread(pcmBuffer, 2 * sizeof(short int), PCM_SIZE, pcmFile);
                        write = [SimpleLame encode:pcmBuffer samples: read mp3buf:mp3Buffer mp3bufSize:PCM_SIZE];
                        if(write >= 0){
                            fwrite(mp3Buffer, write, 1, mp3File);
                        }
                    }
                } while (audioRecorder.isRecording);
                do{
                    read = fread(pcmBuffer, 2 * sizeof(short int), PCM_SIZE, pcmFile);
                    if(read == 0){
                        write = [SimpleLame flush:mp3Buffer mp3bufSize:PCM_SIZE];
                    }else{
                        write = [SimpleLame encode:pcmBuffer samples: read mp3buf:mp3Buffer mp3bufSize:PCM_SIZE];
                    }
                }while (read != 0);
                
                
                [SimpleLame close];
                fclose(mp3File);
                fclose(pcmFile);
                convertMp3Success = YES;
                
            }
            @catch(NSException *ex){
                NSLog(@"Failed to converting audio: %@", [[ex userInfo] description]);
            }
            @finally{
                [audioRecorder convertMp3Finished: convertMp3Success];
            }
        }
    });
}

- (void)convertMp3Finished:(BOOL)flag
{
    CDVPluginResult *pluginResult;
    if(flag){
        NSURL *mp3Url = [NSURL URLWithString:mp3FilePath];
        NSString *mp3FileName = [mp3Url lastPathComponent];
        NSDictionary *result = [NSDictionary dictionaryWithObjectsAndKeys:
                                mp3FileName, @"name",
                                @"audio/mpeg", @"type",
                                mp3FilePath, @"uri",
                                [NSString stringWithFormat:@"%.2g", endRecordTime - startRecordTime ], @"duration",
                                nil];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
    }else{
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Failed to converting mp3"];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:stopRecordCallbackId];
    
}

- (BOOL) hasAvSession
{
    BOOL hasSession = YES;
    if(avSession == nil){
        NSError *error = nil;
        
        avSession = [AVAudioSession sharedInstance];
        if(error != nil){
            NSLog(@"get AvAudioSession failed: %@", [[error userInfo] description]);
            avSession = nil;
            hasSession = NO;
        }
    }
    return hasSession;
}

- (void) playSound:(CDVInvokedUrlCommand *)command {
    NSString* path = [command.arguments objectAtIndex:0];
    if (path == nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"missing path"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId: command.callbackId];
    }
    
    if (avPlayer != nil) {
        [avPlayer pause];
        avPlayer = nil;
        if (playSoundCallbackId != nil) {
            CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:STATUS_STOP];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:playSoundCallbackId];
            playSoundCallbackId = nil;
        }
    }
    
    NSURL *url;
    if ([path hasPrefix:@"http://"] || [path hasPrefix:@"https://"]) {
        url = [NSURL URLWithString:path];
    } else {
        url = [NSURL fileURLWithPath:path];
    }
    AVPlayerItem *item = [[AVPlayerItem alloc] initWithURL:url];
    avPlayer = [[AVPlayer alloc] initWithPlayerItem:item];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:item];
    if (avPlayer.error == nil) {
        playSoundCallbackId = command.callbackId;
        
        [avPlayer play];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:STATUS_START];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId: command.callbackId];
        
    } else {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: [NSString stringWithFormat: @"play sound error: %@", [[item.error userInfo] description]]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    
    
}

- (void) stopSound:(CDVInvokedUrlCommand *)command {
    if (avPlayer != nil) {
        [avPlayer pause];
        avPlayer = nil;
    }
    if (playSoundCallbackId != nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:STATUS_STOP];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:playSoundCallbackId];
        playSoundCallbackId = nil;
    }
}

- (void)didFinishPlaying:(NSNotification *)notification {
    if (playSoundCallbackId != nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:STATUS_FINISH];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:playSoundCallbackId];
        self.playSoundCallbackId = nil;
    }
}

@end
