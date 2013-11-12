//
//  UIButton+SnapAdditions.m
//  Snap
//
//  Created by Kevin Casey on 8/18/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "UIButton+SnapAdditions.h"
#import "UIFont+SnapAdditions.h"

@implementation UIButton (SnapAdditions)

- (void)rw_applySnapStyle
{
    self.titleLabel.font = [UIFont rw_snapFontWithSize:20.0f];
    
    UIImage *butonImage = [[UIImage imageNamed:@"Button"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
    [self setBackgroundImage:butonImage forState:UIControlStateNormal];
    
    UIImage *pressedImage = [[UIImage imageNamed:@"ButtonPressed"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
    [self setBackgroundImage:pressedImage forState:UIControlStateHighlighted];
}

@end
