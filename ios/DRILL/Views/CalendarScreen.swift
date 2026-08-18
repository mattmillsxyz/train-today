import SwiftUI

/// A scrollable run of months, Monday-first, coloured by what actually got done.
///
/// This replaces the web app's one-row week strip. The strip could only ever
/// show seven days; a month grid is where you can see a streak building or a
/// fortnight going quiet, and tapping a day opens it on Today.
struct CalendarScreen: View {
    @Environment(AppState.self) private var app
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(TrainingStore.self) private var store

    /// How far the calendar reaches. A year back is more history than the app
    /// can have; three months forward is enough to see a plan change land.
    private let monthsBack = 12
    private let monthsForward = 3

    private var settings: PlanSettings { settingsStore.settings }

    var body: some View {
        let calculator = ProgressCalculator(store: store, settings: settings)

        ScrollViewReader { proxy in
            // One fixed weekday row for the whole screen. Per-month rows get
            // hidden under the pinned month heading as soon as you scroll.
            VStack(spacing: 0) {
                weekdayHeader
                ScrollView {
                LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                    ForEach(months, id: \.self) { month in
                        Section {
                            MonthGrid(month: month, calculator: calculator) { day in
                                app.open(day)
                            }
                            .id(month)
                        } header: {
                            monthHeader(month)
                        }
                    }
                }
                .appColumn()
                .padding(.horizontal, 12)
                .padding(.bottom, 16)

                legend
                    .appColumn()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 24)
                }
                .onAppear {
                    proxy.scrollTo(TrainingCalendar.startOfMonth(app.selectedDate), anchor: .center)
                }
            }
            .background(Theme.bg)
        }
        .navigationTitle("Calendar")
        // The scroll view no longer touches the bar, so without this the large
        // title has nothing to collapse against and never draws.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Today") { app.open(app.today) }
                    .font(.system(size: 15, weight: .semibold))
            }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { day in
                Text(Weekdays.initials[day])
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .appColumn()
        .background(Theme.bg)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    /// Anchored on `app.today` rather than `.now`, so the window slides to the
    /// new month on a rollover instead of waiting for an unrelated redraw.
    private var months: [Date] {
        let thisMonth = TrainingCalendar.startOfMonth(app.today)
        return (-monthsBack...monthsForward).compactMap {
            TrainingCalendar.calendar.date(byAdding: .month, value: $0, to: thisMonth)
        }
    }

    private func monthHeader(_ month: Date) -> some View {
        HStack {
            Text(month, format: .dateTime.month(.wide).year())
                .font(.system(size: 18, weight: .bold))
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(Theme.bg)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach([DayStatus.complete, .partial, .upcoming, .missed, .rest], id: \.self) { status in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DayStatus.fill(for: status))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.border, lineWidth: status == .rest ? 1 : 0))
                        .frame(width: 12, height: 12)
                    Text(status.legendLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Month grid

private struct MonthGrid: View {
    let month: Date
    let calculator: ProgressCalculator
    let onSelect: (Date) -> Void

    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 4) {
            ForEach(weeks, id: \.self) { week in
                HStack(spacing: 4) {
                    ForEach(week, id: \.self) { day in
                        if let day {
                            DayCell(
                                day: day,
                                status: calculator.status(of: day),
                                isSelected: TrainingCalendar.isSameDay(day, app.selectedDate),
                                isToday: TrainingCalendar.isSameDay(day, app.today)
                            ) {
                                onSelect(day)
                            }
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: 44)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }

    /// Monday-first rows, padded with `nil` before the first and after the last.
    private var weeks: [[Date?]] {
        let calendar = TrainingCalendar.calendar
        let first = TrainingCalendar.startOfMonth(month)
        let dayCount = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let leading = TrainingCalendar.weekday(first)

        var cells: [Date?] = Array(repeating: nil, count: leading)
        cells += (0..<dayCount).map { TrainingCalendar.adding(days: $0, to: first) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }
}

private struct DayCell: View {
    let day: Date
    let status: DayStatus
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(TrainingCalendar.calendar.component(.day, from: day))")
                .font(.system(size: 15, weight: isToday ? .bold : .medium))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(DayStatus.fill(for: status), in: .rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isSelected ? Theme.text : (isToday ? Theme.green : .clear),
                            lineWidth: 2
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).month().day()))
        .accessibilityValue(status.legendLabel)
    }

    private var foreground: Color {
        DayStatus.foreground(for: status)
    }
}

extension DayStatus: Hashable {
    var legendLabel: String {
        switch self {
        case .complete: "Done"
        case .partial: "Partly"
        case .missed: "Missed"
        case .upcoming: "Scheduled"
        case .rest: "Rest"
        }
    }

    /// The five states have to be told apart at a glance on a grid of 30 small
    /// squares, which rules out five shades of the same grey. Scheduled days get
    /// the green tint, because "is there a workout on Thursday?" is the question
    /// this screen exists to answer.
    static func fill(for status: DayStatus) -> Color {
        switch status {
        case .complete: Theme.green
        case .partial: Theme.green.opacity(0.4)
        case .missed: Theme.border
        case .upcoming: Theme.greenLight
        case .rest: .clear
        }
    }

    static func foreground(for status: DayStatus) -> Color {
        switch status {
        case .complete: Theme.ink
        case .partial, .upcoming: Theme.text
        case .missed: Theme.textSecondary
        case .rest: Theme.textSecondary.opacity(0.5)
        }
    }
}
