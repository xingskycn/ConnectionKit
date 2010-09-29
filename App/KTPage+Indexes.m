//
//  KTPage+Indexes.m
//  Marvel
//
//  Created by Mike on 30/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTPage+Paths.h"

#import "SVArticle.h"
#import "SVArchivePage.h"
#import "SVHTMLContext.h"
#import "SVHTMLTemplateParser.h"
#import "SVTextAttachment.h"

#import "NSArray+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSCharacterSet+Karelia.h"
#import "NSError+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSSortDescriptor+Karelia.h"
#import "NSString+KTExtensions.h"
#import "KSURLUtilities.h"
#import "NSXMLElement+Karelia.h"


@interface KTPage (PathsPrivate)
- (NSString *)pathRelativeToSiteWithCollectionPathStyle:(KTCollectionPathStyle)collectionPathStyle;
@end


#pragma mark -


@implementation KTPage (Indexes)

#pragma mark Basic Properties

// what becomes of these? Case: 89588
- (KTCollectionSummaryType)collectionSummaryType { return [self wrappedIntegerForKey:@"collectionSummaryType"]; }

- (void)setCollectionSummaryType:(KTCollectionSummaryType)type
{
	[self setWrappedInteger:type forKey:@"collectionSummaryType"];
}

#pragma mark Index

- (BOOL)pagesInIndexAllowComments
{
	BOOL result = NO;
	
	if ([self isCollection])
	{
		NSArray *pages = [self pagesInIndex];
		for ( KTPage *page in pages )
		{
			if ( [page wrappedBoolForKey:@"allowComments"] )
			{
				result = YES;
				break;
			}
		}
	}
	
	return result;
}

#pragma mark -
#pragma mark Navigation Arrows

/*	All those pages which are suitable for linking to with navigation arrows.
 */
- (NSArray *)navigablePages;
{
	// How to sort the pages? Generally this is the same as usual, but for chronological collections, the arrows need to always be the same. #32341
    SVCollectionSortOrder sorting = [[self collectionSortOrder] integerValue];
    BOOL ascending = [self isSortedChronologically] ? NO : [[self collectionSortAscending] boolValue];
    
    NSArray *result = [self childrenWithSorting:sorting ascending:ascending inIndex:YES];
	return result;
}

- (KTPage *)previousPage
{
    SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
    
	NSArray *siblings = [[self parentPage] childPages];
    [context addDependencyOnObject:self keyPath:@"parentPage.childPages"];
    
	unsigned index = [siblings indexOfObjectIdenticalTo:self];
	while (index > 0)
	{
        index--;
		
        KTPage *result = [siblings objectAtIndex:index];
        [context addDependencyOnObject:result keyPath:@"shouldIncludeInIndexes"];
        
        if ([result shouldIncludeInIndexes]) return result;
	}
	
	return nil;
}

- (KTPage *)nextPage
{
	SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
    
	NSArray *siblings = [[self parentPage] childPages];
	[context addDependencyOnObject:self keyPath:@"parentPage.childPages"];
    
	unsigned index = [siblings indexOfObjectIdenticalTo:self] + 1;
	while (index < [siblings count])
	{
		KTPage *result = [siblings objectAtIndex:index];
        [context addDependencyOnObject:result keyPath:@"shouldIncludeInIndexes"];

        if ([result shouldIncludeInIndexes]) return result;
        
        index++;
	}
	
	return nil;
}

#pragma mark RSS Feed

@dynamic collectionSyndicate;
- (BOOL)validateCollectionSyndicate:(NSNumber **)syndicate error:(NSError **)outError;
{
    // Only collections are allowed to syndicate
    BOOL result = (![*syndicate boolValue] || [self isCollection]);
    if (!result && outError)
    {
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                        code:NSValidationNumberTooLargeError
                        localizedDescription:@"Only collections can be syndicated"];
    }
    
    return result;
}

@dynamic collectionMaxSyndicatedPagesCount;
- (BOOL)validateCollectionMaxIndexItems:(NSNumber **)max error:(NSError **)outError;
{
    // mandatory for collections, nil otherwise
    if ([self isCollection])
    {
        if (!*max)
        {
            if (outError) *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                                          code:NSValidationMissingMandatoryPropertyError
                                          localizedDescription:@"collectionMaxSyndicatedPagesCount is non-optional for collections"];
            
            return NO;
        }
    }
    else
    {
        if (*max)
        {
            if (outError) *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                                          code:NSValidationNumberTooLargeError
                                          localizedDescription:@"Only collections can specify a number of articles to syndicate"];
            return NO;
        }
    }
    
    return YES;
}

@dynamic collectionTruncateFeedItems;
@dynamic collectionMaxFeedItemLength;

@dynamic RSSFileName;

