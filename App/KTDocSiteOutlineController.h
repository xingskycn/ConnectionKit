//
//  KTDocSiteOutlineController.h
//  Marvel
//
//  Created by Terrence Talbot on 1/2/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTPage, KTDocument, KTDocWindowController;


@interface KTDocSiteOutlineController : NSObjectController
{
	IBOutlet NSOutlineView			*siteOutline;
	
@private
	
	KTDocWindowController	*myWindowController;
	
	NSMutableSet			*myPages;
	NSManagedObjectContext	*myMOC;
	
	NSIndexSet	*mySelectedIndexes;
	NSSet		*mySelectedPages;
	NSArrayController	*myTempSelectionController;
	
	NSImage				*myCachedFavicon;
	NSMutableDictionary	*myCachedPluginIcons;
	NSMutableDictionary	*myCachedCustomPageIcons;
	
	NSMutableArray		*myCustomIconGenerationQueue;
	KTPage				*myGeneratingCustomIcon;
}

- (NSOutlineView *)siteOutline;
- (void)siteOutlineDidLoad;

- (KTDocWindowController *)windowController;
- (void)setWindowController:(KTDocWindowController *)controller;
- (KTDocument *)document;

- (NSManagedObjectContext *)managedObjectContext;
- (void)setManagedObjectContext:(NSManagedObjectContext *)context;

- (void)reloadSiteOutline;
- (void)reloadPage:(KTPage *)anItem reloadChildren:(BOOL)aFlag;

// FIXME: is this the right object to implement this?
- (NSAttributedString *)attributedStringForDisplayOfItem:(id)anItem;

@end


@interface KTDocSiteOutlineController (Icons)
- (NSImage *)iconForPage:(KTPage *)page;

- (void)invalidateIconCaches;
- (void)setCachedFavicon:(NSImage *)icon;

@end


@interface KTDocSiteOutlineController (Selection)

- (NSIndexSet *)selectedIndexes;
- (void)setSelectedIndexes:(NSIndexSet *)indexes;

- (NSSet *)selectedPages;	// Generated on-demand, can be slow
- (void)setSelectedPages:(NSSet *)selectedPages;
- (KTPage *)selectedPage;	// Always fast!

@end