def branch = env.BRANCH_NAME ?: "ecr"
def namespace = env.NAMESPACE ?: "dev"
def workingDir = "/home/jenkins/agent"

pipeline {
    agent {
        kubernetes {
            yaml """
            apiVersion: "v1"
            kind: "Pod"
            metadata:
              annotations:
                buildUrl: "http://jenkins.jenkins-builder.svc.cluster.local:80/job/test-nexus-poc-java/39/"
                runUrl: "job/test-nexus-poc-java/39/"
              labels:
                jenkins-new: "slave"
                jenkins/label-digest: "4142328e473e84b7346ddd1ca1c74e663e95c7bb"
                jenkins/label: "test-nexus-poc-java_39-z7h35"
              name: "test-nexus-poc-java-39-z7h35-ltbwh-0k1jn"
              namespace: "jenkins-builder"
            spec:
              containers:
              - env:
                - name: "GIT_SSL_CAINFO"
                  value: "/etc/pki/tls/certs/ca-bundle.crt"
                - name: "JENKINS_SECRET"
                  value: "********"
                - name: "JENKINS_TUNNEL"
                  value: "jenkins-jnlp.jenkins-builder.svc.cluster.local:50000"
                - name: "JENKINS_AGENT_NAME"
                  value: "test-nexus-poc-java-39-z7h35-ltbwh-0k1jn"
                - name: "JENKINS_NAME"
                  value: "test-nexus-poc-java-39-z7h35-ltbwh-0k1jn"
                - name: "JENKINS_AGENT_WORKDIR"
                  value: "/home/jenkins/agent"
                - name: "JENKINS_URL"
                  value: "http://jenkins.jenkins-builder.svc.cluster.local:80/"
                envFrom:
                - configMapRef:
                    name: "jenkins-agent-env"
                    optional: true
                image: "jenkins/inbound-agent:3107.v665000b_51092-15"
                name: "jnlp"
                resources:
                  requests:
                    memory: "256Mi"
                    cpu: "100m"
                securityContext:
                  privileged: true
                volumeMounts:
                - mountPath: "/etc/pki/tls/certs"
                  name: "jenkins-trusted-ca-bundle"
                - mountPath: "/home/jenkins/agent"
                  name: "workspace-volume"
                  readOnly: false
              - command:
                - "/bin/bash"
                env:
                - name: "HOME"
                  value: "/home/jenkins/agent"
                - name: "BRANCH"
                  value: "ecr"
                - name: "GIT_SSL_CAINFO"
                  value: "/etc/pki/tls/certs/ca-bundle.crt"
                envFrom:
                - configMapRef:
                    name: "jenkins-agent-env"
                    optional: true
                image: "registry.access.redhat.com/ubi8/nodejs-16:latest"
                name: "node"
                securityContext:
                  privileged: true
                tty: true
                volumeMounts:
                - mountPath: "/etc/pki/tls/certs"
                  name: "jenkins-trusted-ca-bundle"
                - mountPath: "/home/jenkins/agent"
                  name: "workspace-volume"
                  readOnly: false
                workingDir: "/home/jenkins/agent"
              - command:
                - "/bin/bash"
                env:
                - name: "HOME"
                  value: "/home/jenkins/agent"
                - name: "BRANCH"
                  value: "ecr"
                - name: "NEXUS_ACCESS_TOKEN"
                  valueFrom:
                    secretKeyRef:
                      key: "token"
                      name: "jenkins-token-qqsb2"
                - name: "GIT_SSL_CAINFO"
                  value: "/etc/pki/tls/certs/ca-bundle.crt"
                envFrom:
                - configMapRef:
                    name: "jenkins-agent-env"
                    optional: true
                image: "136299550619.dkr.ecr.us-west-2.amazonaws.com/cammismaven:1.0.0"
                name: "cammismaven"
                securityContext:
                  privileged: true
                tty: true
                volumeMounts:
                - mountPath: "/etc/pki/tls/certs"
                  name: "jenkins-trusted-ca-bundle"
                - mountPath: "/home/jenkins/agent"
                  name: "workspace-volume"
                  readOnly: false
                workingDir: "/home/jenkins/agent"
              nodeSelector:
                kubernetes.io/os: "linux"
              restartPolicy: "Never"
              serviceAccountName: "jenkins"
              volumes:
              - hostPath:
                  path: "/var/run/docker.sock"
                name: "dockersock"
              - configMap:
                  defaultMode: 420
                  name: "jenkins-trusted-ca-bundle"
                  optional: true
                name: "jenkins-trusted-ca-bundle"
              - emptyDir: {}
                name: "varlibcontainers"
              - emptyDir:
                  medium: ""
                name: "workspace-volume"
            """
        }
    }
    stages {
        stage('Initialize') {
            steps {
                echo 'Initialization steps'
            }
        }
        
        stage('Checkout Source') {
            steps {
                container('jnlp') {
                    script {
                        deleteDir()
                        checkout(scm)
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
                    dir('spring-app') {
                        withEnv(['NEXUS_USER=<your-nexus-username>', 'NEXUS_PASSWORD=<your-nexus-password>']) {
                            sh 'mvn clean deploy -DskipTests=true'
                        }
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo 'Build and deployment process finished'
        }
        failure {
            echo 'Build and deployment failed'
        }
    }
}
