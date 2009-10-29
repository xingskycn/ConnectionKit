// 
//  SVSidebar.m
//  Sandvox
//
//  Created by Mike on 29/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVSidebar.h"

#import "KTAbstractPage.h"
#import "SVPagelet.h"

#import "NSSortDescriptor+Karelia.h"


@implementation SVSidebar 

@dynamic page;

#pragma mark Pagelets

@dynamic pagelets;

- (NSArray *)sortedPagelets;
{
    // Our pagelets, but sorted by their sort key
    static NSArray *sortDescriptors;
    if (!sortDescriptors)
    {
        sortDescriptors = [NSSortDescriptor sortDescriptorArrayWithKey:@"sidebarSortKey"
                                                             ascending:YES];
        [sortDescriptors retain];
        OBASSERT(sortDescriptors);
    }
    
    NSArray *result = [[[self pagelets] allObjects] sortedArrayUsingDescriptors:sortDescriptors];
    return result;
}

- (BOOL)validatePagelets:(NSSet **)pagelets error:(NSError **)error
{
    BOOL result = YES;
    
    // All our pagelets should have unique sort keys
    NSSet *sortKeys = [*pagelets valueForKey:@"sidebarSortKey"];
    if ([sortKeys count] != [*pagelets count])
    {
        result = NO;
        if (error)
        {
            NSDictionary *info = [NSDictionary dictionaryWithObject:@"Pagelet sort keys are not unique" forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSManagedObjectValidationError userInfo:info];
        }
    }
    
    return result;
}

@end
