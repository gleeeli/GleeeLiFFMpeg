//
//  BookStudyNoteViewController.m
//  GleeeLiFFMpeg
//
//  Created by 小柠檬 on 2019/5/31.
//  Copyright © 2019 gleeli. All rights reserved.
//

#import "BookStudyNoteViewController.h"
#include <stdlib.h>
#include <stdio.h>
#include <libavutil/channel_layout.h>//用户音频声道布局操作
#include <libavutil/opt.h>//设置操作选项操作
#include <libavutil/mathematics.h>//用于数学相关操作
#include <libavutil/timestamp.h>//用于时间戳操作
#include <libavformat/avformat.h>//用于封装与解封装操作
#include <libswscale/swscale.h>//用户缩放、转换颜色格式操作
#include <libswresample/swresample.h>//用于进行音频采样率操作

@interface BookStudyNoteViewController ()

@end

@implementation BookStudyNoteViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    av_register_all();
    AVOutputFormat *fmt;
    AVFormatContext *oc;//封装格式相关操作，需要此上下文
    
    avformat_alloc_output_context2(&oc, NULL, "flv", "test2");
    if (!oc) {
        printf("cannot alloc flv format\n");
        return ;
    }
    fmt = oc->oformat;
    
    //申请AVStream流 用来存放音频、视频、字幕数据流
    //将codec与avstream进行对应
    AVStream *st;
    AVCodecContext *c;
    st = avformat_new_stream(oc, NULL);
    if (!st) {
        printf("cannot alloccate stream\n");
    }
    
    st->id = oc->nb_streams-1;
    c->codec_id = CODEC_ID_TTF;
    c->bit_rate = 400000;
    c->width = 352;
    c->height = 288;
    st->time_base = (AVRational){1,25};
    c->time_base = st->time_base;
    c->gop_size = 12;
    c->pix_fmt = AV_PIX_FMT_YUV420P;
    
    //有些封装格式需要写入头部信息
    AVDictionary *opt;
    int ret;
    ret = avformat_write_header(oc, &opt);
    if (ret < 0) {
        printf("error occured when opening");
    }
    
    //写入帧数据
    AVFormatContext *ifmt_ctx = NULL;
    unsigned char *inbuff;

}

@end
