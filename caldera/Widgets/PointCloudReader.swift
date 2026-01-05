//
//  PointCloudReader.swift
//
//  Created by John Matthew Weston on 6/13/25.
//

import SwiftUI
import SceneKit
import UniformTypeIdentifiers

// MARK: STL Parser

func parseSTLFile(data: Data) throws -> SCNGeometry {
    // Check if it's binary STL (starts with 80-byte header, then 4-byte triangle count)
    if data.count > 84 {
        // Try binary format first
        if let geometry = try? parseBinarySTL(data: data) {
            return geometry
        }
    }
    
    // Try ASCII format
    return try parseASCIISTL(data: data)
}

func parseBinarySTL(data: Data) throws -> SCNGeometry {
    guard data.count >= 84 else {
        throw STLError.invalidFormat
    }
    
    // Skip 80-byte header
    let triangleCountData = data.subdata(in: 80..<84)
    let triangleCount = triangleCountData.withUnsafeBytes { $0.load(as: UInt32.self) }
    
    guard data.count >= 84 + Int(triangleCount) * 50 else {
        throw STLError.invalidFormat
    }
    
    var vertices: [SCNVector3] = []
    var normals: [SCNVector3] = []
    var indices: [UInt32] = []
    
    var offset = 84
    
    for i in 0..<Int(triangleCount) {
        // Read normal (12 bytes)
        let normalData = data.subdata(in: offset..<offset+12)
        let normal = normalData.withUnsafeBytes { bytes in
            SCNVector3(
                x: bytes.load(fromByteOffset: 0, as: Float.self),
                y: bytes.load(fromByteOffset: 4, as: Float.self),
                z: bytes.load(fromByteOffset: 8, as: Float.self)
            )
        }
        offset += 12
        
        // Read 3 vertices (36 bytes)
        for j in 0..<3 {
            let vertexData = data.subdata(in: offset..<offset+12)
            let vertex = vertexData.withUnsafeBytes { bytes in
                SCNVector3(
                    x: bytes.load(fromByteOffset: 0, as: Float.self),
                    y: bytes.load(fromByteOffset: 4, as: Float.self),
                    z: bytes.load(fromByteOffset: 8, as: Float.self)
                )
            }
            vertices.append(vertex)
            normals.append(normal)
            indices.append(UInt32(i * 3 + j))
            offset += 12
        }
        
        // Skip attribute byte count (2 bytes)
        offset += 2
    }
    
    return createGeometry(vertices: vertices, normals: normals, indices: indices)
}

// MARK: OBJ Parser

struct OBJResult {
    let geometry: SCNGeometry
    let materials: [SCNMaterial]
}

func parseOBJFile(data: Data, baseURL: URL) throws -> OBJResult {
    guard let content = String(data: data, encoding: .utf8) else {
        throw FileError.invalidFormat
    }
    
    let lines = content.components(separatedBy: .newlines)
    var vertices: [SCNVector3] = []
    var normals: [SCNVector3] = []
    var textureCoords: [CGPoint] = []
    var faces: [OBJFace] = []
    var materials: [String: SCNMaterial] = [:]
    var currentMaterial: String?
    var mtlLibrary: String?
    
    // Parse OBJ file
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
        
        let components = trimmed.components(separatedBy: .whitespaces)
        guard !components.isEmpty else { continue }
        
        switch components[0] {
        case "v": // Vertex
            if components.count >= 4 {
                if let x = Float(components[1]),
                   let y = Float(components[2]),
                   let z = Float(components[3]) {
                    vertices.append(SCNVector3(x: x, y: y, z: z))
                }
            }
            
        case "vn": // Normal
            if components.count >= 4 {
                if let x = Float(components[1]),
                   let y = Float(components[2]),
                   let z = Float(components[3]) {
                    normals.append(SCNVector3(x: x, y: y, z: z))
                }
            }
            
        case "vt": // Texture coordinate
            if components.count >= 3 {
                if let u = Float(components[1]),
                   let v = Float(components[2]) {
                    textureCoords.append(CGPoint(x: CGFloat(u), y: CGFloat(1.0 - v))) // Flip V coordinate
                }
            }
            
        case "f": // Face
            if components.count >= 4 {
                let face = OBJFace(
                    vertices: Array(components[1...]),
                    material: currentMaterial
                )
                faces.append(face)
            }
            
        case "mtllib": // Material library
            if components.count >= 2 {
                mtlLibrary = components[1]
            }
            
        case "usemtl": // Use material
            if components.count >= 2 {
                currentMaterial = components[1]
            }
            
        default:
            break
        }
    }
    
    // Load materials if MTL file is specified
    if let mtlFile = mtlLibrary {
        let mtlURL = baseURL.appendingPathComponent(mtlFile)
        materials = loadMTLFile(url: mtlURL)
    }
    
    // Convert to SceneKit geometry
    let geometry = try createOBJGeometry(
        vertices: vertices,
        normals: normals,
        textureCoords: textureCoords,
        faces: faces
    )
    
    // Apply materials to geometry
    let sceneMaterials = faces.compactMap { face in
        if let materialName = face.material,
           let material = materials[materialName] {
            return material
        }
        return nil
    }
    
    return OBJResult(geometry: geometry, materials: sceneMaterials)
}

