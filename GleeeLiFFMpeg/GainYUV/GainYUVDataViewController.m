//
//  GainYUVDataViewController.m
//  GleeeLiFFMpeg
//
//  Created by zqh on 2018/6/28.
//  Copyright © 2018年 gleeli. All rights reserved.
//

#import "GainYUVDataViewController.h"
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
#include <libavutil/pixdesc.h>
#include <libavutil/pixfmt.h>
#import "CommHeader.h"

@interface GainYUVDataViewController ()
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (copy, nonatomic) NSString *savePath;
@end

@implementation GainYUVDataViewController
{
    AVCodecContext *videoCodecCtx;
    struct SwsContext *swsContext;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"获取YUV数据";
    
    NSString *filePath = [kPathDocument stringByAppendingPathComponent:@"videoYUV.yuv"];
    self.savePath = filePath;
    
    self.view.backgroundColor = [UIColor greenColor];
    
    dispatch_async(dispatch_queue_create(DISPATCH_TARGET_QUEUE_DEFAULT, 0), ^{
        [self startGainYUV];
    });
}

- (void)changeStatus:(NSString *)status otherInfo:(NSString *)other
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *msg = [NSString stringWithFormat:@"状态：%@\n其它信息：%@",status,other];
        self.statusLabel.text = msg;
    });
}

- (void)startGainYUV
{
    
    NSString *loaclVideoPath = [[NSBundle mainBundle] pathForResource:@"NineMinute" ofType:@"mp4"];
    
    //    NSString *input_str= [NSString stringWithFormat:@"resource.bundle/%@",@"war3end.mp4"];
    //    NSString *loaclVideoPath=[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:input_str];
    
    const char *path = [loaclVideoPath UTF8String];
    NSLog(@"解析文件路径：%s",path);
    
    [self changeStatus:@"解析进行中..." otherInfo:loaclVideoPath];
    
    //    char input_str_full[500]={0};
    //    sprintf(input_str_full,"%s",path);
    //    printf("Input Path:%s\n",input_str_full);
    //    char in_filename[500]={0};
    //    strcpy(in_filename,input_str_full);
    
    av_register_all();
    //Network
    avformat_network_init();
    
    AVFormatContext *formatCtx = avformat_alloc_context();
    //设置回调
    AVIOInterruptCB int_cb = {interrupt_callback, (__bridge void *)(self)};
    formatCtx->interrupt_callback = int_cb;
    
    
    avformat_open_input(&formatCtx, path, NULL, NULL);
    avformat_find_stream_info(formatCtx, NULL);
    
    int videoStreamIndex = -1;
    int audioStreamIndex = -1;
    AVCodecContext *audioCodecCtx = NULL;
    SwrContext *swrContext = NULL;
    
    AVPicture picture;//作用是转格式，比如将rgb的原始数据转YUV
    for (int i = 0; i < formatCtx ->nb_streams; i++)
    {
        AVStream *stream = formatCtx->streams[i];
        
        if (AVMEDIA_TYPE_VIDEO == stream->codec->codec_type)
        {
            //视频流
            videoStreamIndex = i;
            [self parserVideoStream:stream];
            
            //先校验视频流是否格式合法,并初始化picture格式
            bool pictureValid = [self getAVPictueValidWithVideoCodecCtx:videoCodecCtx picture:picture];
            if (!pictureValid)
            {
                NSLog(@"视频流不合法");
            }
            else
            {
                //转换成需要的视频格式
                [self parserVideoFormat];
            }
            
        }
        else if (AVMEDIA_TYPE_AUDIO == stream->codec->codec_type)
        {
            //音频流
            audioStreamIndex = i;
            audioCodecCtx = [self parserAudioStream:stream];
            swrContext =[self parserAudioFormat:audioCodecCtx];
        }
    }
    
    AVCodecContext *pCodecCtx=formatCtx->streams[videoStreamIndex]->codec;
    
    //输出文件信息
    printf("--------------- 文件信息 ----------------\n");
    av_dump_format(formatCtx, 0, path, 0);
    printf("---------------------文件信息结束----------------------------\n");
    
    //获取每一帧数据
    [self handleEveryFrameWithFormatCtx:formatCtx videoStreamIndex:videoStreamIndex audioStreamIndex:audioStreamIndex audioCodecCtx:audioCodecCtx swrContext:swrContext picture:picture];
}

/**
 获取每一帧数据
 */