- (NSURL *)feedURL
{
	NSURL *result = nil;
	
	if ([[self collectionSyndicate] boolValue])
	{
		result = [NSURL ks_URLWithPath:[self RSSFileName] relativeToURL:[self URL] isDirectory:NO];
	}
	
	return result;
}
+ (NSString *)keyPathsForValuesAffectingFeedURL;
{
    return [NSSet setWithObjects:@"collectionSyndicate", @"URL", @"RSSFileName", nil];
}

/*  The pages that will go into the RSS feed. Sort chronologically and apply the limit
 */
- (NSArray *)pagesInRSSFeed
{
	NSArray *result = [self childrenWithSorting:SVCollectionSortByDateCreated ascending:NO inIndex:YES];
    
    NSUInteger max = [[self collectionMaxSyndicatedPagesCount] unsignedIntegerValue];
    if ([result count] > max)
    {
        result = [result subarrayToIndex:max];
    }
    
	return result;
}

/*!	Return the HTML.
 */
- (NSString *)RSSFeed;
{
	NSMutableString *result = [NSMutableString string];
    SVHTMLContext *context = [[SVHTMLContext alloc] initWithOutputWriter:result];
    
    [self writeRSSFeed:context];
	[context release];
		
	// We won't do any "stringByEscapingCharactersOutOfEncoding" since we are using UTF8, which means everything is OK, and we
	// don't want to introduce any entities into the XML anyhow.
	
	OBPOSTCONDITION(result);
    return result;
}

- (void)writeRSSFeed:(SVHTMLContext *)context;
{
    // Find the template
	NSString *template = [[NSBundle mainBundle] templateRSSAsString];
	OBASSERT(template);
	
	
    // Generate XML
	SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithTemplate:template component:self];
	
    [parser parseIntoHTMLContext:context];
    [parser release];
}

- (NSSize)RSSFeedThumbnailsSize { return NSMakeSize(128.0, 128.0); }

- (NSArray *)feedEnclosures
{
    NSSet *attachments = [[self article] attachments];
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[attachments count]];
    
    for (SVTextAttachment *anAttachment in attachments)
    {
        id <SVEnclosure> enclosure = [[anAttachment graphic] enclosure];
        if (enclosure) [result addObject:enclosure];
    }
    
	return result;
}

#pragma mark Standard Summary

- (void)writeSummary:(SVHTMLContext *)context;
{
    NSAttributedString *html = [[self article] attributedHTMLString];
    NSMutableAttributedString *summary = [html mutableCopy];
    NSMutableArray *attachments = [[NSMutableArray alloc] initWithCapacity:
                                   [[[self article] attachments] count]];
    
    
    // Strip out large attachments
    NSUInteger location = 0;
    
    while (location < summary.length)
    {
        NSRange effectiveRange;
        SVTextAttachment *attachment = [summary attribute:@"SVAttachment"
                                                  atIndex:location
                                           effectiveRange:&effectiveRange];
        
        if (attachment && [[attachment causesWrap] boolValue])
        {
            [attachments addObject:[attachment graphic]];
            [summary deleteCharactersInRange:effectiveRange];
        }
        else
        {
            location = location + effectiveRange.length;
        }
    }
    
    
    // Are we left with only whitespace? If so, fallback to graphic captions
    NSString *text = [[summary string] stringByConvertingHTMLToPlainText];
    if ([text isWhitespace])
    {
        [summary release]; summary = nil;
        
        for (SVGraphic *aGraphic in attachments)
        {
            if ([aGraphic showsCaption])
            {
                summary = [[[aGraphic caption] attributedHTMLString] retain];
                break;
            }
        }
    }
    
        
    // Write it
    [context writeAttributedHTMLString:summary];
    
    [attachments release];
    [summary release];
}


