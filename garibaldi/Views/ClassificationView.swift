//
//  ClassificationView.swift
//  garibaldi
//
//  Created by John Matthew Weston on 11/8/25.
//

import SwiftUI
import Foundation
import Combine
import UIKit

// MARK: Classification View

struct ClassificationView: View {
    @State private var selectedImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var showingImagePicker = false
    
    var models = ["Classify", "Segment", "Vision T(f)", "Depth Estimation"]
    @State private var selectedModel = "Classification"
    
    @State private var processingType: ProcessingType = .original

    private var provider = ClassificationProvider()
    
    private var displayImage: UIImage? {
        switch processingType {
        case .original:
            return selectedImage
        default:
            return processedImage ?? selectedImage
        }
    }
    
    var body: some View {
        VStack {
            // Image Display Area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 400)
                
                if let image = displayImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 380)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Tap to select an image")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: {
                            // TODO: .....
                        }) {
                            Label("Step One", systemImage: "perspective")
                        } // button
                        Divider()
                        Button(action: {
                            // TODO: ....
                        }) {
                            Label("Step Two", systemImage: "perspective")
                        } // button
                        
                    } label: {
                        Label("toolbar", systemImage: "mountain.2")
                    }
                } // toolbaritem
            } // toolbar
            .onTapGesture {
                showingImagePicker = true
            }
            
            // Processing Type Picker
            if selectedImage != nil {
                VStack(alignment: .leading, spacing: 12) {
                    
                    // TODO: segmented picker and processing steps are carry over from filter - refactor, decruft
                    
                    Text("Foundation Models")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Picker("Model Type", selection: $processingType) {
                        ForEach(models, id: \.self) { name in
                            Text(name)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    /*
                    .onChange(of: processingType) { _ in
                        //if let provider = provider,
                        //  if let image = selectedImage {
                        //    provider.processImage( image ) {_ in
                        //    }
                        //}
                    }*/
                }
                
                VStack {
                    Picker("Please choose a model", selection: $selectedModel) {
                        ForEach(models, id: \.self) {
                            Text($0)
                        }
                    }
                    Text("selection: \(selectedModel)")
                }
                
                Spacer()
            } // vstack
        } // view - body
        .onAppear(perform: {
            DispatchQueue.global(qos: .userInitiated).async {
                provider.loadModel()
            }
        })
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
                .onDisappear {
                    if selectedImage != nil {
                        //if let provider = provider,
                        //   let image = selectedImage {
                        provider.processImage( selectedImage! ) {_ in }
                        //}
                    } // image selected...
                }
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

