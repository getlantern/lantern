// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "Suggestion.h"

#define maxSuggestions 4 + 3

@implementation Suggestion {
    NSString *text;
    NSRange range;

    NSMutableOrderedSet *options;
    NSMutableArray *buttons;
    NSArray *possibleSuggestions;
    NSCharacterSet *breakingChars;
}

- (instancetype)init
{
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    self = [self initWithFrame:CGRectMake(0.0f, 0.0f, screenWidth, 36.0f)];
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame inputViewStyle:UIInputViewStyleKeyboard];
    if (self) {
        possibleSuggestions = @[
            @")base ",
            @")debug ",
            @")format ",
            @")maxdigits ",
            @")op ",
            @")origin ",
            @")prec ",
            @")prompt ",
            @")seed ",
            @"cos ",
            @"iota ",
            @"log ",
            @"max ",
            @"min ",
            @"pi ",
            @"rho ",
            @"sin ",
            @"sqrt ",
            @"tan "
        ];
        breakingChars =
            [NSCharacterSet characterSetWithCharactersInString:@"/+-*,^|= "];
        options = [[NSMutableOrderedSet alloc] initWithCapacity:maxSuggestions];
        buttons = [[NSMutableArray alloc] init];
        self.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.05f];
        [self setSuggestions:nil];
    }
    return self;
}

- (void)suggestFor:(NSString *)t
{
    text = t;
    range =
        [text rangeOfCharacterFromSet:breakingChars options:NSBackwardsSearch];
    if (range.location == NSNotFound) {
        range.location = 0;
        range.length = text.length;
    } else {
        if (range.location > 0 &&
            [text characterAtIndex:range.location - 1] == ')') {
            // Special case for suggestions that start with ") ".
            range.location -= 1;
            range.length++;
        } else {
            range.location += 1;
            range.length -= 0;
        }
    }
    range.length = text.length - range.location;
    if (range.length == 0) {
        [self setSuggestions:nil];
    } else {
        NSString *prefix = [text substringWithRange:range];
        // TODO: make not so slow.
        NSArray *suggestions = @[];
        for (NSString *suggestion in possibleSuggestions) {
            if ([suggestion hasPrefix:prefix] && prefix.length < suggestion.length) {
                suggestions = [suggestions arrayByAddingObject:suggestion];
            }
        }
        if (suggestions.count > 3) {
            suggestions = nil;
        }
        [self setSuggestions:suggestions];
    }
    [self setNeedsLayout];
}

- (void)setSuggestions:(NSArray *)suggestions
{
    [options removeAllObjects];

    if ([suggestions respondsToSelector:
                         @selector(countByEnumeratingWithState:objects:count:)]) {
        for (NSString *suggestion in suggestions) {
            if (options.count < maxSuggestions) {
                [options addObject:suggestion];
            } else {
                break;
            }
        }
    }
}

- (void)layoutSubview:(NSString *)t at:(CGFloat)x width:(CGFloat)w
{
    UIButton *b = [[UIButton alloc]
        initWithFrame:CGRectMake(x, 0.0f, w, self.bounds.size.height)];
    [b setTitle:t forState:UIControlStateNormal];
    b.titleLabel.adjustsFontSizeToFitWidth = YES;
    b.titleLabel.textAlignment = NSTextAlignmentCenter;
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [b addTarget:self
                  action:@selector(buttonTouched:)
        forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:b];

    if (x > 0) {
        UIView *line = [[UIView alloc]
            initWithFrame:CGRectMake(0.0f, 0.0f, 0.5f, self.bounds.size.height)];
        line.backgroundColor =
            [UIColor colorWithRed:0.984 green:0.977 blue:0.81 alpha:1.0];
        [b addSubview:line];
    }

    [buttons addObject:b];
}

- (void)layoutSubviews
{
    for (UIView *subview in buttons) {
        [subview removeFromSuperview];
    }
    [buttons removeAllObjects];

    CGFloat symbolWidth = 40.0f;
    [self layoutSubview:@"+" at:0 * symbolWidth width:symbolWidth];
    [self layoutSubview:@"-" at:1 * symbolWidth width:symbolWidth];
    [self layoutSubview:@"*" at:2 * symbolWidth width:symbolWidth];
    [self layoutSubview:@"/" at:3 * symbolWidth width:symbolWidth];

    for (int i = 0; i < options.count; i++) {
        NSString *suggestion = options[i];
        CGFloat width =
            (self.bounds.size.width - (4 * symbolWidth)) / options.count;
        CGFloat x = (4 * symbolWidth) + (i * width);
        [self layoutSubview:suggestion at:x width:width];
    }
}

- (void)buttonTouched:(UIButton *)button
{
    NSTimeInterval duration = 0.08f;
    [UIView
        animateWithDuration:duration
                 animations:^{
                 [button setBackgroundColor:[UIColor whiteColor]];

                 if ([self.delegate
                         respondsToSelector:@selector(suggestionReplace:)]) {
                   NSString *t = text;
                   if (t == nil) {
                     t = @"";
                   }
                   if (button.currentTitle.length == 1) {
                     // Special case for +, -, *, /.
                     t = [t stringByAppendingString:button.currentTitle];
                   } else {
                     t = [text stringByReplacingCharactersInRange:
                                   range withString:button.currentTitle];
                   }
                   [self performSelector:@selector(suggestionReplace:)
                              withObject:t
                              afterDelay:duration * 0.8f];
                 }
                 [button performSelector:@selector(setBackgroundColor:)
                              withObject:[UIColor clearColor]
                              afterDelay:duration];
                 }];
}

- (void)suggestionReplace:(NSString *)t
{
    [self.delegate performSelector:@selector(suggestionReplace:) withObject:t];
}

@end
