/**
* Copyright Maarten Billemont (http://www.lhunath.com, lhunath@lyndir.com)
*
* See the enclosed file LICENSE for license information (LGPLv3). If you did
* not receive this file, see http://www.gnu.org/licenses/lgpl-3.0.txt
*
* @author   Maarten Billemont <lhunath@lyndir.com>
* @license  http://www.gnu.org/licenses/lgpl-3.0.txt
*/

//
//  MPPasswordWindowController.h
//  MPPasswordWindowController
//
//  Created by lhunath on 2014-06-18.
//  Copyright, lhunath (Maarten Billemont) 2014. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "MPPasswordWindowController.h"
#import "MPMacAppDelegate.h"
#import "MPAppDelegate_Store.h"
#import "MPElementModel.h"
#import "MPAppDelegate_Key.h"

#define MPAlertIncorrectMP  @"MPAlertIncorrectMP"
#define MPAlertCreateSite   @"MPAlertCreateSite"

@implementation MPPasswordWindowController

#pragma mark - Life

- (void)windowDidLoad {

    [super windowDidLoad];

//    [[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationWillBecomeActiveNotification object:nil
//                                                       queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
//        [self fadeIn];
//    }];
//    [[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationWillResignActiveNotification object:nil
//                                                       queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
//        [self fadeOut];
//    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowDidBecomeKeyNotification object:self.window
                                                       queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [self fadeIn];
        [self updateUser];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowDidResignMainNotification object:self.window
                                                       queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [self fadeOut];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:MPSignedInNotification object:nil
                                                       queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [self updateUser];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:MPSignedOutNotification object:nil
                                                       queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [self updateUser];
    }];
}

#pragma mark - NSResponder

- (void)doCommandBySelector:(SEL)commandSelector {

    [self handleCommand:commandSelector];
}

#pragma mark - NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector {

    if (control == self.passwordField) {
        if (commandSelector == @selector( insertNewline: )) {
            NSString *password = self.passwordField.stringValue;
            [self.progressView startAnimation:self];
            [MPMacAppDelegate managedObjectContextPerformBlock:^(NSManagedObjectContext *moc) {
                MPUserEntity *activeUser = [[MPMacAppDelegate get] activeUserInContext:moc];
                NSString *userName = activeUser.name;
                BOOL success = [[MPMacAppDelegate get] signInAsUser:activeUser saveInContext:moc usingMasterPassword:password];

                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [self.progressView stopAnimation:self];
                    if (!success)
                        [[NSAlert alertWithError:[NSError errorWithDomain:MPErrorDomain code:0 userInfo:@{
                                NSLocalizedDescriptionKey : PearlString( @"Incorrect master password for user %@", userName )
                        }]] beginSheetModalForWindow:self.window modalDelegate:self
                                      didEndSelector:@selector( alertDidEnd:returnCode:contextInfo: ) contextInfo:MPAlertIncorrectMP];
                }];
            }];
            return YES;
        }
    }

    if (control == self.siteField) {
        if (commandSelector == @selector( moveUp: )) {
            [self.elementsController selectPrevious:self];
            return YES;
        }
        if (commandSelector == @selector( moveDown: )) {
            [self.elementsController selectNext:self];
            return YES;
        }
    }

    return [self handleCommand:commandSelector];
}

- (void)controlTextDidChange:(NSNotification *)note {

    if (note.object == self.siteField) {
        [self updateElements];

        // Update the site content as the site name changes.
//    if ([[NSApp currentEvent] type] == NSKeyDown &&
//        [[[NSApp currentEvent] charactersIgnoringModifiers] isEqualToString:@"\r"]) { // Return while completing.
//        [self useSite];
//        return;
//    }

//    if ([[NSApp currentEvent] type] == NSKeyDown &&
//        [[[NSApp currentEvent] charactersIgnoringModifiers] characterAtIndex:0] == 0x1b) { // Escape while completing.
//        [self trySiteWithAction:NO];
//        return;
//    }
    }
}

