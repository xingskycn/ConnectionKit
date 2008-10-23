//
//  KTAbstractElement.h
//  Sandvox
//
//  Copyright (c) 2005-2008, Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
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

#import "KTManagedObject.h"
#import <WebKit/WebKit.h>


@class KTDocument, KTMediaManager, KTElementPlugin, KTPage;
@interface KTAbstractElement : KTManagedObject 
{
    // optional delegate
	id myDelegate;
}

#pragma mark awake

// Plugin awake
- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject; // we want to be able to pass a flag here for special circumstances
- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary;

// Delegate
- (id)delegate;


// Accessors
- (NSString *)uniqueID; // for convenience

- (NSString *)titleHTML;
- (void)setTitleHTML:(NSString *)value;
- (NSString *)titleText;
- (void)setTitleText:(NSString *)title;

@end


@interface NSObject (KTAbstractPluginDelegate)
- (void)plugin:(KTAbstractElement *)plugin 
   didSetValue:(id)value 
  forPluginKey:(NSString *)key 
	  oldValue:(id)oldValue;

- (BOOL)plugin:(KTAbstractElement *)plugin
	shouldInsertNode:(DOMNode *)node
  intoTextForKeyPath:(NSString *)keyPath
		 givenAction:(WebViewInsertAction)action;
@end


@protocol KTExtensiblePluginPropertiesArchiving
+ (id)objectWithArchivedIdentifier:(NSString *)identifier inDocument:(KTDocument *)document;
- (NSString *)archiveIdentifier;
@end
