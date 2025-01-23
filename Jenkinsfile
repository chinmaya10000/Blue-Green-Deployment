#!/usr/bin/env groovy

pipeline {

    agent any
    tools {
        maven 'Maven'
    }

    environment {
        ECR_REPO_URL = '156041433917.dkr.ecr.us-east-2.amazonaws.com'
        IMAGE_NAME = "${ECR_REPO_URL}/bank-app"
        IMAGE_TAG = "1.0-${BUILD_NUMBER}" // Build-specific tag
        SCANNER_HOME = tool 'sonar-scanner'
        AWS_REGION = 'us-east-2'
        AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
        AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
        GITHUB_TOKEN = credentials('github_token')
    }

    stages {
        stage('Checkout Code') {
            steps {
                script {
                    echo 'Checking out code from the repository...'
                    checkout scm
                }
            }
        }
        stage('compile') {
            steps {
                script {
                    echo 'compile the application ...'
                    sh 'mvn compile'
                }
            }
        }
        stage('SAST - SonarQube') {
            steps {
                script {
                    withSonarQubeEnv('sonar-server') {
                        sh "$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectKey=java-app -Dsonar.projectName=java-app -Dsonar.java.binaries=target"
                    }
                }
            }
        }
        // stage('Quality Gate') {
        //     steps {
        //         script {
        //             timeout(time: 1, unit: 'HOURS') {
        //                 waitForQualityGate abortPipeline: false
        //             }
        //         }
        //     }
        // }
        stage('Building the App') {
            steps {
                script {
                    sh 'mvn package -DskipTests=True'
                }
            }
        }
        stage('SCA - Dependency Check') {
            steps {
                script {
                    echo 'Starting OWASP Dependency Check for security vulnerabilities...'
                    sh 'mvn org.owasp:dependency-check-maven:check'
                }
            }
        }
        stage('Publish to Nexus') {
            steps {
                script {
                    echo 'Publishing the application to the Nexus repository...'
                    withMaven(globalMavenSettingsConfig: 'maven-settings', jdk: '', maven: 'Maven', mavenSettingsConfig: '', traceability: true) {
                        sh 'mvn deploy -DskipTests=true'
                    }
                }
            }
        }
        stage('Build Docker Image') {
            steps {
                script {
                    echo 'Building the Docker image...'
                    sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
                }
            }
        }
        stage('Scan Docker Image') {
            steps {
                script {
                    echo 'Scanning the Docker image for vulnerabilities...'
                    sh "trivy image -f json -o trivy.json --severity HIGH,CRITICAL --exit-code 0 ${IMAGE_NAME}:${IMAGE_TAG}"
                }
            }
        }
        stage('Push Docker Image') {
            steps {
                script {
                    echo 'Pushing the Docker image to Amazon ECR...'
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URL}"
                    sh "docker push ${IMAGE_NAME}:${IMAGE_TAG}"
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
                        echo 'Repo does not exists - Cloning the repo'
                        sh 'git clone https://github.com/chinmaya10000/gitops-argocd.git'
                    }
                }
            }
        }
        stage('Update Manifest') {
            steps {
                script {
                    dir('gitops-argocd/bankapp') {
                        echo 'Update the Kubernetes manifest with the new image tag...'
                        sh "sed -i 's#image: 156041433917.dkr.ecr.us-east-2.amazonaws.com/.*#image: ${IMAGE_NAME}:${IMAGE_TAG}#g' java-app.yml"
                    }
                }
            }
        }
        stage('GitOps Update') {
            steps {
                script {
                    echo 'Commit and push the changes'
                    dir('gitops-argocd/bankapp') {
                        sh 'git config --global user.email "jenkins@gmail.com"'
                        sh 'git config --global user.name "jenkins"'
                        sh "git remote set-url origin https://${GITHUB_TOKEN}@github.com/chinmaya10000/gitops-argocd.git"
                        sh 'git checkout feature/argocd-gitops'
                        sh 'git add .'
                        sh 'git commit -m "Updated image version for Build - $IMAGE_TAG"'
                        sh 'git push origin feature/argocd-gitops'
                    }
                }
            }
        }
    }
}