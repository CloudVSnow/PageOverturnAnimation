//
//  ViewController.m
//  PageOverturnAnimation
//
//  Created by LiuTian on 2018/1/10.
//  Copyright © 2018年 CloudVSnow. All rights reserved.
//

#import "ViewController.h"
#import <CoreGraphics/CoreGraphics.h>

#define KKHeight [UIScreen mainScreen].bounds.size.height
#define KKWidth [UIScreen mainScreen].bounds.size.width

@interface ViewController ()<UIGestureRecognizerDelegate>
@property(nonatomic,strong) UIImageView *upImageV;//展示图片
@property(nonatomic,strong) UIImageView *downImageV;

@property(nonatomic,strong) UIImageView *upTemporaryImageV;//翻转过程中临时展示图片
@property(nonatomic,strong) UIImageView *downTemporaryImageV;

@property(nonatomic,strong) NSMutableArray *upImageCache;//将布置好的View切割的图片的缓存
@property(nonatomic,strong) NSMutableArray *downImageCache;

@property(nonatomic,assign) CGFloat initialLocation;//手势初始值

@property(nonatomic,strong) NSMutableArray *viewsCash;//生成的View
@end

@implementation ViewController
{
    NSInteger _index; //翻转图片下标
    NSInteger _imageIndex;//当前图片下标
  
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    //初始化view
    self.view.backgroundColor = [UIColor whiteColor];
    [self overturnPrepare];
    
    //切割生成好的view
    [self performSelector:@selector(handleViews) withObject:nil afterDelay:1.0];
}

-(void)overturnPrepare{
    _index = 0;
    _imageIndex=0;
    
    self.upTemporaryImageV = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, KKWidth, KKHeight/2.f)];
    self.downTemporaryImageV = [[UIImageView alloc]initWithFrame:CGRectMake(0, KKHeight/2.f, KKWidth, KKHeight/2.f)];
    
    self.upImageV = [[UIImageView alloc]init];
    self.upImageV.userInteractionEnabled = YES;
    self.upImageV.layer.anchorPoint = CGPointMake(0.5, 1.0);
    self.upImageV.frame = self.upTemporaryImageV.frame;
    UIPanGestureRecognizer* downPan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(downPan:)];
    downPan.delegate = self;
    [self.upImageV addGestureRecognizer:downPan];
    
    self.downImageV = [[UIImageView alloc]init];
    self.downImageV.userInteractionEnabled = YES;
    self.downImageV.layer.anchorPoint = CGPointMake(0.5, 0);
    self.downImageV.frame = self.downTemporaryImageV.frame;
    UIPanGestureRecognizer* upPan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(upPan:)];
    upPan.delegate = self;
    [self.downImageV addGestureRecognizer:upPan];
    
    [self.view addSubview:self.upTemporaryImageV];
    [self.view addSubview:self.upImageV];
    [self.view addSubview:self.downTemporaryImageV];
    [self.view addSubview:self.downImageV];
    
}

-(void)handleViews{
    for (UIView *subView in self.viewsCash) {
        UIImage *upImage =  [self private_captureImageFromView:subView isUp:YES];
        UIImage *downImage = [self private_captureImageFromView:subView isUp:NO];
        [self.upImageCache addObject:upImage];
        [self.downImageCache addObject:downImage];
    }
    self.upImageV.image = self.upImageCache.firstObject;
    self.downImageV.image = self.downImageCache.firstObject;
}

#pragma mark --UIGestureRecognizerDelegate

