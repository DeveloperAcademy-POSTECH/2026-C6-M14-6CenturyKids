import XCTest
import ToDocDomain
@testable import ToDocHome

@MainActor final class HomeViewModelTests: XCTestCase {
    private let patientID = UUID()
    private let firstDoctor = UUID()
    private let secondDoctor = UUID()
    private var patients = Patients()
    private var doctors = Doctors()
    private var model: HomeViewModel!

    private func reset() {
        patients = Patients()
        doctors = Doctors()
        patients.value = patient(patientID, doctorID: firstDoctor)
        doctors.value = doctor(firstDoctor)
        model = HomeViewModel(repositories: .init(patients: patients, doctors: doctors))
    }
    private func context(_ id: UUID, visible: Bool = true) -> HomeContext {
        .init(patientID: id, isVisible: visible, isAppActive: true)
    }

    func testHomeReentryReadsChangedDoctorAndDisconnection() async {
        reset()
        await model.updateContext(context(patientID))?.value
        XCTAssertEqual(model.state.doctorName, "첫 의사")
        model.updateContext(context(patientID, visible: false))
        patients.value = patient(patientID, doctorID: secondDoctor)
        doctors.value = doctor(secondDoctor)
        await model.updateContext(context(patientID))?.value
        XCTAssertEqual(model.state.doctorName, "새 의사")
        model.updateContext(context(patientID, visible: false))
        patients.value = patient(patientID, doctorID: nil)
        await model.updateContext(context(patientID))?.value
        XCTAssertEqual(model.state.doctor, .loaded(.unlinked))
        XCTAssertNil(model.state.doctorName)
    }

    func testLookupFailureCanBeRetried() async {
        reset()
        patients.load = { throw LookupFailure() }
        await model.updateContext(context(patientID))?.value
        XCTAssertEqual(model.state.doctor, .failed(.loadFailed, previous: nil))
        patients.load = nil
        await model.reload()?.value
        XCTAssertEqual(model.state.doctorName, "첫 의사")
    }

    func testBothLookupsRejectLateRepliesAfterCancellationOrAccountChange() async {
        for doctorLookup in [false, true] {
            for accountChange in [false, true] {
                reset()
                let patientReply = Reply<Patient?>()
                let doctorReply = Reply<Doctor?>()
                if doctorLookup { doctors.load = { try await doctorReply.wait() } }
                else { patients.load = { try await patientReply.wait() } }
                let request = model.updateContext(context(patientID))
                await fulfillment(of: [doctorLookup ? doctorReply.started : patientReply.started], timeout: 2)
                patients.load = nil
                doctors.load = nil
                if accountChange {
                    let nextPatient = UUID()
                    patients.value = patient(nextPatient, doctorID: secondDoctor)
                    doctors.value = doctor(secondDoctor)
                    await model.updateContext(context(nextPatient))?.value
                    XCTAssertEqual(model.state.doctorName, "새 의사")
                } else {
                    model.cancel()
                    XCTAssertEqual(model.state.doctor, .idle)
                }
                let expected = model.state.doctor
                if doctorLookup {
                    doctorReply.finish(accountChange ? .success(doctor(firstDoctor)) : .failure(LookupFailure()))
                } else {
                    patientReply.finish(accountChange ? .success(patient(patientID, doctorID: firstDoctor)) : .failure(LookupFailure()))
                }
                await request?.value
                XCTAssertEqual(model.state.doctor, expected)
            }
        }
    }

    private func user(_ id: UUID, name: String = "가상 환자") -> User {
        try! User(id: id, name: name, birthday: Date(timeIntervalSince1970: 631152000), sex: .female)
    }
    private func patient(_ id: UUID, doctorID: UUID?) -> Patient {
        Patient(user: user(id), doctorId: doctorID, disease: nil)
    }
    private func doctor(_ id: UUID) -> Doctor {
        Doctor(user: user(id, name: id == firstDoctor ? "첫 의사" : "새 의사"), code: "HOME01", hospitalId: UUID())
    }
}

private struct LookupFailure: Error {}

@MainActor private final class Patients: PatientRepository {
    var value: Patient?
    var load: (() async throws -> Patient?)?
    func findById(_ id: UUID) async throws -> Patient? {
        if let load { return try await load() }
        return value
    }
    func save(patient: Patient) async throws { XCTFail("Home must only read") }
    func findByName(_ name: String) async throws -> [Patient] {
        XCTFail("Unexpected lookup")
        return []
    }
    func findByDoctorId(_ id: UUID) async throws -> [Patient] {
        XCTFail("Unexpected lookup")
        return []
    }
    func connectToDoctor(code: String) async throws { XCTFail("Home must only read") }
    func disconnectFromDoctor() async throws { XCTFail("Home must only read") }
}

@MainActor private final class Doctors: DoctorRepository {
    var value: Doctor?
    var load: (() async throws -> Doctor?)?
    func findById(_ id: UUID) async throws -> Doctor? {
        if let load { return try await load() }
        return value
    }
    func save(doctor: Doctor) async throws { XCTFail("Home must only read") }
    func findByName(_ name: String) async throws -> [Doctor] {
        XCTFail("Unexpected lookup")
        return []
    }
    func findByHospitalId(_ id: UUID) async throws -> [Doctor] {
        XCTFail("Unexpected lookup")
        return []
    }
    func findByCode(_ code: String) async throws -> Doctor? {
        XCTFail("Unexpected lookup")
        return nil
    }
    func findConnectionInfoByCode(_ code: String) async throws -> DoctorConnectionInfo? {
        XCTFail("Home must use the saved doctor ID")
        return nil
    }
}

@MainActor private final class Reply<Value> {
    let started = XCTestExpectation(description: "Lookup started")
    private var continuation: CheckedContinuation<Value, Error>?
    func wait() async throws -> Value {
        try await withCheckedThrowingContinuation {
            continuation = $0
            started.fulfill()
        }
    }
    func finish(_ result: Result<Value, Error>) {
        continuation?.resume(with: result)
    }
}
