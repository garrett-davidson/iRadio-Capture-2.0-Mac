//
//  MainWindowController.m
//  iRadio Capture 2.0
//
//  Created by Garrett Davidson on 8/6/13.
//  Copyright (c) 2013 Garrett Davidson. All rights reserved.
//

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
    NSString *picturePath;
    NSString *tempSongPath;
    NSTask *assniffer;
    NSString *tempDirectory;
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

    [self clearTMP];


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
    NSArray *tmpContents = [manager contentsOfDirectoryAtPath:path error:nil];
    for (NSString *file in tmpContents)
    {
        if (![file isEqualToString:@"songsTMP"])
            [manager removeItemAtPath:[NSString stringWithFormat:@"%@%@", path, file] error:nil];
        else
        {
            NSString *subPath = [NSString stringWithFormat:@"%@%@", path, file];
            NSArray *tmpSubContents = [manager contentsOfDirectoryAtPath:subPath error:nil];
            for (NSString *subFile in tmpSubContents)
            {
                [manager removeItemAtPath:[NSString stringWithFormat:@"%@/%@", subPath, subFile] error:nil];
            }
        }
    }
}

//./assniffer /Users/garrettdavidson/Downloads/assniffer02/source/assniffer/test -d 1 -mimetype audio

- (IBAction)startStop:(id)sender {
    started = !started;

    
    if (!stream)
    {
        CFStringRef downloadsPath;
        NSString *downloadsPathString = [NSString stringWithFormat:@"%@/Downloads", NSHomeDirectory()];
        NSLog(@"%@", downloadsPathString);
        downloadsPath = (__bridge CFStringRef)(downloadsPathString);
        
        CFStringRef assnifferOutputDirectory;
        NSString *assnifferOutputDirecotryString = [NSString stringWithFormat:@"%@/songsTMP", tempDirectory];
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

        else
        {
            //look for the song
            [mainWindowInstance findSong:path];
        }

        
    }
}

- (void) findPicture:(NSString *)downloadsPath
{
    if (!foundPicture)
    {

        //FSEventStream doesn't tell you what file caused the event to fire
        //So I have to do all this just to find the picture
        
        NSFileManager *manager = [NSFileManager defaultManager];
        NSURL *downloadsURL = [NSURL fileURLWithPath:downloadsPath isDirectory:YES];
        NSArray *fileArray = [manager contentsOfDirectoryAtURL:downloadsURL includingPropertiesForKeys:[NSArray arrayWithObject:NSURLCreationDateKey] options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsSubdirectoryDescendants error:nil];

        NSDate *newestDate = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
        NSURL *newestFile;
        for (NSURL *filePath in fileArray)
        {
            if ([filePath.lastPathComponent rangeOfString:@".jpg"].location != NSNotFound)
            {
                NSDate *creationDate = nil;
                [filePath getResourceValue:&creationDate forKey:NSURLCreationDateKey error:nil];

                if ([newestDate laterDate:creationDate] == creationDate)
                {
                    if ([[filePath lastPathComponent] componentsSeparatedByString:@"_"].count == 4)
                    {
                        newestDate = creationDate;
                        newestFile = filePath;
                    }
                }
            }
        }

        NSLog(@"Newest file: %@", newestFile);


        NSString *newestFileString = [newestFile path];

        //if the newest picture has changed from the last time this event fired
        if (![newestFile.lastPathComponent isEqualToString:picturePath.lastPathComponent])
        {
            foundPicture = true;

            NSString *newPath = [NSString stringWithFormat:@"%@%@", tempDirectory, [newestFile lastPathComponent]];
            [manager moveItemAtPath:newestFileString toPath:newPath error:nil];
            picturePath = newPath;
            NSLog(@"%@", picturePath);
            
            //Update UI
            self.statusLabel.stringValue = @"Found Picture";
            NSArray *tags = [picturePath.lastPathComponent componentsSeparatedByString:@"_"];
            NSString *labelInfo = [NSString stringWithFormat:@"%@ by %@ on %@", tags[0], tags[1], tags[2]];
            self.songInfoLabel.stringValue = labelInfo;
            NSData *imageData = [NSData dataWithContentsOfFile:picturePath];
            self.albumArtImageWell.image = [[NSImage alloc] initWithData:imageData];

            if (foundSong) [NSThread detachNewThreadSelector:@selector(captureSong) toTarget:self withObject:nil];
        }

    }
}

