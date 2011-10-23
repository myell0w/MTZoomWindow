//
//  UIView+MTZoom.m
//  MTZoomWindow
//
//  Created by Tretter Matthias on 23.10.11.
//  Copyright (c) 2011 NOUS Wissensmanagement GmbH. All rights reserved.
//

#import "UIView+MTZoom.h"
#import "MTZoomWindow.h"
#import <objc/runtime.h>

static char wrapKey;
static char sizeKey;
static char placeholderKey;

@implementation UIView (MTZoom)

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Zooming
////////////////////////////////////////////////////////////////////////

- (void)zoomIn {
    [self zoomInWithPreparation:nil completion:nil];
}

- (void)zoomOut {
    [self zoomOutWithPreparation:nil completion:nil];
}

- (void)zoomInWithPreparation:(mt_zoom_block)preparationBlock completion:(mt_zoom_block)completionBlock {
    UIView *superview = self.superview;
    MTZoomWindow *zoomWindow = [MTZoomWindow sharedWindow];
    UIView *placeholderView = [[[UIView alloc] initWithFrame:self.frame] autorelease];
    
    // setup invisible copy of self
    placeholderView.autoresizingMask = self.autoresizingMask;
    [superview insertSubview:placeholderView belowSubview:self];
    self.zoomPlaceholderView = placeholderView;
    
    // call preparation-block before we are zooming in
    if (preparationBlock != nil) {
        preparationBlock();
    }
    
    // Zoom view into fullscreen-mode and call completion-block
    [zoomWindow zoomView:self toSize:self.zoomedSize completion:completionBlock];
}

- (void)zoomOutWithPreparation:(mt_zoom_block)preparationBlock completion:(mt_zoom_block)completionBlock {
    MTZoomWindow *zoomWindow = [MTZoomWindow sharedWindow];
    
    // call preparation-block before we are zooming out
    if (preparationBlock != nil) {
        preparationBlock();
    }
    
    // zoom view back to original frame and call completion-block
    [zoomWindow zoomOutWithCompletion:completionBlock];
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Properties
////////////////////////////////////////////////////////////////////////

- (void)setWrapInScrollviewWhenZoomed:(BOOL)wrapInScrollviewWhenZoomed {
    objc_setAssociatedObject(self, &wrapKey, [NSNumber numberWithBool:wrapInScrollviewWhenZoomed], OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)isWrappedInScrollviewWhenZoomed {
    BOOL wrapSetByUser = [objc_getAssociatedObject(self, &wrapKey) boolValue];
    
    // scrollviews don't get wrapped in another scrollview
    return wrapSetByUser && ![self isKindOfClass:[UIScrollView class]] && ![self isKindOfClass:NSClassFromString(@"MKMapView")];
}

- (void)setZoomedSize:(CGSize)zoomedSize {
    objc_setAssociatedObject(self, &sizeKey, [NSValue valueWithCGSize:zoomedSize], OBJC_ASSOCIATION_RETAIN);
}

- (CGSize)zoomedSize {
    return [objc_getAssociatedObject(self, &sizeKey) CGSizeValue];
}

- (void)setZoomPlaceholderView:(UIView *)zoomPlaceholderView {
    objc_setAssociatedObject(self, &placeholderKey, zoomPlaceholderView, OBJC_ASSOCIATION_RETAIN);
}

- (UIView *)zoomPlaceholderView {
    return (UIView *)objc_getAssociatedObject(self, &placeholderKey);
}

@end
