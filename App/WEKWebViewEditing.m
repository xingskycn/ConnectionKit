//
//  WEKWebViewEditing.m
//  Sandvox
//
//  Created by Mike on 27/05/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "WEKWebViewEditing.h"

#import "SVWebViewSelectionController.h"

#import "DOMRange+Karelia.h"
#import "NSString+Karelia.h"


#pragma mark -


@implementation WebView (WEKWebViewEditing)

#pragma mark Selection

- (WEKSelection *)wek_selection;
{
    DOMRange *selection = [self selectedDOMRange];
    if (selection)
    {
        return [[[WEKSelection alloc] initWithDOMRange:selection
                                              affinity:[self selectionAffinity]] autorelease];
    }
    return nil;
}

- (void)wek_setSelection:(WEKSelection *)selection;
{
    if (selection)
    {
        DOMRange *range = [self selectedDOMRange];
        if (!range) range = [[[selection startContainer] ownerDocument] createRange];
        
        [range setStart:[selection startContainer] offset:[selection startOffset]];
        [range setEnd:[selection endContainer] offset:[selection endOffset]];
        
        [self setSelectedDOMRange:range affinity:[selection affinity]];
    }
    else
    {
        [self setSelectedDOMRange:nil affinity:0];
    }
}

#pragma mark Alignment

- (NSTextAlignment)wek_alignment;
{
    NSTextAlignment result = NSNaturalTextAlignment;
    
    DOMDocument *doc = [[self selectedFrame] DOMDocument];
    if ([[doc queryCommandValue:@"justifyleft"] isEqualToStringCaseInsensitive:@"true"])
    {
        result = NSLeftTextAlignment;
    }
    else if ([[doc queryCommandValue:@"justifycenter"] isEqualToStringCaseInsensitive:@"true"])
    {
        result = NSCenterTextAlignment;
    }
    else if ([[doc queryCommandValue:@"justifyright"] isEqualToStringCaseInsensitive:@"true"])
    {
        result = NSRightTextAlignment;
    }
    else if ([[doc queryCommandValue:@"justifyfull"] isEqualToStringCaseInsensitive:@"true"])
    {
        result = NSJustifiedTextAlignment;
    }
    
    return result;
}

#pragma mark Lists

- (IBAction)insertOrderedList:(id)sender;
{
    id delegate = [self editingDelegate];
    if ([delegate respondsToSelector:@selector(webView:doCommandBySelector:)])
    {
        if ([delegate webView:self doCommandBySelector:_cmd]) return;
    }
    
    if ([self orderedList]) return;  // nowt to do
    
    DOMDocument *document = [[self selectedFrame] DOMDocument];
    if ([document execCommand:@"InsertOrderedList"])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeNotification object:self];
    }
    else
    {
        NSBeep();
    }
}

- (IBAction)insertUnorderedList:(id)sender;
{
    id delegate = [self editingDelegate];
    if ([delegate respondsToSelector:@selector(webView:doCommandBySelector:)])
    {
        if ([delegate webView:self doCommandBySelector:_cmd]) return;
    }
    
    if ([self unorderedList]) return;  // nowt to do

    DOMDocument *document = [[self selectedFrame] DOMDocument];
    if (![document execCommand:@"InsertUnorderedList"])
    {
        NSBeep();
    }
}

- (IBAction)removeList:(id)sender;
{
    id delegate = [self editingDelegate];
    if ([delegate respondsToSelector:@selector(webView:doCommandBySelector:)])
    {
        if ([delegate webView:self doCommandBySelector:_cmd]) return;
    }
    
    
    DOMRange *selection = [self selectedDOMRange];
    if (!selection)
    {
        NSBeep();
        return;
    }
    
    SVWebViewSelectionController *controller = [[SVWebViewSelectionController alloc] init];
    [controller setSelection:selection];
    
    while ([[controller deepestListIndentLevel] unsignedIntegerValue])
    {
        [[[self selectedFrame] DOMDocument] execCommand:@"Outdent"];
        
        selection = [self selectedDOMRange];
        if (!selection) break;
        [controller setSelection:[self selectedDOMRange]];
    }
    
    [controller release];
}

- (BOOL)orderedList;
{
    DOMDocument *document = [[self selectedFrame] DOMDocument];
    return [document queryCommandState:@"InsertOrderedList"];
}

- (BOOL)unorderedList;
{
    DOMDocument *document = [[self selectedFrame] DOMDocument];
    return [document queryCommandState:@"InsertUnorderedList"];
}

@end


#pragma mark -


@implementation WEKSelection

- (id)initWithDOMRange:(DOMRange *)range affinity:(NSSelectionAffinity)affinity;
{
    [self init];
    
    _startContainer = [[range startContainer] retain];
    _startOffset = [range startOffset];
    _endContainer = [[range endContainer] retain];
    _endOffset = [range endOffset];
    _affinity = affinity;
    
    return self;
}

- (void)dealloc
{
    [_startContainer release];
    [_endContainer release];
    
    [super dealloc];
}

@synthesize startContainer = _startContainer;
@synthesize startOffset = _startOffset;
@synthesize endContainer = _endContainer;
@synthesize endOffset = _endOffset;
@synthesize affinity = _affinity;

@end