#pragma mark - NSTextViewDelegate

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {

    return [self handleCommand:commandSelector];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {

    return (NSInteger)[self.elements count];
}

#pragma mark - NSAlert

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {

    if (contextInfo == MPAlertIncorrectMP) {
        [self close];
        return;
    }
    if (contextInfo == MPAlertCreateSite) {
        switch (returnCode) {
            case NSAlertFirstButtonReturn: {
                // "Create" button.
                [[MPMacAppDelegate get] addElementNamed:[self.siteField stringValue] completion:^(MPElementEntity *element) {
                    if (element)
                        PearlMainQueue( ^{ [self updateElements]; } );
                }];
                break;
            }
            case NSAlertThirdButtonReturn:
                // "Cancel" button.
                break;
            default:
                break;
        }
    }
}

#pragma mark - State

- (void)insertObject:(MPElementModel *)model inElementsAtIndex:(NSUInteger)index {

    [self.elements insertObject:model atIndex:index];
}

- (void)removeObjectFromElementsAtIndex:(NSUInteger)index {

    [self.elements removeObjectAtIndex:index];
}

- (MPElementModel *)selectedElement {

    return [self.elementsController.selectedObjects firstObject];
}

#pragma mark - Private

- (BOOL)handleCommand:(SEL)commandSelector {

    if (commandSelector == @selector( insertNewline: )) {
        [self useSite];
        return YES;
    }
    if (commandSelector == @selector( cancel: ) || commandSelector == @selector( cancelOperation: )) {
        [self fadeOut];
        return YES;
    }

    return NO;
}

- (void)updateUser {

    [MPMacAppDelegate managedObjectContextForMainThreadPerformBlock:^(NSManagedObjectContext *mainContext) {
        MPUserEntity *mainActiveUser = [[MPMacAppDelegate get] activeUserInContext:mainContext];
        if (mainActiveUser) {
            if ([MPMacAppDelegate get].key) {
                self.inputLabel.stringValue = strf( @"%@'s password for:", mainActiveUser.name );
                [self.passwordField setHidden:YES];
                [self.siteField setHidden:NO];
                [self.siteTable setHidden:NO];
                [self.siteField becomeFirstResponder];
            }
            else {
                self.inputLabel.stringValue = strf( @"Enter %@'s master password:", mainActiveUser.name );
                [self.passwordField setHidden:NO];
                [self.siteField setHidden:YES];
                [self.siteTable setHidden:YES];
                [self.passwordField becomeFirstResponder];
            }
        }
        else {
            self.inputLabel.stringValue = @"";
            [self.passwordField setHidden:YES];
            [self.siteField setHidden:YES];
            [self.siteTable setHidden:YES];
        }

        self.passwordField.stringValue = @"";
        self.siteField.stringValue = @"";
        [self updateElements];
    }];
}

- (void)updateElements {

    if (![MPMacAppDelegate get].key) {
        self.elements = nil;
        return;
    }

    NSString *query = [self.siteField stringValue];
    [MPMacAppDelegate managedObjectContextPerformBlockAndWait:^(NSManagedObjectContext *context) {
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass( [MPElementEntity class] )];
        fetchRequest.sortDescriptors = [NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"lastUsed" ascending:NO]];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"(%@ == '' OR name BEGINSWITH[cd] %@) AND user == %@",
                                                                  query, query, [[MPMacAppDelegate get] activeUserInContext:context]];

        NSError *error = nil;
        NSArray *siteResults = [context executeFetchRequest:fetchRequest error:&error];
        if (!siteResults) {
            err( @"While fetching elements for completion: %@", error );
            return;
        }

        NSMutableArray *newElements = [NSMutableArray arrayWithCapacity:[siteResults count]];
        for (MPElementEntity *element in siteResults)
            [newElements addObject:[[MPElementModel alloc] initWithEntity:element]];
        self.elements = newElements;
    }];
}

- (void)useSite {

    MPElementModel *selectedElement = [self selectedElement];
    if (selectedElement) {
        // Performing action while content is available.  Copy it.
        [self copyContent:selectedElement.content];

        [self close];

        NSUserNotification *notification = [NSUserNotification new];
        notification.title = @"Password Copied";
        if (selectedElement.loginName.length)
            notification.subtitle = PearlString( @"%@ at %@", selectedElement.loginName, selectedElement.siteName );
        else
            notification.subtitle = selectedElement.siteName;
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    }
    else {
        NSString *siteName = [self.siteField stringValue];
        if ([siteName length])
            // Performing action without content but a site name is written.
            [self createNewSite:siteName];
    }
}

- (void)createNewSite:(NSString *)siteName {

    PearlMainQueue( ^{
        NSAlert *alert = [NSAlert new];
        [alert addButtonWithTitle:@"Create"];
        [alert addButtonWithTitle:@"Cancel"];
        [alert setMessageText:@"Create site?"];
        [alert setInformativeText:PearlString( @"Do you want to create a new site named:\n\n%@", siteName )];
        [alert beginSheetModalForWindow:self.window modalDelegate:self
                         didEndSelector:@selector( alertDidEnd:returnCode:contextInfo: ) contextInfo:MPAlertCreateSite];
    } );
}

- (void)copyContent:(NSString *)content {

    [[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    if (![[NSPasteboard generalPasteboard] setString:content forType:NSPasteboardTypeString]) {
        wrn( @"Couldn't copy password to pasteboard." );
        return;
    }

    [MPMacAppDelegate managedObjectContextPerformBlock:^(NSManagedObjectContext *moc) {
        [[self.selectedElement entityInContext:moc] use];
        [moc saveToStore];
    }];
}

- (void)fadeIn {

    CGWindowID windowID = (CGWindowID)[self.window windowNumber];
    CGImageRef capturedImage = CGWindowListCreateImage( CGRectInfinite, kCGWindowListOptionOnScreenBelowWindow, windowID,
            kCGWindowImageBoundsIgnoreFraming );
    NSImage *screenImage = [[NSImage alloc] initWithCGImage:capturedImage size:NSMakeSize(
            CGImageGetWidth( capturedImage ) / self.window.backingScaleFactor,
            CGImageGetHeight( capturedImage ) / self.window.backingScaleFactor )];

    NSImage *smallImage = [[NSImage alloc] initWithSize:NSMakeSize(
            CGImageGetWidth( capturedImage ) / 20,
            CGImageGetHeight( capturedImage ) / 20 )];
    [smallImage lockFocus];
    [screenImage drawInRect:(NSRect){ .origin = CGPointZero, .size = smallImage.size, }
                   fromRect:NSZeroRect
                  operation:NSCompositeSourceOver
                   fraction:1.0];
    [smallImage unlockFocus];

    self.blurView.image = smallImage;

    [self.window setFrame:self.window.screen.frame display:YES];
    [[NSAnimationContext currentContext] setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];
    [[self.window animator] setAlphaValue:1.0];
}

- (void)fadeOut {

    [[NSAnimationContext currentContext] setCompletionHandler:^{
        [self close];
    }];
    [[NSAnimationContext currentContext] setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];
    [[self.window animator] setAlphaValue:0.0];
}

@end
