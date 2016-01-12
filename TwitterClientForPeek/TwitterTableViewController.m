//
//  TwitterTableViewController.m
//  TwitterClientForPeek
//
//  Created by Nikhil Mehta on 1/8/16.
//  Copyright © 2016 MehtaiPhoneApps. All rights reserved.
//

#import "TwitterTableViewController.h"
#import <Social/Social.h>
#import <Accounts/Accounts.h>
#import "UIScrollView+SVInfiniteScrolling.h"
#import "UIScrollView+SVPullToRefresh.h"
#import "RetweetButtonApp.h"
#import "SDWebImage/UIImageView+WebCache.h"
#import <Fabric/Fabric.h>
#import <TwitterKit/TwitterKit.h>
#import "DetailViewController.h"


//I used SVPullToRefresh to handle the infinite scrolling and refresh: https://github.com/samvermette/SVPullToRefresh

@interface TwitterTableViewController () <TWTRTweetViewDelegate>

@end

@implementation TwitterTableViewController

@synthesize tableData;
NSArray *twitterFeedArray;
int count = 15;
ACAccount *accountToUse;
BOOL didAddMediaURL;
NSMutableDictionary *lookForExistingTweets;

NSArray *colorKeysArray;
NSDictionary *colorsArray;
int colorsArrayCount = 0;



- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.allowsMultipleSelectionDuringEditing = NO;

    //array to set up the different colors. i use a dictionary and the key is the string values and the actual colors are the values so we can easily access later
    colorKeysArray = [NSArray arrayWithObjects:@"yellow", @"purple", @"green", @"cyan", @"gray", nil];
    NSArray * colorValues = [NSArray arrayWithObjects:[UIColor yellowColor], [UIColor colorWithRed:(189/255.0) green:(162/255.0) blue:(212/255.0) alpha:1], [UIColor colorWithRed:(171/255.0) green:(214/255.0) blue:(149/255.0) alpha:1], [UIColor cyanColor], [UIColor lightGrayColor], nil];
    colorsArray = [NSDictionary dictionaryWithObjects:colorValues forKeys:colorKeysArray];
    colorsArrayCount = 0;
    
    
    __weak TwitterTableViewController *weakSelf = self;
    
    //make sure the insets are correct for the infinite scrolling and pull to refresh
    UIEdgeInsets currentInset = self.tableView.contentInset;
    currentInset.top = self.navigationController.navigationBar.bounds.size.height;
    self.automaticallyAdjustsScrollViewInsets = NO;
    currentInset.top += 20;
    
    self.tableView.contentInset = currentInset;
    
    //__block BOOL addToFront;

    //[weakSelf refreshTwitterView];

    [weakSelf.tableView addPullToRefreshWithActionHandler:^{
        //blocks for refreshing
        BOOL addToFront = true;
        colorsArrayCount = 0;
        [weakSelf refreshTwitterView:addToFront];
    }];
    
    [weakSelf.tableView addInfiniteScrollingWithActionHandler:^{

        BOOL addToFront = false;
        colorsArrayCount = 0;
        //increment the count of tweets to load
        count = count+5;
        //blocks for infinite scrolling
        [weakSelf refreshTwitterView:addToFront];
    }];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return YES if you want the specified item to be editable.
    return YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [self.tableView triggerPullToRefresh];
}


- (void)tableView: (UITableView*)tableView willDisplayCell: (UITableViewCell*)cell forRowAtIndexPath: (NSIndexPath*)indexPath {
    //helper delegate method to change the color of the text
    NSString *string = [colorKeysArray objectAtIndex:colorsArrayCount];
    cell.backgroundColor = [colorsArray valueForKey:string];
    //cell.backgroundColor = [UIColor string];
    
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    if (colorsArrayCount >= 4) {
        //since i only have 5 colors, reset the count if it gets above 4. can also be done randomized or using mod but I did it this way
        colorsArrayCount = 0;
    } else {
        colorsArrayCount++;
    }

}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        //deleton
        //get the cell and its text at the current indexPath
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        NSString *cellText = cell.textLabel.text;
        
        UILabel *userNameButton = (UILabel*)[cell.contentView viewWithTag:(indexPath.row + 2200)];
        cellText = [userNameButton.text stringByAppendingString:cellText];
        NSLog(@"%@", cellText);

        //get the dictionary
        NSDictionary *retrievedDictionary = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"DicKey"];
        if (retrievedDictionary == nil) {
            //if dictionary doesn't already exist, create it by adding the value and putting it into nsuserdefaults
            NSMutableDictionary *mutableDictionary = [[NSMutableDictionary alloc] init];
            
            
            
            [mutableDictionary setValue:@"1" forKey:cellText];
            
            [[NSUserDefaults standardUserDefaults] setObject:mutableDictionary forKey:@"DicKey"];

        } else {
            //else just add another key to it
            NSMutableDictionary *mutableRetrievedDictionary = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DicKey"] mutableCopy];
            
            NSString *valueKey = [mutableRetrievedDictionary objectForKey:cellText];
            
            [mutableRetrievedDictionary setValue:@"1" forKey:cellText];
            
            [[NSUserDefaults standardUserDefaults] setObject:mutableRetrievedDictionary forKey:@"DicKey"];

        }
        [tableData removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
//    NSLog(@"CALLED");

  //  NSLog(@"SUP count is %lu", (unsigned long)[twitterFeedArray count]);
    return [self.tableData count];
}

