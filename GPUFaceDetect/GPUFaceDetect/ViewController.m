//
//  ViewController.m
//  GPUFaceDetect
//
//  Created by BJ on 2018/11/27.
//  Copyright © 2018年 face. All rights reserved.
//

#import "ViewController.h"
#import "GPUFaceViewController.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(100, 200, 180, 50)];
    btn.backgroundColor = [UIColor grayColor];
    [btn setTitle:@"点击进入人脸识别" forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(btn) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    
}

-(void)btn{
    GPUFaceViewController *faceVC = [[GPUFaceViewController alloc] init];
    [self.navigationController pushViewController:faceVC animated:YES];
}



@end
