//
//  ENHViewController.m
//  TestVideoCam
//
//  Created by Jonathan Saggau on 1/20/14.
//  Copyright (c) 2014 Enharmonic. All rights reserved.
//

#import "ENHViewController.h"

#define USE_SWIFT_SCENE_IMPLEMENTATION (1)
#if USE_SWIFT_SCENE_IMPLEMENTATION

#define SCENE_CLASS ENHSWMyScene
#import "TestVideoCam-Swift.h"

#else

#define SCENE_CLASS ENHMyScene
#import "ENHMyScene.h"

#endif

@interface ENHViewController ()

@property(nonatomic, weak)IBOutlet UILabel *gravityFalloffLabel;
@property(nonatomic, weak)IBOutlet UILabel *gravityStrengthLabel;
@property(nonatomic, weak)IBOutlet UILabel *vortexStrengthLabel;

@end

@implementation ENHViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Configure the view.
    SKView * skView = (SKView *)self.view;
    skView.showsFPS = YES;
    skView.showsNodeCount = YES;
    
    // Create and configure the scene.
    SCENE_CLASS * scene = [SCENE_CLASS sceneWithSize:skView.bounds.size];
    scene.scaleMode = SKSceneScaleModeAspectFill;
    [scene setAnchorPoint:(CGPoint){0.5,0.5}];
    [scene setGravityStrength:5.0];
    [scene setGravityFalloff:1.1];
    [scene setVortexStrength:2.0];

    // Present the scene.
    [skView presentScene:scene];
    //[skView setFrameInterval:2]; //30 FPS should be fine.  Gives us some breathing room.
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (IBAction)gravityFalloffSliderSlid:(UISlider *)sender
{
    NSString *text = [@"Gravity Falloff " stringByAppendingFormat:@"%2.2f", (float)[sender value]];
    [self.gravityFalloffLabel setText:text];
    [self.scene setGravityFalloff:sender.value];
}

- (IBAction)gravityStrengthSliderSlid:(UISlider *)sender
{
    NSString *text = [@"Gravity Strength " stringByAppendingFormat:@"%2.2f", (float)[sender value]];
    [self.gravityStrengthLabel setText:text];
    [self.scene setGravityStrength:sender.value];
}

- (IBAction)vortexStrengthSliderSlid:(UISlider *)sender
{
    NSString *text = [@"Vortex Strength " stringByAppendingFormat:@"%2.2f", (float)[sender value]];
    [self.vortexStrengthLabel setText:text];
    [self.scene setVortexStrength:sender.value];
}

-(SKView *)skView
{
    return (id)[self view];
}

-(SCENE_CLASS *)scene
{
    return (id)[self.skView scene];
}


@end
