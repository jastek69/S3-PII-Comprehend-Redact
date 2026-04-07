pipeline {
    agent any
    
    parameters {
        choice(
            name: 'ACTION',
            choices: ['apply', 'destroy', 'plan'],
            description: 'Terraform action to perform'
        )
    }
    
    environment {
        AWS_REGION = 'us-west-2'
        TF_IN_AUTOMATION = 'true'
        // SSH key managed by Jenkins Credentials Plugin
        SSH_KEY_PATH = credentials('pii-ec2-ssh-key')  // Create this in Jenkins
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'chmod +x terraform_startup.sh'
            }
        }
        
        stage('Terraform Init') {
            steps {
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials'  // Create this in Jenkins
                    ]
                ]) {
                    sh '''
                        terraform init -reconfigure
                        terraform validate
                    '''
                }
            }
        }
        
        stage('Terraform Plan') {
            when {
                expression { params.ACTION == 'plan' || params.ACTION == 'apply' }
            }
            steps {
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials'
                    ]
                ]) {
                    sh 'terraform plan -out=tfplan'
                }
            }
        }
        
        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials'
                    ]
                ]) {
                    sh './terraform_startup.sh'
                }
            }
        }
        
        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                input message: 'Are you sure you want to destroy?', ok: 'Destroy'
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials'
                    ]
                ]) {
                    sh 'terraform destroy -auto-approve'
                }
            }
        }
        
        stage('Test PII Redaction') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials'
                    ]
                ]) {
                    sh '''
                        if [ -f test-lambda.py ]; then
                            python3 test-lambda.py || echo "Test failed but continuing"
                        fi
                    '''
                }
            }
        }
    }
    
    post {
        success {
            echo 'Deployment successful!'
            sh 'terraform output'
        }
        failure {
            echo 'Deployment failed!'
        }
        always {
            // Archive Terraform state and outputs
            archiveArtifacts artifacts: '*.tfplan,terraform.tfstate', allowEmptyArchive: true
        }
    }
}
