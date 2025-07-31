import SwiftUI

@available(iOS 15.0, *)
struct FatalMigrationErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)

            Text("Data Migration Failed")
                .font(.title)
                .fontWeight(.bold)

            Text("LifeMeter encountered an issue loading your data. Please reinstall the app or contact support.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Text(error.localizedDescription)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }
}

