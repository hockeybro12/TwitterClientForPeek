//
//  DetailViewController.m
//  TwitterClientForPeek
//
//  Created by Nikhil Mehta on 1/9/16.
//  Copyright © 2016 MehtaiPhoneApps. All rights reserved.
//

#import "DetailViewController.h"


@interface DetailViewController ()

@end

@implementation DetailViewController
@synthesize captionTextField;
@synthesize captionTextString;
@synthesize photoImageView;
@synthesize tweetString;
@synthesize photoURL;
@synthesize accountToUse;
@synthesize userNameString;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    //set the caption
    captionTextField.text = captionTextString;
    
    //set the image View
    [self getProfileImageForURLString:photoURL andImageView:photoImageView];
    
    [retweetButton addTarget:self action:@selector(retweetButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    

    userNameLabel.text = userNameString;

    
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) getProfileImageForURLString:(NSString *)urlString andImageView:(UIImageView *)imageView;
{
    //use the url to make an image, resize it to 200 * 200 and insert it into the passed in imageView
    NSURL *url = [NSURL URLWithString:urlString];
    NSData *data = [NSData dataWithContentsOfURL:url];
    UIImage *image = [UIImage imageWithData:data];
    CGSize size = CGSizeMake(200, 200);
    UIImage *realImage = [self resizeImage:image newSize:size];
    [imageView setImage:realImage];
}

- (UIImage *)resizeImage:(UIImage*)image newSize:(CGSize)newSize {
    CGRect newRect = CGRectIntegral(CGRectMake(0, 0, newSize.width, newSize.height));
    CGImageRef imageRef = image.CGImage;
    
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Set the quality level to use when rescaling
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, newSize.height);
    
    CGContextConcatCTM(context, flipVertical);
    // Draw into the context; this scales the image
    CGContextDrawImage(context, newRect, imageRef);
    
    // Get the resized image from the context and a UIImage
    CGImageRef newImageRef = CGBitmapContextCreateImage(context);
    UIImage *newImage = [UIImage imageWithCGImage:newImageRef];
    
    CGImageRelease(newImageRef);
    UIGraphicsEndImageContext();
    
    return newImage;
}

//same retweet as before
-(void)retweetButtonClicked:(id)sender{
    NSString *retweetString = [NSString stringWithFormat:@"https://api.twitter.com/1/statuses/retweet/%@.json", tweetString];
    NSURL *retweetURL = [NSURL URLWithString:retweetString];
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:retweetURL parameters:nil];
    request.account = accountToUse;
    
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if (responseData)
        {
            //NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
            //NSLog(@"%@", responseDict);
            NSLog(@"finished retweeting");
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // code here
                [[[UIAlertView alloc]initWithTitle:@"Success!"
                                           message:@"Your have retweeted this tweet"
                                          delegate:nil
                                 cancelButtonTitle:@"Yay!"
                                 otherButtonTitles: nil] show];
            });
            
            
        }
        else
        {
            NSLog(@"Request Error: %@", [error localizedDescription]);
        }
    }];
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

