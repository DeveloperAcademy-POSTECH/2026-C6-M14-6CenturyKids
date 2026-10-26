import SwiftUI

struct SettingsProfileAvatar: View {
    var size: CGFloat = 120
    var body: some View {
        LinearGradient(colors: [Color(red: 207 / 255, green: 233 / 255, blue: 161 / 255),
                                Color(red: 158 / 255, green: 197 / 255, blue: 88 / 255)],
                       startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .top) {
                Image("PrevisitDoctorFace").resizable().scaledToFit()
                    .frame(width: size * 1.525, height: size * 1.525).offset(y: size * 0.075)
            }
            .frame(width: size, height: size).clipShape(Circle()).accessibilityHidden(true)
    }
}
