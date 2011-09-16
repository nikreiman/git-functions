#!/bin/bash

# Prefer git in /usr/local to system default
[ -e "/usr/local/bin/git" ] && alias git="/usr/local/bin/git"

gitLogFormatShort="%C(cyan)%cr %Creset%s"

function git-branch-current() {
  printf "%s\n" $(git branch 2> /dev/null | grep -e ^* | tr -d "\* ")
}

function git-fetchall() {
  git fetch --all
}

function git-pull-safe() {
  local currentBranch=$(git branch 2> /dev/null | grep -e ^* | tr -d "\* ")
  local localLastCommit=$(git log $currentBranch | head -1 | cut -f 2 -d ' ')
  local remoteLastCommit=$(git log origin/$currentBranch | head -1 | cut -f 2 -d ' ')

  git fetch origin $currentBranch
  local remoteHeadCommit=$(git log origin/$currentBranch | head -1 | cut -f 2 -d ' ')
  if [ "$remoteHeadCommit" = "$localLastCommit" ] ; then
    # Same message as git pull prints in this case
    printf "Already up-to-date.\n"
    return
  fi

  git --no-pager log --oneline origin/$currentBranch ${remoteLastCommit}..HEAD
  local reply=
  echo
  while read -p "What should we do now? (merge/diff/quit) " reply ; do
    if [ "$reply" = "m" -o "$reply" = "merge" ] ; then
      git merge origin/$currentBranch
      break
    elif [ "$reply" = "d" -o "$reply" = "diff" ] ; then
      git diff origin/$currentBranch ${remoteLastCommit}..${remoteHeadCommit}
    elif [ "$reply" = "q" -o "$reply" = "quit" ] ; then
      return
    fi
  done
}

function git-stash-merge() {
  git stash
  git merge origin/$(git-branch-current)
  git stash pop
}

function git-push-dev() {
  git push origin develop
}

function git-push-all() {
  git push origin develop
  git push origin master
  git push origin --tags
}

function git-checkout() {
  git checkout --track -b $1 origin/$1
}

function git-log() {
  local outputFormat=
  if [ "$1" = "short" ] ; then
    outputFormat=$gitLogFormatShort
    shift
  else
    outputFormat="%C(yellow)%h %C(green)%cn %C(cyan)%cr %Creset%s"
  fi

  git log --format="$outputFormat" $*
}

function git-log-last-hash() {
  printf "%s\n" $(git log | head -1 | cut -f 2 -d ' ')
}

function git-log-detail() {
  git --no-pager log --full-diff -p $@
}

function git-log-detail-commit() {
  if [ -z "$1" ] ; then
    commit=$(git-log-last-hash)
  else
    commit=$1
  fi

  git --no-pager log -n 1 --full-diff -p $commit
}

function git-log-since-last-tag() {
  local format=$gitLogFormatShort
  if [ "$1" = "changelog" ] ; then
    format="- %s"
  fi
  local lastTag=$(git-tag-last)
  printf "Changes since %s:\n" $lastTag
  git --no-pager log --format="$format" "${lastTag}..HEAD"
}

function git-tag-changelog() {
  local tagName=
  if ! [ -z "$1" ] ; then
    tagName=$1
  else
    tagName=$(git-tag-last)
  fi

  git tag -v $tagName | tail -n +6
}

function git-tag-last() {
  printf "%s\n" $(git-tag-sorted | tail -1)
}

function git-tag-sorted() {
  git tag -l | sort -k 1n,1 -k 2n,2 -k 3n,3 -t '.'
}

function git-tag-next() {
  local lastTag=$(git-tag-last)
  local nextTag="${lastTag%.*}.$((${lastTag##*.} + 1))"
  if [ -z "$(grep $nextTag AndroidManifest.xml)" ] ; then
    echo "You forgot to set the version in the manifest!"
    return 1
  fi
  git-log-since-last-tag changelog > changelog.txt
  $EDITOR changelog.txt
  echo "Tagging release $nextTag with:"
  cat changelog.txt
  git tag -s $nextTag -F changelog.txt
  pbcopy < changelog.txt
  echo "Changelog copied to clipboard"
  rm changelog.txt
}

