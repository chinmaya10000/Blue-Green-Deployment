pipeline {
    agent any

    tools {
        maven 'Maven'
    }

    environment {
        IMAGE_NAME = 'chinmayapradhan/bankapp'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        SCANNER_HOME = tool 'sonar-scanner'
    }

    stages {
        stage('Clone Repository') {
            steps {
                script {
                    git branch: 'feature/devsecops', url: 'https://github.com/chinmaya10000/Blue-Green-Deployment.git'
                }
            }
        }
        stage('Secret Scanning with Gitleaks') {
            steps {
                script {
                    try {
                        // Run Gitleaks scan
                        sh 'gitleaks detect --source=. -v --report-path=gitleaks-report.json'
                        echo "Gitleaks scan completed successfully"
                    }
                    catch (Exception e) {
                        echo "Gitleaks scan failed: ${e.message}"
                        error("Gitleaks scanning stage failed")
                    }
                }
            }
        }
        stage('SCA with OWASP Dependency-Check') {
            steps {
                script {
                    echo "Running OWASP Dependency-Check..."
                    dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'DP-Check'
                    dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
                }
            }
        }

        stage('Compile') {
            steps {
                script {
                    sh 'mvn compile'
                }
            }
        }
        stage('Unit Test') {
            steps {
                script {
                    sh 'mvn test -DskipTests=true'
                }
            }
        }
        stage('TRIVY FS SCAN') {
            steps {
                script {
                    sh 'trivy fs --format table -o fs.json .'
                }
            }
        }
        stage('SonarQube Analysis (SAST)') {
            steps {
                script {
                    withSonarQubeEnv('sonar-server') {
                        sh "$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectKey=multitier -Dsonar.projectName=multitier -Dsonar.java.binaries=target"
                    }
                }
            }
        }
        stage('Quality Gate Check') {
            steps {
                script {
                    timeout(time: 1, unit: 'HOURS') {
                        waitForQualityGate abortPipeline: false
                    }
                }
            }
        }
        stage('Build') {
            steps {
                script {
                    sh 'mvn package -DskipTests=true'
                }
            }
        }
        stage('Publish Artifact to Nexus') {
            steps {
                script {
                    withMaven(globalMavenSettingsConfig: 'maven-settings', jdk: '', maven: 'Maven', mavenSettingsConfig: '', traceability: true) {
                        sh 'mvn deploy -DskipTests=true'
                    }
                }
            }
        }
        stage('Build Image') {
            steps {
                script {
                    echo 'building the docker image...'
                    sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
                }
            }
        }
        stage('Image Security Scan') {
            steps {
                script {
                    echo 'Scan image with trivy..'
                    sh "trivy image --format table -o image.json ${IMAGE_NAME}:${IMAGE_TAG}"
                }
            }
        }
        stage('Push Image') {
            steps {
                script {
                    echo 'Push Docker Image'
                    withCredentials([usernamePassword(credentialsId: 'docker-credentials-id', passwordVariable: 'PASSWORD', usernameVariable: 'USER')]) {
                        sh "echo $PASSWORD | docker login -u $USER --password-stdin"
                        sh "docker push ${IMAGE_NAME}:${IMAGE_TAG}"
                    }
                }
            }
        }
        stage('Clone/Pull Repo') {
            steps {
                script {
                    if(fileExists('gitops-argocd')) {

                        echo 'Cloned repo already exists - Pulling latest changes'
                        dir("gitops-argocd") {
                            sh 'git pull'
                        }
                    } else {
                        echo 'Repo does not exist - Cloning the Repo'
                        sh 'git clone https://github.com/chinmaya10000/gitops-argocd.git'
                    }
                }
            }
        }
        stage('Update Manifest') {
            steps {
                script {
                    dir("gitops-argocd/bankapp") {
                        sh "sed -i 's#image: chinmayapradhan/.*#image: ${IMAGE_NAME}:${IMAGE_TAG}#g' bankapp.yml"
                    }
                }
            }
        }
        stage('Commit and Push') {
            steps {
                script {
                    echo 'Configure Git and push changes'
                    withCredentials([string(credentialsId: 'github', variable: 'GITHUB_TOKEN')]) {
                        sh '''
                          git config --global user.name "chinmaya1000"
                          git config --global user.email "chinmayapradhan10000@gmail.com"
                          git remote set-url origin https://${GITHUB_TOKEN}@github.com/chinmaya10000/gitops-argocd.git
                          git add .
                          git commit -m "Updated image version for Build - $IMAGE_TAG"
                          git push origin main
                        '''
                    }
                }
            }
        }
    }
}