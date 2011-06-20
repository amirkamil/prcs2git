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

if [ $# -ne 1 ]; then
	cat <<EOF
Usage: $(basename $0) project

New Git repository is exported at ${gdir}project.

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

rm -rf  ${gdir}
mkdir -p ${gdir}
cd ${gdir}
git init

for i in ${revs[@]}; do 
	c_info=$(cd /; prcs info -f -r${i} -l ${package})
	c_branch=$(echo $i | sed -e 's/\.[0-9]\+$//')
	c_branch_rev=$(echo $i | sed -e 's/^.*\.//')
	p_revs=($(echo "${c_info}" | grep Parent-Version: | awk '{print $2}' ))

	date=$(echo "${c_info}" | cut -d' ' -f 3-8)

	if [ "${i}" = "0.1" ] ;then
	    rsync --exclude=.git --delete -ac "${pdir}/0.1/." .
	    git add .
	    git commit -a --date="${date}" -m "${c_info}"
	    git branch -m master prcs_0
	    continue
	fi
	
	if [ ${c_branch_rev} = "1" ]; then
	    p_branch=$(echo "${p_revs[0]}" | sed -e 's/\.[0-9]\+$//')
	    git checkout "prcs_${p_branch}"
	    git branch "prcs_${c_branch}"
	fi
	git checkout "prcs_${c_branch}"

	for p in ${p_revs[@]}; do 
	    p_branch=$(echo $p | sed -e 's/\.[0-9]\+$//')
	    p_branch_rev=$(echo $p | sed -e 's/^.*\.//')
	    git merge "prcs_${p_branch}" || true
	    git add -u 
	    git add . 
	done

	rsync --exclude=.git --delete -ac ${pdir}/${i}/. .

	git add -u 
	git add . 
	git commit -a --date="${date}" -m "${c_info}" 
done

rm -rf ${pdir}