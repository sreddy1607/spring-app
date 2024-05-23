def branch = env.BRANCH_NAME ?: "ecr"
def namespace = env.NAMESPACE ?: "dev"
def workingDir = "/home/jenkins/agent"

pipeline {
  agent {
    kubernetes {
      yaml """
        apiVersion: v1
        kind: Pod
        spec:
          serviceAccountName: jenkins
          volumes:
            - name: dockersock
              hostPath:
                path: /var/run/docker.sock
            - name: varlibcontainers
              emptyDir: {}
            - name: jenkins-trusted-ca-bundle
              configMap:
                name: jenkins-trusted-ca-bundle
                defaultMode: 420
                optional: true
          containers:
            - name: jnlp
              securityContext:
                privileged: true
              envFrom:
                - configMapRef:
                    name: jenkins-agent-env
                    optional: true
              env:
                - name: GIT_SSL_CAINFO
                  value: "/etc/pki/tls/certs/ca-bundle.crt"
              volumeMounts:
                - name: jenkins-trusted-ca-bundle
                  mountPath: /etc/pki/tls/certs
            - name: node
              image: registry.access.redhat.com/ubi8/nodejs-16:latest
              tty: true
              command: ["/bin/bash"]
              securityContext:
                privileged: true
              workingDir: ${workingDir}
              envFrom:
                - configMapRef:
                    name: jenkins-agent-env
                    optional: true
              env:
                - name: HOME
                  value: ${workingDir}
                - name: BRANCH
                  value: ${branch}
                - name: GIT_SSL_CAINFO
                  value: "/etc/pki/tls/certs/ca-bundle.crt"
              volumeMounts:
                - name: jenkins-trusted-ca-bundle
                  mountPath: /etc/pki/tls/certs
            - name: cammismaven
              image: 136299550619.dkr.ecr.us-west-2.amazonaws.com/cammismaven:1.0.0
              tty: true
              command: ["/bin/bash"]
              securityContext:
                privileged: true
              workingDir: ${workingDir}
              envFrom:
                - configMapRef:
                    name: jenkins-agent-env
                    optional: true
              env:
                - name: HOME
                  value: ${workingDir}
                - name: BRANCH
                  value: ${branch}
                - name: NEXUS_ACCESS_TOKEN
                  valueFrom:
                    secretKeyRef:
                      name: jenkins-token-qqsb2
                      key: token
                - name: GIT_SSL_CAINFO
                  value: "/etc/pki/tls/certs/ca-bundle.crt"
              volumeMounts:
                - name: jenkins-trusted-ca-bundle
                  mountPath: /etc/pki/tls/certs
      """
    }
  }

  options {
    disableConcurrentBuilds()
    timeout(time: 5, unit: 'HOURS')
    skipDefaultCheckout()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  environment {
    env_git_branch_type = "feature"
    env_git_branch_name = ""
    env_current_git_commit = ""
    env_skip_build = "false"
    env_stage_name = ""
    env_step_name = ""
    DOTNET_CLI_TELEMETRY_OPTOUT = '1'
    NEXUS_URL = "https://nexusrepo-tools.apps.bld.cammis.medi-cal.ca.gov"
    NEXUS_REPOSITORY = "cammis-java-repo-group"
    NEXUS_CREDENTIALS_ID = 'nexus-credentials'
    MAVEN_OPTS = "-Dmaven.wagon.http.ssl.insecure=true -Dmaven.wagon.http.ssl.allowall=true"
  }

  stages {
    stage("Initialize") {
      steps {
        container(name: "node") {
          script {
            properties([
              parameters([])
            ])

            env_stage_name = "initialize"
            env_step_name = "checkout"

            deleteDir()
            echo 'Checkout source and get the commit ID'
            env_current_git_commit = checkout(scm).GIT_COMMIT

            echo 'Loading properties file'
            env_step_name = "load properties"
            load(".jenkins/pipelines/Jenkinsfile.ecr.properties")

            env_step_name = "set global variables"
            echo 'Initialize Slack channels and tokens'
            initSlackChannels()

            env_git_branch_name = BRANCH_NAME
            env_current_git_commit = "${env_current_git_commit[0..7]}"
            echo "The commit hash from the latest git current commit is ${env_current_git_commit}"
            currentBuild.displayName = "#${BUILD_NUMBER}"
            slackNotification("pipeline","${APP_NAME}-${env_git_branch_name}: <${BUILD_URL}console|build #${BUILD_NUMBER}> started.","#439FE0","false")
          }
        }
      }
    }

    stage('Prepare Environment') {
      steps {
        container('cammismaven') {
          script {
            echo 'Preparing environment'
            // Download Nexus certificate and import it to the Java truststore
            sh """
              echo | openssl s_client -connect ${env.NEXUS_URL}:443 -showcerts > nexus-cert.pem
              keytool -importcert -file nexus-cert.pem -keystore /usr/lib/jvm/java-17-openjdk/lib/security/cacerts -alias nexus-cert -storepass changeit -noprompt
            """
          }
        }
      }
    }

    stage('Build and Deploy to Nexus') {
      steps {
        container('cammismaven') {
          withCredentials([usernamePassword(credentialsId: 'nexus-credentials', usernameVariable: 'NEXUS_USERNAME', passwordVariable: 'NEXUS_PASSWORD')]) {
            script {
              // Write custom settings.xml file
              writeFile file: 'settings.xml', text: """
                <settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
                          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                          xsi:schemaLocation="http://maven.apache.org/xsd/settings-1.0.0.xsd">
                  <servers>
                    <server>
                      <id>nexus</id>
                      <username>${env.NEXUS_USERNAME}</username>
                      <password>${env.NEXUS_PASSWORD}</password>
                      <configuration>
                        <httpConfiguration>
                          <all>
                            <params>
                              <property>
                                <name>ssl.insecure</name>
                                <value>true</value>
                              </property>
                              <property>
                                <name>ssl.allowall</name>
                                <value>true</value>
                              </property>
                            </params>
                          </all>
                        </httpConfiguration>
                      </configuration>
                    </server>
                  </servers>
                </settings>
              """
              sh """
                git clone https://github.com/sreddy1607/spring-app.git
                cp settings.xml spring-app
                cd spring-app
                mvn deploy:deploy-file \\
                  -DgroupId=com.example \\
                  -DartifactId=spring-app \\
                  -Dversion=1.0.0 \\
                  -Dpackaging=jar \\
                  -Dfile=target/spring-app-1.0.0.jar \\
                  -DrepositoryId=nexus \\
                  -Durl=${env.NEXUS_URL}/repository/${env.NEXUS_REPOSITORY}/
              """
            }
          }
        }
      }
    }
  }
}
