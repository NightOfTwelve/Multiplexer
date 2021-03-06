#import "headers.h"
#import "RAGestureManager.h"
#import "RAMissionControlManager.h"
#import "RAMissionControlWindow.h"
#import "RASettings.h"
#import "RASnapshotProvider.h"
#import "RADesktopManager.h"

BOOL allowMissionControlActivationFromSwitcher = YES;
BOOL statusBarVisibility;
BOOL willShowMissionControl = NO;

%hook SBUIController
- (void)_showNotificationsGestureBeganWithLocation:(CGPoint)arg1
{
	if ([[[%c(SBUIController) sharedInstance] switcherWindow] isKeyWindow] && CGRectContainsPoint([[[%c(SBUIController) sharedInstance] switcherWindow] viewWithTag:999].frame, arg1))
		return;

	if ([[%c(RASettings) sharedInstance] missionControlEnabled] && self.isAppSwitcherShowing)
		return;

	%orig;
}

- (_Bool)_activateAppSwitcher
{
	statusBarVisibility = UIApplication.sharedApplication.statusBarHidden;
	willShowMissionControl = NO;

	if ([[%c(RASettings) sharedInstance] replaceAppSwitcherWithMC] && [[%c(RASettings) sharedInstance] missionControlEnabled])
	{
		if (RAMissionControlManager.sharedInstance.isShowingMissionControl == NO)
		{
			[RAMissionControlManager.sharedInstance showMissionControl:YES];
	    }
	    else
	    	[RAMissionControlManager.sharedInstance hideMissionControl:YES];

		return YES;
	}
	else
	{
		if ([RAMissionControlManager.sharedInstance isShowingMissionControl])
		{
			[RAMissionControlManager.sharedInstance hideMissionControl:YES];
		}
	}

	BOOL s = %orig;
	if (s && [[%c(RASettings) sharedInstance] missionControlEnabled] && [[[%c(SBUIController) sharedInstance] switcherWindow] viewWithTag:999] != nil)
	{
		[UIView animateWithDuration:0.3 animations:^{
			[[[%c(SBUIController) sharedInstance] switcherWindow] viewWithTag:999].alpha = 1;
		}];
	}
	if (s)
	{
		[[%c(RADesktopManager) sharedInstance] performSelectorOnMainThread:@selector(hideDesktop) withObject:nil waitUntilDone:NO];
		//[[[%c(RADesktopManager) sharedInstance] currentDesktop] unloadApps];
	}
	return s;
}

- (void)_hideNotificationsGestureCancelled
{
	%orig;
	RAMissionControlManager.sharedInstance.inhibitDismissalGesture = NO;
}

- (void)_hideNotificationsGestureEndedWithCompletionType:(long long)arg1 velocity:(CGPoint)arg2
{
	%orig;
	RAMissionControlManager.sharedInstance.inhibitDismissalGesture = NO;
}

- (void)_hideNotificationsGestureBegan:(CGFloat)arg1
{
	RAMissionControlManager.sharedInstance.inhibitDismissalGesture = YES;
	%orig;
}

- (_Bool)isAppSwitcherShowing
{
	return %orig || RAMissionControlManager.sharedInstance.isShowingMissionControl;
}

-(void) _dismissSwitcherAnimated:(_Bool)arg1
{
	if (RAMissionControlManager.sharedInstance.isShowingMissionControl)
	{
		[RAMissionControlManager.sharedInstance hideMissionControl:arg1];
	}
	
	%orig;
}
%end

%hook SBAppSwitcherController
// iOS 8
- (void)switcherWillBeDismissed:(_Bool)arg1
{
	if (willShowMissionControl == NO)
	{
		[[%c(RADesktopManager) sharedInstance] reshowDesktop];
		//[[[%c(RADesktopManager) sharedInstance] currentDesktop] loadApps];
	}

	[UIView animateWithDuration:0.3 animations:^{
		[[[%c(SBUIController) sharedInstance] switcherWindow] viewWithTag:999].alpha = 0;
	}];

	%orig;
}

// iOS 9
- (void)_switcherWasDismissed:(_Bool)arg1
{
	if (willShowMissionControl == NO)
	{
		[[%c(RADesktopManager) sharedInstance] reshowDesktop];
		//[[[%c(RADesktopManager) sharedInstance] currentDesktop] loadApps];
	}

	[UIView animateWithDuration:0.3 animations:^{
		[[[%c(SBUIController) sharedInstance] switcherWindow] viewWithTag:999].alpha = 0;
	}];

	%orig;
}

