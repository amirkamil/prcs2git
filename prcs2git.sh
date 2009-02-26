#!/bin/bash 

set -e

if [ $# -ne 1 ]; then
	echo Usage: $(basename $0) package
	exit 1
fi

package=$1

basedir=/tmp/p2g
pdir=${basedir}/prcs/${package}
gdir=${basedir}/git/${package}
edir=${basedir}/export/${package}

revs=($(prcs info --sort=date ${package} | grep -v '\*DELETED\*' | awk '{print $2}'))

branches=($(for i in ${revs[@]}; do 
	echo $i | sed -e 's/\.[0-9]\+$//'
done | sort -u ))

for i in ${revs[@]}; do 
	mkdir -p ${pdir}/${i}
	cd ${pdir}/${i}
	if [ ! -f ${package}.prj ]; then
		prcs checkout -f -r${i} ${package} 
	fi
done

for i in ${branches[@]}; do 
	mkdir -p ${gdir}/${i}
	cd ${gdir}/${i}
	git init
done

for i in ${revs[@]}; do 
	c_info=$(cd /; prcs info -f -r${i} -l ${package})
	c_branch=$(echo $i | sed -e 's/\.[0-9]\+$//')
	p_revs=($(echo "${c_info}" | grep Parent-Version: | awk '{print $2}' ))
	cd ${gdir}/${c_branch}

	for p in ${p_revs[@]}; do 
		branch=$(echo $p | sed -e 's/\.[0-9]\+$//')
		git pull ${gdir}/${branch} ${branch} || true
	done
	rsync --exclude=.git --delete -a ${pdir}/${i}/. .
	until git add . ; do 
		git rm $(git add . 2>&1 |grep ^fatal:|
			grep 'unable to stat'|awk  '{print $2}'|
			cut -d: -f1)
	done

	git commit -a -m "${c_info}"

	if git branch | grep "\* master\$"; then
		git branch -m master ${c_branch}
	fi
done

mkdir -p ${edir}
cd ${edir}
git init

for b in ${branches[@]}; do 
	git remote add ${b} ${gdir}/${b} 
	git fetch ${b}
	git checkout ${b}/${b}
	git checkout -b ${b}/${b}
	git branch -m ${b}/${b} prcs_${b}
	git remote rm ${b}
done

