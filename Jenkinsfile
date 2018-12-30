pipeline {
  agent {
    node {
      label 'ansible'
    }
  }
  stages {
    stage('Install virtual environment') {
      steps {
        script {
          sh(script: 'python -m pip install --user virtualenv')
          sh(script: 'python -m virtualenv --no-site-packages .testenv')
          sh(script: 'source ./.testenv/bin/activate')
          sh(script: '.testenv/bin/pip install -r tests/requirements.txt --no-cache-dir')
        }
      }
    }
    stage('ansible-lint validation') {
      steps {
        script {
          sh(script: ".testenv/bin/ansible-lint tasks/main.yml", returnStdout: true)
        }
      }
    }
    stage('yamllint validation') {
      steps {
        script {
          sh(script: ".testenv/bin/yamllint .", returnStdout: true)
        }
      }
    }
  }
}