-(void)refreshTwitterView:(BOOL)addToFront {
    __weak TwitterTableViewController *weakSelf = self;

    
    colorsArrayCount = 0;
    //built using assistance from : http://www.techotopia.com/index.php/IPhone_iOS_6_Facebook_and_Twitter_Integration_using_SLRequest
    
    //used to gain access to the account that is stored in the settings part of the app
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    //NSLog(@"Step 1");
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    [accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error) {
      //  NSLog(@"Step 2");
    //at this point if granted is yes, then we have access
    if (granted == YES) {
        NSArray *account = [accountStore accountsWithAccountType:accountType];
        if (!account || (account.count)) {
            //if there are multiple accounts, just use the first one for simplicity's sake
            accountToUse = [account objectAtIndex:0];
                if (accountToUse != nil) {
                    //the string to send to twitter
                    
                    NSString *requestToAPI = [NSString stringWithFormat:@"https://api.twitter.com/1.1/search/tweets.json?q=%%40peek&include_entities=true&count=%d", count];
                    //create a request using the social framework apple provides and set account to the one since twitter needs that info with version 1.1
                    SLRequest *slRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:requestToAPI] parameters:nil];
                    [slRequest setAccount:accountToUse];
                    [slRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
                        
                        //dictionary will have 2 arrays, so we want the statuses one
                        twitterFeedArray = [responseDict objectForKey:@"statuses"];
                        
                        //clear array
                        //this part can be improved. we can compare all the texts of this array with the current ones in tabledata and only update the table view with the new rows.
                        //comparison will be done in a similar manner to what is done with the dictionary and defaults
                        //[tableData removeAllObjects];
                        
                        
                        BOOL firstTimeAdding = false;
                        BOOL dontAddTheText = false;
                        BOOL addedAnyRow = false;
                        NSInteger tableDataInitialCount = 0;
                        
                        tableDataInitialCount = [tableData count];
                        
                        //initialize the table data
                        NSMutableArray *tableDataToAdd = [[NSMutableArray alloc] initWithArray:twitterFeedArray];
                        if (([tableData count] == 0)) {
                            firstTimeAdding = true;
                            tableData = [[NSMutableArray alloc] initWithArray:twitterFeedArray];
                        } else {
                            for (int j = 0; j < [tableDataToAdd count]; j++) {
                                NSDictionary *aDictionary = [tableDataToAdd objectAtIndex:j];
                                NSString *text = [aDictionary objectForKey:@"text"];
                                dontAddTheText = false;
                                for (int i = 0; i < [tableData count]; i++) {
                                    NSDictionary *tweet = [tableData objectAtIndex:i];
                                    NSString *text2 = [tweet objectForKey:@"text"];
                                    if ([text isEqualToString:text2]) {
                                        dontAddTheText = true;
                                    }
                                }
                                if (dontAddTheText == false) {
                                    addedAnyRow = true;
                                    [tableData addObject:aDictionary];
                                }
                            }
                        }
                        
                        
                        
                        //get the dictionary from nsuserdefaults that contains all the deleted tweets
                        NSDictionary *retrievedDictionary = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"DicKey"];
                        
                        if (retrievedDictionary != nil) {
                            //if there are objects in the dictionary, then we have to compare them to make sure it's not loaded since user previously deleted them
                            NSMutableDictionary *mutableRetrievedDictionary = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DicKey"] mutableCopy];
                            NSArray *keys=[mutableRetrievedDictionary allKeys];
                            for (NSString *string in keys) {
                                for (int i = 0; i < [tableData count]; i++) {
                                    NSDictionary *tweet = [tableData objectAtIndex:i];
                                    NSString *text = [tweet objectForKey:@"text"];
                                    NSDictionary *userNameDict = [tweet objectForKey:@"user"];
                                    NSString *usernameButtonString = [userNameDict objectForKey:@"screen_name"];
                                    
                                    text = [usernameButtonString stringByAppendingString:text];
                                    if ([text isEqualToString:string]) {
                                        [tableData removeObjectAtIndex:i];
                                    }
                                }
                            }
                        }
                        
                        colorsArrayCount = 0;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            //make sure we reload data on the main thread so that it reloads for sure
                            colorsArrayCount = 0;
                            if (firstTimeAdding == true) {
                                [weakSelf.tableView reloadData];
                            }
                            
                            if ((addedAnyRow == true) && (addToFront == false)) {
                                NSLog(@"Here1");
                                NSInteger statingIndex = tableDataInitialCount;
                                NSInteger noOfObjects = [tableData count] - tableDataInitialCount;
                                NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
                                
                                for (NSInteger index = statingIndex; index < statingIndex+noOfObjects; index++) {
                                    
                                    //[_objects addObject:]; // add the object from getFeed method.
                                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
                                    [indexPaths addObject:indexPath];
                                    
                                }
                                
                                [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];
                            } /*else if ((addedAnyRow == true) && (addToFront == true)) {
                                NSLog(@"Here2");
                                [tableData removeAllObjects];
                                tableData = [[NSMutableArray alloc] initWithArray:twitterFeedArray];
                                
                                if (retrievedDictionary != nil) {
                                    //if there are objects in the dictionary, then we have to compare them to make sure it's not loaded since user previously deleted them
                                    NSMutableDictionary *mutableRetrievedDictionary = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DicKey"] mutableCopy];
                                    NSArray *keys=[mutableRetrievedDictionary allKeys];
                                    for (NSString *string in keys) {
                                        for (int i = 0; i < [tableData count]; i++) {
                                            NSDictionary *tweet = [tableData objectAtIndex:i];
                                            NSString *text = [tweet objectForKey:@"text"];
                                            NSDictionary *userNameDict = [tweet objectForKey:@"user"];
                                            NSString *usernameButtonString = [userNameDict objectForKey:@"screen_name"];
                               
                                            text = [usernameButtonString stringByAppendingString:text];
                                            if ([text isEqualToString:string]) {
                                                [tableData removeObjectAtIndex:i];
                                            }
                                        }
                                    }
                                }
                                
                                [weakSelf.tableView reloadData];
                            } */ else {
                                [tableData removeAllObjects];
                                tableData = [[NSMutableArray alloc] initWithArray:twitterFeedArray];
                                
                                if (retrievedDictionary != nil) {
                                    //if there are objects in the dictionary, then we have to compare them to make sure it's not loaded since user previously deleted them
                                    NSMutableDictionary *mutableRetrievedDictionary = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DicKey"] mutableCopy];
                                    NSArray *keys=[mutableRetrievedDictionary allKeys];
                                    for (NSString *string in keys) {
                                        for (int i = 0; i < [tableData count]; i++) {
                                            NSDictionary *tweet = [tableData objectAtIndex:i];
                                            NSString *text = [tweet objectForKey:@"text"];
                                            NSDictionary *userNameDict = [tweet objectForKey:@"user"];
                                            NSString *usernameButtonString = [userNameDict objectForKey:@"screen_name"];
                                            
                                            text = [usernameButtonString stringByAppendingString:text];
                                            if ([text isEqualToString:string]) {
                                                [tableData removeObjectAtIndex:i];
                                            }
                                        }
                                    }
                                }
                                
                                [weakSelf.tableView reloadData];
                            }
                            
                            //stop the infinitescrollingview and the pulltorefresh
                            [weakSelf.tableView endUpdates];
                            
                            [weakSelf.tableView.infiniteScrollingView stopAnimating];

                            [weakSelf.tableView.pullToRefreshView stopAnimating];
                        });
                        
                        

                        
                    }];
                }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[[UIAlertView alloc]initWithTitle:@"Oh oh!"
                                           message:@"You have not linked a twitter account. Please go into iPhone settings and add a twitter account and then try again."
                                          delegate:nil
                                 cancelButtonTitle:@"Thanks!"
                                 otherButtonTitles: nil] show];

            });
        }
        }
    }];
    
    

}

