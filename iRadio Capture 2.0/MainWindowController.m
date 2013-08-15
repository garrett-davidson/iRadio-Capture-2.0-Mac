//
//  MainWindowController.m
//  iRadio Capture 2.0
//
//  Created by Garrett Davidson on 8/6/13.
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


#import "MainWindowController.h"
#import <AVFoundation/AVFoundation.h>
#import "iTunes.h"
#import "PreferencesWindowController.h"

@interface MainWindowController ()
{
    FSEventStreamRef stream;
    bool foundPicture;
    bool foundSong;
    bool started;
    bool previousSongDidNotFinish;
    bool taggingInProgress;
    NSString *picturePath;
    NSString *tempSongPath;
    NSTask *assniffer;
    NSString *tempDirectory;
    NSDate *newestPictureDate;
}
@property (weak) IBOutlet NSButton *startButton;
@property (weak) IBOutlet NSMenuItem *startMenuItem;
@property (weak) IBOutlet NSTextField *songInfoLabel;
@property (weak) IBOutlet NSImageView *albumArtImageWell;
@property (weak) IBOutlet NSTextField *statusLabel;

- (IBAction)showPreferences:(id)sender;

@end

static MainWindowController *mainWindowInstance = nil;

@implementation MainWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }

    mainWindowInstance = self;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults objectForKey:@"NIC"]) [defaults setObject:@"1" forKey:@"NIC"];
    if (![defaults boolForKey:@"useCustomFolder"]) [defaults setObject:NO forKey:@"useCustomFolder"];
    if (![defaults boolForKey:@"addToiTunesPlaylist"]) [defaults setBool:YES forKey:@"addToiTunesPlaylist"];
    if (![defaults objectForKey:@"playlistName"]) [defaults setObject:@"iRadio Capture 2.0" forKey:@"playlistName"];
    if (![defaults boolForKey:@"overwriteLowerBitrate"]) [defaults setBool:YES forKey:@"overwriteLowerBitrate"];
    if (![defaults boolForKey:@"customFolder"]) [defaults setObject:[NSString stringWithFormat:@"%@/Music/iRadio Capture 2.0", NSHomeDirectory()] forKey:@"customFolder"];

    tempDirectory = [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"iRadio_Capture/"];

    //Yes I know I did this wrong...
    //Deal with it
    NSApplication *app = [NSApplication sharedApplication];
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(applicationWillTerminate:)
     name:NSApplicationWillTerminateNotification object:app];

    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

-(void) clearTMP
{
    //Clean out the tmp directory
    //this prevents tagging songs left over from previous runs
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *path = tempDirectory;

    BOOL positive = true;
    if (![manager fileExistsAtPath:path isDirectory:&positive]) [manager createDirectoryAtPath:path withIntermediateDirectories:FALSE attributes:nil error:nil];
    if (![manager fileExistsAtPath:[path stringByAppendingString:@"songsTMP"] isDirectory:&positive]) [manager createDirectoryAtPath:[path stringByAppendingString:@"songsTMP"] withIntermediateDirectories:FALSE attributes:nil error:nil];
    NSArray *tmpContents = [manager contentsOfDirectoryAtURL:[NSURL fileURLWithPath:path] includingPropertiesForKeys:[NSArray arrayWithObject:NSURLCreationDateKey] options:0 error:nil];
    for (NSURL *file in tmpContents)
    {
        NSDate *creationDate = nil;
        [file getResourceValue:&creationDate forKey:NSURLCreationDateKey error:nil];

        if ([creationDate laterDate:newestPictureDate] == newestPictureDate)
        {

            if (![file.lastPathComponent isEqualToString:@"songsTMP"])
                [manager removeItemAtURL:file error:nil];
            else
            {
                NSArray *tmpSubContents = [manager contentsOfDirectoryAtURL:file includingPropertiesForKeys:nil options:0 error:nil];
                for (NSURL *subFile in tmpSubContents)
                {
                    [subFile getResourceValue:&creationDate forKey:NSURLCreationDateKey error:nil];
                    if ([creationDate laterDate:newestPictureDate] == newestPictureDate) [manager removeItemAtURL:subFile error:nil];
                }
            }
        }

        else if ([file.lastPathComponent isEqualToString:@"output.m4a"])
        {
            [manager removeItemAtURL:file error:nil];
        }
    }
    tempSongPath = nil;
    picturePath = nil;
    taggingInProgress = false;
}

//./assniffer /Users/garrettdavidson/Downloads/assniffer02/source/assniffer/test -d 1 -mimetype audio

