//
//  HelpCenterView.swift
//  OneBox
//
//  Comprehensive help center with search, tutorials, and contextual assistance
//

import SwiftUI
import UIComponents

struct HelpCenterView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: HelpCategory? = nil
    @State private var showingSearch = false
    @State private var recentlyViewed: [HelpArticle] = []
    @State private var popularArticles: [HelpArticle] = []
    @State private var featuredTutorials: [Tutorial] = []
    @State private var showingContactSupport = false
    @State private var showingVideoTutorials = false
    @State private var showingFeatureTour = false
    @State private var showingShortcuts = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: OneBoxSpacing.large) {
                        // Search Header
                        searchHeader
                        
                        // Quick Actions
                        quickActionsSection
                        
                        // Categories
                        categoriesSection
                        
                        // Featured Content
                        if searchText.isEmpty {
                            featuredContentSection
                        } else {
                            searchResultsSection
                        }
                        
                        // Recently Viewed
                        if !recentlyViewed.isEmpty && searchText.isEmpty {
                            recentlyViewedSection
                        }
                    }
                    .padding(OneBoxSpacing.medium)
                }
            }
            .navigationTitle("Help Center")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryText)
                }
            }
        }
        .onAppear {
            loadHelpContent()
        }
        .sheet(isPresented: $showingContactSupport) {
            ContactSupportView()
        }
        .sheet(isPresented: $showingVideoTutorials) {
            VideoTutorialsView()
        }
        .sheet(isPresented: $showingFeatureTour) {
            FeatureTourView()
        }
        .sheet(isPresented: $showingShortcuts) {
            KeyboardShortcutsView()
        }
    }

    // MARK: - Search Header
    private var searchHeader: some View {
        OneBoxCard(style: .elevated) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("How can we help?")
                            .font(OneBoxTypography.sectionTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("Search for answers, tutorials, and guides")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(OneBoxColors.primaryGold)
                }
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(OneBoxColors.secondaryText)
                    
                    TextField("Search help articles...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(OneBoxColors.tertiaryText)
                        }
                    }
                }
                .padding(OneBoxSpacing.medium)
                .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                .cornerRadius(OneBoxRadius.medium)
            }
        }
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            Text("Quick Actions")
                .font(OneBoxTypography.cardTitle)
                .foregroundColor(OneBoxColors.primaryText)
                .padding(.horizontal, OneBoxSpacing.small)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OneBoxSpacing.medium) {
                    quickActionCard("Contact Support", "Get personalized help", "envelope.fill", OneBoxColors.primaryGold) {
                        contactSupport()
                    }
                    
                    quickActionCard("Video Tutorials", "Learn with step-by-step guides", "play.circle.fill", OneBoxColors.secureGreen) {
                        showVideoTutorials()
                    }
                    
                    quickActionCard("Feature Tour", "Rediscover OneBox capabilities", "location.circle.fill", OneBoxColors.warningAmber) {
                        startFeatureTour()
                    }
                    
                    quickActionCard("Shortcuts", "Master keyboard shortcuts", "command.circle.fill", OneBoxColors.criticalRed) {
                        showShortcuts()
                    }
                }
                .padding(.horizontal, OneBoxSpacing.medium)
            }
        }
    }
    
    private func quickActionCard(_ title: String, _ description: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: OneBoxSpacing.small) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }
                
                VStack(spacing: OneBoxSpacing.tiny) {
                    Text(title)
                        .font(OneBoxTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(OneBoxColors.primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text(description)
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(width: 120)
            .padding(OneBoxSpacing.medium)
            .background(
                OneBoxCard(style: .interactive) {
                    EmptyView()
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Categories
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            Text("Browse by Category")
                .font(OneBoxTypography.cardTitle)
                .foregroundColor(OneBoxColors.primaryText)
                .padding(.horizontal, OneBoxSpacing.small)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: OneBoxSpacing.medium) {
                ForEach(HelpCategory.allCases) { category in
                    categoryCard(category)
                }
            }
        }
    }
    
    private func categoryCard(_ category: HelpCategory) -> some View {
        NavigationLink(destination: CategoryDetailView(category: category)) {
            OneBoxCard(style: .interactive) {
                VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                    HStack {
                        VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                            Image(systemName: category.icon)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(category.color)
                            
                            Text(category.displayName)
                                .font(OneBoxTypography.body)
                                .fontWeight(.semibold)
                                .foregroundColor(OneBoxColors.primaryText)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(OneBoxColors.tertiaryText)
                    }
                    
                    Text(category.description)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .lineLimit(2)
                    
                    Text("\(category.articleCount) articles")
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.tertiaryText)
                }
                .padding(OneBoxSpacing.medium)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Featured Content
    private var featuredContentSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            Text("Popular Articles")
                .font(OneBoxTypography.cardTitle)
                .foregroundColor(OneBoxColors.primaryText)
                .padding(.horizontal, OneBoxSpacing.small)
            
            VStack(spacing: OneBoxSpacing.small) {
                ForEach(popularArticles.prefix(5)) { article in
                    NavigationLink(destination: ArticleDetailView(article: article)) {
                        articleRow(article)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            if !featuredTutorials.isEmpty {
                VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                    Text("Featured Tutorials")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                        .padding(.horizontal, OneBoxSpacing.small)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: OneBoxSpacing.medium) {
                            ForEach(featuredTutorials) { tutorial in
                                tutorialCard(tutorial)
                            }
                        }
                        .padding(.horizontal, OneBoxSpacing.medium)
                    }
                }
                .padding(.top, OneBoxSpacing.large)
            }
        }
    }
    
    private func articleRow(_ article: HelpArticle) -> some View {
        OneBoxCard(style: .standard) {
            HStack(spacing: OneBoxSpacing.medium) {
                VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                    Text(article.title)
                        .font(OneBoxTypography.body)
                        .fontWeight(.medium)
                        .foregroundColor(OneBoxColors.primaryText)
                        .lineLimit(2)
                    
                    Text(article.summary)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .lineLimit(3)
                    
                    HStack {
                        Text(article.category.displayName)
                            .font(OneBoxTypography.micro)
                            .foregroundColor(article.category.color)
                            .padding(.horizontal, OneBoxSpacing.small)
                            .padding(.vertical, OneBoxSpacing.tiny)
                            .background(article.category.color.opacity(0.1))
                            .cornerRadius(OneBoxRadius.small)
                        
                        Spacer()
                        
                        Text("\(article.readTime) min read")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.tertiaryText)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(OneBoxColors.tertiaryText)
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func tutorialCard(_ tutorial: Tutorial) -> some View {
        NavigationLink(destination: TutorialDetailView(tutorial: tutorial)) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                // Thumbnail
                Rectangle()
                    .fill(OneBoxColors.surfaceGraphite)
                    .frame(width: 200, height: 120)
                    .cornerRadius(OneBoxRadius.medium)
                    .overlay(
                        VStack {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(OneBoxColors.primaryGold)
                            
                            Text("\(tutorial.duration)")
                                .font(OneBoxTypography.micro)
                                .foregroundColor(OneBoxColors.primaryText)
                        }
                    )
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text(tutorial.title)
                        .font(OneBoxTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(OneBoxColors.primaryText)
                        .lineLimit(2)
                    
                    Text(tutorial.description)
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .lineLimit(2)
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(OneBoxColors.primaryGold)
                        
                        Text(String(format: "%.1f", tutorial.rating))
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.secondaryText)
                        
                        Spacer()
                        
                        Text("Level \(tutorial.difficulty)")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.tertiaryText)
                    }
                }
            }
            .frame(width: 200)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Search Results
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            Text("Search Results")
                .font(OneBoxTypography.cardTitle)
                .foregroundColor(OneBoxColors.primaryText)
                .padding(.horizontal, OneBoxSpacing.small)
            
            let filteredArticles = filterArticles(searchText)
            
            if filteredArticles.isEmpty {
                noResultsView
            } else {
                VStack(spacing: OneBoxSpacing.small) {
                    ForEach(filteredArticles) { article in
                        NavigationLink(destination: ArticleDetailView(article: article)) {
                            articleRow(article)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    private var noResultsView: some View {
        OneBoxCard(style: .standard) {
            VStack(spacing: OneBoxSpacing.medium) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(OneBoxColors.tertiaryText)
                
                Text("No results found")
                    .font(OneBoxTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text("Try different keywords or browse categories below")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .multilineTextAlignment(.center)
                
                Button("Browse Categories") {
                    searchText = ""
                }
                .font(OneBoxTypography.body)
                .foregroundColor(OneBoxColors.primaryGold)
                .padding(.top, OneBoxSpacing.small)
            }
            .padding(OneBoxSpacing.large)
        }
    }
    
    // MARK: - Recently Viewed
    private var recentlyViewedSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            Text("Recently Viewed")
                .font(OneBoxTypography.cardTitle)
                .foregroundColor(OneBoxColors.primaryText)
                .padding(.horizontal, OneBoxSpacing.small)
            
            VStack(spacing: OneBoxSpacing.small) {
                ForEach(recentlyViewed.prefix(3)) { article in
                    NavigationLink(destination: ArticleDetailView(article: article)) {
                        articleRow(article)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func loadHelpContent() {
        popularArticles = [
            HelpArticle(
                id: "getting-started",
                title: "Getting Started with OneBox",
                summary: "Learn the basics of document processing and security features in OneBox.",
                content: "Complete guide to getting started...",
                category: .gettingStarted,
                readTime: 5,
                lastUpdated: Date()
            ),
            HelpArticle(
                id: "pdf-compression",
                title: "Advanced PDF Compression",
                summary: "Optimize your documents with AI-powered compression techniques.",
                content: "Advanced compression guide...",
                category: .features,
                readTime: 8,
                lastUpdated: Date()
            ),
            HelpArticle(
                id: "security-setup",
                title: "Setting Up Security Features",
                summary: "Configure biometric authentication and encryption settings.",
                content: "Security setup guide...",
                category: .security,
                readTime: 6,
                lastUpdated: Date()
            ),
            HelpArticle(
                id: "collaboration",
                title: "Secure Document Sharing",
                summary: "Share documents safely with encrypted links and access controls.",
                content: "Collaboration guide...",
                category: .collaboration,
                readTime: 7,
                lastUpdated: Date()
            ),
            HelpArticle(
                id: "troubleshooting-common",
                title: "Common Issues and Solutions",
                summary: "Quick fixes for the most frequently encountered problems.",
                content: "Troubleshooting guide...",
                category: .troubleshooting,
                readTime: 4,
                lastUpdated: Date()
            )
        ]
        
        featuredTutorials = [
            Tutorial(
                id: "merge-tutorial",
                title: "Merging PDFs Like a Pro",
                description: "Learn advanced merging techniques with bookmarks and metadata",
                duration: "4:32",
                difficulty: 2,
                rating: 4.8
            ),
            Tutorial(
                id: "signing-tutorial", 
                title: "Digital Signatures Setup",
                description: "Configure Face ID authentication and signature profiles",
                duration: "6:15",
                difficulty: 3,
                rating: 4.9
            ),
            Tutorial(
                id: "compression-tutorial",
                title: "Smart Compression Techniques",
                description: "Optimize file sizes while maintaining quality",
                duration: "3:45",
                difficulty: 1,
                rating: 4.7
            )
        ]
        
        recentlyViewed = Array(popularArticles.prefix(2))
    }
    
    private func filterArticles(_ query: String) -> [HelpArticle] {
        guard !query.isEmpty else { return popularArticles }
        
        return popularArticles.filter { article in
            article.title.localizedCaseInsensitiveContains(query) ||
            article.summary.localizedCaseInsensitiveContains(query) ||
            article.category.displayName.localizedCaseInsensitiveContains(query)
        }
    }
    
    private func contactSupport() {
        showingContactSupport = true
    }

    private func showVideoTutorials() {
        showingVideoTutorials = true
    }

    private func startFeatureTour() {
        showingFeatureTour = true
    }

    private func showShortcuts() {
        showingShortcuts = true
    }
}

// MARK: - Supporting Types

struct HelpArticle: Identifiable {
    let id: String
    let title: String
    let summary: String
    let content: String
    let category: HelpCategory
    let readTime: Int
    let lastUpdated: Date
}

struct Tutorial: Identifiable {
    let id: String
    let title: String
    let description: String
    let duration: String
    let difficulty: Int
    let rating: Double
}

enum HelpCategory: String, CaseIterable, Identifiable {
    case gettingStarted = "getting-started"
    case features = "features"
    case security = "security"
    case collaboration = "collaboration"
    case troubleshooting = "troubleshooting"
    case advanced = "advanced"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .gettingStarted: return "Getting Started"
        case .features: return "Features & Tools"
        case .security: return "Security & Privacy"
        case .collaboration: return "Collaboration"
        case .troubleshooting: return "Troubleshooting"
        case .advanced: return "Advanced Usage"
        }
    }
    
    var description: String {
        switch self {
        case .gettingStarted: return "Basic setup and first steps"
        case .features: return "Core features and capabilities"
        case .security: return "Privacy and security settings"
        case .collaboration: return "Sharing and teamwork"
        case .troubleshooting: return "Common issues and solutions"
        case .advanced: return "Power user features"
        }
    }
    
    var icon: String {
        switch self {
        case .gettingStarted: return "play.circle.fill"
        case .features: return "wand.and.stars.inverse"
        case .security: return "lock.shield.fill"
        case .collaboration: return "person.2.fill"
        case .troubleshooting: return "wrench.and.screwdriver.fill"
        case .advanced: return "gearshape.2.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .gettingStarted: return OneBoxColors.secureGreen
        case .features: return OneBoxColors.primaryGold
        case .security: return OneBoxColors.criticalRed
        case .collaboration: return OneBoxColors.warningAmber
        case .troubleshooting: return OneBoxColors.secondaryGold
        case .advanced: return OneBoxColors.primaryGold
        }
    }
    
    var articleCount: Int {
        switch self {
        case .gettingStarted: return 8
        case .features: return 15
        case .security: return 12
        case .collaboration: return 6
        case .troubleshooting: return 10
        case .advanced: return 9
        }
    }
}

// MARK: - Detail Views

struct CategoryDetailView: View {
    let category: HelpCategory
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OneBoxSpacing.large) {
                Text(category.description)
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.secondaryText)
                
                Text("Articles in this category")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                // Articles would be loaded here
                Text("Articles coming soon...")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.tertiaryText)
            }
            .padding(OneBoxSpacing.medium)
        }
        .background(OneBoxColors.primaryGraphite)
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct ArticleDetailView: View {
    let article: HelpArticle
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OneBoxSpacing.large) {
                // Article meta
                VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                    HStack {
                        Text(article.category.displayName)
                            .font(OneBoxTypography.caption)
                            .foregroundColor(article.category.color)
                            .padding(.horizontal, OneBoxSpacing.small)
                            .padding(.vertical, OneBoxSpacing.tiny)
                            .background(article.category.color.opacity(0.1))
                            .cornerRadius(OneBoxRadius.small)
                        
                        Spacer()
                        
                        Text("\(article.readTime) min read")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Text(article.summary)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                
                Divider()
                    .background(OneBoxColors.surfaceGraphite)
                
                // Article content
                Text(article.content)
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText)
                    .lineSpacing(6)
                
                // Helpful section
                OneBoxCard(style: .standard) {
                    VStack(spacing: OneBoxSpacing.medium) {
                        Text("Was this article helpful?")
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        HStack(spacing: OneBoxSpacing.large) {
                            Button("Yes") {
                                // Track helpful
                            }
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.primaryGraphite)
                            .padding(.horizontal, OneBoxSpacing.large)
                            .padding(.vertical, OneBoxSpacing.small)
                            .background(OneBoxColors.secureGreen)
                            .cornerRadius(OneBoxRadius.medium)
                            
                            Button("No") {
                                // Track not helpful
                            }
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.primaryText)
                            .padding(.horizontal, OneBoxSpacing.large)
                            .padding(.vertical, OneBoxSpacing.small)
                            .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                            .cornerRadius(OneBoxRadius.medium)
                        }
                    }
                    .padding(OneBoxSpacing.medium)
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .background(OneBoxColors.primaryGraphite)
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct TutorialDetailView: View {
    let tutorial: Tutorial
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: OneBoxSpacing.large) {
                // Video placeholder
                Rectangle()
                    .fill(OneBoxColors.surfaceGraphite)
                    .frame(height: 200)
                    .cornerRadius(OneBoxRadius.medium)
                    .overlay(
                        VStack {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(OneBoxColors.primaryGold)
                            
                            Text("Tutorial Video")
                                .font(OneBoxTypography.body)
                                .foregroundColor(OneBoxColors.primaryText)
                        }
                    )
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                    Text(tutorial.description)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.secondaryText)
                    
                    HStack {
                        Text("Duration: \(tutorial.duration)")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                        
                        Spacer()
                        
                        Text("Level \(tutorial.difficulty)")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                Button("Watch Tutorial") {
                    // Play tutorial
                }
                .font(OneBoxTypography.body)
                .foregroundColor(OneBoxColors.primaryGraphite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, OneBoxSpacing.medium)
                .background(OneBoxColors.primaryGold)
                .cornerRadius(OneBoxRadius.medium)
            }
            .padding(OneBoxSpacing.medium)
        }
        .background(OneBoxColors.primaryGraphite)
        .navigationTitle(tutorial.title)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Contact Support View

struct ContactSupportView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OneBoxSpacing.large) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(OneBoxColors.primaryGold)

                    Text("Contact Support")
                        .font(OneBoxTypography.heroTitle)
                        .foregroundColor(OneBoxColors.primaryText)

                    Text("We're here to help! Since OneBox is a privacy-first app, we don't collect any usage data. Please describe your issue below.")
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                        supportOption("Email Support", "envelope.fill", "support@onebox.app")
                        supportOption("In-App Feedback", "bubble.left.fill", "Use the feedback form in Settings")
                        supportOption("FAQ", "questionmark.circle.fill", "Check our frequently asked questions")
                    }
                    .padding(.top, OneBoxSpacing.large)
                }
                .padding(OneBoxSpacing.large)
            }
            .background(OneBoxColors.primaryGraphite)
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(OneBoxColors.primaryGold)
                }
            }
        }
    }

    private func supportOption(_ title: String, _ icon: String, _ detail: String) -> some View {
        HStack(spacing: OneBoxSpacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(OneBoxColors.primaryGold)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                Text(title)
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                Text(detail)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
        }
        .padding(OneBoxSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OneBoxColors.surfaceGraphite)
        .cornerRadius(OneBoxRadius.medium)
    }
}

