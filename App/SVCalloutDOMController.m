//
//  SVCalloutDOMController.m
//  Sandvox
//
//  Created by Mike on 28/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVCalloutDOMController.h"


@implementation SVCalloutDOMController

- (NSString *)HTMLElementIDName;
{
    return [NSString stringWithFormat:@"callout-controller-%p", self];
}

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    DOMHTMLElement *element = (DOMHTMLElement *)[document getElementById:[self HTMLElementIDName]];
    [element setIdName:nil];
    
    [self setHTMLElement:element];
}

@end
