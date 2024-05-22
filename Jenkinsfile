def branch = env.BRANCH_NAME ?: "ecr"
def namespace = env.NAMESPACE ?: "dev"
def workingDir = "/home/jenkins/agent"

pipeline {
    agent any

    environment {
        MAVEN_HOME = tool 'Maven'
        NEXUS_URL = 'https://nexusrepo-tools.apps.bld.cammis.medi-cal.ca.gov/repository/cammis-java-repo-group/'
        NEXUS_USERNAME = credentials('nexus-Username')
        NEXUS_PASSWORD = credentials('nexus-Password')
    }

    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/sreddy1607/spring-app.git'
            }
        }
        stage('Build') {
            steps {
                sh "${MAVEN_HOME}/bin/mvn clean install"
            }
        }
        stage('Deploy to Nexus') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'nexus-credentials', usernameVariable: 'NEXUS_USERNAME', passwordVariable: 'NEXUS_PASSWORD')]) {
                        sh "${MAVEN_HOME}/bin/mvn deploy -Drepository.url=${NEXUS_URL} -Drepository.username=${NEXUS_USERNAME} -Drepository.password=${NEXUS_PASSWORD}"
                    }
                }
            }
        }
    }
}


