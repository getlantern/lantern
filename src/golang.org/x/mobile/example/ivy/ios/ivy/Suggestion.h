// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <UIKit/UIKit.h>

@protocol SuggestionDelegate <NSObject>

@required
- (void)suggestionReplace:(NSString *)text;
@end

@interface Suggestion : UIInputView

- (instancetype)init;
- (instancetype)initWithFrame:(CGRect)frame;
- (void)suggestFor:(NSString *)text;

@property (weak) id<SuggestionDelegate> delegate;

@end