// MARK: - Video Tutorials View

struct VideoTutorialsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OneBoxSpacing.large) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(OneBoxColors.primaryGold)

                    Text("Video Tutorials")
                        .font(OneBoxTypography.heroTitle)
                        .foregroundColor(OneBoxColors.primaryText)

                    Text("Video tutorials are coming soon! In the meantime, explore our written guides in the Help Center.")
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .multilineTextAlignment(.center)

                    VStack(spacing: OneBoxSpacing.medium) {
                        tutorialPlaceholder("Getting Started", "5 min")
                        tutorialPlaceholder("PDF Processing Basics", "8 min")
                        tutorialPlaceholder("Advanced Workflows", "12 min")
                        tutorialPlaceholder("Privacy Features", "6 min")
                    }
                    .padding(.top, OneBoxSpacing.medium)
                }
                .padding(OneBoxSpacing.large)
            }
            .background(OneBoxColors.primaryGraphite)
            .navigationTitle("Video Tutorials")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(OneBoxColors.primaryGold)
                }
            }
        }
    }

    private func tutorialPlaceholder(_ title: String, _ duration: String) -> some View {
        HStack {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(OneBoxColors.primaryGold.opacity(0.5))

            VStack(alignment: .leading) {
                Text(title)
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                Text(duration + " • Coming Soon")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.tertiaryText)
            }

            Spacer()
        }
        .padding(OneBoxSpacing.medium)
        .background(OneBoxColors.surfaceGraphite.opacity(0.5))
        .cornerRadius(OneBoxRadius.medium)
    }
}