- (void)retweetMessage:(NSString *)message
{
    //create the request as before and run alerts on the main thread. use the account from the global variable accountToUse that was saved before
    NSString *retweetString = [NSString stringWithFormat:@"https://api.twitter.com/1/statuses/retweet/%@.json", message];
    NSURL *retweetURL = [NSURL URLWithString:retweetString];
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:retweetURL parameters:nil];
    request.account = accountToUse;
    
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if (responseData)
        {
            //NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
            //NSLog(@"%@", responseDict);
            
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
            NSLog(@"Error: %@", [error localizedDescription]);
        }
    }];
}



- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = 0.0;
    
    NSDictionary *tweet = [tableData objectAtIndex:indexPath.row];
    NSString *text = [tweet objectForKey:@"text"];
    height = [text sizeWithFont:[UIFont systemFontOfSize:14] constrainedToSize:CGSizeMake(240,300) lineBreakMode:NSLineBreakByWordWrapping].height;
    //if there is a photo, then we need to add a boost
    int boost = 0;
    
    NSDictionary *media = [tweet objectForKey:@"entities"];
    
    NSArray *realMedia = [media objectForKey:@"media"];
    
    if (realMedia == NULL) {
    } else {
        boost = 125;
    }
    
    //74 is just some extra space for the username
    return height + 74 + boost;
}

