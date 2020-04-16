ss_info(){
	echo "snapshot.sh"
	echo "LABGUA SOFTWARE 2020"
	echo "List Actions"
	echo "> update <target> <zipfile>"
	echo "> revert <target> <zipfile>"
	echo "> ftp_send <pathfile>|{file-1,file-2,...,file-n}"
	echo "> rpc <function> [data]"
	echo "> install_rpc"
}

if [[ $# == 0 ]]; then
	ss_info
	exit 0
fi

#loading config
source .conf.snapshot

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
	echo "DONE"
}

revert(){
	TARGET=$1
	OUT_ZIPFILE=$2
	echo ">>> revert()"
	echo ">>> reading remote state from .snapshots ..."
	#HEAD_SHA=$(git rev-parse --short HEAD)
	HEAD_SHA=$(curl -u $SS_USER:$SS_PASS -o - "ftp://$SS_FTP_HOST$SS_PATH.snapshots")

	if [[ $HEAD_SHA == "" ]]; then
		echo "Errore, nessun snapshots trovato in remoto."
		exit -1
	fi

	echo -n "Stai per creare un revert fino al commit $TARGET, ok? [y/n]: "
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
	sed -i "s/$SS_SECRET/$NEW_SS_SECRET/" ".conf.snapshot"

	echo ">>> Generating php rpc server ..."
	cp "index.php.template" "index.php"
	sed -i "s/###SECRET###/$NEW_SS_SECRET/" "index.php"

	echo ">>> Sending to host ..."
	ftp_send $SS_PATH_RPC "{index.php,actions.php}"
	rm "index.php"
	echo ">>> rpc URI: $SS_HOST$SS_PATH_RPC"
	echo ">>> SECRET: $NEW_SS_SECRET"
}

case $ACTION in
	update)
		if [[ $# -lt 3 ]]; then
			echo "Errore parametri, definire il target e zipfile"
			exit -1
		fi
		update $2 $3
		;;
	revert)
		if [[ $# -lt 3 ]]; then
			echo "Errore parametri, definire il target e zipfile"
			exit -1
		fi
		revert $2 $3
		;;
	ftp_send)
		ftp_send $SS_PATH $2
		;;
	rpc)
		rpc $2 $3
		;;
	install_rpc)
		install_rpc
		;;
	*)
		echo "Errore, Comando non conosciuto."
		;;
esac