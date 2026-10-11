/// 환자는 의사 연결 없이도 이용할 수 있습니다. 연관 값은 조회 시점의 스냅샷입니다.
nonisolated public struct Patient: Sendable {
    public let user: User
    public let doctor: Doctor?
    public let disease: CarcinomaDetail?
    public let painRecords: [PainRecord]
    public let symptomRecords: [SymptomRecord]
    public let intakeRecords: [IntakeRecord]
    public let exerciseGoals: [ExerciseGoal]

    public init(user: User, doctor: Doctor?, disease: CarcinomaDetail?, painRecords: [PainRecord],
                symptomRecords: [SymptomRecord], intakeRecords: [IntakeRecord], exerciseGoals: [ExerciseGoal]) {
        self.user = user
        self.doctor = doctor
        self.disease = disease
        self.painRecords = painRecords
        self.symptomRecords = symptomRecords
        self.intakeRecords = intakeRecords
        self.exerciseGoals = exerciseGoals
    }
}