- (void)switcherScroller:(id)arg1 itemTapped:(__unsafe_unretained SBDisplayLayout*)arg2
{
	SBDisplayItem *item = [arg2 displayItems][0];
	NSString *identifier = item.displayIdentifier;

	[[%c(RADesktopManager) sharedInstance] removeAppWithIdentifier:identifier animated:NO forceImmediateUnload:YES];

	%orig;
}
%end

@interface SBAppSwitcherController ()
-(UIView*) view;
@end

//%hook SBAppSwitcherWindow
%hook SBAppSwitcherController
//-(void) addSubview:(UIView*)view

- (void)_layoutInOrientation:(long long)arg1
{
	%orig;
	
	UIView *view = MSHookIvar<UIView*>(self, "_contentView");

	if ([view viewWithTag:999] == nil && ([[%c(RASettings) sharedInstance] missionControlEnabled] && ![[%c(RASettings) sharedInstance] replaceAppSwitcherWithMC]))
	{
		CGFloat width = 50, height = 30;
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
		{
			width = 60;
		    height = 40;
		}
		SBControlCenterGrabberView *grabber = [[%c(SBControlCenterGrabberView) alloc] initWithFrame:CGRectMake(0, 0, width, height)];
		grabber.center = CGPointMake(view.frame.size.width / 2, 20/2);
		
		grabber.backgroundColor = [UIColor clearColor];
		//grabber.chevronView.vibrantSettings = [%c(_SBFVibrantSettings) vibrantSettingsWithReferenceColor:UIColor.whiteColor referenceContrast:0.5 legibilitySettings:nil];

		_UIBackdropView *blurView = [[%c(_UIBackdropView) alloc] initWithStyle:2060];
		blurView.frame = grabber.frame;
		[grabber insertSubview:blurView atIndex:0];

		[grabber.chevronView setState:1 animated:NO];

		grabber.layer.cornerRadius = 5;

		//[grabber.chevronView setState:1 animated:YES];
		grabber.tag = 999;
		[view addSubview:grabber];

		[[%c(RAGestureManager) sharedInstance] addGestureRecognizerWithTarget:(NSObject<RAGestureCallbackProtocol> *)self forEdge:UIRectEdgeTop identifier:@"com.efrederickson.reachapp.appswitchergrabber"];
	}
	else
		((UIView*)[view viewWithTag:999]).center = CGPointMake(view.frame.size.width / 2, 20/2);
}

// iOS 8
-(void)viewDidAppear:(BOOL)a
{
	%orig;

	UIView *view = MSHookIvar<UIView*>(self, "_contentView");

	if ([view viewWithTag:999] == nil && ([[%c(RASettings) sharedInstance] missionControlEnabled] && ![[%c(RASettings) sharedInstance] replaceAppSwitcherWithMC]))
	{
		CGFloat width = 50, height = 30;
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
		{
			width = 60;
		    height = 40;
		}
		SBControlCenterGrabberView *grabber = [[%c(SBControlCenterGrabberView) alloc] initWithFrame:CGRectMake(0, 0, width, height)];
		grabber.center = CGPointMake(view.frame.size.width / 2, 20/2);
		
		
		grabber.backgroundColor = [UIColor clearColor];
		//grabber.chevronView.vibrantSettings = [%c(_SBFVibrantSettings) vibrantSettingsWithReferenceColor:UIColor.whiteColor referenceContrast:0.5 legibilitySettings:nil];

		_UIBackdropView *blurView = [[%c(_UIBackdropView) alloc] initWithStyle:2060];
		blurView.frame = grabber.frame;
		[grabber insertSubview:blurView atIndex:0];

		[grabber.chevronView setState:1 animated:NO];

		grabber.layer.cornerRadius = 5;

		//[grabber.chevronView setState:1 animated:YES];
		grabber.tag = 999;
		[view addSubview:grabber];

		//[grabber.chevronView setState:1 animated:YES];
		grabber.tag = 999;
		[view addSubview:grabber];

		[[%c(RAGestureManager) sharedInstance] addGestureRecognizerWithTarget:(NSObject<RAGestureCallbackProtocol> *)self forEdge:UIRectEdgeTop identifier:@"com.efrederickson.reachapp.appswitchergrabber"];
	}
	else
		((UIView*)[view viewWithTag:999]).center = CGPointMake(view.frame.size.width / 2, 20/2);
}

