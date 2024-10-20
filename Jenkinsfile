#!/usr/bin/env groovy

@Library('jenkins-shared-library')_

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
                    cloneRepo("https://github.com/chinmaya10000/Blue-Green-Deployment.git", "feature/devsecops")
                }
            }
        }
        stage('Secret Scanning with Gitleaks') {
            steps {
                script {
                    gitleaksScan('.', 'gitleaks-report.json')
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
        stage('Integration Test') {
            steps {
                script {
                    sh 'mvn verify -DskipUnitTests'
                }
            }
        }
        stage('TRIVY FS SCAN') {
            steps {
                script {
                    scanCodebase()
                }
            }
        }
        stage('SonarQube Analysis') {
            steps {
                script {
                    echo 'Call the shared library function for SonarQube analysis'
                    sonarQubeAnalysis('sonar-server', 'Multitier', 'Multitier')
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
                    // Call the shared library function to build the Docker image
                    echo 'building the docker image...'
                    buildDockerImage(env.IMAGE_NAME, env.IMAGE_TAG)
                }
            }
        }
        stage('Image Security Scan') {
            steps {
                script {
                    echo 'Scan image with trivy..'
                    imageSecurityScan(env.IMAGE_NAME, env.IMAGE_TAG)
                }
            }
        }
        stage('Push Image') {
            steps {
                script {
                    echo 'Push Docker Image'
                    pushDockerImage(env.IMAGE_NAME, env.IMAGE_TAG)
                }
            }
        }
    }
}