//
//  ViewController.m
//  BallsApp
//
//  Created by Anthony Burzillo on 4/1/15.
//  Copyright (c) 2015 Anthony Burzillo. All rights reserved.
//

#import "ViewController.h"

#import <AddressBook/AddressBook.h>
#import <MessageUI/MessageUI.h>

NSString *const ios_url = @"http://www.ballsapp.com/ios/";
NSString *const ballsapp_scheme = @"ballsapp";
NSString *const get_contacts_action_type = @"GetContacts";
NSString *const send_invite_action_type = @"SendInvite";
NSString *const contact_permission_error = @"This app requires access to your contacts to function properly. Please visit to the \"Privacy\" section in the iPhone Settings app.";

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [_web_view setDelegate:self];
    NSURL *url = [NSURL URLWithString:ios_url];
    NSURLRequest *request_obj = [NSURLRequest requestWithURL:url];
    [_web_view loadRequest:request_obj];
}

- (void)listPeopleInAddressBook:(ABAddressBookRef)addressBook
{
    NSArray *allPeople = CFBridgingRelease(ABAddressBookCopyArrayOfAllPeople(addressBook));
    NSInteger numberOfPeople = [allPeople count];
    for(NSInteger i = 0; i < numberOfPeople; i++) {
        ABRecordRef person = (__bridge ABRecordRef)allPeople[i];
        ABMultiValueRef phoneNumbers = ABRecordCopyValue(person, kABPersonPhoneProperty);
        CFIndex numberOfPhoneNumbers = ABMultiValueGetCount(phoneNumbers);
        if(numberOfPhoneNumbers > 0) {
            NSString *firstName = CFBridgingRelease(ABRecordCopyValue(person, kABPersonFirstNameProperty));
            NSString *lastName  = CFBridgingRelease(ABRecordCopyValue(person, kABPersonLastNameProperty));
            NSArray *names = [[NSArray alloc] initWithObjects:firstName, lastName, nil];
            NSString *name = [names componentsJoinedByString:@" "];
            NSString *phoneNumber = CFBridgingRelease(ABMultiValueCopyValueAtIndex(phoneNumbers, 0));
            NSString *request_string = [NSString stringWithFormat:@"add_contact('%@', '%@')", name, phoneNumber];
            [_web_view performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:request_string waitUntilDone:YES];
        }
        CFRelease(phoneNumbers);
    }
}

- (void)getContacts {
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    if (status == kABAuthorizationStatusDenied || status == kABAuthorizationStatusRestricted) {
        [[[UIAlertView alloc] initWithTitle:nil message:contact_permission_error delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        return;
    }
    CFErrorRef error = NULL;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error);
    if(!addressBook) {
        NSLog(@"ABAddressBookCreateWithOptions error: %@", CFBridgingRelease(error));
        return;
    }
    ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
        if(error) {
            NSLog(@"ABAddressBookRequestAccessWithCompletion error: %@", CFBridgingRelease(error));
        }
        if (granted) {
            [self listPeopleInAddressBook:addressBook];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[[UIAlertView alloc] initWithTitle:nil message:contact_permission_error delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            });
        }
        CFRelease(addressBook);
    });
}

- (BOOL)webView:(UIWebView *)webView
        shouldStartLoadWithRequest:(NSURLRequest *)request
        navigationType:(UIWebViewNavigationType)navigationType {
    if(![request.URL.scheme isEqualToString:ballsapp_scheme]) {
        return YES;
    }
    NSString *action_type = request.URL.host;
    if([action_type isEqualToString:get_contacts_action_type]) {
        [self getContacts];
    } else if([action_type isEqualToString:send_invite_action_type]) {
        NSLog(@"SendInvite");
    }
    return NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