// MARK: - Feature Tour View

struct FeatureTourView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentStep = 0

    private let tourSteps = [
        ("Fort Knox Security", "shield.lefthalf.filled", "All processing happens on your device. Your documents never leave your control."),
        ("Powerful PDF Tools", "doc.fill", "Merge, split, compress, sign, redact, and watermark PDFs with ease."),
        ("Smart Workflows", "gearshape.2.fill", "Automate repetitive tasks with customizable workflows."),
        ("Privacy Dashboard", "lock.shield.fill", "Monitor your security settings and audit trail in one place.")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: OneBoxSpacing.xxl) {
                Spacer()

                Image(systemName: tourSteps[currentStep].1)
                    .font(.system(size: 80))
                    .foregroundColor(OneBoxColors.primaryGold)

                Text(tourSteps[currentStep].0)
                    .font(OneBoxTypography.heroTitle)
                    .foregroundColor(OneBoxColors.primaryText)

                Text(tourSteps[currentStep].2)
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, OneBoxSpacing.large)

                Spacer()

                // Progress dots
                HStack(spacing: OneBoxSpacing.small) {
                    ForEach(0..<tourSteps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? OneBoxColors.primaryGold : OneBoxColors.surfaceGraphite)
                            .frame(width: 8, height: 8)
                    }
                }

                // Navigation buttons
                HStack(spacing: OneBoxSpacing.medium) {
                    if currentStep > 0 {
                        Button("Previous") {
                            withAnimation { currentStep -= 1 }
                        }
                        .foregroundColor(OneBoxColors.secondaryText)
                    }

                    Spacer()

                    Button(currentStep < tourSteps.count - 1 ? "Next" : "Done") {
                        if currentStep < tourSteps.count - 1 {
                            withAnimation { currentStep += 1 }
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    .fontWeight(.semibold)
                }
                .padding(.horizontal, OneBoxSpacing.large)
                .padding(.bottom, OneBoxSpacing.large)
            }
            .background(OneBoxColors.primaryGraphite)
            .navigationTitle("Feature Tour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") { dismiss() }
                        .foregroundColor(OneBoxColors.secondaryText)
                }
            }
        }
    }
}

