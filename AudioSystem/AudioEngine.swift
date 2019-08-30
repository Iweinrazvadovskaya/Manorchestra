//
//  AudioEngine.swift
//  ManOrchestra
//
//  Created by Jane Razvadovskaya on 14/07/2019.
//  Copyright © 2019 uSpec. All rights reserved.
//

import Foundation
import AudioKit

extension Notification.Name {
    static let audioEngineChangedRecordedNotes = Notification.Name(rawValue: "audioEngineChangedRecordedNotes")
}

let noteNames = [
    0: "C",
    1: "D",
    2: "E",
    3: "F",
    4: "G",
    5: "A",
    6: "H"
]

struct Note: Equatable {
    let frequency: Float
    let name: String
}

struct Octave: Equatable {
    let index: Int
    let notes: [Note]
}

let allNotes: [[Float]] = [
    [16.35, 18.35, 20.60, 21.83, 24.50, 27.50, 30.87],
    [32.70, 36.71, 41.20, 43.65, 49.00, 55.00, 61.74],
    [65.41, 73.42, 82.41, 87.31, 98.00, 110.0, 123.5],
    [130.8, 146.8, 164.8, 174.6, 196.0, 220.0, 246.9],
    [261.6, 293.7, 329.6, 349.2, 392.0, 440.0, 493.9],
    [523.3, 587.3, 659.3, 698.5, 784.0, 880.0, 987.8]
]

class AudioEngine {
    static let shared = AudioEngine()

    var isRecording = false

    // Store recorded notes
    var recordedNotes = [Entry]() {
        didSet {
            NotificationCenter.default.post(name: .audioEngineChangedRecordedNotes, object: self)
        }
    }

    // Recording stack
    let mic = AKMicrophone()!
    lazy var tracker: AKFrequencyTracker = { [weak self] in
        let highPass = AKHighPassFilter(mic, cutoffFrequency: 32, resonance: 0)
        let lowPass = AKLowPassFilter(highPass, cutoffFrequency: 550, resonance: 0)
        return AKFrequencyTracker(lowPass)
        }()
    var timing: AKNodeTiming?

    // MIDI
    var bank = AKOscillatorBank()
    var sampler = AKSampler()

    // Timer which polls microphone, updates UI
    var timer: Timer?

    let octaves: [Octave]
    var speechRecorder: AKNodeRecorder?
    var player: AKPlayer?

    init() {
        var octaves = [Octave]()
        for (octaveIndex, octaveNotes) in allNotes.enumerated() {
            var notes = [Note]()
            for (noteIndex, frequency) in octaveNotes.enumerated() {
                notes.append(Note(frequency: frequency, name: noteNames[noteIndex]!))
            }
            octaves.append(Octave(index: octaveIndex, notes: notes))
        }
        self.octaves = octaves
    }

    func startRecording() {
        stopRecording()

        isRecording = true

        let silence = AKBooster(tracker, gain: 0)

        AudioKit.output = silence
        timing = AKNodeTiming(node: silence)

        if recordedNotes.isEmpty {
            recordedNotes = []

            try? AudioKit.start()

            timing?.start()
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true, block: { [weak self] (_) in
                self?.pollFrequency()
            })
        } else {
//            try? AudioKit.start()

//            speechRecorder = try? AKNodeRecorder(node: mic, file: AKAudioFile(writeIn: .documents, name: nil, settings: [:]))
            let docsURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let url = docsURL.appendingPathComponent(UUID().uuidString + ".wav")
            do {
                avRecorder = try AVAudioRecorder(url: url, format: AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)!)

                avRecorder?.record()
//                try speechRecorder?.record()
            } catch {
                debugPrint("EXCEPTION \(error)")
            }
//            debugPrint("Recording to \(speechRecorder?.audioFile?.avAsset.url.absoluteString ?? "empty")")
            isRecording = true
        }
    }

    var avRecorder: AVAudioRecorder?

    func stopRecording() {
        speechRecorder?.stop()
        avRecorder?.stop()

        try? AudioKit.stop()

        timer?.invalidate()
        timer = nil

        isRecording = false
    }

    func playAll() {
        playSpeech()
        playPiano()
    }

    func playPiano() {
        Conductor.shared.loadSamples(byIndex: 0)

        let now = DispatchTime.now()
        var prevNote: UInt8?
        recordedNotes.forEach { (entry) in
            DispatchQueue.main.asyncAfter(deadline: now + entry.start, execute: {
                if let prevNote = prevNote {
                    Conductor.shared.stopNote(note: prevNote, channel: 0)
                }

                Conductor.shared.playNote(note: entry.correctedMidiNote, velocity: 80, channel: 0)
                prevNote = entry.correctedMidiNote
            })
        }
        if
            let lastNote = recordedNotes.last,
            let lastEntryEnd = lastNote.end {
            DispatchQueue.main.asyncAfter(deadline: now + lastEntryEnd) {
                Conductor.shared.stopNote(note: lastNote.correctedMidiNote, channel: 0)
            }
        }
    }

    func playSpeech() {
        if let fileURL = avRecorder?.url {
            do {
                let file = try AKAudioFile(forReading: fileURL)
                Conductor.shared.play(file: file)
            } catch {
                debugPrint("exception \(error)")
            }
        }
//        if let file = speechRecorder?.audioFile {
//            Conductor.shared.play(file: file)
//        }
    }

    var frequencyBuffer = [Float]()

    func addNewNoteIfNeeded() {
        let frequency = frequencyBuffer.average

        var minDistance: Float = 10000.0

        var detectedOctave = self.octaves.first!
        var detectedNote = self.octaves.first!.notes.first!
        octaves.forEach { (octave) in
            octave.notes.forEach({ (note) in
                let distance = fabsf(note.frequency - frequency)
                if (distance < minDistance){
                    detectedNote = note
                    detectedOctave = octave
                    minDistance = distance
                }
            })
        }

        let midiNote = tracker.frequency.frequencyToMIDINote()

        guard let time = timing?.currentTime else { return }

        if let last = recordedNotes.last {
            let changed = last.octave != detectedOctave || last.note != detectedNote
            if changed {
                debugPrint("Changed! Adding new")
                debugPrint("last \(last.note.name)\(last.octave.index)")
                debugPrint("new  \(detectedNote.name)\(detectedOctave.index)")

                last.end = time

                let entry = Entry(note: detectedNote, octave: detectedOctave, frequency: frequency, start: time, midiNote: midiNote)
                recordedNotes.append(entry)
            }
        } else {
            debugPrint("Adding new note \(detectedNote.name)\(detectedOctave.index)")
            let entry = Entry(note: detectedNote, octave: detectedOctave, frequency: frequency, start: time, midiNote: midiNote)
            recordedNotes.append(entry)
        }
    }

    func pollFrequency() {
        guard tracker.amplitude > 0.12 else {
            // Audio stopped, add new note
            if
                let time = timing?.currentTime,
                let lastNote = recordedNotes.last,
                lastNote.end == nil {
                lastNote.end = time
            }
            return
        }

        let frequency = Float(tracker.frequency)
        debugPrint("Detected frequency \(frequency)")

        frequencyBuffer.append(frequency)
        if frequencyBuffer.count >= 6 {
            addNewNoteIfNeeded()
            frequencyBuffer = []
        }
    }
}

extension Collection where Iterator.Element == Float {
    var average: Float {
        let total = reduce(0, +)
        return isEmpty ? 0 : total / Float(count)
    }
}