- (IBAction)startStop:(id)sender {
    started = !started;

    newestPictureDate = [NSDate dateWithTimeIntervalSinceNow:0];
    [self clearTMP];
    
    if (!stream)
    {
        
        CFStringRef downloadsPath;
        NSString *downloadsPathString = [NSString stringWithFormat:@"%@/Downloads", NSHomeDirectory()];
        NSLog(@"%@", downloadsPathString);
        downloadsPath = (__bridge CFStringRef)(downloadsPathString);
        
        CFStringRef assnifferOutputDirectory;
        NSString *assnifferOutputDirecotryString = [NSString stringWithFormat:@"%@songsTMP", tempDirectory];
        NSLog(@"%@", assnifferOutputDirecotryString);
        assnifferOutputDirectory = (__bridge CFStringRef)(assnifferOutputDirecotryString);

        CFStringRef paths[] = {downloadsPath, assnifferOutputDirectory};

        CFArrayRef pathsToWath = CFArrayCreate(NULL, (const void **)paths, 2, NULL);

        

        stream = FSEventStreamCreate(NULL, &foundSomething, NULL, pathsToWath, kFSEventStreamEventIdSinceNow, 3, kFSEventStreamEventFlagItemCreated);

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        
    }

    if (started)
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *NIC = [defaults objectForKey:@"NIC"];
        self.startButton.title = @"Stop";
        self.startMenuItem.title = @"Stop";
        FSEventStreamStart(stream);
        NSString *path = [[NSBundle mainBundle] pathForResource:@"assniffer" ofType:@""];
        NSLog(@"%@", path);
        NSString *assnifferOutputDirecotryString = [NSString stringWithFormat:@"%@songsTMP", tempDirectory];
        NSArray *args = [NSArray arrayWithObjects:assnifferOutputDirecotryString, @"-d", NIC, @"-mimetype", @"audio", nil];
        assniffer = [NSTask launchedTaskWithLaunchPath:path arguments:args];
        
    }

    else
    {
        self.startButton.title = @"Start";
        self.startMenuItem.title = @"Stop";
        FSEventStreamStop(stream);
    }
}

void foundSomething (ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[])
{
    char **paths = eventPaths;

    bool songPathhDiscovered = false;
    for (int i = 0; i < numEvents; i++)
    {
        NSString *path = [NSString stringWithUTF8String:paths[i]];

        

        if ([path rangeOfString:@"Download"].location != NSNotFound)
        {
            //Must be here to work properly
            //Don't ask why
            sleep(5);

            //look for the picture
            [mainWindowInstance findPicture:path];
        }

        else if ([path rangeOfString:@"/0/"].location != NSNotFound || [path rangeOfString:@"/access/"].location != NSNotFound)
        {
            //look for the song
            [mainWindowInstance findSong:path];
            songPathhDiscovered = true;
            
        }

        
    }
}

- (void) findPicture:(NSString *)downloadsPath
{

    while (taggingInProgress)
    {
        sleep(5);
    }

    if (!foundPicture | previousSongDidNotFinish)
    {

        //FSEventStream doesn't tell you what file caused the event to fire
        //So I have to do all this just to find the picture
        
        NSFileManager *manager = [NSFileManager defaultManager];
        NSURL *downloadsURL = [NSURL fileURLWithPath:downloadsPath isDirectory:YES];
        NSArray *fileArray = [manager contentsOfDirectoryAtURL:downloadsURL includingPropertiesForKeys:[NSArray arrayWithObject:NSURLCreationDateKey] options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsSubdirectoryDescendants error:nil];

        NSURL *newestFile;
        for (NSURL *filePath in fileArray)
        {
            if ([filePath.lastPathComponent rangeOfString:@".jpg"].location != NSNotFound)
            {
                NSDate *creationDate = nil;
                [filePath getResourceValue:&creationDate forKey:NSURLCreationDateKey error:nil];

                if ([creationDate laterDate:newestPictureDate] == creationDate)
                {
                    if ([[filePath lastPathComponent] componentsSeparatedByString:@"_"].count == 4)
                    {
                        newestPictureDate = creationDate;
                        newestFile = filePath;
                    }
                }
            }
        }

        if (newestFile)
        {

            NSLog(@"Newest file: %@", newestFile);

            //in case the image isn't finished downloading
            //(sometimes chrome decides to take a while to initiate the download)
            while ([newestFile.lastPathComponent rangeOfString:@"crdownload"].location != NSNotFound)
            {
                sleep(5);
            }

            NSString *newestFileString = [newestFile path];

            //if the newest picture has changed from the last time this event fired
            if (![newestFile.lastPathComponent isEqualToString:picturePath.lastPathComponent])
            {
                foundPicture = true;

                NSString *newPath = [NSString stringWithFormat:@"%@%@", tempDirectory, [newestFile lastPathComponent]];
                [manager moveItemAtPath:newestFileString toPath:newPath error:nil];
                if ([manager fileExistsAtPath:picturePath]) [manager removeItemAtPath:picturePath error:nil];
                picturePath = newPath;
                NSLog(@"%@", picturePath);
                
                //Update UI
                NSArray *tags = [picturePath.lastPathComponent componentsSeparatedByString:@"_"];
                NSString *labelInfo = [NSString stringWithFormat:@"%@ by %@ on %@", tags[0], tags[1], tags[2]];
                self.songInfoLabel.stringValue = labelInfo;
                NSData *imageData = [NSData dataWithContentsOfFile:picturePath];
                self.albumArtImageWell.image = [[NSImage alloc] initWithData:imageData];

                if (foundSong) [NSThread detachNewThreadSelector:@selector(captureSong) toTarget:self withObject:nil];
            }
        }

    }
}

