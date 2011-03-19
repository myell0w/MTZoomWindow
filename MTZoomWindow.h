//
//  MTZoomWindow.h
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


#import <Foundation/Foundation.h>


@interface MTZoomWindow : UIWindow <UIScrollViewDelegate> {
    // the black background
    UIView *backgroundView_;
	// the view we want to zoom
    UIView *zoomedView_;
    // the original superview of our zoomed view
    UIView *originalSuperview_;
	// the new superview of our zoomed view (either the window itself, or a scrollView)
	UIView *newSuperview_;
	// the index our zoomed view had in it's superview
    NSInteger subviewIndex_;
	// the original frame of our zoomed view in it's superviews bounds
    CGRect originalFrameInSuperview_;
	// the original frame of our zoomed view in the mainScreens bounds
    CGRect originalFrameInWindow_;
	// the size we want our view to zoom into
    CGSize overlaySize_;
	// saves if scrolling was enabled on zoomedView before zooming in
	BOOL scrollEnabledBefore_;
    // animation options
    UIViewAnimationOptions animationOptions_;
    // animation duration
    NSTimeInterval animationDuration_;

	// Gesture recognizer on the zoomedView
	UIGestureRecognizer *zoomedViewGestureRecognizer_;
	// Gesture Recognizer on the window itself
	UIGestureRecognizer *windowGestureRecognizer_;
}

@property (nonatomic, retain) UIView *backgroundView;
@property (nonatomic, retain) UIView *zoomedView;
@property (nonatomic, assign) CGSize overlaySize;
@property (nonatomic, retain) UIGestureRecognizer *zoomedViewGestureRecognizer;
@property (nonatomic, retain) UIGestureRecognizer *windowGestureRecognizer;
@property (nonatomic) UIViewAnimationOptions animationOptions;
@property (nonatomic) NSTimeInterval animationDuration;


- (id)initWithTargetView:(UIView *)targetView gestureRecognizerClass:(Class)gestureRecognizerClass;
- (id)initWithTargetView:(UIView *)targetView gestureRecognizerClass:(Class)gestureRecognizerClass wrapInScrollView:(BOOL)wrapInScrollView;

@end
