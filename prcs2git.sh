#!/bin/bash 

if [ $# -ne 1 ]; then
	echo Usage: $(basename $0) package
	exit 1
fi

package=$1

basedir=/tmp/p2g
workdir=${basedir}/${package}
pdir=${basedir}/prcs/${package}
gdir=${basedir}/git/${package}

revs=($(prcs info --sort=date ${package} | awk '{print $2}'))

branches=($(for i in ${revs[@]}; do 
	echo $i | sed -e 's/\.[0-9]\+$//'
done | sort -u ))

for i in ${revs[@]}; do 
	mkdir -p ${pdir}/${i}
	(cd ${pdir}/${i}; 
	prcs checkout -f -r${i} ${package} 
	)
done

for i in ${branches[@]}; do 
	mkdir -p ${gdir}/${i}
	(cd ${gdir}/${i}
	git init
	)
done

for i in ${revs[@]}; do 
	if [ ${i} = "0.1" ]; then
		(
		cd ${gdir}/0
		git init 
		rsync -a ${pdir}/${i}/. .
		git add .
		git commit -a -m "${i} init"
		git branch -m master 0
		)
		continue
	fi

	c_branch=$(echo $i | sed -e 's/\.[0-9]\+$//')
	c_info=$(cd /; prcs info -f -r${i} -l ${package})
	p_revs=($(echo ${c_info} | grep Parent-Version: | awk '{print $2}' ))
	cd ${gdir}/${c_branch}
	if [ $(git branch| wc -l ) -eq 0 ] ; then
		for p in ${p_revs[@]}; do 
			branch=$(echo $p | sed -e 's/\.[0-9]\+$//')
			git pull ${gdir}/${branch} ${branch}
		done
		git branch -m master ${c_branch}
		git checkout ${c_branch}
		rsync --exclude=.git --delete -a ${pdir}/${i}/. .
		git add . || exit 1
		git commit -a -m "${p} -> ${i}"
	else
		for p in ${p_revs[@]}; do 
			branch=$(echo $p | sed -e 's/\.[0-9]\+$//')
			git pull ${gdir}/${branch} ${branch}
			rsync --exclude=.git --delete -a ${pdir}/${i}/. .
			git add . || exit 1
			git commit -a -m "${p} -> ${i}"
		done
	fi
done

#mkdir -p ${workdir}/${package}_git
#cd ${workdir}/${package}_git
mkdir -p ${basedir}/export/${package}
cd ${basedir}/export/${package}
git init

for b in ${branches[@]}; do 
	git remote add ${b} ${gdir}/${b}
	git fetch ${b}
	git checkout ${b}/${b}
	git checkout -b ${b}/${b}
	git branch -m ${b}/${b} prcs_${b}
	git remote rm ${b}
done