-(void) findSong:(NSString *) path
{

    while (taggingInProgress)
    {
        sleep(5);
    }

    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *subs = [manager subpathsAtPath:path];

    if (subs[0])
    {
        NSString *newPath = [NSString stringWithFormat:@"%@%@", path, subs[0]];
        
        if (![tempSongPath isEqualToString:newPath])
        {
            //If everything is going properly
            if (!tempSongPath)
            {
                tempSongPath = newPath;
                self.statusLabel.stringValue = @"Buffering";
                NSLog(@"song path: %@", tempSongPath);
            }

            //Otherwise the last song probably got interrupted (e.g. skipped, lost internet connection, etc.)
            //or the last image didnt download
            else if (tempSongPath && !previousSongDidNotFinish)
            {
                tempSongPath = newPath;
                previousSongDidNotFinish = true;
                self.statusLabel.stringValue = @"Buffering";
                NSLog(@"Song path changed: %@", tempSongPath);
            }

            //if it doesn't meet either of the above, it is an extraneous call
        }


        else
        {
            //NSLog(@"error");
            foundSong = true;
            previousSongDidNotFinish = false;
            if (foundPicture) [NSThread detachNewThreadSelector:@selector(captureSong) toTarget:self withObject:nil];
        }
    }
    

}

- (void)captureSong
{
    taggingInProgress = true;
    //make sure the song is finished transferring
    NSFileManager *manager = [NSFileManager defaultManager];
    NSDictionary *dict = [manager attributesOfItemAtPath:tempSongPath error:nil];

    /*
    NSNumber *size = [NSNumber numberWithLongLong:[dict fileSize]];
    NSNumber *newSize;
    NSLog(@"Watching file size");
    self.statusLabel.stringValue = @"Buffering";
    while (size != newSize)
    {
        size = newSize;
        sleep(5);
        newSize = [NSNumber numberWithLongLong:[[manager attributesOfItemAtPath:tempSongPath error:nil] fileSize]];
    }*/

    NSArray *tags = [picturePath.lastPathComponent componentsSeparatedByString:@"_"];

    //move the song the tmp directory so changing it won't set off the eventStream
    NSString *newPath = [NSString stringWithFormat:@"%@input", tempDirectory];
    NSString *site = tags[3];


    

    //Don't ask me why the preset needs to change
    //it appears to be a bug on Apple's end
    NSString *preset;

    //Last.fm uses .mp3 extension
    if ([site rangeOfString:@"last"].location != NSNotFound)
    {
        newPath = [newPath stringByAppendingString:@".mp3"];
        preset = AVAssetExportPresetAppleM4A;
    }

    //Pandora uses .m4a
    else {
        preset = AVAssetExportPresetPassthrough;
        newPath = [newPath stringByAppendingString:@".m4a"];
    }

    NSURL *originalURL = [NSURL fileURLWithPath:[tempSongPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    tempSongPath = newPath;
    NSURL *inputURL = [NSURL fileURLWithPath:[tempSongPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];

    /*
    NSError *wrapperError;
    NSError *writeError;
    NSFileWrapper *wrapper = [[NSFileWrapper alloc] initWithURL:originalURL options:NSFileWrapperReadingImmediate error:&wrapperError];
    [wrapper writeToURL:inputURL options:NSFileWrapperWritingWithNameUpdating originalContentsURL:originalURL error:&writeError];
    if (wrapperError)
    {
        NSLog(@"Wrapper error: %@", wrapperError);
    }

    if (writeError)
    {
        NSLog(@"Write error: %@", writeError);
    }
    */
   [manager copyItemAtURL:originalURL toURL:inputURL error:nil];

    NSLog(@"Capture song now");
    foundSong = false;
    foundPicture = false;

    NSData *imageData = [NSData dataWithContentsOfFile:picturePath];

    AVMutableMetadataItem *songInfo = [AVMutableMetadataItem metadataItem];
    NSDictionary *atts = [[NSDictionary alloc] initWithObjectsAndKeys:tags[0], AVMetadataiTunesMetadataKeySongName, tags[1], AVMetadataiTunesMetadataKeyArtist, tags[2], AVMetadataiTunesMetadataKeyAlbum, imageData, AVMetadataCommonKeyArtwork, nil];
    songInfo.extraAttributes = atts;

    
    
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL: inputURL options:nil];

    NSURL *outputURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", tempDirectory, @"output.m4a"] isDirectory:NO];

    
    AVAssetExportSession *session;
    //if ([picturePath.lastPathComponent rangeOfString:@".m4a"].location != NSNotFound)

    

    
        session = [AVAssetExportSession exportSessionWithAsset:asset presetName:preset];
    NSArray *metadataArray = metadataFromAssetDictionary(nil, atts, NO, nil, AVMetadataKeySpaceiTunes);
    session.metadata = metadataArray;
    session.outputFileType = AVFileTypeAppleM4A;
    
    

    session.outputURL = outputURL;
    NSLog(@"Asset: %@", asset);
    NSLog(@"Session %@", session);
    [session exportAsynchronouslyWithCompletionHandler:^{


        if (AVAssetExportSessionStatusCompleted == session.status) {
            NSLog(@"Completed");
            [mainWindowInstance exportedSongWithTags:tags toURL:session.outputURL];
        }

        else
        {
            self.statusLabel.stringValue = @"Failed";
            NSString *cause;
            NSString *stringError;
            if (session.error)
            {
                NSLog(@"%@", session.error);
                stringError = [session.error localizedDescription];
                cause = session.error.localizedFailureReason;

            }
            else
                stringError = @"Unknown error";
            NSLog(@"Error: %@ because %@", stringError, cause);
            for (NSString *key in session.error.userInfo.allKeys)
            {
                NSLog(@"%@: %@", key, [session.error.userInfo objectForKey:key]);
            }
            [self clearTMP];
        }
    }];

}

- (void)exportedSongWithTags:(NSArray *)tags toURL:(NSURL *)outputURL
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"useCustomFolder"])
    {
        //save to folder

        NSString *folderPath = [defaults objectForKey:@"customFolder"];

        NSFileManager *manager = [NSFileManager defaultManager];

        //create the directory if it doesn't exist
        //it should have already been created when the folder was set, but just in case
        BOOL positive = YES;
        if (![manager fileExistsAtPath:folderPath isDirectory:&positive]) [manager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];

        NSString *outputPath = [NSString stringWithFormat:@"%@/%@/%@/", folderPath, tags[1], tags[2]];
        //create the output hierarchy if it doesn't exist
        if (![manager fileExistsAtPath:outputPath isDirectory:&positive]) [manager createDirectoryAtPath:outputPath withIntermediateDirectories:YES attributes:nil error:nil];

        BOOL duplicate = false;
        outputPath = [outputPath stringByAppendingFormat:@"%@.m4a", tags[0]];
        if ([manager fileExistsAtPath:outputPath])
        {
            duplicate = true;
        }

        else {
            [manager moveItemAtPath:outputURL.path toPath:outputPath error:nil];
        }

        //Add bitrate check here
    }

    else
    {
        //save to iTunes

        
        iTunesApplication *iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
        SBElementArray *sources = [iTunes sources];
        iTunesSource *librarySource = [sources objectWithName:@"Library"];
        iTunesPlaylist *library = [[librarySource libraryPlaylists] objectWithName:@"Library"];
        iTunesPlaylist *playlist = nil;
        if ([defaults boolForKey:@"addToiTunesPlaylist"])
        {
            NSString *name = [defaults objectForKey:@"playlistName"];
            playlist = [[librarySource userPlaylists] objectWithName:name];

            //create the playlist if it doesn't exist
            if (!playlist)
            {
                NSString *playlistname = [defaults objectForKey:@"playlistName"];
                NSNumber *visible = [NSNumber numberWithBool:TRUE];
                NSDictionary *properties = [NSDictionary dictionaryWithObjectsAndKeys:playlistname, @"name", visible, @"visible", nil];
                iTunesPlaylist *myPlaylist;// = [[[iTunes classForScriptingClass:@"playlist"] alloc] initWithDictionary:propes];
                myPlaylist = [[[iTunes classForScriptingClass:@"playlist"] alloc] initWithProperties:properties];
                [[librarySource userPlaylists] addObject:myPlaylist];
                playlist = myPlaylist;
            }
        }
        SBElementArray *tracks = [library tracks];


        //simple check for duplicates
        iTunesFileTrack *duplicateSong = [[tracks objectWithName:tags[0]] get];

        //duplicate verification (make sure it is a duplicate)
        //some songs have same name but are from different albums, or by different artists, etc.
        bool duplicate = false;
        if (duplicateSong)
        {
            if ([duplicateSong.album isEqualToString:tags[2]])
            {
                if ([duplicateSong.artist isEqualToString:tags[1]])
                {
                    duplicate = true;
                }
            }
        }

        //advanced duplicate checking
        //in case of multiple different songs with same name
        if (duplicateSong && !duplicate)
        {
            for (iTunesFileTrack *track in tracks)
            {
                if ([track.name isEqualToString:tags[0]])
                {
                    if ([track.album isEqualToString:tags[2]])
                    {
                        if ([track.artist isEqualToString:tags[1]])
                        {
                            duplicate = true;
                            break;
                        }
                    }
                }
            }
        }

        bool overWrote = false;
        //overwrite lower bitrate songs
        if (duplicate)
        {
            if ([defaults boolForKey:@"overwriteLowerBitrate"])
            {
                iTunesTrack *testSong;
                if (playlist) testSong = [iTunes add:[NSArray arrayWithObject:outputURL] to:playlist];
                else testSong = [iTunes add:[NSArray arrayWithObject:outputURL] to:library];
                if (testSong.bitRate > duplicateSong.bitRate)
                {
                    //replace old song
                    [duplicateSong delete];
                    overWrote = true;
                    
                 }

                else
                {
                    //remove test
                    [testSong delete];
                }
            }
        }

        else
        {
            if ([defaults boolForKey:@"addToiTunesPlaylist"])
            {
                [iTunes add:[NSArray arrayWithObject:outputURL] to:playlist];
            }
            else [iTunes add:[NSArray arrayWithObject:outputURL] to:playlist];
        }


        //UI must be updated on main thread
        dispatch_async(dispatch_get_main_queue(), ^{

            NSString *status;

            if (overWrote) status = @"Overwrote";

            else if (duplicate) status = @"Duplicate";

            else status = @"Captured";

            self.statusLabel.stringValue = status;

        });
    }


    [self clearTMP];
}

