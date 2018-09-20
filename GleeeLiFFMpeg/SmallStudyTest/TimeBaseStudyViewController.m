//
//  TimeBaseStudyViewController.m
//  GleeeLiFFMpeg
//
//  Created by 小柠檬 on 2018/9/20.
//  Copyright © 2018年 gleeli. All rights reserved.
//

#import "TimeBaseStudyViewController.h"
#include <libswscale/swscale.h>

@interface TimeBaseStudyViewController ()

@end

@implementation TimeBaseStudyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"时间基";
    
    AVRational radio;
    radio.num = 1;
    radio.den = 1000;
    
    AVRational radio2;
    radio2.num = 1;
    radio2.den = 10;
    
    int64_t now = av_rescale_q_rnd(2000, radio, radio2, AV_ROUND_NEAR_INF);
    printf("result:%lld", now);//输出20
}

@end
