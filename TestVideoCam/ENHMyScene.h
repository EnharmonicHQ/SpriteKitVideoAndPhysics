//
//  ENHMyScene.h
//  TestVideoCam
//

//  Copyright (c) 2014 Enharmonic. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

extern const uint32_t kENHMySceneEdgeCollisionCategory;

@interface ENHMyScene : SKScene

@property(nonatomic, assign)CGFloat gravityStrength;
@property(nonatomic, assign)CGFloat gravityFalloff;

@property(nonatomic, assign)CGFloat vortexStrength;

@end
