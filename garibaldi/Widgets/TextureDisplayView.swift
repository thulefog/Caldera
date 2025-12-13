//
//  TextureDisplayView.swift
//
//  Created by John Matthew Weston on 12/12/25.
//

import SwiftUI
import MetalKit

// MARK: Metal Texture Viewport (outer)

struct MetalTextureViewport: View {
    @State private var texture: MTLTexture?
    
    var body: some View {
        MetalTextureView(texture: texture)
            .onAppear { loadTexture() }
    }
    
    private func loadTexture() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let url = Bundle.main.url(forResource: "00033", withExtension: "png") else {
            return
        }
        
        let loader = MTKTextureLoader(device: device)
        texture = try? loader.newTexture(URL: url, options: [
            .SRGB: false,
            .generateMipmaps: false
        ])
    }
}

// MARK: - Aspect Ratio Handling

enum AspectRatioMode {
    case fit       // Letterbox/pillarbox to fit entirely
    case fill      // Crop to fill the view
    case stretch   // Distort to fill
}


// MARK: Texture Display View (inner)

class TextureDisplayView: MTKView {
    
    private var commandQueue: MTLCommandQueue!
    private var renderPipelineState: MTLRenderPipelineState!
    private var samplerState: MTLSamplerState!
    private var vertexBuffer: MTLBuffer!
    
    var aspectRatioMode: AspectRatioMode = .fit {
        didSet { updateVertexBuffer() }
    }
    
    // The texture to display
    var displayTexture: MTLTexture? {
        didSet { setNeedsDisplay() }
    }
    
    // MARK: - Initialization
    
    init?(frame: CGRect, device: MTLDevice) {
        super.init(frame: frame, device: device)
        commonInit()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        self.device = MTLCreateSystemDefaultDevice()
        commonInit()
    }
    
    private func commonInit() {
        guard let device = self.device else { return }
        
        commandQueue = device.makeCommandQueue()
        
        // Configure view
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true
        enableSetNeedsDisplay = true  // Manual refresh mode
        isPaused = true               // We'll draw on demand
        
        setupPipeline()
        setupSampler()
    }
    
    // MARK: - Pipeline Setup
    
    private func setupPipeline() {
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };
        
        vertex VertexOut vertex_passthrough(uint vertexID [[vertex_id]]) {
            // Full-screen quad using vertex ID
            float2 positions[4] = {
                float2(-1, -1),
                float2( 1, -1),
                float2(-1,  1),
                float2( 1,  1)
            };
            
            float2 texCoords[4] = {
                float2(0, 1),
                float2(1, 1),
                float2(0, 0),
                float2(1, 0)
            };
            
            VertexOut out;
            out.position = float4(positions[vertexID], 0, 1);
            out.texCoord = texCoords[vertexID];
            return out;
        }
        
        fragment float4 fragment_texture(VertexOut in [[stage_in]],
                                         texture2d<float> texture [[texture(0)]],
                                         sampler textureSampler [[sampler(0)]]) {
            return texture.sample(textureSampler, in.texCoord);
        }
        """
        
        guard let device = self.device,
              let library = try? device.makeLibrary(source: shaderSource, options: nil) else {
            fatalError("Failed to create shader library")
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertex_passthrough")
        descriptor.fragmentFunction = library.makeFunction(name: "fragment_texture")
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    private func setupSampler() {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        samplerState = device?.makeSamplerState(descriptor: descriptor)
    }
    
    // MARK: - Drawing
    
    override func draw(_ rect: CGRect) {
        guard let texture = displayTexture,
              let drawable = currentDrawable,
              let descriptor = currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func updateVertexBuffer() {
        let viewAspect = drawableSize.width / drawableSize.height
        let textureAspect: CGFloat
        
        if let texture = displayTexture {
            textureAspect = CGFloat(texture.width) / CGFloat(texture.height)
        } else {
            textureAspect = 16.0 / 9.0
        }
        
        var scaleX: Float = 1.0
        var scaleY: Float = 1.0
        
        switch aspectRatioMode {
        case .fit:
            if viewAspect > textureAspect {
                scaleX = Float(textureAspect / viewAspect)
            } else {
                scaleY = Float(viewAspect / textureAspect)
            }
        case .fill:
            if viewAspect > textureAspect {
                scaleY = Float(viewAspect / textureAspect)
            } else {
                scaleX = Float(textureAspect / viewAspect)
            }
        case .stretch:
            break
        }
        
        struct Vertex {
            var position: SIMD2<Float>
            var texCoord: SIMD2<Float>
        }
        
        let vertices: [Vertex] = [
            Vertex(position: SIMD2(-scaleX, -scaleY), texCoord: SIMD2(0, 1)),
            Vertex(position: SIMD2( scaleX, -scaleY), texCoord: SIMD2(1, 1)),
            Vertex(position: SIMD2(-scaleX,  scaleY), texCoord: SIMD2(0, 0)),
            Vertex(position: SIMD2( scaleX,  scaleY), texCoord: SIMD2(1, 0)),
        ]
        
        vertexBuffer = device?.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<Vertex>.stride * vertices.count,
            options: .storageModeShared
        )
    }
}

import SwiftUI

#if os(iOS)
typealias ViewRepresentable = UIViewRepresentable
#else
typealias ViewRepresentable = NSViewRepresentable
#endif

struct MetalTextureView: ViewRepresentable {
    let texture: MTLTexture?
    
    func makeNSView(context: Context) -> TextureDisplayView {
        let device = MTLCreateSystemDefaultDevice()!
        let view = TextureDisplayView(frame: .zero, device: device)!
        return view
    }
    
    func updateNSView(_ view: TextureDisplayView, context: Context) {
        view.displayTexture = texture
    }
    
    #if os(iOS)
    func makeUIView(context: Context) -> TextureDisplayView {
        makeView(context: context)
    }

    func updateUIView(_ view: TextureDisplayView, context: Context) {
        updateView(view, context: context)
    }
    #else
    func makeNSView(context: Context) -> TextureDisplayView {
        makeView()
    }

    func updateNSView(_ view: TextureDisplayView, context: Context) {
        updateView(view)
    }
    #endif


    func makeView(context: Context) -> TextureDisplayView {
        let device = MTLCreateSystemDefaultDevice()!
        let view = TextureDisplayView(frame: .zero, device: device)!
        view.aspectRatioMode = .fit
        return view
    }
    
    func updateView(_ view: TextureDisplayView, context: Context) {
        view.displayTexture = texture
    }
}
