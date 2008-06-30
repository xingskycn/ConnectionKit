//
//  KTPrefsController.m
//  Marvel
//
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

// $Id$

#import "KTPrefsController.h"

#import "KT.h"
#import "KTApplication.h"
#import "KTAppDelegate.h"
#import "KSEmailAddressComboBox.h"
#import "CIImage+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSImage+KTExtensions.h"
#import "NSApplication+Karelia.h"
#import "KSAbstractBugReporter.h"
#import <Sparkle/Sparkle.h>

@interface KTPrefsController ( Private )

- (int)sparkleOption;
- (void)setSparkleOption:(int)aSparkleOption;

@end



@implementation KTPrefsController

#pragma mark Initialization Methods


- (id)init
{
	[KSEmailAddressComboBox setWillAddAnonymousEntry:NO];
	[KSEmailAddressComboBox setWillIncludeNames:NO];
	self = [super initWithWindowNibName:@"Prefs"];
    if (self)
	{
		
    }
    return self;
}


- (void)dealloc
{
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];

	[controller removeObserver:self forKeyPath:@"values.KTPreferredJPEGQuality"];
	[controller removeObserver:self forKeyPath:@"values.KTPrefersPNGFormat"];
	[controller removeObserver:self forKeyPath:@"values.LiveDataFeeds"];

	[self removeObserver:self forKeyPath:@"sparkleOption"];

	[mySampleImage release];
	
	[super dealloc];
}

- (void)updateImageSettingsBlowAway:(BOOL)aBlowAway;
{
	
	// PNG FORMAT OR JPEG QUALITY ... BLOW AWAY IMAGE CACHE WHEN CHANGED.
	
	if (nil == mySampleImage)
	{
		// public domain US government image: http://invasivespecies.nbii.gov/gardening.html
		mySampleImage = [[NSImage imageNamed:@"quality_sample"] retain];
	}
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
	NSUserDefaults *defaults = [controller defaults];
	if ([defaults boolForKey:@"KTPrefersPNGFormat"])
	{
		[oCompressionSample setHidden:YES];
	}
	else
	{
		[oCompressionSample setHidden:NO];
		float quality = [defaults floatForKey:@"KTPreferredJPEGQuality"];
		
		NSData *jpegData = [mySampleImage JPEGRepresentationWithQuality:quality];
		NSImage *newImage = [[[NSImage alloc] initWithData:jpegData] autorelease];
		[newImage normalizeSize];
		[oCompressionSample setImage:newImage];
	}
	
	/// Don't blow away in 1.5, the cache isn't used anyway
	// TODO: remove this code, make sure all prefs work
//	// Blow away caches, but only if the keypath is real -- meaning the value actually changed.
//	if (aBlowAway)
//	{
//		// Blow away the ENTIRE cache, of all documents ever opened.
//		
//		// Note that NSSearchPath.. and NSHomeDirectory return home directory path without resolving
//		// symbolic links so they should match up.
//		
//		NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES);
//		if ( [libraryPaths count] == 1 )
//		{
//			NSString *cachePath = [libraryPaths objectAtIndex:0];
//			cachePath = [cachePath stringByAppendingPathComponent:[NSApplication applicationName]];
//			cachePath = [cachePath stringByAppendingPathComponent:@"Sites"];
//			cachePath = [cachePath stringByAppendingPathExtension:@"noindex"];
//			
//			// Double-check!
//			if (![cachePath hasPrefix:NSHomeDirectory()]
//				|| [cachePath isEqualToString:NSHomeDirectory()]
//				|| [cachePath isEqualToString:@"/"]
//				|| NSNotFound == [cachePath rangeOfString:@"Library/Caches"].location)
//			{
//				NSLog(@"Not removing image cache path from %@", cachePath);
//			}
//			else
//			{
//				NSFileManager *fm = [NSFileManager defaultManager];
//				[fm removeFileAtPath:cachePath handler:nil];
//				NSLog(@"Removed cache files from %@", cachePath);
//			}
//		}
//	}	
}

- (IBAction) emailComboChanged:(id)sender;
{
	[oAddressComboBox saveSelectionToDefaults];
}

// Scale down if it's bigger than 150% of what will show.  That will allow us to drag in approximately sized
// small images for an exact test.

- (IBAction) updateSampleImage:sender		
{
#define WIDTH 100
#define HEIGHT 75

	[mySampleImage release];
	
	NSImage *newImage = [sender image];
	NSBitmapImageRep *bitmap = [newImage bitmap];
	
	if ( [bitmap pixelsWide] > (1.5 * WIDTH) || [bitmap pixelsHigh] > (1.5 * WIDTH) )
	{
		CIImage *im = [newImage toCIImage];
		// Show the top/center of the image.  This crop & center it.
		im = [im scaleToWidth:WIDTH height:HEIGHT behavior:kCoverRect alignment:NSImageAlignCenter opaqueEdges:YES];
		
		newImage = [im toNSImageBitmap];
	}
	mySampleImage = [newImage retain];
	[self updateImageSettingsBlowAway:NO];
}

