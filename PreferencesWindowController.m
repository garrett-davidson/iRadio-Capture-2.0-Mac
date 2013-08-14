//
//  PreferencesWindowController.m
//  iRadio Capture 2.0
//
//  Created by Garrett Davidson on 8/11/13.
//  Copyright (c) 2013 Garrett Davidson.
//

//This file is part of iRadio Capture 2.0.
//
//iRadio Capture 2.0 is free software: you can redistribute it and/or modify
//it under the terms of the GNU General Public License as published by
//the Free Software Foundation, either version 3 of the License, or
//(at your option) any later version.
//
//iRadio Capture 2.0 is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//GNU General Public License for more details.
//
//You should have received a copy of the GNU General Public License
//along with iRadio Capture 2.0.  If not, see <http://www.gnu.org/licenses/>.

#import "PreferencesWindowController.h"

@interface PreferencesWindowController ()
- (IBAction)toggleAddToPlaylist:(id)sender;
- (IBAction)toggleSaveType:(id)sender;
@property (weak) IBOutlet NSButton *iTunesCheckbox;
@property (weak) IBOutlet NSButton *playlistCheckbox;
@property (weak) IBOutlet NSTextField *playlistField;
@property (weak) IBOutlet NSButton *customFolderCheckbox;
@property (weak) IBOutlet NSTextField *customFolderField;
@property (weak) IBOutlet NSButton *overwriteLowerBitrateCheckbox;
@property (weak) IBOutlet NSButton *chooseCustomFolderButton;
- (IBAction)saveChanges:(id)sender;
- (IBAction)cancelChanges:(id)sender;


@end

@implementation PreferencesWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.

        [super windowDidLoad];

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
    return self;
}

- (void) windowDidLoad
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    self.iTunesCheckbox.state = ![defaults boolForKey:@"useCustomFolder"];
    self.playlistCheckbox.state = [defaults boolForKey:@"addToiTunesPlaylist"];
    self.playlistField.stringValue = [defaults objectForKey:@"playlistName"];
    self.customFolderField.stringValue = [defaults objectForKey:@"customFolder"];
    self.overwriteLowerBitrateCheckbox.state = [defaults boolForKey:@"overwriteLowerBitrate"];

    //automatically enables/disables controls
    [self toggleSaveType:nil];
}


- (IBAction)toggleAddToPlaylist:(id)sender {
    [self.playlistField setEnabled:self.playlistCheckbox.state];
}

- (IBAction)toggleSaveType:(id)sender {

    if (sender == self.customFolderCheckbox) self.iTunesCheckbox.state = !self.customFolderCheckbox.state;

    bool saveToiTunesState = (bool)self.iTunesCheckbox.state;
    [self.playlistCheckbox setEnabled:saveToiTunesState];
    [self.playlistField setEnabled:saveToiTunesState & self.playlistCheckbox.state];

    [self.customFolderField setEnabled:!saveToiTunesState];
    [self.customFolderCheckbox setNeedsDisplay];
    [self.chooseCustomFolderButton setEnabled:!saveToiTunesState];
    self.customFolderCheckbox.state = !saveToiTunesState;

    //Only until I figure out how to check the bitrate of songs without iTunes
    [self.overwriteLowerBitrateCheckbox setEnabled:self.iTunesCheckbox.state];
}
- (IBAction)saveChanges:(id)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:self.customFolderCheckbox.state forKey:@"useCustomFolder"];
    [defaults setBool:self.playlistCheckbox.state forKey:@"addToiTunesPlaylist"];
    [defaults setObject:self.playlistField.stringValue forKey:@"playlistName"];
    [defaults setBool:self.overwriteLowerBitrateCheckbox.state forKey:@"overwriteLowerBitrate"];
    [defaults setObject:self.customFolderField.stringValue forKey:@"customFolder"];
    if (self.customFolderCheckbox.state)
    {
        NSFileManager *manager = [NSFileManager defaultManager];
        BOOL positive = true;
        if (![manager fileExistsAtPath:self.customFolderField.stringValue isDirectory:&positive]) [manager createDirectoryAtPath:self.customFolderField.stringValue withIntermediateDirectories:YES attributes:nil error:nil];
    }
    [self close];
    
}

- (IBAction)cancelChanges:(id)sender {
    self.shouldCloseDocument = YES;
    [self.window close];
    [self close];
    [self.window performClose:self];
}
@end
