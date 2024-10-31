def currentBranch = env.BRANCH_NAME ?: "ecr"
def environmentNamespace = env.NAMESPACE ?: "dev"
def workspaceDirectory = "/home/jenkins/agent"

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
            - name: cammismaven
              image: 136299550619.dkr.ecr.us-west-2.amazonaws.com/cammismaven:1.0.0
              tty: true
              command: ["/bin/bash"]
              securityContext:
                privileged: true
              workingDir: ${workspaceDirectory}
              envFrom:
                - configMapRef:
                    name: jenkins-agent-env
                    optional: true
              env:
                - name: HOME
                  value: ${workspaceDirectory}
                - name: BRANCH
                  value: ${currentBranch}
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
  
  parameters {
    choice(name: 'RELEASE_TYPE', choices: ['PATCH', 'MINOR', 'MAJOR'], description: 'Enter Release type')
    string(name: 'RELEASE', defaultValue: 'enter release name', description: 'Override Release Name')
  }
  
  environment {
    env_git_branch_type = "feature/devops"
    env_git_branch_name = ""
    env_current_git_commit = ""
    env_skip_build = "false"
    env_stage_name = ""
    env_step_name = ""
    env_release_type = "${params.RELEASE_TYPE}"
    
    SONAR_TIMEOUT = 3
    SONAR_SLEEP = 10000
    SONAR_ERROR_MSG = "QUALITY GATE ERROR: Pipeline set to unstable "
    SONAR_BUILD_RESULT = "UNSTABLE"
    SONAR_SLACK_MSG = "Quality Gate Passed"
    
    NEXUS_URL = "https://nexusrepo-tools.apps.bld.cammis.medi-cal.ca.gov"
    NEXUS_REPOSITORY = "feature-tar-purge-hosted"
    NEXUS_CREDENTIALS = credentials('nexus-credentials')
  }

  stages {
    stage("Initialize") {
      steps {
        container(name: "cammismaven") {
          script {
            env_stage_name = "initialize"
            env_step_name = "checkout"

            deleteDir()
            echo 'Checkout source and get the commit ID'
            env_current_git_commit = checkout(scm).GIT_COMMIT

            echo 'Loading properties file'
            env_step_name = "load properties"
            env_step_name = "set global variables"
            echo 'Initialize Slack channels and tokens'
          }
        }
      }
    }

    stage('Maven Build') {
      steps {
        container('cammismaven') {
          script {
            def newReleaseName = params.RELEASE ?: "default-release-name"
            def newVersion = ""
            
            if (env_release_type == "MAJOR") {
              newVersion = "1.0.0"
            } else if (env_release_type == "MINOR") {
              newVersion = "1.1.0"
            } else if (env_release_type == "PATCH") {
              newVersion = "1.0.1"
            } else {
              newVersion = "1.0.0-SNAPSHOT"
            }

            sh """
            cd tarpurge
            mvn clean package -DartifactId=${newReleaseName} -Dversion=${newVersion}
            """
          }
        }
      }
    }

    stage('Sonar Scan') {
      steps {
        script {
          withSonarQubeEnv('sonar_server') {
            container(name: "cammismaven") {
              sh """
              echo ' wget and unzip file'
              mkdir -p /home/jenkins/agent/.sonar/native-sonar-scanner
              wget --quiet https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-6.1.0.4477-linux-x64.zip
              unzip -q sonar-scanner-cli-6.1.0.4477-linux-x64.zip -d /home/jenkins/agent/.sonar/native-sonar-scanner
              """
            }
            container(name: "jnlp") {
              sh """
              echo ' doing sonar-scanner call'
              /home/jenkins/agent/.sonar/native-sonar-scanner/sonar-scanner-6.1.0.4477-linux-x64/bin/sonar-scanner -Dproject.settings=${WORKSPACE}/devops/sonar/sonar-project.properties
              """
            }
          }
        }
      }
    }

    stage("Quality Gate") {
      steps {
        container(name: "jnlp") {
          script {
            sh """
            echo "######################################################################################\n"
            echo "####       RUNNING SONARQUBE QUALITY GATE CHECK                                                                  ####\n"
            echo "SONAR TIMEOUT  ${SONAR_TIMEOUT}"
            cat ${WORKSPACE}/devops/sonar/sonar-project.properties
            echo "#################################################################################\n"
            """
            sleep time: SONAR_SLEEP, unit: "MILLISECONDS"

            timeout(time: SONAR_TIMEOUT, unit: 'MINUTES') {
              def qualGate = waitForQualityGate()
              if (qualGate.status == "OK") {
                echo "PIPELINE INFO: ${qualGate.status}\n"
              } else if (qualGate.status == "NONE") {
                SONAR_SLACK_MSG = "PIPELINE WARNING: NO Quality Gate or projectKey associated with project \nCheck sonar-project.properties projectKey value is correct"
                echo "Quality gate failure: ${qualGate.status} \n ${SONAR_SLACK_MSG} \n#####################################################################################################################\n"
                currentBuild.result = SONAR_BUILD_RESULT
              } else {
                echo "Quality Gate: ${qualGate.status} \n ${SONAR_SLACK_MSG} \n#####################################################################################################################\n"
                slackNotification("pipeline","${APP_NAME}-${env_git_branch_name}: <${BUILD_URL}|build #${BUILD_NUMBER}> ${SONAR_SLACK_MSG}.", "#F6F60F","true")
                currentBuild.result = SONAR_BUILD_RESULT
              }
            }
          }
        }
      }
    }

    stage('Upload Artifact to Nexus') {
      steps {
        container('cammismaven') {
          script {
             
 
    sh '''
    
    cd tarpurge
    JARFILE=$(ls target/ | grep -E '.jar$|.war$|.ear$' | head -1)
    
    curl -kv -u ${NEXUS_CREDENTIALS_USR}:${NEXUS_CREDENTIALS_PSW} -F "maven2.generate-pom=false" -F "maven2.asset1=@pom.xml" -F "maven2.asset1.extension=pom" -F "maven2.asset2=@target/$JARFILE;type=application/java-archive" -F "maven2.asset2.extension=war" ${NEXUS_URL}/service/rest/v1/components?repository=${NEXUS_REPOSITORY}
    '''

            }
        }
      }
    }
  }
}
