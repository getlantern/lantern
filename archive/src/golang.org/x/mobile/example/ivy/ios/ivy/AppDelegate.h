// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <UIKit/UIKit.h>
#import "Suggestion.h"
#import "IvyController.h"

@interface AppDelegate
    : UIResponder <UIApplicationDelegate, UITextFieldDelegate, UIWebViewDelegate>

@property (strong, nonatomic) UIWindow *window;

@end
