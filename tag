#! /usr/bin/env bash
# vim:ft=sh
set -eu

MY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${MY_DIR}/utils

FILE_TO_TAG=${1?You need to provide me something to tag}
ABS_PATH_OF_FILE_TO_TAG=$(abspath ${FILE_TO_TAG})
shift
TAGS=("$@")

# this is the root of where our tag data will be stored
TAG_STORE_ROOT=${TAG_STORE_ROOT-~/.tags}
# and under that, where our "items tagged" will be referenced
ITEM_STORE=${TAG_STORE_ROOT}/objs/
# as well, the tags that reference those tagged items
TAG_STORE=${TAG_STORE_ROOT}/tags/
mkdir -p ${ITEM_STORE} ${TAG_STORE}


# my job is to make a tag into something nice and easy to store
# on the file system
function sanitize_tag(){
  TAG="${1?You must provide a tag for me to sanitize}"
  TAG="${TAG/ /_}"
}

# my job is to determine if a provided tag meets the criteria of being
# a tag. that is to say, it must contain only alphanumeric characters
# spaces dashes '-' or underscores '_'
function validate_tag(){
  TAG="${1?You must provide a tag for me to validate}"
  TAG="${TAG//[A-Za-z0-9_\- ]/}"
  [ -z "${TAG}" ] || die "invalid tag ${TAG}, you can only use alphanumeric, space, -, and _" 1
}
# my job is to validate an entire array of tags are formatted correctly as
# per the definition in validate_tag
function validate_tags(){
  local TAGS=("$@")
  [ "${#TAGS[@]}" -ne 0 ] || exit 0 # no tags is perfectly valid
  for tag in "${TAGS[@]}"
  do
    validate_tag "$tag"
  done
}
# my job is to determine if the provided value meets the criteria to be
# a key. that is to say it, it must contain only alphanumeric characters,
# underscores '_' or dashes '-"
function validate_key(){
  local KEY="${1?You must provide a tag for me to validate}"
  local KEY="${KEY//[A-Za-z0-9_\-]/}"
  [ -z "${KEY}" ] || die "invalid key ${KEY}, you can only use alphanumeric, -, and _" 2
}

function tag_this(){
  local KEY="${1?You must provide me a key to associate tags with}"
  shift
  # After the key, the rest are the tags
  local TAGS=("$@")
  [ "${#TAGS[@]}" -eq 0 ] && die "You provided no tags, I can't tag something with no tags" 3
  local KEY_FILE="${ITEM_STORE}${KEY}.json"
  # this is not local, because we want the caller to have access
  # if they're interested
  ONCE_THRU=
  TAG_JSON=$(
    echo "{"
    echo "  "\""key"\"":"\""${KEY}"\"","
    echo -n "  "\""tags"\"":["
    for tag in "${TAGS[@]}"
    do
      [ -n "${ONCE_THRU}" ] && echo -n ","
      echo -n ""\""${tag}"\"""
      ONCE_THRU=true
    done
    echo "]"
    echo "}"
  )
  # store our tag JSON blob, which serves as a convenient way to go vrom
  # key to tags
  echo "${TAG_JSON}" > "${KEY_FILE}"

  # create our tag links which make a nice way to go from tag to items
  for tag in "${TAGS[@]}"
  do
    sanitize_tag "$tag"
    mkdir -p "${TAG_STORE}${TAG}"
    local TAG_FILE="${TAG_STORE}${TAG}/${KEY}.json"
    # it's ok, if we're overwriting one it's because it's the same thing
    ln -fs "${KEY_FILE}" "${TAG_FILE}"
  done
}

function get_tags(){
  local KEY="${1?You need to provide a key so I can look up tags for you}"
  local KEY_FILE="${ITEM_STORE}${KEY}.json"
  jq ".tags" "${KEY_FILE}"
}

# display tags
#jq ".tags" ~/.tags/objs/fa68903b60e2f919013703df0e6fdeafd7b0da7c.json | sed -e 's/["|,]//g' | sed -E '/^\[|\]$/d'

[ "${TAGS:-x}" != "x" ] && validate_tags "${TAGS[@]}"

find_a_hasher 'openssl'
KEY=$(hasher ${ABS_PATH_OF_FILE_TO_TAG})
if [ "${TAGS:-x}" == "x" ]; then
  STORED_TAGS=$(get_tags "${KEY}")
  if [ -z "${STORED_TAGS}" ]; then
    die "no tags for key ${KEY}" 0
  else
    echo ${STORED_TAGS}
  fi
else
  tag_this "${KEY}" "${TAGS[@]}"
fi

