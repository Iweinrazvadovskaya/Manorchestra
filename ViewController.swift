//
//  ViewController.swift
//  ManOrchestra
//
//  Created by Jane Razvadovskaya on 13/07/2019.
//  Copyright © 2019 uSpec. All rights reserved.
//

import UIKit
import AudioKit

//let noteFrequencies = [16.35, 17.32, 18.35, 19.45, 20.6, 21.83, 23.12, 24.5, 25.96, 27.5, 29.14, 30.87]
//let noteNamesWithSharps = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
//let noteNamesWithFlats = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]

let noteFrequencies     = [16.35, 18.35, 20.6, 21.83, 24.5, 27.5, 30.87]
let noteNamesWithSharps = ["C", "D", "E", "F", "G", "A", "B"]
let noteNamesWithFlats  = ["C", "D", "E", "F", "G",  "A", "B"]

let exsPresets = [
    "TX LoTine81z",
    "TX Metalimba",
    "TX Pluck Bass",
    "TX Brass"
]

class Entry {
//    let noteIndex: Int

    let note: Note
    let octave: Octave
    let frequency: Float

    let start: TimeInterval
    var end: TimeInterval?

    let midiNote: Double

    var correctedMidiNote: UInt8 {
        return UInt8(midiNote + 28) // move 4 octaves forward as we had problems with lower notes of sound back
    }

    init(note: Note, octave: Octave, frequency: Float, start: TimeInterval, midiNote: Double) {
        self.note = note
        self.octave = octave
        self.frequency = frequency
        self.start = start
        self.midiNote = midiNote
    }
}

class ViewController: UIViewController {
    // Views
    @IBOutlet var pitchLabel: UILabel!
    @IBOutlet var recordingButton: UIButton!
    @IBOutlet var playButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        playButton.isEnabled = false

        NotificationCenter.default.addObserver(forName: .audioEngineChangedRecordedNotes, object: nil, queue: nil) { (_) in
            self.reloadViews()
        }
    }

    func configure() {
//            stopAllNotes()
//        let newPreset = exsPresets[0]
//        Conductor.sharedInstance.useSound(newPreset)
//        setDefaults()
    }

    @IBAction func recordAction() {
        if AudioEngine.shared.isRecording {
            AudioEngine.shared.stopRecording()
            playButton.isEnabled = true
            pitchLabel.text = ""
        } else {
            AudioEngine.shared.startRecording()
            pitchLabel.text = "Sing, please!"
        }
    }

    @IBAction func playAction() {
        if AudioEngine.shared.isRecording {
            AudioEngine.shared.stopRecording()
        }

        AudioEngine.shared.playAll()
        pitchLabel.text = "Playing..."
    }

    func reloadViews() {
        guard let lastNote = AudioEngine.shared.recordedNotes.last else {
            self.pitchLabel.text = nil
            return
        }

        pitchLabel.text = "\(lastNote.note.name)\(lastNote.octave.index)"
    }
}