+ (MainWindowController *)sharedManager
{
    if (mainWindowInstance == nil)
    {
        mainWindowInstance = [[super allocWithZone:NULL] init];
    }

    return mainWindowInstance;
}

-(void)applicationWillTerminate:(NSNotification *)notification
{
    if (assniffer) [assniffer terminate];
}

static NSArray * metadataFromAssetDictionary(NSArray *sourceMetadata, NSDictionary *metadataDict, BOOL editingMode, NSString *metadataFormat, NSString *metadataKeySpace)
{
    NSMutableDictionary *mutableMetadataDict = [NSMutableDictionary dictionaryWithDictionary:metadataDict];
    NSMutableArray *newMetadata = [NSMutableArray array];

    for (id key in [mutableMetadataDict keyEnumerator]) {
		id value = [mutableMetadataDict objectForKey:key];
		if (value) {
			AVMutableMetadataItem *newItem = [AVMutableMetadataItem metadataItem];
			[newItem setKey:key];
			if (nil != metadataKeySpace && ![key isEqualToString:AVMetadataCommonKeyArtwork]) {
				[newItem setKeySpace:metadataKeySpace];
			}
			else {
				[newItem setKeySpace:AVMetadataKeySpaceCommon];
			}
			[newItem setLocale:[NSLocale currentLocale]];
			[newItem setValue:value];
			[newItem setExtraAttributes:nil];
			[newMetadata addObject:newItem];
		}
	}
    return newMetadata;
}


- (IBAction)showPreferences:(id)sender {
    PreferencesWindowController *prefsWindowController = [[PreferencesWindowController alloc] initWithWindowNibName:@"PreferencesWindowController"];
    [prefsWindowController loadWindow];
    [prefsWindowController windowDidLoad];
    [prefsWindowController.window makeKeyWindow];
}
@end
