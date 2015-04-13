//
//  ViewController.m
//  BallsApp
//
//  Created by Anthony Burzillo on 4/1/15.
//  Copyright (c) 2015 Anthony Burzillo. All rights reserved.
//

#import "ViewController.h"

NSString *const ios_url = @"http://www.ballsapp.com/ios/";

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSURL *url = [NSURL URLWithString:ios_url];
    NSURLRequest *request_obj = [NSURLRequest requestWithURL:url];
    [_webView loadRequest:request_obj];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
