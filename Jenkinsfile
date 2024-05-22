def branch = env.BRANCH_NAME ?: "ecr"
def namespace = env.NAMESPACE ?: "dev"
def workingDir = "/home/jenkins/agent"

pipeline {
    agent {
        kubernetes {
            label 'test-nexus-poc-java'
            defaultContainer 'jnlp'
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins/label: test-nexus-poc-java
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:3107.v665000b_51092-15
    env:
    - name: GIT_SSL_CAINFO
      value: /etc/pki/tls/certs/ca-bundle.crt
    - name: JENKINS_URL
      value: http://jenkins.jenkins-builder.svc.cluster.local:80/
    volumeMounts:
    - name: jenkins-trusted-ca-bundle
      mountPath: /etc/pki/tls/certs
    - name: workspace-volume
      mountPath: /home/jenkins/agent
  - name: cammismaven
    image: 136299550619.dkr.ecr.us-west-2.amazonaws.com/cammismaven:1.0.0
    command:
    - /bin/bash
    tty: true
    env:
    - name: HOME
      value: /home/jenkins/agent
    - name: BRANCH
      value: ecr
    - name: NEXUS_ACCESS_TOKEN
      valueFrom:
        secretKeyRef:
          name: jenkins-token-qqsb2
          key: token
    - name: GIT_SSL_CAINFO
      value: /etc/pki/tls/certs/ca-bundle.crt
    volumeMounts:
    - name: jenkins-trusted-ca-bundle
      mountPath: /etc/pki/tls/certs
    - name: workspace-volume
      mountPath: /home/jenkins/agent
  volumes:
  - name: jenkins-trusted-ca-bundle
    configMap:
      name: jenkins-trusted-ca-bundle
      optional: true
  - name: workspace-volume
    emptyDir: {}
"""
        }
    }
    environment {
        BRANCH_NAME = "ecr"
    }
    stages {
        stage('Initialize') {
            steps {
                container('jnlp') {
                    script {
                        deleteDir()
                        echo 'Checkout source and get the commit ID'
                        checkout scm
                        echo 'Loading properties file'
                        // Add code to load properties if necessary
                        echo 'Initialize Slack channels and tokens'
                        // Add code to initialize Slack if necessary
                    }
                }
            }
        }
        stage('Prepare Environment') {
            steps {
                container('cammismaven') {
                    script {
                        echo 'Preparing environment'
                        sh '''
                        echo
                        openssl s_client -connect nexusrepo-tools.apps.bld.cammis.medi-cal.ca.gov:443 -showcerts > nexus-cert.pem
                        keytool -importcert -file nexus-cert.pem -keystore /usr/lib/jvm/java-17-openjdk/lib/security/cacerts -alias nexus-cert -storepass changeit -noprompt
                        '''
                    }
                }
            }
        }
        stage('Build and Deploy to Nexus') {
            steps {
                container('cammismaven') {
                    dir('spring-app') { // Ensure the correct directory
                        script {
                            sh 'mvn clean deploy -DskipTests=true'
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            echo 'Build and deployment process is complete.'
        }
        failure {
            echo 'Build and deployment failed.'
        }
    }
}
