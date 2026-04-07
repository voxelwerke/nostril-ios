//
//  BilingualText.swift
//  Nostril
//
//  Created by Ben Nolan on 08/04/2026.
//


import SwiftUI

// MARK: - Bilingual Text Component

struct BilingualText: View {
    let teReo: String
    let english: String
    
    @State private var showTeReo = true
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // English layer (underneath)
            Text(english)
                .opacity(showTeReo ? 0 : 1)
            
            // Te Reo layer (on top, slides in)
            Text(teReo)
                .offset(x: showTeReo ? 0 : UIScreen.main.bounds.width)
                .opacity(showTeReo ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    offset = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 50
                    
                    if value.translation.width < -threshold {
                        // Swipe left -> show Te Reo
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showTeReo = true
                        }
                    } else if value.translation.width > threshold {
                        // Swipe right -> show English
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showTeReo = false
                        }
                    }
                    
                    offset = 0
                }
        )
        .onAppear {
            // Start with English, then auto-reveal Te Reo after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    showTeReo = false
                }
            }
        }
    }
}
