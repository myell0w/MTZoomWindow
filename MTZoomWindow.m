//
//  MTZoomWindow.m
//
//  Created by Matthias Tretter on 8.3.2011.
//  Copyright (c) 2009-2011 Matthias Tretter, @myell0w. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// Rotation code based on Alan Quatermains AQSelfRotatingViewController

#import "MTZoomWindow.h"

@interface MTZoomWindow ()

@property (nonatomic, strong, readwrite) UIView *zoomedView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (unsafe_unretained, nonatomic, readonly) UIView *zoomSuperview;
@property (nonatomic, strong) NSMutableSet *gestureRecognizers;

- (void)handleGesture:(UIGestureRecognizer *)gestureRecognizer;

- (void)orientationWillChange:(NSNotification *)note;
- (void)orientationDidChange:(NSNotification *)note;
- (void)setupForOrientation:(UIInterfaceOrientation)orientation forceLayout:(BOOL)forceLayout;

@end


@implementation MTZoomWindow

@synthesize backgroundView = backgroundView_;
@synthesize zoomGestures = zoomGestures_;
@synthesize animationOptions = animationOptions_;
@synthesize animationDuration = animationDuration_;
@synthesize animationDelay = animationDelay_;
@synthesize scrollView = scrollView_;
@synthesize zoomedView = zoomedView_;
@synthesize gestureRecognizers = gestureRecognizers_;
@synthesize maximumZoomScale = maximumZoomScale_;

////////////////////////////////////////////////////////////////////////
#pragma mark - Lifecycle
////////////////////////////////////////////////////////////////////////

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        // setup window
        self.windowLevel = UIWindowLevelStatusBar + 2.0f;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.backgroundColor = [UIColor clearColor];
        
        // setup black backgroundView
        backgroundView_ = [[UIView alloc] initWithFrame:self.frame];
        backgroundView_.backgroundColor = [UIColor blackColor];
        backgroundView_.alpha = 0.0f;
        backgroundView_.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:backgroundView_];
        
        // setup scrollview
        maximumZoomScale_ = 2.f;
        scrollView_ = [[UIScrollView alloc] initWithFrame:self.frame];
        scrollView_.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        scrollView_.maximumZoomScale = maximumZoomScale_;
        scrollView_.showsVerticalScrollIndicator = NO;
        scrollView_.showsHorizontalScrollIndicator = NO;
        scrollView_.delegate = self;
        scrollView_.hidden = YES;
        [self addSubview:scrollView_];
        
        // setup animation properties
        animationOptions_ = UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction;
        animationDuration_ = 0.4;
        animationDelay_ = 0.0;
        
        gestureRecognizers_ = [[NSMutableSet alloc] init];
        self.zoomGestures = MTZoomGestureTap | MTZoomGesturePinch;
        
        // register for orientation change notification
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(orientationWillChange:)
                                                     name: UIApplicationWillChangeStatusBarOrientationNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(orientationDidChange:)
                                                     name: UIApplicationDidChangeStatusBarOrientationNotification
                                                   object: nil];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: UIApplicationWillChangeStatusBarOrientationNotification
                                                  object: nil];
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: UIApplicationDidChangeStatusBarOrientationNotification
                                                  object: nil];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - MTZoomWindow
////////////////////////////////////////////////////////////////////////

- (void)zoomView:(UIView *)view toSize:(CGSize)size {
    self.zoomedView = view;
    
    // save frames before zoom operation
	CGRect originalFrameInWindow = [view convertRect:view.bounds toView:self];
    
    // pre-setup
    self.backgroundView.alpha = 0.f;
    self.hidden = NO;
    
    // the zoomedView now has another superview and therefore we must change it's frame
	// to still visually appear on the same place like before to the user
    [self.zoomSuperview addSubview:self.zoomedView];
    self.zoomedView.frame = originalFrameInWindow;
    self.zoomedView.autoresizingMask = self.zoomedView.zoomedAutoresizingMask;
    
    [UIView animateWithDuration:self.animationDuration
                          delay:self.animationDelay
                        options:self.animationOptions 
                     animations:^{
                         self.backgroundView.alpha = 1.f;
                         self.zoomedView.frame = CGRectMake((self.bounds.size.width-size.width)/2.f, (self.bounds.size.height-size.height)/2.f,
                                                            size.width, size.height);
                     } completion:^(BOOL finished) {
                         id<MTZoomWindowDelegate> delegate = view.zoomDelegate;
                         
                         if ([delegate respondsToSelector:@selector(zoomWindow:didZoomInView:)]) {
                             [delegate zoomWindow:self didZoomInView:view];
                         }
                     }];
}

