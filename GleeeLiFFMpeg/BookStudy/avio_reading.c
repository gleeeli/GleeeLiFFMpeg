//
//  avio_reading.c
//  GleeeLiFFMpeg
//
//  Created by 小柠檬 on 2019/6/18.
//  Copyright © 2019 gleeli. All rights reserved.

/*
 muxer是指合并文件，即将视频文件、音频文件和字幕文件合并为某一个视频格式
demuxer是muxer的逆过程，就是把合成的文件中提取出不同的格式文件。
*/

/**
 * @file
 * libavformat AVIOContext API example.
 *
 * Make libavformat demuxer access media content through a custom
 * AVIOContext read callback.
 * @example avio_reading.c
 */

#include "avio_reading.h"

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavformat/avio.h>
#include <libavutil/file.h>

struct buffer_data {
    uint8_t *ptr;//正在读的buffer内存地址
    size_t size; ///< size left in the buffer
};
//读取文件的回调函数，每次返回4096
static int read_packet(void *opaque, uint8_t *buf, int buf_size)
{
    struct buffer_data *bd = (struct buffer_data *)opaque;
    buf_size = FFMIN(buf_size, bd->size);
    if (!buf_size)
        return AVERROR_EOF;
    //打印当前buffer的内存地址，以及剩余未读取的文件大小
    printf("ptr:%p size:%zu\n", bd->ptr, bd->size);
    /* copy internal buffer data to buf */
    memcpy(buf, bd->ptr, buf_size);
    bd->ptr  += buf_size;
    bd->size -= buf_size;
    return buf_size;
}

int start_main_avio_reading(char *input_filename)
{
    //少了这个avformat_open_input会报错：Invalid data found when processing input
    av_register_all();
    
    AVFormatContext *fmt_ctx = NULL;//解封装上下文，或者称：格式上下文
    AVIOContext *avio_ctx = NULL;//输入输出数据的结构体。
    uint8_t *buffer = NULL, *avio_ctx_buffer = NULL;
    //文件存储在扇区，多个扇区组成块，不同系统块的大小不一样，一般是4096，这里定义读取文件时，每次读取的buffer缓冲大小
    size_t buffer_size, avio_ctx_buffer_size = 4096;

    int ret = 0;
    struct buffer_data bd = { 0 };

    /* slurp（映射） file content into buffer */
    ret = av_file_map(input_filename, &buffer, &buffer_size, 0, NULL);
    if (ret < 0)
        goto end;
    /* fill opaque structure used by the AVIOContext read callback */
    bd.ptr  = buffer;//文件读取起始内存地址
    bd.size = buffer_size;//文件总大小
    if (!(fmt_ctx = avformat_alloc_context())) {
        ret = AVERROR(ENOMEM);
        goto end;
    }
    avio_ctx_buffer = av_malloc(avio_ctx_buffer_size);
    if (!avio_ctx_buffer) {
        ret = AVERROR(ENOMEM);
        goto end;
    }
    //将每次读取的buffer大小，起始地址，文件总大小，回调函数，封装进读取文件的上下文中
    avio_ctx = avio_alloc_context(avio_ctx_buffer, avio_ctx_buffer_size,
                                  0, &bd, &read_packet, NULL, NULL);
    if (!avio_ctx) {
        ret = AVERROR(ENOMEM);
        goto end;
    }
    //读取文件上下文赋值给封装格式上下文的pd属性
    fmt_ctx->pb = avio_ctx;
    
//    AVInputFormat* iformat=av_find_input_format("h264");
    ret = avformat_open_input(&fmt_ctx, NULL, NULL, NULL);
    if (ret < 0) {
        fprintf(stderr, "Could not open input\n");
        goto end;
    }
     /*在一些格式当中没有头部信息，如flv格式，h264格式，
      这个时候调用avformat_open_input()在打开文件之后就没有参数，也就无法获取到里面的信息。
      填充AVStream信息，比如时间dts pts，pix_fmt图像格式yuv或RGB，codec_width编码宽和高
     */
    ret = avformat_find_stream_info(fmt_ctx, NULL);
    if (ret < 0) {
        fprintf(stderr, "Could not find stream information\n");
        goto end;
    }
    av_dump_format(fmt_ctx, 0, input_filename, 0);
end:
    avformat_close_input(&fmt_ctx);
    /* note: the internal buffer could have changed, and be != avio_ctx_buffer */
    if (avio_ctx)
        av_freep(&avio_ctx->buffer);
    
    av_free(avio_ctx);
//    avio_context_free(&avio_ctx);
    av_file_unmap(buffer, buffer_size);
    if (ret < 0) {
        fprintf(stderr, "Error occurred: %s\n", av_err2str(ret));
        return 1;
    }
    return 0;
}
