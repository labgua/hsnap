
#loading config & set working directory
SS_DIR=$(dirname "$0")
ABS_SS_DIR=$(readlink -f $SS_DIR)
cd "$SS_DIR"
source .conf.snapshot
cd "$SS_WORKING_DIR"

echo "HSnap"
echo "LABGUA SOFTWARE 2020"
echo "(SS_DIR): $SS_DIR <- $ABS_SS_DIR"
echo "(WORKING_DIR): $PWD"

ss_info(){
	echo "List Actions"
	echo "> init"
	echo "> install_rpc"
	echo "> update <target> <zipfile>"
	echo "> revert <target> <zipfile>"
	echo "> ftp_send <pathfile>|{file-1,file-2,...,file-n} [! PWD]"
	echo "> rpc <function> [data]"
}

if [[ $# == 0 ]]; then
	ss_info
	exit 0
fi

ACTION=$1

update(){
	TARGET=$1
	OUT_ZIPFILE=$2
	echo ">>> update()"
	START_COMMIT=$(git rev-parse --short $(cat .snapshots) )

	echo ">>> update from $START_COMMIT to $TARGET ..."
	git diff-tree -r --no-commit-id --name-only --diff-filter=D $START_COMMIT $TARGET > .todelete
	echo $(git rev-parse --short "$TARGET") > .snapshots
	LIST_FILES=$(git diff-tree -r --no-commit-id --name-only --diff-filter=ACMRT $START_COMMIT $TARGET)
	LIST_FILES="$LIST_FILES\n.todelete\n.snapshots"

	echo ">>> creating zipfile $OUT_ZIPFILE ..."
	echo -e "$LIST_FILES" | zip -@ $OUT_ZIPFILE
	rm .todelete

	echo ">>> upload file:$OUT_ZIPFILE to $SS_FTP_HOST$SS_PATH ..."
	ftp_send "/snap/" $OUT_ZIPFILE

	echo ">>> remote patching..."
	echo "rpc \"synczip\" \"file=/snap/$OUT_ZIPFILE&path=$SS_PATH\""
	rpc "synczip" "file=/snap/$OUT_ZIPFILE&path=$SS_PATH"
	echo ">>> DONE"
}

revert(){
	TARGET=$1
	OUT_ZIPFILE=$2
	echo ">>> revert()"
	echo ">>> reading remote state from .snapshots ..."
	#HEAD_SHA=$(git rev-parse --short HEAD)
	HEAD_SHA=$(curl -u $SS_USER:$SS_PASS -o - "ftp://$SS_FTP_HOST$SS_PATH.snapshots")

	if [[ $HEAD_SHA == "" ]]; then
		echo "Error, snapshot not found on host server."
		exit -1
	fi

	echo -n "Do you really want to go back to commit $TARGET ? [y/n]: "
	read ASK_REVERT

	if [[ $ASK_REVERT == 'y' ]]; then
		echo ">>> revert from HEAD:$HEAD_SHA to $TARGET ..."

		git revert --no-commit $TARGET..HEAD
		git commit -m "Revert commit $TARGET..HEAD:$HEAD_SHA"

		update "HEAD" $OUT_ZIPFILE
	fi
}

ftp_send(){
	UPLOAD_PATH=$1
	FILE_TO_UPLOAD=$2
	echo ">>> ftp_send()"
	echo ">>> upload file:$FILE_TO_UPLOAD to $SS_FTP_HOST$UPLOAD_PATH ..."
	curl -T $FILE_TO_UPLOAD -u $SS_USER:$SS_PASS ftp://$SS_FTP_HOST$UPLOAD_PATH --ftp-create-dirs
	echo ">>> DONE"
}

ftp_get(){
	URI_PATH=$1
	curl -u $SS_USER:$SS_PASS -O "ftp://$SS_FTP_HOST$URI_PATH"
}

rpc(){
	ACTION=$1
	POST_DATA=$2
	curl -d "secret=$SS_SECRET&_action=$ACTION&$POST_DATA" "$SS_HOST$SS_PATH_RPC"
	echo ""
}

install_rpc(){
	echo ">>> install_rpc()"
	echo ">>> Installing rpc in $SS_PATH_RPC ..."

	echo ">>> Updating .conf.snapshot with new secret ..."
	NEW_SS_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
	sed -i "/SS_SECRET/c\SS_SECRET=\"$NEW_SS_SECRET\"" "$SS_DIR/.conf.snapshot"

	echo ">>> Generating php rpc server ..."
	cp "$SS_DIR/index.php.template" "$SS_DIR/index.php"
	sed -i "s/###SECRET###/$NEW_SS_SECRET/" "$SS_DIR/index.php"
	sed -i "s/###DIR_INST###/$SS_PATH_RPC/" "$SS_DIR/index.php"

	echo ">>> Sending to host ..."
	ftp_send $SS_PATH_RPC "{$SS_DIR/index.php,$SS_DIR/actions.php}"
	rm "$SS_DIR/index.php"
	echo ">>> rpc URI: $SS_HOST$SS_PATH_RPC"
	echo ">>> SECRET: $NEW_SS_SECRET"
}

init_project(){
	echo ">>> check git project ..."
	if [ -d ".git" ]; then
		echo ">>> OK"
	else
		echo ">>> Error: this is not a git project"
		echo ">>> try to make it with: 'git init'"
		exit -1
	fi

	echo ">>> checking .gitignore ..."
	if [ ! -f ".gitignore" ]; then
		echo ">>> not found .gitignore, making ..."
		touch .gitignore
	fi

	echo ">>> checking for snapshot.sh rules ..."
	cat ".gitignore" | grep "###> snapshot.sh ignore" >/dev/null
	if [[ $? == 0 ]]; then
		echo ">>> OK"
	else
		echo ">>> NO rules, adding to .gitignore ..."

		## HP: ABS_SS_DIR := WORKING_DIR + RELATIVE_PREFIX_PATH
		##  -> RELATIVE_PREFIX_PATH = ABS_SS_DIR - WORKING_DIR
		RELATIVE_PREFIX_PATH="${ABS_SS_DIR/$PWD/""}/" 

		echo "" >> .gitignore
		echo "###> snapshot.sh ignore ###" >> .gitignore
		echo $RELATIVE_PREFIX_PATH >> .gitignore
		echo "###< snapshot.sh ignore ###" >> .gitignore

		echo ">>> resync git repo with new .gitignore file"
		#https://stackoverflow.com/questions/7075923/resync-git-repo-with-new-gitignore-file
		# if "fatal: pathspec '...' did not match any files" it's ok, https://ar.al/2389/
		git rm -r --cached .
		git add .
		git commit -m "setting .gitignore for snapshot.sh"
	fi


	echo ">>> committing the installation ..."
	git commit -m "snapshot.sh installed [empty commit]" --allow-empty
	git rev-parse --short HEAD > .snapshots

	echo ">>> DONE"
}

case $ACTION in
	update)
		if [[ $# -lt 3 ]]; then
			echo "$ACTION: Error, you must define <target> <zipfile>"
			exit -1
		fi
		update $2 $3
		;;
	revert)
		if [[ $# -lt 3 ]]; then
			echo "$ACTION: Error, you must define <target> <zipfile>"
			exit -1
		fi
		revert $2 $3
		;;
	ftp_send)
		if [[ $# -lt 2 ]]; then
			echo "$ACTION: Error, you must define <pathfile>|{file-1,file-2,...,file-n}"
			exit -1
		fi
		ftp_send $SS_PATH $2
		;;
	rpc)
		if [[ $# -lt 2 ]]; then
			echo "$ACTION: Error, you must define <function>"
			exit -1
		fi
		rpc $2 $3
		;;
	install_rpc)
		install_rpc
		;;
	init)
		init_project
		;;
	*)
		echo "$ACTION: unknown action"
		exit -1
		;;
esac
