//
//  SVMediaPlugIn.h
//  Sandvox
//
//  Created by Mike on 24/09/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPlugIn.h"
#import "SVEnclosure.h"

#import "SVMediaGraphic.h"


@interface SVMediaPlugIn : SVPlugIn <SVEnclosure>

#pragma mark Source
- (SVMediaRecord *)media;
- (NSURL *)externalSourceURL;
- (void)didSetSource;
+ (NSArray *)allowedFileTypes;

- (SVMediaRecord *)posterFrame;
- (BOOL)validatePosterFrame:(SVMediaRecord *)posterFrame;


#pragma mark Publishing
- (BOOL)validateTypeToPublish:(NSString *)type;

- (CGSize)originalSize;

- (BOOL)shouldWriteHTMLInline;
- (BOOL)canWriteHTMLInline;   // NO for most graphics. Images and Raw HTML return YES
- (id <SVMedia>)thumbnailMedia;			// usually just media; might be poster frame of movie
- (id)imageRepresentation;
- (NSString *)imageRepresentationType;


@end


@interface SVMediaPlugIn (Inherited)
@property(nonatomic, readonly) SVMediaGraphic *container;
@end
