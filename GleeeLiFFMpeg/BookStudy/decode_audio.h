//
//  decode_audio.h
//  GleeeLiFFMpeg
//
//  Created by 小柠檬 on 2019/6/19.
//  Copyright © 2019 gleeli. All rights reserved.
//

#ifndef decode_audio_h
#define decode_audio_h

#include <stdio.h>

/**
 解码音频
 
 @param outfilename pcm文件路径
 @param filename 音频文件如mp3
 */
int start_main_decode_audio(const char *outfilename, const char *filename);

#endif /* decode_audio_h */
