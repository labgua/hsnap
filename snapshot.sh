
if [[ $# == 0 ]]; then
	echo "Errore, selezionare una azione"
	echo " > update <target> <zipfile>"
	echo " > revert <target> <zipfile>"
	exit -1
fi

#loading config
source .conf.snapshot

ACTION=$1

update(){
	TARGET=$1
	OUT_ZIPFILE=$2
	echo ">>> update()"
	START_COMMIT=$(cat .snapshots)

	echo ">>> update from $START_COMMIT to $TARGET ..."
	git diff-tree -r --no-commit-id --name-only --diff-filter=D $START_COMMIT $TARGET > .todelete
	echo "$TARGET" > .snapshots
	LIST_FILES=$(git diff-tree -r --no-commit-id --name-only --diff-filter=ACMRT $START_COMMIT $TARGET)
	LIST_FILES="$LIST_FILES\n.todelete\n.snapshots"

	#echo ">>> creating zipfile $OUT_ZIPFILE ..."
	#echo -e "$LIST_FILES" | zip -@ $OUT_ZIPFILE

	#echo ">>> upload file:$FILE_TO_UPLOAD to $SS_FTP_HOST$SS_PATH ..."
	#ftp_send $FILE_TO_UPLOAD

	#echo ">>> remote patching..."
	#rpc "synczip" "file=XXXXX_snapshot.zip&path=PROJ_DIR/"
	#echo "DONE"
}

revert(){
	TARGET=$1
	OUT_ZIPFILE=$2
	echo ">>> revert()"
	START_COMMIT=$(cat .snapshots)

	echo -n "Creare un revert fino al commit $TARGET ? [y/n]: "
	read ASK_REVERT

	if [[ $ASK_REVERT == 'y' ]]; then
		echo ">>> revert from $START_COMMIT to $TARGET ..."

		git revert --no-commit $START_COMMIT..$TARGET  
		git commit -m "Revert commit $START_COMMIT..$TARGET"

		update "HEAD~1" "HEAD"
	fi
}

test_ftp(){
	FILE_TO_UPLOAD=$1

	echo ">>> test_ftp()"
	echo ">>> upload file:$FILE_TO_UPLOAD to $SS_FTP_HOST$SS_PATH ..."

	ftp_send $FILE_TO_UPLOAD

	echo ">>> DONE"
}

ftp_send(){
	FILE_TO_UPLOAD=$1
	curl -T $FILE_TO_UPLOAD -u $SS_USER:$SS_PASS ftp://$SS_FTP_HOST$SS_PATH
}

rpc(){
	ACTION=$1
	POST_DATA=$2
	curl -d "secret=$SS_SECRET&_action=$ACTION&$POST_DATA" "$SS_URL_RPC"
	echo ""
}


case $ACTION in
	update)
		if [[ $# -lt 3 ]]; then
			echo "Errore parametri, definire il target e zipfile"
			exit -1
		fi
		update $2
		;;
	revert)
		if [[ $# -lt 3 ]]; then
			echo "Errore parametri, definire il target e zipfile"
			exit -1
		fi
		revert $2
		;;
	test_ftp)
		test_ftp $2
		;;
	test_rpc)
		rpc $2 $3
esac