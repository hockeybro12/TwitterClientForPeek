//
//  DetailViewController.h
//  TwitterClientForPeek
//
//  Created by Nikhil Mehta on 1/9/16.
//  Copyright © 2016 MehtaiPhoneApps. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Social/Social.h>
#import <Accounts/Accounts.h>

@interface DetailViewController : UIViewController {
    IBOutlet UITextView *captionTextField;
    IBOutlet UIImageView *photoImageView;
    IBOutlet UIButton *retweetButton;
    IBOutlet UILabel *userNameLabel;
}

@property (nonatomic, strong) UITextView *captionTextField;
@property (nonatomic, strong) NSString *captionTextString;
@property (nonatomic, strong) UIImageView *photoImageView;
@property (nonatomic, strong) NSString *tweetString;
@property (nonatomic, strong) NSString *photoURL;
@property (nonatomic, strong) ACAccount *accountToUse;
@property (nonatomic, strong) NSString *userNameString;

@end
