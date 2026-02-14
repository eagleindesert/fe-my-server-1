# Jenkins & Git Webhook 설정 가이드

이 문서는 생성된 `Jenkinsfile`을 사용하여 Jenkins 파이프라인을 구성하고, Git Webhook을 통해 자동 빌드를 설정하는 방법을 설명합니다.

## 1. 전제 조건 (Prerequisites)

- **Jenkins 서버**: OCI VM 등에 Jenkins가 설치되어 있어야 합니다.
- **Docker 설치**: Jenkins가 실행되는 서버(에이전트)에 `docker`가 설치되어 있어야 합니다.
- **권한 설정**: Jenkins 사용자가 docker 명령어를 실행할 수 있어야 합니다. (예: `sudo usermod -aG docker jenkins` 후 Jenkins 재시작)
- **플러그인**: Jenkins 관리 > 플러그인 관리에서 다음 플러그인이 설치되어 있는지 확인하세요.
  - **Docker Pipeline** (필수)
  - **GitHub Plugin** (GitHub 사용 시) 또는 **GitLab Plugin** (GitLab 사용 시)

---

## 2. Jenkins Job 생성 및 파이프라인 설정

1.  **새로운 Job 만들기**:
    - Jenkins 메인 화면 -> **"새로운 Item"** 클릭.
    - 이름 입력 (예: `my-server-fe-cd`).
    - **"Pipeline"** 선택 후 OK.

2.  **General 설정**:
    - GitHub 프로젝트라면 "GitHub project" 체크 후 프로젝트 URL 입력.

3.  **Build Triggers (빌드 유발)**:
    - GitHub 사용 시: **"GitHub hook trigger for GITScm polling"** 체크.
    - GitLab 사용 시: **"Build when a change is pushed to GitLab"** 체크.

4.  **Pipeline (파이프라인) 설정**:
    - **Definition**: `Pipeline script from SCM` 선택.
    - **SCM**: `Git` 선택.
    - **Repository URL**: Git 저장소 주소 입력 (참고: Private 저장소라면 Credentials에 계정 정보 추가 필요).
    - **Branch Specifier**: `*/main` (또는 사용하는 브랜치명).
    - **Script Path**: `Jenkinsfile` (기본값).

5.  **저장**: 설정을 저장합니다.

---

## 3. Webhook 설정 (Git 저장소 쪽)

Jenkins가 외부에서 코드가 변경되었다는 신호를 받을 수 있도록 Git 저장소에서 Webhook을 설정해야 합니다.

### 3-1. Private Subnet 환경일 경우 (ngrok 사용)

OCI의 Private Subnet에 Jenkins가 있어 외부에서 직접 접속할 수 없는 경우, `ngrok`을 사용하여 터널을 뚫어주어야 합니다.

1.  **ngrok 설치 (Jenkins VM에서 실행)**:

    ```bash
    # ngrok 다운로드 및 설치 (Linux 기준)
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list && sudo apt update && sudo apt install ngrok
    ```

