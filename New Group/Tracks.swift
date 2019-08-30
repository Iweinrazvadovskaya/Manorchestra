//
//  Tracks.swift
//  ManOrchestra
//
//  Created by Jane Razvadovskaya on 14/07/2019.
//  Copyright © 2019 uSpec. All rights reserved.
//

import Foundation

class Track {
    let title: String

    init(title: String) {
        self.title = title
    }

    func play() {

    }
}

class PianoTrack : Track {
    let recordedEntries: [Entry]

    init(title: String, recordedEntries: [Entry]) {
        self.recordedEntries = recordedEntries
        super.init(title: title)
    }

    override func play() {
        AudioEngine.shared.playPiano()
    }
}

class VoiceTrack : Track {
    let fileURL: URL

    init(title: String, fileURL: URL) {
        self.fileURL = fileURL
        super.init(title: title)
    }

    override func play() {

    }
}

struct Project {
    var tracks: [Track]

    func play() {
        tracks.forEach { (track) in
            track.play()
        }
    }
}
