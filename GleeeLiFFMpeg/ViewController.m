//
//  ViewController.m
//  GleeeLiFFMpeg
//
//  Created by zqh on 2018/6/28.
//  Copyright © 2018年 gleeli. All rights reserved.
//

#import "ViewController.h"
#import "GainYUVDataViewController.h"
#import "CommAudioUnitViewController.h"

@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSMutableArray *muArray;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"选择功能";
    
    self.muArray = [[NSMutableArray alloc] init];
    [self.muArray addObject:@"获取视频的YUV数据，保存到本地"];
    [self.muArray addObject:@"使用AudioUnit 录音和播放录音"];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 40;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.muArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell"];
    cell.textLabel.text = self.muArray[indexPath.row];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *title = self.muArray[indexPath.row];
    if ([title isEqualToString:@"获取视频的YUV数据，保存到本地"])
    {
        UIStoryboard *storyboar = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        GainYUVDataViewController *gaiVc = [storyboar instantiateViewControllerWithIdentifier:@"GainYUVDataViewController"];
        [self.navigationController pushViewController:gaiVc animated:YES];
    }
    if ([title isEqualToString:@"使用AudioUnit 录音和播放录音"])
    {
        //UIStoryboard *storyboar = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        CommAudioUnitViewController *audioUnitVC = [[CommAudioUnitViewController alloc] init];
        [self.navigationController pushViewController:audioUnitVC animated:YES];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
