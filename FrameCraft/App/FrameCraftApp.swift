//
//  FrameCraftApp.swift
//  FrameCraft
//

import SwiftUI

@main
struct FrameCraftApp: App {

    @StateObject private var camera = CameraController()
    @StateObject private var album = AlbumStore()

    var body: some Scene {
        WindowGroup {
            CameraView()
                .environmentObject(camera)
                .environmentObject(album)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}