%new -(BOOL) RAGestureCallback_canHandle:(CGPoint)point velocity:(CGPoint)velocity
{
	return allowMissionControlActivationFromSwitcher && [[%c(RASettings) sharedInstance] missionControlEnabled] && self.view.window.isKeyWindow;
}

%new -(RAGestureCallbackResult) RAGestureCallback_handle:(UIGestureRecognizerState)state withPoint:(CGPoint)location velocity:(CGPoint)velocity forEdge:(UIRectEdge)edge
{
	[[%c(SBUIController) sharedInstance] performSelector:@selector(_showNotificationsGestureFailed)];
	[[%c(SBUIController) sharedInstance] performSelector:@selector(_showNotificationsGestureCancelled)];

	static CGFloat origY = -1;
	static UIView *fakeView;
	UIView *view = MSHookIvar<UIView*>(self, "_contentView");

	if (!fakeView)
	{
		UIImage *snapshot = [[%c(RASnapshotProvider) sharedInstance] storedSnapshotOfMissionControl];

		if (snapshot)
		{
			fakeView = [[UIImageView alloc] initWithFrame:view.frame];
			((UIImageView*)fakeView).image = snapshot;
			[view addSubview:fakeView];
		}
		else
		{
			fakeView = [[UIView alloc] initWithFrame:view.frame];

			CGFloat width = UIScreen.mainScreen.RA_interfaceOrientedBounds.size.width / 4.5714;
			CGFloat height = UIScreen.mainScreen.RA_interfaceOrientedBounds.size.height / 4.36;

			_UIBackdropView *blurView = [[%c(_UIBackdropView) alloc] initWithStyle:1];
			blurView.frame = fakeView.frame;
			[fakeView addSubview:blurView];

			UILabel *desktopLabel, *windowedLabel, *otherLabel;
			UIScrollView *desktopScrollView, *windowedAppScrollView, *otherRunningAppsScrollView;

			CGFloat x = 15;
			CGFloat y = 25;

			desktopLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, y, fakeView.frame.size.width - 20, 20)];
			desktopLabel.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:14];
			desktopLabel.textColor = UIColor.whiteColor;
			desktopLabel.text = @"Desktops";
			[fakeView addSubview:desktopLabel];

			y = y + desktopLabel.frame.size.height + 3;

			desktopScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, y, fakeView.frame.size.width, height * 1.2)];
			desktopScrollView.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.3];

			[fakeView addSubview:desktopScrollView];

			UIButton *newDesktopButton = [[UIButton alloc] init];
			newDesktopButton.frame = CGRectMake(x, 20, width, height);
			newDesktopButton.backgroundColor = [UIColor darkGrayColor];
			[newDesktopButton setTitle:@"+" forState:UIControlStateNormal];
			newDesktopButton.titleLabel.font = [UIFont systemFontOfSize:36];
			[desktopScrollView addSubview:newDesktopButton];

			x = 15;
			y = desktopScrollView.frame.origin.y + desktopScrollView.frame.size.height + 5;

			windowedLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, y, fakeView.frame.size.width - 20, 20)];
			windowedLabel.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:14];
			windowedLabel.textColor = UIColor.whiteColor;
			windowedLabel.text = @"On This Desktop";
			[fakeView addSubview:windowedLabel];

			windowedAppScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, y + windowedLabel.frame.size.height + 3, fakeView.frame.size.width, height * 1.2)];
			windowedAppScrollView.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.3];

			[fakeView addSubview:windowedAppScrollView];

			x = 15;
			y = windowedAppScrollView.frame.origin.y + windowedAppScrollView.frame.size.height + 5;

			otherLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, y, fakeView.frame.size.width - 20, 20)];
			otherLabel.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:14];
			otherLabel.textColor = UIColor.whiteColor;
			otherLabel.text = @"Running Elsewhere";
			[fakeView addSubview:otherLabel];

			otherRunningAppsScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, y + otherLabel.frame.size.height + 3, fakeView.frame.size.width, height * 1.2)];
			otherRunningAppsScrollView.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.3];

			[fakeView addSubview:otherRunningAppsScrollView];

			[view addSubview:fakeView];
		}
	}

	if (origY == -1)
	{
		CGRect f = fakeView.frame;
		f.origin.y = -f.size.height;
		fakeView.frame = f;
		origY = fakeView.center.y;
	}

	if (state == UIGestureRecognizerStateChanged)	
		fakeView.center = (CGPoint) { fakeView.center.x, origY + location.y };
	
	if (state == UIGestureRecognizerStateEnded)
	{
		//NSLog(@"[ReachApp] %@ + %@ = %@ > %@", NSStringFromCGPoint(fakeView.frame.origin), NSStringFromCGPoint(velocity), @(fakeView.frame.origin.y + velocity.y), @(-(UIScreen.mainScreen.bounds.size.height / 2)));

		if (fakeView.frame.origin.y + velocity.y > -(UIScreen.mainScreen.RA_interfaceOrientedBounds.size.height / 2))
		{			
			willShowMissionControl = YES;
			CGFloat distance = UIScreen.mainScreen.RA_interfaceOrientedBounds.size.height - (fakeView.frame.origin.y + fakeView.frame.size.height);
			CGFloat duration = MIN(distance / velocity.y, 0.3);

			//NSLog(@"[ReachApp] dist %f, dur %f", distance, duration);

			[UIView animateWithDuration:duration animations:^{
				fakeView.frame = UIScreen.mainScreen.RA_interfaceOrientedBounds;
			} completion:^(BOOL _) {
				//((UIWindow*)[[%c(SBUIController) sharedInstance] switcherWindow]).alpha = 0;
				[[%c(SBUIController) sharedInstance] dismissSwitcherAnimated:NO];
				[[%c(SBUIController) sharedInstance] restoreContentUpdatingStatusBar:YES];
				[RAMissionControlManager.sharedInstance showMissionControl:NO];
				[fakeView removeFromSuperview];
				fakeView = nil;
				UIApplication.sharedApplication.statusBarHidden = statusBarVisibility;
				// avoid status bar hiding
				//dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
				//	((UIWindow*)[[%c(SBUIController) sharedInstance] switcherWindow]).alpha = 1;
				//});
			}];
		}
		else
		{
			CGFloat distance = fakeView.frame.size.height + fakeView.frame.origin.y /* origin.y is less than 0 so the + is actually a - operation */;
			CGFloat duration = MIN(distance / velocity.y, 0.3);

			//NSLog(@"[ReachApp] dist %f, dur %f", distance, duration);

			[UIView animateWithDuration:duration animations:^{
				fakeView.frame = CGRectMake(fakeView.frame.origin.x, -fakeView.frame.size.height, fakeView.frame.size.width, fakeView.frame.size.height);
			} completion:^(BOOL _) {
				[fakeView removeFromSuperview];
				fakeView = nil;
			}];
		}
	}

	return RAGestureCallbackResultSuccess;
}
%end

