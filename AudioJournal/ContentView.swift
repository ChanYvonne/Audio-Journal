//
//  ContentView.swift
//  AudioJournal
//
//  Created by Yvonne Chan on 10/31/25.
//

import SwiftUI
import Combine
import AVFoundation
import Speech

// MARK: - Color Palette
extension Color {
    static let journalBeige = Color(red: 242/255, green: 233/255, blue: 228/255)
    static let journalCream = Color(red: 242/255, green: 233/255, blue: 228/255)
    static let journalTeal = Color(red: 107/255, green: 211/255, blue: 209/255)
    static let journalGray = Color(red: 62/255, green: 74/255, blue: 89/255)
}

// MARK: - Models
struct JournalEntry: Identifiable, Codable {
    let id: UUID
    var date: Date
    var transcript: String
    var synthesis: String?
    var questions: [String]
    
    init(id: UUID = UUID(), date: Date = Date(), transcript: String, synthesis: String? = nil, questions: [String] = []) {
        self.id = id
        self.date = date
        self.transcript = transcript
        self.synthesis = synthesis
        self.questions = questions
    }
}

// MARK: - Audio Manager
class AudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    override init() {
        super.init()
        requestAuthorization()
    }
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.authorizationStatus = status
            }
        }
    }
    
    func startRecording() {
        guard authorizationStatus == .authorized else {
            print("Speech recognition not authorized")
            return
        }
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session error: \(error)")
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            print("Unable to create audio engine")
            return
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine start error: \(error)")
            return
        }
        
        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
            }
            
            if error != nil || result?.isFinal == true {
                self.stopRecording()
            }
        }
        
        isRecording = true
    }
    
    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        
        isRecording = false
    }
}

// MARK: - View Model
class JournalViewModel: ObservableObject {
    @Published var entries: [JournalEntry] = []
    
    init() {
        loadEntries()
    }
    
    func addEntry(_ entry: JournalEntry) {
        entries.insert(entry, at: 0)
        saveEntries()
    }
    
    func updateEntry(_ entry: JournalEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            saveEntries()
        }
    }
    
    func deleteEntry(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
    }
    
    private func saveEntries() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: "journalEntries")
        }
    }
    
    private func loadEntries() {
        if let data = UserDefaults.standard.data(forKey: "journalEntries"),
           let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            entries = decoded
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var viewModel = JournalViewModel()
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    
    var body: some View {
        Group {
            if !hasSeenWelcome {
                WelcomeView(onContinue: {
                    withAnimation {
                        hasSeenWelcome = true
                    }
                })
            } else {
                HomeView()
                    .environmentObject(viewModel)
            }
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    let onContinue: () -> Void
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.85, blue: 0.7), Color.journalBeige],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                    
                    Text("What's on your\nmind today?")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.journalBeige)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var viewModel: JournalViewModel
    @State private var showingNewEntry = false
    @State private var showingPrompts = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: { showingNewEntry = true }) {
                                HStack {
                                    Image(systemName: "mic.circle.fill")
                                        .font(.title2)
                                    Text("New Audio Entry")
                                        .font(.headline)
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.journalTeal],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                            
                            Button(action: { showingPrompts = true }) {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.title2)
                                    Text("Journal Prompts")
                                        .font(.headline)
                                    Spacer()
                                }
                                .foregroundColor(Color.journalGray)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.journalTeal, lineWidth: 2)
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Previous Entries
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Previous Entries")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            if viewModel.entries.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "book.closed")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray.opacity(0.5))
                                    Text("No entries yet")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    Text("Start your first journal entry above")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            } else {
                                ForEach(viewModel.entries) { entry in
                                    NavigationLink(destination: EntryDetailView(entry: entry)) {
                                        EntryCardView(entry: entry)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("My Journal")
            .sheet(isPresented: $showingNewEntry) {
                NewEntryView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showingPrompts) {
                PromptsView()
            }
        }
    }
}