- (void)handleEveryFrameWithFormatCtx:(AVFormatContext *)formatCtx videoStreamIndex:(int)videoStreamIndex audioStreamIndex:(int)audioStreamIndex audioCodecCtx:(AVCodecContext *)audioCodecCtx swrContext:(SwrContext *)swrContext picture:(AVPicture)picture
{
    //处理每一帧数据
    AVPacket packet;
    int gotFrame = 0;
    
    av_init_packet(&packet);
    packet.data = NULL;
    packet.size = 0;
    
    AVFrame *videoFrame = av_frame_alloc();
    
    //int numBytes = avpicture_get_size(PIX_FMT_YUV420P, videoCodecCtx->width,videoCodecCtx->height);
    uint8_t *out_buffer;// = (uint8_t *)av_malloc(numBytes*sizeof(uint8_t));
    //分配输出内存空间
    out_buffer = (uint8_t *)av_malloc(avpicture_get_size(AV_PIX_FMT_YUV420P, videoCodecCtx->width, videoCodecCtx->height));
    
    avpicture_fill((AVPicture *)videoFrame, out_buffer, AV_PIX_FMT_YUV420P,videoCodecCtx->width, videoCodecCtx->height);
    
    
    while (true)
    {
        
        if (av_read_frame(formatCtx, &packet))
        {
            //读到文件末尾，av_read_frame返回0代表成功，非0则为文件末尾
            [self changeStatus:@"解码完成,请查看解析文件" otherInfo:self.savePath];
            NSLog(@"本地保存路径:%@",self.savePath);
            break;
        }
        
        int packetStreamIndex = packet.stream_index;
        if (packetStreamIndex == videoStreamIndex)
        {
            //从packet里面 得到videoFrame
            int len = avcodec_decode_video2(videoCodecCtx, videoFrame, &gotFrame, &packet);
            if (len < 0)
            {
                NSLog(@"解码出错");
                continue;
            }
            
            if (gotFrame)
            {
                [self handleVideoFrameWithVideoFrame:videoFrame picture:picture];
            }
        }
        else if(packetStreamIndex == audioStreamIndex)
        {
            //处理一帧音频数据
            AVFrame *audioFrame = av_frame_alloc();
            //从packet里面 得到audioFrame
            int len = avcodec_decode_audio4(audioCodecCtx, audioFrame, &gotFrame, &packet);
            
            if (len < 0)
            {
                break;
            }
            
            if (gotFrame)
            {
                [self handleAudioFrameWithSwrContext:swrContext audioFrame:audioFrame];
            }
        }
    }
}

/**
 网络延迟超时回调
 */

int interrupt_callback(void *sender)
{
    NSLog(@"*********收到回调:%s",sender);
    return 0;
}

#pragma mark 音频流
/**
 解析音频流
 */
- (AVCodecContext *)parserAudioStream:(AVStream *)audioStream
{
    AVCodecContext *audioCodecCtx = audioStream->codec;
    AVCodec *codec = avcodec_find_decoder(audioCodecCtx->codec_id);
    if (!codec) {
        printf("找不到对应的音频解码器");
        [self changeStatus:@"找不到对应的音频解码器" otherInfo:nil];
    }
    
    int openCodecErrCode = 0;
    if ((openCodecErrCode = avcodec_open2(audioCodecCtx, codec, NULL)) < 0)
    {
        printf("打开音频解码器失败");
        [self changeStatus:@"打开音频解码器失败" otherInfo:nil];
    }
    return audioCodecCtx;
}

/**
 解析音频格式
 */
- (SwrContext *)parserAudioFormat:(AVCodecContext *)audioCodecCtx
{
    //
    SwrContext *swrContext = NULL;
    
    if (audioCodecCtx->sample_fmt != AV_SAMPLE_FMT_S16)
    {
        //输出声道数
        int64_t outputChannel = 2;
        int outSampleRate = 0;
        int64_t in_ch_layout = 0;
        //输入音频格式
        enum AVSampleFormat in_samplet_fmt = audioCodecCtx->sample_fmt;
        int in_sample_rate = 0;
        int log_offset = 0;
        
        //设置转化器参数，将音频格式转成AV_SAMPLE_FMT_S16
        swrContext = swr_alloc_set_opts(NULL, outputChannel, AV_SAMPLE_FMT_S16, outSampleRate, in_ch_layout, in_samplet_fmt, in_sample_rate, log_offset, NULL);
        
        if (!swrContext || swr_init(swrContext))
        {
            if (swrContext)
            {
                swr_free(&swrContext);
            }
        }
    }
    
    return swrContext;
}


/**
 得到AV_SAMPLE_FMT_S16格式的音频裸数据
 */