@interface SBAppSwitcherPageViewController : UIViewController
@end
%hook SBAppSwitcherPageViewController
- (void)_layout
{
	%orig;

	UIView *view = [self view];

	if ([view viewWithTag:999] == nil && ([[%c(RASettings) sharedInstance] missionControlEnabled] && ![[%c(RASettings) sharedInstance] replaceAppSwitcherWithMC]))
	{
		CGFloat width = 50, height = 30;
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
		{
			width = 60;
		    height = 40;
		}
		SBControlCenterGrabberView *grabber = [[%c(SBControlCenterGrabberView) alloc] initWithFrame:CGRectMake(0, 0, width, height)];
		grabber.center = CGPointMake(view.frame.size.width / 2, 20/2);
		
		
		grabber.backgroundColor = [UIColor clearColor];
		//grabber.chevronView.vibrantSettings = [%c(_SBFVibrantSettings) vibrantSettingsWithReferenceColor:UIColor.whiteColor referenceContrast:0.5 legibilitySettings:nil];

		_UIBackdropView *blurView = [[%c(_UIBackdropView) alloc] initWithStyle:2060];
		blurView.frame = grabber.frame;
		[grabber insertSubview:blurView atIndex:0];

		[grabber.chevronView setState:1 animated:NO];

		grabber.layer.cornerRadius = 5;

		//[grabber.chevronView setState:1 animated:YES];
		grabber.tag = 999;
		[view addSubview:grabber];

		//[grabber.chevronView setState:1 animated:YES];
		grabber.tag = 999;
		[view addSubview:grabber];

		[[%c(RAGestureManager) sharedInstance] addGestureRecognizerWithTarget:(NSObject<RAGestureCallbackProtocol> *)self forEdge:UIRectEdgeTop identifier:@"com.efrederickson.reachapp.appswitchergrabber"];
	}
	else
		((UIView*)[view viewWithTag:999]).center = CGPointMake(view.frame.size.width / 2, 20/2);
}
%end
