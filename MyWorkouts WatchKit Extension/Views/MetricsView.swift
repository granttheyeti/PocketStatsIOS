/*
 https://stackoverflow.com/questions/60532968/how-do-i-prevent-interface-controller-from-locking-screen-watchos
 
*/

import SwiftUI
import HealthKit

//@available(watchOS 9.0, *)
struct MetricsView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var scrollAmount = 0.0
    @State private var prevScrollAmount = 0.0
    @State private var up = false
    @State private var cooloff = false

    @State var upCount = 0
    @State var downCount = 0
    
    var body: some View {
        TimelineView(MetricsTimelineSchedule(from: workoutManager.builder?.startDate ?? Date(),
                                             isPaused: workoutManager.session?.state == .paused)) { context in
            VStack(alignment: .center) {
                if #available(watchOS 9.0, *) {
                    Text("\(upCount)/\(upCount + downCount)")
                    .focusable(true)
                    .digitalCrownRotation($scrollAmount, onChange: {
                        event in
                        if (!cooloff) {
                            if (event.offset  > prevScrollAmount) {
                                self.upCount = self.upCount + 1
                                self.up = true
                                WKInterfaceDevice.current().play(.success)
                            } else {
                                self.downCount = self.downCount + 1
                                self.up = false
                                WKInterfaceDevice.current().play(.failure)
                            }
                            cooloff = true
                        }
                        self.prevScrollAmount = event.offset
                    }, onIdle: { cooloff = false })
                    .font(.system(size: 500))
                    .minimumScaleFactor(0.01).foregroundColor(cooloff ? (up ? .green : .red) : .yellow)
//                            .digitalCrownAccessory { Text("wait") }
                    
                } else {
                    Text("Please update to watchOS 9.0")
                }
                if (upCount > 0) {
                    Text((Double(upCount)/Double(upCount + downCount)).formatted(.percent.precision(.significantDigits(2)))).font(.system(.title, design: .rounded)).foregroundColor(.teal)
                }
//                Text(workoutManager.heartRate.formatted(.number.precision(.fractionLength(0))) + " bpm")
//                Text(Measurement(value: workoutManager.distance, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road)))
                ElapsedTimeView(elapsedTime: workoutManager.builder?.elapsedTime(at: context.date) ?? 0, showSubseconds: context.cadence == .live).font(.system(.body, design: .rounded).monospacedDigit().lowercaseSmallCaps())
            }
        }
            // .font(.system(.title, design: .rounded).monospacedDigit().lowercaseSmallCaps())
            .frame(maxWidth: .infinity, alignment: .center)
            .ignoresSafeArea(edges: .bottom)
            .scenePadding()
    }
}

struct MetricsView_Previews: PreviewProvider {
    static var previews: some View {
        MetricsView().environmentObject(WorkoutManager())
    }
}

private struct MetricsTimelineSchedule: TimelineSchedule {
    var startDate: Date
    var isPaused: Bool

    init(from startDate: Date, isPaused: Bool) {
        self.startDate = startDate
        self.isPaused = isPaused
    }

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var baseSchedule = PeriodicTimelineSchedule(from: self.startDate,
                                                    by: (mode == .lowFrequency ? 1.0 : 1.0 / 30.0))
            .entries(from: startDate, mode: mode)
        
        return AnyIterator<Date> {
            guard !isPaused else { return nil }
            return baseSchedule.next()
        }
    }
}