- (void)handleAudioFrameWithSwrContext:(SwrContext *)swrContext audioFrame:(AVFrame *)audioFrame
{
    void *audioData;//最终得到的音频数据
    int numFrames;//每个声道的采样率
    void *swrBuffer;
    int swrBufferSize = 0;
    if (swrContext)//非AV_SAMPLE_FMT_S16格式
    {
        //双声道
        int nb_channels = 2;
        //总采样率
        int nb_samples = (int)(audioFrame->nb_samples * nb_channels);
        //获取一帧需要的缓存区大小
        int bufSize = av_samples_get_buffer_size(NULL, nb_channels, nb_samples, AV_SAMPLE_FMT_S16, 1);
        if (!swrBuffer || swrBufferSize < bufSize)
        {
            swrBufferSize = bufSize;
            //更改swrBuffer内存大小
            swrBuffer = realloc(swrBuffer, swrBufferSize);
        }
        Byte *outbuf[2] = {swrBuffer,0};
        int out_count = (int)(audioFrame->nb_samples * nb_channels);
        //原始数据
        const uint_fast8_t **uint8 = (const uint_fast8_t **)audioFrame->data;
        //一个通道有效的采样率
        int in_count = audioFrame->nb_samples;
        //按照swrContext设置的采样参数开始重采样
        numFrames = swr_convert(swrContext, outbuf, out_count, uint8, in_count);
        audioData = swrBuffer;
    }
    else//不需要转格式，已经是需要的格式
    {
        audioData = audioFrame->data[0];
        numFrames = audioFrame->nb_samples;
    }
}

#pragma mark 视频流
/**
 解析视频流
 */
- (void)parserVideoStream:(AVStream *)videoStream
{
    videoCodecCtx = videoStream->codec;
    
    //自己设置需要的格式
    //    videoCodecCtx->codec_id = AV_CODEC_ID_H264;
    //帧率的基本单位，我们用分数来表示，
    //用分数来表示的原因是，有很多视频的帧率是带小数的eg：NTSC 使用的帧率是29.97
    //    videoCodecCtx->time_base.den = 30;
    //    videoCodecCtx->time_base = (AVRational){1,25};
    //    videoCodecCtx->time_base.num = 1;
    
    
    //    //目标的码率，即采样的码率；显然，采样码率越大，视频大小越大
    //    videoCodecCtx->bit_rate = 2000000;
    //    //固定允许的码率误差，数值越大，视频越小
    //    videoCodecCtx->bit_rate_tolerance = 4000000;
    
    //AVCodec是存储编解码器信息的结构体,找到一种编解码器（比如h264）的信息
    AVCodec *codec = avcodec_find_decoder(videoCodecCtx->codec_id);
    if (!codec) {
        printf("找不到对应的视频解码器");
    }
    
    int openCodecErrCode = 0;
    //用于初始化一个视音频编解码器的AVCodecContext
    if ((openCodecErrCode = avcodec_open2(videoCodecCtx, codec, NULL)) < 0)
    {
        printf("打开视频解码器失败");
    }
    
    //    videoCodecCtx->width = videoCodecCtx->coded_width;
    //    videoCodecCtx->height = videoCodecCtx->coded_height;
    //    videoCodecCtx->pix_fmt = PIX_FMT_YUV420P;
}

- (bool)getAVPictueValidWithVideoCodecCtx:(AVCodecContext *)videoCodecCtx picture:(AVPicture)picture
{
    //static AVPicture src_picture;
    bool pictureValid = avpicture_alloc(&picture, AV_PIX_FMT_YUV420P, videoCodecCtx->width, videoCodecCtx->height) == 0;
    if (!pictureValid)
    {
        printf("分配失败");
        [self changeStatus:@"分配失败" otherInfo:nil];
    }
    return pictureValid;
}

/**
 设置需要的视频格式
 */
- (void)parserVideoFormat
{
    //    AVPicture picture ;
    //    bool pictureValid = avpicture_alloc(&picture, PIX_FMT_YUV420P, videoCodecCtx->width, videoCodecCtx->height) == 0;
    //    if (!pictureValid)
    //    {
    //        printf("分配失败");
    //        return NULL;
    //    }
    //转换图片格式和分辨率
    //SWS_FAST_BILINEAR:为某算法，此算法没有明显失真 详情：https://blog.csdn.net/leixiaohua1020/article/details/12029505
    //缩放前的初始化参数的函数，前两个参数原始图片宽高 ，原始格式，输出尺寸，输出格式
    swsContext= sws_getContext(videoCodecCtx->width, videoCodecCtx->height, videoCodecCtx->pix_fmt,
                               videoCodecCtx->width, videoCodecCtx->height, AV_PIX_FMT_YUV420P, SWS_BICUBIC, NULL, NULL, NULL);//转码的信息
    //sws_getCachedContext(swsContext, videoCodecCtx->width, videoCodecCtx->height, videoCodecCtx->pix_fmt, videoCodecCtx->width, videoCodecCtx->height, PIX_FMT_YUV420P, SWS_BICUBIC, NULL, NULL, NULL);//SWS_BICUBIC SWS_FAST_BILINEAR
}

