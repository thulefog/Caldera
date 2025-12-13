//
//  TextureDisplayView.swift
//
//  Created by John Matthew Weston on 12/12/25.
//

import SwiftUI
import MetalKit

struct TextureDisplayViewport: View {
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

class TextureDisplayView: MTKView {
    
    private var commandQueue: MTLCommandQueue!
    private var renderPipelineState: MTLRenderPipelineState!
    private var samplerState: MTLSamplerState!
    
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
}

struct MetalTextureView: UIViewRepresentable { // Use UIViewRepresentable for iOS
    let texture: MTLTexture?
    
    func makeUIView(context: Context) -> TextureDisplayView {
        let device = MTLCreateSystemDefaultDevice()!
        let view = TextureDisplayView(frame: .zero, device: device)!
        return view
    }
    
    func updateUIView(_ view: TextureDisplayView, context: Context) {
        view.displayTexture = texture
    }
}
