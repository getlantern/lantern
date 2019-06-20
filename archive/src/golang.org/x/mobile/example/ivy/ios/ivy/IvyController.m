// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "IvyController.h"
#import "mobile/Mobile.h"

@interface IvyController ()

@end

@implementation IvyController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.input = (UITextField *)[self.view viewWithTag:1];
    self.input.delegate = self;
    self.input.autocorrectionType = UITextAutocorrectionTypeNo;
    self.input.keyboardType = UIKeyboardTypeNumbersAndPunctuation;

    self.suggestionView = [[Suggestion alloc] init];
    self.suggestionView.delegate = self;

    self.tape = (UIWebView *)[self.view viewWithTag:2];
    self.tape.delegate = self;

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(textDidChange:)
               name:UITextFieldTextDidChangeNotification
             object:self.input];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(keyboardWillShow:)
               name:UIKeyboardWillShowNotification
             object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(keyboardWillHide:)
               name:UIKeyboardWillHideNotification
             object:nil];

    NSURL *bundleURL =
        [[NSBundle mainBundle] URLForResource:@"tape" withExtension:@"html"];
    NSURLRequest *request = [NSURLRequest requestWithURL:bundleURL];
    [self.tape loadRequest:request];
    self.tape.delegate = self;
    [self.input becomeFirstResponder];
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if ([textField isEqual:self.input]) {
        textField.inputAccessoryView = self.suggestionView;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        [textField reloadInputViews];
    }
    return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    if ([textField isEqual:self.input]) {
        textField.inputAccessoryView = nil;
        [textField reloadInputViews];
    }
    return YES;
}

- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)str
{
    if ([str isEqualToString:@"\n"]) {
        [self
            appendTape:[NSString stringWithFormat:@"<b>%@</b>", [self.input text]]];
        NSString *expr = [self.input.text stringByAppendingString:@"\n"];
        NSString *result;
        NSError *err = [NSError alloc];
        if (!GoMobileEval(expr, &result, &err)) {
            result = err.description;
        }
        result = [result
            stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        result =
            [result stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
        result =
            [result stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
        NSMutableArray *lines =
            (NSMutableArray *)[result componentsSeparatedByString:@"\n"];
        for (NSMutableString *line in lines) {
            [self appendTape:line];
        }
        self.input.text = @"";
        return NO;
    }

    return YES;
}

- (void)textDidChange:(NSNotification *)notif
{
    [self.suggestionView suggestFor:self.input.text];
}

- (void)suggestionReplace:(NSString *)text
{
    self.input.text = text;
    [self.suggestionView suggestFor:text];
}

- (void)keyboardWillShow:(NSNotification *)aNotification
{
    // Move the input text field up, as the keyboard has taken some of the screen.
    NSDictionary *info = [aNotification userInfo];
    CGRect kbFrame =
        [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSNumber *duration =
        [info objectForKey:UIKeyboardAnimationDurationUserInfoKey];

    UIViewAnimationCurve keyboardTransitionAnimationCurve;
    [[info valueForKey:UIKeyboardAnimationCurveUserInfoKey]
        getValue:&keyboardTransitionAnimationCurve];
    UIViewAnimationOptions options =
        keyboardTransitionAnimationCurve | keyboardTransitionAnimationCurve << 16;

    [UIView animateWithDuration:duration.floatValue
        delay:0
        options:options
        animations:^{
        self.bottomConstraint.constant = kbFrame.size.height + 32;
        [self.view layoutIfNeeded];
        }
        completion:^(BOOL finished) {
        [self scrollTapeToBottom];
        }];
}

- (void)keyboardWillHide:(NSNotification *)aNotification
{
    // Move the input text field back down.
    NSDictionary *info = [aNotification userInfo];
    NSNumber *duration =
        [info objectForKey:UIKeyboardAnimationDurationUserInfoKey];

    UIViewAnimationCurve keyboardTransitionAnimationCurve;
    [[info valueForKey:UIKeyboardAnimationCurveUserInfoKey]
        getValue:&keyboardTransitionAnimationCurve];
    UIViewAnimationOptions options =
        keyboardTransitionAnimationCurve | keyboardTransitionAnimationCurve << 16;

    [UIView animateWithDuration:duration.floatValue
        delay:0
        options:options
        animations:^{
        self.bottomConstraint.constant = 32;
        [self.view layoutIfNeeded];
        }
        completion:^(BOOL finished) {
        [self scrollTapeToBottom];
        }];
}

- (void)scrollTapeToBottom
{
    NSString *scroll = @"window.scrollBy(0, document.body.offsetHeight);";
    [self.tape stringByEvaluatingJavaScriptFromString:scroll];
}

- (void)appendTape:(NSString *)text
{
    NSString *injectSrc = @"appendDiv('%@');";
    NSString *runToInject = [NSString stringWithFormat:injectSrc, text];
    [self.tape stringByEvaluatingJavaScriptFromString:runToInject];
}

@end
