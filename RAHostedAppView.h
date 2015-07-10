#import "headers.h"

@class RAAppSliderProvider;

@interface RAHostedAppView : UIView {
	SBApplication *app;
	FBWindowContextHostWrapperView *view;
}
-(id) initWithBundleIdentifier:(NSString*)bundleIdentifier;

@property (nonatomic, retain) NSString *bundleIdentifier;
@property (nonatomic) BOOL autosizesApp;

@property (nonatomic) BOOL isTopApp;
@property (nonatomic) BOOL allowHidingStatusBar;

-(SBApplication*) app;
-(NSString*) displayName;

@property (nonatomic, readonly) UIInterfaceOrientation orientation;
-(void) rotateToOrientation:(UIInterfaceOrientation)o;

-(void) preloadApp;
-(void) loadApp;
-(void) unloadApp;
@end