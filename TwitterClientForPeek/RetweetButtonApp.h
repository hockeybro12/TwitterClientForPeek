//
//  RetweetButtonApp.h
//  TwitterClientForPeek
//
//  Created by Nikhil Mehta on 1/9/16.
//  Copyright © 2016 MehtaiPhoneApps. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RetweetButtonApp : UIButton {
    
    id userData;
    
}

@property (nonatomic, readwrite, retain) id userData;

@end
