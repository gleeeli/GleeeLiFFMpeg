//
//  decode_audio.c
//  GleeeLiFFMpeg
//
//  Created by 小柠檬 on 2019/6/19.
//  Copyright © 2019 gleeli. All rights reserved.
//

#include "decode_audio.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libavutil/frame.h>
#include <libavutil/mem.h>
#include <libavcodec/avcodec.h>
#define AUDIO_INBUF_SIZE 20480
#define AUDIO_REFILL_THRESH 4096

//static void decode(AVCodecContext *dec_ctx, AVPacket *pkt, AVFrame *frame,
//                   FILE *outfile)
//{
//    int i, ch;
//    int ret, data_size;
//    /* send the packet with the compressed data to the decoder */
//
//    int got_frame_ptr = 0;
//    ret = avcodec_decode_audio4(dec_ctx, frame, &got_frame_ptr, pkt);
//
////    ret = avcodec_send_packet(dec_ctx, pkt);
//
//    if (ret < 0) {
//        av_frame_free(&frame);
//        fprintf(stderr, "Error avcodec_decode_audio4 \n");
////        fprintf(stderr, "Error submitting the packet to the decoder\n");
//        exit(1);
//    }
//    /* read all the output frames (in general there may be any number of them */
////    while (ret >= 0) {
////        ret = avcodec_receive_frame(dec_ctx, frame);
//        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF)
//            return;
//        else if (ret < 0) {
//            fprintf(stderr, "Error during decoding\n");
//            exit(1);
//        }
//        data_size = av_get_bytes_per_sample(dec_ctx->sample_fmt);
//        if (data_size < 0) {
//            /* This should not occur, checking just for paranoia */
//            fprintf(stderr, "Failed to calculate data size\n");
//            exit(1);
//        }
//        for (i = 0; i < frame->nb_samples; i++)
//            for (ch = 0; ch < dec_ctx->channels; ch++)
//                fwrite(frame->data[ch] + data_size*i, 1, data_size, outfile);
////    }
//}

static void decode(AVCodecContext *dec_ctx, AVPacket *pkt, AVFrame *frame,
                   FILE *outfile)
{
    int i, ch;
    int ret, data_size;
    
    int got_frame_ptr = 0;
    ret = avcodec_decode_audio4(dec_ctx, frame, &got_frame_ptr, pkt);
    
    if (ret < 0) {
        av_frame_free(&frame);
        fprintf(stderr, "Error avcodec_decode_audio4 \n");
        //        fprintf(stderr, "Error submitting the packet to the decoder\n");
        exit(1);
    }

    if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF)
        return;
    else if (ret < 0) {
        fprintf(stderr, "Error during decoding\n");
        exit(1);
    }
    
    data_size = av_get_bytes_per_sample(dec_ctx->sample_fmt);
    if (data_size < 0) {
        /* This should not occur, checking just for paranoia */
        fprintf(stderr, "Failed to calculate data size\n");
        exit(1);
    }
    
    if (got_frame_ptr)
    {
        //data[0] = 左声道L data[1] = 右声道R
        if (frame->data[0] && frame->data[1])
        {
            //nb_samples：音频的一个AVFrame中可能包含多个音频帧，在此标记包含了几个
            for (int i = 0; i < frame->nb_samples; i++)
            {
                fwrite(frame->data[0] + i * data_size, 1, data_size, outfile);
                fwrite(frame->data[1] + i * data_size, 1, data_size, outfile);
            }
            
            for (i = 0; i < frame->nb_samples; i++)
                for (ch = 0; ch < dec_ctx->channels; ch++)
                    fwrite(frame->data[ch] + data_size*i, 1, data_size, outfile);

        }
        else if(frame->data[0])
        {
            fwrite(frame->data[0], 1, frame->linesize[0], outfile);
        }
    }
}

int start_main(int argc, char **argv)
{
    const char *outfilename, *filename;
    const AVCodec *codec;
    AVCodecContext *c= NULL;
    AVCodecParserContext *parser = NULL;
    int len, ret;
    FILE *f, *outfile;
    /*
     注释：在输入比特流结尾的要求附加分配字节的数量上进行解码。
     
     这主要是因为一些优化的比特流读取器一次读取32位或64位，并且可以读取结束字节之外。
     
     注意：如果附加字节的前23位不为0，则损坏的MPEG比特流可能会导致重读和segfault(发生错误)。
     */
    uint8_t inbuf[AUDIO_INBUF_SIZE + 64];//AV_INPUT_BUFFER_PADDING_SIZE
    uint8_t *data;
    size_t   data_size;
    AVPacket *pkt = NULL;
    AVFrame *decoded_frame = NULL;
    if (argc <= 2) {
        fprintf(stderr, "Usage: %s <input file> <output file>\n", argv[0]);
        exit(0);
    }
    filename    = argv[1];
    outfilename = argv[2];
    av_init_packet(pkt);
//    pkt = av_packet_alloc();
    /* find the MPEG audio decoder */
    codec = avcodec_find_decoder(AV_CODEC_ID_MP2);
    if (!codec) {
        fprintf(stderr, "Codec not found\n");
        exit(1);
    }
    parser = av_parser_init(codec->id);
    if (!parser) {
        fprintf(stderr, "Parser not found\n");
        exit(1);
    }
    c = avcodec_alloc_context3(codec);
    if (!c) {
        fprintf(stderr, "Could not allocate audio codec context\n");
        exit(1);
    }
    /* open it */
    if (avcodec_open2(c, codec, NULL) < 0) {
        fprintf(stderr, "Could not open codec\n");
        exit(1);
    }
    f = fopen(filename, "rb");
    if (!f) {
        fprintf(stderr, "Could not open %s\n", filename);
        exit(1);
    }
    outfile = fopen(outfilename, "wb");
    if (!outfile) {
        av_free(c);
        exit(1);
    }
    /* decode until eof */
    data      = inbuf;
    data_size = fread(inbuf, 1, AUDIO_INBUF_SIZE, f);
    while (data_size > 0) {
        if (!decoded_frame) {
            if (!(decoded_frame = av_frame_alloc())) {
                fprintf(stderr, "Could not allocate audio frame\n");
                exit(1);
            }
        }
        ret = av_parser_parse2(parser, c, &pkt->data, &pkt->size,
                               data, data_size,
                               AV_NOPTS_VALUE, AV_NOPTS_VALUE, 0);
        if (ret < 0) {
            fprintf(stderr, "Error while parsing\n");
            exit(1);
        }
        data      += ret;
        data_size -= ret;
        if (pkt->size)
            decode(c, pkt, decoded_frame, outfile);
        if (data_size < AUDIO_REFILL_THRESH) {
            memmove(inbuf, data, data_size);
            data = inbuf;
            len = fread(data + data_size, 1,
                        AUDIO_INBUF_SIZE - data_size, f);
            if (len > 0)
                data_size += len;
        }
    }
    /* flush(清空) the decoder */
    pkt->data = NULL;
    pkt->size = 0;
    decode(c, pkt, decoded_frame, outfile);
    fclose(outfile);
    fclose(f);
    avcodec_free_context(&c);
    av_parser_close(parser);
    av_frame_free(&decoded_frame);
    av_free_packet(pkt);
//    av_packet_free(&pkt);
    return 0;
}


/*
 fwrite 写入文本函数理解案列：
 
 int main ()
 {
     FILE * pFile;
     char buffer[] = { 'x' , 'y' , 'z' };
     pFile = fopen ( "myfile.bin" , "wb" );
     fwrite (buffer , sizeof(char), sizeof(buffer) , pFile );
     fclose (pFile);
     return 0;
 }
 
 */