-(void)upPan:(UIPanGestureRecognizer *)pan
{
    if (self.upImageCache.count<2) {
        return;
    }
    
    if (_index==self.upImageCache.count-1) {
        _index = -1;
    }
    static BOOL temporaryChange = YES; //是否替换临时图片
    static BOOL upPaninng=YES; //是否替换正在旋转的图片
    
    CGPoint location = [pan locationInView:pan.view.superview];
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.initialLocation = location.y;   //初始y坐标
    }
    CGFloat conversionFactor = M_PI/(pan.view.superview.frame.size.height-self.initialLocation);
    if ((location.y-self.initialLocation)*conversionFactor<=0&&(location.y-self.initialLocation)*conversionFactor>=-M_PI) { //0到180度之间翻转
        if (temporaryChange) {   //替换一次就不在替换
            self.downTemporaryImageV.image = self.downImageCache[_index+1];
            temporaryChange = NO;
        }
        self.downImageV.layer.transform = [self getTransForm3DWithAngle:-(location.y-self.initialLocation)*conversionFactor];
        if (-(location.y-self.initialLocation)*conversionFactor>M_PI_2) {  //超过90度;切换过一次图片就不在切换
            if (upPaninng) {
                upPaninng = NO;
                self.downImageV.image = [self rotateImage:self.upImageCache[_index+1] rotation:UIImageOrientationDown];
            }
            
        }else { //没超过90
            if (!upPaninng) {   //切换过一次图片就不在切换
                upPaninng = YES;
                if (_index==-1) {
                    self.downImageV.image = self.downImageCache[self.upImageCache.count-1];
                }else{
                    self.downImageV.image = self.downImageCache[_index];
                }
            }
        }
    }
    //用户松手
    if (pan.state == UIGestureRecognizerStateEnded) {
        temporaryChange = YES;
        __block CGFloat angle = -(location.y-self.initialLocation)*conversionFactor;
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(timer, ^{
            if (angle>=M_PI_2&&angle<M_PI) {  //超过90度翻页
                angle+=0.1;
                self.downImageV.layer.transform = [self getTransForm3DWithAngle:angle];
            }else{  //未超过90度不翻页
                angle-=0.1;
                self.downImageV.layer.transform = [self getTransForm3DWithAngle:angle];
            }
            
            if (angle>=M_PI) {  //180度取消定时器,并初始化
                self.upImageV.image = self.upImageCache[_index+1];
                [self.view bringSubviewToFront:self.upImageV];
                self.downImageV.image = self.downImageCache[_index+1];
                self.downImageV.layer.transform = [self getTransForm3DWithAngle:0];
                self.downImageV.frame = CGRectMake(0, KKHeight/2.0, KKWidth, KKHeight/2.0);
                [self.view bringSubviewToFront:self.downImageV];
                dispatch_cancel(timer);
                
                _index+=1; //图片下标加一
                
                _imageIndex += 1;
                if (_imageIndex==self.upImageCache.count) {
                    _imageIndex = self.upImageCache.count-1;
                }
            }
            
            if (angle<=0) {
                dispatch_cancel(timer);
                self.downImageV.layer.transform = [self getTransForm3DWithAngle:0];
                [self.view bringSubviewToFront:self.downImageV];
                
                if (_index==-1) {
                    _index=self.upImageCache.count-1;
                }
            }
        });
        dispatch_resume(timer);
    }
}

-(void)downPan:(UIPanGestureRecognizer *)pan
{
    if (self.upImageCache.count<2) {
        return;
    }
    static BOOL downing= YES;
    static BOOL temporaryChange = YES;
    if (_index==0) {
        _index = self.upImageCache.count;
    }
    CGPoint location = [pan locationInView:pan.view.superview];
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.initialLocation = location.y;
    }
    CGFloat conversionFactor = M_PI/(pan.view.superview.frame.size.height-self.initialLocation);
    if ((location.y-self.initialLocation)*conversionFactor>=0&&(location.y-self.initialLocation)*conversionFactor<=M_PI) {
        if (temporaryChange) {
            self.upTemporaryImageV.image = self.upImageCache[_index-1];
            temporaryChange = NO;
        }
        self.upImageV.layer.transform = [self getTransForm3DWithAngle:-(location.y-self.initialLocation)*conversionFactor];
        if ((location.y-self.initialLocation)*conversionFactor>M_PI_2) {
            if (downing) {
                downing = NO;
                self.upImageV.image = [self rotateImage:self.downImageCache[_index-1] rotation:UIImageOrientationDown];
            }
        }else {
            if (!downing) {
                downing = YES;
                if (_index==self.upImageCache.count) {
                    self.upImageV.image = self.upImageCache[0];
                }else{
                    self.upImageV.image = self.upImageCache[_index];
                }
            }
        }
    }
    
    if (pan.state == UIGestureRecognizerStateEnded) {
        temporaryChange = YES;
        ;
        __block CGFloat angle = -(location.y-self.initialLocation)*conversionFactor;
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(timer, ^{
            if (angle<=-M_PI_4) {
                angle-=0.1;
                self.upImageV.layer.transform = [self getTransForm3DWithAngle:angle];
                if (angle<=-M_PI_2) {
                    if (downing) {
                        downing =NO;
                        self.upImageV.image = [self rotateImage:self.downImageCache[_index-1] rotation:UIImageOrientationDown];
                    }
                }
            }else{
                angle+=0.1;
                self.upImageV.layer.transform = [self getTransForm3DWithAngle:angle];
            }
            if (angle<=-M_PI) {
                self.downImageV.image = self.downImageCache[_index-1];
                [self.view bringSubviewToFront:self.downImageV];
                self.upImageV.image = self.upImageCache[_index-1];
                self.upImageV.layer.transform = [self getTransForm3DWithAngle:0];
                //self.upImageV.frame = CGRectMake(0, 0, SCREEN_WIDTH, (SCREEN_HEIGHT-64)/2.0);
                [self.view bringSubviewToFront:self.upImageV];
                dispatch_cancel(timer);
                _index-=1;
                _imageIndex -= 1;
                if (_imageIndex==-1) {
                    _imageIndex = 0;
                }
            }
            if (angle>=0) {
                dispatch_cancel(timer);
                self.upImageV.layer.transform = [self getTransForm3DWithAngle:0];
                [self.view bringSubviewToFront:self.upImageV];
                if (_index==self.upImageCache.count) {
                    _index = 0;
                }
            }
        });
        dispatch_resume(timer);
    }
}

