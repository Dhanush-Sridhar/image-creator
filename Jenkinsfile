pipeline {
    agent any
    
    parameters {
        choice choices: ['production', 'installation', 'development'], description: 'Image type', name: 'imageType'
        choice choices: ['installer', 'tarball', 'loop'], description: 'Image target', name: 'imageTarget'
        choice choices: ['amd64'], description: 'Image architecture', name: 'imageArch'
        choice choices: ['focal'], description: 'Image distro', name: 'imageDistro'
    }
    
    options {
        timestamps()
        buildDiscarder logRotator(artifactNumToKeepStr: '1', numToKeepStr: '15')
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_CREATOR="${WORKSPACE}/image-creator.sh"
    }

    stages {
        stage('Prepare') {
            steps {
                checkout scm
                copyArtifacts(projectName: "pds-cutter-ngs/develop", filter: "pds-cutter_*.deb", flatten: true, target: "packages/deb/")
                copyArtifacts(projectName: "qtopcua-upstream", filter: "qtopcua-bin_5.15.0-1.tar.gz", flatten: true, target: "packages/tarballs/")
            }
        }
        stage('Rootfs Tarball') {
            when {
                expression { params.imageTarget == "tarball" }
            }
            steps {
                sh """#!/bin/bash
                     sudo ${IMAGE_CREATOR} --arch ${params.imageArch} --distro ${params.imageDistro} --image-target tarball --image-type ${params.imageType} --clean
                """
            }
        }
        stage('Image Installerscript') {
            when {
                anyOf {
                    expression { params.imageTarget == "installer" }
                    expression { params.imageType == "installation" }
                }
            }
            steps {
                sh """#!/bin/bash
                     sudo ${IMAGE_CREATOR} --arch ${params.imageArch} --distro ${params.imageDistro} --image-target installer --image-type production --clean
                """
            }
        }
        stage('Bootable Image') {
            when {
                expression { params.imageTarget == "loop" }
            }
            steps {
                sh """#!/bin/bash
                     sudo ${IMAGE_CREATOR} --arch ${params.imageArch} --distro ${params.imageDistro} --image-target loop --image-type ${params.imageType} --clean
                """
            }
        }
    }
}
