//
//  SurfaceRenderPointCloudView.swift
//
//  Created by John Matthew Weston on 7/2/25.
//

import SwiftUI
import SceneKit
import UniformTypeIdentifiers

// MARK: - SurfaceRenderPointCloudView View

struct SurfaceRenderPointCloudView: View {
    @State private var selectedFileURL: URL?
    @State private var showingFilePicker = false
    @State private var scene: SCNScene?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if let scene = scene {
                    /*
                    SceneView(
                        scene: scene,
                        pointOfView: nil,
                        options: [.allowsCameraControl, .autoenablesDefaultLighting]
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    */
                    SceneView(
                        scene: scene,
                        pointOfView: nil,
                        options: [.allowsCameraControl, .autoenablesDefaultLighting, .rendersContinuously],
                        preferredFramesPerSecond: 60,
                        antialiasingMode: .multisampling4X,
                        delegate: nil,
                        technique: nil
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No 3D file loaded")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                        
                        if isLoading {
                            ProgressView("Loading 3D file...")
                                .padding()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("3D File Viewer")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("Open File") {
                            showingFilePicker = true
                        }
                    } label: {
                        Label("toolbar", systemImage: "mountain.2")
                    }
                } // toolbaritem
                if scene != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Clear") {
                            scene = nil
                            selectedFileURL = nil
                            errorMessage = nil
                        }
                    }
                }
            } // toolbar
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "stl")!,
                UTType(filenameExtension: "obj")!
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedFileURL = url
                    load3DFile(from: url)
                }
            case .failure(let error):
                errorMessage = "Failed to select file: \(error.localizedDescription)"
            }
        }
    }
    
    private func load3DFile(from url: URL) {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Access the security scoped resource
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                let fileExtension = url.pathExtension.lowercased()
                let data = try Data(contentsOf: url)
                
                let geometry: SCNGeometry
                let materials: [SCNMaterial]
                
                switch fileExtension {
                case "stl":
                    geometry = try parseSTLFile(data: data)
                    materials = [createDefaultMaterial(color: .systemBlue)]
                case "obj":
                    let objResult = try parseOBJFile(data: data, baseURL: url.deletingLastPathComponent())
                    geometry = objResult.geometry
                    materials = objResult.materials.isEmpty ? [createDefaultMaterial(color: .systemGray)] : objResult.materials
                default:
                    throw FileError.unsupportedFormat
                }
                
                DispatchQueue.main.async {
                    createScene(with: geometry, materials: materials)
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Failed to load 3D file: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    /*
    private func createScene(with geometry: SCNGeometry, materials: [SCNMaterial] = []) {
        let newScene = SCNScene()
        
        newScene.background.contents = UIColor.black
        
        // Apply materials or create default
        if materials.isEmpty {
            geometry.materials = [createDefaultMaterial(color: .systemBlue)]
        } else {
            geometry.materials = materials
        }
        
        // Create node
        let modelNode = SCNNode(geometry: geometry)
        newScene.rootNode.addChildNode(modelNode)
        
        // Add lighting
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.light!.color = UIColor.white
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        newScene.rootNode.addChildNode(lightNode)
        
        // Add ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.color = UIColor.darkGray
        newScene.rootNode.addChildNode(ambientLight)
        
        // Center the model
        centerModel(node: modelNode)
        
        scene = newScene
    }
    
     */
    private func createDefaultMaterial(color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.specular.contents = UIColor.white
        material.shininess = 0.8
        return material
    }
    
    private func centerModel(node: SCNNode) {
        let (min, max) = node.boundingBox
        let center = SCNVector3(
            x: (min.x + max.x) / 2,
            y: (min.y + max.y) / 2,
            z: (min.z + max.z) / 2
        )
        
        node.position = SCNVector3(-center.x, -center.y, -center.z)
    }

    
    private func createScene(with geometry: SCNGeometry, materials: [SCNMaterial] = []) {
        let newScene = SCNScene()
        
        // Set scene background
        newScene.background.contents = UIColor.black
        
        // Apply materials or create default
        if materials.isEmpty {
            geometry.materials = [createDefaultMaterial(color: .systemBlue)]
        } else {
            geometry.materials = materials
        }
        
        // Create node
        let modelNode = SCNNode(geometry: geometry)
        newScene.rootNode.addChildNode(modelNode)
        
        // Center the model BEFORE setting up camera
        centerModel(node: modelNode)
        
        // Add camera explicitly
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 5)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        newScene.rootNode.addChildNode(cameraNode)
        
        // Add lighting
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.light!.color = UIColor.white
        lightNode.light!.intensity = 1000
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        newScene.rootNode.addChildNode(lightNode)
        
        // Add ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.color = UIColor(white: 0.5, alpha: 1.0)
        ambientLight.light!.intensity = 1000
        newScene.rootNode.addChildNode(ambientLight)
        
        scene = newScene
    }
}