2.  **ngrok 인증 토큰 설정 (필수)**:
    - [ngrok 대시보드](https://dashboard.ngrok.com/get-started/your-authtoken)에 로그인하여 **Authtoken**을 복사합니다. (계정이 없다면 무료 회원가입 필요)
    - 다음 명령어로 토큰을 등록합니다:

    ```bash
    ngrok config add-authtoken <YOUR_AUTHTOKEN>
    ```

3.  **ngrok 실행**:

    ```bash
    # 8080 포트를 외부로 노출 (백그라운드 실행 권장)
    ngrok http 8080
    ```

    - 실행 후 화면에 나오는 `Forwarding` 주소(예: `https://abcd-123-456.ngrok-free.app`)를 복사합니다. 이 주소가 Jenkins의 공인 주소 역할을 합니다.

4.  **Webhook URL 구성**:
    - 기존: `http://<JENKINS_SERVER_IP>:8080/github-webhook/`
    - **변경(ngrok 사용)**: `https://abcd-123-456.ngrok-free.app/github-webhook/` (뒤에 경로는 동일)

> **주의**: 무료 버전 ngrok은 재시작할 때마다 도메인 주소가 바뀝니다. 바뀔 때마다 Git Webhook 설정을 업데이트해줘야 합니다. 고정 도메인을 쓰려면 유료 플랜이 필요합니다.

---

### 3-2. Webhook 등록 (GitHub/GitLab)

### GitHub를 사용하는 경우

1.  GitHub 저장소의 **Settings** -> **Webhooks** 메뉴로 이동.
2.  **Add webhook** 클릭.
3.  **Payload URL**: `http://<JENKINS_SERVER_IP>:8080/github-webhook/`
    - (주의: 마지막의 `/`를 꼭 포함하세요)
4.  **Content type**: `application/json` 선택.
5.  **Which events would you like to trigger this webhook?**: "Just the push event" 선택.
6.  **Active** 체크 확인 후 "Add webhook" 클릭.

### GitLab을 사용하는 경우

1.  GitLab 저장소의 **Settings** -> **Webhooks** 메뉴로 이동.
2.  **URL**: `http://<JENKINS_SERVER_IP>:8080/project/<JOB_NAME>` (GitLab 플러그인 설정에 따라 다를 수 있음, 보통 Jenkins Job 설정 화면에 표시된 URL 사용).
3.  **Trigger**: "Push events" 체크.
4.  "Add webhook" 클릭.

---

## 4. OCI(Oracle Cloud) 네트워크 설정 (필수 확인)

외부(Git)에서 Jenkins(OCI VM)로 신호를 보내려면 방화벽이 열려있어야 합니다.

1.  OCI 콘솔 로그인 -> **Networking** -> **Virtual Cloud Networks (VCN)**.
2.  Jenkins VM이 속한 **Subnet** 클릭 -> **Security List** 클릭.
3.  **Ingress Rules (수신 규칙)** 에 다음 규칙 추가:
    - **Source**: `0.0.0.0/0` (모든 곳에서 허용) 또는 Git 서버의 IP 대역.
    - **Destination Port**: `8080` (Jenkins 포트).
    - **Protocol**: TCP.

설정이 완료되면 코드를 `push` 했을 때 잠시 후 Jenkins에서 자동으로 빌드가 시작되는지 확인합니다.

---

## 5. 보안 강화 (필수): 외부 접근 제한하기

Private Subnet에 있는 Jenkins를 `ngrok`으로 무방비하게 노출하면, 누구나 로그인 페이지에 접근하여 무차별 대입 공격(Brute Force)을 시도할 수 있습니다. 이를 방지하기 위해 **Webhook만 허용하고 나머지는 차단**하는 설정을 추가해야 합니다.

### 해결책: Nginx 리버스 프록시 사용

`ngrok`이 Jenkins(8080)를 직접 바라보는 대신, 중간에 **Nginx**를 두어 `/github-webhook/` 경로만 허용하고 나머지는 차단합니다.

1.  **Nginx 설치 (Jenkins VM)**:

    ```bash
    sudo apt install nginx -y
    ```

2.  **Nginx 설정 파일 작성**:
    `/etc/nginx/sites-available/jenkins-webhook` 파일을 생성하고 다음 내용을 입력합니다.

    ```nginx
    server {
        listen 8000; # ngrok이 연결할 포트
        server_name localhost;

        # 1. Webhook 요청은 Jenkins로 전달 (허용)
        location /github-webhook/ {
            proxy_pass http://localhost:8080/github-webhook/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # 2. 그 외 모든 요청(로그인 페이지 등)은 차단
        location / {
            return 403; # Forbidden (접근 금지)
        }
    }
    ```

3.  **설정 활성화 및 재시작**:

    ```bash
    sudo ln -s /etc/nginx/sites-available/jenkins-webhook /etc/nginx/sites-enabled/
    sudo rm /etc/nginx/sites-enabled/default  # 기본 설정 제거
    sudo systemctl restart nginx
    ```

4.  **ngrok 재시작 (포트 변경)**:
    이제 8080이 아닌 **8000번 포트**를 노출합니다.
    ```bash
    ngrok http 8000
    ```

### 관리자(나)는 어떻게 접속하나요?

이제 외부 주소(ngrok)로는 로그인 화면에 접속할 수 없습니다. 관리자는 **SSH 터널링**을 통해 안전하게 접속합니다.

- **내 컴퓨터 터미널에서 실행**:
  ```bash
  # Bastion Host를 경유하거나 VPN을 통해 Jenkins VM의 8080 포트를 내 PC의 8080으로 당겨옴
  ssh -L 8080:localhost:8080 -i <key-file> opc@<BASTION_OR_JENKINS_IP>
  ```
- **접속 주소**: 웹 브라우저에서 `http://localhost:8080` (내 컴퓨터인 것처럼 접속)
