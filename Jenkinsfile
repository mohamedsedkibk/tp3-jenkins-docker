pipeline {
  agent any
  options { timestamps() }

  environment {
    IMAGE = 'mohamedsedkiboukadida/monapp'
    TAG   = "build-${env.BUILD_NUMBER}"
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }   // lit le meme repo que le job
    }

    stage('Docker Build') {
      steps {
        bat 'docker version'
        bat "docker build -t %IMAGE%:%TAG% ."
      }
    }

    stage('Smoke Test') {
      steps {
        // Port 8083 : le port 8081 est deja utilise sur cette machine
        bat """
          docker rm -f monapp_test 2>nul || ver > nul
          docker run -d --name monapp_test -p 8083:80 %IMAGE%:%TAG%
          ping -n 3 127.0.0.1 > nul
          curl -I http://localhost:8083 | find "200 OK"
          if errorlevel 1 (
            docker rm -f monapp_test
            exit /b 1
          )
          docker rm -f monapp_test
        """
      }
    }

    stage('Push (Docker Hub)') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-cred',
                                          usernameVariable: 'USER',
                                          passwordVariable: 'PASS')]) {
          bat """
            echo %PASS%| docker login -u %USER% --password-stdin
            docker tag %IMAGE%:%TAG% %IMAGE%:latest
            docker push %IMAGE%:%TAG%
            docker push %IMAGE%:latest
            docker logout
          """
        }
      }
    }

    stage('Deploy (docker compose)') {
      steps {
        // docker-compose.exe : le plugin "docker compose" n'est pas visible par le service Jenkins
        bat 'docker-compose pull'
        bat 'docker-compose up -d'
        bat 'docker ps'
      }
    }
  }

  post {
    success { echo 'Build+Test+Push+Deploy OK' }
    failure { echo 'Build/Tests/Push/Deploy KO' }
  }
}
