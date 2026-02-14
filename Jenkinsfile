pipeline {
    agent any

    environment {
        // 이미지 이름을 프로젝트 이름으로 설정
        IMAGE_NAME = 'my-server-fe-1'
    }

    stages {
        stage('Build Docker Image') {
            steps {
                script {
                    // Docker 이미지 빌드 (태그에 빌드 번호 포함)
                    sh "docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} ."
                    
                    // latest 태그 추가
                    sh "docker tag ${IMAGE_NAME}:${BUILD_NUMBER} ${IMAGE_NAME}:latest"
                }
            }
        }

        /* 
        // (선택 사항) 레지스트리 푸시 단계 예시
        stage('Push Image') {
            steps {
                script {
                    // Docker Hub 또는 OCI Registry 로그인이 필요할 경우 credentialsId 설정 필요
                    // withDockerRegistry(credentialsId: 'docker-hub-credentials', url: '') {
                    //     sh "docker push ${IMAGE_NAME}:${BUILD_NUMBER}"
                    //     sh "docker push ${IMAGE_NAME}:latest"
                    // }
                }
            }
        }
        */
    }

    post {
        success {
            echo 'Build successful!'
        }
        failure {
            echo 'Build failed.'
        }
    }
}
