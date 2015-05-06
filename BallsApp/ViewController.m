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

NSString* const ios_url = @"http://www.ballsapp.com/ios/";
NSString* const ballsapp_scheme = @"ballsapp";
NSString* const get_contacts_action_type = @"GetContacts";
NSString* const send_invite_action_type = @"SendInvite";
NSString* const send_invites_action_type = @"SendInvites";
NSString* const contact_permission_error = @"This app requires access to your contacts to function properly. Please visit to the \"Privacy\" section in the iPhone Settings app.";

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [_web_view setDelegate:self];
    NSURL* url = [NSURL URLWithString:ios_url];
    NSURLRequest* request_obj = [NSURLRequest requestWithURL:url];
    [_web_view loadRequest:request_obj];
    invite_queue = [NSMutableArray array];
}

- (void)listPeopleInAddressBook:(ABAddressBookRef)addressBook
{
    NSArray* allPeople = CFBridgingRelease(ABAddressBookCopyArrayOfAllPeople(addressBook));
    NSInteger numberOfPeople = [allPeople count];
    for(NSInteger i = 0; i < numberOfPeople; i++) {
        ABRecordRef person = (__bridge ABRecordRef)allPeople[i];
        ABMultiValueRef phoneNumbers = ABRecordCopyValue(person, kABPersonPhoneProperty);
        CFIndex numberOfPhoneNumbers = ABMultiValueGetCount(phoneNumbers);
        if(numberOfPhoneNumbers > 0) {
            NSString* firstName = CFBridgingRelease(ABRecordCopyValue(person, kABPersonFirstNameProperty));
            NSString* lastName  = CFBridgingRelease(ABRecordCopyValue(person, kABPersonLastNameProperty));
            NSArray* names = [[NSArray alloc] initWithObjects:firstName, lastName, nil];
            NSString* name = [names componentsJoinedByString:@" "];
            NSString* phoneNumber = CFBridgingRelease(ABMultiValueCopyValueAtIndex(phoneNumbers, 0));
            NSString* request_string = [NSString stringWithFormat:@"add_contact('%@', '%@')", name, phoneNumber];
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

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result {
    [self dismissViewControllerAnimated:YES completion:nil];
    switch (result) {
        case MessageComposeResultCancelled:
        case MessageComposeResultSent:
        {
            if([invite_queue count] > 0) {
                [self sendInvites];
            }
            break;
        }
        case MessageComposeResultFailed:
        {
            UIAlertView* warningAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Failed to send SMS!" delegate:nil                              cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [warningAlert show];
            break;
        }
        default:
            break;
    }
}

- (void)sendInvite:(NSString *)number
        league_name:(NSString *)league_name
        invite_path:(NSString *)invite_path {
    if(![MFMessageComposeViewController canSendText]) {
        UIAlertView* warningAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Your device doesn't support SMS!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [warningAlert show];
        return;
    }
    NSArray* recipients = @[number];
    NSString* message =
        [NSString stringWithFormat:@"Hey! Come play beer pong with me in my league \"%@\" in BallsApp! Join here: %@", league_name, invite_path];
    MFMessageComposeViewController* messageController = [[MFMessageComposeViewController alloc] init];
    messageController.messageComposeDelegate = self;
    [messageController setRecipients:recipients];
    [messageController setBody:message];
    [self presentViewController:messageController animated:YES completion:nil];
}

- (void)sendInvites {
    if([invite_queue count] > 0) {
        NSDictionary* json_object = [invite_queue lastObject];
        [self sendInvite:[json_object objectForKey:@"number"] league_name:[json_object objectForKey:@"league_name"] invite_path: [json_object objectForKey:@"invite_path"]];
        [invite_queue removeLastObject];
    }
}

- (BOOL)webView:(UIWebView *)webView
        shouldStartLoadWithRequest:(NSURLRequest *)request
        navigationType:(UIWebViewNavigationType)navigationType {
    if(![request.URL.scheme isEqualToString:ballsapp_scheme]) {
        return YES;
    }
    NSString* action_type = request.URL.host;
    if([action_type isEqualToString:get_contacts_action_type]) {
        [self getContacts];
    } else if([action_type isEqualToString:send_invite_action_type]) {
        NSString* invite_json = [request.URL.fragment stringByReplacingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
        NSError* json_error;
        NSData* object_data = [invite_json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary* json_object = [NSJSONSerialization JSONObjectWithData:object_data
                                                                    options:NSJSONReadingMutableContainers
                                                                      error:&json_error];
        if(json_error) {
            UIAlertView *warningAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Failed to communicate with the server." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [warningAlert show];
        }
        [self sendInvite:[json_object objectForKey:@"number"] league_name:[json_object objectForKey:@"league_name"] invite_path: [json_object objectForKey:@"invite_path"]];
    } else if([action_type isEqualToString:send_invites_action_type]) {
        NSString* json_string = [request.URL.fragment stringByReplacingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
        NSError* json_error;
        NSData* object_data = [json_string dataUsingEncoding:NSUTF8StringEncoding];
        invite_queue = [NSJSONSerialization JSONObjectWithData:object_data
                                                       options:NSJSONReadingMutableContainers
                                                         error:&json_error];
        if(json_error) {
            UIAlertView *warningAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Failed to communicate with the server." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [warningAlert show];
            return NO;
        }
        [self sendInvites];
    }
    return NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [_web_view reload];
}

@end
