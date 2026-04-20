import SwiftUI

extension View {
    @ViewBuilder
    func onChangeCompat<Value: Equatable>(of value: Value, perform action: @escaping (Value) -> Void) -> some View {
        if #available(macOS 14.0, *) {
            onChange(of: value) {
                action(value)
            }
        } else {
            onChange(of: value, perform: action)
        }
    }
}
