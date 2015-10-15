//
//  ENHSWMyScene.swift
//  TestVideoCam
//
//  Created by Jonathan Saggau on 6/3/15.
//  Copyright (c) 2015 Enharmonic. All rights reserved.
//

import UIKit
import SpriteKit
import AVFoundation

struct ENHSWMySceneConstants
{
    static let edgeCategory = UInt32(0x1 << 1)
    static let nodeCategory = UInt32(0x1 << 2)
    static let useFrontCam = true
    static let gravityFieldNodeName = "GravityField"
    static let vortexFieldNodeName = "VortexField"
}

func randomDoubleInRange(min:Double, max:Double) -> Double
{
    let r:Double = Double(arc4random_uniform(UInt32(100000)))
    return min + (r / 100000.0) * (max - min)
}

func randomPointInsideRect(rect:CGRect) -> CGPoint
{
    let minPoint = CGPoint(x: CGRectGetMinX(rect), y: CGRectGetMinY(rect))
    let maxPoint = CGPoint(x: CGRectGetMaxX(rect), y: CGRectGetMaxY(rect))
    let randPoint = CGPoint(x: randomDoubleInRange(Double(minPoint.x), max: Double(maxPoint.x)),
                            y: randomDoubleInRange(Double(minPoint.y), max: Double(maxPoint.y)));
    return randPoint;
}

class ENHSWMyScene: SKScene {
    var textureIsReady = false

    var gravityStrength:Float {
        didSet(oldGravityStrength) {
            gravityNode?.strength = gravityStrength
        }
    }
    
    var gravityFalloff:Float {
        didSet(oldGravityFalloff) {
            gravityNode?.falloff = gravityFalloff
        }
    }
    
    var vortexStrength:Float {
        didSet(oldVortexStrength) {
            vortexNode?.strength = vortexStrength
        }
    }

    private var textureObservationContext = "Texture Observation Key"

    private var camToTexture:ENHSWVideoCamToSKTexture

    private var gravityNode:SKFieldNode? {
        get {
            return childNodeWithName(ENHSWMySceneConstants.gravityFieldNodeName) as! SKFieldNode?
        }
    }

    private var vortexNode:SKFieldNode? {
        get {
            return childNodeWithName(ENHSWMySceneConstants.vortexFieldNodeName) as! SKFieldNode?
        }
    }

    override init(size: CGSize)
    {
        gravityStrength = 0.0
        gravityFalloff = 0.0
        vortexStrength = 0.0
        camToTexture = ENHSWVideoCamToSKTexture(captureSessionPreset: AVCaptureSessionPresetMedium,
                                                      useFrontCamera: ENHSWMySceneConstants.useFrontCam)
        camToTexture.startCapture()

        super.init(size: size)
        camToTexture.addObserver(self, forKeyPath: "texture", options: NSKeyValueObservingOptions.New, context: &textureObservationContext)

        backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.3, alpha: 1.0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToView(view: SKView)
    {
        super.didMoveToView(view)
        view.ignoresSiblingOrder = true
        let physicsBody = SKPhysicsBody(edgeLoopFromRect: self.frame)
        physicsBody.categoryBitMask = ENHSWMySceneConstants.edgeCategory
        physicsBody.collisionBitMask = 0
        physicsBody.contactTestBitMask = 0
        self.physicsBody = physicsBody

        self.physicsWorld.gravity = CGVectorMake(0, 0)
    }

    private func frameInMyCoordinateSystem() -> CGRect
    {
        let size = self.size
        let anchor = self.anchorPoint
        let frameInMyCoordinateSystem = CGRect(origin: CGPoint(x: 1.0-size.width * anchor.x, y: 1.0 - size.height * anchor.y), size: size)
        return frameInMyCoordinateSystem
    }

    private func generatePhysics()
    {
        let vortex = SKFieldNode.vortexField()
        vortex.name = ENHSWMySceneConstants.vortexFieldNodeName
        vortex.strength = vortexStrength
        addChild(vortex)

        let centerOfGravity = SKFieldNode.radialGravityField()
        centerOfGravity.name = ENHSWMySceneConstants.gravityFieldNodeName
        centerOfGravity.strength = gravityStrength
        addChild(centerOfGravity)
    }

    private func generateABunchOfRandomQuads()
    {
        for _ in 0..<20
        {
            let frame = frameInMyCoordinateSystem()
            let randomPoint = randomPointInsideRect(frame)
            addRandomQuad(randomPoint)
        }
    }

    private func addRandomQuad(position:CGPoint) -> SKSpriteNode?
    {
        var node:SKSpriteNode? = nil
        if let texture = self.camToTexture.texture
        {
            let textureSize = texture.size()
            let rando = CGFloat(randomDoubleInRange(0.15, max: 0.4))
            var spriteSize = textureSize
            spriteSize.width *= rando
            spriteSize.height *= rando 
            node = SKSpriteNode(texture:texture, size:spriteSize)
            if let theNode = node
            {
                theNode.position = position
                theNode.zRotation = (ENHSWMySceneConstants.useFrontCam ? CGFloat(0.0) : CGFloat(M_PI))

                let nodeBody = SKPhysicsBody(rectangleOfSize: spriteSize)
                nodeBody.mass = 1.0
                nodeBody.affectedByGravity = true
                nodeBody.categoryBitMask = ENHSWMySceneConstants.nodeCategory
                nodeBody.collisionBitMask = ENHSWMySceneConstants.edgeCategory
                nodeBody.restitution = 0.3 //bounce
                nodeBody.linearDamping = 0.3 //friction
                theNode.physicsBody = nodeBody
                addChild(theNode)
                nodeBody.applyAngularImpulse(CGFloat(randomDoubleInRange(0.0, max: 0.15))) //random spin
            }
        }
        return nil
    }

    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        if let touch = touches.first 
        {
            let location = touch.locationInNode(self)
            addRandomQuad(location)
        }
    }

    override func update(currentTime: NSTimeInterval)
    {
        //print("update \(currentTime)")
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context == &textureObservationContext
        {
            textureIsReady = true
            generateABunchOfRandomQuads()
            generatePhysics()
            camToTexture.removeObserver(self, forKeyPath: "texture", context: &textureObservationContext)
        }
        else
        {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    deinit
    {
        if !textureIsReady
        {
            camToTexture.removeObserver(self, forKeyPath: "texture", context: &textureObservationContext)
        }
    }
}
