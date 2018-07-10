//
//  CommAudioUnitViewController.m
//  GleeeLiFFMpeg
//
//  Created by zqh on 2018/7/9.
//  Copyright © 2018年 gleeli. All rights reserved.
//

#import "CommAudioUnitViewController.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

@interface CommAudioUnitViewController ()
{
    AudioUnit remoteIOUnit;
    AURenderCallbackStruct renderProc;
    ExtAudioFileRef finalAudioFile;
    AudioStreamBasicDescription asbd;
    NSString *destinationFilePath;
    AUGraph processingGraph;
}
@end

@implementation CommAudioUnitViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0];
    destinationFilePath = [documentsDirectory stringByAppendingPathComponent:@"temp.wav"];
    NSLog(@"文件保存路径：%@",destinationFilePath);
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error;
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    
    NSTimeInterval bufferDuration = 0.002;//buff越小延迟越低
    [audioSession setPreferredIOBufferDuration:bufferDuration error:&error];
    
    double hwSampleRate = 44100.0;
    [audioSession setPreferredSampleRate:hwSampleRate error:&error];
    [audioSession setActive:YES error:&error];

    AudioComponentDescription ioUnitDescription;
    /*
     kAudioUnitType_Effect 提供声音特殊处理功能 其子类型有:
        kAudioUnitSubType_NBandEQ :均衡效果器，增强声音的频带，该效果器需要指定多个频带
        kAudioUnitSubType_DynamicsProcessor :压缩效果器，当声音较小的时候可以提高声音的能量，反之也行
        kAudioUnitSubType_Reverb2：混响器
     
     其它：（High Pass）高通 （Band Pass）带通 （Delay）延迟 （Limiter）压限
     */
    
    /*
     kAudioUnitType_FormatConverter ：提供格式转换,比如采样格式由float转SInt16，交错和平铺的格式转换，单双声道转换等。
        子类型：
        kAudioUnitSubType_AUConverter：【重要】比如SInt16需要播放，则必须使用次转Float32才能播放
        kAudioUnitSubType_NewTimePitch：对声音的音高、速度进行调整（会说话的汤姆猫）
     */
    
    /*
     kAudioUnitType_Generator ：在开发的中我们经常使用它来提供播放器功能
     子类型：
        kAudioUnitSubType_AudioFilePlayer：输入的不是麦克风而是媒体文件
     */
    ioUnitDescription.componentType = kAudioUnitType_Output;//output 采集音频和播放音频的
    ioUnitDescription.componentSubType = kAudioUnitSubType_RemoteIO;//子类型
    ioUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;//厂商
    ioUnitDescription.componentFlags = 0;
    ioUnitDescription.componentFlagsMask = 0;
    
    AudioComponent ioUnitRef = AudioComponentFindNext(NULL, &ioUnitDescription);
//    AudioUnit remoteIOUnit;
    AudioComponentInstanceNew(ioUnitRef, &remoteIOUnit);
    
    NewAUGraph(&processingGraph);
    
    //AUGraph中增加一个node
    AUNode ioNode;
    AUGraphAddNode(processingGraph, &ioUnitDescription, &ioNode);
    
    //注意 必需在获取AudioUnit之前打开整个AUGraph，否则我们将不能从对应的AUNode中获取正确的AudioUnit
    Boolean graphIsOpen;
    AUGraphIsOpen(processingGraph, &graphIsOpen);
    if (!graphIsOpen)
    {
        AUGraphOpen(processingGraph);
    }
    
    Boolean graphIsInitialized;
    CheckStatus(AUGraphIsInitialized(processingGraph, &graphIsInitialized), @"get graph initialize state error",YES);
    if (!graphIsInitialized) {
        CheckStatus(AUGraphInitialize(processingGraph), @"initialize graph error",YES);
    }
    
    //从node重取出audioUnit
    //AudioUnit ioUnit;
    CheckStatus(AUGraphNodeInfo(processingGraph, ioNode, NULL, &remoteIOUnit),@"获取node信息出错",YES);
    
   
    UInt32 oneFlag = 1;
    [self speakerOpenWithOneFlag:oneFlag];
    
    //麦克风
    [self connectMicrophoneWithOneFlag:oneFlag];
    
    [self speakerOhterSet];
    
    
    //方式一、
    //将音频输入和输出连接起来
    //AUGraphConnectNodeInput(processingGraph, <#AUNode inSourceNode#>, <#UInt32 inSourceOutputNumber#>, <#AUNode inDestNode#>, <#UInt32 inDestInputNumber#>);
    
    //方式二、
    //remoteIOUnit 需要数据输入的时候就会调用该回调
    renderProc.inputProc = renderCallback;
    renderProc.inputProcRefCon = (__bridge void *)self;
    AUGraphSetNodeInputCallback(processingGraph, ioNode, 0, &renderProc);
    
    [self startAUGraph];
}



- (void)startAUGraph
{
    Boolean graphIsRunning;
    CheckStatus(AUGraphIsRunning(processingGraph, &graphIsRunning), @"get graph running state error",YES);
    CheckStatus(AUGraphStart(processingGraph), @"start graph error",YES);
}

