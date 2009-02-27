#!/bin/bash 
# prcs2git - convert PRCS repository to Git repository
# Copyright (C) 2009 TANIGUCHI, Takaki <takaki@asis.media-as.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -e

package=$1
basedir=/tmp/prcs2git
pdir=${basedir}/prcs/${package}
gdir=${basedir}/git/${package}
edir=${basedir}/export/${package}

if [ $# -ne 1 ]; then
	cat <<EOF
Usage: $(basename $0) project

New Git repository placed at ${edir}project.

prcs2git - Copyright (C) 2009 TANIGUCHI Takaki <takaki@asis.media-as.org>
This program comes with ABSOLUTELY NO WARRANTY.  This is free software,
and you are welcome to redistribute it under certain conditions
EOF
	exit 1
fi

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

