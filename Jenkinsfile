pipeline {
    agent any
    
    parameters {
        choice choices: ['production', 'installation', 'development'], description: 'Image type', name: 'imageType'
		// actual there is no loop target posible
        //choice choices: ['installer', 'tarball', 'loop'], description: 'Image target', name: 'imageTarget'
        choice choices: ['installer', 'tarball'], description: 'Image target', name: 'imageTarget'
        choice choices: ['develop', 'prototype'], description: 'Application source branch', name: 'sourceBranch'
        choice choices: ['amd64'], description: 'Image architecture', name: 'imageArch'
        choice choices: ['focal'], description: 'Image distro', name: 'imageDistro'
    }
    
    options {
        timestamps()
        buildDiscarder logRotator(artifactNumToKeepStr: '1', numToKeepStr: '15')
        disableConcurrentBuilds()
    }

    environment {
		SCRIPT_DIR="/var/lib/jenkins/scripts"
        IMAGE_CREATOR_ORG="${WORKSPACE}/image-creator.sh"
        IMAGE_CREATOR_DIR="${SCRIPT_DIR}"
        IMAGE_CREATOR="${IMAGE_CREATOR_DIR}/image-creator.sh"
    }

    stages {
        stage('Prepare') {
            steps {
                checkout scm
                copyArtifacts(projectName: "pds-cutter-ngs/${params.sourceBranch}", filter: "pds-cutter_*.deb", flatten: true, target: "packages/deb/")
                copyArtifacts(projectName: "qtopcua-upstream", filter: "qtopcua-bin_5.15.0-1.tar.gz", flatten: true, target: "packages/tarballs/")
                sh """#!/bin/bash
					echo "use application package from pds-cutter-ngs/${params.sourceBranch}"
					ls -l ${WORKSPACE}/packages/deb/*.deb
					if [ -f ${SCRIPT_DIR} ]; then
						echo "${SCRIPT_DIR} is a file => remove!"
						##echo "--- ${SCRIPT_DIR} ---"
						##cat ${SCRIPT_DIR}
						##echo "---"
						rm -f ${SCRIPT_DIR}
					fi
					if [ ! -d ${SCRIPT_DIR} ]; then
						echo "create ${SCRIPT_DIR}"
						mkdir -p ${SCRIPT_DIR}/
					fi
					echo copy ${IMAGE_CREATOR_ORG} to ${SCRIPT_DIR}/
					cp ${IMAGE_CREATOR_ORG} ${SCRIPT_DIR}/
					##ls -l ${SCRIPT_DIR}/*.sh
                """
            }
        }
		// only for some test reason
		/*
        stage('Research') {
            steps {
                sh """#!/bin/bash
					##ls -l
					##ls -l ${WORKSPACE}/..
					##ls -l ${WORKSPACE}
					##echo "--- workspaces ---"
					##cat ${WORKSPACE}/../workspaces.txt
					##echo "---"
					##ls -l ${WORKSPACE}/../image-creator
					##ls -l ${WORKSPACE}/../image-creator/rootfs
					##ls -l ${SCRIPT_DIR}/
					echo "used script:"
					ls -l ${IMAGE_CREATOR}
					echo "---"
					cat ${IMAGE_CREATOR}
					echo "---"
                """
            }
        }
		*/
        stage('Rootfs Tarball') {
            when {
                expression { params.imageTarget == "tarball" }
            }
            steps {
                sh """#!/bin/bash
                     sudo ${IMAGE_CREATOR} --arch ${params.imageArch} --distro ${params.imageDistro} --image-target tarball --image-type ${params.imageType} --clean
					 ##echo "target ist stored to \'${SCRIPT_DIR}/\' - todo: should be stored to workspace"
					 ##echo "workaround is a target copy"
					 ##cp ${SCRIPT_DIR}/*.tar.bz2 ${WORKSPACE}/
                """
				archiveArtifacts artifacts: "*.tar.bz2", fingerprint: true
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
					 ##echo "target ist stored to \'${SCRIPT_DIR}/\' - todo: should be stored to workspace"
					 ##echo "workaround is a target copy"
					 ##cp ${SCRIPT_DIR}/*.bin ${WORKSPACE}/
                """
				archiveArtifacts artifacts: "*.bin", fingerprint: true
            }
        }
		// this does actual not work on the jenkins server
		/*
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
		*/
        stage('Clean Up') {
            steps {
                sh """#!/bin/bash
                    echo "clean..."
					sudo ${IMAGE_CREATOR} --clean --image-target none
					echo "workspace:"
					ls -l ${WORKSPACE}/
					echo "scriptdir:"
					ls -l ${SCRIPT_DIR}/
                """
            }
        }
    }
}
