#!/usr/bin/env groovy

pipeline {

    agent any
    tools {
        maven 'Maven'
    }

    environment {
        ECR_REPO_URL = '156041433917.dkr.ecr.us-east-2.amazonaws.com'
        IMAGE_NAME = '${ECR_REPO_URL}/bank-app'
        IMAGE_TAG = "1.0-${BUILD_NUMBER}"
        SCANNER_HOME = tool 'sonar-scanner'
        CLUSTER_NAME = 'staging-myapp-eks'
        CLUSTER_REGION = 'us-east-2'
        AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
        AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo 'Checking out code...'
                    git branch: 'feature/deploy-on-eks', url: 'https://github.com/chinmaya10000/Blue-Green-Deployment.git'
                }
            }
        }
        stage('Compile') {
            steps {
                script {
                    echo 'Building the application ...'
                    sh 'mvn compile'
                }
            }
        }
        stage('Code Analysis') {
            steps {
                script {
                    echo 'Running code analysis with SonarQube...'
                    withSonarQubeEnv('sonar-server') {
                        sh "$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectKey=multitier -Dsonar.projectName=multitier -Dsonar.java.binaries=target"
                    }
                }
            }
        }
        stage('build') {
            steps {
                script {
                    sh 'mvn package -DskipTests=true'
                }
            }
        }
        stage('Publish Artifact to Nexus') {
            steps {
                script {
                    echo 'push to nexus'
                    withMaven(globalMavenSettingsConfig: 'maven-settings', jdk: '', maven: 'Maven', mavenSettingsConfig: '', traceability: true) {
                       sh 'mvn deploy -DskipTests=true'
                    }
                }
            }
        }
        stage('Build Docker Image') {
            steps {
                script {
                    echo "building the docker image..."
                    sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
                    sh "aws ecr get-login-password --region ${CLUSTER_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URL}"
                    sh "docker push ${IMAGE_NAME}:${IMAGE_TAG}"
                }
            }
        }
        stage('Image Security Scan') {
            steps {
                script {
                    echo 'Scan image with trivy...'
                    sh "aws ecr get-login-password --region ${CLUSTER_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URL}"
                    sh "trivy image -f json -o trivy.json ${IMAGE_NAME}:${IMAGE_TAG}"
                }
            }
        }
        stage('Deploy To EKS') {
            environment {
                APP_NAME = 'bankapp'
                APP_NAMESPACE = 'bankapp'
                // Note: credentials helper function only works in the environment block
                DB_USER_SECRET = credentials('db_user')
                DB_NAME_SECRET = credentials('db_name')
                DB_ROOT_PASS_SECRET = credentials('db_root_pass')
            }
            steps {
                script {
                    // configure kubeconfig context to access the cluster with kubectl - alternative to copying the kubeconfig file to Jenkins server manually
                    sh "aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${CLUSTER_REGION}"

                    // set env variables for db-secret.yaml, using Jenkins credentials of "secret text" credentials type
                    env.DB_ROOT_PASS = sh(script: 'echo -n $DB_ROOT_PASS_SECRET | base64', returnStdout: true).trim()
                    env.DB_NAME = sh(script: 'echo -n $DB_NAME_SECRET | base64', returnStdout: true).trim()
                    env.DB_USER = sh(script: 'echo -n $DB_USER_SECRET | base64', returnStdout: true).trim()

                    // Note the correct usage of secret credentials in script: https://www.jenkins.io/doc/book/pipeline/jenkinsfile/#interpolation-of-sensitive-environment-variables
                    // Wrong: script: "echo -n ${DB_PASS_SECRET} | base64"
                    // Correct: script: 'echo -n $DB_PASS_SECRET | base64'

                    echo 'deploying new release to EKS...'
                    sh 'envsubst < k8s-deployment/db-config-cicd.yaml | kubectl apply -f -'
                    sh 'envsubst < k8s-deployment/db-secret-cicd.yaml | kubectl apply -f -'
                    sh 'envsubst < k8s-deployment/java-app-cicd.yaml | kubectl apply -f -'
                }
            }
        }
    }
}