/*!	Here is the main information about how summaryHTML works.

A page is asked for its summaryHTML to populate its parent's general index page, if it exists.
Exactly how that summary is generated is a bit complex.

First off -- if this is a collection (with some children), there is a behavior flag which is
consulted.  Depending on this flag, the summary may be generated to do one of the following:
* Show the summaryHTML of the most recently added item in that collection.  This is useful
in the case of a link to a blog, where the latest article is a teaser.
* Show a small list of titles of recent articles, limited to N articles.  Sort of a mini-index.
* Show an alphabetical list of items.  (Limited to N articles, like Yahoo subcategories?)

If the collection is instead marked "automatic", or the page is not a collection, then the
summaryHTML is generated as follows.

We use valueForUndefinedKey to cause the page to check, in this order:
* its delegate, for a summaryHTML method
* the page's plugin properties
* the element --which will also check first its delegate than its plugin properties

The idea is that you give subclasses a chance to "override" the method to calculate the value,
or look it up if not found.

A few known places where a delegate overrides summaryHTML to provide us with something:
* Image element delegate returns a photo's caption.
* Rich text element delegate returns the entire rich text article (possibly truncated)
if no override value has been set in the properties dictionary.

The general idea is that summaryHTML is automatically derived as much as possible, but the site
creator has the ability to override that and replace it with some other text.

For setting Summary HTML, the idea is that if the page has its own summary HTML value of non-nil,
meaning that the summary has been "split off", then go ahead and set that property.  Otherwise,
ask its original source to set its original value.

QUESTION: WHAT IF SUMMARY IS DERIVED -- WHAT DOES THAT MEAN TO SET?

*/
/*
- (NSString *)summaryHTML
{
	NSString *result = [self summaryHTMLAllowingTruncation:YES];	
	return result;
}

- (NSString *)summaryHTMLAllowingTruncation:(BOOL)inAllowTruncation
{
	USESDEPRECATEDAPI;
	
	NSString *result = @"";
	KTCollectionSummaryType summaryType;
	if ([self hasChildren]
		&&
		KTSummarizeAutomatic != (summaryType = [self integerForKey:@"collectionSummaryType"]))
	{
		NSArray *descriptors;
		if (summaryType == KTSummarizeAlphabeticalList)
		{
			descriptors = gAlphaSort;
		}
		else
		{
			descriptors = (KTTimestampModificationDate == [[self master] integerForKey:@"timestampType"])
			   ? gModNewTop
			   : gCreationNewTop;
		}
		
		[self lockPSCAndMOC];
		NSArray *sortedChildren = [[[self childrenInIndexSet] allObjects] sortedArrayUsingDescriptors:descriptors];
		[self unlockPSCAndMOC];
		
		if (summaryType == KTSummarizeMostRecent)
		{
			if ([sortedChildren count])
			{
				KTPage *topPage = [sortedChildren objectAtIndex:0];
				result = [topPage summaryHTML];
			}
		}
		else if (summaryType == KTSummarizeFirstItem)
		{
			if ([sortedChildren count])
			{
				KTPage *topPage = [sortedChildren lastObject];
				result = [topPage summaryHTML];
			}
		}
		else
		{
			int maxForSummary = [[NSUserDefaults standardUserDefaults] integerForKey:@"MaximumTitlesInCollectionSummary"];
			NSMutableString *s = [NSMutableString stringWithString:@"<ul>\n"];
			NSEnumerator *theEnum = [sortedChildren objectEnumerator];
			KTPage *page;
			int count = 1;

			while (nil != (page = [theEnum nextObject]) )
			{
				[s appendFormat:@"\t<li>%@</li>\n", [page wrappedValueForKey:@"titleHTML"]];
				if (count++ >= maxForSummary)
				{
					break;
				}
			}
			[s appendFormat:@"</ul>"];
			result = s;
		}
	}
	
	return result;
}
*/

- (NSString *)preTruncationSummaryHTML
{
	// TODO: Handle collections
	
	NSString *result = @"";
	
	NSString *summaryHTMLKeyPath = [self summaryHTMLKeyPath];
	if (summaryHTMLKeyPath)
	{
		result = [self valueForKeyPath:summaryHTMLKeyPath];
	}

	return result;
}