// MARK: - Keyboard Shortcuts View

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OneBoxSpacing.large) {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 60))
                        .foregroundColor(OneBoxColors.primaryGold)

                    Text("Keyboard Shortcuts")
                        .font(OneBoxTypography.heroTitle)
                        .foregroundColor(OneBoxColors.primaryText)

                    Text("Use these shortcuts with an external keyboard on iPad.")
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .multilineTextAlignment(.center)

                    VStack(spacing: OneBoxSpacing.small) {
                        shortcutRow("New Document", "⌘ N")
                        shortcutRow("Open File", "⌘ O")
                        shortcutRow("Save", "⌘ S")
                        shortcutRow("Export", "⌘ E")
                        shortcutRow("Search", "⌘ F")
                        shortcutRow("Settings", "⌘ ,")
                        shortcutRow("Help", "⌘ ?")
                    }
                    .padding(.top, OneBoxSpacing.medium)
                }
                .padding(OneBoxSpacing.large)
            }
            .background(OneBoxColors.primaryGraphite)
            .navigationTitle("Keyboard Shortcuts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(OneBoxColors.primaryGold)
                }
            }
        }
    }

    private func shortcutRow(_ action: String, _ shortcut: String) -> some View {
        HStack {
            Text(action)
                .font(OneBoxTypography.body)
                .foregroundColor(OneBoxColors.primaryText)

            Spacer()

            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(OneBoxColors.primaryGold)
                .padding(.horizontal, OneBoxSpacing.small)
                .padding(.vertical, OneBoxSpacing.tiny)
                .background(OneBoxColors.surfaceGraphite)
                .cornerRadius(OneBoxRadius.small)
        }
        .padding(OneBoxSpacing.small)
    }
}

#Preview {
    HelpCenterView()
}