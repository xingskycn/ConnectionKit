//
//  PhotoGridIndexPlugIn.m
//  PhotoGridIndex
//
//  Copyright 2004-2011 Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "PhotoGridIndexPlugIn.h"


@implementation PhotoGridIndexPlugIn

- (void)awakeFromNew
{
    [super awakeFromNew];
    self.enableMaxItems = NO;
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    // Extra CSS to handle caption functionality new to 2.0
    [context addCSSString:@".photogrid-index-bottom { clear:left; }"];
    
    // parse template
    [super writeHTML:context];
}

- (void)writePlaceholderHTML:(id <SVPlugInContext>)context;
{
    if ( self.indexedCollection )
    {
        // write thumbnail of example image
        [context startElement:@"div" attributes:[NSDictionary dictionaryWithObject:@"gridItem" 
                                                                            forKey:@"class"]];
        [context writeThumbnailOfPage:nil
                                width:128
                               height:128
                           attributes:nil
                              options:(SVThumbnailScaleAspectFit | SVThumbnailLinkToPage)];
        [context startElement:@"h3"];
        [context startAnchorElementWithPage:[context page]];
        [context startElement:@"span" attributes:[NSDictionary dictionaryWithObject:@"in" 
                                                                             forKey:@"class"]];
        [context writeText:NSLocalizedString(@"Example Photo", 
                                             "placeholder image name")];
        [context endElement]; // </a>
        [context endElement]; // </span>
        [context endElement]; // </h3>
        [context endElement]; // </div>

        // thumbnail <DIV> with text content that instructs you to drag in images
        [context startElement:@"div" attributes:[NSDictionary dictionaryWithObject:@"gridItem" 
                                                                            forKey:@"class"]];
        [context writeText:NSLocalizedString(@"Drag photos directly to this grid to build the album.",
                                             "add photos to grid")];
        [context endElement]; // </div>                
    }
    else
    {
        [context startElement:@"div" attributes:[NSDictionary dictionaryWithObject:@"gridItem" 
                                                                            forKey:@"class"]];
        [context writeText:NSLocalizedString(@"Please specify the collection to use for the album.",
                                             "set photo collection")];
        [context endElement];
    }
}


/*
<img[[idClass entity:Page property:aPage.thumbnail flags:"anchor" id:aPage.identifier]]
src="[[mediainfo info:path media:aPage.thumbnail sizeToFit:thumbnailImageSize]]"
alt="[[=&aPage.title]]"
width="[[mediainfo info:width media:aPage.thumbnail sizeToFit:thumbnailImageSize]]"
height="[[mediainfo info:height media:aPage.thumbnail sizeToFit:thumbnailImageSize]]" />
 */

- (void)writeThumbnailImageOfIteratedPage
{
    id<SVPlugInContext> context = [self currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    
    [context writeThumbnailOfPage:iteratedPage
                            width:128
                           height:128
                       attributes:nil
                          options:(SVThumbnailScaleAspectFit | SVThumbnailLinkToPage)];
}

@end
