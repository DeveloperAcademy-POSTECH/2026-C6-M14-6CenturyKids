import SwiftUI

/// Figma '진료 전 길록 바텀시트 플로우'(753:535)의 지난 기록 화면들이 함께 쓰는 조각입니다.
/// 아이콘은 Figma에서 아직 자리만 잡혀 있어 SF Symbol로 둡니다.
struct PrevisitIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName).font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.Semantic.Text.sub)
                .frame(width: 44, height: 44)
                .background(AppColors.Semantic.Background.default, in: Circle())
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}

/// Figma Page Title(Center): 작은 윗글 + 제목
struct PrevisitPageTitle: View {
    let sub: String
    let title: String

    var body: some View {
        VStack(spacing: 4) {
            Text(sub).appText(.label).foregroundStyle(AppColors.Semantic.Text.sub)
            Text(title).appText(.title).foregroundStyle(AppColors.Semantic.Text.default)
                .accessibilityAddTraits(.isHeader)
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
    }
}

/// Figma Body: 뒤로 버튼 줄(44) · 제목 · 4 여백, 사이 16
struct PrevisitScreenHeader: View {
    let sub: String
    let title: String
    let backLabel: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            PrevisitIconButton(systemName: "chevron.left", label: backLabel, action: onBack)
                .frame(maxWidth: .infinity, alignment: .leading)
            PrevisitPageTitle(sub: sub, title: title)
            Color.clear.frame(height: 4)
        }
    }
}

/// Figma Day Record Card: 고른 날 + 요일 + 점 목록
struct PrevisitRecordDayCard: View {
    let title: String
    let weekday: String
    let entries: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).appText(.labelLarge).foregroundStyle(AppColors.Semantic.Text.default)
                Text(weekday).appText(.label).foregroundStyle(AppColors.Semantic.Text.disabled)
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array((entries.isEmpty ? ["기록 없음"] : entries).enumerated()), id: \.offset) { _, entry in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Circle().fill(AppColors.Semantic.Border.error).frame(width: 6, height: 6)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 1 }
                        Text(entry).appText(.bodySmall).foregroundStyle(AppColors.Semantic.Text.default)
                    }
                }
            }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 30))
    }
}

/// Figma Mood Option(보조 문구 없음). 고른 상태는 background/selected
struct PrevisitMoodCard: View {
    let mood: PrevisitMood
    var selected = false

    var body: some View {
        HStack(spacing: 20) {
            PrevisitDoctorAvatar(mood: mood, size: 40)
            Text(mood.title).appText(.body).foregroundStyle(AppColors.Semantic.Text.default)
                .frame(maxWidth: .infinity, alignment: .leading)
        }.padding(24)
            .background(selected ? AppColors.Semantic.Background.selected : AppColors.Semantic.Background.surface,
                        in: RoundedRectangle(cornerRadius: 30))
    }
}

/// Figma Note Card: To. 주치의 / 내용 / From. 환자
struct PrevisitNoteCard: View {
    let doctorName: String
    let letter: String
    var patientName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("To. \(doctorName)").appText(.caption).foregroundStyle(AppColors.Semantic.Text.sub)
            Text(letter.isEmpty ? "남긴 말이 없어요" : letter).appText(.body)
                .foregroundStyle(letter.isEmpty ? AppColors.Semantic.Text.placeholder : AppColors.Semantic.Text.default)
            if !patientName.isEmpty {
                Text("From. \(patientName)").appText(.caption).foregroundStyle(AppColors.Semantic.Text.sub)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 30))
    }
}

/// Figma Toast: 진한 바탕 + 흰 글자, 2초 뒤 사라짐
struct PrevisitToast: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        Text(message).appText(.bodySmall).foregroundStyle(AppColors.Semantic.Text.inverse)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(AppColors.Semantic.Background.inverse, in: Capsule())
            .accessibilityAddTraits(.isStaticText)
            .task {
                AccessibilityNotification.Announcement(message).post()
                try? await Task.sleep(for: .seconds(2))
                onDismiss()
            }
    }
}

/// Figma Dialog(Button): 제목·설명 + 되돌릴 수 없는 버튼 + 글자 버튼
struct PrevisitDialog: View {
    let title: String
    let message: String
    let destructiveTitle: String
    let cancelTitle: String
    let onDestructive: () -> Void
    let onCancel: () -> Void

    var body: some View {
        SymptomPopup {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text(title).appText(.labelLarge).foregroundStyle(AppColors.Semantic.Text.default)
                        .accessibilityAddTraits(.isHeader)
                    Text(message).appText(.bodySmall).foregroundStyle(AppColors.Semantic.Text.sub)
                }
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24).padding(.top, 32).padding(.bottom, 24)
                VStack(spacing: 4) {
                    Button(action: onDestructive) {
                        Text(destructiveTitle).appText(.labelLarge).foregroundStyle(AppColors.Semantic.Text.error)
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .background(AppColors.Semantic.Background.error, in: Capsule())
                            .contentShape(Capsule())
                    }.buttonStyle(.plain)
                    Button(action: onCancel) {
                        Text(cancelTitle).appText(.labelLarge).foregroundStyle(AppColors.Semantic.Text.action)
                            .padding(.horizontal, 16).frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 20).padding(.bottom, 20)
            }
        }
    }
}