//...



/*
struct SurfaceRenderPointCloudViewSK: View {
@StateObject private var modelManager = ModelManager()
@State private var showingFilePicker = false


var body: some View {
    NavigationView {
        VStack {
            if modelManager.currentModel != nil {
                SceneView3D(modelManager: modelManager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                ModelInfoView(modelManager: modelManager)
                    .padding()
                    .background(Color.gray.opacity(0.1))
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 80))
                        .foregroundColor(.gray)
                    
                    Text("No 3D Model Loaded")
                        .font(.title2)
                        .foregroundColor(.gray)
                    
                    Button("Load STL File") {
                        showingFilePicker = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("3D STL Viewer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Load Model") {
                    showingFilePicker = true
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "stl")!],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                if let file = files.first {
                    modelManager.loadSTLFile(from: file)
                }
            case .failure(let error):
                print("File picker error: \(error)")
            }
        }
    }
}


}
*/

// MARK: - Model Manager
class ModelManager: ObservableObject {
@Published var currentModel: SCNNode?
@Published var position: SCNVector3 = SCNVector3(0, 0, 0)
@Published var rotation: SCNVector4 = SCNVector4(0, 0, 0, 0)
@Published var scale: Float = 1.0

func loadSTLFile(from url: URL) {
    guard url.startAccessingSecurityScopedResource() else {
        print("Failed to access security scoped resource")
        return
    }
    
    defer {
        url.stopAccessingSecurityScopedResource()
    }
    
    do {
        let data = try Data(contentsOf: url)
        let geometry = try parseSTLFile(data: data)
        
        DispatchQueue.main.async {
            let node = SCNNode(geometry: geometry)
            
            // Add material
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemBlue
            material.specular.contents = UIColor.white
            material.shininess = 0.8
            geometry.materials = [material]
            
            // Center the model
            let boundingBox = geometry.boundingBox
            let center = SCNVector3(
                (boundingBox.min.x + boundingBox.max.x) / 2,
                (boundingBox.min.y + boundingBox.max.y) / 2,
                (boundingBox.min.z + boundingBox.max.z) / 2
            )
            node.position = SCNVector3(-center.x, -center.y, -center.z)
            
            self.currentModel = node
            self.resetTransform()
        }
    } catch {
        print("Error loading STL file: \(error)")
    }
}

func updatePosition(_ newPosition: SCNVector3) {
    position = newPosition
    currentModel?.position = newPosition
}

func updateRotation(_ newRotation: SCNVector4) {
    rotation = newRotation
    currentModel?.rotation = newRotation
}

func updateScale(_ newScale: Float) {
    scale = newScale
    currentModel?.scale = SCNVector3(newScale, newScale, newScale)
}

func resetTransform() {
    position = SCNVector3(0, 0, 0)
    rotation = SCNVector4(0, 0, 0, 0)
    scale = 1.0
    
    currentModel?.position = position
    currentModel?.rotation = rotation
    currentModel?.scale = SCNVector3(scale, scale, scale)
}


}

