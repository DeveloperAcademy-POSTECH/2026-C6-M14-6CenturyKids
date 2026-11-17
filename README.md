# 속닥 - 속마음을 닥터에게

<img width="1152" height="648" alt="배너" src="https://github.com/user-attachments/assets/d21afefe-e6e9-4960-962a-bdc38746a4d4" />

<img width="4096" height="442" alt="프로젝트 소개" src="https://github.com/user-attachments/assets/52a29099-b94f-46e2-ae97-3a206b3b5544" /> <br>
  
속닥은 통원 항암 환자가 병원 밖에서 겪은 통증과 증상을 기록하고, 의료진이 그 기록을 다음 진료에 활용할 수 있도록 돕는 앱입니다. <br>
iOS 27.0 이상의 iPhone 15 Pro, iPhone 15 Pro Max 및 이후 모델과 호환됩니다.

<a href="https://apps.apple.com/kr/app/id6823646328">
  <img
    src="https://github.com/user-attachments/assets/99e622e6-9df8-44c4-86c8-3312a2099b7a"
    width="130"
    height="40"
    alt="App Store에서 속닥 다운로드"
  />
</a><br>

<br><img width="4096" height="442" alt="UserStory" src="https://github.com/user-attachments/assets/2d0411b5-f4df-4039-b4c1-c1b05661b939" /><br>


> “선생님이 내가 그동안 얼마나 힘들었는지 알고 계실까?”

통원 항암 환자는 다음 진료를 기다리는 동안 여러 증상과 통증을 겪습니다. 몸에 생긴 변화가 괜찮은 건지, 진료 때 꼭 이야기해야 하는 건지 알기 어려울 때도 있습니다. 막상 진료실에 들어서면 그동안 겪은 일을 떠올려 무엇부터 말할지 정하고, 짧은 시간 안에 설명해야 합니다.

의료진 역시 진료 사이에 환자가 어떻게 지냈는지 알기 어렵습니다. “많이 아프셨어요?”, “약을 드시고 좀 나아지셨어요?” 같은 질문으로 대화를 시작하지만, 짧은 진료 안에서 통증이 언제 심해졌는지, 약을 먹은 뒤 얼마나 달라졌는지까지 파악하기는 쉽지 않습니다. 환자에게는 자신의 어려움이 충분히 전해졌는지 아쉬움이 남고, 의료진에게는 변화를 구체적으로 이해할 정보가 필요합니다.

속닥은 환자가 일상에서 남긴 기록으로 진료실의 첫 질문이 달라지도록 만들었습니다. 의료진이 기록을 보고 “약을 드신 뒤에도 통증이 남아 있었네요. 그때 어떤 점이 가장 힘드셨어요?”라고 묻는다면, 환자는 지난 일을 처음부터 설명해야 하는 부담을 덜고 자신에게 가장 중요했던 이야기부터 꺼낼 수 있습니다.

그렇게 환자가 **선생님이 내가 어떻게 지냈는지 알고, 신경 써 주고 계시는구나**라고 느끼는 것. 저희가 속닥으로 만들고 싶은 연결감입니다.

**병원 밖에서의 3주가, 진료실 안의 3분에 담길 수 있도록.**

<br><img width="4096" height="442" alt="MainFeatures" src="https://github.com/user-attachments/assets/cc8674ec-cf21-4724-b51b-450bff92cecc" /><br>

| 기능 | 설명 |
| --- | --- |
| **대화형 증상 기록** | 미니 의사 ‘속닥이’ 캐릭터의 질문에 답하며 증상이 언제 나타났는지, 얼마나 자주 발생했고 얼마나 오래 지속됐는지 기록할 수 있습니다. 답변은 증상별 원문으로 의료진에게 전달됩니다. |
| **진통제 복용 전후 통증 기록** | 돌발성 통증이 발생했을 때에는 통증 부위와 강도를 기록할 수 있습니다. 기록이 생기면 실시간 현황(Live Activity)에서 1시간 타이머가 시작되며, 타이머가 끝나면 변화한 통증 강도를 다시 기록할 수 있습니다. |
| **진료 전 할 말과 마음 정리** | 통증·증상 기록에서 진료 때 이야기하고 싶은 내용을 고르고, 추가로 의료진에게 하고픈 말을 전달할 수 있습니다. |
| **기록을 돕는 알림** | 매일 사용자가 설정한 시간에 증상 기록을 알리는 실시간 현황(Live Activity)을 받을 수 있습니다. 또, 연결된 병원 근처에 도착하면 알림을 통해 진료 전 할 말을 정리할 수 있도록 돕습니다. |

<br><img width="4096" height="442" alt="TechStack" src="https://github.com/user-attachments/assets/58f95f51-c2b5-4ef1-9978-26da20a101a9" /><br>

<img src="https://img.shields.io/badge/swift-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift"/>
<img src="https://img.shields.io/badge/supabase-3FCF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase"/>

### 주요 프레임워크

| 사용 기술 | 사용되는 곳 |
| --- | --- |
| **ActivityKit + WidgetKit + UserNotifications**| 실시간 현황(Live Activity)를 통해 통증 및 증상 기록을 잊지 않고 할 수 있도록 돕습니다. |
| **AVFoundation + Speech + CoreAI + FoundationModels** | 마이크로 받은 음성을 텍스트로 변환하고, 환자의 답변을 바탕으로 다음 질문을 생성하는 데 사용됩니다. |

<br><img width="4096" height="442" alt="팀 소개" src="https://github.com/user-attachments/assets/9eea1ba4-3243-47ed-a983-fada9585074a" /><br>

| [Andy (안동선)](https://www.linkedin.com/in/dongsun-an-301034402) | [Enzo (양은서)](https://www.linkedin.com/in/은서-양-526a463b5) | [Jody (조재윤)](https://www.linkedin.com/in/jaeyooncho0427/) | [Pony (최연우)](https://www.linkedin.com/in/nuarc/) | [Hazi (허지우)](https://www.linkedin.com/in/jiwoo-heo-46530033b/) | [Hosu (양석호)](https://www.linkedin.com/in/seokhoyang/) |
| --- | --- | --- | --- | --- | --- |
| <img width="371" height="371" alt="Mask group-2" src="https://github.com/user-attachments/assets/e68c5d97-f22a-4591-8279-468273ddea06" /> | <img width="371" height="371" alt="Mask group-5" src="https://github.com/user-attachments/assets/9acc4cc3-1a7f-4082-be3f-9fd222ace6eb" /> | <img width="371" height="371" alt="Mask group-4" src="https://github.com/user-attachments/assets/9f257c4b-6efd-4943-9b93-5b4e2b039b48" /> | <img width="371" height="371" alt="Mask group" src="https://github.com/user-attachments/assets/6d233bc3-0c1c-4ab1-8809-f28872b6739d" /> | <img width="371" height="371" alt="Mask group-1" src="https://github.com/user-attachments/assets/4a8bc1ff-6e83-4768-bf0a-a15f5357c2a3" /> | <img width="371" height="371" alt="Mask group-3" src="https://github.com/user-attachments/assets/c8b7e4e2-f8ca-4b82-9666-d46e081944ea" /> |
| iOS Developer<br>Backend Developer | iOS Developer<br>Project Manager | Product Designer | Brand Designer | iOS Developer<br>Product Manager | iOS Developer<br>AI Engineer |
