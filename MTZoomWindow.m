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


////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Defines
////////////////////////////////////////////////////////////////////////

#define kDefaultZoomAnimationOptions  UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
#define kDefaultZoomAnimationDuration 0.5f

#define kDefaultWidth  300
#define kDefaultHeight 300



////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Private Class Extension
////////////////////////////////////////////////////////////////////////

@interface MTZoomWindow ()

@property (nonatomic, retain) UIView *originalSuperview;
@property (nonatomic, assign) UIView *newSuperview;
@property (nonatomic) NSInteger subviewIndex;
@property (nonatomic) CGRect originalFrameInSuperview;
@property (nonatomic) CGRect originalFrameInWindow;
@property (nonatomic, getter=isScrollEnabledBefore) BOOL scrollEnabledBefore;

- (void)handleGesture:(UIGestureRecognizer *)gestureRecognizer;

- (void)saveProperties;
- (void)restoreProperties;
- (void)enableZoomedinPropertyState;

@end


@implementation MTZoomWindow

@synthesize backgroundView = backgroundView_;
@synthesize zoomedView = zoomedView_;
@synthesize originalSuperview = originalSuperview_;
@synthesize newSuperview = newSuperview_;
@synthesize subviewIndex = subviewIndex_;
@synthesize originalFrameInSuperview = originalFrameInSuperview_;
@synthesize originalFrameInWindow = originalFrameInWindow_;
@synthesize overlaySize = overlaySize_;
@synthesize windowGestureRecognizer = windowGestureRecognizer_;
@synthesize animationOptions = animationOptions_;
@synthesize animationDuration = animationDuration_;
@synthesize zoomedViewGestureRecognizer = zoomedViewGestureRecognizer_;
@synthesize scrollEnabledBefore = scrollEnabledBefore_;

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Lifecycle
////////////////////////////////////////////////////////////////////////

- (id)initWithTargetView:(UIView *)targetView gestureRecognizerClass:(Class)gestureRecognizerClass {
    if ((self = [super initWithFrame:[UIScreen mainScreen].bounds])) {
        self.windowLevel = UIWindowLevelStatusBar + 2.0f;
        self.backgroundColor = [UIColor clearColor];
        self.alpha = 0.0f;
        self.hidden = NO;

        overlaySize_ = CGSizeMake(kDefaultWidth,kDefaultHeight);
        zoomedView_ = [targetView retain];
        originalSuperview_ = [targetView.superview retain];
		newSuperview_ = self;
		scrollEnabledBefore_ = NO;
        animationOptions_ = kDefaultZoomAnimationOptions;
        animationDuration_ = kDefaultZoomAnimationDuration;

        backgroundView_ = [[UIView alloc] initWithFrame:self.frame];
        backgroundView_.backgroundColor = [UIColor blackColor];
        backgroundView_.alpha = 0.0f;
        [self addSubview:backgroundView_];

		// retreive index of zoomedView in superview
        subviewIndex_ = 0;
        for (UIView *subview in targetView.superview.subviews) {
            if (subview == targetView) {
                break;
            }

            subviewIndex_++;
        }

		// if the zoomed view is not scrollable, embed it in a scrollView
        if (![targetView isKindOfClass:[UIScrollView class]] && ![targetView isKindOfClass:NSClassFromString(@"MKMapView")]) {
            /*scrollView_ = [[[UIScrollView alloc] initWithFrame:self.frame] autorelease];
			 scrollView_.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            scrollView_.maximumZoomScale = 3.0f;
            scrollView_.showsVerticalScrollIndicator = NO;
            scrollView_.showsHorizontalScrollIndicator = NO;
            scrollView_.delegate = self;
            [self addSubview:scrollView_];

            newSuperview_ = scrollView_;*/
        }

        // Gesture Recognition to Zoom In/Out
        windowGestureRecognizer_ = [[gestureRecognizerClass alloc] initWithTarget:self
																		   action:@selector(handleGesture:)];
        zoomedViewGestureRecognizer_ = [[[gestureRecognizerClass alloc] initWithTarget:self
																				action:@selector(handleGesture:)] autorelease];

        [self addGestureRecognizer:windowGestureRecognizer_];
        [zoomedView_ addGestureRecognizer:zoomedViewGestureRecognizer_];
    }

    return self;
}