// MARK: - 3D Scene View
struct SceneView3D: UIViewRepresentable {
@ObservedObject var modelManager: ModelManager


func makeUIView(context: Context) -> SCNView {
    let sceneView = SCNView()
    let scene = SCNScene()
    
    // Setup camera
    let cameraNode = SCNNode()
    cameraNode.camera = SCNCamera()
    cameraNode.position = SCNVector3(0, 0, 10)
    scene.rootNode.addChildNode(cameraNode)
    
    // Setup lighting
    let lightNode = SCNNode()
    lightNode.light = SCNLight()
    lightNode.light!.type = .omni
    lightNode.position = SCNVector3(10, 10, 10)
    scene.rootNode.addChildNode(lightNode)
    
    let ambientLight = SCNNode()
    ambientLight.light = SCNLight()
    ambientLight.light!.type = .ambient
    ambientLight.light!.color = UIColor.darkGray
    scene.rootNode.addChildNode(ambientLight)
    
    sceneView.scene = scene
    sceneView.backgroundColor = UIColor.black //.. UIColor.systemBackground
    sceneView.allowsCameraControl = true
    sceneView.antialiasingMode = .multisampling4X
    
    //..
    sceneView.autoenablesDefaultLighting = true
    
    // Add gesture recognizers
    let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan))
    let rotationGesture = UIRotationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRotation))
    let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch))
    
    sceneView.addGestureRecognizer(panGesture)
    sceneView.addGestureRecognizer(rotationGesture)
    sceneView.addGestureRecognizer(pinchGesture)
    
    return sceneView
}

func updateUIView(_ uiView: SCNView, context: Context) {
    context.coordinator.modelManager = modelManager
    
    if let model = modelManager.currentModel {
        // Remove existing model
        uiView.scene?.rootNode.childNodes.forEach { node in
            if node.geometry != nil {
                node.removeFromParentNode()
            }
        }
        
        // Add new model
        uiView.scene?.rootNode.addChildNode(model)
    }
}

func makeCoordinator() -> Coordinator {
    Coordinator(modelManager)
}

class Coordinator: NSObject {
    var modelManager: ModelManager
    
    init(_ modelManager: ModelManager) {
        self.modelManager = modelManager
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let model = modelManager.currentModel else { return }
        
        let translation = gesture.translation(in: gesture.view)
        let newPosition = SCNVector3(
            model.position.x + Float(translation.x) * 0.01,
            model.position.y - Float(translation.y) * 0.01,
            model.position.z
        )
        
        modelManager.updatePosition(newPosition)
        gesture.setTranslation(.zero, in: gesture.view)
    }
    
    @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard let model = modelManager.currentModel else { return }
        
        let rotation = Float(gesture.rotation)
        let newRotation = SCNVector4(
            model.rotation.x,
            model.rotation.y,
            1,
            model.rotation.w + rotation
        )
        
        modelManager.updateRotation(newRotation)
        gesture.rotation = 0
    }
    
    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let scale = Float(gesture.scale)
        let newScale = modelManager.scale * scale
        
        modelManager.updateScale(newScale)
        gesture.scale = 1.0
    }
}


}

// MARK: - Model Info View
struct ModelInfoView: View {
@ObservedObject var modelManager: ModelManager


var body: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Model Transform")
            .font(.headline)
        
        HStack {
            VStack(alignment: .leading) {
                Text("Position:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("X: \(String(format: "%.2f", modelManager.position.x))")
                Text("Y: \(String(format: "%.2f", modelManager.position.y))")
                Text("Z: \(String(format: "%.2f", modelManager.position.z))")
            }
            
            Spacer()
            
            VStack(alignment: .leading) {
                Text("Rotation:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("X: \(String(format: "%.2f", modelManager.rotation.x))")
                Text("Y: \(String(format: "%.2f", modelManager.rotation.y))")
                Text("Z: \(String(format: "%.2f", modelManager.rotation.z))")
                Text("W: \(String(format: "%.2f", modelManager.rotation.w))")
            }
            
            Spacer()
            
            VStack(alignment: .leading) {
                Text("Scale:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(String(format: "%.2f", modelManager.scale))")
            }
        }
        .font(.caption)
        
        Button("Reset Transform") {
            modelManager.resetTransform()
        }
        .buttonStyle(.bordered)
    }
}


}

// MARK: Reality Kit: SurfaceRenderPointCloudView

import SwiftUI
import RealityKit
import ModelIO
import MetalKit
import UniformTypeIdentifiers