struct OBJFace {
    let vertices: [String]
    let material: String?
}

func createOBJGeometry(vertices: [SCNVector3], normals: [SCNVector3], textureCoords: [CGPoint], faces: [OBJFace]) throws -> SCNGeometry {
    var finalVertices: [SCNVector3] = []
    var finalNormals: [SCNVector3] = []
    var finalTexCoords: [CGPoint] = []
    var indices: [UInt32] = []
    var currentIndex: UInt32 = 0
    
    for face in faces {
        // Convert face to triangles (assuming quads or triangles)
        let faceVertices = face.vertices
        
        // Triangulate if needed (simple fan triangulation for convex polygons)
        for i in 1..<(faceVertices.count - 1) {
            let triangleIndices = [0, i, i + 1]
            
            for triIndex in triangleIndices {
                let vertexData = faceVertices[triIndex]
                let components = vertexData.components(separatedBy: "/")
                
                // Parse vertex index
                if let vIndex = Int(components[0]), vIndex > 0, vIndex <= vertices.count {
                    finalVertices.append(vertices[vIndex - 1]) // OBJ indices are 1-based
                } else {
                    throw FileError.invalidFormat
                }
                
                // Parse texture coordinate index
                if components.count > 1 && !components[1].isEmpty,
                   let tIndex = Int(components[1]), tIndex > 0, tIndex <= textureCoords.count {
                    finalTexCoords.append(textureCoords[tIndex - 1])
                } else {
                    finalTexCoords.append(CGPoint(x: 0, y: 0))
                }
                
                // Parse normal index
                if components.count > 2 && !components[2].isEmpty,
                   let nIndex = Int(components[2]), nIndex > 0, nIndex <= normals.count {
                    finalNormals.append(normals[nIndex - 1])
                } else {
                    // Calculate normal if not provided
                    finalNormals.append(SCNVector3(0, 1, 0)) // Default up normal
                }
                
                indices.append(currentIndex)
                currentIndex += 1
            }
        }
    }
    
    guard !finalVertices.isEmpty else {
        throw FileError.noVertices
    }
    
    // Create geometry sources
    let vertexSource = SCNGeometrySource(vertices: finalVertices)
    let normalSource = SCNGeometrySource(normals: finalNormals)
    
    var sources = [vertexSource, normalSource]
    
    // Add texture coordinates if available
    if !finalTexCoords.isEmpty {
        let texCoordSource = SCNGeometrySource(textureCoordinates: finalTexCoords)
        sources.append(texCoordSource)
    }
    
    // Create geometry element
    let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size)
    let element = SCNGeometryElement(
        data: indexData,
        primitiveType: .triangles,
        primitiveCount: indices.count / 3,
        bytesPerIndex: MemoryLayout<UInt32>.size
    )
    
    return SCNGeometry(sources: sources, elements: [element])
}

// MARK: MTL Parser

