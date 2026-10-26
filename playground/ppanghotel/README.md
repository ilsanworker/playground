# BBANGBBANG HOTEL · Supabase + GitHub Pages

이 버전은 GitHub Pages(정적 홈페이지) + Supabase Postgres(공유 예약 DB) + Supabase Auth(관리자 로그인)를 사용합니다.

## A. Supabase 프로젝트 만들기
1. https://supabase.com/dashboard 에서 새 프로젝트를 만듭니다.
2. 프로젝트가 준비되면 **SQL Editor → New query**로 갑니다.
3. 이 폴더의 `supabase.sql` 전체를 붙여넣고 **Run**을 누릅니다.
4. 성공 메시지가 나오는지 확인합니다.

## B. 관리자 계정 만들기
1. Supabase 대시보드 → **Authentication → Users**로 갑니다.
2. **Add user**를 눌러 관리자 이메일과 비밀번호를 만듭니다. 가능하면 이메일 확인을 완료합니다.
3. SQL Editor에서 아래 쿼리의 이메일을 본인 관리자 이메일로 바꾸고 실행합니다.

```sql
insert into public.admin_users (user_id)
select id
from auth.users
where email = 'YOUR_ADMIN_EMAIL@example.com'
on conflict (user_id) do nothing;
```

4. 아래 쿼리를 실행해서 관리자 1명이 등록됐는지 확인할 수 있습니다.

```sql
select au.user_id, u.email
from public.admin_users au
join auth.users u on u.id = au.user_id;
```

일반 방문자에게 관리자 계정을 만들어 주지 마세요. 관리자 계정에만 예약 개인정보를 볼 권한이 있습니다.

## C. Supabase URL / Publishable key 연결
1. Supabase 대시보드에서 **Connect** 또는 **Project Settings → API Keys**로 갑니다.
2. 프로젝트 URL과 `Publishable key`(구형 프로젝트에서는 `anon` public key로 표시될 수 있음)를 복사합니다.
3. `index.html`과 `admin.html`의 맨 아래 JavaScript에서 아래 두 값을 같은 값으로 교체합니다.

```js
const SUPABASE_URL = "https://YOUR-PROJECT-REF.supabase.co";
const SUPABASE_PUBLISHABLE_KEY = "YOUR_SUPABASE_PUBLISHABLE_KEY";
```

`admin.html`에서는 변수명에 공백 없이 같은 값을 넣습니다.

**절대 `service_role` 키 또는 Secret key를 HTML에 넣지 마세요.** 브라우저에 들어가는 키는 공개 가능한 publishable/anon 키만 사용하고, 데이터 접근은 SQL의 RLS 정책으로 보호합니다.

## D. GitHub Pages에 올리기
1. `index.html`과 `admin.html`을 기존 GitHub Pages 저장소의 루트 폴더에 업로드합니다.
2. `supabase.sql`은 홈페이지에 올릴 필요가 없습니다. 로컬에 보관하거나 저장소에 둘 수 있지만, 공개 저장소에 데이터베이스 비밀번호나 비밀 키는 올리지 마세요.
3. GitHub Pages가 배포되면 홈페이지에서 예약 신청을 테스트합니다.
4. 상단 `관리자` 버튼을 눌러 `admin.html`에 들어가 관리자 이메일/비밀번호로 로그인합니다.
5. 예약을 확정하거나 취소합니다. 다른 기기에서도 예약 날짜가 공유됩니다.

## E. 테스트 순서
1. 미래 날짜로 예약 신청 → 승인 대기 표시 확인
2. 다른 브라우저/휴대폰에서 같은 날짜를 예약 → 겹치는 예약이 거절되는지 확인
3. 관리자 로그인 → 예약 확정
4. 예약 현황에서 확정 상태가 보이는지 확인
5. 취소 → 해당 날짜를 다시 예약할 수 있는지 확인

## 동작 규칙
- `pending`(승인 대기)와 `confirmed`(확정)는 날짜를 점유합니다.
- `cancelled`(취소)는 날짜를 점유하지 않습니다.
- 체크아웃 날짜는 점유 범위에서 제외됩니다. 예: 11/2 체크인, 11/3 체크아웃이면 11/3 체크인 예약은 가능합니다.
- 공개 예약 현황에는 날짜와 상태만 나옵니다. 예약자 이름/나이/메모는 관리자 로그인 후에만 표시됩니다.
- 예약 확정 알림은 현재 관리자 화면에 표시됩니다. 사이트 방문자에게 이메일이나 푸시 알림을 보내는 기능은 포함하지 않았습니다.
- 재미용 프로젝트용 구현입니다. 실제 민감한 개인정보를 수집하지 마세요.

## 문제 해결
- 예약 현황에 `function not found`가 나오면 `supabase.sql` 전체가 성공적으로 실행됐는지 확인하세요.
- 관리자 로그인은 되지만 권한이 없다고 나오면 `admin_users`에 해당 Auth 사용자 ID가 등록됐는지 확인하세요.
- `permission denied`가 나오면 SQL 실행 중 오류가 없었는지, RLS 정책과 grants가 그대로 적용됐는지 확인하세요.
- 같은 기간 예약이 두 개 들어가면 안 됩니다. 데이터베이스의 exclusion constraint가 마지막 방어선입니다.
