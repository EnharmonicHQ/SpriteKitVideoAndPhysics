//
//  ENHMyScene.m
//  TestVideoCam
//
//  Created by Jonathan Saggau on 1/20/14.
//  Copyright (c) 2014 Enharmonic. All rights reserved.
//

#define USE_SWIFT_VID_CAM_IMPLEMENTATION (1)

#import "ENHMyScene.h"
#if USE_SWIFT_VID_CAM_IMPLEMENTATION

#define VID_CAM_CLASS ENHSWVideoCamToSKTexture
#import "TestVideoCam-Swift.h"

#else

#define VID_CAM_CLASS ENHVideoCamToSKTexture
#import "ENHVideoCamToSKTexture.h"

#endif

#define STRINGIFY(shader) #shader

const uint32_t kENHMySceneEdgeCollisionCategory = 0x1 << 1;
static const uint32_t nodeCategory = 0x1 << 2;

static const BOOL useFrontCam = YES;

static NSString *gravityFieldNodeName = @"GravityField";
static NSString *vortexFieldNodeName = @"VortexField";

static float randomFloatInRange(float min, float max)
{
    int r = arc4random_uniform(100000);
    return min + ((float)r / 100000.0f) * (max - min);
}

static CGPoint randomPointInsideRect(const CGRect rect)
{
    CGPoint minPoint = (CGPoint){.x = CGRectGetMinX(rect), .y = CGRectGetMinY(rect)};
    CGPoint maxPoint = (CGPoint){.x = CGRectGetMaxX(rect), .y = CGRectGetMaxY(rect)};
    CGPoint randPoint = (CGPoint){.x = randomFloatInRange(minPoint.x, maxPoint.x), .y = randomFloatInRange(minPoint.y, maxPoint.y)};
    return randPoint;
}

@interface ENHMyScene ()

@property(nonatomic, strong)VID_CAM_CLASS *camToTexture;
@property(readonly)SKFieldNode *gravityNode;
@property(readonly)SKFieldNode *vortexNode;

@end

@implementation ENHMyScene
{
    BOOL _textureIsReady;
}

static NSString *textureObservationContext = @"Texture Observation Key";
-(id)initWithSize:(CGSize)size {
    if (self = [super initWithSize:size]) {
        /* Setup your scene here */

        self.backgroundColor = [SKColor colorWithRed:0.15 green:0.15 blue:0.3 alpha:1.0];
        _camToTexture = [[VID_CAM_CLASS alloc] initWithCaptureSessionPreset:AVCaptureSessionPresetMedium useFrontCamera:useFrontCam];
        [_camToTexture startCapture];
        [_camToTexture addObserver:self
                        forKeyPath:@"texture"
                           options:NSKeyValueObservingOptionNew
                           context:&textureObservationContext];
    }
    return self;
}

-(void)didMoveToView:(SKView *)view
{
    if ([view respondsToSelector:@selector(setIgnoresSiblingOrder:)])
    {
        [view setIgnoresSiblingOrder:YES];
    }
    SKPhysicsBody *physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];
    [physicsBody setCategoryBitMask:kENHMySceneEdgeCollisionCategory];
    [physicsBody setCollisionBitMask:0];
    [physicsBody setContactTestBitMask:0];
    [self setPhysicsBody:physicsBody];
    
    SKPhysicsWorld *world = [self physicsWorld];
    [world setGravity:CGVectorMake(0, 0)];
}

-(CGRect)frameInMyCoordinateSystem
{
    CGSize size = [self size];
    CGPoint anchor = [self anchorPoint];
    CGRect frameInMyCoordinateSystem = (CGRect){.size = size, .origin = (CGPoint){.x = 1.0 - size.width * anchor.x, .y = 1.0 - size.height * anchor.y}};
    return frameInMyCoordinateSystem;
}

