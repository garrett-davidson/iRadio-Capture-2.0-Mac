//
//  MainWindowController.h
//  iRadio Capture 2.0
//
//  Created by Garrett Davidson on 8/6/13.
//  Copyright (c) 2013 Garrett Davidson. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MainWindowController : NSWindowController

- (IBAction)startStop:(id)sender;
+ (MainWindowController *)sharedManager;


@end