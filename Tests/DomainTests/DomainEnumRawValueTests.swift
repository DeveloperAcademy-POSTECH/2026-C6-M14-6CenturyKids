import XCTest
import ToDocDomain

final class DomainEnumRawValueTests: XCTestCase {
    private func assertContract<T: RawRepresentable & CaseIterable & Equatable>(
        _ type: T.Type, _ expected: [(T, String)],
        file: StaticString = #filePath, line: UInt = #line
    ) where T.RawValue == String {
        XCTAssertEqual(Array(T.allCases), expected.map(\.0), file: file, line: line)
        XCTAssertEqual(Set(expected.map(\.1)).count, expected.count, file: file, line: line)
        for (value, rawValue) in expected {
            XCTAssertEqual(value.rawValue, rawValue, file: file, line: line)
            XCTAssertEqual(T(rawValue: rawValue), value, file: file, line: line)
        }
        for unsupported in ["", "__unknown__", expected[0].1.uppercased(), " " + expected[0].1] {
            XCTAssertNil(T(rawValue: unsupported), file: file, line: line)
        }
    }

    func testSexContract() {
        assertContract(Sex.self, [(.male, "male"), (.female, "female")])
    }

    func testCarcinomaStageContract() {
        assertContract(CarcinomaStage.self, [
            (.stage0, "stage0"), (.stage1, "stage1"), (.stage2, "stage2"),
            (.stage3, "stage3"), (.stage4, "stage4"), (.unknown, "unknown")
        ])
    }

    func testCarcinomaTypeContract() {
        assertContract(CarcinomaType.self, [
            (.liver, "liver"), (.thyroid, "thyroid"), (.gallbladderAndBileDuct, "gallbladderAndBileDuct"),
            (.colorectal, "colorectal"), (.kidney, "kidney"), (.stomach, "stomach"),
            (.breast, "breast"), (.prostate, "prostate"), (.pancreas, "pancreas"), (.lung, "lung"),
            (.larynx, "larynx"), (.thymus, "thymus"), (.esophagus, "esophagus"),
            (.smallIntestine, "smallIntestine"), (.anus, "anus"), (.other, "other")
        ])
    }

    func testApprovedAdditionalCancerValuesAndStageLimit() {
        let additions = [("larynx", "후두암"), ("thymus", "흉선암"), ("esophagus", "식도암"),
                         ("smallIntestine", "소장암"), ("anus", "항문암")]
        for (raw, korean) in additions {
            XCTAssertEqual(CarcinomaType(rawValue: raw)?.displayName, korean)
        }
        XCTAssertEqual(CarcinomaType.allCases.count, 16)
        XCTAssertNil(CarcinomaStage(rawValue: "terminal"))
        XCTAssertEqual(CarcinomaStage.allCases.map(\.displayName), ["0기", "1기", "2기", "3기", "4기", "모르겠어요"])
    }

    func testMealTypeContract() {
        assertContract(MealType.self, [(.breakfast, "breakfast"), (.lunch, "lunch"), (.dinner, "dinner")])
    }

    func testIntakeAmountContract() {
        assertContract(IntakeAmount.self, [
            (.veryFull, "veryFull"), (.moderate, "moderate"),
            (.smallAmount, "smallAmount"), (.barelyAte, "barelyAte")
        ])
    }

    func testBodyPartContract() {
        assertContract(BodyPart.self, [
            (.headFace, "headFace"), (.neck, "neck"), (.shoulder, "shoulder"), (.chest, "chest"),
            (.abdomen, "abdomen"), (.backLowerBack, "backLowerBack"),
            (.pelvisButtocks, "pelvisButtocks"), (.armHand, "armHand"), (.legFoot, "legFoot")
        ])
    }

    func testBodySideContractIncludesBothAndUnspecified() {
        assertContract(BodySide.self, [
            (.left, "left"), (.right, "right"), (.center, "center"),
            (.both, "both"), (.unspecified, "unspecified")
        ])
    }

    func testBodyViewContractIncludesUnspecified() {
        assertContract(BodyView.self, [(.front, "front"), (.back, "back"), (.unspecified, "unspecified")])
    }

    func testSymptomTypeContract() {
        assertContract(SymptomType.self, [
            (.nauseaVomiting, "nauseaVomiting"), (.constipation, "constipation"),
            (.diarrhea, "diarrhea"), (.oralPain, "oralPain"), (.numbness, "numbness"),
            (.rashItching, "rashItching"), (.dehydrationNutrition, "dehydrationNutrition"),
            (.other, "other")
        ])
    }
}
