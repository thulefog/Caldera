//
//  ContentView.swift
//  Garibaldi
//
//  Created by John Matthew Weston on 6/6/25.
//
import SwiftUI
import Foundation
import Combine
import UIKit

struct ContentView: View {
    
    var body: some View {
        TabView {
            NavigationView {
                ImageFilterView()
                    .navigationTitle("Augmentation")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Augmentation", systemImage: "tortoise.circle")
            }
            NavigationView {
                MetalTextureViewport()
                .navigationTitle("Texture")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Texture", systemImage: "lizard")
            }
/*
            NavigationView {
                ClassificationView()
                .navigationTitle("Classification")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Classifier", systemImage: "lizard")
            }
 */
            NavigationView {
                PredictorView()
                .navigationTitle("Predictor")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Predictor", systemImage: "lizard.circle")
            }
            //..
            NavigationView {
                SurfaceRenderPointCloudView()
                    .navigationTitle("Surface Render")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Surface Render", systemImage: "fossil.shell")
            }
            //..
        }
        .preferredColorScheme(.dark)
        .tint(.orange)
        .onAppear(perform: {
            UITabBar.appearance().unselectedItemTintColor = .systemGray
            UITabBarItem.appearance().badgeColor = .systemOrange
        })
        //
    }
}
