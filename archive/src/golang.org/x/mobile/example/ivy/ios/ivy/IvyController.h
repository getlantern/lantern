// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <UIKit/UIKit.h>
#import "Suggestion.h"

// IvyController displays the main app view.
@interface IvyController
    : UIViewController <UITextFieldDelegate, UIWebViewDelegate,
                        SuggestionDelegate>

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomConstraint;

// A text input field coupled to an output "tape", rendered with a UIWebView.
@property (strong, nonatomic) UITextField *input;
@property (strong, nonatomic) Suggestion *suggestionView;
@property (strong, nonatomic) UIWebView *tape;

@end