#pragma mark -- Image Handle
-(CATransform3D)getTransForm3DWithAngle:(CGFloat)angle{
    CATransform3D  transform = CATransform3DIdentity;
    transform.m34 = -2.0/2000;
    transform  = CATransform3DRotate(transform,angle, 1, 0, 0);
    return transform;
}

-(UIImage *)rotateImage:(UIImage *)image rotation:(UIImageOrientation)orientation
{
    long double rotate = 0.0;
    CGRect rect;
    float translateX = 0;
    float translateY = 0;
    float scaleX = 1.0;
    float scaleY = 1.0;
    
    switch (orientation) {
        case UIImageOrientationLeft:
            rotate = M_PI_2;
            rect = CGRectMake(0, 0, image.size.height, image.size.width);
            translateX = 0;
            translateY = -rect.size.width;
            scaleY = rect.size.width/rect.size.height;
            scaleX = rect.size.height/rect.size.width;
            break;
        case UIImageOrientationRight:
            rotate = 3 * M_PI_2;
            rect = CGRectMake(0, 0, image.size.height, image.size.width);
            translateX = -rect.size.height;
            translateY = 0;
            scaleY = rect.size.width/rect.size.height;
            scaleX = rect.size.height/rect.size.width;
            break;
        case UIImageOrientationDown:
            rotate = M_PI;
            rect = CGRectMake(0, 0, image.size.width, image.size.height);
            translateX = -rect.size.width;
            translateY = -rect.size.height;
            break;
        default:
            rotate = 0.0;
            rect = CGRectMake(0, 0, image.size.width, image.size.height);
            translateX = 0;
            translateY = 0;
            break;
    }
    
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextScaleCTM(context, scaleX, scaleY);
    //绘制图片
    CGContextDrawImage(context, CGRectMake(0, 0, rect.size.width, rect.size.height), image.CGImage);
    CGContextRestoreGState(context);
    UIImage *newPic = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newPic;
}

- (UIImage *)private_captureImageFromView:(UIView *)view isUp:(BOOL)up{
    CGRect imageRect = CGRectMake(0,0,KKWidth ,KKHeight/2.0);
    if (!up) {
        imageRect= CGRectMake(0,KKHeight/2.0,KKWidth ,KKHeight/2.0 );
    }
    UIGraphicsBeginImageContextWithOptions(imageRect.size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL){
        return nil;
    }
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, -imageRect.origin.x, -imageRect.origin.y);
    [view.layer renderInContext:context];
    CGContextRestoreGState(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

#pragma mark -- Getter

-(NSMutableArray *)upImageCache{
    if (!_upImageCache) {
        _upImageCache = [NSMutableArray array];
    }
    return _upImageCache;
}

-(NSMutableArray *)downImageCache{
    if (!_downImageCache) {
        _downImageCache = [NSMutableArray array];
    }
    return _downImageCache;
}

-(NSMutableArray *)viewsCash{
    if (!_viewsCash) {
        _viewsCash = [NSMutableArray array];
        NSArray *imageNames = @[@"IMG_2986.PNG",@"IMG_2985.PNG",@"IMG_2988.PNG",@"IMG_2987.PNG",@"IMG_2989.PNG"];
        for (NSString *name in imageNames) {
            UIImageView *imageV = [[UIImageView alloc]initWithImage:[UIImage imageNamed:name]];
            imageV.frame = CGRectMake(0, 0, KKWidth, KKHeight);
            [_viewsCash addObject:imageV];
        }
    }
    return _viewsCash;
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
