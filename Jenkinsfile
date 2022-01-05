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
        // option to install b&r site manager
        choice choices: ['yes', 'no'], description: 'Install SiteManager', name: 'siteManager'
    }
    
    options {
        timestamps()
        buildDiscarder logRotator(artifactNumToKeepStr: '1', numToKeepStr: '15')
        disableConcurrentBuilds()
    }

    environment {
		SCRIPT_DIR="/var/lib/jenkins/scripts"
		IMAGE_CREATOR_NAME="image-creator.sh"
        IMAGE_CREATOR_ORG="${WORKSPACE}/${IMAGE_CREATOR_NAME}"
        IMAGE_CREATOR="${SCRIPT_DIR}/${IMAGE_CREATOR_NAME}"
    }

    stages {
        stage('Prepare') {
            steps {
                checkout scm
				
				//
				// do some cleaning... (clean up after build would hide some result steps)
				//
                sh """#!/bin/bash
					## remove old packages
					rm ${WORKSPACE}/packages/deb/*.deb || true
					
					## remove old site manager
					rm ${WORKSPACE}/packages/sitemanager/*.tar* || true
					
					## remove rootfs
                    echo "clean..."
					sudo ${IMAGE_CREATOR} --clean --image-target none
                """
 
                copyArtifacts(projectName: "pds-cutter-ngs/${params.sourceBranch}", filter: "pds-cutter_*.deb", flatten: true, target: "packages/deb/")
                copyArtifacts(projectName: "qtopcua-upstream", filter: "qtopcua-bin_5.15.0-1.tar.gz", flatten: true, target: "packages/tarballs/")

				archiveArtifacts artifacts: "packages/deb/pds-cutter_*.deb", fingerprint: true
				
                sh """#!/bin/bash
					echo "use application package from pds-cutter-ngs/${params.sourceBranch}"
					ls -l ${WORKSPACE}/packages/deb/*.deb
					
					## just if something went wrong before
					if [ -f ${SCRIPT_DIR} ]; then
						echo "${SCRIPT_DIR} is a file => remove!"
						rm -f ${SCRIPT_DIR}
					fi
					
					## create script destination directory
					if [ ! -d ${SCRIPT_DIR} ]; then
						echo "create ${SCRIPT_DIR}"
						mkdir -p ${SCRIPT_DIR}/
					fi

 					## remove old script
					if [ -f ${IMAGE_CREATOR} ]; then
						echo "revove old ${IMAGE_CREATOR}!"
						rm -f ${IMAGE_CREATOR}
						## control output
						echo "---"
						ls -l ${SCRIPT_DIR}/*.sh
						echo "---"
					fi
					
					## copy script to run from destination (for sudo reason)
					echo "copy ${IMAGE_CREATOR_ORG} to ${SCRIPT_DIR}/"
					cp ${IMAGE_CREATOR_ORG} ${SCRIPT_DIR}/
					
					## script output 4 verifikation
					echo "used script:"
					ls -l ${IMAGE_CREATOR}
					echo "---"
					cat ${IMAGE_CREATOR}
					echo "---"
                """
            }
        }
		
        stage('Fetch SiteManager') {
            when {
                expression { params.siteManager == "yes" }
            }
            steps {
				copyArtifacts(projectName: "sitemanagertar/master", filter: "SiteManager.tar", flatten: true, target: "packages/sitemanager/")
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
                """
				archiveArtifacts artifacts: "*installer_2*.bin", fingerprint: true
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
		
		/*
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
		*/
    }
}