-(void)generatePhysics
{
    SKFieldNode *vortex = [SKFieldNode vortexField];
    [vortex setName:vortexFieldNodeName];
    [vortex setStrength:self.vortexStrength];
    [self addChild:vortex];
    
    SKFieldNode *centerOfGravity = [SKFieldNode radialGravityField];
    [centerOfGravity setName:gravityFieldNodeName];
    [centerOfGravity setFalloff:self.gravityFalloff];
    [centerOfGravity setStrength:self.gravityStrength];
    [self addChild:centerOfGravity];
}

-(void)generateABunchOfRandomQuads
{
    NSString *shaderStr = @STRINGIFY(
                                     void main()
                                     {
                                         vec2 tex_coord = vec2(v_tex_coord.x, 1.0 - v_tex_coord.y);
                                         gl_FragColor = (v_color_mix * texture2D(u_texture, tex_coord)).bgra;
                                     }
                                     );
    SKShader *shader = [SKShader shaderWithSource:shaderStr];

    for (NSInteger i=0; i<20; i++)
    {
        CGRect frame = [self frameInMyCoordinateSystem];
        CGPoint randomPoint = randomPointInsideRect(frame);
        SKSpriteNode *node = [self addRandomQuadWithPosition:randomPoint];
        [node setShader:shader];

#pragma unused(node)
    }
}

-(SKSpriteNode *)addRandomQuadWithPosition:(CGPoint)startPoint
{
    SKSpriteNode *node = nil;
    SKTexture *texture = [self.camToTexture texture];
    if (texture != nil)
    {
        CGSize textureSize = [texture size];
        CGFloat rando = randomFloatInRange(0.15, 0.4);
        CGSize spriteSize = textureSize;
        spriteSize.width *= rando;
        spriteSize.height *= rando;
        node = [SKSpriteNode spriteNodeWithTexture:texture size:spriteSize];
        [node setPosition:startPoint];
        [node setZRotation:useFrontCam ? 0 : M_PI];
        SKPhysicsBody *nodeBody = [SKPhysicsBody bodyWithRectangleOfSize:spriteSize];
        [nodeBody setMass:1.0];
        [nodeBody setAffectedByGravity:YES];
        [nodeBody setCategoryBitMask:nodeCategory];
        [nodeBody setCollisionBitMask:kENHMySceneEdgeCollisionCategory]; // | nodeCategory
        [nodeBody setRestitution:0.3]; //bounce
        [nodeBody setLinearDamping:0.3]; //friction
        [node setPhysicsBody:nodeBody];
        [self addChild:node];
        [nodeBody applyAngularImpulse:randomFloatInRange(0.0, 0.15)]; //random spin
    }
    return node;
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint location = [[touches anyObject] locationInNode:self];
    SKNode *node = [self addRandomQuadWithPosition:location];
#pragma unused(node)
}

-(void)setGravityStrength:(CGFloat)gravityStrength
{
    if (_gravityStrength != gravityStrength)
    {
        _gravityStrength = gravityStrength;
        [self.gravityNode setStrength:gravityStrength];
    }
}

-(void)setGravityFalloff:(CGFloat)gravityFalloff
{
    if (_gravityFalloff != gravityFalloff)
    {
        _gravityFalloff = gravityFalloff;
        [self.gravityNode setFalloff:gravityFalloff];
    }
}

-(void)setVortexStrength:(CGFloat)vortexStrength
{
    if (_vortexStrength != vortexStrength)
    {
        _vortexStrength = vortexStrength;
        [self.vortexNode setStrength:vortexStrength];
    }
}

-(SKFieldNode *)gravityNode
{
    return (id) [self childNodeWithName:gravityFieldNodeName];
}

-(SKFieldNode *)vortexNode
{
    return (id) [self childNodeWithName:vortexFieldNodeName];
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */

}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &textureObservationContext)
    {
        if (!_textureIsReady)
        {
            _textureIsReady = YES;
            [self generateABunchOfRandomQuads];
            [self generatePhysics];
            [self.camToTexture removeObserver:self
                                   forKeyPath:keyPath];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

-(void)dealloc
{
    if (!_textureIsReady)
    {
        [self.camToTexture removeObserver:self
                               forKeyPath:@"texture"];
    }
}

@end