- (void)windowDidLoad
{
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
	NSUserDefaults *defaults = [controller defaults];

	[controller addObserver:self forKeyPath:@"values.KTPreferredJPEGQuality" options:(NSKeyValueObservingOptionNew) context:nil];
	[controller addObserver:self forKeyPath:@"values.KTPrefersPNGFormat" options:(NSKeyValueObservingOptionNew) context:nil];
	[controller addObserver:self forKeyPath:@"values.LiveDataFeeds" options:(NSKeyValueObservingOptionNew) context:nil];


	// setup sparkeOption
	if ([defaults boolForKey:@"contactHomeBase"])
	{
		if ([[[NSBundle mainBundle] objectForInfoDictionaryKey:SUFeedURLKey]
			 isEqualToString:[defaults objectForKey:SUFeedURLKey]])
		{
			[self setSparkleOption:kSparkleRelease];
		}
		else
		{
			[self setSparkleOption:kSparkleBeta];	// SOME kind of special feed, overridden.
		}
	}
	else
	{
		[self setSparkleOption:kSparkleNone];
	}

	// Now start observing
	
	[self addObserver:self forKeyPath:@"sparkleOption" options:(NSKeyValueObservingOptionNew) context:nil];

	
	[oObjectController setContent:self];	

	[oCompressionSample setEditable:YES];
	[oCompressionSample setImageFrameStyle:NSImageFrameGrayBezel];	// NSImageFrameGrayBezel
	[oCompressionSample setAction:@selector(updateSampleImage:)];
	[oCompressionSample setTarget:self];
	[oCompressionSample setImageScaling:NSScaleNone];	// if we scaled, it would be all wonky
	
	// Fix the transparent background
//	[oHaloscanTextView setDrawsBackground:NO];
//	NSScrollView *scrollView = [oHaloscanTextView enclosingScrollView];
//	[scrollView setDrawsBackground:NO];
//	[[scrollView contentView] setCopiesOnScroll:NO];

	[[self window] center];
	
	// Kick things off, initialize image stuff
	[self updateImageSettingsBlowAway:NO];
}

- (void)observeValueForKeyPath:(NSString *)aKeyPath
                      ofObject:(id)anObject
                        change:(NSDictionary *)aChange
                       context:(void *)aContext
{
//	NSLog(@"observeValueForKeyPath: %@", aKeyPath);
//	NSLog(@"                object: %@", anObject);
//	NSLog(@"                change: %@", [aChange description]);

	if ([aKeyPath isEqualToString:@"values.LiveDataFeeds"])
	{
		// FIXME: Need a replacement for this
//		[[NSNotificationCenter defaultCenter] postNotificationName:kKTWebViewMayNeedRefreshingNotification
//															object:nil];
	}
	else if ([aKeyPath isEqualToString:@"sparkleOption"])
	{
		int sparkleOption = [self sparkleOption];
		
		NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
		NSUserDefaults *defaults = [controller defaults];
		NSString *SUFeedURL = [[NSBundle mainBundle] objectForInfoDictionaryKey:SUFeedURLKey];	// default feed.
		
		switch (sparkleOption)
		{
			case kSparkleNone:
				[defaults setBool:NO forKey:@"contactHomeBase"];
				[[[NSApp delegate] sparkleUpdater] scheduleCheckWithInterval:0.0];	// cancel it now
				break;
			case kSparkleRelease:
				[defaults setBool:YES forKey:@"contactHomeBase"];
				[defaults removeObjectForKey:SUFeedURLKey];	// revert to regular
				break;
			case kSparkleBeta:
				[defaults setBool:YES forKey:@"contactHomeBase"];
				NSString *newString = [SUFeedURL stringByAppendingString:@"&type=beta"];
				[defaults setObject:newString forKey:SUFeedURLKey];	// revert to regular
				break;
		}
		[defaults synchronize];
	}
	else
	{
		[self updateImageSettingsBlowAway:(nil != aKeyPath)];
	}
}

- (IBAction) windowHelp:(id)sender
{
	[[NSApp delegate] showHelpPage:@"Preferences"];	// HELPSTRING
}

- (IBAction) checkForUpdates:(id)sender
{
	[[[NSApp delegate] sparkleUpdater] checkForUpdates:sender];
}


- (int)sparkleOption
{
    return mySparkleOption;
}

- (void)setSparkleOption:(int)aSparkleOption
{
    mySparkleOption = aSparkleOption;
}

@end