- (void)zoomOut {
    if (self.zoomedIn) {
        CGRect destinationFrameInWindow = [self.zoomedView.zoomPlaceholderView convertRect:self.zoomedView.zoomPlaceholderView.bounds toView:self];
        UIView *zoomSuperview = self.zoomSuperview;
        
        // if superview is a scrollView, reset zoom-scale
        if ([zoomSuperview respondsToSelector:@selector(setZoomScale:animated:)]) {
            [zoomSuperview performSelector:@selector(setZoomScale:animated:)
                                withObject:[NSNumber numberWithFloat:1.f] 
                                withObject:[NSNumber numberWithBool:YES]];
        }
        
        [UIView animateWithDuration:self.animationDuration
                              delay:self.animationDelay
                            options:self.animationOptions | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             self.backgroundView.alpha = 0.0f;
                             self.zoomedView.frame = destinationFrameInWindow;
                         } completion:^(BOOL finished) {
                             // reset zoomed view to original position
                             self.zoomedView.frame = self.zoomedView.zoomPlaceholderView.frame;
                             self.zoomedView.autoresizingMask = self.zoomedView.zoomPlaceholderView.autoresizingMask;
                             [self.zoomedView.zoomPlaceholderView.superview insertSubview:self.zoomedView aboveSubview:self.zoomedView.zoomPlaceholderView];
                             [self.zoomedView.zoomPlaceholderView removeFromSuperview];
                             self.zoomedView.zoomPlaceholderView = nil;
                             // hide window
                             self.hidden = YES;
                             
                             id<MTZoomWindowDelegate> delegate = self.zoomedView.zoomDelegate;
                             
                             if ([delegate respondsToSelector:@selector(zoomWindow:didZoomOutView:)]) {
                                 [delegate zoomWindow:self didZoomOutView:self.zoomedView];
                             }
                             
                             self.zoomedView = nil;
                         }];
    }
}

- (UIView *)zoomSuperview {
    if (self.zoomedView.wrapInScrollviewWhenZoomed) {
        self.scrollView.hidden = NO;
        return self.scrollView;
    } else {
        self.scrollView.hidden = YES;
        return self;
    }
}

- (BOOL)isZoomedIn {
    return !self.hidden && self.zoomedView != nil;
}

- (void)setZoomGestures:(NSInteger)zoomGestures {
    if (zoomGestures != zoomGestures_) {
        zoomGestures_ = zoomGestures;
        
        // remove old gesture recognizers
        [self.gestureRecognizers removeAllObjects];
        for (UIGestureRecognizer *gestureRecognizer in self.gestureRecognizers) {
            [self.backgroundView removeGestureRecognizer:gestureRecognizer];
        }
        
        // create new gesture recognizers
        if (zoomGestures & MTZoomGestureTap) {
            UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                                    action:@selector(handleGesture:)];
            [self.gestureRecognizers addObject:tapGestureRecognizer];
        }
        if (zoomGestures & MTZoomGestureDoubleTap) {
            UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                                    action:@selector(handleGesture:)];
            tapGestureRecognizer.numberOfTapsRequired = 2;
            [self.gestureRecognizers addObject:tapGestureRecognizer];
        }
        
        // add new gesture recognizers to views
        for (UIGestureRecognizer *gestureRecognizer in self.gestureRecognizers) {
            [self.backgroundView addGestureRecognizer:gestureRecognizer];
        }
    }
}

