//
//  SVGraphicContainer.h
//  Sandvox
//
//  Created by Mike on 23/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVHTMLContext;
@protocol SVGraphic;


@protocol SVGraphicContainer <NSObject>
- (void)write:(SVHTMLContext *)context graphic:(id <SVGraphic>)graphic;
@end