// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "DocsController.h"
#import "mobile/Mobile.h"

@interface DocsController ()

@end

@implementation DocsController

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIWebView *webView = (UIWebView *)[self.view viewWithTag:11];
    NSString *helpHTML = GoMobileHelp();
    [webView loadHTMLString:helpHTML baseURL:NULL];
    if ([self respondsToSelector:@selector(
                                     setAutomaticallyAdjustsScrollViewInsets:)]) {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