- (void) getProfileImageForURLString:(NSString *)urlString andImageView:(UIImageView *)imageView;
{
    //this method is not used in this class since I use the SDWebImage library to handle inserting images and caching it.
    NSURL *url = [NSURL URLWithString:urlString];
    NSData *data = [NSData dataWithContentsOfURL:url];
    UIImage *image = [UIImage imageWithData:data];
    CGSize size = CGSizeMake(25, 25);
    UIImage *realImage = [self resizeImage:image newSize:size];
    [imageView setImage:realImage];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    
    //parse the tableData into separate dictionaries so we can access Tweet Text, Tweet ID, photo, and username
    NSDictionary *tweet = [tableData objectAtIndex:indexPath.row];
    NSDictionary *media = [tweet objectForKey:@"entities"];

    NSArray *realMedia = [media objectForKey:@"media"];
    NSString *mediaURL;
    
    NSDictionary *userNameDict = [tweet objectForKey:@"user"];

    
    if (realMedia == NULL) {
        didAddMediaURL = false;
    } else {
        NSDictionary *mediaURLDictionary = [realMedia objectAtIndex:0];
        mediaURL = [mediaURLDictionary objectForKey:@"media_url_https"];
        didAddMediaURL = true;
    }
    
    if (cell == nil) {
        //initiialize the cell created above called "Cell"
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        
        //this part is needed to make sure the text wrapps around
        [[cell textLabel] setNumberOfLines:0]; // unlimited number of lines
        [[cell textLabel] setLineBreakMode:NSLineBreakByWordWrapping];
        [[cell textLabel] setFont:[UIFont systemFontOfSize: 14.0]];
        
        //create image views only once since table view reuses, so we don't want to be drawing new ones every time
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(25, 5, 30, 30)];
        imageView.backgroundColor = [UIColor clearColor];
        imageView.tag = (indexPath.row+200);
        [cell.contentView addSubview:imageView];
        
        CGRect frame = [tableView rectForRowAtIndexPath:indexPath];

        
        UIImageView *imageViewBigPhoto = [[UIImageView alloc] initWithFrame:CGRectMake((cell.contentView.bounds.size.width / 2) - 50, frame.size.height - 100, 100, 100)];
        imageViewBigPhoto.backgroundColor = [UIColor clearColor];
        imageViewBigPhoto.tag = (indexPath.row + 1200);
        [cell.contentView addSubview:imageViewBigPhoto];
        
        UILabel *usernameButton = [[UILabel alloc] initWithFrame:CGRectZero];
        usernameButton.font = [UIFont systemFontOfSize:14];
        [usernameButton setTextColor:[UIColor blueColor]];
        usernameButton.tag = (indexPath.row + 2200);
        
        [cell.contentView addSubview:usernameButton];

    }
    

    if(indexPath.row == 0){
        cell.contentView.backgroundColor = [UIColor yellowColor];
    }
    if(indexPath.row == 1){
        cell.contentView.backgroundColor = [UIColor colorWithRed:(189/255.0) green:(162/255.0) blue:(212/255.0) alpha:1];
    }
    if (indexPath.row == 2) {
        cell.contentView.backgroundColor = [UIColor colorWithRed:(171/255.0) green:(214/255.0) blue:(149/255.0) alpha:1];
    }
    if (indexPath.row == 3) {
        cell.contentView.backgroundColor = [UIColor cyanColor];
    }
    
   
  
    NSString *tweetID = [tweet objectForKey:@"id"];
    cell.textLabel.text = [tweet objectForKey:@"text"];
    
    //configure the text that shows the username name. in a full feature app, you can click this button and load the person's profile
    UILabel *userNameButton = (UILabel*)[cell.contentView viewWithTag:(indexPath.row + 2200)];
    NSString *usernameButtonString = [userNameDict objectForKey:@"screen_name"];
    CGSize stringsize = [usernameButtonString sizeWithFont:[UIFont systemFontOfSize:14]];
    [userNameButton setText:usernameButtonString];
    [userNameButton setFrame:CGRectMake(60, 5, stringsize.width, stringsize.height)];
    
    NSString *profilePictureURL = [userNameDict objectForKey:@"profile_image_url_https"];
    
    UIImageView *newImageView = (UIImageView*)[cell.contentView viewWithTag:(indexPath.row+200)];
    //implement the SDWebImage for caching
    [newImageView sd_setImageWithURL:[NSURL URLWithString:profilePictureURL] placeholderImage:[UIImage imageNamed:@"placeholder.png"]];
    

    UIImageView *newImageViewBigPhoto = (UIImageView*)[cell.contentView viewWithTag:(indexPath.row+1200)];
    [newImageViewBigPhoto sd_setImageWithURL:[NSURL URLWithString:mediaURL] placeholderImage:[UIImage imageNamed:@"placedholder2.png"]];
    
    
    CGRect frame = [tableView rectForRowAtIndexPath:indexPath];

    //add the retweet button and do its targets
    RetweetButtonApp  *retweetButton = [[RetweetButtonApp alloc] initWithFrame:CGRectMake(frame.size.width - 90, 5, 90, stringsize.height)];
    retweetButton.backgroundColor = [UIColor clearColor];
    [retweetButton setTitle:@"Retweet" forState:UIControlStateNormal];
    [retweetButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    retweetButton.tag = (indexPath.row + 2400);
    [retweetButton addTarget:self action:@selector(retweetButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    retweetButton.userData = tweetID;
    [cell.contentView addSubview:retweetButton];
    
    
    return cell;
 
}

-(void)retweetButtonClicked:(id)sender{
    RetweetButtonApp *button = (RetweetButtonApp*)sender;
    UIView *view = button.superview; //Cell contentView
    UITableViewCell *cell = (UITableViewCell *)view.superview;
    NSLog(@"%@ %@", cell.textLabel.text, button.userData); //Cell Text
    
    [self retweetMessage:button.userData];
}


//resizeImage method I got from internet, but I didn't use it here
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

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSString *cellText = cell.textLabel.text;
    
    //for paging
    //get the correct view and send all the data (text, username, images across so we don't have to reload them again)
    UIStoryboard*  sb = [UIStoryboard storyboardWithName:@"Main"
                                                  bundle:nil];
    DetailViewController* detailViewController = [sb instantiateViewControllerWithIdentifier:@"DetailViewController"];
    
   // DetailViewController *detailViewController = [[DetailViewController alloc] initWithNibName:@"DetailViewController" bundle:nil];
    detailViewController.captionTextString = cellText;
    
    NSDictionary *tweet = [tableData objectAtIndex:indexPath.row];
    
    NSDictionary *userNameDict = [tweet objectForKey:@"user"];
    NSString *usernameButtonString = [userNameDict objectForKey:@"screen_name"];
    detailViewController.userNameString = usernameButtonString;
    
    NSString *tweetID = [tweet objectForKey:@"id"];
    detailViewController.tweetString = tweetID;
    
    NSDictionary *media = [tweet objectForKey:@"entities"];
    
    NSArray *realMedia = [media objectForKey:@"media"];
    NSString *mediaURL;
    
    if (realMedia == NULL) {
    } else {
        NSDictionary *mediaURLDictionary = [realMedia objectAtIndex:0];
        mediaURL = [mediaURLDictionary objectForKey:@"media_url_https"];
    }
    
    detailViewController.photoURL = mediaURL;
    detailViewController.accountToUse = accountToUse;
    
    [self.navigationController pushViewController:detailViewController animated:YES];

}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
