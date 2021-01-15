/*************************************************************************/
/*  view_controller.mm                                                   */
/*************************************************************************/
/*                       This file is part of:                           */
/*                           GODOT ENGINE                                */
/*                      https://godotengine.org                          */
/*************************************************************************/
/* Copyright (c) 2007-2021 Juan Linietsky, Ariel Manzur.                 */
/* Copyright (c) 2014-2021 Godot Engine contributors (cf. AUTHORS.md).   */
/*                                                                       */
/* Permission is hereby granted, free of charge, to any person obtaining */
/* a copy of this software and associated documentation files (the       */
/* "Software"), to deal in the Software without restriction, including   */
/* without limitation the rights to use, copy, modify, merge, publish,   */
/* distribute, sublicense, and/or sell copies of the Software, and to    */
/* permit persons to whom the Software is furnished to do so, subject to */
/* the following conditions:                                             */
/*                                                                       */
/* The above copyright notice and this permission notice shall be        */
/* included in all copies or substantial portions of the Software.       */
/*                                                                       */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,       */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF    */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.*/
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY  */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,  */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE     */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                */
/*************************************************************************/

#import "view_controller.h"

#include "core/project_settings.h"
#import "godot_view.h"
#import "godot_view_renderer.h"
#import "keyboard_input_view.h"
#import "native_video_view.h"
#include "os_iphone.h"

@interface ViewController ()

@property(strong, nonatomic) GodotViewRenderer *renderer;
@property(strong, nonatomic) GodotNativeVideoView *videoView;
@property(strong, nonatomic) GodotKeyboardInputView *keyboardView;

@end

@implementation ViewController

- (GodotView *)godotView {
	return (GodotView *)self.view;
}

- (void)loadView {
	GodotView *view = [[GodotView alloc] init];
	[view initializeRendering];

	GodotViewRenderer *renderer = [[GodotViewRenderer alloc] init];

	self.renderer = renderer;
	self.view = view;

	view.renderer = self.renderer;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

	if (self) {
		[self godot_commonInit];
	}

	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];

	if (self) {
		[self godot_commonInit];
	}

	return self;
}

- (void)godot_commonInit {
	// Initialize view controller values.
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	printf("*********** did receive memory warning!\n");
};

- (void)viewDidLoad {
	[super viewDidLoad];

	[self observeKeyboard];

	if (@available(iOS 11.0, *)) {
		[self setNeedsUpdateOfScreenEdgesDeferringSystemGestures];
	}
}

- (void)observeKeyboard {
	printf("******** setting up keyboard input view\n");
	self.keyboardView = [GodotKeyboardInputView new];
	[self.view addSubview:self.keyboardView];

	printf("******** adding observer for keyboard show/hide\n");
	[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(keyboardOnScreen:)
				   name:UIKeyboardDidShowNotification
				 object:nil];
	[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(keyboardHidden:)
				   name:UIKeyboardDidHideNotification
				 object:nil];
}

- (void)dealloc {
	[self.videoView stopVideo];
	self.videoView = nil;

	self.keyboardView = nil;

	self.renderer = nil;

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

// MARK: Orientation

- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures {
	return UIRectEdgeAll;
}

- (BOOL)shouldAutorotate {
	if (!OSIPhone::get_singleton()) {
		return NO;
	}

	switch (OS::get_singleton()->get_screen_orientation()) {
		case OS::SCREEN_SENSOR:
		case OS::SCREEN_SENSOR_LANDSCAPE:
		case OS::SCREEN_SENSOR_PORTRAIT:
			return YES;
		default:
			return NO;
	}
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	if (!OSIPhone::get_singleton()) {
		return UIInterfaceOrientationMaskAll;
	}

	switch (OS::get_singleton()->get_screen_orientation()) {
		case OS::SCREEN_PORTRAIT:
			return UIInterfaceOrientationMaskPortrait;
		case OS::SCREEN_REVERSE_LANDSCAPE:
			return UIInterfaceOrientationMaskLandscapeRight;
		case OS::SCREEN_REVERSE_PORTRAIT:
			return UIInterfaceOrientationMaskPortraitUpsideDown;
		case OS::SCREEN_SENSOR_LANDSCAPE:
			return UIInterfaceOrientationMaskLandscape;
		case OS::SCREEN_SENSOR_PORTRAIT:
			return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
		case OS::SCREEN_SENSOR:
			return UIInterfaceOrientationMaskAll;
		case OS::SCREEN_LANDSCAPE:
			return UIInterfaceOrientationMaskLandscapeLeft;
	}
}

- (BOOL)prefersStatusBarHidden {
	return YES;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
	if (GLOBAL_GET("display/window/ios/hide_home_indicator")) {
		return YES;
	} else {
		return NO;
	}
}

// MARK: Keyboard

- (void)keyboardOnScreen:(NSNotification *)notification {
	NSDictionary *info = notification.userInfo;
	NSValue *value = info[UIKeyboardFrameEndUserInfoKey];

	CGRect rawFrame = [value CGRectValue];
	CGRect keyboardFrame = [self.view convertRect:rawFrame fromView:nil];

	if (OSIPhone::get_singleton()) {
		OSIPhone::get_singleton()->set_virtual_keyboard_height(keyboardFrame.size.height);
	}
}

- (void)keyboardHidden:(NSNotification *)notification {
	if (OSIPhone::get_singleton()) {
		OSIPhone::get_singleton()->set_virtual_keyboard_height(0);
	}
}

// MARK: Native Video Player

- (BOOL)playVideoAtPath:(NSString *)filePath volume:(float)videoVolume audio:(NSString *)audioTrack subtitle:(NSString *)subtitleTrack {
	// If we are showing some video already, reuse existing view for new video.
	if (self.videoView) {
		return [self.videoView playVideoAtPath:filePath volume:videoVolume audio:audioTrack subtitle:subtitleTrack];
	} else {
		// Create autoresizing view for video playback.
		GodotNativeVideoView *videoView = [[GodotNativeVideoView alloc] initWithFrame:self.view.bounds];
		videoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self.view addSubview:videoView];

		self.videoView = videoView;

		return [self.videoView playVideoAtPath:filePath volume:videoVolume audio:audioTrack subtitle:subtitleTrack];
	}
}

@end
