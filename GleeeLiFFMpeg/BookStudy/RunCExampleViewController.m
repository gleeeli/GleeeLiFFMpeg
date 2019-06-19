//
//  RunCExampleViewController.m
//  GleeeLiFFMpeg
//
//  Created by 小柠檬 on 2019/6/18.
//  Copyright © 2019 gleeli. All rights reserved.
//

#import "RunCExampleViewController.h"
#import "avio_reading.h"

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
