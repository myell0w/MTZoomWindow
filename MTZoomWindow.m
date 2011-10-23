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


#import "MTZoomWindow.h"

@interface MTZoomWindow ()

@property (nonatomic, retain) UIView *zoomedView;
@property (nonatomic, retain) UIScrollView *scrollView;
@property (nonatomic, readonly) UIView *zoomSuperview;
@property (nonatomic, retain) NSMutableSet *gestureRecognizers;

- (void)handleGesture:(UIGestureRecognizer *)gestureRecognizer;

- (void)orientationWillChange:(NSNotification *)note;
- (void)orientationDidChange:(NSNotification *)note;

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

#import <QuartzCore/QuartzCore.h>

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Lifecycle
////////////////////////////////////////////////////////////////////////

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        // setup window
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.windowLevel = UIWindowLevelStatusBar + 2.0f;
        self.backgroundColor = [UIColor clearColor];
        
        // setup black backgroundView
        backgroundView_ = [[UIView alloc] initWithFrame:self.frame];
        backgroundView_.backgroundColor = [UIColor blackColor];
        backgroundView_.alpha = 0.0f;
        backgroundView_.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:backgroundView_];
        
        // setup scrollview
        scrollView_ = [[UIScrollView alloc] initWithFrame:self.frame];
        scrollView_.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        scrollView_.maximumZoomScale = 2.0f;
        scrollView_.showsVerticalScrollIndicator = NO;
        scrollView_.showsHorizontalScrollIndicator = NO;
        scrollView_.delegate = self;
        
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
        
        scrollView_.layer.borderWidth = 2.f;
        scrollView_.layer.borderColor = [UIColor blueColor].CGColor;
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
    
    [backgroundView_ release], backgroundView_ = nil;
    [zoomedView_ release], zoomedView_ = nil;
    [scrollView_ release], scrollView_ = nil;
    [gestureRecognizers_ release], gestureRecognizers_ = nil;
    
    [super dealloc];
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark MTZoomWindow
////////////////////////////////////////////////////////////////////////

- (void)zoomView:(UIView *)view toSize:(CGSize)size completion:(mt_zoom_block)completionBlock {
    self.zoomedView = view;
    
    // save frames before zoom operation
	CGRect originalFrameInWindow = [view convertRect:view.bounds toView:nil];
    CGSize zoomedSize = view.zoomedSize;
    
    // pre-setup
    self.backgroundView.alpha = 0.f;
    self.hidden = NO;
    
    // the zoomedView now has another superview and therefore we must change it's frame
	// to still visually appear on the same place like before to the user
    [self.zoomSuperview addSubview:self.zoomedView];
    self.zoomedView.frame = originalFrameInWindow;
    self.zoomedView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    [UIView animateWithDuration:self.animationDuration
                          delay:self.animationDelay
                        options:self.animationOptions 
                     animations:^{
                         self.backgroundView.alpha = 1.f;
                         self.zoomedView.frame = CGRectMake((self.frame.size.width-zoomedSize.width)/2.f, (self.frame.size.height-zoomedSize.height)/2.f,
                                                            zoomedSize.width, zoomedSize.height);
                     } completion:^(BOOL finished) {
                         if (completionBlock != nil) {
                             completionBlock();
                         }
                     }];
}

- (void)zoomOutWithCompletion:(mt_zoom_block)completionBlock {
    CGRect destinationFrameInWindow = [self.zoomedView.zoomPlaceholderView convertRect:self.zoomedView.zoomPlaceholderView.bounds toView:nil];
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
                         [self.zoomedView.zoomPlaceholderView.superview addSubview:self.zoomedView];
                         [self.zoomedView.zoomPlaceholderView removeFromSuperview];
                         self.zoomedView.zoomPlaceholderView = nil;
                         // hide window
                         self.hidden = YES;
                         
                         if (completionBlock != nil) {
                             completionBlock();
                         }
                     }];
}

- (UIView *)zoomSuperview {
    if (self.zoomedView.wrapInScrollviewWhenZoomed) {
        if (self.scrollView.superview == nil) {
            [self insertSubview:self.scrollView atIndex:1];
        }
        return self.scrollView;
    } else {
        [self.scrollView removeFromSuperview];
        return self;
    }
}

- (BOOL)isZoomedIn {
    return !self.hidden && self.backgroundView.alpha > 0.f;
}

- (void)setZoomGestures:(NSInteger)zoomGestures {
    if (zoomGestures != zoomGestures_) {
        zoomGestures_ = zoomGestures;
        
        // remove old gesture recognizers
        for (UIGestureRecognizer *gestureRecognizer in self.gestureRecognizers) {
            [self.backgroundView removeGestureRecognizer:gestureRecognizer];
        }
        
        // create new gesture recognizers
        if (zoomGestures & MTZoomGestureTap) {
            UITapGestureRecognizer *tapGestureRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                                    action:@selector(handleGesture:)] autorelease];
            [self.gestureRecognizers addObject:tapGestureRecognizer];
        }
        if (zoomGestures & MTZoomGestureDoubleTap) {
            UITapGestureRecognizer *tapGestureRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                                    action:@selector(handleGesture:)] autorelease];
            tapGestureRecognizer.numberOfTapsRequired = 2;
            [self.gestureRecognizers addObject:tapGestureRecognizer];
        }
        if (zoomGestures & MTZoomGesturePinch) {
            UIPinchGestureRecognizer *pinchGestureRecognizer = [[[UIPinchGestureRecognizer alloc] initWithTarget:self
                                                                                                          action:@selector(handleGesture:)] autorelease];
            [self.gestureRecognizers addObject:pinchGestureRecognizer];
        }
        
        // add new gesture recognizers to views
        for (UIGestureRecognizer *gestureRecognizer in self.gestureRecognizers) {
            [self.backgroundView addGestureRecognizer:gestureRecognizer];
            // TODO: add to zoomedView
        }
    }
}

- (void)handleGesture:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateRecognized) {
        if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
            UIPinchGestureRecognizer *pinchGestureRecognizer = (UIPinchGestureRecognizer *)gestureRecognizer;
            
            if (pinchGestureRecognizer.scale < 1.0) {
                // TODO: how to set completion block?
                [self zoomOutWithCompletion:nil];
            }
        } else {
            [self zoomOutWithCompletion:nil];
        }
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UIScrollViewDelegate
////////////////////////////////////////////////////////////////////////

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.zoomedView;
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Rotation
////////////////////////////////////////////////////////////////////////

- (void)orientationWillChange:(NSNotification *)note {
	UIInterfaceOrientation current = [[UIApplication sharedApplication] statusBarOrientation];
	UIInterfaceOrientation orientation = [[[note userInfo] objectForKey: UIApplicationStatusBarOrientationUserInfoKey] integerValue];
	
   // if ( [self shouldAutorotateToInterfaceOrientation: orientation] == NO )
   //	return;
    
	if ( current == orientation )
		return;
    
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
    
	CGAffineTransform rotation = CGAffineTransformMakeRotation( angle );
    
    [UIView animateWithDuration:0.4 animations:^{
        self.transform = CGAffineTransformConcat(rotation, self.transform);
    }];
}

- (void)orientationDidChange:(NSNotification *)note {
	// UIInterfaceOrientation orientation = [[[note userInfo] objectForKey: UIApplicationStatusBarOrientationUserInfoKey] integerValue];
	
    //if ([self shouldAutorotateToInterfaceOrientation:[[UIApplication sharedApplication] statusBarOrientation]] == NO)
	//	return;
    
	self.frame = [[UIScreen mainScreen] applicationFrame];
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Singleton definitons
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
