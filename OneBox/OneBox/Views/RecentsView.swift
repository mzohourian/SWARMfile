//
//  RecentsView.swift
//  OneBox
//

import SwiftUI
import JobEngine

struct RecentsView: View {
    @EnvironmentObject var jobManager: JobManager
    @State private var selectedJob: Job?

    private var recentJobs: [Job] {
        jobManager.jobs
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(20)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if recentJobs.isEmpty {
                    emptyState
                } else {
                    jobsList
                }
            }
            .navigationTitle("Recents")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedJob) { job in
                JobResultView(job: job)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Recent Jobs")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your processed files will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var jobsList: some View {
        List {
            ForEach(recentJobs) { job in
                JobRow(job: job)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedJob = job
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            jobManager.deleteJob(job)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Job Row
struct JobRow: View {
    let job: Job

    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            statusIcon
                .frame(width: 40, height: 40)
                .background(statusColor.opacity(0.1))
                .cornerRadius(8)

            // Job Info
            VStack(alignment: .leading, spacing: 4) {
                Text(job.type.displayName)
                    .font(.headline)

                Text(job.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if job.status == .running {
                    ProgressView(value: job.progress)
                        .tint(statusColor)
                }
            }

            Spacer()

            // Action Button
            if job.status == .success {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if job.status == .failed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: some View {
        Image(systemName: statusIconName)
            .foregroundColor(statusColor)
    }

    private var statusIconName: String {
        switch job.status {
        case .pending: return "clock"
        case .running: return "arrow.triangle.2.circlepath"
        case .success: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch job.status {
        case .pending: return .orange
        case .running: return .blue
        case .success: return .green
        case .failed: return .red
        }
    }
}

#Preview {
    RecentsView()
        .environmentObject(JobManager.shared)
}
