/// 의사는 반드시 병원에 연결된 값으로 생성합니다.
nonisolated public struct Doctor: Sendable {
    public let user: User
    public let code: String
    public let patients: [Patient]
    public let hospital: Hospital
    public let exerciseGoals: [ExerciseGoal]

    public init(user: User, code: String, patients: [Patient], hospital: Hospital, exerciseGoals: [ExerciseGoal]) {
        self.user = user
        self.code = code
        self.patients = patients
        self.hospital = hospital
        self.exerciseGoals = exerciseGoals
    }
}
