pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 15, unit: 'MINUTES')
    }

    environment {
        IMAGE_NAME     = 'cicd-webapp'
        IMAGE_TAG      = "${BUILD_NUMBER}"
        CONTAINER_NAME = 'cicd-webapp'
        APP_USER       = 'ubuntu'
        APP_HOST       = '13.233.91.151'
        APP_PORT       = '80'
        SSH_CRED_ID    = 'app-server-ssh'
    }

    stages {
        stage('Checkout Source Code') {
            steps {
                checkout scm
                sh 'git log -1 --oneline'
            }
        }

        stage('Build Application') {
            steps {
                sh '''
                    set -e
                    for f in index.html Dockerfile; do
                        test -s "$f" || { echo "Missing or empty: $f"; exit 1; }
                    done
                    echo "Static site: no compile step. Source files validated."
                '''
            }
        }

        stage('Test Application') {
            steps {
                sh '''
                    set -e
                    grep -q "<title>" index.html
                    grep -q "</html>" index.html
                    grep -q "stylesheet" index.html
                    echo "Basic HTML checks passed."
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build \
                        --build-arg BUILD_NUMBER=${BUILD_NUMBER} \
                        -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker images ${IMAGE_NAME}
                '''
            }
        }

        stage('Deploy to AWS EC2') {
            steps {
                sshagent(credentials: [env.SSH_CRED_ID]) {
                    sh '''
                        set -e
                        SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"

                        echo "Transferring image over SSH..."
                        docker save ${IMAGE_NAME}:${IMAGE_TAG} | gzip \
                            | ssh $SSH_OPTS ${APP_USER}@${APP_HOST} "gunzip | docker load"

                        echo "Replacing container..."
                        ssh $SSH_OPTS ${APP_USER}@${APP_HOST} "
                            docker stop ${CONTAINER_NAME} 2>/dev/null || true
                            docker rm ${CONTAINER_NAME} 2>/dev/null || true
                            docker run -d \
                                --name ${CONTAINER_NAME} \
                                --restart unless-stopped \
                                -p ${APP_PORT}:80 \
                                ${IMAGE_NAME}:${IMAGE_TAG}
                            docker images ${IMAGE_NAME} --format '{{.Tag}}' | sort -rn | tail -n +4 \
                                | xargs -r -I{} docker rmi ${IMAGE_NAME}:{} || true
                        "
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    set -e
                    sleep 5
                    curl -fsS --retry 5 --retry-delay 3 http://${APP_HOST}:${APP_PORT}/ > /dev/null
                    LIVE=$(curl -fsS http://${APP_HOST}:${APP_PORT}/version.txt | tr -d '[:space:]')
                    echo "Live build: $LIVE / Expected: ${BUILD_NUMBER}"
                    test "$LIVE" = "${BUILD_NUMBER}"
                '''
            }
        }
    }

    post {
        always {
            sh 'docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true'
            sh 'docker image prune -f || true'
        }
        success {
            echo "Deployed build #${BUILD_NUMBER} successfully."
        }
        failure {
            echo "Pipeline failed. Check the stage logs above."
        }
    }
}
