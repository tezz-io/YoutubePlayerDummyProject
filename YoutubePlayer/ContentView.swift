//
//  ContentView.swift
//  YoutubePlayer
//
//  Created by tezz on 07/03/21.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        YoutubePlayer(videoURL: "https://www.youtube.com/watch?v=ePpPVE-GGJw")
            .frame(width: 1920 / 7, height: 1080 / 7, alignment: .center)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
