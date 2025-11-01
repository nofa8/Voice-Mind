//
//  ContentView.swift
//  FirstApp
//
//  Created by Afonso on 29/09/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {	
            Image(systemName: "globe")
                .imageScale(.large)	
                .foregroundStyle(.tint)		
            VStack {
                Text("Turtle Rock")
                    .font(.title)	
            }
        }
        .padding()	    
    }
}

#Preview {
    ContentView()
}
	
	
	