struct SurfaceRenderPointCloudViewRK: View {
    @StateObject private var viewModel = ModelViewModel()
    @State private var showingFilePicker = false
    
    var body: some View {
        VStack {
            // 3D Model View
            ARViewContainer(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Controls and Info Panel
            VStack(spacing: 16) {
                // File Info and Load Button
                VStack(spacing: 8) {
                    if let fileName = viewModel.currentFileName {
                        Text("Loaded: \(fileName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Load STL File") {
                        showingFilePicker = true
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                // Position Controls
                VStack(alignment: .leading, spacing: 8) {
                    Text("Position")
                        .font(.headline)
                    
                    HStack {
                        Text("X: \(viewModel.position.x, specifier: "%.2f")")
                        Slider(value: $viewModel.position.x, in: -2...2)
                    }
                    
                    HStack {
                        Text("Y: \(viewModel.position.y, specifier: "%.2f")")
                        Slider(value: $viewModel.position.y, in: -2...2)
                    }
                    
                    HStack {
                        Text("Z: \(viewModel.position.z, specifier: "%.2f")")
                        Slider(value: $viewModel.position.z, in: -2...2)
                    }
                }
                
                // Rotation Controls
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rotation (degrees)")
                        .font(.headline)
                    
                    HStack {
                        Text("X: \(viewModel.rotation.x * 180 / .pi, specifier: "%.1f")°")
                        Slider(value: $viewModel.rotation.x, in: 0...(2 * .pi))
                    }
                    
                    HStack {
                        Text("Y: \(viewModel.rotation.y * 180 / .pi, specifier: "%.1f")°")
                        Slider(value: $viewModel.rotation.y, in: 0...(2 * .pi))
                    }
                    
                    HStack {
                        Text("Z: \(viewModel.rotation.z * 180 / .pi, specifier: "%.1f")°")
                        Slider(value: $viewModel.rotation.z, in: 0...(2 * .pi))
                    }
                }
                
                // Scale Control
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scale")
                        .font(.headline)
                    
                    HStack {
                        Text("Scale: \(viewModel.scale, specifier: "%.2f")")
                        Slider(value: $viewModel.scale, in: 0.1...3.0)
                    }
                }
                
                // Model Info
                if let modelInfo = viewModel.modelInfo {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model Info")
                            .font(.headline)
                        Text("Vertices: \(modelInfo.vertexCount)")
                            .font(.caption)
                        Text("Triangles: \(modelInfo.triangleCount)")
                            .font(.caption)
                        Text("Size: \(modelInfo.boundingBoxSize.x, specifier: "%.2f") × \(modelInfo.boundingBoxSize.y, specifier: "%.2f") × \(modelInfo.boundingBoxSize.z, specifier: "%.2f")")
                            .font(.caption)
                    }
                }
                
                // Reset Button
                Button("Reset Transform") {
                    viewModel.resetTransform()
                }
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .background(Color(.systemGray6))
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.init(filenameExtension: "stl")!],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.loadSTLFile(from: url)
                }
            case .failure(let error):
                print("File picker error: \(error)")
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: ModelViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure the scene
        arView.environment.background = .color(.systemBackground)
        
        // Add lighting
        let directionalLight = DirectionalLight()
        directionalLight.light.intensity = 1000
        directionalLight.orientation = simd_quatf(angle: .pi / 4, axis: [1, -1, 0])
        
        let lightAnchor = AnchorEntity(world: [0, 0, 0])
        lightAnchor.addChild(directionalLight)
        arView.scene.addAnchor(lightAnchor)
        
        // Store reference to ARView in view model
        viewModel.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        viewModel.updateModelTransform()
    }
}

struct ModelInfo {
    let vertexCount: Int
    let triangleCount: Int
    let boundingBoxSize: SIMD3<Float>
}

class ModelViewModel: ObservableObject {
    @Published var position = SIMD3<Float>(0, 0, 0)
    @Published var rotation = SIMD3<Float>(0, 0, 0)
    @Published var scale: Float = 1.0
    @Published var currentFileName: String?
    @Published var modelInfo: ModelInfo?
    
    var arView: ARView?
    private var modelEntity: ModelEntity?
    private var modelAnchor: AnchorEntity?
    