-(void) findSong:(NSString *) assnifferOutputDirectory
{
    if (!foundSong)
    {
        NSFileManager *manager = [NSFileManager defaultManager];
        NSArray *subs = [manager subpathsOfDirectoryAtPath:assnifferOutputDirectory error:nil];
        if ([subs lastObject])
        {
            tempSongPath = [NSString stringWithFormat:@"%@%@", assnifferOutputDirectory, [subs lastObject]];
            NSLog(@"song path: %@", tempSongPath);
            foundSong = true;
            
            if (foundSong) [NSThread detachNewThreadSelector:@selector(captureSong) toTarget:self withObject:nil];
        }
    }
}

- (void)captureSong
{
    //make sure the song is finished transferring
    NSFileManager *manager = [NSFileManager defaultManager];
    NSDictionary *dict = [manager attributesOfItemAtPath:tempSongPath error:nil];

    unsigned long long size = [dict fileSize];
    unsigned long long newSize;
    NSLog(@"Watching file size");
    self.statusLabel.stringValue = @"Buffering";
    while (size != newSize)
    {
        size = newSize;
        sleep(5);
        newSize = [[manager attributesOfItemAtPath:tempSongPath error:nil] fileSize];
    }

    NSArray *tags = [picturePath.lastPathComponent componentsSeparatedByString:@"_"];

    //move the song the tmp directory so changing it won't set off the eventStream
    NSString *newPath = [NSString stringWithFormat:@"%@input", tempDirectory];
    NSString *site = tags[3];
    if ([site rangeOfString:@"last"].location != NSNotFound) newPath = [newPath stringByAppendingString:@".mp3"];
    else newPath = [newPath stringByAppendingString:@".m4a"];

    //[manager moveItemAtPath:tempSongPath toPath:newPath error:nil];
    NSURL *originalURL = [NSURL fileURLWithPath:[tempSongPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    tempSongPath = newPath;

    NSLog(@"Capture song now");
#warning uncomment these
    foundSong = false;
    foundPicture = false;

    NSData *imageData = [NSData dataWithContentsOfFile:picturePath];

    AVMutableMetadataItem *songInfo = [AVMutableMetadataItem metadataItem];
    NSDictionary *atts = [[NSDictionary alloc] initWithObjectsAndKeys:tags[0], AVMetadataiTunesMetadataKeySongName, tags[1], AVMetadataiTunesMetadataKeyArtist, tags[2], AVMetadataiTunesMetadataKeyAlbum, imageData, AVMetadataCommonKeyArtwork, nil];
    songInfo.extraAttributes = atts;

    
    NSURL *inputURL = [NSURL fileURLWithPath:[tempSongPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL: inputURL options:nil];

    NSURL *outputURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", tempDirectory, @"output.m4a"] isDirectory:NO];

    
    AVAssetExportSession *session;
    //if ([picturePath.lastPathComponent rangeOfString:@".m4a"].location != NSNotFound)
        session = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetAppleM4A];
    NSArray *metadataArray = metadataFromAssetDictionary(nil, atts, NO, nil, AVMetadataKeySpaceiTunes);
    session.metadata = metadataArray;
    session.outputFileType = AVFileTypeAppleM4A;

    NSFileWrapper *wrapper = [[NSFileWrapper alloc] initWithURL:originalURL options:NSFileWrapperReadingImmediate error:nil];
    [wrapper writeToURL:inputURL options:NSFileWrapperWritingWithNameUpdating originalContentsURL:originalURL error:nil];

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
        }
    }];

}

- (void)exportedSongWithTags:(NSArray *)tags toURL:(NSURL *)outputURL
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"useCustomFolder"])
    {
        //save to folder
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