func loadMTLFile(url: URL) -> [String: SCNMaterial] {
    var materials: [String: SCNMaterial] = [:]
    
    do {
        let content = try String(contentsOf: url)
        let lines = content.components(separatedBy: .newlines)
        var currentMaterial: SCNMaterial?
        var currentName: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            
            let components = trimmed.components(separatedBy: .whitespaces)
            guard !components.isEmpty else { continue }
            
            switch components[0] {
            case "newmtl": // New material
                if let name = currentName, let material = currentMaterial {
                    materials[name] = material
                }
                if components.count >= 2 {
                    currentName = components[1]
                    currentMaterial = SCNMaterial()
                }
                
            case "Kd": // Diffuse color
                if components.count >= 4,
                   let r = Float(components[1]),
                   let g = Float(components[2]),
                   let b = Float(components[3]) {
                    currentMaterial?.diffuse.contents = UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
                }
                
            case "Ks": // Specular color
                if components.count >= 4,
                   let r = Float(components[1]),
                   let g = Float(components[2]),
                   let b = Float(components[3]) {
                    currentMaterial?.specular.contents = UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
                }
                
            case "Ns": // Specular exponent
                if components.count >= 2,
                   let shininess = Float(components[1]) {
                    currentMaterial?.shininess = CGFloat(shininess / 1000.0) // Normalize to SceneKit range
                }
                
            case "d", "Tr": // Transparency
                if components.count >= 2,
                   let alpha = Float(components[1]) {
                    currentMaterial?.transparency = CGFloat(components[0] == "d" ? alpha : 1.0 - alpha)
                }
                
            case "map_Kd": // Diffuse texture
                if components.count >= 2 {
                    let texturePath = components[1]
                    let textureURL = url.deletingLastPathComponent().appendingPathComponent(texturePath)
                    if let image = UIImage(contentsOfFile: textureURL.path) {
                        currentMaterial?.diffuse.contents = image
                    }
                }
                
            default:
                break
            }
        }
        
        // Add the last material
        if let name = currentName, let material = currentMaterial {
            materials[name] = material
        }
        
    } catch {
        print("Failed to load MTL file: \(error)")
    }
    
    return materials
}

func parseASCIISTL(data: Data) throws -> SCNGeometry {
    guard let content = String(data: data, encoding: .utf8) else {
        throw STLError.invalidFormat
    }
    
    let lines = content.components(separatedBy: .newlines)
    var vertices: [SCNVector3] = []
    var normals: [SCNVector3] = []
    var indices: [UInt32] = []
    
    var currentNormal: SCNVector3?
    var triangleVertices: [SCNVector3] = []
    var vertexIndex: UInt32 = 0
    
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let components = trimmed.components(separatedBy: .whitespaces)
        
        if components.count >= 4 && components[0] == "facet" && components[1] == "normal" {
            // Parse normal
            if let x = Float(components[2]),
               let y = Float(components[3]),
               let z = Float(components[4]) {
                currentNormal = SCNVector3(x: x, y: y, z: z)
            }
        } else if components.count >= 4 && components[0] == "vertex" {
            // Parse vertex
            if let x = Float(components[1]),
               let y = Float(components[2]),
               let z = Float(components[3]) {
                triangleVertices.append(SCNVector3(x: x, y: y, z: z))
            }
        } else if components.count >= 1 && components[0] == "endfacet" {
            // End of triangle
            if triangleVertices.count == 3, let normal = currentNormal {
                for vertex in triangleVertices {
                    vertices.append(vertex)
                    normals.append(normal)
                    indices.append(vertexIndex)
                    vertexIndex += 1
                }
            }
            triangleVertices.removeAll()
            currentNormal = nil
        }
    }
    
    guard !vertices.isEmpty else {
        throw STLError.noVertices
    }
    
    return createGeometry(vertices: vertices, normals: normals, indices: indices)
}

func createGeometry(vertices: [SCNVector3], normals: [SCNVector3], indices: [UInt32]) -> SCNGeometry {
    let vertexSource = SCNGeometrySource(vertices: vertices)
    let normalSource = SCNGeometrySource(normals: normals)
    let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size)
    let element = SCNGeometryElement(
        data: indexData,
        primitiveType: .triangles,
        primitiveCount: indices.count / 3,
        bytesPerIndex: MemoryLayout<UInt32>.size
    )
    
    return SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
}

enum STLError: Error, LocalizedError {
    case invalidFormat
    case noVertices
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid STL file format"
        case .noVertices:
            return "No vertices found in STL file"
        }
    }
}

enum FileError: Error, LocalizedError {
    case invalidFormat
    case noVertices
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid file format"
        case .noVertices:
            return "No vertices found in file"
        case .unsupportedFormat:
            return "Unsupported file format"
        }
    }
}
