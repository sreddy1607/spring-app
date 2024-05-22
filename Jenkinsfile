def branch = env.BRANCH_NAME ?: "ecr"
def namespace = env.NAMESPACE ?: "dev"
def workingDir = "/home/jenkins/agent"

pipeline {
    agent {
        kubernetes {
            label 'maven-builder'
            defaultContainer 'maven'
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: 'maven-builder'
spec:
  containers:
  - name: maven
    image: 136299550619.dkr.ecr.us-west-2.amazonaws.com/cammismaven:1.0.0
    command:
    - cat
    tty: true
    volumeMounts:
    - name: maven-settings
      mountPath: /root/.m2
  volumes:
  - name: maven-settings
    configMap:
      name: maven-settings
"""
        }
    }
    environment {
        MAVEN_OPTS = "-Duser.home=/root"
        NEXUS_REPO_URL = 'https://nexusrepo-tools.apps.bld.cammis.medi-cal.ca.gov/repository/cammis-java-repo-group/'
    }
    stages {
        stage('Checkout') {
            steps {
                git url: 'https://github.com/sreddy1607/spring-app.git', branch: 'main'
            }
        }
        stage('Build') {
            steps {
                container('maven') {
                    sh 'mvn clean package'
                }
            }
        }
        stage('Deploy') {
            steps {
                container('maven') {
                    withCredentials([usernamePassword(credentialsId: 'nexus-credentials', passwordVariable: 'NEXUS_PASSWORD', usernameVariable: 'NEXUS_USERNAME')]) {
                        sh """
                        mvn deploy:deploy-file \\
                            -DgroupId=com.example \\
                            -DartifactId=spring-app \\
                            -Dversion=1.0.0 \\
                            -Dpackaging=jar \\
                            -Dfile=target/spring-app-1.0.0.jar \\
                            -DrepositoryId=nexus \\
                            -Durl=$NEXUS_REPO_URL \\
                            -DrepositoryId=nexus \\
                            -Durl=$NEXUS_REPO_URL \\
                            -Dusername=$NEXUS_USERNAME \\
                            -Dpassword=$NEXUS_PASSWORD
                        """
                    }
                }
            }
        }
    }
    post {
        success {
            echo 'Build and deployment successful'
        }
        failure {
            echo 'Build and deployment failed'
        }
    }
}

