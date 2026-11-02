extends RefCounted
## All campaign tuning, recipes and authored story beats live here.

const MATERIALS = ["기획", "프로그래밍", "그래픽", "QA"]
const PRODUCTS = ["콘텐츠 기획서", "시스템 기획서", "캐릭터 코드", "코드 수정본", "그래픽 수정본", "게임 빌딩", "아트 작업물 완성본", "오류뭉텅이"]
const RECIPES = {"0+0": 4, "0+1": 5, "1+2": 6, "1+3": 7, "2+3": 8, "1+1": 9, "2+2": 10}
const RECIPE_PAIRS = [[0,0], [0,1], [1,2], [1,3], [2,3], [1,1], [2,2]]
const CHAPTERS = ["01 / NEON CAMPUS", "02 / FANTASY ARCHIVE", "03 / FINAL BUILD"]
const SUBTITLES = ["1학년 · 첫 번째 수업 프로젝트", "2학년 · 협업 프로젝트", "3학년 · 졸업작품"]
const THEMES = [Color("65edcc"), Color("c5a0ff"), Color("ffc879")]
const STAGE_NAMES = [
 ["검은 화면 너머", "첫 번째 컴파일", "사라진 캐릭터", "색을 되찾는 법", "테스트의 시간", "충돌하는 코드", "밤샘 실습실", "분홍색 예외", "제출 5분 전", "HELLO, WORLD!"],
 ["깨어난 아카이브", "마법사의 변수", "기사의 스프라이트", "길 잃은 퀘스트", "저주받은 루프", "팀원의 메시지", "드래곤의 메모리", "무너지는 성벽", "마지막 병합", "함께 만든 세계"],
 ["졸업작품.exe", "도시의 노이즈", "복제된 신호", "과부하", "고장 난 신호등", "최종 QA", "릴리스 후보", "크런치 타임", "돌아갈 좌표", "DEPLOY TO REALITY"]
]
const INTRO = [
 ["밤새 만든 게임을 실행했다. 모니터는 검게 물들었고… 눈을 뜨니 코드 속이었다.", "첫 단말기가 응답했다. 기획과 코드를 잇자 끊겼던 길이 모습을 드러낸다.", "주인공의 스프라이트가 사라졌다. 코드에 그래픽을 연결해야 한다.", "회색뿐이던 실습실. 이번엔 색을 되돌려 보자.", "실행은 된다. 하지만 제대로 동작하는 걸까? QA 데이터가 필요하다.", "서로 다른 코드가 충돌한다. 조합표를 확인하고 정확한 패치를 보내자.", "현실의 시계도 흘러간다. 팀원들은 내가 돌아오길 기다리고 있을까?", "분홍 탄환에서 이상한 신호가 온다. 점프로 되받아치면 버그가 멈춘다!", "첫 제출까지 얼마 남지 않았다. 동선을 짧게, 판단은 빠르게.", "첫 프로젝트의 핵심이다. 모든 단말기를 복구하고 다음 세계로 가자."],
 ["문 너머는 우리가 함께 만든 판타지 게임. 팀원들의 코드가 갇혀 있다.", "마법이 엉뚱한 방향으로 날아간다. 주문의 변수를 수정하자.", "기사는 검 대신 오류를 들고 있다. 캐릭터 코드를 다시 묶어야 한다.", "퀘스트의 끝이 사라졌다. 기획서가 길을 되찾아 줄 것이다.", "끝없이 반복되는 마법. 분홍 신호를 패링하면 잠깐 루프가 끊긴다.", "채팅 로그가 복구됐다. ‘혼자 다 하지 마. 우리 작업물도 가져가.’", "드래곤이 메모리를 삼켰다. 탄막 사이로 패치를 전달하자.", "성이 무너지고 있다. 단말기 하나를 고칠 때마다 공격도 잠깐 멈춘다.", "마지막 병합이다. 서로 다른 재료가 하나의 결과물이 된다.", "우리가 만든 세계가 다시 빛난다. 이제 졸업작품만 남았다."],
 ["마지막 빌드. 현실을 닮은 도시의 모든 신호가 붉게 깜빡인다.", "거리에 노이즈가 번진다. 그래픽과 QA를 묶어 도시를 되살리자.", "신호가 복제되며 탄막이 늘어난다. 급할수록 탈출할 방향을 남겨 두자.", "서버가 과열됐다. 제작을 기다리는 동안 다음 단말기의 요구를 확인하자.", "빨간 신호 사이로 분홍 신호가 보인다. 위험을 기회로 바꿔 보자.", "출시 전 마지막 테스트. 작은 오류 하나도 놓칠 수 없다.", "릴리스 후보 빌드가 준비됐다. 이제 돌이킬 수 있는 오류는 전부 고친다.", "남은 건 시간과 집중력. 동료들의 작업물을 끝까지 전달하자.", "돌아갈 좌표를 찾았다. 마지막 단말기들이 문을 막고 있다.", "현실로 연결되는 최종 빌드. 이 프로젝트의 엔딩은 네가 완성한다."]
]
const ACHIEVEMENTS = [
 ["first", "첫 번째 커밋", "첫 스테이지를 클리어하세요."],
 ["parry", "예외 처리 전문가", "분홍 탄환을 점프로 패링하세요."],
 ["clean", "무결점 빌드", "피해 없이 스테이지를 클리어하세요."],
 ["fast", "빠른 제출", "60초 안에 스테이지를 클리어하세요."],
 ["chapter1", "1학년 수료", "첫 챕터의 10개 스테이지를 클리어하세요."],
 ["chapter2", "최고의 팀", "두 번째 챕터를 클리어하세요."],
 ["chapter3", "졸업을 축하합니다", "30개 스테이지를 모두 클리어하세요."],
 ["secret", "이것도 경험이지", "???"]
]

static func item_name(id: int) -> String:
	return MATERIALS[id] if id < 4 else PRODUCTS[id - 4]

static func combine(a: int, b: int) -> int:
	return RECIPES.get("%d+%d" % [mini(a,b), maxi(a,b)], 11)

static func pair_for(id: int) -> Array:
	return RECIPE_PAIRS[id - 4] if id >= 4 and id <= 10 else []

static func stage(chapter: int, number: int) -> Dictionary:
	var count := 2 + int(chapter > 0 or number >= 6) + int(chapter == 2)
	var rounds := 1 + int(number >= 4) + int(chapter == 2 and number >= 7)
	var orders: Array = []
	for t in range(count):
		var queue: Array = []
		for r in range(rounds):
			var id := 4 + ((number + t * 2 + r * 3 + chapter) % 7)
			if number == 0 and chapter == 0:
				id = 0 if t == 0 else 5
			elif chapter == 0 and number < 4:
				id = [[4,5],[6,7],[8,10]][number-1][t]
			queue.append([id, (number + t) % 4] if r > 0 and chapter > 0 else [id])
		orders.append(queue)
	return {"orders": orders, "time": 180.0 + rounds * 25.0 - chapter * 18.0 - number * 2.0,
		"interval": maxf(1.0, 2.8 - number * 0.09 - chapter * 0.4),
		"speed": 115.0 + chapter * 26.0 + number * 5.0, "enemies": 2 + chapter + int(number >= 7)}
