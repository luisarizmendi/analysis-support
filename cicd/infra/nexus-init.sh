#!/bin/bash
set -x 


#
# add_nexus3_repo [repo-id] [repo-url] [nexus-username] [nexus-password] [nexus-url]
#
function add_nexus3_repo() {
  local _REPO_ID=$1
  local _REPO_URL=$2
  local _NEXUS_USER=$3
  local _NEXUS_PWD=$4
  local _NEXUS_URL=$5

  read -r -d '' _REPO_JSON << EOM
{
  "name": "$_REPO_ID",
  "type": "groovy",
  "content": "repository.createMavenProxy('$_REPO_ID','$_REPO_URL')"
}
EOM

  # Pre Nexus 3.8
  curl -v -H "Accept: application/json" -H "Content-Type: application/json" -d "$_REPO_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/siesta/rest/v1/script/"
  curl -v -X POST -H "Content-Type: text/plain" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/siesta/rest/v1/script/$_REPO_ID/run"

  # Post Nexus 3.8
  curl -v -H "Accept: application/json" -H "Content-Type: application/json" -d "$_REPO_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/"
  curl -v -X POST -H "Content-Type: text/plain" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/$_REPO_ID/run"
}

#
# add_nexus3_group_repo [comma-separated-repo-ids] [group-id] [nexus-username] [nexus-password] [nexus-url]
#
function add_nexus3_group_repo() {
  local _REPO_IDS=$1
  local _GROUP_ID=$2
  local _NEXUS_USER=$3
  local _NEXUS_PWD=$4
  local _NEXUS_URL=$5

  read -r -d '' _REPO_JSON << EOM
{
  "name": "$_GROUP_ID",
  "type": "groovy",
  "content": "repository.createMavenGroup('$_GROUP_ID', '$_REPO_IDS'.split(',').toList())"
}
EOM

  # Pre Nexus 3.8
  curl -v -H "Accept: application/json" -H "Content-Type: application/json" -d "$_REPO_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/siesta/rest/v1/script/"
  curl -v -X POST -H "Content-Type: text/plain" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/siesta/rest/v1/script/$_GROUP_ID/run"

  # Post Nexus 3.8
  curl -v -H "Accept: application/json" -H "Content-Type: application/json" -d "$_REPO_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/"
  curl -v -X POST -H "Content-Type: text/plain" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/rest/v1/script/$_GROUP_ID/run"
}

#
# add_nexus3_redhat_repos [nexus-username] [nexus-password] [nexus-url]
#
function add_nexus3_demo_repos() {
  local _NEXUS_USER=$1
  local _NEXUS_PWD=$2
  local _NEXUS_URL=$3

  add_nexus3_repo redhat-ga https://maven.repository.redhat.com/ga/ $_NEXUS_USER $_NEXUS_PWD $_NEXUS_URL
  add_nexus3_repo redhat-ea https://maven.repository.redhat.com/earlyaccess/all/ $_NEXUS_USER $_NEXUS_PWD $_NEXUS_URL
  add_nexus3_repo redhat-techpreview https://maven.repository.redhat.com/techpreview/all $_NEXUS_USER $_NEXUS_PWD $_NEXUS_URL
  add_nexus3_repo jboss-ce https://repository.jboss.org/nexus/content/groups/public/ $_NEXUS_USER $_NEXUS_PWD $_NEXUS_URL

  add_nexus3_group_repo maven-central,maven-releases,maven-snapshots,jboss-ce,redhat-ga,redhat-ea,redhat-techpreview maven-all-public $_NEXUS_USER $_NEXUS_PWD $_NEXUS_URL
}