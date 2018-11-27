//
//  GPUFaceViewController.m
//  GPUFaceDetect
//
//  Created by BJ on 2018/11/27.
//  Copyright © 2018年 face. All rights reserved.
//

#import "GPUFaceViewController.h"
#import "GPUImage.h"
#import "GPUImageBeautifyFilter.h"

#define WS(weakSelf) __weak __typeof(&*self) weakSelf = self
#define kWidth [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height

@interface GPUFaceViewController ()<GPUImageVideoCameraDelegate,AVCaptureMetadataOutputObjectsDelegate,AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong) GPUImageStillCamera *Camera;
@property (nonatomic, strong) GPUImageView *filterView;
@property (nonatomic, strong) UIButton *beautifyButton;
@property (strong, nonatomic) AVCaptureMetadataOutput *medaDataOutput;
@property (strong, nonatomic) dispatch_queue_t captureQueue;
@property (nonatomic, strong) AVCapturePhotoOutput *iOutput;

@property (nonatomic, strong) NSArray *faceObjects;
@property (nonatomic,strong)UIImageView *imageView;
@property(nonatomic,assign)BOOL isFirst;
@property(nonatomic,strong)UIView *roundView;
@property(nonatomic,strong)UIImageView *faceImgView;
@property(nonatomic,strong)NSData *imageData;
@property (nonatomic, strong) UIView *maskView;

@end

@implementation GPUFaceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
   // self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"人脸识别";
    _isFirst = YES;
    
    [self faceDeviceInit];
    [self initUI];
}

//摄像头相关设置
-(void)faceDeviceInit{
    self.captureQueue = dispatch_queue_create("com.kimsungwhee.mosaiccamera.videoqueue", NULL);
    
    self.videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1920x1080 cameraPosition:AVCaptureDevicePositionBack];
    self.videoCamera.delegate = self;
    
    self.videoCamera.videoCaptureConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    self.filterView = [[GPUImageView alloc] initWithFrame:CGRectMake(0, 64, kWidth, kHeight-64)];
    self.filterView.backgroundColor = [UIColor clearColor];
    self.filterView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    [self.view addSubview:self.filterView];
    
    [self.videoCamera startCameraCapture];
    
    //美颜
    [self beautify];
    
    //Meta data
    dispatch_async(dispatch_get_main_queue(), ^{
        self.medaDataOutput = [[AVCaptureMetadataOutput alloc] init];
        if ([self.videoCamera.captureSession canAddOutput:self.medaDataOutput]) {
            [self.videoCamera.captureSession addOutput:self.medaDataOutput];
            //类型设置为人脸
            self.medaDataOutput.metadataObjectTypes = @[AVMetadataObjectTypeFace];
            [self.medaDataOutput setMetadataObjectsDelegate:self queue:self.captureQueue];
        }
    });
 
    //设置有效扫描区域
    [self setScanArea];
    
}


-(void)initUI{
    _faceImgView = [[UIImageView alloc] initWithFrame:CGRectMake(kWidth - 120 , 64, 120, 120)];
    _faceImgView.backgroundColor = [UIColor blueColor];
    [self.view addSubview:_faceImgView];
    
    
    UILabel *titleLab = [[UILabel alloc] initWithFrame:CGRectMake(52, 100, kWidth - 108, 18)];
    titleLab.text = @"请对准脸部拍摄  提高认证成功率";
    titleLab.textAlignment = NSTextAlignmentCenter;
    titleLab.textColor = [UIColor redColor];
    titleLab.font = [UIFont systemFontOfSize:17];
    [self.view addSubview:titleLab];
}


// 设置有效扫描区域
-(void)setScanArea{
    
    _maskView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kWidth, kHeight)];
    
    _maskView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
    
    [self.view addSubview:_maskView];
    
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, kWidth, kHeight)];
    
    [maskPath appendPath:[[UIBezierPath bezierPathWithRoundedRect:CGRectMake(73, 206, kWidth - 142, kWidth - 142) cornerRadius:(kWidth - 142)/2.0] bezierPathByReversingPath]];
    
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    
    maskLayer.path = maskPath.CGPath;
    
    _maskView.layer.mask = maskLayer;
    
}

//美颜
- (void)beautify {
    [self.videoCamera removeAllTargets];
    GPUImageBeautifyFilter *beautifyFilter = [[GPUImageBeautifyFilter alloc] init];
    [self.videoCamera addTarget:beautifyFilter];
    [beautifyFilter addTarget:self.filterView];
}


//显示截取到的图片，请求人脸识别接口
-(void)uploadFaceImg:(UIImage *)image{
    _faceImgView.image = image;
   
    NSLog(@"imageData:%@",self.imageData);
    WS(weakSelf);
    //这里设置为2秒后可以进行继续检测
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        weakSelf.isFirst = YES;
    });
   //这里开始写请求接口的代码
    
}


//GPUImage代理方法
- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
    CIImage *sourceImage;
    
    CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    sourceImage = [CIImage imageWithCVPixelBuffer:imageBuffer
                                          options:nil];
    
    WS(weakSelf);
    //检测到人脸
    if (self.faceObjects && self.faceObjects.count > 0) {
        NSLog(@"self.faceObjects.count == %ld",self.faceObjects.count);
       //这个布尔值用于判断检测到人脸后，获取到人脸照片，不用再进行持续检测
        if (_isFirst) {
             //因为刚开始扫描到的人脸是模糊照片，所以延迟几秒获取
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                //该view用来获取截取人脸的Frame
                UIView *view = [[UIView alloc] initWithFrame:CGRectMake(73, 146, kWidth - 142, kWidth - 142)];
                [self.view addSubview:view];
                
                //截取屏幕
                UIGraphicsBeginImageContext(weakSelf.filterView.bounds.size);
                [weakSelf.filterView drawViewHierarchyInRect:weakSelf.filterView.bounds afterScreenUpdates:YES];;//截取动态图形
                [weakSelf.filterView.layer renderInContext:UIGraphicsGetCurrentContext()];
                UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                
                //截取屏幕中的人脸
                UIImage *faceImage = [UIImage imageWithCGImage:CGImageCreateWithImageInRect(newImage.CGImage, view.frame)];
                //  UIImageWriteToSavedPhotosAlbum(firstImage, self, nil, nil); //将图片保存到相册
                //转换人脸图片为NSData类型
                weakSelf.imageData = UIImageJPEGRepresentation(faceImage, 0.05);
                //获取人脸图片后，请求人脸识别接口
                [self uploadFaceImg:faceImage];
            });
            _isFirst = NO;
            
        }
    }else {
        //无人脸
    }
}



//AVCaptureMetadataOutputObjectsDelegate ===== 拿出当前帧的图片进行人脸识别
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    self.faceObjects = metadataObjects;
}


- (AVCaptureVideoOrientation) videoOrientationFromCurrentDeviceOrientation {
    switch (self.interfaceOrientation) {
        case UIInterfaceOrientationPortrait: {
            return AVCaptureVideoOrientationPortrait;
        }
        case UIInterfaceOrientationLandscapeLeft: {
            return AVCaptureVideoOrientationLandscapeLeft;
        }
        case UIInterfaceOrientationLandscapeRight: {
            return AVCaptureVideoOrientationLandscapeRight;
        }
        case UIInterfaceOrientationPortraitUpsideDown: {
            return AVCaptureVideoOrientationPortraitUpsideDown;
        }
        default:
            return AVCaptureVideoOrientationPortrait;
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
