import SwiftUI
import NostrClient
import Security

struct SignupView: View {
    @AppStorage("displayName") private var displayName: String = ""
    @AppStorage("myPubKey") private var myPubKey: String = ""
    @EnvironmentObject private var datastoreHolder: DatastoreHolder
    
    @State private var tempDisplayName: String = ""
    @State private var generatedPubKey: String = ""
    @State private var generatedPrivateKey: String = ""
    @State private var isImportingPrivateKey: Bool = false
    @State private var importedPrivateKey: String = ""
    @State private var showAdvanced: Bool = false
    @FocusState private var isTextFieldFocused: Bool // The "Magic" focus bit
    
    var body: some View {
        NavigationStack {
            ZStack {
                Tukutuku()
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 20) {
                    
                    // 2. Header Block
                    VStack(alignment: .leading, spacing: 12) {
                        BilingualText(
                            teReo: "Kia ora e hoa",
                            english: "Hello, friend"
                        ).font(.largeTitle.weight(.bold))
                        
                        BilingualText(
                            teReo: "Ko te whānau te mea nui o te ao.",
                            english: "Family is the greatest thing in the world."
                        )
                        .font(.subheadline)
                        
                        Text("🥝 Proudly made in New Zealand")
                            .font(.caption).opacity(0.7)
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(30)
                    
                    
                    // 3. Form Block
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What is your name?")
                                .font(.headline)
                            
                            TextField("Herbie Hancock", text: $tempDisplayName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 28, weight: .bold))
                                .focused($isTextFieldFocused)
                                .textInputAutocapitalization(.words)
                            
                            Divider()
                        }
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isTextFieldFocused = true
                            }
                        }
                        
                        Toggle("Advanced", isOn: $showAdvanced)
                            .tint(.orange)
                        
                        if showAdvanced {
                            advancedInputs
                                .transition(.opacity)
                        }
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(30)
                    
                    // 4. Action Button
                    Button(action: beginTapped) {
                        Text("Begin")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                Capsule()
                                    .fill(canBegin ? AnyShapeStyle(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color(red:0.3, green: 0.3, blue: 0.3).opacity(0.8)))
                            )
                            .foregroundColor(.white)
                        
                        
                    }
                    .disabled(!canBegin)
                    .padding(.top, 10)
                    
                    Spacer(minLength: 100)
                }
                .padding(48)
                
            }
            .onAppear(perform: prepareKeys)
        }
    }
    
    private var advancedInputs: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isImportingPrivateKey {
                TextField("Paste your nsec", text: $importedPrivateKey, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(3)
            } else {
                HStack {
                    Text(displayedNpub)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: regenerateKeys) {
                        Image(systemName: "dice.fill")
                    }.buttonStyle(.plain)
                }
            }
            
            Button(isImportingPrivateKey ? "Generate new key" : "Import key") {
                withAnimation { isImportingPrivateKey.toggle() }
            }.font(.caption).underline()
        }
    }
    
    // MARK: - Logic
    private var displayedNpub: String {
        let raw = generatedPubKey.isEmpty ? "Will be generated" : generatedPubKey
        guard raw.count > 20 else { return raw }
        return "\(raw.prefix(10))...\(raw.suffix(8))"
    }
    
    private var canBegin: Bool {
        !tempDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func prepareKeys() { if generatedPubKey.isEmpty { regenerateKeys() } }
    
    private func regenerateKeys() {
        if let kp = try? KeyPair() {
            generatedPubKey = kp.npub
            generatedPrivateKey = kp.nsec
        }
    }
    
    private func beginTapped() {
        displayName = tempDisplayName
        storePrivateKeyInKeychain(isImportingPrivateKey ? importedPrivateKey : generatedPrivateKey)
        datastoreHolder.rebuildIfNeeded()
    }
    
    private func storePrivateKeyInKeychain(_ key: String) {
        KeychainStore.saveNsec(key)
    }
}
