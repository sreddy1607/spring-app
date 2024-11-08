def currentBranch = env.BRANCH_NAME ?: 'feature/devops'
def environmentNamespace = env.NAMESPACE ?: 'dev'
def workspaceDirectory = '/home/jenkins/agent'
def versionFile = "devops/version.txt"

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
    - name: m2-cache
      emptyDir: {}
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
        workingDir: /home/jenkins/agent
      envFrom:
        - configMapRef:
            name: jenkins-agent-env
            optional: true
      env:
        - name: HOME
          value: /home/jenkins/agent
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
        - name: m2-cache
          mountPath: /root/.m2
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
        
        booleanParam(name: 'DEPLOY_LATEST', defaultValue: false, description: 'Deploy then current build ?')
        booleanParam(name: 'DEPLOY_EXISTING', defaultValue: true, description: 'Deploy to Previous build Version?')   
    }  
    
    environment {
        env_git_branch_type = 'feature/devops'
        env_git_branch_name = ''
        env_current_git_commit = ''
        env_skip_build = 'false'
        env_stage_name = ''
        env_step_name = ''
        env_release_type = "${params.RELEASE_TYPE}"

        SONAR_TIMEOUT = 3
        SONAR_SLEEP = 10000
        SONAR_ERROR_MSG = 'QUALITY GATE ERROR: Pipeline set to unstable '
        SONAR_BUILD_RESULT = 'UNSTABLE'
        SONAR_SLACK_MSG = 'Quality Gate Passed'

        NEXUS_URL = 'https://nexusrepo-tools.apps.bld.cammis.medi-cal.ca.gov'
        NEXUS_REPOSITORY = 'feature-image-viewer-app'
        NEXUS_CREDENTIALS = credentials('nexus-credentials')
        MAVEN_CONFIG_DIR = '/root/.m2' // Define the Maven configuration directory
        COMMON_REPO = 'https://github.com/ca-mmis/tar-common.git'
        IMAGE_VIEWER_REPO = 'https://github.com/ca-mmis/tar-image-viewer-app.git'
        GIT_CREDENTIALS = 'github-key'
        REPOSITORY = 'feature-image-viewer-app'
        GROUP_ID = 'SURGE_image_viewer'
        ARTIFACT_ID = 'SURGE_image_viewer'
        PACKAGING = ''
        CREDENTIALS_ID = 'nexus-credentials'
    }

    stages {
        stage('Initialize') {
            steps {
                container('cammismaven') {
                    script {
                        
                        deleteDir()
                        echo 'Checkout main source and get the commit ID'
                        def mainCommit = checkout(scm).GIT_COMMIT
                        echo "Main repository commit ID: ${mainCommit}"

                        // Load or initialize the version file
                        def version = "1.0.0"  // Default version
                        if (fileExists(versionFile)) {
                            version = readFile(versionFile).trim()
                        } else {
                            writeFile(file: versionFile, text: version)
                        }
                        env.BUILD_VERSION = version

                        // Compare with the previous build’s commit ID
                        if (fileExists('devops/previous_commit.txt')) {
                            def previousCommit = readFile('devops/previous_commit.txt').trim()
                            if (previousCommit == mainCommit) {
                                echo "No changes detected from previous build. Skipping build."
                                currentBuild.result = 'SUCCESS'
                                return
                            }
                        }
                        writeFile(file: 'devops/previous_commit.txt', text: mainCommit)

                        echo 'Cloning SURGE_common and tar_image_viewer repositories'
                        git branch: 'master', credentialsId: GIT_CREDENTIALS, url: COMMON_REPO
                        dir('SURGE_image_viewer') {
                            git branch: 'feature/devops', credentialsId: GIT_CREDENTIALS, url: IMAGE_VIEWER_REPO
                        }

                        echo 'Creating Maven settings.xml'
                        sh """
                            mkdir -p ${MAVEN_CONFIG_DIR}
                            echo "<settings xmlns='http://maven.apache.org/SETTINGS/1.0.0'
                            xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'
                            xsi:schemaLocation='http://maven.apache.org/SETTINGS/1.0.0
                            http://maven.apache.org/xsd/settings-1.0.0.xsd'>
                            <localRepository>${MAVEN_CONFIG_DIR}/repository</localRepository>
                            </settings>" > ${MAVEN_CONFIG_DIR}/settings.xml
                        """
                    }
                }
            }
        }
        
        stage('Build') {
            when { expression { return params.DEPLOY_LATEST } }
            steps {
                container('cammismaven') {
                    script {
                        echo 'Building SURGE_common project'
                        dir('SURGE_common') {
                            sh 'mvn clean install'
                        }

                        echo 'Building and packaging SURGE_image_viewer project'
                        dir('SURGE_image_viewer/SURGE_image_viewer') {
                            sh "mvn clean package --settings ${MAVEN_CONFIG_DIR}/settings.xml"
                        }
                    }
                }
            }
        }

        stage('Sonar Scan') {
            steps {
                script {
                    withSonarQubeEnv('sonar_server') {
                        container(name: 'cammismaven') {
                            sh """
                                echo 'wget and unzip file'
                                mkdir -p /home/jenkins/agent/.sonar/native-sonar-scanner
                                wget --quiet https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-6.1.0.4477-linux-x64.zip
                                unzip -q sonar-scanner-cli-6.1.0.4477-linux-x64.zip -d /home/jenkins/agent/.sonar/native-sonar-scanner
                            """
                        }
                        container(name: 'jnlp') {
                            sh """
                                echo 'doing sonar-scanner call'
                                /home/jenkins/agent/.sonar/native-sonar-scanner/sonar-scanner-6.1.0.4477-linux-x64/bin/sonar-scanner -Dproject.settings=${WORKSPACE}/SURGE_image_viewer/devops/sonar/sonar-project.properties
                            """
                        }
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                container(name: 'jnlp') {
                    script {
                        sh """
                            echo "######################################################################################\n"
                            echo "####       RUNNING SONARQUBE QUALITY GATE CHECK                                                                  ####\n"
                            echo "SONAR TIMEOUT  ${SONAR_TIMEOUT}"
                            cat ${WORKSPACE}/SURGE_image_viewer/devops/sonar/sonar-project.properties
                            echo "#################################################################################\n"
                        """
                        sleep time: SONAR_SLEEP, unit: 'MILLISECONDS'

                        timeout(time: SONAR_TIMEOUT, unit: 'MINUTES') {
                            def qualGate = waitForQualityGate()
                            if (qualGate.status == 'OK') {
                                echo "PIPELINE INFO: ${qualGate.status}\n"
                            } else if (qualGate.status == 'NONE') {
                                SONAR_SLACK_MSG = 'PIPELINE WARNING: NO Quality Gate or projectKey associated with project \nCheck sonar-project.properties projectKey value is correct'
                                echo "Quality gate failure: ${qualGate.status} \n ${SONAR_SLACK_MSG} \n#####################################################################################################################\n"
                                currentBuild.result = SONAR_BUILD_RESULT
                            } else {
                                echo "Quality Gate: ${qualGate.status} \n ${SONAR_SLACK_MSG} \n#####################################################################################################################\n"
                                slackNotification('pipeline', "${APP_NAME}-${env_git_branch_name}: <${BUILD_URL}|build #${BUILD_NUMBER}> ${SONAR_SLACK_MSG}.", '#F6F60F', 'true')
                                currentBuild.result = SONAR_BUILD_RESULT
                            }
                        }
                    }
                }
            }
        }

        stage('Nexus Upload') {
            when { expression { return params.DEPLOY_LATEST } }
            steps {
                container('cammismaven') {
                    script {
                        sh '''
                          cd SURGE_image_viewer/SURGE_image_viewer
                          FILENAME=$(ls target/ | grep -E '.jar$|.war$|.ear$' | head -1)
	                  FILETYPE="${FILENAME##*.}"
                          curl -kv -u ${NEXUS_CREDENTIALS_USR}:${NEXUS_CREDENTIALS_PSW} -F "maven2.generate-pom=false" -F "maven2.asset1=@pom.xml" -F "maven2.asset1.extension=pom" -F "maven2.asset2=@target/$FILENAME;type=application/java-archive" -F "maven2.asset2.extension=$FILETYPE" ${NEXUS_URL}/service/rest/v1/components?repository=${NEXUS_REPOSITORY}
                            '''
                    }
            }
        }
    }

stage('VERSIONS AVAILABLE') {
    steps {
        container('cammismaven') {
            script {
                // Ask if deploying the latest version or an existing version
                
                
                if (params.DEPLOY_LATEST) {
                    // If deploying the latest version, skip version fetching
                    echo "Deploying the latest version..."
                    // You can set the version to 'latest' or use any other appropriate flag for the latest version
                    env.ARTIFACT_VERSION = "latest"
                } else {
                    // If deploying an existing version, fetch available versions from Nexus
                    echo "Fetching available versions from Nexus..."

                    def nexusResponse = sh(script: """ 
                        curl -kv -u ${NEXUS_CREDENTIALS_USR}:${NEXUS_CREDENTIALS_PSW} -X GET "${NEXUS_URL}/service/rest/v1/search?repository=${NEXUS_REPOSITORY}&group=${GROUP_ID}&name=${ARTIFACT_ID}" -H "Accept: application/json" -s 
                    """, returnStdout: true)

                    def jsonResponse = readJSON(text: nexusResponse)
                    def versions = jsonResponse.items.collect { it.version }.join('\n') // Use newline for `choice` parameter

                    // Dynamically set the choice parameter for versions
                    properties([
                        parameters([
                            choice(
                                name: 'ARTIFACT_VERSION', 
                                choices: versions, 
                                description: 'Select the version of the Maven artifact to deploy'
                            )
                        ])
                    ])

                    echo "Available versions: ${versions}"
                }
            }
        }
    }
}
  
        stage('Deploy LATEST') {
            when { expression { return params.DEPLOY_LATEST } }
            steps {
                container('cammismaven') {
                    script {

                        sh '''
                          echo " deploying latest version to tomcat"
                            '''

                    }
                }
            }
        }
        stage('Deploy EXISTING') {
            when { expression { return params.DEPLOY_EXISTING } }
            steps {
                container('cammismaven') {
                    script {

                        def selectedVersion = params.ARTIFACT_VERSION
                        def targetDirectory = "${workspaceDirectory}/target"
                        def artifactBaseUrl = "${NEXUS_URL}/repository/${NEXUS_REPOSITORY}/${GROUP_ID.replace('.', '/')}/${ARTIFACT_ID}/${selectedVersion}/${ARTIFACT_ID}-${selectedVersion}"
                
                        echo "Attempting to download JAR or WAR file from Nexus..."
                        sh "mkdir -p ${targetDirectory}"

                        withCredentials([usernamePassword(credentialsId: 'nexus-credentials', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                        def packagingOptions = ["jar", "war"]
                        def downloadSuccess = false
                    
                        for (type in packagingOptions) {
                        def downloadUrl = "${artifactBaseUrl}.${type}"
                        def outputFile = "${targetDirectory}/${ARTIFACT_ID}-${selectedVersion}.${type}"
                        
                        try {
                            sh """
                                curl -f -o ${outputFile} -u '${NEXUS_USER}:${NEXUS_PASS}' -k "${downloadUrl}"
                            """
                            echo "Successfully downloaded ${type.toUpperCase()} file: ${outputFile}"
                            downloadSuccess = true
                            env.PACKAGING = type
                            break
                        } catch (Exception e) {
                            echo "Failed to download ${type.toUpperCase()} file. Trying next option if available."
                        }
                    }
                    
                        if (!downloadSuccess) {
                        error "Failed to download both JAR and WAR files. Please check Nexus repository."
                    }
                }
                
                        // List all downloaded files in the target directory
                        echo "Listing all downloaded files in ${targetDirectory}:"
                        sh "ls -al ${targetDirectory}"
                        

                    }
                }
            }
        }
  }
}
