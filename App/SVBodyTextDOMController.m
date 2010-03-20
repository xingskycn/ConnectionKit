//
//  SVPageletBodyTextAreaController.m
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyTextDOMController.h"
#import "SVParagraphDOMController.h"

#import "KT.h"
#import "SVAttributedHTMLWriter.h"
#import "KTPage.h"
#import "SVGraphic.h"
#import "SVRichText.h"
#import "KTDocument.h"
#import "SVImage.h"
#import "SVLinkManager.h"
#import "SVLink.h"
#import "SVMediaRecord.h"
#import "SVTextAttachment.h"
#import "SVWebContentObjectsController.h"
#import "SVWebEditorView.h"

#import "NSDictionary+Karelia.h"
#import "NSString+Karelia.h"
#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"

#import "KSOrderedManagedObjectControllers.h"


static NSString *sBodyTextObservationContext = @"SVBodyTextObservationContext";


@implementation SVBodyTextDOMController

#pragma mark Init & Dealloc

- (id)init;
{
    // Super
    self = [super init];
    
    
    // Keep an eye on model
    [self addObserver:self forKeyPath:@"representedObject.string" options:0 context:sBodyTextObservationContext];    
    
    // Finish up
    return self;
}

- (void)dealloc
{
    [self removeObserver:self forKeyPath:@"representedObject.string"];
    
    // Release ivars
    
    [super dealloc];
}

#pragma mark DOM Node

- (void)setHTMLElement:(DOMHTMLElement *)element
{
    [super setHTMLElement:element];
    [self setTextHTMLElement:element];
}

#pragma mark Content

- (void)update
{
    [self willUpdate];
    
    [self didUpdate];
}

#pragma mark Insertion

- (void)insertGraphic:(SVGraphic *)graphic;
{
    SVWebEditorView *webEditor = [self webEditor];
    
    
    // Create text attachment for the graphic
    SVTextAttachment *textAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"TextAttachment"
                                                                     inManagedObjectContext:[graphic managedObjectContext]];
    [textAttachment setGraphic:graphic];
    [textAttachment setBody:[self representedObject]];
    
    
    // Create controller for graphic
    SVDOMController *controller = [[[graphic DOMControllerClass] alloc]
                                   initWithHTMLDocument:(DOMHTMLDocument *)[webEditor HTMLDocument]];
    [controller setHTMLContext:[self HTMLContext]];
    [controller setRepresentedObject:graphic];
    
    [self addChildWebEditorItem:controller];
    [controller release];
    
    
    // Generate DOM node
    [webEditor willChange];
    
    DOMRange *selection = [webEditor selectedDOMRange];
    [selection insertNode:[controller HTMLElement]];
    
    [webEditor didChange];
}

- (IBAction)insertPagelet:(id)sender;
{
    // TODO: Make the insertion
}

