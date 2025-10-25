//
//  ContentView.swift
//  AudioJournal
//
//  Created by Yvonne Chan on 10/24/25.
//

import SwiftUI
import Combine

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
                colors: [Color(red: 0.95, green: 0.85, blue: 0.7), Color(red: 0.85, green: 0.75, blue: 0.65)],
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
                        .foregroundColor(Color(red: 0.85, green: 0.75, blue: 0.65))
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
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                    Text("New Journal Entry")
                                        .font(.headline)
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 0.85, green: 0.65, blue: 0.55), Color(red: 0.75, green: 0.55, blue: 0.45)],
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
                                .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.45))
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(red: 0.85, green: 0.65, blue: 0.55), lineWidth: 2)
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
                    .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.45))
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
                                .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.45))
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
                                    .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.45))
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
    @Environment(\.presentationMode) var presentationMode
    @State private var transcript = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("For now, type your journal entry below. Speech-to-text coming soon!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
                
                TextEditor(text: $transcript)
                    .padding(8)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                    .frame(maxHeight: .infinity)
                
                Button(action: saveEntry) {
                    Text("Save Entry")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(transcript.isEmpty ? Color.gray : Color(red: 0.85, green: 0.65, blue: 0.55))
                        .cornerRadius(12)
                }
                .disabled(transcript.isEmpty)
            }
            .padding()
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func saveEntry() {
        let newEntry = JournalEntry(
            transcript: transcript,
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
                                .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.45))
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
