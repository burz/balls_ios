//
//  ViewController.h
//  BallsApp
//
//  Created by Anthony Burzillo on 4/1/15.
//  Copyright (c) 2015 Anthony Burzillo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>

@interface ViewController : UIViewController <UIWebViewDelegate, MFMessageComposeViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *web_view;

@end