- (NSString *)summaryHTMLWithTruncation:(unsigned)truncation
{
	NSString *result = [self preTruncationSummaryHTML];
	
	
	// Truncate to the specified no. characters.
	// This is tricky because we want to truncate to number of visible characters, not HTML characters.
	// Also, this might leave us in the middle of an open tag.  
// TODO: figure out how to truncate gracefully
	if (truncation && [result length] > truncation)
	{
//						result = [NSString stringWithFormat:@"%@%C", 
//							[result substringToIndex:truncateCharacters], 0x2026];
		
		// NOTE: I STILL NEED TO TRUNCATE BY CHARACTERS, NOT BY MARKUP
		// I could do it by making a doc of the whole thing, then scan through the XML doc for text, and 
		// stop when I reach the Nth character.  Then dump the rest of the tree,
		// then output the tree and XSLT remove the HTML, HEAD, BODY tags.
		
		// Now, tidy this HTML
		NSError *theError = NULL;
		NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithXMLString:result options:NSXMLDocumentTidyHTML error:&theError] autorelease];
		NSArray *theNodes = [xmlDoc nodesForXPath:@"/html/body" error:&theError];
		NSXMLNode *node = [theNodes lastObject];
		NSXMLElement *theBody = [theNodes lastObject];
		int accumulator = 0;
		while (nil != node)
		{
			if ([node kind] == NSXMLTextKind)
			{
				NSString *thisString = [node stringValue];	// renders &amp; etc.
				int thisLength = [thisString length];
				unsigned int newAccumulator = accumulator + thisLength;
				if (newAccumulator >= truncation)	// will we need to prune?
				{
					int truncateIndex = truncation - accumulator;
					// Now back up just a few more characters if we can hit whitespace.
					NSRange whereWhitespace = [thisString rangeOfCharacterFromSet:[NSCharacterSet fullWhitespaceAndNewlineCharacterSet]
																		  options:NSBackwardsSearch
																			range:NSMakeRange(0,truncateIndex)];
					
#define REASONABLE_WORD_LENGTH 15
					/*
					 Might be NSNotFound which means we want to truncate the whole thing?
					 Perhaps if it's small.  If we have japanese with no spaces, I don't
					 want to lose anything like that.  Maybe if the length > N and we
					 couldn't truncate, don't trucate at all. 
					 */
					if (NSNotFound == whereWhitespace.location)
					{
						if (truncateIndex < REASONABLE_WORD_LENGTH)		truncateIndex = 0;	// remove this segment entirely
						// else, just truncate at character; this might be no-space text.
					}
					else
					{
						// Would we truncate a whole bunch extra (meaning a long long word or few/no spaces text?
						if (truncateIndex - whereWhitespace.location < REASONABLE_WORD_LENGTH)
						{
							// only reset the truncate index if we won't chop off TOO much.
							truncateIndex = whereWhitespace.location;
						}
					}
					NSString *truncd = [thisString substringToIndex:truncateIndex];
					// Trucate, plus add on an ellipses
					NSString *newString = [NSString stringWithFormat:@"%@%C", 
						truncd, 0x2026];

					[node setStringValue:newString];	// re-escapes &amp; etc.
					
					break;		// we will now remove everything after "node"
				}
				accumulator = newAccumulator;
			}
			node = [node nextNode];
		}
		
		[theBody removeAllNodesAfter:(NSXMLElement *)node];

		result = [theBody XMLStringWithOptions:NSXMLDocumentTidyXML];
		// DON'T use NSXMLNodePreserveAll -- it converted " to ' and ' to &apos;  !!!
							
		NSRange rangeOfBodyStart = [result rangeOfString:@"<body>" options:0];
		NSRange rangeOfBodyEnd   = [result rangeOfString:@"</body>" options:NSBackwardsSearch];
		if (NSNotFound != rangeOfBodyStart.location && NSNotFound != rangeOfBodyEnd.location)
		{
			int sPos = NSMaxRange(rangeOfBodyStart);
			int len  = rangeOfBodyEnd.location - sPos;
			result = [result substringWithRange:NSMakeRange(sPos,len)];
		}
	}
	
	
	return result;
}

/*	The key path to generate a summary from. If the delegate does not implement this we return nil
 */
- (NSString *)summaryHTMLKeyPath
{
	NSString *result = @"titleHTMLString";
	
	return result;
}

/*	Whether the page's summary should be editable. Generally this is true, but in some cases (e.g. Raw HTML page)
 *	we want a non-editable summary.
 *	The default is NO to be on the safe side.
 */
- (BOOL)summaryHTMLIsEditable
{
	BOOL result = NO;
	
	return result;
}

#pragma mark custom summary

/*	Returns nil if there is no custom summary
 */
- (NSString *)customSummaryHTML { return [self wrappedValueForKey:@"customSummaryHTML"]; }

- (void)setCustomSummaryHTML:(NSString *)HTML { [self setWrappedValue:HTML forKey:@"customSummaryHTML"]; }

#pragma mark Archives

@dynamic collectionGenerateArchives;

- (NSArray *)archivePages;
{
    NSMutableArray *result = [NSMutableArray array];
    NSMutableArray *currentPages = [NSMutableArray array];
    NSDateComponents *currentMonth = nil;
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSArray *pages = [self childrenWithSorting:SVCollectionSortByDateCreated ascending:NO inIndex:YES];
    for (SVSiteItem *anItem in pages)
    {
        // If this page is into a different archive period, generate an archive for the pages processed so far
        NSDateComponents *components = [calendar components:(kCFCalendarUnitYear | kCFCalendarUnitMonth)
                                                   fromDate:[anItem creationDate]];
        
        if (![components isEqual:currentMonth] && currentMonth)
        {
            SVArchivePage *archivePage = [[SVArchivePage alloc] initWithPages:currentPages];
            [currentPages removeAllObjects];
            
            [result addObject:archivePage];
            [archivePage release];
        }
        
        [currentPages addObject:anItem];
        currentMonth = components;
    }
    
    
    // Create an archive page for the remaining pages
    if ([currentPages count])
    {
        SVArchivePage *archivePage = [[SVArchivePage alloc] initWithPages:currentPages];
        [currentPages removeAllObjects];
        
        [result addObject:archivePage];
        [archivePage release];
    }
    
    
    return result;
}

@end