/**
 得到视频裸数据（YUV）
 */
- (void)handleVideoFrameWithVideoFrame:(AVFrame *)videoFrame picture:(AVPicture)picture
{
    NSMutableData *luma;
    NSMutableData *chromaB;
    NSMutableData *chromaR;
    if (videoCodecCtx->pix_fmt == AV_PIX_FMT_YUV420P ||
        videoCodecCtx->pix_fmt == AV_PIX_FMT_YUVJ420P)
    {
        luma = copyFrameData(videoFrame->data[0],videoFrame->linesize[0],videoCodecCtx->width,videoCodecCtx->height);
        chromaB = copyFrameData(videoFrame->data[1],videoFrame->linesize[1],videoCodecCtx->width/2,videoCodecCtx->height/2);
        chromaR = copyFrameData(videoFrame->data[2],videoFrame->linesize[2],videoCodecCtx->width/2,videoCodecCtx->height/2);
        
        [self writefile:luma];
        [self writefile:chromaB];
        [self writefile:chromaR];
    }
    else//转换YUV格式
    {
        //执行缩放和转格式的函数
        //videoFrame->data 输入的各通道数据数组  picture.data 输出的各通道（YUV）数据数组
        //videoFrame->linesize 为输入图像数据各颜色通道每行存储的字节数数组，一个图片有很多行，每一行的大小也可能超过宽度
        //0 为从输入图像数据的第多少列开始逐行扫描，通常设为0；
        sws_scale(swsContext, (const uint8_t **)videoFrame->data, videoFrame->linesize, 0, videoCodecCtx->height, picture.data, picture.linesize);
        
        luma = copyFrameData(picture.data[0],picture.linesize[0],videoCodecCtx->width,videoCodecCtx->height);
        chromaB = copyFrameData(picture.data[1],picture.linesize[1],videoCodecCtx->width/2,videoCodecCtx->height/2);
        chromaR = copyFrameData(picture.data[2],picture.linesize[2],videoCodecCtx->width/2,videoCodecCtx->height/2);
        
        [self writefile:luma];
        [self writefile:chromaB];
        [self writefile:chromaR];
    }
}

static NSMutableData * copyFrameData(UInt8 *src, int linesize, int width, int height)
{
    //width = MIN(linesize, width);
    NSInteger maxSize = width * height;//最大值是Y分量
    NSMutableData *md = [NSMutableData dataWithLength: maxSize];
    Byte *dst = md.mutableBytes;
    for (NSUInteger i = 0; i < height; ++i) {//遍历每行
        memcpy(dst, src, linesize);
        //dst += width;感觉不对
        dst += linesize;
        src += linesize;
    }
    
    return md;
}

- (void)writefile:(NSData *)yuvData
{
    
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if(![fileManager fileExistsAtPath:self.savePath]) //如果不存在
    {
        [yuvData writeToFile:self.savePath atomically:YES];
        return;
    }
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:self.savePath];
    
    [fileHandle seekToEndOfFile];  //将节点跳到文件的末尾
    
    [fileHandle writeData:yuvData]; //追加写入数据
    
    [fileHandle closeFile];
}

#pragma mark 扩展不利用AVPicture转RGB
char* scaleYUVImgToRGB(int nSrcW,int nSrcH,uint8_t **src_data,int *lineSize,int nDstW,int nDstH){
    int i ; int ret ;  FILE *nRGB_file ;
    
    struct SwsContext* m_pSwsContext;
    char*  out_Img[3];
    int out_linesize[3];
    
    return out_Img[0];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

/*
 补充
 https://www.cnblogs.com/Sharley/p/5595768.html
 在YUV420中，一个像素点对应一个Y，一个4X4的小方块对应一个U和V。对于所有YUV420图像，它们的Y值排列是完全相同的，因为只有Y的图像就是灰度图像。YUV420sp与YUV420p的数据格式它们的UV排列在原理上是完全不同的。420p它是先把U存放完后，再存放V，也就是说UV它们是连续的。而420sp它是UV、UV这样交替存放的。(见下图) 有了上面的理论，我就可以准确的计算出一个YUV420在内存中存放的大小。 width * hight =Y（总和） U = Y / 4   V = Y / 4
 
 YUV420 数据在内存中的长度是 width * hight * 3 / 2，
 */
@end