// MARK: - Entry Card View
struct EntryCardView: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(entry.date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.journalTeal)
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Text(entry.transcript)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(3)
            
            if let synthesis = entry.synthesis {
                Text(synthesis)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Entry Detail View
struct EntryDetailView: View {
    @EnvironmentObject var viewModel: JournalViewModel
    @State var entry: JournalEntry
    @State private var isEditing = false
    @State private var editedTranscript: String
    @Environment(\.presentationMode) var presentationMode
    
    init(entry: JournalEntry) {
        _entry = State(initialValue: entry)
        _editedTranscript = State(initialValue: entry.transcript)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Date Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date, style: .date)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(entry.date, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Divider()
                
                // Transcript Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Transcript")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            if isEditing {
                                entry.transcript = editedTranscript
                                viewModel.updateEntry(entry)
                            }
                            isEditing.toggle()
                        }) {
                            Text(isEditing ? "Save" : "Edit")
                                .font(.subheadline)
                                .foregroundColor(Color.journalTeal)
                        }
                    }
                    
                    if isEditing {
                        TextEditor(text: $editedTranscript)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                    } else {
                        Text(entry.transcript)
                            .font(.body)
                    }
                }
                
                // Synthesis Section
                if let synthesis = entry.synthesis {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Synthesis")
                            .font(.headline)
                        Text(synthesis)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                
                // Questions Section
                if !entry.questions.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reflection Questions")
                            .font(.headline)
                        
                        ForEach(Array(entry.questions.enumerated()), id: \.offset) { index, question in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1).")
                                    .font(.body)
                                    .foregroundColor(Color.journalTeal)
                                    .fontWeight(.semibold)
                                Text(question)
                                    .font(.body)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive, action: {
                    viewModel.deleteEntry(entry)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "trash")
                }
            }
        }
    }
}

// MARK: - New Entry View
struct NewEntryView: View {
    @EnvironmentObject var viewModel: JournalViewModel
    @StateObject private var audioManager = AudioManager()
    @Environment(\.presentationMode) var presentationMode
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.journalTeal, Color.journalBeige],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Waveform visualization placeholder
                    if audioManager.isRecording {
                        VStack(spacing: 16) {
                            Text("Listening...")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 4) {
                                ForEach(0..<5) { i in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.7))
                                        .frame(width: 8, height: CGFloat.random(in: 20...80))
                                        .animation(
                                            Animation.easeInOut(duration: 0.5)
                                                .repeatForever()
                                                .delay(Double(i) * 0.1),
                                            value: audioManager.isRecording
                                        )
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "waveform")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.8))
                            Text("Tap to start recording")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Record button
                    Button(action: toggleRecording) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 100, height: 100)
                                .shadow(radius: 10)
                            
                            if audioManager.isRecording {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red)
                                    .frame(width: 40, height: 40)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 60, height: 60)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Transcript preview
                    if !audioManager.transcript.isEmpty {
                        ScrollView {
                            Text(audioManager.transcript)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                        }
                        .frame(maxHeight: 200)
                        .padding(.horizontal)
                        
                        Button(action: saveEntry) {
                            Text("Save Entry")
                                .font(.headline)
                                .foregroundColor(Color.journalTeal)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if audioManager.isRecording {
                            audioManager.stopRecording()
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Microphone Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings", action: openSettings)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable microphone and speech recognition access in Settings to record audio journals.")
            }
            .onAppear {
                checkPermissions()
            }
        }
    }
    
    private func toggleRecording() {
        if audioManager.authorizationStatus != .authorized {
            showingPermissionAlert = true
            return
        }
        
        if audioManager.isRecording {
            audioManager.stopRecording()
        } else {
            audioManager.transcript = ""
            audioManager.startRecording()
        }
    }
    
    private func checkPermissions() {
        if audioManager.authorizationStatus == .notDetermined {
            audioManager.requestAuthorization()
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func saveEntry() {
        let newEntry = JournalEntry(
            transcript: audioManager.transcript,
            synthesis: "Your thoughts have been captured. Synthesis coming soon!",
            questions: [
                "What emotions came up for you while journaling today?",
                "How does this connect to what you shared yesterday?"
            ]
        )
        viewModel.addEntry(newEntry)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Prompts View
struct PromptsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    let prompts = [
        "What are you grateful for today?",
        "What challenge did you face recently, and what did you learn from it?",
        "Describe a moment when you felt truly present.",
        "What would you tell your younger self?",
        "What's weighing on your mind right now?",
        "What made you smile today?",
        "How have you grown in the past month?",
        "What do you need to let go of?"
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(prompts, id: \.self) { prompt in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "quote.bubble")
                                .foregroundColor(Color.journalTeal)
                            Text(prompt)
                                .font(.body)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Journal Prompts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
