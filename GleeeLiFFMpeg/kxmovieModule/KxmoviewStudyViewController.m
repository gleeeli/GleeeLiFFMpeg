//
//  KxmoviewStudyViewController.m
//  GleeeLiFFMpeg
//
//  Created by 小柠檬 on 2019/2/20.
//  Copyright © 2019年 gleeli. All rights reserved.
//

#import "KxmoviewStudyViewController.h"
#import "KxMovieViewController.h"

@interface KxmoviewStudyViewController ()

@end

@implementation KxmoviewStudyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(50, 150, 100, 50)];
    [btn setTitle:@"play test" forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(playTest:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
}

- (void)playTest:(UIButton *)btn {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"NineMinute" ofType:@"mp4"];
    UIViewController *vc;
    vc = [KxMovieViewController movieViewControllerWithContentPath:path parameters:nil];
    [self presentViewController:vc animated:YES completion:nil];
}

@end
