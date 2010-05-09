//
//  SVPageBodyTextDOMController.h
//  Sandvox
//
//  Created by Mike on 28/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVRichTextDOMController.h"

#import "SVPageBody.h"


@interface SVPageBodyTextDOMController : SVRichTextDOMController
{
  @private
    DOMElement  *_dragCaret;
    DOMNode     *_dropNode; // weak ref
}

- (IBAction)insertPagelet:(id)sender;


#pragma mark Drag Caret
- (void)removeDragCaret;
- (void)moveDragCaretToBeforeDOMNode:(DOMNode *)node;


@end