- (IBAction)insertFile:(id)sender;
{
    NSWindow *window = [[[self HTMLElement] documentView] window];
    NSOpenPanel *panel = [[[window windowController] document] makeChooseDialog];
    
    [panel beginSheetForDirectory:nil file:nil modalForWindow:window modalDelegate:self didEndSelector:@selector(chooseDialogDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)chooseDialogDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    if (returnCode == NSCancelButton) return;
    
    
    NSManagedObjectContext *context = [[self representedObject] managedObjectContext];
    SVMediaRecord *media = [SVMediaRecord mediaWithURL:[sheet URL]
                                            entityName:@"ImageMedia"
                        insertIntoManagedObjectContext:context
                                                 error:NULL];
    
    if (media)
    {
        SVImage *image = [SVImage insertNewImageWithMedia:media];
        [self insertGraphic:image];
    }
    else
    {
        NSBeep();
    }
}

#pragma mark Editability

- (BOOL)isSelectable { return NO; }

- (void)setEditable:(BOOL)editable
{
    // TODO: Embedded graphics must NOT be selectable
    for (SVDOMController *aGraphicController in [self graphicControllers])
    {
        if (![aGraphicController isHTMLElementCreated])
        {
            [aGraphicController loadHTMLElementFromDocument:[[self HTMLElement] ownerDocument]];
        }
        
        [[[aGraphicController HTMLElement] style] setProperty:@"-webkit-user-select"
                                                        value:@"none"
                                                     priority:@"!important"];
    }
    
    // Carry on
    [super setEditable:editable];
}

- (void)webEditorTextDidBeginEditing;
{
    [super webEditorTextDidBeginEditing];
    
    // A bit crude, but we don't want WebKit's usual focus ring
    [[[self HTMLElement] style] setProperty:@"outline" value:@"none" priority:@""];
}

#pragma mark Subcontrollers

- (SVDOMController *)controllerForBodyElement:(SVBodyElement *)element;
{
    SVDOMController * result = nil;
    for (result in [self childWebEditorItems])
    {
        if ([result representedObject] == element) break;
    }
    
    return result;
}

- (SVDOMController *)controllerForDOMNode:(DOMNode *)node;
{
    SVDOMController *result = nil;
    for (result in [self childWebEditorItems])
    {
        if ([node isDescendantOfNode:[result HTMLElement]]) break;
    }
             
    return result;
}

- (NSArray *)graphicControllers;
{
    return [self childWebEditorItems];
}

#pragma mark Updates

@synthesize updating = _isUpdating;

- (void)willUpdate
{
    OBPRECONDITION(!_isUpdating);
    _isUpdating = YES;
}

- (void)didUpdate
{
    OBPRECONDITION(_isUpdating);
    _isUpdating = NO;
}

#pragma mark Editing

- (void)webViewDidChange;
{    
    //  Write the whole out using a special stream
        _isUpdating = YES;
    [SVAttributedHTMLWriter writeContentsOfTextDOMController:self
                                            toAttributedHTML:[self representedObject]];
    _isUpdating = NO;
}

#pragma mark Links

@synthesize selectedLink = _selectedLink;

- (void)webEditorTextDidChangeSelection:(NSNotification *)notification
{
    [super webEditorTextDidChangeSelection:notification];
    
    
    // Does the selection contain a link? If so, make it the selected object
    SVWebEditorView *webEditor = [self webEditor];
    DOMRange *selection = [webEditor selectedDOMRange];
    DOMHTMLAnchorElement *anchorElement = [selection editableAnchorElement];
    
    SVLink *link = nil;
    if (anchorElement)
    {
        // Is it a page link?
        NSString *linkURLString = [anchorElement getAttribute:@"href"]; // -href will give the URL a scheme etc. if there's no base URL
        if ([linkURLString hasPrefix:kKTPageIDDesignator])
        {
            NSString *pageID = [linkURLString substringFromIndex:[kKTPageIDDesignator length]];
            KTPage *target = [KTPage pageWithUniqueID:pageID
                                               inManagedObjectContext:[[self representedObject] managedObjectContext]];
            
            if (target)
            {
                link = [[SVLink alloc] initWithPage:target
                                    openInNewWindow:[[anchorElement target] isEqualToString:@"_blank"]];
            }
        }
        
        // Not a page link? Fallback to regular link
        if (!link)
        {
            link = [[SVLink alloc] initWithURLString:linkURLString
                                     openInNewWindow:[[anchorElement target] isEqualToString:@"_blank"]];
        }
    }
    
    //[[SVLinkManager sharedLinkManager] setSelectedLink:link editable:(selection != nil)];
    [link release];
}

#pragma mark Pasteboard

- (void)addSelectionTypesToPasteboard:(NSPasteboard *)pasteboard;
{
    [pasteboard addTypes:[NSArray arrayWithObject:@"com.karelia.html+graphics"] owner:self];
    
    [SVAttributedHTMLWriter writeDOMRange:[[self webEditor] selectedDOMRange]
                             toPasteboard:pasteboard
                       graphicControllers:[self graphicControllers]];
}

#pragma mark Dragging

- (BOOL)webEditorTextValidateDrop:(id <NSDraggingInfo>)info
                proposedOperation:(NSDragOperation *)proposedOperation;
{
    // When dragging graphics within the Web Editor, want to move them rather than do a copy
    SVWebEditorView *webEditor = [self webEditor];
    if ([info draggingSource] == webEditor)
    {
        *proposedOperation = NSDragOperationMove;
        
        return NO;
    }
    else
    {
        return [super webEditorTextValidateDrop:info proposedOperation:proposedOperation];
    }
}

- (BOOL)webEditorTextShouldInsertNode:(DOMNode *)node
                    replacingDOMRange:(DOMRange *)range
                          givenAction:(WebViewInsertAction)action;
{
    // When moving an inline element, want to actually do that move
    if (action == WebViewInsertActionDropped)
    {
        SVWebEditorView *webEditor = [self webEditor];
        NSPasteboard *pasteboard = [webEditor insertionPasteboard];
        
        NSArray *items = [webEditor draggedItems];
        if (pasteboard && items)
        {
            // Insert nothing. MUST supply empty text node otherwise WebKit interprets as a paragraph break for some reason
            [[node mutableChildNodesArray] removeAllObjects];
            [node appendChild:[[node ownerDocument] createTextNode:@""]];
            
            
            // Move the dragged items into place
            for (SVWebEditorItem *anItem in items)
            {
                if ([anItem parentWebEditorItem] == self)
                {
                    [range insertNode:[anItem HTMLElement]];
                }
            }
        }
    }
    
    
    
    
    return [super webEditorTextShouldInsertNode:node replacingDOMRange:range givenAction:action];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sBodyTextObservationContext)
    {
        if (![self isUpdating])
        {
            [[self webEditorViewController] setNeedsUpdate];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end


#pragma mark -


@implementation SVRichText (SVDOMController)

- (Class)DOMControllerClass;
{
    return [SVBodyTextDOMController class];
}

@end