    func loadSTLModel() {
        // This method is now replaced by loadSTLFile(from:)
        // Keep for backward compatibility with demo model
        loadSampleModel()
    }
    
    private func loadSampleModel() {
        guard let arView = arView else { return }
        
        // Remove existing model if any
        if let existingAnchor = modelAnchor {
            arView.scene.removeAnchor(existingAnchor)
        }
        
        // Create a sample mesh (box) - replace with STL loading logic
        let mesh = MeshResource.generateBox(size: 0.5)
        var material = SimpleMaterial()
        material.color = .init(tint: .blue, texture: nil)
        material.metallic = 0.2
        material.roughness = 0.3
        
        modelEntity = ModelEntity(mesh: mesh, materials: [material])
        
        // Center the model
        centerModel()
        
        // Create anchor and add model
        modelAnchor = AnchorEntity(world: [0, 0, -1])
        modelAnchor?.addChild(modelEntity!)
        arView.scene.addAnchor(modelAnchor!)
        
        // Reset transform values
        resetTransform()
        currentFileName = "Sample Box"
        modelInfo = ModelInfo(vertexCount: 8, triangleCount: 12, boundingBoxSize: SIMD3<Float>(0.5, 0.5, 0.5))
    }
    
    private func centerModel() {
        guard let entity = modelEntity else { return }
        
        // Get the bounding box of the model
        let bounds = entity.model?.mesh.bounds
        if let bounds = bounds {
            let center = (bounds.max + bounds.min) / 2
            entity.position = -center
        }
    }
    
    func updateModelTransform() {
        guard let entity = modelEntity else { return }
        
        // Update position
        entity.position = position
        
        // Update rotation (convert from Euler angles to quaternion)
        let rotationX = simd_quatf(angle: rotation.x, axis: [1, 0, 0])
        let rotationY = simd_quatf(angle: rotation.y, axis: [0, 1, 0])
        let rotationZ = simd_quatf(angle: rotation.z, axis: [0, 0, 1])
        entity.orientation = rotationZ * rotationY * rotationX
        
        // Update scale
        entity.scale = SIMD3<Float>(scale, scale, scale)
    }
    
    func resetTransform() {
        position = SIMD3<Float>(0, 0, 0)
        rotation = SIMD3<Float>(0, 0, 0)
        scale = 1.0
    }
}

// MARK: - STL Loading Extension
extension ModelViewModel {
    
    // This function handles actual STL file loading from any file path
    func loadSTLFile(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security scoped resource")
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // Extract filename for display
        currentFileName = url.lastPathComponent
        
        // Create MDLAsset from STL file with proper vertex descriptor
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: 0,
            bufferIndex: 0
        )
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: 12)
        