static OSStatus renderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp,UInt32 inBusNumber,UInt32 inNumberFrames,AudioBufferList *ioData)
{
    NSLog(@"回调");
    OSStatus result = noErr;

    __unsafe_unretained CommAudioUnitViewController *THIS = (__bridge CommAudioUnitViewController *)inRefCon;
    
    AudioUnitRender(THIS->remoteIOUnit, ioActionFlags, inTimeStamp, 0, inNumberFrames, ioData);
    result = ExtAudioFileWriteAsync(THIS->finalAudioFile, inNumberFrames, ioData);
    return result;
}

- (void)speakerOpenWithOneFlag:(UInt32)oneFlag
{
    //使用扬声器
    UInt32 busZero = 0;
    CheckStatus(AudioUnitSetProperty(remoteIOUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, busZero, &oneFlag, sizeof(oneFlag)),@"无法连接到扬声器",YES);
}

- (void)speakerOhterSet
{
    UInt32 propSize = sizeof(asbd);
    CheckStatus(AudioUnitGetProperty(remoteIOUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     0,
                                     &asbd,
                                     &propSize),@"couldn't get kAudioUnitProperty_StreamFormat with kAudioUnitScope_Output",YES);
    
    CheckStatus(AudioUnitSetProperty(remoteIOUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     1,
                                     &asbd,
                                     propSize),@"couldn't set kAudioUnitProperty_StreamFormat with kAudioUnitScope_Output",YES);
}

- (void)connectMicrophoneWithOneFlag:(UInt32)oneFlag
{
    //连接上麦克风
    UInt32 busOne = 1;
    AudioUnitSetProperty(remoteIOUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, busOne, &oneFlag, sizeof(oneFlag));
    
    //给audioUnit设置数据格式
    UInt32 bytesPerSample = sizeof(Float32);
//    AudioStreamBasicDescription asbd;
    bzero(&asbd, sizeof(asbd));
    asbd.mFormatID = kAudioFormatLinearPCM;//音频编码格式
    asbd.mSampleRate = 44100;
    asbd.mChannelsPerFrame = 2;//通道数
    asbd.mFramesPerPacket = 1;
    asbd.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;//指定采样为float格式，非交错存储
    asbd.mBitsPerChannel = 8 * bytesPerSample;//一个声道的音频数据用多少位来表示
    asbd.mBytesPerFrame = bytesPerSample;//如果是interleaved，则需要乘以声道数
    asbd.mBytesPerPacket = bytesPerSample;//如果是interleaved，则需要乘以声道数
    
    //设置录音格式 参数
    AudioUnitSetProperty(remoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &asbd, sizeof(asbd));
    
    [self createAudioFile];
    
}

- (void)createAudioFile
{
    CFURLRef destinationURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                            (CFStringRef)destinationFilePath,
                                                            kCFURLPOSIXPathStyle,
                                                            false);
    // specify codec Saving the output in .m4a format
    AudioStreamBasicDescription ima4DataFormat;
    UInt32 formatSize = sizeof(ima4DataFormat);
    memset(&ima4DataFormat, 0, sizeof(ima4DataFormat));
    ima4DataFormat.mSampleRate = asbd.mSampleRate;
    ima4DataFormat.mChannelsPerFrame = 2;
    ima4DataFormat.mFormatID = kAudioFormatAppleIMA4;
    CheckStatus(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &formatSize, &ima4DataFormat), @"couldn't create IMA4 destination data format",YES);
    CheckStatus(ExtAudioFileCreateWithURL(destinationURL,
                                            kAudioFileCAFType,
                                            &ima4DataFormat,
                                            NULL,
                                            kAudioFileFlags_EraseFile,
                                            &finalAudioFile), @"augraph recorder create url error",YES);
    CFRelease(destinationURL);

    // set the audio data format of mixer Unit
    CheckStatus(ExtAudioFileSetProperty(finalAudioFile,
                                          kExtAudioFileProperty_ClientDataFormat,
                                          sizeof(asbd),
                                          &asbd), @"augraph recorder set file format error",YES);
// kExtAudioFileProperty_CodecManufacturer 是否使用硬件编解码
    UInt32 codec = kAppleHardwareAudioCodecManufacturer;
    CheckStatus(ExtAudioFileSetProperty(finalAudioFile,
                                          kExtAudioFileProperty_CodecManufacturer,
                                          sizeof(codec),
                                          &codec), @"augraph recorder set file codec error",YES);

    //CheckStatus(ExtAudioFileWriteAsync(finalAudioFile, 0, NULL), @"augraph recorder write file error",YES);
}

//用来检查扬声器是否又错误
static void CheckStatus(OSStatus status, NSString *message,BOOL fatal)
{
    if (status != noErr)
    {
        char fourCC[16];
        *(UInt32 *)fourCC = CFSwapInt32HostToBig(status);
        fourCC[4] = '\0';
        if (isprint(fourCC[0]) && isprint(fourCC[1]) && isprint(fourCC[2]) && isprint(fourCC[3]))
        {
            NSLog(@"%@:%s",message,fourCC);
        }
        else
        {
            NSLog(@"%@:%d",message,(int)status);
        }
        
        if (fatal)
        {
            exit(-1);
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
