#!/bin/bash
# A collection of random git functions which help out during my daily workflow.
# This is kind of an expanded version of git aliases, with some other helper
# functions added in as well.
# To install, source this file from your ~/.bashrc
#
# All pull requests welcome. For more info, contact me at GitHub:
# http://github.com/nikreiman

# Prefer git in /usr/local to system default
[ -e "/usr/local/bin/git" ] && alias git="/usr/local/bin/git"

gitLogFormatShort="%C(cyan)%cr %Creset%s"
gitLogFormatOneline="%C(yellow)%h %C(green)%cn %C(cyan)%cr %Creset%s"

function git-branch-current() {
  printf "%s\n" $(git branch 2> /dev/null | grep -e ^* | tr -d "\* ")
}

function git-pull-safe() {
  local currentBranch=$(git-branch-current)
  local localLastCommit=$(git log --format="%H" $currentBranch | head -1)
  local localLastPushCommit="$(git log --format="%H" origin/${currentBranch}.. | tail -n-1)^"

  git fetch origin $currentBranch
  local remoteHeadCommit=$(git log --format="%H" origin/$currentBranch | head -1)
  if [ "$remoteHeadCommit" = "$localLastCommit" ] ; then
    # Same message as git pull prints in this case
    printf "Already up-to-date.\n"
    return
  fi

  git-log-incoming $currentBranch
  local reply=
  echo
  while read -p "What should we do now? (merge/diff/quit) " reply ; do
    if [ "$reply" = "m" -o "$reply" = "merge" ] ; then
      git merge origin/$currentBranch
      break
    elif [ "$reply" = "d" -o "$reply" = "diff" ] ; then
      git diff origin/$currentBranch ${localLastPushCommit}..HEAD
    elif [ "$reply" = "q" -o "$reply" = "quit" ] ; then
      return
    fi
  done
}

function git-log-for-branch() {
  branch="$1"
  git --no-pager log --format="$gitLogFormatShort" --no-merges $branch --not \
    $(git for-each-ref --format="%(refname)" refs/remotes/origin | \
      grep -F -v $branch)
}

function git-log-incoming() {
  local branch=$1
  if [ -z "$branch" ] ; then
    branch=$(git-branch-current)
  fi
  git --no-pager log --format="$gitLogFormatOneline" origin/$branch ^$branch
}

function git-log-incoming-interactive() {
  local branch=$(git-branch-current)
  local response=
  for i in $(git --no-pager log --format="%h" origin/$branch ^$branch) ; do
    clear
    git show $i
    read -p "Press any key to continue " response
  done
}

function git-stash-merge() {
  git stash
  git merge origin/$(git-branch-current)
  git stash pop
}

function git-checkout-remote-branch() {
  git checkout --track -b $1 origin/$1
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

function git-tag-for-commit() {
  git name-rev --name-only $1
}

function git-tag-last() {
  printf "%s\n" $(git-tag-list-sorted | tail -1)
}

# When git prints out tags with -l, they are sorted by not correctly when you
# have versions like 1.0.10, which would come before 1.0.2.
function git-tag-list-sorted() {
  git tag -l | sort -k 1n,1 -k 2n,2 -k 3n,3 -t '.'
}

function git-tag-next-version() {
  local lastTag=$(git-tag-last)
  local nextTag="${lastTag%.*}.$((${lastTag##*.} + 1))"

  if ! [ -z "$1" ] ; then
    local versionFile=$1
    if [ -z "$(grep $nextTag $versionFile)" ] ; then
      echo "You forgot to set the current version in $versionFile!"
      return 1
    fi
  fi

  local changelogFile=/tmp/changelog.txt
  git-log-since-last-tag changelog > $changelogFile
  $EDITOR $changelogFile
  echo "Tagging release $nextTag with:"
  cat $changelogFile
  git tag -s $nextTag -F $changelogFile
  if ! [ -z `which pbcopy` ] ; then
    pbcopy < $changelogFile
    echo "Changelog copied to clipboard"
  fi
  rm $changelogFile
}