- (void)dealloc {
	[backgroundView_ release], backgroundView_ = nil;
	[zoomedView_ release], zoomedView_ = nil;
	[originalSuperview_ release], originalSuperview_ = nil;
	[zoomedViewGestureRecognizer_ release], zoomedViewGestureRecognizer_ = nil;
	[windowGestureRecognizer_ release], windowGestureRecognizer_ = nil;

    [super dealloc];
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Zooming
////////////////////////////////////////////////////////////////////////

- (void)zoomIn {
	// save frames before zoom operation
	self.originalFrameInWindow = [self.zoomedView convertRect:self.zoomedView.bounds toView:nil];
	self.originalFrameInSuperview = self.zoomedView.frame;

	// add to new superview
	[self.newSuperview addSubview:self.zoomedView];
	// the zoomedView now has another superview and therefore we must change it's frame
	// now it appears on the same place like before
	self.zoomedView.frame = self.originalFrameInWindow;
	// make the overlay-window visible
	self.alpha = 1.0f;
	// save important property-states that are changed during zooming
	[self saveProperties];

    // animate to fullscreen-display of imageView
    [UIView animateWithDuration:self.animationDuration 
                          delay:0. 
                        options:self.animationOptions
                     animations:^{
                         // make the black background visible
                         self.backgroundView.alpha = 1.0f;
                         // TODO: set new size depending on original frame
                         self.zoomedView.frame = CGRectMake((self.frame.size.width-self.overlaySize.width)/2,
                                                            (self.frame.size.height-self.overlaySize.height)/2,
                                                            self.overlaySize.width,
                                                            self.overlaySize.height);
                     }
                     completion:^(BOOL finished) {
                         [self enableZoomedinPropertyState];
                     }];
}

- (void)zoomOut {
    // animate to fullscreen-display of imageView
    [UIView animateWithDuration:self.animationDuration 
                          delay:0. 
                        options:self.animationOptions
                     animations:^{
                         // hide black background
                         self.backgroundView.alpha = 0.0f;
                         // set the frame of the imageView of the overlay back to original frame of image
                         [self.zoomedView setFrame:CGRectMake(self.originalFrameInWindow.origin.x, // + self.scrollView.contentOffset.x,
                                                              self.originalFrameInWindow.origin.y, // + self.scrollView.contentOffset.y,
                                                              self.originalFrameInWindow.size.width,
                                                              self.originalFrameInWindow.size.height)];
                     }
                     completion:^(BOOL finished) {
                         // reset frame to original frame in original superview
                         self.zoomedView.frame = self.originalFrameInSuperview;
                         // insert subview in original superview at original index
                         [self.originalSuperview insertSubview:self.zoomedView atIndex:self.subviewIndex];
                         // hide the overlay
                         self.alpha = 0.0f;
                         
						 [self restoreProperties];
                     }];
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
#pragma mark Private Methods
////////////////////////////////////////////////////////////////////////

- (void)handleGesture:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        // is the targetView currently zoomed in?
        if (self.zoomedView.superview == self) {
            [self zoomOut];
        }
		// currently zoomed out -> zoom in
		else {
            [self zoomIn];
        }
    }
}

- (void)saveProperties {
	 if ([self.zoomedView respondsToSelector:@selector(isScrollEnabled)]) {
		 id zoomedViewId = self.zoomedView;
		 self.scrollEnabledBefore = [zoomedViewId isScrollEnabled];
	 }
}
- (void)restoreProperties {
	if ([self.zoomedView respondsToSelector:@selector(setScrollEnabled:)]) {
		id targetId = self.zoomedView;
		[targetId setScrollEnabled:self.scrollEnabledBefore];
	}
}

- (void)enableZoomedinPropertyState {
	// this especially is useful for MKMapView that are not enabled to
	// scroll in their small frame -> when zoomed in you can scroll
	if ([self.zoomedView respondsToSelector:@selector(setScrollEnabled:)]) {
		[self.zoomedView performSelector:@selector(setScrollEnabled:) withObject:[NSNumber numberWithBool:YES]];
	}
}

@end
