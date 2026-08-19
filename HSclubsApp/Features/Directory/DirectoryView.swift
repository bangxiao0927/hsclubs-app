import SwiftUI

struct DirectoryView: View {
    @Bindable var model: DirectoryViewModel
    @Bindable var schoolSelection: SchoolSelection

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading, model.directory == nil {
                    loadingView
                } else if let directory = model.directory {
                    directoryList(directory)
                } else {
                    failureView
                }
            }
            .background(Color(.systemGroupedBackground))
            .searchable(
                text: $model.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search by school or host"
            )
        }
    }

    private var loadingView: some View {
        ProgressView("Loading schools...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var failureView: some View {
        ContentUnavailableView {
            Label("Unable to load schools", systemImage: "wifi.exclamationmark")
        } description: {
            Text(model.errorMessage ?? "The directory is not available right now.")
        } actions: {
            Button("Try Again") {
                Task { await model.refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func directoryList(_ directory: AppDirectory) -> some View {
        let results = model.schools

        return ScrollView {
            LazyVStack(spacing: 12) {
                if let errorMessage = model.errorMessage {
                    notice(errorMessage, systemImage: "wifi.exclamationmark", tint: .orange)
                }

                if let cachedAt = model.cachedAt {
                    notice(
                        "Saved \(cachedAt.formatted(date: .abbreviated, time: .shortened))",
                        systemImage: "clock.arrow.circlepath",
                        tint: .secondary
                    )
                }

                if directory.schools.isEmpty {
                    ContentUnavailableView(
                        "No schools yet",
                        systemImage: "building.2",
                        description: Text("Waiting for the first verified directory.")
                    )
                    .frame(minHeight: 360)
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: model.query)
                        .frame(minHeight: 360)
                } else {
                    ForEach(results) { school in
                        Button {
                            guard school.enterableURL != nil else { return }
                            schoolSelection.select(school)
                        } label: {
                            SchoolRow(school: school)
                        }
                        .buttonStyle(.plain)
                        .disabled(school.enterableURL == nil)
                        .accessibilityIdentifier("school-card-\(school.slug)")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .refreshable {
            await model.refresh()
        }
    }

    private func notice(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SchoolRow: View {
    let school: DirectorySchool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: school.demo ? "flask.fill" : "building.2.fill")
                .font(.title3)
                .foregroundStyle(school.demo ? Color.purple : Color.accentColor)
                .frame(width: 36, height: 36)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(school.name)
                        .font(.headline)
                    if school.demo {
                        Text("Demo")
                            .font(.caption2.bold())
                            .foregroundStyle(.purple)
                    }
                }
                Text(school.host)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if school.enterableURL == nil {
                    // An incompatible school stays visible so a misconfiguration is not invisible,
                    // but says why and cannot be opened.
                    Label(
                        school.unavailableReason ?? "Unavailable right now",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }

            Spacer()
            if school.enterableURL != nil {
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .opacity(school.enterableURL == nil ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    DirectoryView(
        model: AppEnvironment.makeDirectoryViewModel(),
        schoolSelection: SchoolSelection()
    )
}