        let bufferAllocator = MTKMeshBufferAllocator(device: MTLCreateSystemDefaultDevice()!)
        let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)
        
        guard let object = asset.object(at: 0) as? MDLMesh else {
            print("Failed to load STL mesh from: \(url.lastPathComponent)")
            return
        }
        
        // Generate normals if they don't exist
        if object.vertexAttributeData(forAttributeNamed: MDLVertexAttributeNormal) == nil {
            object.addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0.5)
        }
        
        // Convert MDLMesh to RealityKit MeshResource
        do {
            let meshResource = try createMeshResourceFromMDL(object)
            
            // Calculate model info
            let info = calculateModelInfo(from: object)
            
            // Create material
            var material = SimpleMaterial()
            material.color = .init(tint: .gray, texture: nil)
            material.metallic = 0.1
            material.roughness = 0.7
            
            // Create model entity
            modelEntity = ModelEntity(mesh: meshResource, materials: [material])
            
            // Update model info and add to scene
            DispatchQueue.main.async { [weak self] in
                self?.modelInfo = info
                self?.addModelToScene()
            }
            
        } catch {
            print("Error creating mesh resource: \(error)")
            // Fallback to sample model
            DispatchQueue.main.async { [weak self] in
                self?.loadSampleModel()
            }
        }
    }
    
    private func calculateModelInfo(from mdlMesh: MDLMesh) -> ModelInfo {
        let vertexCount = mdlMesh.vertexCount
        
        // Calculate triangle count from submeshes
        var triangleCount = 0
        for submesh in mdlMesh.submeshes ?? [] {
            if let mdlSubmesh = submesh as? MDLSubmesh {
                if mdlSubmesh.geometryType == .triangles {
                    triangleCount += mdlSubmesh.indexCount / 3
                }
            }
        }
        
        // Get bounding box size
        let boundingBox = mdlMesh.boundingBox
        let size = boundingBox.maxBounds - boundingBox.minBounds
        let boundingBoxSize = SIMD3<Float>(size.x, size.y, size.z)
        
        return ModelInfo(
            vertexCount: vertexCount,
            triangleCount: triangleCount,
            boundingBoxSize: boundingBoxSize
        )
    }
    
    // Helper method to convert MDLMesh to MeshResource
    private func createMeshResourceFromMDL(_ mdlMesh: MDLMesh) throws -> MeshResource {
        var descriptor = MeshDescriptor()
        
        // Get vertex data
        guard let vertexAttribute = mdlMesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributePosition) else {
            throw NSError(domain: "MeshError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No position data found"])
        }
        
        let vertexCount = mdlMesh.vertexCount
        let vertexBuffer = vertexAttribute.dataStart.assumingMemoryBound(to: SIMD3<Float>.self)
        let positions = Array(UnsafeBufferPointer(start: vertexBuffer, count: vertexCount))
        
        descriptor.positions = MeshBuffer(positions)
        
        // Get normal data if available
        if let normalAttribute = mdlMesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributeNormal) {
            let normalBuffer = normalAttribute.dataStart.assumingMemoryBound(to: SIMD3<Float>.self)
            let normals = Array(UnsafeBufferPointer(start: normalBuffer, count: vertexCount))
            descriptor.normals = MeshBuffer(normals)
        }
        
        // Get texture coordinates if available
        if let texCoordAttribute = mdlMesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributeTextureCoordinate) {
            let texCoordBuffer = texCoordAttribute.dataStart.assumingMemoryBound(to: SIMD2<Float>.self)
            let texCoords = Array(UnsafeBufferPointer(start: texCoordBuffer, count: vertexCount))
            descriptor.textureCoordinates = MeshBuffer(texCoords)
        }
        
        // Get index data from submeshes
        var allIndices: [UInt32] = []
        for submesh in mdlMesh.submeshes ?? [] {
            if let mdlSubmesh = submesh as? MDLSubmesh {
                let indexCount = mdlSubmesh.indexCount
                let indexBuffer = mdlSubmesh.indexBuffer
                let mappedBuffer = indexBuffer.map()
                
                if mdlSubmesh.indexType == .uint32 {
                    let indices = mappedBuffer.bytes.assumingMemoryBound(to: UInt32.self)
                    allIndices.append(contentsOf: Array(UnsafeBufferPointer(start: indices, count: indexCount)))
                } else if mdlSubmesh.indexType == .uint16 {
                    let indices16 = mappedBuffer.bytes.assumingMemoryBound(to: UInt16.self)
                    let indices32 = Array(UnsafeBufferPointer(start: indices16, count: indexCount)).map { UInt32($0) }
                    allIndices.append(contentsOf: indices32)
                }
            }
        }
        
        if !allIndices.isEmpty {
            descriptor.primitives = .triangles(allIndices)
        } else {
            // If no indices, create them sequentially
            let indices = Array(0..<UInt32(vertexCount))
            descriptor.primitives = .triangles(indices)
        }
        
        return try MeshResource.generate(from: [descriptor])
    }

    
    private func addModelToScene() {
        guard let arView = arView, let entity = modelEntity else { return }
        
        // Remove existing model
        if let existingAnchor = modelAnchor {
            arView.scene.removeAnchor(existingAnchor)
        }
        
        // Center the model
        centerModel()
        
        // Create new anchor and add model
        modelAnchor = AnchorEntity(world: [0, 0, -1])
        modelAnchor?.addChild(entity)
        arView.scene.addAnchor(modelAnchor!)
        
        // Reset transform
        resetTransform()
    }
}

#Preview {
    SurfaceRenderPointCloudViewRK()
}
