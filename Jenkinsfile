pipeline {
    agent any

    tools {
        maven 'Maven'
    }

    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['blue', 'green'], description: 'Choose which environment to deploy: Blue or Green')
        choice(name: 'VERSION', choices: ['blue', 'green'], description: 'Chose the Docker Image version for deployment')
        booleanParam(name: 'SWITCH_TRAFFIC', defaultValue: false, description: 'Switch traffic between Blue and Green')
    }

    environment {
        IMAGE_NAME = 'chinmayapradhan/bankapp'
        IMAGE_TAG = "${params.VERSION}"
        SCANNER_HOME = tool 'sonar-scanner'
        CLUSTER_NAME = "my-cluster"
        CLUSTER_REGION = "us-east-2"
        AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
        AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
        APP_NAMESPACE = 'my-app'
    }

    stages {
        stage('Clone Repository') {
            steps {
                script {
                    git branch: 'main', credentialsId: 'git-cred', url: 'https://github.com/chinmaya10000/Blue-Green-Deployment.git'
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
        stage('Deploy MySql Deployment and Service') {
            steps {
                script {
                    // configure kubeconfig context to access the cluster with kubectl - alternative to copying the kubeconfig file to Jenkins server manually
                    sh "aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${CLUSTER_REGION}"
                    
                    echo 'deploying new release to EKS...'

                    sh 'envsubst < kubernetes/mysql-ds.yml | kubectl apply -f -'
                }
            }
        }

        stage('Deploy SVC-bankapp') {
            steps {
                script {
                    sh "aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${CLUSTER_REGION}"

                    sh ''' if ! kubectl get svc bankapp-service; then
                           envsubst < kubernetes/bankapp-service.yml | kubectl apply -f -
                           fi
                    '''
                }
            }
        }

        stage('Deploy to K8s') {
            steps {
                script {
                    sh "aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${CLUSTER_REGION}"

                    def deploymentFile = ""
                    if (params.DEPLOY_ENV == 'blue') {
                        deploymentFile = kubernetes/app-deployment-blue.yml
                    } else {
                        deploymentFile = kubernetes/app-deployment-green.yml
                    }

                    sh 'envsubst < ${deploymentFile} | kubectl apply -f -'
                }
            }
        }

        stage('Switch Traffic Between Blue & Green Environment') {
            when {
                expression { return params.SWITCH_TRAFFIC }
            }
            steps {
                script {
                    def newEnv = params.DEPLOY_ENV

                    sh "aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${CLUSTER_REGION}"
                    sh 'kubectl patch service bankapp-service -p "{\\"spec\\": {\\"selector\\": {\\"app\\": \\"bankapp\\", \\"version\\": \\"''' + newEnv + '''\\"}}}"'
                    
                    echo "Traffic has been switched to the ${newEnv} environment."
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    def verifyEnv = params.DEPLOY_ENV

                    sh "aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${CLUSTER_REGION}"
                    sh """
                        kubectl get pods -l version=${verifyEnv} -n ${KUBE_NAMESPACE}
                        kubectl get svc bankapp-service -n ${KUBE_NAMESPACE}
                    """
                }
            }
        }
    }
}