//
//  RunCExampleViewController.m
//  GleeeLiFFMpeg
//
//  Created by 小柠檬 on 2019/6/18.
//  Copyright © 2019 gleeli. All rights reserved.
//

#import "RunCExampleViewController.h"
#import "avio_reading.h"
#import "decode_audio.h"
#import "CommHeader.h"

@interface RunCExampleViewController ()

@end

@implementation RunCExampleViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //NineMinute test2
    NSString *loaclVideoPath = [[NSBundle mainBundle] pathForResource:@"test2" ofType:@"mp4"];
    const char *path = [loaclVideoPath UTF8String];
    
    if ([self.typeName isEqualToString:@"avio_reading"]) {
        char inputname[1000];
        
        strcpy(inputname, path);
        NSLog(@"复制后的内容：%s",inputname);
        start_main_avio_reading(path);
    }else if ([self.typeName isEqualToString:@"decode_audio"]) {
        
         NSString *pcmfilePath = [kPathDocument stringByAppendingPathComponent:@"audioPcm.pcm"];
        const char *pcmpath = [pcmfilePath UTF8String];
        NSLog(@"解码后的pcm文件路径：%@",pcmfilePath);
        
        NSString *mp3filePath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"mp3"];
        const char *mp3path = [mp3filePath UTF8String];
        
        start_main_decode_audio(pcmpath, mp3path);
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
