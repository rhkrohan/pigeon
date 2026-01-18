import SwiftUI

struct MissingPersonView: View {
    @EnvironmentObject var viewModel: MeshViewModel
    @Environment(\.dismiss) var dismiss

    @State private var personName = ""
    @State private var lastSeenLocation = ""
    @State private var lastSeenTime = ""
    @State private var physicalDescription = ""
    @State private var contactInfo = ""
    @State private var showingSentAlert = false

    var body: some View {
        Form {
            Section("Person details") {
                TextField("Full name", text: $personName)
                TextField("Last seen location", text: $lastSeenLocation)
                TextField("Last seen time", text: $lastSeenTime)
            }

            Section("Physical description") {
                TextEditor(text: $physicalDescription)
                    .frame(minHeight: 80)
                    .overlay(alignment: .topLeading) {
                        if physicalDescription.isEmpty {
                            Text("Height, clothing, distinguishing features...")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section("Contact information") {
                TextField("Phone or other contact", text: $contactInfo)
                    .keyboardType(.phonePad)
            }

            Section {
                Button {
                    sendMissingPerson()
                } label: {
                    HStack {
                        Spacer()
                        Text("Broadcast alert")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(personName.isEmpty || physicalDescription.isEmpty)
            }
        }
        .navigationTitle("Missing person")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Alert sent", isPresented: $showingSentAlert) {
            Button("Done") { dismiss() }
        } message: {
            Text("Missing person alert has been broadcast to the mesh network.")
        }
    }

    private func sendMissingPerson() {
        viewModel.meshService.sendMissingPerson(
            name: personName,
            lastSeenLocation: lastSeenLocation,
            lastSeenTime: lastSeenTime,
            description: physicalDescription,
            contactInfo: contactInfo
        )
        showingSentAlert = true
    }
}