- (void)handleGesture:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateRecognized) {
        [self.zoomedView zoomOut];
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - UIScrollViewDelegate
////////////////////////////////////////////////////////////////////////

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.zoomedView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    if (self.zoomGestures & MTZoomGesturePinch) {
        if (!scrollView.zooming && scrollView.zoomBouncing && scrollView.zoomScale <= 1.f) {
            [self.zoomedView zoomOut];
        }
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Rotation
////////////////////////////////////////////////////////////////////////

- (void)setupForOrientation:(UIInterfaceOrientation)orientation forceLayout:(BOOL)forceLayout {
    UIInterfaceOrientation current = [[UIApplication sharedApplication] statusBarOrientation];
    
    if (!forceLayout) {
        // if ( [self shouldAutorotateToInterfaceOrientation: orientation] == NO )
        //	return;
        
        if (current == orientation) {
            return;
        }
    }
    
	// direction and angle
	CGFloat angle = 0.0;
	switch (current) {
		case UIInterfaceOrientationPortrait: {
			switch (orientation) {
				case UIInterfaceOrientationPortraitUpsideDown:
					angle = (CGFloat)M_PI;	// 180.0*M_PI/180.0 == M_PI
					break;
                    
				case UIInterfaceOrientationLandscapeLeft:
					angle = (CGFloat)(M_PI*-90.0)/180.0;
					break;
                    
				case UIInterfaceOrientationLandscapeRight:
					angle = (CGFloat)(M_PI*90.0)/180.0;
					break;
                    
				default:
					return;
			}
			break;
		}
            
		case UIInterfaceOrientationPortraitUpsideDown: {
			switch (orientation) {
				case UIInterfaceOrientationPortrait:
					angle = (CGFloat)M_PI;	// 180.0*M_PI/180.0 == M_PI
					break;
                    
				case UIInterfaceOrientationLandscapeLeft:
					angle = (CGFloat)(M_PI*90.0)/180.0;
					break;
                    
				case UIInterfaceOrientationLandscapeRight:
					angle = (CGFloat)(M_PI*-90.0)/180.0;
					break;
                    
				default:
					return;
			}
			break;
		}
            
		case UIInterfaceOrientationLandscapeLeft: {
			switch (orientation) {
				case UIInterfaceOrientationLandscapeRight:
					angle = (CGFloat)M_PI;	// 180.0*M_PI/180.0 == M_PI
					break;
                    
				case UIInterfaceOrientationPortraitUpsideDown:
					angle = (CGFloat)(M_PI*-90.0)/180.0;
					break;
                    
				case UIInterfaceOrientationPortrait:
					angle = (CGFloat)(M_PI*90.0)/180.0;
					break;
                    
				default:
					return;
			}
			break;
		}
            
		case UIInterfaceOrientationLandscapeRight: {
			switch (orientation) {
				case UIInterfaceOrientationLandscapeLeft:
					angle = (CGFloat)M_PI;	// 180.0*M_PI/180.0 == M_PI
					break;
                    
				case UIInterfaceOrientationPortrait:
					angle = (CGFloat)(M_PI*-90.0)/180.0;
					break;
                    
				case UIInterfaceOrientationPortraitUpsideDown:
					angle = (CGFloat)(M_PI*90.0)/180.0;
					break;
                    
				default:
					return;
			}
			break;
		}
	}
    
	CGAffineTransform rotation = CGAffineTransformMakeRotation(angle);
    
    [UIView animateWithDuration:0.4 animations:^{
        self.transform = CGAffineTransformConcat(rotation, self.transform);
    }];
}

- (void)orientationWillChange:(NSNotification *)note {
	UIInterfaceOrientation orientation = [[[note userInfo] objectForKey: UIApplicationStatusBarOrientationUserInfoKey] integerValue];
    [self setupForOrientation:orientation forceLayout:NO];
}

- (void)orientationDidChange:(NSNotification *)note {
	// UIInterfaceOrientation orientation = [[[note userInfo] objectForKey: UIApplicationStatusBarOrientationUserInfoKey] integerValue];
	
    //if ([self shouldAutorotateToInterfaceOrientation:[[UIApplication sharedApplication] statusBarOrientation]] == NO)
	//	return;
    
	self.frame = [[UIScreen mainScreen] bounds];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Singleton definitons
////////////////////////////////////////////////////////////////////////

static MTZoomWindow *sharedMTZoomWindow = nil;

+ (MTZoomWindow *)sharedWindow {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMTZoomWindow = [[self alloc] initWithFrame:[UIScreen mainScreen].bounds];
    });
    
	return sharedMTZoomWindow;
}

@end
