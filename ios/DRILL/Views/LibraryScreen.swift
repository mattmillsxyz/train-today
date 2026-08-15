import SwiftUI

/// Every exercise in the library, grouped by tag — the app's version of the
/// `exercises.html` reference page.
struct LibraryScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var grouped: [(tag: Tag, exercises: [Exercise])] {
        let matching = ExerciseLibrary.shared.all.filter { exercise in
            search.isEmpty
                || exercise.name.localizedCaseInsensitiveContains(search)
                // The category is the obvious thing to search for, and the
                // sections are already labelled with it. "Plyometrics" is
                // accepted too, since that is the word the site and the
                // onboarding blurb use for the `plyo` tag.
                || exercise.tag.matchesSearch(search)
                || exercise.steps.contains { $0.text.localizedCaseInsensitiveContains(search) }
        }
        return Dictionary(grouping: matching, by: \.tag)
            .sorted { $0.key < $1.key }
            .map { (tag: $0.key, exercises: $0.value.sorted { $0.name < $1.name }) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.tag) { group in
                    Section(group.tag.displayName) {
                        ForEach(group.exercises) { exercise in
                            NavigationLink {
                                ExerciseDetail(exercise: exercise)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name).font(.system(size: 16, weight: .semibold))
                                    Text(exercise.displayDuration)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ExerciseDetail: View {
    let exercise: Exercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    TagLabel(tag: exercise.tag)
                    Text(exercise.name).font(.system(size: 26, weight: .bold))
                    Text(exercise.displayDuration)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                }

                if let metric = exercise.prMetric {
                    Label("Tracks: \(metric.label)", systemImage: "trophy")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.greenDark)
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeading(text: "How to do it:")
                    NumberedSteps(steps: exercise.steps.map(\.text))
                }
                .padding(14)
                .background(Theme.card, in: .rect(cornerRadius: 14))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appColumn()
            .padding(16)
        }
        .background(Theme.bg)
        .navigationBarTitleDisplayMode(.inline)
    }
}
