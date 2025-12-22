//
//  SettingsView.swift
//  OneBox
//

import SwiftUI
import Payments
import Privacy
import UIComponents

struct SettingsView: View {
    @EnvironmentObject var paymentsManager: PaymentsManager
    @EnvironmentObject var privacyManager: Privacy.PrivacyManager
    @AppStorage("strip_metadata_default") private var stripMetadataDefault = true
    @AppStorage("keep_originals") private var keepOriginals = false
    @AppStorage("diagnostics_enabled") private var diagnosticsEnabled = false
    @State private var showingPrivacyPolicy = false
    @State private var showingSupport = false
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            List {
                // Pro Status
                proSection

                // Processing Defaults
                Section {
                    Toggle("Strip Metadata by Default", isOn: $stripMetadataDefault)
                    Toggle("Keep Original Files", isOn: $keepOriginals)
                } header: {
                    Text("Processing")
                } footer: {
                    Text("These settings apply to all tools by default")
                }

                // Privacy
                Section {
                    NavigationLink("Privacy Dashboard") {
                        PrivacyDashboardView()
                    }
                    
                    Toggle("Anonymous Diagnostics", isOn: $diagnosticsEnabled)
                    Button("Privacy Policy") {
                        showingPrivacyPolicy = true
                    }
                } header: {
                    Text("Privacy & Security")
                } footer: {
                    Text("All processing happens on your device. No files are uploaded.")
                }

                // Support
                Section("Support") {
                    Button("Help & FAQ") {
                        showingSupport = true
                    }
                    Link("Report an Issue", destination: URL(string: "mailto:vaultpdf@spuud.com")!)
                }

                // About
                Section {
                    // Brand identity with logo
                    HStack(spacing: 16) {
                        Image("VaultLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Vault PDF")
                                .font(.headline)
                                .foregroundColor(OneBoxColors.primaryText)
                            Text("Version \(appVersion) (\(buildNumber))")
                                .font(.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                            Text("Privacy-first document processing")
                                .font(.caption2)
                                .foregroundColor(OneBoxColors.tertiaryText)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)

                    // Website link
                    Link(destination: URL(string: "https://spuud.com")!) {
                        HStack {
                            Text("Website")
                                .foregroundColor(OneBoxColors.primaryText)
                            Spacer()
                            Text("spuud.com")
                                .foregroundColor(OneBoxColors.secondaryText)
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(OneBoxColors.tertiaryText)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("About")
                }

                // Restore Purchases
                if !paymentsManager.hasPro {
                    Section {
                        Button("Restore Purchases") {
                            Task {
                                await paymentsManager.restorePurchases()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .scrollContentBackground(.hidden)
            .background(OneBoxColors.primaryGraphite)
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showingSupport) {
                SupportView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    private var proSection: some View {
        Section {
            if paymentsManager.hasPro {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vault PDF Pro")
                            .font(.headline)
                            .foregroundColor(OneBoxColors.primaryText)
                        Text("Thank you for your support!")
                            .font(.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(OneBoxColors.secureGreen)
                        .font(.title2)
                }
            } else {
                Button {
                    showingPaywall = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Upgrade to Pro")
                                .font(.headline)
                                .foregroundColor(OneBoxColors.primaryText)
                            Text("Unlimited exports, no ads, and more")
                                .font(.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "crown.fill")
                            .foregroundColor(OneBoxColors.primaryGold)
                            .font(.title2)
                    }
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(OneBoxColors.primaryText)

                    Group {
                        policySection(
                            title: "On-Device Processing",
                            content: "All file conversions and processing happen entirely on your device. Your files never leave your iPhone or iPad."
                        )

                        policySection(
                            title: "No Data Collection",
                            content: "We do not collect, store, or transmit any of your personal data or files. OneBox has no access to your files except when you explicitly select them for processing."
                        )

                        policySection(
                            title: "Optional Diagnostics",
                            content: "If enabled, anonymous crash reports and usage statistics help us improve the app. This data contains no personal information or file content."
                        )

                        policySection(
                            title: "Advertisements",
                            content: "Non-tracking banner ads may be displayed in the free version. These ads do not collect personal data or track your behavior."
                        )

                        policySection(
                            title: "In-App Purchases",
                            content: "Purchase information is handled by Apple through the App Store. We only verify your purchase status to unlock Pro features."
                        )
                    }

                    Text("Last updated: \(Date().formatted(date: .long, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(OneBoxColors.tertiaryText)
                        .padding(.top)
                }
                .padding()
            }
            .background(OneBoxColors.primaryGraphite)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.goldText)
                }
            }
        }
    }

    private func policySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(OneBoxColors.primaryText)
            Text(content)
                .font(.subheadline)
                .foregroundColor(OneBoxColors.secondaryText)
        }
    }
}

// MARK: - Support View
struct SupportView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Frequently Asked Questions") {
                    FAQRow(
                        question: "How do I convert images to PDF?",
                        answer: "Tap 'Images → PDF' on the home screen, select your photos, adjust settings, and tap Convert."
                    )
                    FAQRow(
                        question: "Are my files uploaded to a server?",
                        answer: "No. All processing happens on your device. Your files never leave your iPhone or iPad."
                    )
                    FAQRow(
                        question: "What's included in the free version?",
                        answer: "You can process up to 3 files per day for free. Pro unlocks unlimited exports and removes ads."
                    )
                    FAQRow(
                        question: "How do I restore my Pro purchase?",
                        answer: "Go to Settings → Restore Purchases. Make sure you're signed in with the same Apple ID."
                    )
                }

                Section("Supported Formats") {
                    FormatRow(category: "Images", formats: "HEIC, JPEG, PNG")
                    FormatRow(category: "PDFs", formats: "PDF")
                }

                Section("Contact") {
                    Link("Report a Bug", destination: URL(string: "mailto:vaultpdf@spuud.com")!)
                        .foregroundColor(OneBoxColors.goldText)
                    Link("Request a Feature", destination: URL(string: "mailto:vaultpdf@spuud.com?subject=Feature%20Request")!)
                        .foregroundColor(OneBoxColors.goldText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(OneBoxColors.primaryGraphite)
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.goldText)
                }
            }
        }
    }
}

struct FAQRow: View {
    let question: String
    let answer: String
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(answer)
                .font(.subheadline)
                .foregroundColor(OneBoxColors.secondaryText)
                .padding(.top, 4)
        } label: {
            Text(question)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(OneBoxColors.primaryText)
        }
    }
}

struct FormatRow: View {
    let category: String
    let formats: String

    var body: some View {
        HStack {
            Text(category)
                .foregroundColor(OneBoxColors.primaryText)
            Spacer()
            Text(formats)
                .foregroundColor(OneBoxColors.secondaryText)
                .font(.subheadline)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(PaymentsManager.shared)
        .environmentObject(Privacy.PrivacyManager.shared)
}
